import 'package:JsxposedX/generated/memory_tool.g.dart';

abstract class MemoryPointerQueryRepository {
  Future<PointerScanSessionState> getPointerScanSessionState();

  Future<PointerScanTaskState> getPointerScanTaskState();

  Future<List<PointerScanResult>> getPointerScanResults({
    required int offset,
    required int limit,
  });
}
