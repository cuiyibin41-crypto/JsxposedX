import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/common/widgets/ref_error.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_pointer_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_search_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_batch_edit_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_calculator_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_stats_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_list.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart'
    show
        FrozenMemoryValue,
        MemoryValuePreview,
        PointerScanRequest,
        SearchResult,
        SearchSessionState;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolSearchResultCard extends HookConsumerWidget {
  const MemoryToolSearchResultCard({
    super.key,
    required this.hasMatchingSession,
    required this.sessionStateAsync,
    required this.onRetry,
    required this.onOpenSearch,
    required this.onOpenBrowseTab,
    required this.onOpenPointerTab,
  });

  final bool hasMatchingSession;
  final AsyncValue<SearchSessionState> sessionStateAsync;
  final VoidCallback onRetry;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenBrowseTab;
  final VoidCallback onOpenPointerTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionState = ref.watch(memoryToolResultSelectionProvider);
    final selectionNotifier = ref.read(
      memoryToolResultSelectionProvider.notifier,
    );
    final livePreviewsAsync = ref.watch(
      currentSearchResultLivePreviewsProvider,
    );
    final valueHistoryState = ref.watch(memoryValueHistoryProvider);
    final removedResultState = ref.watch(memoryToolRemovedResultProvider);
    final removedResultNotifier = ref.read(
      memoryToolRemovedResultProvider.notifier,
    );
    final savedItemsNotifier = ref.read(memoryToolSavedItemsProvider.notifier);
    final selectedPid = ref.watch(memoryToolSelectedProcessProvider)?.pid;
    final frozenValuesAsync = ref.watch(currentFrozenMemoryValuesProvider);
    final processPausedAsync = selectedPid == null
        ? const AsyncValue.data(false)
        : ref.watch(processPausedProvider(pid: selectedPid));
    final processControlState = ref.watch(memoryProcessControlActionProvider);
    final isSettingsVisible = useState(false);
    final isBatchEditVisible = useState(false);
    final isCalculatorVisible = useState(false);

    final resultsAsync = hasMatchingSession
        ? ref.watch(currentSearchResultsProvider)
        : const AsyncValue.data(<SearchResult>[]);
    final displayedResults = resultsAsync.maybeWhen(
      data: (results) => results,
      orElse: () => const <SearchResult>[],
    );
    final resultCount = sessionStateAsync.maybeWhen(
      data: (state) {
        final removedCount = removedResultState.removedAddresses.length;
        if (state.resultCount <= removedCount) {
          return 0;
        }
        return state.resultCount - removedCount;
      },
      orElse: () => displayedResults.length,
    );
    final pageCount = selectionState.selectionLimit <= 0
        ? 0
        : (resultCount / selectionState.selectionLimit).ceil();
    final visibleResults = displayedResults
        .take(selectionState.selectionLimit)
        .toList(growable: false);
    final selectedResults = visibleResults
        .where((result) => selectionState.contains(result.address))
        .toList(growable: false);
    final canRestorePrevious = selectionState.selectedAddresses.any(
      valueHistoryState.containsKey,
    );
    final previousValueByAddress = <int, String>{
      for (final entry in valueHistoryState.entries)
        entry.key: entry.value.displayValue,
    };
    final listStorageKey = PageStorageKey<String>(
      'memory_tool_search_results_${selectedPid ?? 0}',
    );
    final frozenAddresses = <int>{
      for (final value
          in frozenValuesAsync.asData?.value ?? const <FrozenMemoryValue>[])
        if (selectedPid != null && value.pid == selectedPid) value.address,
    };

    Future<void> showSavedToast(int count) async {
      await ToastOverlayMessage.show(
        context.l10n.memoryToolSavedToSavedMessage(count),
        duration: const Duration(milliseconds: 1200),
      );
    }

    Future<void> saveResultsToSaved(
      Iterable<SearchResult> results, {
      required Map<int, MemoryValuePreview> previewsByAddress,
      required Set<int> frozenResultAddresses,
    }) async {
      if (selectedPid == null) {
        return;
      }

      final resultList = results.toList(growable: false);
      if (resultList.isEmpty) {
        return;
      }

      savedItemsNotifier.saveMany(
        pid: selectedPid,
        results: resultList,
        previewsByAddress: previewsByAddress,
        frozenAddresses: frozenResultAddresses,
      );
      await showSavedToast(resultList.length);
    }

    return Stack(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.r),
          child: Column(
            children: <Widget>[
              MemoryToolResultSelectionBar(
                actions: <MemoryToolResultSelectionActionData>[
                  MemoryToolResultSelectionActionData(
                    icon: Icons.search_rounded,
                    onTap: onOpenSearch,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: processPausedAsync.asData?.value ?? false
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    onTap:
                        selectedPid == null ||
                            processControlState.isLoading ||
                            processPausedAsync.isLoading
                        ? null
                        : () async {
                            try {
                              final isPaused =
                                  processPausedAsync.asData?.value ?? false;
                              await ref
                                  .read(
                                    memoryProcessControlActionProvider.notifier,
                                  )
                                  .setProcessPaused(
                                    pid: selectedPid,
                                    paused: !isPaused,
                                  );
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.done_all_rounded,
                    onTap: visibleResults.isEmpty
                        ? null
                        : () {
                            selectionNotifier.selectVisible(visibleResults);
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.flip_rounded,
                    onTap: visibleResults.isEmpty
                        ? null
                        : () {
                            selectionNotifier.invertVisible(visibleResults);
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.layers_clear_rounded,
                    onTap: visibleResults.isEmpty
                        ? null
                        : selectionNotifier.clear,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.delete_sweep_rounded,
                    onTap: selectedResults.isEmpty
                        ? null
                        : () {
                            removedResultNotifier.removeMany(
                              selectionState.selectedAddresses,
                            );
                            selectionNotifier.clear();
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.save_alt_rounded,
                    onTap: selectedResults.isEmpty
                        ? null
                        : () async {
                            await saveResultsToSaved(
                              selectedResults,
                              previewsByAddress:
                                  livePreviewsAsync.asData?.value ??
                                  const <int, MemoryValuePreview>{},
                              frozenResultAddresses: frozenAddresses,
                            );
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.calculate_outlined,
                    onTap: selectedResults.length >= 2
                        ? () {
                            isCalculatorVisible.value = true;
                          }
                        : null,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.edit_rounded,
                    onTap: selectedResults.isEmpty
                        ? null
                        : () {
                            isBatchEditVisible.value = true;
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.undo_rounded,
                    onTap: canRestorePrevious
                        ? () async {
                            try {
                              final sessionState = await ref.read(
                                getSearchSessionStateProvider.future,
                              );
                              await ref
                                  .read(memoryValueActionProvider.notifier)
                                  .restorePreviousValues(
                                    addresses: selectionState.selectedAddresses,
                                    littleEndian: sessionState.littleEndian,
                                  );
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          }
                        : null,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.tune_rounded,
                    onTap: () {
                      isSettingsVisible.value = true;
                    },
                  ),
                ],
              ),
              SizedBox(height: 1.r),
              Expanded(
                child: !hasMatchingSession
                    ? _MemoryToolSearchEmptyState(message: context.l10n.noData)
                    : resultsAsync.when(
                        data: (_) {
                          if (visibleResults.isEmpty) {
                            return _MemoryToolSearchEmptyState(
                              message: context.l10n.noData,
                            );
                          }

                          return MemoryToolSearchResultList(
                            listStorageKey: listStorageKey,
                            results: visibleResults,
                            isSelected: selectionState.contains,
                            onToggleSelection: selectionNotifier.toggle,
                            onDeleteResult: (result) {
                              selectionNotifier.removeAddress(result.address);
                              removedResultNotifier.remove(result.address);
                            },
                            livePreviewsAsync: livePreviewsAsync,
                            previousValueByAddress: previousValueByAddress,
                            processPid: selectedPid,
                            initialFrozenStateByAddress: <int, bool>{
                              for (final address in frozenAddresses)
                                address: true,
                            },
                            onPreviewMemoryAddress: (
                              result,
                              preview,
                              displayValue,
                              targetAddress,
                            ) async {
                              onOpenBrowseTab();
                              await ref
                                  .read(
                                    memoryToolBrowseControllerProvider.notifier,
                                  )
                                  .previewFromAddress(
                                    sourceResult: result,
                                    sourcePreview: preview,
                                    sourceDisplayValue: displayValue,
                                    targetAddress: targetAddress,
                                  );
                            },
                            onStartPointerScan: (
                              PointerScanRequest request,
                            ) async {
                              onOpenPointerTab();
                              await ref
                                  .read(
                                    memoryToolPointerControllerProvider.notifier,
                                  )
                                  .startRootScan(request: request);
                            },
                          );
                        },
                        error: (error, _) =>
                            RefError(onRetry: onRetry, error: error),
                        loading: () {
                          if (visibleResults.isNotEmpty) {
                            return MemoryToolSearchResultList(
                              listStorageKey: listStorageKey,
                              results: visibleResults,
                              isSelected: selectionState.contains,
                              onToggleSelection: selectionNotifier.toggle,
                              onDeleteResult: (result) {
                                selectionNotifier.removeAddress(result.address);
                                removedResultNotifier.remove(result.address);
                              },
                              livePreviewsAsync: livePreviewsAsync,
                              previousValueByAddress: previousValueByAddress,
                              processPid: selectedPid,
                              initialFrozenStateByAddress: <int, bool>{
                                for (final address in frozenAddresses)
                                  address: true,
                              },
                              onPreviewMemoryAddress: (
                                result,
                                preview,
                                displayValue,
                                targetAddress,
                              ) async {
                                onOpenBrowseTab();
                                await ref
                                    .read(
                                      memoryToolBrowseControllerProvider
                                          .notifier,
                                    )
                                    .previewFromAddress(
                                      sourceResult: result,
                                      sourcePreview: preview,
                                      sourceDisplayValue: displayValue,
                                      targetAddress: targetAddress,
                                    );
                              },
                              onStartPointerScan: (
                                PointerScanRequest request,
                              ) async {
                                onOpenPointerTab();
                                await ref
                                    .read(
                                      memoryToolPointerControllerProvider
                                          .notifier,
                                    )
                                    .startRootScan(request: request);
                              },
                            );
                          }

                          return const Loading();
                        },
                      ),
              ),
              SizedBox(height: 6.r),
              MemoryToolResultStatsBar(
                resultCount: resultCount,
                selectedCount: selectionState.selectedCount,
                renderedCount: visibleResults.length,
                pageCount: pageCount,
              ),
            ],
          ),
        ),
        if (isSettingsVisible.value)
          Positioned.fill(
            child: MemoryToolResultSelectionDialog(
              initialLimit: selectionState.selectionLimit,
              title: context.l10n.memoryToolResultSelectionDialogTitle,
              fieldLabel: context.l10n.memoryToolResultSelectionFieldLabel,
              onClose: () {
                isSettingsVisible.value = false;
              },
              onConfirm: (value) {
                selectionNotifier.updateSelectionLimit(value);
                isSettingsVisible.value = false;
              },
            ),
          ),
        if (isBatchEditVisible.value)
          Positioned.fill(
            child: MemoryToolBatchEditDialog(
              results: selectedResults,
              livePreviewsAsync: livePreviewsAsync,
              savedSyncMode: MemoryToolBatchEditSavedSyncMode.frozenOnly,
              onClose: () {
                isBatchEditVisible.value = false;
              },
            ),
          ),
        if (isCalculatorVisible.value)
          Positioned.fill(
            child: MemoryToolResultCalculatorDialog(
              results: selectedResults,
              livePreviewsAsync: livePreviewsAsync,
              onClose: () {
                isCalculatorVisible.value = false;
              },
            ),
          ),
      ],
    );
  }
}

class _MemoryToolSearchEmptyState extends StatelessWidget {
  const _MemoryToolSearchEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colorScheme.onSurface.withValues(alpha: 0.66),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
