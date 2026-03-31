import 'dart:async';

import 'package:JsxposedX/core/models/ai_config.dart';
import 'package:JsxposedX/core/models/ai_message.dart';
import 'package:JsxposedX/core/models/ai_session.dart';
import 'package:JsxposedX/core/network/http_service.dart';
import 'package:JsxposedX/core/providers/pinia_provider.dart';
import 'package:JsxposedX/feature/ai/data/datasources/chat/ai_chat_action_datasource.dart';
import 'package:JsxposedX/feature/ai/data/repositories/chat/ai_chat_action_repository_impl.dart';
import 'package:JsxposedX/feature/ai/domain/models/ai_response_issue.dart';
import 'package:JsxposedX/feature/ai/domain/models/ai_session_init_state.dart';
import 'package:JsxposedX/feature/ai/domain/models/ai_tool_call.dart';
import 'package:JsxposedX/feature/ai/domain/repositories/chat/ai_chat_action_repository.dart';
import 'package:JsxposedX/feature/ai/domain/services/prompt_builder.dart';
import 'package:JsxposedX/feature/ai/domain/services/tool_executor.dart';
import 'package:JsxposedX/feature/ai/presentation/providers/chat/ai_chat_query_provider.dart';
import 'package:JsxposedX/feature/ai/presentation/providers/config/ai_config_query_provider.dart';
import 'package:JsxposedX/feature/ai/presentation/states/ai_chat_action_state.dart';
import 'package:JsxposedX/feature/apk_analysis/presentation/providers/apk_analysis_query_provider.dart';
import 'package:JsxposedX/feature/so_analysis/presentation/providers/so_analysis_provider.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'ai_chat_action_provider.g.dart';

@Riverpod(keepAlive: true)
Future<bool> aiStatus(Ref ref) async {
  final config = ref.watch(aiConfigProvider).value;
  if (config == null || config.apiUrl.isEmpty) {
    return false;
  }

  try {
    await ref.read(aiChatActionRepositoryProvider).testConnection(config);
    return true;
  } catch (_) {
    return false;
  }
}

@riverpod
AiChatActionDatasource aiChatActionDatasource(Ref ref) {
  final httpService = ref.watch(httpServiceProvider);
  final storage = ref.watch(piniaStorageLocalProvider);
  return AiChatActionDatasource(httpService: httpService, storage: storage);
}

@riverpod
AiChatActionRepository aiChatActionRepository(Ref ref) {
  final dataSource = ref.watch(aiChatActionDatasourceProvider);
  return AiChatActionRepositoryImpl(dataSource: dataSource);
}

@riverpod
class AiChatAction extends _$AiChatAction {
  static const String _sessionSummaryPrefix = '[session_summary]';
  static const int _contextHardBudgetChars = 16000;
  static const int _contextTargetBudgetChars = 9000;
  static const int _recentUserRoundsToKeep = 3;
  static const int _toolResultProtocolMaxChars = 900;

  bool _isDisposed = false;
  bool _stopRequested = false;
  final StreamController<String> _streamingContentController =
      StreamController<String>.broadcast();
  StreamSubscription? _activeResponseSubscription;
  Completer<_CollectedAssistantResponse>? _activeResponseCompleter;
  String _latestStreamingContent = '';

  Stream<String> get streamingContentStream =>
      _streamingContentController.stream;

  @override
  AiChatActionState build({required String packageName}) {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _activeResponseSubscription?.cancel();
      _streamingContentController.close();
    });
    Future.microtask(() {
      if (!_isDisposed) {
        _initSessions();
      }
    });
    return const AiChatActionState();
  }

  void beginSessionInitialization() {
    _clearStreamingContent();
    state = state.copyWith(
      sessionInitState: AiSessionInitState.initializing,
      error: null,
      lastResponseIssue: null,
      apkSessionId: null,
      dexPaths: const [],
    );
  }

  void markSessionReady() {
    state = state.copyWith(
      sessionInitState: AiSessionInitState.ready,
      error: null,
      lastResponseIssue: null,
    );
  }

  void markSessionInitFailed(String message) {
    _clearStreamingContent();
    state = state.copyWith(
      sessionInitState: AiSessionInitState.failed,
      error: message,
      lastResponseIssue: AiResponseIssue.toolInitError,
      isStreaming: false,
      apkSessionId: null,
      dexPaths: const [],
    );
  }

  void setSystemPrompt(String prompt) {
    state = state.copyWith(systemPrompt: prompt);
  }

  void setApkSession(String sessionId, List<String> dexPaths) {
    state = state.copyWith(
      apkSessionId: sessionId,
      dexPaths: List<String>.unmodifiable(dexPaths),
    );
  }

  Future<void> _initSessions() async {
    try {
      final sessions = await getSessionsAsync();
      if (_isDisposed || sessions.isEmpty) {
        return;
      }

      final lastActiveSessionId = await ref
          .read(aiChatQueryRepositoryProvider)
          .getLastActiveSessionId(packageName);
      if (_isDisposed) {
        return;
      }

      final initialSessionId =
          lastActiveSessionId != null &&
              sessions.any((session) => session.id == lastActiveSessionId)
          ? lastActiveSessionId
          : sessions.first.id;
      await switchSession(initialSessionId);
    } catch (_) {
      if (_isDisposed) {
        return;
      }
      state = state.copyWith(
        error: 'AI 会话加载失败',
        isStreaming: false,
      );
    }
  }

  Future<List<AiSession>> getSessionsAsync() async {
    final sessions = await ref
        .read(aiChatQueryRepositoryProvider)
        .getSessions(packageName);
    sessions.sort(
      (left, right) => right.lastUpdateTime.compareTo(left.lastUpdateTime),
    );
    if (_isDisposed) {
      return sessions;
    }
    state = state.copyWith(sessions: List<AiSession>.unmodifiable(sessions));
    return sessions;
  }

  List<AiSession> getSessions() => state.sessions;

  Future<void> switchSession(String sessionId) async {
    _clearStreamingContent();
    final protocolMessages = await ref
        .read(aiChatQueryRepositoryProvider)
        .getChatHistory(packageName, sessionId);
    if (_isDisposed) {
      return;
    }

    final displayMessages = _buildDisplayMessagesFromProtocol(protocolMessages);
    state = state.copyWith(
      currentSessionId: sessionId,
      protocolMessages: List<AiMessage>.unmodifiable(protocolMessages),
      messages: List<AiMessage>.unmodifiable(displayMessages),
      visibleMessageCount: 10,
      error: null,
      isStreaming: false,
      lastResponseIssue: null,
    );
    await ref
        .read(aiChatActionRepositoryProvider)
        .saveLastActiveSessionId(packageName, sessionId);
  }

  void loadMore() {
    if (state.visibleMessageCount >= state.totalVisibleMessagesCount) {
      return;
    }

    state = state.copyWith(
      visibleMessageCount: (state.visibleMessageCount + 10).clamp(
        0,
        state.totalVisibleMessagesCount,
      ),
    );
  }

  Future<void> createSession(String name) async {
    final sessionId = const Uuid().v4();
    final session = AiSession(
      id: sessionId,
      name: name,
      packageName: packageName,
      lastUpdateTime: DateTime.now(),
      lastMessage: '',
    );

    final updatedSessions = [session, ...state.sessions];
    await ref
        .read(aiChatActionRepositoryProvider)
        .saveSessions(packageName, updatedSessions);

    state = state.copyWith(
      currentSessionId: sessionId,
      sessions: List<AiSession>.unmodifiable(updatedSessions),
      protocolMessages: const [],
      messages: const [],
      visibleMessageCount: 10,
      error: null,
      isStreaming: false,
      lastResponseIssue: null,
    );

    await ref
        .read(aiChatActionRepositoryProvider)
        .saveLastActiveSessionId(packageName, sessionId);
    await _saveChatHistory();
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty || state.isStreaming) {
      return;
    }
    _stopRequested = false;

    if (state.currentSessionId == null) {
      await createSession(
        '新对话 ${DateTime.now().hour}:${DateTime.now().minute}',
      );
    }

    if (state.sessionInitState == AiSessionInitState.initializing) {
      state = state.copyWith(
        error: '逆向会话仍在初始化，请稍后再试。',
        lastResponseIssue: AiResponseIssue.toolInitError,
      );
      return;
    }

    if (state.sessionInitState == AiSessionInitState.failed) {
      state = state.copyWith(
        error: state.error ?? '逆向会话初始化失败，当前无法发送消息。',
        lastResponseIssue: AiResponseIssue.toolInitError,
      );
      return;
    }

    final config = ref.read(aiConfigProvider).value;
    if (config == null) {
      state = state.copyWith(error: 'AI 配置未加载', isStreaming: false);
      return;
    }

    final userMessage = AiMessage(
      id: const Uuid().v4(),
      role: 'user',
      content: text,
    );
    final placeholder = AiMessage(
      id: const Uuid().v4(),
      role: 'assistant',
      content: '',
    );

    final protocolMessages = [...state.protocolMessages, userMessage];
    final displayMessages = [...state.messages, userMessage, placeholder];
    state = state.copyWith(
      protocolMessages: List<AiMessage>.unmodifiable(protocolMessages),
      messages: List<AiMessage>.unmodifiable(displayMessages),
      isStreaming: true,
      error: null,
      lastResponseIssue: null,
    );

    try {
      _latestStreamingContent = '';
      await _runAssistantTurn(
        config: config,
        protocolMessages: protocolMessages,
        placeholderId: placeholder.id,
        toolsJson: _buildToolsJson(),
        retriesRemaining: 2,
      );
    } catch (error) {
      _markDisplayMessageError(
        placeholder.id,
        '发送失败：$error',
        AiResponseIssue.networkError,
      );
    }
  }

  Future<void> _runAssistantTurn({
    required AiConfig config,
    required List<AiMessage> protocolMessages,
    required String placeholderId,
    required int retriesRemaining,
    List<Map<String, dynamic>>? toolsJson,
  }) async {
    final preparedProtocolMessages = await _prepareProtocolMessages(
      protocolMessages,
      config,
    );
    final requestMessages = _buildRequestMessages(
      preparedProtocolMessages,
      config,
    );
    final response = await _collectAssistantResponse(
      config: config,
      requestMessages: requestMessages,
      toolsJson: toolsJson,
    );
    if (_isDisposed) {
      return;
    }

    if (response.issue == AiResponseIssue.emptyResponse &&
        retriesRemaining > 0) {
      await _runAssistantTurn(
        config: config,
        protocolMessages: preparedProtocolMessages,
        placeholderId: placeholderId,
        retriesRemaining: retriesRemaining - 1,
        toolsJson: toolsJson,
      );
      return;
    }

    if (response.issue == AiResponseIssue.emptyResponse) {
      _markDisplayMessageError(
        placeholderId,
        'AI 未返回有效内容，请稍后重试。',
        AiResponseIssue.emptyResponse,
      );
      return;
    }

    if (response.issue == AiResponseIssue.parseError) {
      _markDisplayMessageError(
        placeholderId,
        response.errorMessage ?? 'AI 响应格式异常。',
        AiResponseIssue.parseError,
      );
      return;
    }

    if (response.issue == AiResponseIssue.networkError) {
      _markDisplayMessageError(
        placeholderId,
        response.errorMessage ?? 'AI 请求失败。',
        AiResponseIssue.networkError,
      );
      return;
    }

    if (response.issue == AiResponseIssue.partialResponse) {
      final partialContent = response.content.isEmpty
          ? (response.errorMessage ?? 'AI 响应中断，内容可能不完整。')
          : response.content;
      _updateDisplayMessage(
        placeholderId,
        content: partialContent,
        isError: true,
      );
      state = state.copyWith(
        isStreaming: false,
        error: response.errorMessage ?? 'AI 响应中断，内容可能不完整。',
        lastResponseIssue: AiResponseIssue.partialResponse,
      );
      await _saveChatHistory();
      return;
    }

    if (response.toolCalls != null && response.toolCalls!.isNotEmpty) {
      await _handleToolCalls(
        config: config,
        protocolMessages: preparedProtocolMessages,
        placeholderId: placeholderId,
        initialContent: response.content,
        toolCalls: response.toolCalls!,
        toolsJson: toolsJson,
      );
      return;
    }

    _finishAssistantMessage(
      placeholderId,
      response.content,
      protocolMessages: [
        ...preparedProtocolMessages,
        AiMessage(
          id: const Uuid().v4(),
          role: 'assistant',
          content: response.content,
        ),
      ],
    );
  }

  Future<void> _handleToolCalls({
    required AiConfig config,
    required List<AiMessage> protocolMessages,
    required String placeholderId,
    required List<Map<String, dynamic>> toolCalls,
    required String initialContent,
    List<Map<String, dynamic>>? toolsJson,
  }) async {
    final toolExecutor = _getToolExecutor();
    if (toolExecutor == null) {
      _markDisplayMessageError(
        placeholderId,
        '逆向会话未初始化完成，无法执行工具调用。',
        AiResponseIssue.toolInitError,
      );
      return;
    }

    final assistantToolMessage = AiMessage(
      id: const Uuid().v4(),
      role: 'assistant',
      content: initialContent,
      toolCalls: toolCalls,
    );
    var nextProtocolMessages = [...protocolMessages, assistantToolMessage];
    state = state.copyWith(
      protocolMessages: List<AiMessage>.unmodifiable(nextProtocolMessages),
    );

    if (initialContent.isNotEmpty) {
      _updateDisplayMessage(placeholderId, content: initialContent);
    } else {
      _removeDisplayMessage(placeholderId);
    }

    final parsedCalls = toolCalls
        .map(AiToolCall.fromJson)
        .toList(growable: false);
    for (final call in parsedCalls) {
      if (_stopRequested) {
        state = state.copyWith(
          isStreaming: false,
          error: '已停止生成。',
          lastResponseIssue: AiResponseIssue.partialResponse,
        );
        await _saveChatHistory();
        return;
      }

      final bubbleId = const Uuid().v4();
      _appendDisplayMessage(
        AiMessage(
          id: bubbleId,
          role: 'assistant',
          content:
              '调用 `${call.name}`${call.arguments.isNotEmpty ? '(${call.arguments.entries.map((entry) => '${entry.key}: ${entry.value}').join(', ')})' : ''}...',
          isToolResultBubble: true,
        ),
      );

      final result = await toolExecutor.execute(call);
      _updateDisplayMessage(
        bubbleId,
        content:
            '${result.success ? '✅' : '❌'} `${call.name}`:\n\n${result.content}',
      );

      if (_stopRequested) {
        state = state.copyWith(
          isStreaming: false,
          error: '已停止生成。',
          lastResponseIssue: AiResponseIssue.partialResponse,
        );
        await _saveChatHistory();
        return;
      }

      nextProtocolMessages = [
        ...state.protocolMessages,
        AiMessage.toolResult(
          toolCallId: result.toolCallId,
          content: _buildToolResultProtocolSummary(
            call: call,
            content: result.content,
            success: result.success,
          ),
        ),
      ];
      state = state.copyWith(
        protocolMessages: List<AiMessage>.unmodifiable(nextProtocolMessages),
      );

      if (!result.success && _isCriticalTool(call.name)) {
        final errorMessage = AiMessage(
          id: const Uuid().v4(),
          role: 'assistant',
          content: '关键工具 `${call.name}` 执行失败，无法继续分析。',
          isError: true,
        );
        _appendDisplayMessage(errorMessage);
        state = state.copyWith(
          isStreaming: false,
          error: errorMessage.content,
          lastResponseIssue: AiResponseIssue.toolInitError,
        );
        await _saveChatHistory();
        return;
      }
    }

    await _saveChatHistory();

    if (_stopRequested) {
      state = state.copyWith(
        isStreaming: false,
        error: '已停止生成。',
        lastResponseIssue: AiResponseIssue.partialResponse,
      );
      return;
    }

    final newPlaceholder = AiMessage(
      id: const Uuid().v4(),
      role: 'assistant',
      content: '',
    );
    _appendDisplayMessage(newPlaceholder);

    await _runAssistantTurn(
      config: config,
      protocolMessages: state.protocolMessages,
      placeholderId: newPlaceholder.id,
      retriesRemaining: 2,
      toolsJson: toolsJson,
    );
  }

  Future<_CollectedAssistantResponse> _collectAssistantResponse({
    required AiConfig config,
    required List<AiMessage> requestMessages,
    List<Map<String, dynamic>>? toolsJson,
  }) async {
    final stream = ref
        .read(aiChatActionRepositoryProvider)
        .getChatStream(
          config: config,
          messages: requestMessages,
          tools: toolsJson,
        );

    final contentBuffer = StringBuffer();
    List<Map<String, dynamic>>? toolCalls;
    var sawChunk = false;
    final completer = Completer<_CollectedAssistantResponse>();
    _activeResponseCompleter = completer;
    _latestStreamingContent = '';

    try {
      _activeResponseSubscription = stream.listen(
        (chunk) {
          if (_isDisposed) {
            return;
          }

          sawChunk = true;
          if (chunk.hasToolCalls) {
            toolCalls = chunk.toolCalls;
            return;
          }

          if (chunk.content.isNotEmpty) {
            contentBuffer.write(chunk.content);
            _latestStreamingContent = contentBuffer.toString();
            _pushStreamingContent(_latestStreamingContent);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (completer.isCompleted) {
            return;
          }

          final bufferedContent = contentBuffer.toString();
          if (error is PlatformException) {
            if (bufferedContent.isNotEmpty) {
              completer.complete(
                _CollectedAssistantResponse(
                  content: bufferedContent,
                  issue: AiResponseIssue.partialResponse,
                  errorMessage: _describePlatformException(error),
                ),
              );
              return;
            }
            completer.complete(
              _CollectedAssistantResponse(
                content: bufferedContent,
                issue: _classifyPlatformIssue(error),
                errorMessage: _describePlatformException(error),
              ),
            );
            return;
          }

          if (bufferedContent.isNotEmpty) {
            completer.complete(
              _CollectedAssistantResponse(
                content: bufferedContent,
                issue: AiResponseIssue.partialResponse,
                errorMessage: error.toString(),
              ),
            );
            return;
          }

          completer.complete(
            _CollectedAssistantResponse(
              content: '',
              issue: AiResponseIssue.networkError,
              errorMessage: error.toString(),
            ),
          );
        },
        onDone: () {
          if (completer.isCompleted) {
            return;
          }

          final fullContent = contentBuffer.toString();
          if (!sawChunk &&
              (toolCalls == null || (toolCalls?.isEmpty ?? true)) &&
              fullContent.isEmpty) {
            completer.complete(
              const _CollectedAssistantResponse(
                content: '',
                issue: AiResponseIssue.emptyResponse,
              ),
            );
            return;
          }

          if (fullContent.isEmpty &&
              (toolCalls == null || (toolCalls?.isEmpty ?? true))) {
            completer.complete(
              const _CollectedAssistantResponse(
                content: '',
                issue: AiResponseIssue.emptyResponse,
              ),
            );
            return;
          }

          completer.complete(
            _CollectedAssistantResponse(
              content: fullContent,
              toolCalls: toolCalls,
            ),
          );
        },
        cancelOnError: false,
      );

      return await completer.future;
    } finally {
      if (identical(_activeResponseCompleter, completer)) {
        _activeResponseCompleter = null;
      }
      _activeResponseSubscription = null;
      _latestStreamingContent = '';
    }
  }

  List<AiMessage> _buildRequestMessages(
    List<AiMessage> protocolMessages,
    AiConfig config,
  ) {
    final historyMessages = _selectProtocolWindow(protocolMessages, config);
    return [
      if (state.systemPrompt != null && state.systemPrompt!.isNotEmpty)
        AiMessage(
          id: const Uuid().v4(),
          role: 'system',
          content: state.systemPrompt!,
        ),
      ...historyMessages,
    ];
  }

  List<AiMessage> _selectProtocolWindow(
    List<AiMessage> protocolMessages,
    AiConfig config,
  ) {
    final summaryMessage = _findLatestSessionSummary(protocolMessages);
    final workingMessages = protocolMessages
        .where((message) => !_isSessionSummary(message))
        .toList(growable: false);
    final maxRounds = config.memoryRounds <= 0
        ? 0
        : config.memoryRounds.toInt();
    if (maxRounds <= 0 || workingMessages.isEmpty) {
      return List<AiMessage>.unmodifiable([
        if (summaryMessage != null) summaryMessage,
        ...workingMessages,
      ]);
    }

    var userRounds = 0;
    var startIndex = 0;
    for (var index = workingMessages.length - 1; index >= 0; index--) {
      if (workingMessages[index].role == 'user') {
        userRounds++;
        if (userRounds >= maxRounds) {
          startIndex = index;
          break;
        }
      }
    }
    return List<AiMessage>.unmodifiable([
      if (summaryMessage != null) summaryMessage,
      ...workingMessages.sublist(startIndex),
    ]);
  }

  List<Map<String, dynamic>>? _buildToolsJson() {
    if (state.apkSessionId == null || state.apkSessionId!.isEmpty) {
      return null;
    }
    if (state.sessionInitState != AiSessionInitState.ready) {
      return null;
    }

    final isZh = state.systemPrompt?.contains('你是') ?? true;
    return PromptBuilder(isZh: isZh).withTools().withSoTools().buildToolsJson();
  }

  Future<void> retryByMessageId(String messageId) async {
    if (state.isStreaming) {
      return;
    }

    final displayIndex = state.messages.indexWhere(
      (message) => message.id == messageId,
    );
    if (displayIndex == -1) {
      return;
    }

    final displayMessage = state.messages[displayIndex];
    final isContinueEligible =
        displayMessage.role == 'assistant' &&
        displayMessage.isError &&
        state.lastResponseIssue == AiResponseIssue.partialResponse &&
        displayIndex == state.messages.length - 1 &&
        displayMessage.content.trim().isNotEmpty;
    if (isContinueEligible) {
      await _continueFromPartialMessage(
        displayMessage: displayMessage,
        displayIndex: displayIndex,
      );
      return;
    }

    String? retryText;
    if (displayMessage.role == 'user') {
      retryText = displayMessage.content;
    } else {
      for (var index = displayIndex - 1; index >= 0; index--) {
        final candidate = state.messages[index];
        if (candidate.role == 'user') {
          retryText = candidate.content;
          break;
        }
      }
    }

    if (retryText == null || retryText.trim().isEmpty) {
      return;
    }

    var retryUserDisplayIndex = displayIndex;
    if (displayMessage.role != 'user') {
      for (var index = displayIndex - 1; index >= 0; index--) {
        if (state.messages[index].role == 'user') {
          retryUserDisplayIndex = index;
          break;
        }
      }
    }

    var retryUserProtocolIndex = state.protocolMessages.length;
    for (var index = state.protocolMessages.length - 1; index >= 0; index--) {
      final candidate = state.protocolMessages[index];
      if (candidate.role == 'user' && candidate.content == retryText) {
        retryUserProtocolIndex = index;
        break;
      }
    }

    final nextDisplayMessages = retryUserDisplayIndex <= 0
        ? const <AiMessage>[]
        : List<AiMessage>.from(state.messages.sublist(0, retryUserDisplayIndex));
    final nextProtocolMessages = retryUserProtocolIndex <= 0
        ? const <AiMessage>[]
        : List<AiMessage>.from(
            state.protocolMessages.sublist(0, retryUserProtocolIndex),
          );

    state = state.copyWith(
      messages: List<AiMessage>.unmodifiable(nextDisplayMessages),
      protocolMessages: List<AiMessage>.unmodifiable(nextProtocolMessages),
      error: null,
      lastResponseIssue: null,
    );
    await send(retryText);
  }

  Future<void> _continueFromPartialMessage({
    required AiMessage displayMessage,
    required int displayIndex,
  }) async {
    final config = ref.read(aiConfigProvider).value;
    if (config == null) {
      state = state.copyWith(error: 'AI 配置未加载', isStreaming: false);
      return;
    }

    final partialContent = displayMessage.content.trim();
    final updatedMessages = List<AiMessage>.from(state.messages);
    updatedMessages[displayIndex] = updatedMessages[displayIndex].copyWith(
      isError: false,
    );
    state = state.copyWith(
      messages: List<AiMessage>.unmodifiable(updatedMessages),
      isStreaming: true,
      error: null,
      lastResponseIssue: null,
    );

    try {
      final preparedProtocolMessages = await _prepareProtocolMessages(
        state.protocolMessages,
        config,
      );
      final continuationProtocolMessages = _buildContinuationProtocolMessages(
        preparedProtocolMessages,
        partialContent,
      );
      final requestMessages = _buildRequestMessages(
        continuationProtocolMessages,
        config,
      );

      final response = await _collectAssistantResponse(
        config: config,
        requestMessages: requestMessages,
        toolsJson: _buildToolsJson(),
      );
      if (_isDisposed) {
        return;
      }

      if (response.issue == AiResponseIssue.emptyResponse) {
        _updateDisplayMessage(
          displayMessage.id,
          content: partialContent,
          isError: true,
        );
        state = state.copyWith(
          isStreaming: false,
          error: response.errorMessage ?? 'AI 未返回有效内容，请稍后重试。',
          lastResponseIssue: AiResponseIssue.emptyResponse,
        );
        await _saveChatHistory();
        return;
      }

      if (response.issue == AiResponseIssue.parseError) {
        _updateDisplayMessage(
          displayMessage.id,
          content: partialContent,
          isError: true,
        );
        state = state.copyWith(
          isStreaming: false,
          error: response.errorMessage ?? 'AI 响应格式异常。',
          lastResponseIssue: AiResponseIssue.parseError,
        );
        await _saveChatHistory();
        return;
      }

      if (response.issue == AiResponseIssue.networkError) {
        _updateDisplayMessage(
          displayMessage.id,
          content: partialContent,
          isError: true,
        );
        state = state.copyWith(
          isStreaming: false,
          error: response.errorMessage ?? 'AI 请求失败。',
          lastResponseIssue: AiResponseIssue.networkError,
        );
        await _saveChatHistory();
        return;
      }

      final mergedContent = _mergeContinuationContent(
        partialContent,
        response.content,
      );

      if (response.issue == AiResponseIssue.partialResponse) {
        _updateDisplayMessage(
          displayMessage.id,
          content: mergedContent,
          isError: true,
        );
        state = state.copyWith(
          isStreaming: false,
          error: response.errorMessage ?? 'AI 响应中断，内容可能不完整。',
          lastResponseIssue: AiResponseIssue.partialResponse,
        );
        await _saveChatHistory();
        return;
      }

      if (response.toolCalls != null && response.toolCalls!.isNotEmpty) {
        await _handleToolCalls(
          config: config,
          protocolMessages: preparedProtocolMessages,
          placeholderId: displayMessage.id,
          initialContent: response.content,
          toolCalls: response.toolCalls!,
          toolsJson: _buildToolsJson(),
        );
        return;
      }

      _updateDisplayMessage(
        displayMessage.id,
        content: mergedContent,
        isError: false,
      );
      state = state.copyWith(
        protocolMessages: List<AiMessage>.unmodifiable([
          ...preparedProtocolMessages,
          AiMessage(
            id: const Uuid().v4(),
            role: 'assistant',
            content: mergedContent,
          ),
        ]),
        isStreaming: false,
        error: null,
        lastResponseIssue: null,
      );
      await _saveChatHistory();
    } catch (_) {
      _markDisplayMessageError(
        displayMessage.id,
        partialContent,
        AiResponseIssue.networkError,
      );
    }
  }

  Future<void> retryLastTurn() async {
    if (state.isStreaming || !state.hasUserMessages) {
      return;
    }

    final lastUserMessage = state.messages.lastWhere(
      (message) => message.role == 'user',
    );
    await retryByMessageId(lastUserMessage.id);
  }

  Future<bool> compactContext() async {
    final config = ref.read(aiConfigProvider).value;
    if (config == null || state.protocolMessages.isEmpty) {
      return false;
    }

    final previousMessages = List<AiMessage>.from(state.protocolMessages);
    await _prepareProtocolMessages(
      state.protocolMessages,
      config,
      forceCompact: true,
    );
    return !_sameMessages(previousMessages, state.protocolMessages);
  }

  @Deprecated('Use retryByMessageId instead.')
  Future<void> retry(int index) async {
    final visibleMessages = state.visibleMessages;
    if (index < 0 || index >= visibleMessages.length) {
      return;
    }
    await retryByMessageId(visibleMessages[index].id);
  }

  Future<void> deleteSession(String sessionId) async {
    await ref
        .read(aiChatActionRepositoryProvider)
        .deleteSession(packageName, sessionId);

    final updatedSessions = List<AiSession>.from(state.sessions)
      ..removeWhere((session) => session.id == sessionId);
    await ref
        .read(aiChatActionRepositoryProvider)
        .saveSessions(packageName, updatedSessions);

    if (state.currentSessionId == sessionId) {
      if (updatedSessions.isNotEmpty) {
        state = state.copyWith(
          sessions: List<AiSession>.unmodifiable(updatedSessions),
        );
        await switchSession(updatedSessions.first.id);
      } else {
        state = state.copyWith(
          isStreaming: false,
          messages: const [],
          protocolMessages: const [],
          sessions: const [],
          currentSessionId: null,
        );
        await ref
            .read(aiChatActionRepositoryProvider)
            .clearLastActiveSessionId(packageName);
      }
    } else {
      state = state.copyWith(
        sessions: List<AiSession>.unmodifiable(updatedSessions),
      );
    }
  }

  void resetStreaming() {
    state = state.copyWith(isStreaming: false);
  }

  Future<void> stopStreaming() async {
    if (!state.isStreaming) {
      return;
    }

    _stopRequested = true;
    final partialContent = _latestStreamingContent;
    await _activeResponseSubscription?.cancel();
    _activeResponseSubscription = null;
    _clearStreamingContent();

    final completer = _activeResponseCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        _CollectedAssistantResponse(
          content: partialContent,
          issue: AiResponseIssue.partialResponse,
          errorMessage: '已停止生成。',
        ),
      );
    } else {
      _appendDisplayMessage(
        AiMessage(
          id: const Uuid().v4(),
          role: 'assistant',
          content: '已停止生成。',
          isError: true,
        ),
      );
      state = state.copyWith(
        isStreaming: false,
        error: '已停止生成。',
        lastResponseIssue: AiResponseIssue.partialResponse,
      );
    }
  }

  Future<String> testConnection(AiConfig config) {
    return ref.read(aiChatActionRepositoryProvider).testConnection(config);
  }

  Future<void> deleteHistory() async {
    if (state.currentSessionId != null) {
      await deleteSession(state.currentSessionId!);
    }
  }

  Future<void> clear() async {
    await createSession('新对话 ${DateTime.now().hour}:${DateTime.now().minute}');
  }

  Future<void> _saveChatHistory() async {
    final sessionId = state.currentSessionId;
    if (sessionId == null) {
      return;
    }

    try {
      await ref
          .read(aiChatActionRepositoryProvider)
          .saveChatHistory(packageName, sessionId, state.protocolMessages);

      final sessionIndex = state.sessions.indexWhere(
        (session) => session.id == sessionId,
      );
      if (sessionIndex == -1) {
        return;
      }

      const lastMessage = '';
      final updatedSessions = List<AiSession>.from(state.sessions);
      updatedSessions[sessionIndex] = updatedSessions[sessionIndex].copyWith(
        lastUpdateTime: DateTime.now(),
        lastMessage: lastMessage,
      );
      state = state.copyWith(
        sessions: List<AiSession>.unmodifiable(updatedSessions),
      );
      await ref
          .read(aiChatActionRepositoryProvider)
          .saveSessions(packageName, updatedSessions);
    } catch (_) {
      // Keep UI responsive even if persistence fails.
    }
  }

  List<AiMessage> _buildDisplayMessagesFromProtocol(
    List<AiMessage> protocolMessages,
  ) {
    return protocolMessages
        .where((message) => message.shouldDisplayInChatList)
        .toList(growable: false);
  }

  Future<List<AiMessage>> _prepareProtocolMessages(
    List<AiMessage> protocolMessages,
    AiConfig config, {
    bool forceCompact = false,
  }) async {
    final sanitizedMessages = _sanitizeProtocolMessages(protocolMessages);
    final shouldCompact =
        forceCompact ||
        _estimateProtocolSize(sanitizedMessages) > _contextHardBudgetChars;
    if (!shouldCompact) {
      if (!_sameMessages(protocolMessages, sanitizedMessages)) {
        state = state.copyWith(
          protocolMessages: List<AiMessage>.unmodifiable(sanitizedMessages),
        );
        await _saveChatHistory();
      }
      return sanitizedMessages;
    }

    final compactedMessages = _compactProtocolMessages(sanitizedMessages);
    if (_sameMessages(protocolMessages, compactedMessages)) {
      return compactedMessages;
    }

    state = state.copyWith(
      protocolMessages: List<AiMessage>.unmodifiable(compactedMessages),
    );
    await _saveChatHistory();
    return compactedMessages;
  }

  List<AiMessage> _sanitizeProtocolMessages(List<AiMessage> protocolMessages) {
    final latestSummary = _findLatestSessionSummary(protocolMessages);
    final sanitized = <AiMessage>[
      if (latestSummary != null) latestSummary,
    ];
    final pendingToolCallIds = <String>{};
    var awaitingToolResults = false;

    for (final message in protocolMessages) {
      if (_isSessionSummary(message)) {
        continue;
      }
      if (message.role == 'assistant') {
        pendingToolCallIds
          ..clear()
          ..addAll(_extractToolCallIds(message.toolCalls));
        awaitingToolResults = message.hasToolCalls;
        sanitized.add(message);
        continue;
      }
      if (message.role == 'tool') {
        if (!awaitingToolResults) {
          continue;
        }
        final toolCallId = message.toolCallId;
        if (pendingToolCallIds.isNotEmpty) {
          if (toolCallId == null || !pendingToolCallIds.remove(toolCallId)) {
            continue;
          }
          if (pendingToolCallIds.isEmpty) {
            awaitingToolResults = false;
          }
        }
        sanitized.add(
          message.copyWith(
            content: _summarizeToolProtocolContent(message.content),
          ),
        );
      } else {
        pendingToolCallIds.clear();
        awaitingToolResults = false;
        sanitized.add(message);
      }
    }
    return List<AiMessage>.unmodifiable(sanitized);
  }

  List<AiMessage> _compactProtocolMessages(List<AiMessage> protocolMessages) {
    final latestSummary = _findLatestSessionSummary(protocolMessages);
    final workingMessages = protocolMessages
        .where((message) => !_isSessionSummary(message))
        .toList(growable: false);
    if (workingMessages.isEmpty) {
      return latestSummary == null ? workingMessages : [latestSummary];
    }

    final recentMessages = _selectRecentMessagesForCompaction(workingMessages);
    final cutoffIndex = workingMessages.length - recentMessages.length;
    final olderMessages = workingMessages.sublist(0, cutoffIndex);
    if (olderMessages.isEmpty) {
      return List<AiMessage>.unmodifiable([
        if (latestSummary != null) latestSummary,
        ...workingMessages,
      ]);
    }

    final mergedSummary = _mergeSessionSummary(
      existingSummary: latestSummary?.content,
      olderMessages: olderMessages,
    );
    final compacted = <AiMessage>[
      AiMessage(
        id: latestSummary?.id ?? const Uuid().v4(),
        role: 'system',
        content: mergedSummary,
      ),
      ...recentMessages,
    ];

    while (_estimateProtocolSize(compacted) > _contextTargetBudgetChars &&
        compacted.length > 2) {
      compacted.removeAt(1);
    }

    return List<AiMessage>.unmodifiable(compacted);
  }

  List<AiMessage> _selectRecentMessagesForCompaction(
    List<AiMessage> protocolMessages,
  ) {
    var userRounds = 0;
    var startIndex = 0;
    for (var index = protocolMessages.length - 1; index >= 0; index--) {
      if (protocolMessages[index].role == 'user') {
        userRounds++;
        if (userRounds >= _recentUserRoundsToKeep) {
          startIndex = index;
          break;
        }
      }
    }
    return List<AiMessage>.from(protocolMessages.sublist(startIndex));
  }

  String _mergeSessionSummary({
    String? existingSummary,
    required List<AiMessage> olderMessages,
  }) {
    final sections = _parseSessionSummarySections(existingSummary);
    final pendingNotes = <String>[];

    for (final message in olderMessages) {
      if (message.content.trim().isEmpty) {
        continue;
      }
      final normalized = _truncateForSummary(
        message.content.replaceAll('\r', ' ').replaceAll('\n', ' ').trim(),
      );
      if (normalized.isEmpty) {
        continue;
      }
      if (message.role == 'user') {
        _addUniqueNote(sections.userNeeds, normalized);
        if (_looksLikeQuestion(normalized)) {
          _addUniqueNote(pendingNotes, normalized);
        }
      } else if (message.role == 'tool') {
        _addUniqueNote(sections.toolFindings, normalized);
      } else if (message.role == 'assistant' && !message.hasToolCalls) {
        _addUniqueNote(sections.knownConclusions, normalized);
      }
    }

    final buffer = StringBuffer(_sessionSummaryPrefix);
    _writeSummarySection(
      buffer,
      title: '历史诉求',
      notes: sections.userNeeds.take(6),
    );
    _writeSummarySection(
      buffer,
      title: '已知结论',
      notes: sections.knownConclusions.take(6),
    );
    _writeSummarySection(
      buffer,
      title: '工具发现',
      notes: sections.toolFindings.take(8),
    );

    final unresolved = pendingNotes.where(
      (note) =>
          !sections.knownConclusions.any((item) => item.contains(note)) &&
          !sections.toolFindings.any((item) => item.contains(note)),
    );
    for (final note in unresolved.take(4)) {
      _addUniqueNote(sections.nextSteps, note);
    }
    _writeSummarySection(
      buffer,
      title: '待继续',
      notes: sections.nextSteps.take(4),
    );
    return buffer.toString().trim();
  }

  String _buildToolResultProtocolSummary({
    required AiToolCall call,
    required String content,
    required bool success,
  }) {
    final argumentSummary = call.arguments.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');
    final resultSummary = _summarizeToolProtocolContent(content);
    return '${success ? 'success' : 'failure'} ${call.name}'
        '${argumentSummary.isEmpty ? '' : ' ($argumentSummary)'}\n$resultSummary';
  }

  String _summarizeToolProtocolContent(String content) {
    final cleaned = content.trim();
    if (cleaned.isEmpty) {
      return '';
    }
    final lines = cleaned
        .replaceAll('\r', '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return '';
    }

    final summary = lines.take(8).join('\n');
    if (summary.length <= _toolResultProtocolMaxChars) {
      return summary;
    }
    return '${summary.substring(0, _toolResultProtocolMaxChars)}...';
  }

  int _estimateProtocolSize(List<AiMessage> messages) {
    var total = state.systemPrompt?.length ?? 0;
    for (final message in messages) {
      total += message.role.length;
      total += message.content.length;
      if (message.toolCalls != null) {
        total += message.toolCalls.toString().length;
      }
    }
    return total;
  }

  AiMessage? _findLatestSessionSummary(List<AiMessage> messages) {
    for (var index = messages.length - 1; index >= 0; index--) {
      if (_isSessionSummary(messages[index])) {
        return messages[index];
      }
    }
    return null;
  }

  bool _isSessionSummary(AiMessage message) {
    return message.role == 'system' &&
        message.content.startsWith(_sessionSummaryPrefix);
  }

  String _stripSessionSummaryPrefix(String content) {
    return content.replaceFirst(_sessionSummaryPrefix, '').trim();
  }

  String _truncateForSummary(String text) {
    if (text.length <= 180) {
      return text;
    }
    return '${text.substring(0, 180)}...';
  }

  String _buildContinuationPrompt(String partialContent) {
    return '你上一条回答因为网络中断未完成。请从中断处继续，不要重复已经输出的内容。'
        '如果必须衔接，请只补充后续部分。\n\n'
        '已输出内容如下：\n$partialContent';
  }

  List<String> _extractToolCallIds(List<Map<String, dynamic>>? toolCalls) {
    if (toolCalls == null || toolCalls.isEmpty) {
      return const [];
    }
    return toolCalls
        .map((toolCall) => toolCall['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  bool _endsWithToolContext(List<AiMessage> protocolMessages) {
    for (var index = protocolMessages.length - 1; index >= 0; index--) {
      final message = protocolMessages[index];
      if (message.role == 'tool') {
        return true;
      }
      if (message.role == 'assistant' && message.hasToolCalls) {
        return true;
      }
      if (message.role == 'assistant' || message.role == 'user') {
        return false;
      }
    }
    return false;
  }

  List<AiMessage> _buildContinuationProtocolMessages(
    List<AiMessage> protocolMessages,
    String partialContent,
  ) {
    if (_endsWithToolContext(protocolMessages)) {
      return protocolMessages;
    }

    final updatedMessages = List<AiMessage>.from(protocolMessages);
    for (var index = updatedMessages.length - 1; index >= 0; index--) {
      final candidate = updatedMessages[index];
      if (candidate.role != 'user') {
        continue;
      }
      updatedMessages[index] = candidate.copyWith(
        content: '${candidate.content}\n\n${_buildContinuationPrompt(partialContent)}',
      );
      return List<AiMessage>.unmodifiable(updatedMessages);
    }
    return List<AiMessage>.unmodifiable(updatedMessages);
  }

  String _describePlatformException(PlatformException error) {
    final message = error.message?.trim();
    final details = error.details;
    if (details == null) {
      return message == null || message.isEmpty ? error.code : message;
    }

    String detailText;
    if (details is String) {
      detailText = details.trim();
    } else {
      detailText = details.toString().trim();
    }

    if (detailText.isEmpty) {
      return message == null || message.isEmpty ? error.code : message;
    }
    if (message == null || message.isEmpty) {
      return detailText;
    }
    return '$message\n$detailText';
  }

  String _mergeContinuationContent(String existing, String continuation) {
    final previous = existing.trimRight();
    final next = continuation.trimLeft();
    if (next.isEmpty) {
      return previous;
    }
    if (previous.isEmpty) {
      return next;
    }
    if (next.startsWith(previous)) {
      return next;
    }

    final maxOverlap = previous.length < next.length
        ? previous.length
        : next.length;
    for (var overlap = maxOverlap; overlap >= 8; overlap--) {
      final previousSuffix = previous.substring(previous.length - overlap);
      final nextPrefix = next.substring(0, overlap);
      if (previousSuffix == nextPrefix) {
        return '$previous${next.substring(overlap)}';
      }
    }

    return '$previous$next';
  }

  _SessionSummarySections _parseSessionSummarySections(String? summary) {
    final sections = _SessionSummarySections();
    if (summary == null || summary.isEmpty) {
      return sections;
    }

    String? currentTitle;
    final lines = _stripSessionSummaryPrefix(summary)
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    for (final line in lines) {
      if (line.endsWith('：')) {
        currentTitle = line.substring(0, line.length - 1);
        continue;
      }
      if (!line.startsWith('- ')) {
        continue;
      }
      final note = line.substring(2).trim();
      if (note.isEmpty) {
        continue;
      }

      switch (currentTitle) {
        case '历史诉求':
          _addUniqueNote(sections.userNeeds, note);
          break;
        case '已知结论':
          _addUniqueNote(sections.knownConclusions, note);
          break;
        case '工具发现':
          _addUniqueNote(sections.toolFindings, note);
          break;
        case '待继续':
          _addUniqueNote(sections.nextSteps, note);
          break;
        default:
          _addUniqueNote(sections.knownConclusions, note);
          break;
      }
    }

    return sections;
  }

  void _writeSummarySection(
    StringBuffer buffer, {
    required String title,
    required Iterable<String> notes,
  }) {
    final items = notes
        .map((note) => note.trim())
        .where((note) => note.isNotEmpty)
        .toList(growable: false);
    if (items.isEmpty) {
      return;
    }

    buffer
      ..writeln()
      ..writeln('$title：');
    for (final note in items) {
      buffer.writeln('- $note');
    }
  }

  void _addUniqueNote(List<String> notes, String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (notes.any((item) => item == normalized)) {
      return;
    }
    notes.add(normalized);
  }

  bool _looksLikeQuestion(String text) {
    return text.contains('?') ||
        text.contains('？') ||
        text.startsWith('请') ||
        text.startsWith('分析') ||
        text.startsWith('找') ||
        text.startsWith('定位');
  }

  bool _sameMessages(List<AiMessage> left, List<AiMessage> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      final a = left[index];
      final b = right[index];
      if (a.role != b.role ||
          a.content != b.content ||
          a.isError != b.isError ||
          a.toolCallId != b.toolCallId ||
          a.isToolResultBubble != b.isToolResultBubble) {
        return false;
      }
    }
    return true;
  }

  ToolExecutor? _getToolExecutor() {
    final sessionId = state.apkSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return null;
    }

    return ToolExecutor(
      repo: ref.read(apkAnalysisQueryRepositoryProvider),
      soDataSource: ref.read(soAnalysisDatasourceProvider),
      sessionId: sessionId,
      dexPaths: state.dexPaths,
    );
  }

  bool _isCriticalTool(String toolName) {
    return const {'get_manifest'}.contains(toolName);
  }

  void _finishAssistantMessage(
    String placeholderId,
    String content, {
    required List<AiMessage> protocolMessages,
  }) {
    _updateDisplayMessage(placeholderId, content: content, isError: false);
    state = state.copyWith(
      protocolMessages: List<AiMessage>.unmodifiable(protocolMessages),
      isStreaming: false,
      error: null,
      lastResponseIssue: null,
    );
    _saveChatHistory();
  }

  void _markDisplayMessageError(
    String placeholderId,
    String message,
    AiResponseIssue issue,
  ) {
    _updateDisplayMessage(placeholderId, content: message, isError: true);
    state = state.copyWith(
      isStreaming: false,
      error: message,
      lastResponseIssue: issue,
    );
    _saveChatHistory();
  }

  void _appendDisplayMessage(AiMessage message) {
    state = state.copyWith(
      messages: List<AiMessage>.unmodifiable([...state.messages, message]),
    );
  }

  void _removeDisplayMessage(String messageId) {
    final updatedMessages = List<AiMessage>.from(state.messages)
      ..removeWhere((message) => message.id == messageId);
    state = state.copyWith(
      messages: List<AiMessage>.unmodifiable(updatedMessages),
    );
  }

  void _updateDisplayMessage(
    String messageId, {
    required String content,
    bool? isError,
  }) {
    final updatedMessages = List<AiMessage>.from(state.messages);
    final index = updatedMessages.indexWhere(
      (message) => message.id == messageId,
    );
    if (index == -1) {
      return;
    }

    updatedMessages[index] = updatedMessages[index].copyWith(
      content: content,
      isError: isError ?? updatedMessages[index].isError,
    );
    state = state.copyWith(
      messages: List<AiMessage>.unmodifiable(updatedMessages),
    );
  }

  void _pushStreamingContent(String content) {
    if (_streamingContentController.isClosed) {
      return;
    }
    _streamingContentController.add(content);
  }

  void _clearStreamingContent() {
    if (_streamingContentController.isClosed) {
      return;
    }
    _streamingContentController.add('');
  }

  AiResponseIssue _classifyPlatformIssue(PlatformException error) {
    final code = error.code.toLowerCase();
    if (code.contains('parse')) {
      return AiResponseIssue.parseError;
    }
    return AiResponseIssue.networkError;
  }
}

class _SessionSummarySections {
  final List<String> userNeeds = [];
  final List<String> knownConclusions = [];
  final List<String> toolFindings = [];
  final List<String> nextSteps = [];
}

class _CollectedAssistantResponse {
  const _CollectedAssistantResponse({
    required this.content,
    this.toolCalls,
    this.issue,
    this.errorMessage,
  });

  final String content;
  final List<Map<String, dynamic>>? toolCalls;
  final AiResponseIssue? issue;
  final String? errorMessage;
}
