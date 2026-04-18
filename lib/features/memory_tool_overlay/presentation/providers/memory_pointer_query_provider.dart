import 'package:JsxposedX/features/memory_tool_overlay/data/datasources/memory_pointer_query_datasource.dart';
import 'package:JsxposedX/features/memory_tool_overlay/data/repositories/memory_pointer_query_repository_impl.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_pointer_query_repository.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_pointer_query_provider.g.dart';

@riverpod
MemoryPointerQueryRepository memoryPointerQueryRepository(Ref ref) {
  final dataSource = MemoryPointerQueryDatasource();
  return MemoryPointerQueryRepositoryImpl(dataSource: dataSource);
}

@riverpod
Future<PointerScanSessionState> getPointerScanSessionState(Ref ref) async {
  return await ref
      .watch(memoryPointerQueryRepositoryProvider)
      .getPointerScanSessionState();
}

@riverpod
Future<PointerScanTaskState> getPointerScanTaskState(Ref ref) async {
  return await ref.watch(memoryPointerQueryRepositoryProvider).getPointerScanTaskState();
}

@riverpod
Future<List<PointerScanResult>> getPointerScanResults(
  Ref ref, {
  required int offset,
  required int limit,
}) async {
  return await ref
      .watch(memoryPointerQueryRepositoryProvider)
      .getPointerScanResults(offset: offset, limit: limit);
}
