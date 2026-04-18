import 'package:JsxposedX/features/memory_tool_overlay/data/datasources/memory_pointer_query_datasource.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_pointer_query_repository.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';

class MemoryPointerQueryRepositoryImpl implements MemoryPointerQueryRepository {
  MemoryPointerQueryRepositoryImpl({required this.dataSource});

  final MemoryPointerQueryDatasource dataSource;

  @override
  Future<PointerScanSessionState> getPointerScanSessionState() async {
    return await dataSource.getPointerScanSessionState();
  }

  @override
  Future<PointerScanTaskState> getPointerScanTaskState() async {
    return await dataSource.getPointerScanTaskState();
  }

  @override
  Future<List<PointerScanResult>> getPointerScanResults({
    required int offset,
    required int limit,
  }) async {
    return await dataSource.getPointerScanResults(
      offset: offset,
      limit: limit,
    );
  }
}
