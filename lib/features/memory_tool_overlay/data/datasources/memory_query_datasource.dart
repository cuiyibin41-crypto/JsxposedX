import 'package:JsxposedX/generated/memory_tool.g.dart';

class MemoryQueryDatasource {
  final _native = MemoryToolNative();

  Future<int> getPid({required String packageName}) async {
    return await _native.getPid(packageName: packageName);
  }

  Future<List<ProcessInfo>> getProcessInfo({
    required int offset,
    required int limit,
  }) async {
    return await _native.getProcessInfo(offset, limit);
  }

  Future<List<MemoryRegion>> getMemoryRegions({
    required MemoryRegionQuery query,
  }) async {
    return await _native.getMemoryRegions(query);
  }

  Future<SearchSessionState> getSearchSessionState() async {
    return await _native.getSearchSessionState();
  }

  Future<SearchTaskState> getSearchTaskState() async {
    return await _native.getSearchTaskState();
  }

  Future<List<SearchResult>> getSearchResults({
    required int offset,
    required int limit,
  }) async {
    return await _native.getSearchResults(offset, limit);
  }

  Future<List<MemoryValuePreview>> readMemoryValues({
    required List<MemoryReadRequest> requests,
  }) async {
    return await _native.readMemoryValues(requests);
  }
}
