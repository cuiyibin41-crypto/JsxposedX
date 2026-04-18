import 'package:JsxposedX/features/memory_tool_overlay/data/datasources/memory_pointer_action_datasource.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_pointer_action_repository.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';

class MemoryPointerActionRepositoryImpl implements MemoryPointerActionRepository {
  MemoryPointerActionRepositoryImpl({required this.dataSource});

  final MemoryPointerActionDatasource dataSource;

  @override
  Future<void> startPointerScan({required PointerScanRequest request}) async {
    await dataSource.startPointerScan(request: request);
  }

  @override
  Future<void> cancelPointerScan() async {
    await dataSource.cancelPointerScan();
  }

  @override
  Future<void> resetPointerScanSession() async {
    await dataSource.resetPointerScanSession();
  }
}
