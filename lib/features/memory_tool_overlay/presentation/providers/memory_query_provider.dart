import 'package:JsxposedX/features/memory_tool_overlay/data/datasources/memory_query_datasource.dart';
import 'package:JsxposedX/features/memory_tool_overlay/data/repositories/memory_query_repository_impl.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_query_repository.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_query_provider.g.dart';

@riverpod
MemoryQueryRepository memoryQueryRepository(Ref ref) {
  final dataSource = MemoryQueryDatasource();
  return MemoryQueryRepositoryImpl(dataSource: dataSource);
}

@riverpod
Future<int> getPid(Ref ref, {required String packageName}) async {
  return await ref
      .watch(memoryQueryRepositoryProvider)
      .getPid(packageName: packageName);
}

@riverpod
Future<List<ProcessInfo>> getProcessInfo(
  Ref ref, {
  required int offset,
  required int limit,
}) async {
  return await ref
      .watch(memoryQueryRepositoryProvider)
      .getProcessInfo(offset: offset, limit: limit);
}

@riverpod
Future<List<MemoryRegion>> getMemoryRegions(
  Ref ref, {
  required int pid,
  required int offset,
  required int limit,
  bool readableOnly = true,
  bool includeAnonymous = true,
  bool includeFileBacked = true,
}) async {
  return await ref
      .watch(memoryQueryRepositoryProvider)
      .getMemoryRegions(
        pid: pid,
        offset: offset,
        limit: limit,
        readableOnly: readableOnly,
        includeAnonymous: includeAnonymous,
        includeFileBacked: includeFileBacked,
      );
}

@riverpod
Future<SearchSessionState> getSearchSessionState(Ref ref) async {
  return await ref.watch(memoryQueryRepositoryProvider).getSearchSessionState();
}

@riverpod
Future<SearchTaskState> getSearchTaskState(Ref ref) async {
  return await ref.watch(memoryQueryRepositoryProvider).getSearchTaskState();
}

@riverpod
Future<List<SearchResult>> getSearchResults(
  Ref ref, {
  required int offset,
  required int limit,
}) async {
  return await ref
      .watch(memoryQueryRepositoryProvider)
      .getSearchResults(offset: offset, limit: limit);
}

@riverpod
Future<List<MemoryValuePreview>> readMemoryValues(
  Ref ref, {
  required List<MemoryReadRequest> requests,
}) async {
  return await ref
      .watch(memoryQueryRepositoryProvider)
      .readMemoryValues(requests: requests);
}

@Riverpod(keepAlive: true)
class MemoryToolSelectedProcess extends _$MemoryToolSelectedProcess {
  @override
  ProcessInfo? build() {
    return null;
  }

  void select(ProcessInfo process) {
    state = process;
  }

  void clear() {
    state = null;
  }
}
