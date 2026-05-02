import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:JsxposedX/core/enums/ai_api_type.dart';

part 'ai_config.freezed.dart';

@freezed
abstract class AiConfig with _$AiConfig {
  const AiConfig._(); // 私有构造函数，用于添加自定义方法

  const factory AiConfig({
    required String id,
    required String name,
    required String apiKey,
    required String apiUrl,
    required String moduleName,
    required int maxToken,
    required double temperature,
    required double memoryRounds,
    required AiApiType apiType,
  }) = _AiConfig;

  /// 获取完整的 API URL（自动拼接路径）
  String get fullApiUrl {
  final baseUrl = apiUrl.endsWith('/') ? apiUrl.substring(0, apiUrl.length - 1) : apiUrl;

  // 智谱API特判，保证拼接不出错
  if (id.contains('zhipu') || baseUrl.contains('bigmodel.cn')) {
    if (baseUrl.endsWith('/chat/completions')) return baseUrl;
    return '$baseUrl/chat/completions';
  }

  switch (apiType) {
    case AiApiType.openai:
      // OpenAI 格式：/v1/chat/completions
      // 如果已经包含完整路径，直接返回
      if (baseUrl.contains('/chat/completions')) {
        return baseUrl;
      }
      // 如果只有 /v1，添加 /chat/completions
      if (baseUrl.endsWith('/v1')) {
        return '$baseUrl/chat/completions';
      }
      // 否则添加完整路径
      return '$baseUrl/v1/chat/completions';

    case AiApiType.openaiResponses:
      // OpenAI Responses 格式：/v1/responses
      if (baseUrl.contains('/responses')) {
        return baseUrl;
      }
      if (baseUrl.endsWith('/v1')) {
        return '$baseUrl/responses';
      }
      return '$baseUrl/v1/responses';

    case AiApiType.anthropic:
      // Anthropic Claude 格式：/v1/messages
      if (baseUrl.contains('/messages')) {
        return baseUrl;
      }
      if (baseUrl.endsWith('/v1')) {
        return '$baseUrl/messages';
      }
      return '$baseUrl/v1/messages';
  }
  }
