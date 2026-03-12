// ignore_for_file: invalid_annotation_target

import 'package:JsxposedX/core/models/ai_message.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'ai_message_dto.freezed.dart';
part 'ai_message_dto.g.dart';

@freezed
abstract class AiMessageDto with _$AiMessageDto {
  const AiMessageDto._();

  const factory AiMessageDto({
    @JsonKey(includeFromJson: false, includeToJson: false) String? id,
    @Default("user") String role,
    @Default("") String content,
    @JsonKey(name: 'tool_calls', includeIfNull: false)
    List<Map<String, dynamic>>? toolCalls,
    @JsonKey(name: 'tool_call_id', includeIfNull: false) String? toolCallId,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(false)
    bool isError,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(false)
    bool isToolResultBubble,
  }) = _AiMessageDto;

  factory AiMessageDto.fromJson(Map<String, dynamic> json) =>
      _$AiMessageDtoFromJson(json);

  factory AiMessageDto.fromStorageJson(Map<String, dynamic> json) {
    final rawToolCalls = json['tool_calls'] as List?;

    return AiMessageDto(
      id: json['id'] as String?,
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      toolCalls: rawToolCalls
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      toolCallId: json['tool_call_id'] as String?,
      isError: json['is_error'] == true,
      isToolResultBubble: json['is_tool_result_bubble'] == true,
    );
  }

  Map<String, dynamic> toStorageJson() {
    return {
      if (id != null && id!.isNotEmpty) 'id': id,
      'role': role,
      'content': content,
      if (toolCalls != null) 'tool_calls': toolCalls,
      if (toolCallId != null) 'tool_call_id': toolCallId,
      'is_error': isError,
      'is_tool_result_bubble': isToolResultBubble,
    };
  }

  AiMessage toEntity() {
    return AiMessage(
      id: id != null && id!.isNotEmpty ? id! : const Uuid().v4(),
      role: role,
      content: content,
      isError: isError,
      toolCalls: toolCalls,
      toolCallId: toolCallId,
      isToolResultBubble: isToolResultBubble,
    );
  }

  /// 是否包含工具调用
  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;

  /// 构建 tool 角色的消息
  factory AiMessageDto.toolResult({
    required String toolCallId,
    required String content,
  }) =>
      AiMessageDto(
        role: 'tool',
        content: content,
        toolCallId: toolCallId,
      );

  /// 构建 assistant 带 tool_calls 的消息
  factory AiMessageDto.assistantToolCalls(List<Map<String, dynamic>> calls) =>
      AiMessageDto(
        role: 'assistant',
        content: '',
        toolCalls: calls,
      );
}
