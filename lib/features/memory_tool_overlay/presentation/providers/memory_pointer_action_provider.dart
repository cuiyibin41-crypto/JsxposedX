import 'package:JsxposedX/features/memory_tool_overlay/data/datasources/memory_pointer_action_datasource.dart';
import 'package:JsxposedX/features/memory_tool_overlay/data/repositories/memory_pointer_action_repository_impl.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_pointer_action_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_query_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_pointer_action_provider.g.dart';

@riverpod
MemoryPointerActionDatasource memoryPointerActionDatasource(Ref ref) {
  return MemoryPointerActionDatasource();
}

@riverpod
MemoryPointerActionRepository memoryPointerActionRepository(Ref ref) {
  final dataSource = ref.watch(memoryPointerActionDatasourceProvider);
  return MemoryPointerActionRepositoryImpl(dataSource: dataSource);
}

@Riverpod(keepAlive: true)
class MemoryPointerAction extends _$MemoryPointerAction {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> startPointerScan({required PointerScanRequest request}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(memoryPointerActionRepositoryProvider)
          .startPointerScan(request: request);
      _invalidatePointerQueries();
    });
  }

  Future<void> cancelPointerScan() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(memoryPointerActionRepositoryProvider).cancelPointerScan();
      _invalidatePointerQueries();
    });
  }

  Future<void> resetPointerScanSession() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(memoryPointerActionRepositoryProvider)
          .resetPointerScanSession();
      _invalidatePointerQueries();
    });
  }

  void _invalidatePointerQueries() {
    ref.invalidate(getPointerScanSessionStateProvider);
    ref.invalidate(getPointerScanTaskStateProvider);
    ref.invalidate(getPointerScanResultsProvider);
  }
}
