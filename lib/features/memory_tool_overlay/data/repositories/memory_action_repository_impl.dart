import 'package:JsxposedX/features/memory_tool_overlay/data/datasources/memory_action_datasource.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_action_repository.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';

class MemoryActionRepositoryImpl implements MemoryActionRepository {
  MemoryActionRepositoryImpl({required MemoryActionDatasource dataSource})
    : _dataSource = dataSource;

  final MemoryActionDatasource _dataSource;

  @override
  Future<void> firstScan({required FirstScanRequest request}) async {
    await _dataSource.firstScan(request: request);
  }

  @override
  Future<void> nextScan({required NextScanRequest request}) async {
    await _dataSource.nextScan(request: request);
  }

  @override
  Future<void> cancelSearch() async {
    await _dataSource.cancelSearch();
  }

  @override
  Future<void> resetSearchSession() async {
    await _dataSource.resetSearchSession();
  }
}
