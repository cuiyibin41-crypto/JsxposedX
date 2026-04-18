import 'package:JsxposedX/features/memory_tool_overlay/data/datasources/memory_action_datasource.dart';
import 'package:JsxposedX/features/memory_tool_overlay/data/repositories/memory_action_repository_impl.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_action_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_value_history_state.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_search_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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

@riverpod
Future<List<FrozenMemoryValue>> currentFrozenMemoryValues(Ref ref) async {
  return await ref
      .watch(memoryActionRepositoryProvider)
      .getFrozenMemoryValues();
}

@riverpod
Future<bool> processPaused(Ref ref, {required int pid}) async {
  return await ref
      .watch(memoryActionRepositoryProvider)
      .isProcessPaused(pid: pid);
}

@Riverpod(keepAlive: true)
class MemoryValueHistory extends _$MemoryValueHistory {
  @override
  Map<int, MemoryToolValueHistoryEntryState> build() {
    return const <int, MemoryToolValueHistoryEntryState>{};
  }

  void recordPreview(MemoryValuePreview preview) {
    state = <int, MemoryToolValueHistoryEntryState>{
      ...state,
      preview.address: MemoryToolValueHistoryEntryState.fromPreview(preview),
    };
  }

  void remove(int address) {
    if (!state.containsKey(address)) {
      return;
    }

    final nextState = Map<int, MemoryToolValueHistoryEntryState>.from(state);
    nextState.remove(address);
    state = nextState;
  }

  void clear() {
    if (state.isEmpty) {
      return;
    }
    state = const <int, MemoryToolValueHistoryEntryState>{};
  }
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
      ref.read(memoryValueHistoryProvider.notifier).clear();
      ref.read(memoryToolRemovedResultProvider.notifier).clear();
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
      ref.read(memoryValueHistoryProvider.notifier).clear();
      ref.read(memoryToolRemovedResultProvider.notifier).clear();
      _invalidateSearchQueries();
    });
  }

  void _invalidateSearchQueries() {
    ref.invalidate(getSearchSessionStateProvider);
    ref.invalidate(getSearchTaskStateProvider);
    ref.invalidate(getSearchResultsProvider);
  }
}

@Riverpod(keepAlive: true)
class MemoryValueAction extends _$MemoryValueAction {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> writeMemoryValue({
    required MemoryWriteRequest request,
    MemoryValuePreview? previousPreview,
  }) async {
    state = const AsyncValue.loading();
    final nextState = await AsyncValue.guard(() async {
      await ref
          .read(memoryActionRepositoryProvider)
          .writeMemoryValue(request: request);
      if (previousPreview != null) {
        ref
            .read(memoryValueHistoryProvider.notifier)
            .recordPreview(previousPreview);
      }
      _invalidateValueQueries();
    });
    state = nextState;
    if (nextState.hasError) {
      Error.throwWithStackTrace(
        nextState.error!,
        nextState.asError!.stackTrace,
      );
    }
  }

  Future<void> setMemoryFreeze({required MemoryFreezeRequest request}) async {
    state = const AsyncValue.loading();
    final nextState = await AsyncValue.guard(() async {
      await ref
          .read(memoryActionRepositoryProvider)
          .setMemoryFreeze(request: request);
      _invalidateValueQueries();
    });
    state = nextState;
    if (nextState.hasError) {
      Error.throwWithStackTrace(
        nextState.error!,
        nextState.asError!.stackTrace,
      );
    }
  }

  Future<void> setMemoryFreezes({
    required List<MemoryFreezeRequest> requests,
  }) async {
    if (requests.isEmpty) {
      return;
    }

    state = const AsyncValue.loading();
    final nextState = await AsyncValue.guard(() async {
      final repository = ref.read(memoryActionRepositoryProvider);
      for (final request in requests) {
        await repository.setMemoryFreeze(request: request);
      }
      _invalidateValueQueries();
    });
    state = nextState;
    if (nextState.hasError) {
      Error.throwWithStackTrace(
        nextState.error!,
        nextState.asError!.stackTrace,
      );
    }
  }

  Future<void> writeMemoryValues({
    required List<MemoryWriteRequest> requests,
    required List<MemoryValuePreview> previousPreviews,
  }) async {
    if (requests.isEmpty) {
      return;
    }

    state = const AsyncValue.loading();
    final nextState = await AsyncValue.guard(() async {
      final repository = ref.read(memoryActionRepositoryProvider);
      final historyController = ref.read(memoryValueHistoryProvider.notifier);
      final previousPreviewByAddress = <int, MemoryValuePreview>{
        for (final preview in previousPreviews) preview.address: preview,
      };

      for (final request in requests) {
        await repository.writeMemoryValue(request: request);
        final previousPreview = previousPreviewByAddress[request.address];
        if (previousPreview != null) {
          historyController.recordPreview(previousPreview);
        }
      }

      _invalidateValueQueries();
    });
    state = nextState;
    if (nextState.hasError) {
      Error.throwWithStackTrace(
        nextState.error!,
        nextState.asError!.stackTrace,
      );
    }
  }

  Future<int> restorePreviousValues({
    required List<int> addresses,
    required bool littleEndian,
  }) async {
    final historyState = ref.read(memoryValueHistoryProvider);
    final historyEntries = addresses
        .map((address) => historyState[address])
        .whereType<MemoryToolValueHistoryEntryState>()
        .toList(growable: false);
    if (historyEntries.isEmpty) {
      return 0;
    }

    int restoredCount = 0;
    state = const AsyncValue.loading();
    final nextState = await AsyncValue.guard(() async {
      final currentPreviews = await ref
          .read(memoryQueryRepositoryProvider)
          .readMemoryValues(
            requests: historyEntries
                .map(
                  (entry) => MemoryReadRequest(
                    address: entry.address,
                    type: entry.type,
                    length: resolveMemoryToolReadLengthForType(
                      type: entry.type,
                      bytesLength: entry.rawBytes.length,
                    ),
                  ),
                )
                .toList(growable: false),
          );
      final currentPreviewByAddress = <int, MemoryValuePreview>{
        for (final preview in currentPreviews) preview.address: preview,
      };
      final repository = ref.read(memoryActionRepositoryProvider);
      final historyController = ref.read(memoryValueHistoryProvider.notifier);

      for (final entry in historyEntries) {
        final previousPreview = entry.toPreview();
        final restoreValue = buildMemoryToolWriteValue(
          type: previousPreview.type,
          input: previousPreview.displayValue,
          littleEndian: littleEndian,
          sourceType: previousPreview.type,
          sourceRawBytes: previousPreview.rawBytes,
          sourceDisplayValue: previousPreview.displayValue,
        );
        await repository.writeMemoryValue(
          request: MemoryWriteRequest(
            address: entry.address,
            value: restoreValue,
          ),
        );

        final currentPreview = currentPreviewByAddress[entry.address];
        if (currentPreview != null) {
          historyController.recordPreview(currentPreview);
        } else {
          historyController.remove(entry.address);
        }
        restoredCount += 1;
      }

      _invalidateValueQueries();
    });
    state = nextState;
    if (nextState.hasError) {
      Error.throwWithStackTrace(
        nextState.error!,
        nextState.asError!.stackTrace,
      );
    }
    return restoredCount;
  }

  void _invalidateValueQueries() {
    ref.invalidate(readMemoryValuesProvider);
    ref.invalidate(currentSearchResultLivePreviewsProvider);
    ref.invalidate(currentBrowseResultLivePreviewsProvider);
    ref.invalidate(currentSavedItemLivePreviewsProvider);
    ref.invalidate(currentFrozenMemoryValuesProvider);
  }
}

@Riverpod(keepAlive: true)
class MemoryProcessControlAction extends _$MemoryProcessControlAction {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> setProcessPaused({
    required int pid,
    required bool paused,
  }) async {
    state = const AsyncValue.loading();
    final nextState = await AsyncValue.guard(() async {
      await ref
          .read(memoryActionRepositoryProvider)
          .setProcessPaused(pid: pid, paused: paused);
      ref.invalidate(processPausedProvider(pid: pid));
    });
    state = nextState;
    if (nextState.hasError) {
      Error.throwWithStackTrace(
        nextState.error!,
        nextState.asError!.stackTrace,
      );
    }
  }
}
