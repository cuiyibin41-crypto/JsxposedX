import 'package:JsxposedX/features/memory_tool_overlay/data/datasources/memory_action_datasource.dart';
import 'package:JsxposedX/features/memory_tool_overlay/data/repositories/memory_action_repository_impl.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_action_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_action_provider.g.dart';

@riverpod
MemoryActionDatasource memoryActionDatasource(Ref ref) {
  return MemoryActionDatasource();
}

@riverpod
MemoryActionRepository memoryActionRepository(Ref ref) {
  final dataSource = ref.watch(memoryActionDatasourceProvider);
  return MemoryActionRepositoryImpl(dataSource: dataSource);
}

@Riverpod(keepAlive: true)
class MemorySearchAction extends _$MemorySearchAction {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> firstScan({required FirstScanRequest request}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(memoryActionRepositoryProvider)
          .firstScan(request: request);
      _invalidateSearchQueries();
    });
  }

  Future<void> nextScan({required NextScanRequest request}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(memoryActionRepositoryProvider).nextScan(request: request);
      _invalidateSearchQueries();
    });
  }

  Future<void> cancelSearch() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(memoryActionRepositoryProvider).cancelSearch();
      _invalidateSearchQueries();
    });
  }

  Future<void> resetSearchSession() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(memoryActionRepositoryProvider).resetSearchSession();
      _invalidateSearchQueries();
    });
  }

  void _invalidateSearchQueries() {
    ref.invalidate(getSearchSessionStateProvider);
    ref.invalidate(getSearchTaskStateProvider);
    ref.invalidate(getSearchResultsProvider);
  }
}
