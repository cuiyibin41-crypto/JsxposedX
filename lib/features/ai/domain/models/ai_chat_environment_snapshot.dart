import 'package:JsxposedX/features/ai/domain/contracts/ai_chat_tool_executor_contract.dart';
import 'package:JsxposedX/features/ai/domain/contracts/ai_chat_tools_spec.dart';
import 'package:JsxposedX/features/ai/domain/models/ai_session_init_state.dart';

class AiChatEnvironmentSnapshot {
  const AiChatEnvironmentSnapshot({
    required this.scopeId,
    required this.environmentVersion,
    required this.systemPrompt,
    required this.sessionInitState,
    this.error,
    this.toolsSpec,
    this.toolExecutor,
  });

  final String scopeId;
  final String environmentVersion;
  final String systemPrompt;
  final AiSessionInitState sessionInitState;
  final String? error;
  final AiChatToolsSpec? toolsSpec;
  final AiChatToolExecutorContract? toolExecutor;

  factory AiChatEnvironmentSnapshot.ready({
    required String scopeId,
    required String environmentVersion,
    required String systemPrompt,
    AiChatToolsSpec? toolsSpec,
    AiChatToolExecutorContract? toolExecutor,
  }) {
    return AiChatEnvironmentSnapshot(
      scopeId: scopeId,
      environmentVersion: environmentVersion,
      systemPrompt: systemPrompt,
      sessionInitState: AiSessionInitState.ready,
      toolsSpec: toolsSpec,
      toolExecutor: toolExecutor,
    );
  }

  factory AiChatEnvironmentSnapshot.initializing({
    required String scopeId,
    required String environmentVersion,
    String systemPrompt = '',
  }) {
    return AiChatEnvironmentSnapshot(
      scopeId: scopeId,
      environmentVersion: environmentVersion,
      systemPrompt: systemPrompt,
      sessionInitState: AiSessionInitState.initializing,
    );
  }

  factory AiChatEnvironmentSnapshot.failed({
    required String scopeId,
    required String environmentVersion,
    required String error,
    String systemPrompt = '',
  }) {
    return AiChatEnvironmentSnapshot(
      scopeId: scopeId,
      environmentVersion: environmentVersion,
      systemPrompt: systemPrompt,
      sessionInitState: AiSessionInitState.failed,
      error: error,
    );
  }
}
