import 'package:JsxposedX/features/ai/domain/services/ai_chat_tool_catalog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/memory_ai_overlay_tool_definitions.dart';

class MemoryAiOverlayChatToolsSpec extends AiChatToolCatalog {
  static const String catalogVersion = 'memory_overlay_tools_v2';

  MemoryAiOverlayChatToolsSpec()
    : super(definitions: MemoryAiOverlayToolDefinitions.all);
}
