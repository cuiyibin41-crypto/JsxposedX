import 'package:JsxposedX/generated/memory_tool.g.dart';

class MemoryActionDatasource {
  final _native = MemoryToolNative();

  Future<void> firstScan({required FirstScanRequest request}) async {
    await _native.firstScan(request);
  }

  Future<void> nextScan({required NextScanRequest request}) async {
    await _native.nextScan(request);
  }

  Future<void> cancelSearch() async {
    await _native.cancelSearch();
  }

  Future<void> resetSearchSession() async {
    await _native.resetSearchSession();
  }
}
