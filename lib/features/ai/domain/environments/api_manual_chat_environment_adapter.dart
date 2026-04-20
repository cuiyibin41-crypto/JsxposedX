import 'package:JsxposedX/features/ai/domain/contracts/ai_chat_environment_adapter.dart';
import 'package:JsxposedX/features/ai/domain/models/ai_chat_environment_snapshot.dart';

class ApiManualChatEnvironmentAdapter implements AiChatEnvironmentAdapter {
  const ApiManualChatEnvironmentAdapter({
    required this.scopeId,
    required this.systemPrompt,
  });

  @override
  final String scopeId;

  final String systemPrompt;

  @override
  String get environmentVersion => 'api_manual:${systemPrompt.hashCode}';

  @override
  Future<AiChatEnvironmentSnapshot> initialize() async {
    return AiChatEnvironmentSnapshot.ready(
      scopeId: scopeId,
      environmentVersion: environmentVersion,
      systemPrompt: systemPrompt,
    );
  }

  @override
  Future<void> dispose() async {}
}
