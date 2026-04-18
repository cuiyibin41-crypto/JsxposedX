import 'package:JsxposedX/generated/memory_tool.g.dart';

class MemoryPointerQueryDatasource {
  final _native = MemoryToolNative();

  Future<PointerScanSessionState> getPointerScanSessionState() async {
    return await _native.getPointerScanSessionState();
  }

  Future<PointerScanTaskState> getPointerScanTaskState() async {
    return await _native.getPointerScanTaskState();
  }

  Future<List<PointerScanResult>> getPointerScanResults({
    required int offset,
    required int limit,
  }) async {
    return await _native.getPointerScanResults(offset, limit);
  }
}
