import 'dart:convert';

import 'package:JsxposedX/core/enums/ai_api_type.dart';
import 'package:JsxposedX/core/models/ai_config.dart';
import 'package:JsxposedX/core/network/http_service.dart';
import 'package:JsxposedX/core/providers/pinia_provider.dart';
import 'package:JsxposedX/feature/ai/data/models/ai_message_dto.dart';
import 'package:JsxposedX/feature/ai/data/models/ai_session_dto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class AiChatActionDatasource {
  AiChatActionDatasource({
    required HttpService httpService,
    required PiniaStorage storage,
  }) : _httpService = httpService,
       _storage = storage;

  final HttpService _httpService;
  final PiniaStorage _storage;

  static const String _sessionIndexKeyPrefix = 'ai_v2_sessions_';
  static const String _chatSpacePrefix = 'ai_v2_chat_';
  static const String _chatConfigSpacePrefix = 'ai_v2_chat_config_';
  static const String _chatContentKey = 'messages';
  static const String _chatConfigKey = 'config';

  Stream<AiMessageDto> postChatStream({
    required AiConfig config,
    required List<AiMessageDto> messages,
    List<Map<String, dynamic>>? tools,
  }) {
    switch (config.apiType) {
      case AiApiType.openai:
        return _postOpenAiChatStream(
          config: config,
          messages: messages,
          tools: tools,
        );
      case AiApiType.anthropic:
        return _postAnthropicChatStream(
          config: config,
          messages: messages,
          tools: tools,
        );
    }
  }

  Future<String> testConnection(AiConfig config) {
    switch (config.apiType) {
      case AiApiType.openai:
        return _testOpenAiConnection(config);
      case AiApiType.anthropic:
        return _testAnthropicConnection(config);
    }
  }

  Future<void> saveSessionsIndex(
    String packageName,
    List<AiSessionDto> sessionsDtos,
  ) async {
    final json = jsonEncode(sessionsDtos.map((e) => e.toJson()).toList());
    await _storage.setString(_getSessionIndexKey(packageName), json);
  }

  Future<void> saveLastActiveSessionId(
    String packageName,
    String sessionId,
  ) async {
    await _storage.setString(
      _chatConfigKey,
      sessionId,
      space: _getChatConfigSpace(packageName),
    );
  }

  Future<void> clearLastActiveSessionId(String packageName) async {
    await _storage.remove(
      _chatConfigKey,
      space: _getChatConfigSpace(packageName),
    );
  }

  Future<void> saveChatHistory(
    String packageName,
    String sessionId,
    List<AiMessageDto> messagesDtos,
  ) async {
    final json = jsonEncode(messagesDtos.map((e) => e.toStorageJson()).toList());
    await _storage.setString(
      _chatContentKey,
      json,
      space: _getChatSpace(sessionId, packageName),
    );
  }

  Future<void> removeChatHistory(String packageName, String sessionId) async {
    await _storage.clear(space: _getChatSpace(sessionId, packageName));
  }

  String _getSessionIndexKey(String packageName) =>
      '$_sessionIndexKeyPrefix$packageName';

  String _getChatSpace(String sessionId, String packageName) =>
      '$_chatSpacePrefix${sessionId}_$packageName';

  String _getChatConfigSpace(String packageName) =>
      '$_chatConfigSpacePrefix$packageName';

  Stream<AiMessageDto> _postOpenAiChatStream({
    required AiConfig config,
    required List<AiMessageDto> messages,
    List<Map<String, dynamic>>? tools,
  }) async* {
    final request = <String, dynamic>{
      'model': config.moduleName,
      'messages': messages.map((message) => message.toJson()).toList(),
      'stream': true,
      'temperature': config.temperature,
      'max_tokens': config.maxToken,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
    };

    try {
      final response = await _httpService.dio.post(
        config.fullApiUrl,
        data: request,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            if (config.apiKey.isNotEmpty) 'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
        ),
      );

      _ensureSuccessfulResponse(response);

      final stream = response.data.stream as Stream<List<int>>;
      var buffered = '';
      var isDone = false;
      final toolCallsAccum = <int, Map<String, dynamic>>{};

      await for (final chunk in stream) {
        if (isDone) {
          break;
        }

        buffered += utf8.decode(chunk);
        final lines = buffered.split('\n');
        buffered = lines.removeLast();

        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (line.isEmpty || !line.startsWith('data:')) {
            continue;
          }

          final data = line.substring(5).trim();
          if (data.isEmpty) {
            continue;
          }

          if (data == '[DONE]') {
            isDone = true;
            yield* _yieldValidatedOpenAiToolCalls(toolCallsAccum);
            break;
          }

          final decoded = _tryDecodeJson(data);
          if (decoded is! Map<String, dynamic>) {
            continue;
          }

          final choices = decoded['choices'];
          if (choices is! List || choices.isEmpty) {
            continue;
          }

          final delta = choices.first['delta'];
          if (delta is! Map<String, dynamic>) {
            continue;
          }

          final content = delta['content']?.toString();
          if (content != null && content.isNotEmpty) {
            yield AiMessageDto(role: 'assistant', content: content);
          }

          final toolCalls = delta['tool_calls'];
          if (toolCalls is List) {
            _accumulateOpenAiToolCalls(toolCallsAccum, toolCalls);
          }
        }
      }

      if (!isDone && buffered.trim().isNotEmpty) {
        final tail = buffered.trim();
        if (tail.startsWith('data:')) {
          final data = tail.substring(5).trim();
          if (data == '[DONE]') {
            yield* _yieldValidatedOpenAiToolCalls(toolCallsAccum);
          } else {
            final decoded = _tryDecodeJson(data);
            if (decoded is Map<String, dynamic>) {
              final choices = decoded['choices'];
              if (choices is List && choices.isNotEmpty) {
                final delta = choices.first['delta'];
                if (delta is Map<String, dynamic>) {
                  final content = delta['content']?.toString();
                  if (content != null && content.isNotEmpty) {
                    yield AiMessageDto(role: 'assistant', content: content);
                  }
                  final toolCalls = delta['tool_calls'];
                  if (toolCalls is List) {
                    _accumulateOpenAiToolCalls(toolCallsAccum, toolCalls);
                    yield* _yieldValidatedOpenAiToolCalls(toolCallsAccum);
                  }
                }
              }
            }
          }
        }
      }
    } on DioException catch (error) {
      throw PlatformException(
        code: error.type.name,
        message: error.message ?? 'AI request failed',
        details: error.response?.data,
      );
    } on PlatformException {
      rethrow;
    } catch (error) {
      throw PlatformException(
        code: 'unknown_error',
        message: error.toString(),
      );
    }
  }

  Stream<AiMessageDto> _postAnthropicChatStream({
    required AiConfig config,
    required List<AiMessageDto> messages,
    List<Map<String, dynamic>>? tools,
  }) async* {
    String? system;
    final payloadMessages = <Map<String, dynamic>>[];

    for (final message in messages) {
      if (message.role == 'system') {
        system = message.content;
        continue;
      }

      payloadMessages.add(_mapAnthropicMessage(message));
    }

    final request = <String, dynamic>{
      'model': config.moduleName,
      'messages': payloadMessages,
      'max_tokens': config.maxToken,
      'temperature': config.temperature,
      'stream': true,
      if (system != null && system.isNotEmpty) 'system': system,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
    };

    try {
      final response = await _httpService.dio.post(
        config.fullApiUrl,
        data: request,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'x-api-key': config.apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
        ),
      );

      _ensureSuccessfulResponse(response);

      final stream = response.data.stream as Stream<List<int>>;
      var buffered = '';
      final toolCalls = <Map<String, dynamic>>[];
      final toolArgumentBuffers = <int, StringBuffer>{};

      await for (final chunk in stream) {
        buffered += utf8.decode(chunk);
        final lines = buffered.split('\n');
        buffered = lines.removeLast();

        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (line.isEmpty || !line.startsWith('data:')) {
            continue;
          }

          final data = line.substring(5).trim();
          if (data.isEmpty) {
            continue;
          }

          final decoded = _tryDecodeJson(data);
          if (decoded is! Map<String, dynamic>) {
            continue;
          }

          final type = decoded['type']?.toString();
          if (type == 'content_block_start') {
            final contentBlock = decoded['content_block'];
            if (contentBlock is Map<String, dynamic> &&
                contentBlock['type'] == 'tool_use') {
              final index = toolCalls.length;
              toolCalls.add({
                'id': contentBlock['id']?.toString() ?? '',
                'type': 'function',
                'function': {
                  'name': contentBlock['name']?.toString() ?? '',
                  'arguments': '{}',
                },
              });
              toolArgumentBuffers[index] = StringBuffer();
            }
            continue;
          }

          if (type == 'content_block_delta') {
            final delta = decoded['delta'];
            if (delta is! Map<String, dynamic>) {
              continue;
            }

            final deltaType = delta['type']?.toString();
            if (deltaType == 'text_delta') {
              final text = delta['text']?.toString();
              if (text != null && text.isNotEmpty) {
                yield AiMessageDto(role: 'assistant', content: text);
              }
              continue;
            }

            if (deltaType == 'input_json_delta' && toolCalls.isNotEmpty) {
              final currentIndex = toolCalls.length - 1;
              toolArgumentBuffers[currentIndex]?.write(
                delta['partial_json']?.toString() ?? '',
              );
            }
            continue;
          }

          if (type == 'message_stop') {
            for (var index = 0; index < toolCalls.length; index++) {
              final rawArgs = toolArgumentBuffers[index]?.toString().trim() ?? '';
              if (rawArgs.isEmpty) {
                toolCalls[index]['function']['arguments'] = '{}';
                continue;
              }

              final decodedArgs = _tryDecodeJson(rawArgs);
              if (decodedArgs is Map<String, dynamic>) {
                toolCalls[index]['function']['arguments'] = jsonEncode(decodedArgs);
              } else {
                throw PlatformException(
                  code: 'parse_error',
                  message: 'Anthropic tool input JSON parse failed',
                  details: rawArgs,
                );
              }
            }

            if (toolCalls.isNotEmpty) {
              yield AiMessageDto(
                role: 'assistant',
                content: '',
                toolCalls: toolCalls,
              );
            }
            return;
          }
        }
      }

      if (buffered.trim().isNotEmpty) {
        final tail = buffered.trim();
        if (tail.startsWith('data:')) {
          final data = tail.substring(5).trim();
          final decoded = _tryDecodeJson(data);
          if (decoded is Map<String, dynamic> &&
              decoded['type']?.toString() == 'message_stop' &&
              toolCalls.isNotEmpty) {
            for (var index = 0; index < toolCalls.length; index++) {
              final rawArgs = toolArgumentBuffers[index]?.toString().trim() ?? '';
              toolCalls[index]['function']['arguments'] =
                  rawArgs.isEmpty ? '{}' : rawArgs;
            }
            yield AiMessageDto(role: 'assistant', content: '', toolCalls: toolCalls);
          }
        }
      }
    } on DioException catch (error) {
      throw PlatformException(
        code: error.type.name,
        message: error.message ?? 'AI request failed',
        details: error.response?.data,
      );
    } on PlatformException {
      rethrow;
    } catch (error) {
      throw PlatformException(
        code: 'unknown_error',
        message: error.toString(),
      );
    }
  }

  Future<String> _testOpenAiConnection(AiConfig config) async {
    return _testStreamingConnection(
      url: config.fullApiUrl,
      headers: {
        if (config.apiKey.isNotEmpty) 'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      },
      request: {
        'model': config.moduleName,
        'messages': const [
          {'role': 'user', 'content': 'Hi'},
        ],
        'stream': true,
        'temperature': 0.0,
        'max_tokens': 1,
      },
    );
  }

  Future<String> _testAnthropicConnection(AiConfig config) async {
    return _testStreamingConnection(
      url: config.fullApiUrl,
      headers: {
        'x-api-key': config.apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      },
      request: {
        'model': config.moduleName,
        'messages': const [
          {'role': 'user', 'content': 'Hi'},
        ],
        'stream': true,
        'temperature': 0.0,
        'max_tokens': 1,
      },
    );
  }

  Future<String> _testStreamingConnection({
    required String url,
    required Map<String, dynamic> request,
    required Map<String, String> headers,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _httpService.dio.post(
        url,
        data: request,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      _ensureSuccessfulResponse(response);

      final stream = response.data.stream as Stream<List<int>>;
      await for (final chunk in stream) {
        if (chunk.isEmpty) {
          continue;
        }

        stopwatch.stop();
        final responseTime = stopwatch.elapsedMilliseconds;
        return responseTime < 6000
            ? 'Connection successful (${responseTime}ms)'
            : 'Connection successful but latency is high (${responseTime}ms)';
      }

      throw PlatformException(
        code: 'no_data',
        message: 'No response data received',
      );
    } on DioException catch (error) {
      stopwatch.stop();
      throw PlatformException(
        code: error.type.name,
        message: error.message ?? 'Connection failed',
        details: error.response?.data,
      );
    } on PlatformException {
      rethrow;
    } catch (error) {
      stopwatch.stop();
      throw PlatformException(
        code: 'unknown_error',
        message: error.toString(),
      );
    }
  }

  void _ensureSuccessfulResponse(Response<dynamic> response) {
    final statusCode = response.statusCode;
    if (statusCode != null && statusCode >= 200 && statusCode < 300) {
      return;
    }

    throw PlatformException(
      code: 'http_error',
      message: 'HTTP ${response.statusCode}: ${response.statusMessage ?? 'Unknown error'}',
      details: response.data,
    );
  }

  dynamic _tryDecodeJson(String data) {
    try {
      return jsonDecode(data);
    } catch (_) {
      return null;
    }
  }

  void _accumulateOpenAiToolCalls(
    Map<int, Map<String, dynamic>> toolCallsAccum,
    List<dynamic> toolCalls,
  ) {
    for (final rawCall in toolCalls) {
      if (rawCall is! Map<String, dynamic>) {
        continue;
      }

      final index = rawCall['index'] as int? ?? 0;
      final current = toolCallsAccum.putIfAbsent(index, () {
        return {
          'id': rawCall['id']?.toString() ?? '',
          'type': 'function',
          'function': {
            'name': rawCall['function']?['name']?.toString() ?? '',
            'arguments': <String, dynamic>{},
          },
        };
      });

      final function = current['function'] as Map<String, dynamic>;
      final functionPayload = rawCall['function'];
      if (functionPayload is Map<String, dynamic>) {
        final name = functionPayload['name']?.toString();
        if (name != null && name.isNotEmpty) {
          function['name'] = name;
        }

        final argumentsChunk = functionPayload['arguments']?.toString() ?? '';
        if (argumentsChunk.isNotEmpty) {
          final parsedArgs = _tryDecodeJson(argumentsChunk);
          if (parsedArgs is Map<String, dynamic>) {
            final args = function['arguments'] as Map<String, dynamic>;
            args.addAll(parsedArgs);
          } else {
            final argBuffer = current.putIfAbsent('_argBuffer', () => StringBuffer());
            (argBuffer as StringBuffer).write(argumentsChunk);
          }
        }
      }

      final id = rawCall['id']?.toString();
      if (id != null && id.isNotEmpty) {
        current['id'] = id;
      }
    }
  }

  Stream<AiMessageDto> _yieldValidatedOpenAiToolCalls(
    Map<int, Map<String, dynamic>> toolCallsAccum,
  ) async* {
    if (toolCallsAccum.isEmpty) {
      return;
    }

    final validated = <Map<String, dynamic>>[];
    for (final call in toolCallsAccum.values) {
      final function = call['function'] as Map<String, dynamic>;
      final arguments = function['arguments'];
      if (call['_argBuffer'] is StringBuffer) {
        final raw = (call['_argBuffer'] as StringBuffer).toString().trim();
        if (raw.isNotEmpty) {
          final parsedArgs = _tryDecodeJson(raw);
          if (parsedArgs is Map<String, dynamic>) {
            (arguments as Map<String, dynamic>).addAll(parsedArgs);
          }
        }
      }

      function['arguments'] = arguments is Map<String, dynamic>
          ? jsonEncode(arguments)
          : '{}';
      call.remove('_argBuffer');
      validated.add(call);
    }

    if (validated.isNotEmpty) {
      yield AiMessageDto(role: 'assistant', content: '', toolCalls: validated);
    }
  }

  Map<String, dynamic> _mapAnthropicMessage(AiMessageDto message) {
    if (message.role == 'tool' && message.toolCallId != null) {
      return {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': message.toolCallId,
            'content': message.content,
          },
        ],
      };
    }

    if (message.toolCalls != null && message.toolCalls!.isNotEmpty) {
      return {
        'role': 'assistant',
        'content': message.toolCalls!.map((toolCall) {
          final function = toolCall['function'] as Map<String, dynamic>? ?? {};
          final rawArguments = function['arguments'];
          return {
            'type': 'tool_use',
            'id': toolCall['id'],
            'name': function['name'],
            'input': rawArguments is String
                ? (_tryDecodeJson(rawArguments) ?? <String, dynamic>{})
                : (rawArguments ?? <String, dynamic>{}),
          };
        }).toList(),
      };
    }

    return {
      'role': message.role,
      'content': message.content,
    };
  }
}
