import 'package:JsxposedX/generated/memory_tool.g.dart';

abstract class MemoryPointerActionRepository {
  Future<void> startPointerScan({required PointerScanRequest request});

  Future<void> cancelPointerScan();

  Future<void> resetPointerScanSession();
}
