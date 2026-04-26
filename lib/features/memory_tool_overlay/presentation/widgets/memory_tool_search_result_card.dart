import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/common/widgets/ref_error.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_entry_kind.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_pointer_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_search_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_export_util.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_pointer_utils.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_batch_edit_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_calculator_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_stats_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_group_search_chain_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_settings_dialog.dart';
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
    required this.onOpenJumpAddress,
    required this.onOpenLocateExpression,
    required this.onOpenBrowseTab,
    required this.onOpenPointerTab,
    required this.onOpenDebugTab,
    required this.onOpenSavedTab,
  });

  final bool hasMatchingSession;
  final AsyncValue<SearchSessionState> sessionStateAsync;
  final VoidCallback onRetry;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenJumpAddress;
  final VoidCallback onOpenLocateExpression;
  final VoidCallback onOpenBrowseTab;
  final VoidCallback onOpenPointerTab;
  final VoidCallback onOpenDebugTab;
  final VoidCallback onOpenSavedTab;

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
    final isToolConfigVisible = useState(false);
    final isBatchEditVisible = useState(false);
    final isCalculatorVisible = useState(false);
    final isGroupSearchChainVisible = useState(false);

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

      savedItemsNotifier.saveEntries(
        pid: selectedPid,
        results: resultList,
        previewsByAddress: previewsByAddress,
        frozenAddresses: frozenResultAddresses,
      );
      if (context.mounted) {
        onOpenSavedTab();
      }
      await showSavedToast(resultList.length);
    }

    Future<void> exportSelectedResults(
      List<SearchResult> results,
      Map<int, MemoryValuePreview> previewsByAddress,
    ) async {
      if (results.isEmpty) {
        return;
      }
      await exportMemoryToolItemsToLocal(
        context: context,
        ref: ref,
        sourceKey: 'search',
        pid: selectedPid,
        items: results
            .map((result) {
              final preview = previewsByAddress[result.address];
              return MemoryToolExportItem(
                pid: selectedPid,
                address: result.address,
                regionStart: result.regionStart,
                regionTypeKey: result.regionTypeKey,
                valueType: preview?.type ?? result.type,
                displayValue: resolveMemoryToolPreferredDisplayValue(
                  result: result,
                  livePreview: preview,
                  fallbackDisplayValue: result.displayValue,
                ),
                rawBytes: preview?.rawBytes ?? result.rawBytes,
                isFrozen: frozenAddresses.contains(result.address),
                entryKind: MemoryToolEntryKind.value,
              );
            })
            .toList(growable: false),
      );
    }

    Future<void> previewAndOpenBrowse(
      Future<void> Function() previewAction,
    ) async {
      try {
        await previewAction();
        onOpenBrowseTab();
      } catch (_) {
        if (!context.mounted) {
          return;
        }
        await ToastOverlayMessage.show(
          context.l10n.memoryToolOffsetPreviewUnreadable,
          duration: const Duration(milliseconds: 1200),
        );
      }
    }

    Future<void> jumpToPointer(
      SearchResult result,
      MemoryValuePreview? preview,
      String displayValue,
    ) async {
      if (selectedPid == null) {
        return;
      }

      final targetAddress = decodeMemoryToolPointerAddress(
        preview?.rawBytes ?? result.rawBytes,
      );
      if (targetAddress == null) {
        await ToastOverlayMessage.show(
          context.l10n.memoryToolOffsetPreviewUnreadable,
          duration: const Duration(milliseconds: 1200),
        );
        return;
      }

      await previewAndOpenBrowse(
        () => ref
            .read(memoryToolBrowseControllerProvider.notifier)
            .previewFromAddress(
              sourceResult: result,
              sourcePreview: preview,
              targetAddress: targetAddress,
              preferInstructionMode: false,
            ),
      );
    }

    return Stack(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.r),
          child: Column(
            children: <Widget>[
              MemoryToolResultSelectionBar(
                groups: <MemoryToolResultSelectionActionGroupData>[
                  MemoryToolResultSelectionActionGroupData(
                    icon: Icons.manage_search_rounded,
                    label: context.isZh ? '搜索与定位' : 'Search & Locate',
                    actions: <MemoryToolResultSelectionActionData>[
                      MemoryToolResultSelectionActionData(
                        icon: Icons.search_rounded,
                        label: context.isZh ? '搜索' : 'Search',
                        onTap: onOpenSearch,
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.travel_explore_rounded,
                        label: context.isZh ? '跳转地址' : 'Jump Address',
                        onTap: selectedPid == null ? null : onOpenJumpAddress,
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.data_object_rounded,
                        label: context.isZh ? '表达式定位' : 'Locate Expression',
                        onTap: selectedPid == null
                            ? null
                            : onOpenLocateExpression,
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: processPausedAsync.asData?.value ?? false
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        label: processPausedAsync.asData?.value ?? false
                            ? (context.isZh ? '继续进程' : 'Resume Process')
                            : (context.isZh ? '暂停进程' : 'Pause Process'),
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
                                        memoryProcessControlActionProvider
                                            .notifier,
                                      )
                                      .setProcessPaused(
                                        pid: selectedPid,
                                        paused: !isPaused,
                                      );
                                } catch (error) {
                                  if (!context.mounted) {
                                    return;
                                  }
                                  await ToastOverlayMessage.show(
                                    error.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                    duration: const Duration(
                                      milliseconds: 1400,
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                  MemoryToolResultSelectionActionGroupData(
                    icon: Icons.check_box_rounded,
                    label: context.isZh ? '选择' : 'Selection',
                    actions: <MemoryToolResultSelectionActionData>[
                      MemoryToolResultSelectionActionData(
                        icon: Icons.done_all_rounded,
                        label: context.isZh ? '选择可见' : 'Select Visible',
                        onTap: visibleResults.isEmpty
                            ? null
                            : () {
                                selectionNotifier.selectVisible(visibleResults);
                              },
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.flip_rounded,
                        label: context.isZh ? '反选可见' : 'Invert Visible',
                        onTap: visibleResults.isEmpty
                            ? null
                            : () {
                                selectionNotifier.invertVisible(visibleResults);
                              },
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.layers_clear_rounded,
                        label: context.isZh ? '清空选择' : 'Clear Selection',
                        onTap: visibleResults.isEmpty
                            ? null
                            : selectionNotifier.clear,
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.delete_sweep_rounded,
                        label: context.isZh ? '移除选中' : 'Remove Selected',
                        onTap: selectedResults.isEmpty
                            ? null
                            : () {
                                removedResultNotifier.removeMany(
                                  selectionState.selectedAddresses,
                                );
                                selectionNotifier.clear();
                              },
                      ),
                    ],
                  ),
                  MemoryToolResultSelectionActionGroupData(
                    icon: Icons.folder_special_rounded,
                    label: context.isZh ? '保存与导出' : 'Save & Export',
                    actions: <MemoryToolResultSelectionActionData>[
                      MemoryToolResultSelectionActionData(
                        icon: Icons.bookmark_add_rounded,
                        label: context.isZh ? '保存到暂存' : 'Save',
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
                        icon: Icons.ios_share_rounded,
                        label: context.isZh ? '导出' : 'Export',
                        onTap: selectedResults.isEmpty
                            ? null
                            : () async {
                                await exportSelectedResults(
                                  selectedResults,
                                  livePreviewsAsync.asData?.value ??
                                      const <int, MemoryValuePreview>{},
                                );
                              },
                      ),
                    ],
                  ),
                  MemoryToolResultSelectionActionGroupData(
                    icon: Icons.construction_rounded,
                    label: context.isZh ? '工具' : 'Tools',
                    actions: <MemoryToolResultSelectionActionData>[
                      MemoryToolResultSelectionActionData(
                        icon: Icons.calculate_outlined,
                        label: context.isZh ? '计算器' : 'Calculator',
                        onTap: selectedResults.length >= 2
                            ? () {
                                isCalculatorVisible.value = true;
                              }
                            : null,
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.link_rounded,
                        label: context.isZh ? '复制联合特征链' : 'Copy Chain',
                        onTap: selectedResults.length >= 2
                            ? () {
                                isGroupSearchChainVisible.value = true;
                              }
                            : null,
                      ),
                    ],
                  ),
                  MemoryToolResultSelectionActionGroupData(
                    icon: Icons.edit_note_rounded,
                    label: context.isZh ? '修改' : 'Edit',
                    actions: <MemoryToolResultSelectionActionData>[
                      MemoryToolResultSelectionActionData(
                        icon: Icons.edit_rounded,
                        label: context.isZh ? '批量修改' : 'Batch Edit',
                        onTap: selectedResults.isEmpty
                            ? null
                            : () {
                                isBatchEditVisible.value = true;
                              },
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.undo_rounded,
                        label: context.isZh ? '恢复上次值' : 'Restore Previous',
                        onTap: canRestorePrevious
                            ? () async {
                                try {
                                  final sessionState = await ref.read(
                                    getSearchSessionStateProvider.future,
                                  );
                                  await ref
                                      .read(memoryValueActionProvider.notifier)
                                      .restorePreviousValues(
                                        addresses:
                                            selectionState.selectedAddresses,
                                        littleEndian: sessionState.littleEndian,
                                      );
                                } catch (error) {
                                  if (!context.mounted) {
                                    return;
                                  }
                                  await ToastOverlayMessage.show(
                                    error.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                    duration: const Duration(
                                      milliseconds: 1400,
                                    ),
                                  );
                                }
                              }
                            : null,
                      ),
                    ],
                  ),
                  MemoryToolResultSelectionActionGroupData(
                    icon: Icons.tune_rounded,
                    label: context.isZh ? '设置' : 'Settings',
                    actions: <MemoryToolResultSelectionActionData>[
                      MemoryToolResultSelectionActionData(
                        icon: Icons.view_week_rounded,
                        label: context.isZh ? '显示数量' : 'Display Limit',
                        onTap: () {
                          isSettingsVisible.value = true;
                        },
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.settings_rounded,
                        label: context.isZh ? '配置' : 'Config',
                        onTap: () {
                          isToolConfigVisible.value = true;
                        },
                      ),
                    ],
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
                            onPreviewMemoryBlock:
                                (result, preview, displayValue) async {
                                  await previewAndOpenBrowse(
                                    () => ref
                                        .read(
                                          memoryToolBrowseControllerProvider
                                              .notifier,
                                        )
                                        .previewFromSearchResult(
                                          result: result,
                                          preview: preview,
                                          displayValue: displayValue,
                                          preferInstructionMode: false,
                                        ),
                                  );
                                },
                            onNavigateToAddress:
                                (
                                  result,
                                  preview,
                                  displayValue,
                                  targetAddress,
                                ) async {
                                  await previewAndOpenBrowse(
                                    () => ref
                                        .read(
                                          memoryToolBrowseControllerProvider
                                              .notifier,
                                        )
                                        .previewFromAddress(
                                          sourceResult: result,
                                          sourcePreview: preview,
                                          targetAddress: targetAddress,
                                          preferInstructionMode: false,
                                        ),
                                  );
                                },
                            onJumpToPointer: jumpToPointer,
                            onStartAutoChase:
                                (
                                  PointerScanRequest request,
                                  int maxDepth,
                                ) async {
                                  onOpenPointerTab();
                                  await ref
                                      .read(
                                        memoryToolPointerControllerProvider
                                            .notifier,
                                      )
                                      .startAutoChase(
                                        request: request,
                                        maxDepth: maxDepth,
                                      );
                                },
                            onStartPointerScan:
                                (PointerScanRequest request) async {
                                  onOpenPointerTab();
                                  await ref
                                      .read(
                                        memoryToolPointerControllerProvider
                                            .notifier,
                                      )
                                      .startRootScan(request: request);
                                },
                            onOpenDebugTab: onOpenDebugTab,
                            onOpenSavedTab: onOpenSavedTab,
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
                              onPreviewMemoryBlock:
                                  (result, preview, displayValue) async {
                                    await previewAndOpenBrowse(
                                      () => ref
                                          .read(
                                            memoryToolBrowseControllerProvider
                                                .notifier,
                                          )
                                          .previewFromSearchResult(
                                            result: result,
                                            preview: preview,
                                            displayValue: displayValue,
                                            preferInstructionMode: false,
                                          ),
                                    );
                                  },
                              onNavigateToAddress:
                                  (
                                    result,
                                    preview,
                                    displayValue,
                                    targetAddress,
                                  ) async {
                                    await previewAndOpenBrowse(
                                      () => ref
                                          .read(
                                            memoryToolBrowseControllerProvider
                                                .notifier,
                                          )
                                          .previewFromAddress(
                                            sourceResult: result,
                                            sourcePreview: preview,
                                            targetAddress: targetAddress,
                                            preferInstructionMode: false,
                                          ),
                                    );
                                  },
                              onJumpToPointer: jumpToPointer,
                              onStartAutoChase:
                                  (
                                    PointerScanRequest request,
                                    int maxDepth,
                                  ) async {
                                    onOpenPointerTab();
                                    await ref
                                        .read(
                                          memoryToolPointerControllerProvider
                                              .notifier,
                                        )
                                        .startAutoChase(
                                          request: request,
                                          maxDepth: maxDepth,
                                        );
                                  },
                              onStartPointerScan:
                                  (PointerScanRequest request) async {
                                    onOpenPointerTab();
                                    await ref
                                        .read(
                                          memoryToolPointerControllerProvider
                                              .notifier,
                                        )
                                        .startRootScan(request: request);
                                  },
                              onOpenDebugTab: onOpenDebugTab,
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
        if (isToolConfigVisible.value)
          Positioned.fill(
            child: MemoryToolSettingsDialog(
              onClose: () {
                isToolConfigVisible.value = false;
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
        if (isGroupSearchChainVisible.value)
          Positioned.fill(
            child: MemoryToolGroupSearchChainDialog(
              results: selectedResults,
              livePreviewsAsync: livePreviewsAsync,
              onClose: () {
                isGroupSearchChainVisible.value = false;
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
