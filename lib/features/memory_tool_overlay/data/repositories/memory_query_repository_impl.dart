import 'package:JsxposedX/features/memory_tool_overlay/data/datasources/memory_query_datasource.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_query_repository.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';

class MemoryQueryRepositoryImpl implements MemoryQueryRepository {
  final MemoryQueryDatasource dataSource;

  MemoryQueryRepositoryImpl({required this.dataSource});

  @override
  Future<int> getPid({required String packageName}) async {
    return await dataSource.getPid(packageName: packageName);
  }

  @override
  Future<List<ProcessInfo>> getProcessInfo({
    required int offset,
    required int limit,
  }) async {
    return await dataSource.getProcessInfo(offset: offset, limit: limit);
  }

  @override
  Future<List<MemoryRegion>> getMemoryRegions({
    required int pid,
    required int offset,
    required int limit,
    required bool readableOnly,
    required bool includeAnonymous,
    required bool includeFileBacked,
  }) async {
    return await dataSource.getMemoryRegions(
      query: MemoryRegionQuery(
        pid: pid,
        offset: offset,
        limit: limit,
        readableOnly: readableOnly,
        includeAnonymous: includeAnonymous,
        includeFileBacked: includeFileBacked,
      ),
    );
  }

  @override
  Future<SearchSessionState> getSearchSessionState() async {
    return await dataSource.getSearchSessionState();
  }

  @override
  Future<SearchTaskState> getSearchTaskState() async {
    return await dataSource.getSearchTaskState();
  }

  @override
  Future<List<SearchResult>> getSearchResults({
    required int offset,
    required int limit,
  }) async {
    return await dataSource.getSearchResults(offset: offset, limit: limit);
  }

  @override
  Future<List<MemoryValuePreview>> readMemoryValues({
    required List<MemoryReadRequest> requests,
  }) async {
    return await dataSource.readMemoryValues(requests: requests);
  }
}
