import 'dart:typed_data';

import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_display_item.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_breakpoint_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_instruction_history_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_pointer_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_pointer_utils.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_assembly_preview_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_browse_result_list.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_batch_edit_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_debug_instruction_editor_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_calculator_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_stats_bar.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart'
    show
        MemoryInstructionPatchRequest,
        MemoryValuePreview,
        PointerScanRequest,
        SearchResult;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolBrowseTab extends HookConsumerWidget {
  const MemoryToolBrowseTab({
    super.key,
    required this.onOpenPointerTab,
    required this.onOpenDebugTab,
  });

  final VoidCallback onOpenPointerTab;
  final VoidCallback onOpenDebugTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final browseState = ref.watch(memoryToolBrowseControllerProvider);
    final browseNotifier = ref.read(
      memoryToolBrowseControllerProvider.notifier,
    );
    final visibleResults = ref.watch(currentBrowseResultsProvider);
    final livePreviewsAsync = ref.watch(
      currentBrowseResultLivePreviewsProvider,
    );
    final valueHistoryState = ref.watch(memoryValueHistoryProvider);
    final frozenValuesAsync = ref.watch(currentFrozenMemoryValuesProvider);
    final processControlState = ref.watch(memoryProcessControlActionProvider);
    final processPausedAsync = selectedProcess == null
        ? const AsyncValue.data(false)
        : ref.watch(processPausedProvider(pid: selectedProcess.pid));
    final savedItemsNotifier = ref.read(memoryToolSavedItemsProvider.notifier);
    final isSettingsVisible = useState(false);
    final isBatchEditVisible = useState(false);
    final isCalculatorVisible = useState(false);
    final activeInstructionBatchEditor = useState<String?>(null);
    final assemblyPreviewAddresses = useState<List<int>?>(null);
    final scrollController = useMemoized(() => ScrollController(), [
      browseState.focusRequestId,
    ]);

    useEffect(() {
      return scrollController.dispose;
    }, [scrollController]);

    useEffect(() {
      void handleScroll() {
        if (!scrollController.hasClients) {
          return;
        }
        final position = scrollController.position;
        if (position.extentBefore <= 180.r) {
          browseNotifier.loadMoreAbove();
        }
        if (position.extentAfter <= 320.r) {
          browseNotifier.loadMoreBelow();
        }
      }

      scrollController.addListener(handleScroll);
      return () {
        scrollController.removeListener(handleScroll);
      };
    }, [scrollController, browseNotifier]);

    useEffect(
      () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted || !scrollController.hasClients) {
            return;
          }
          final position = scrollController.position;
          if (position.extentBefore <= 180.r &&
              !browseState.isLoadingAbove &&
              !browseState.reachedTopBoundary) {
            browseNotifier.loadMoreAbove();
          }
          if (position.extentAfter <= 320.r &&
              !browseState.isLoadingBelow &&
              !browseState.reachedBottomBoundary) {
            browseNotifier.loadMoreBelow();
          }
        });
        return null;
      },
      [
        visibleResults.length,
        browseState.isLoadingAbove,
        browseState.isLoadingBelow,
        browseState.reachedTopBoundary,
        browseState.reachedBottomBoundary,
      ],
    );

    if (selectedProcess == null) {
      return Center(
        child: Text(
          context.l10n.selectApp,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.66),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final fallbackPreviewMap = <int, MemoryValuePreview>{
      for (final result in visibleResults)
        result.address: MemoryValuePreview(
          address: result.address,
          type: result.type,
          rawBytes: result.rawBytes,
          displayValue: result.displayValue,
        ),
    };
    final resolvedPreviewMap = <int, MemoryValuePreview>{
      ...fallbackPreviewMap,
      ...?livePreviewsAsync.asData?.value,
    };
    final resolvedLivePreviewsAsync =
        AsyncValue<Map<int, MemoryValuePreview>>.data(resolvedPreviewMap);
    final currentFrozenAddresses =
        frozenValuesAsync.asData?.value
            .where((value) => value.pid == selectedProcess.pid)
            .map((value) => value.address)
            .toSet() ??
        const <int>{};
    final previousValueByAddress = <int, String>{
      for (final entry in valueHistoryState.entries)
        entry.key: entry.value.displayValue,
    };
    final instructionHistoryByAddress = ref.watch(
      memoryToolInstructionHistoryProvider.select(
        (state) =>
            state.entriesByPid[selectedProcess.pid] ??
            const <int, MemoryToolInstructionHistoryEntry>{},
      ),
    );
    final selectedResults = visibleResults
        .where((result) => browseState.selectionState.contains(result.address))
        .toList(growable: false);
    final selectedInstructionResults = selectedResults
        .where((result) => result.isInstruction)
        .toList(growable: false);
    final selectedValueResults = selectedResults
        .where((result) => !result.isInstruction)
        .toList(growable: false);
    final hasInstructionSelection = selectedInstructionResults.isNotEmpty;
    final hasValueSelection = selectedValueResults.isNotEmpty;
    final canEditSelectedValues = hasValueSelection && !hasInstructionSelection;
    final canEditSelectedInstructions =
        hasInstructionSelection && !hasValueSelection;
    final canCalculateSelectedResults = selectedResults.length >= 2;
    final canRestoreValueHistory =
        hasValueSelection &&
        !hasInstructionSelection &&
        browseState.selectionState.selectedAddresses.any(
          valueHistoryState.containsKey,
        );
    final canRestoreInstructionHistory =
        hasInstructionSelection &&
        !hasValueSelection &&
        selectedInstructionResults.any(
          (result) => instructionHistoryByAddress.containsKey(result.address),
        );
    final canRestorePrevious =
        canRestoreValueHistory || canRestoreInstructionHistory;
    final visibleResultCount = browseState.results
        .where(
          (result) => !browseState.hiddenAddresses.contains(result.address),
        )
        .length;
    final pageCount = browseState.selectionState.selectionLimit <= 0
        ? 0
        : (visibleResultCount / browseState.selectionState.selectionLimit)
              .ceil();

    Future<void> showSavedToast(int count) async {
      await ToastOverlayMessage.show(
        context.l10n.memoryToolSavedToSavedMessage(count),
        duration: const Duration(milliseconds: 1200),
      );
    }

    String encodeInstructionBytesHex(Uint8List bytes) {
      return <String>[
        for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
      ].join(' ');
    }

    String resolveBatchInstructionInitialValue() {
      final uniqueInstructions = selectedInstructionResults
          .map((result) => result.effectiveDisplayValue.trim())
          .where((value) => value.isNotEmpty)
          .toSet();
      if (uniqueInstructions.length == 1) {
        return uniqueInstructions.first;
      }
      return '';
    }

    Future<void> saveResultsToSaved(
      Iterable<MemoryToolDisplayItem> results,
    ) async {
      final resultList = results.toList(growable: false);
      if (resultList.isEmpty) {
        return;
      }

      final valueResults = <SearchResult>[];
      for (final result in resultList) {
        if (result.isInstruction) {
          savedItemsNotifier.saveOne(
            pid: selectedProcess.pid,
            result: result.toSearchResult(),
            preview: resolvedPreviewMap[result.address],
            isFrozen: currentFrozenAddresses.contains(result.address),
            isInstructionPatch: true,
            instructionText: result.effectiveDisplayValue,
          );
        } else {
          valueResults.add(result.toSearchResult());
        }
      }
      if (valueResults.isNotEmpty) {
        savedItemsNotifier.saveMany(
          pid: selectedProcess.pid,
          results: valueResults,
          previewsByAddress: resolvedPreviewMap,
          frozenAddresses: currentFrozenAddresses,
        );
      }
      await showSavedToast(resultList.length);
    }

    Future<void> jumpToPointer(
      MemoryToolDisplayItem result,
      MemoryValuePreview? preview,
      String displayValue,
    ) async {
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

      try {
        await browseNotifier.previewFromAddress(
          sourceResult: result.toSearchResult(),
          sourcePreview: preview,
          targetAddress: targetAddress,
          preferInstructionMode: result.isInstruction,
        );
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        await ToastOverlayMessage.show(
          context.l10n.memoryToolOffsetPreviewUnreadable,
          duration: const Duration(milliseconds: 1200),
        );
      }
    }

    Future<String?> patchSelectedInstructions(String value) async {
      final trimmedValue = value.trim();
      if (trimmedValue.isEmpty) {
        return context.l10n.error;
      }

      var patchedCount = 0;
      var failedCount = 0;
      final historyNotifier = ref.read(
        memoryToolInstructionHistoryProvider.notifier,
      );
      for (final result in selectedInstructionResults) {
        try {
          final patchResult = await ref
              .read(memoryValueActionProvider.notifier)
              .patchMemoryInstruction(
                request: MemoryInstructionPatchRequest(
                  pid: selectedProcess.pid,
                  address: result.address,
                  instruction: trimmedValue,
                ),
              );
          historyNotifier.record(
            pid: selectedProcess.pid,
            address: result.address,
            previousBytes: patchResult.beforeBytes,
            previousDisplayValue: result.effectiveDisplayValue,
          );
          savedItemsNotifier.saveOne(
            pid: selectedProcess.pid,
            result: result
                .copyWith(
                  rawBytes: patchResult.afterBytes,
                  displayValue: patchResult.instructionText,
                  instructionText: patchResult.instructionText,
                )
                .toSearchResult(),
            isFrozen: false,
            isInstructionPatch: true,
            instructionText: patchResult.instructionText,
          );
          patchedCount += 1;
        } catch (_) {
          failedCount += 1;
        }
      }

      if (patchedCount == 0) {
        return context.isZh ? '修改失败' : 'Patch failed';
      }

      ref.invalidate(
        getMemoryBreakpointStateProvider(pid: selectedProcess.pid),
      );
      ref.invalidate(getMemoryBreakpointsProvider(pid: selectedProcess.pid));
      ref.invalidate(getMemoryBreakpointHitsProvider(pid: selectedProcess.pid));
      await browseNotifier.refreshVisibleInstructionResults(
        addresses: selectedInstructionResults.map((result) => result.address),
      );
      activeInstructionBatchEditor.value = null;
      await ToastOverlayMessage.show(
        context.isZh
            ? (failedCount == 0
                  ? '已批量修改$patchedCount条指令'
                  : '已修改$patchedCount条，失败$failedCount条')
            : (failedCount == 0
                  ? 'Patched $patchedCount instructions'
                  : 'Patched $patchedCount, failed $failedCount'),
        duration: const Duration(milliseconds: 1400),
      );
      return null;
    }

    Future<void> restoreSelectedInstructions() async {
      final historyNotifier = ref.read(
        memoryToolInstructionHistoryProvider.notifier,
      );
      var restoredCount = 0;
      for (final result in selectedInstructionResults) {
        final entry = instructionHistoryByAddress[result.address];
        if (entry == null) {
          continue;
        }
        try {
          final patchResult = await ref
              .read(memoryValueActionProvider.notifier)
              .patchMemoryInstruction(
                request: MemoryInstructionPatchRequest(
                  pid: selectedProcess.pid,
                  address: entry.address,
                  instruction: encodeInstructionBytesHex(entry.previousBytes),
                ),
              );
          historyNotifier.record(
            pid: selectedProcess.pid,
            address: entry.address,
            previousBytes: patchResult.beforeBytes,
            previousDisplayValue: result.effectiveDisplayValue,
          );
          savedItemsNotifier.saveOne(
            pid: selectedProcess.pid,
            result: result
                .copyWith(
                  rawBytes: patchResult.afterBytes,
                  displayValue: patchResult.instructionText,
                  instructionText: patchResult.instructionText,
                )
                .toSearchResult(),
            isFrozen: false,
            isInstructionPatch: true,
            instructionText: patchResult.instructionText,
          );
          restoredCount += 1;
        } catch (_) {
          continue;
        }
      }

      if (restoredCount == 0) {
        throw StateError(
          context.isZh ? '没有可撤回的指令记录' : 'No instruction history',
        );
      }

      ref.invalidate(
        getMemoryBreakpointStateProvider(pid: selectedProcess.pid),
      );
      ref.invalidate(getMemoryBreakpointsProvider(pid: selectedProcess.pid));
      ref.invalidate(getMemoryBreakpointHitsProvider(pid: selectedProcess.pid));
      await browseNotifier.refreshVisibleInstructionResults(
        addresses: selectedInstructionResults.map((result) => result.address),
      );
      await ToastOverlayMessage.show(
        context.isZh
            ? '已撤回$restoredCount条指令'
            : 'Restored $restoredCount instructions',
        duration: const Duration(milliseconds: 1400),
      );
    }

    final resultList = browseState.hasAnchor
        ? MemoryToolBrowseResultList(
            listStorageKey: PageStorageKey<String>(
              'memory_tool_browse_results_${selectedProcess.pid}_${browseState.anchorAddress ?? 0}_${browseState.focusRequestId}',
            ),
            focusRequestId: browseState.focusRequestId,
            scrollController: scrollController,
            results: visibleResults,
            anchorAddress: browseState.anchorAddress,
            isSelected: browseState.selectionState.contains,
            onToggleSelection: browseNotifier.toggle,
            livePreviewsAsync: resolvedLivePreviewsAsync,
            previousValueByAddress: previousValueByAddress,
            processPid: selectedProcess.pid,
            initialFrozenStateByAddress: <int, bool>{
              for (final address in currentFrozenAddresses) address: true,
            },
            onNavigateToAddress:
                (result, preview, displayValue, targetAddress) async {
                  await browseNotifier.previewFromAddress(
                    sourceResult: result.toSearchResult(),
                    sourcePreview: preview,
                    targetAddress: targetAddress,
                    preferInstructionMode: result.isInstruction,
                  );
                },
            onJumpToPointer: jumpToPointer,
            onStartAutoChase: (PointerScanRequest request, int maxDepth) async {
              onOpenPointerTab();
              await ref
                  .read(memoryToolPointerControllerProvider.notifier)
                  .startAutoChase(request: request, maxDepth: maxDepth);
            },
            onStartPointerScan: (PointerScanRequest request) async {
              onOpenPointerTab();
              await ref
                  .read(memoryToolPointerControllerProvider.notifier)
                  .startRootScan(request: request);
            },
            onOpenDebugTab: onOpenDebugTab,
          )
        : _MemoryToolBrowseEmptyState(
            message: context.l10n.memoryToolBrowseEmpty,
          );

    return Stack(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(12.r),
          child: Column(
            children: <Widget>[
              MemoryToolResultSelectionBar(
                actions: <MemoryToolResultSelectionActionData>[
                  MemoryToolResultSelectionActionData(
                    icon: Icons.my_location_rounded,
                    onTap: browseState.hasAnchor
                        ? () async {
                            await browseNotifier.recenter();
                            if (!context.mounted) {
                              return;
                            }
                          }
                        : null,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: processPausedAsync.asData?.value ?? false
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    onTap:
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
                                    pid: selectedProcess.pid,
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
                            browseNotifier.selectVisible(visibleResults);
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.flip_rounded,
                    onTap: visibleResults.isEmpty
                        ? null
                        : () {
                            browseNotifier.invertVisible(visibleResults);
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.layers_clear_rounded,
                    onTap: visibleResults.isEmpty
                        ? null
                        : browseNotifier.clearSelection,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.save_alt_rounded,
                    onTap: selectedResults.isEmpty
                        ? null
                        : () async {
                            await saveResultsToSaved(selectedResults);
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.calculate_outlined,
                    onTap: canCalculateSelectedResults
                        ? () {
                            isCalculatorVisible.value = true;
                          }
                        : null,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.code_rounded,
                    onTap: selectedResults.isEmpty
                        ? null
                        : () {
                            assemblyPreviewAddresses.value = selectedResults
                                .map((result) => result.address)
                                .toList(growable: false);
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.edit_rounded,
                    onTap: canEditSelectedValues
                        ? () {
                            isBatchEditVisible.value = true;
                          }
                        : canEditSelectedInstructions
                        ? () {
                            activeInstructionBatchEditor.value =
                                resolveBatchInstructionInitialValue();
                          }
                        : null,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.undo_rounded,
                    onTap: canRestorePrevious
                        ? () async {
                            try {
                              if (canRestoreInstructionHistory) {
                                await restoreSelectedInstructions();
                              } else {
                                final sessionState = await ref.read(
                                  getSearchSessionStateProvider.future,
                                );
                                await ref
                                    .read(memoryValueActionProvider.notifier)
                                    .restorePreviousValues(
                                      addresses: browseState
                                          .selectionState
                                          .selectedAddresses,
                                      littleEndian: sessionState.littleEndian,
                                    );
                              }
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
              SizedBox(height: 8.r),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child:
                          browseState.isInitializing && !browseState.hasAnchor
                          ? const Loading()
                          : browseState.errorText != null &&
                                !browseState.hasAnchor
                          ? _MemoryToolBrowseEmptyState(
                              message: browseState.errorText!,
                            )
                          : visibleResults.isEmpty && browseState.hasAnchor
                          ? _MemoryToolBrowseEmptyState(
                              message: context.l10n.noData,
                            )
                          : resultList,
                    ),
                    if (browseState.isInitializing && browseState.hasAnchor)
                      const Positioned.fill(
                        child: _MemoryToolBrowseLoadingMask(),
                      ),
                    if (browseState.isLoadingAbove)
                      const Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: _MemoryToolBrowseEdgeLoader(isTop: true),
                      ),
                    if (browseState.isLoadingBelow)
                      const Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: _MemoryToolBrowseEdgeLoader(isTop: false),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 6.r),
              MemoryToolResultStatsBar(
                resultCount: visibleResultCount,
                selectedCount: browseState.selectionState.selectedCount,
                renderedCount: visibleResults.length,
                pageCount: pageCount,
              ),
            ],
          ),
        ),
        if (isSettingsVisible.value)
          Positioned.fill(
            child: MemoryToolResultSelectionDialog(
              initialLimit: browseState.selectionState.selectionLimit,
              title: context.l10n.memoryToolResultSelectionDialogTitle,
              fieldLabel: context.l10n.memoryToolResultSelectionFieldLabel,
              onClose: () {
                isSettingsVisible.value = false;
              },
              onConfirm: (value) {
                browseNotifier.updateSelectionLimit(value);
                isSettingsVisible.value = false;
              },
            ),
          ),
        if (isBatchEditVisible.value)
          Positioned.fill(
            child: MemoryToolBatchEditDialog(
              results: selectedValueResults
                  .map((result) => result.toSearchResult())
                  .toList(growable: false),
              livePreviewsAsync: resolvedLivePreviewsAsync,
              savedSyncMode: MemoryToolBatchEditSavedSyncMode.frozenOnly,
              onClose: () {
                isBatchEditVisible.value = false;
              },
            ),
          ),
        if (activeInstructionBatchEditor.value case final initialValue?)
          Positioned.fill(
            child: MemoryToolDebugInstructionEditorDialog(
              initialValue: initialValue,
              onSave: (value) async {
                return await patchSelectedInstructions(value);
              },
              onClose: () {
                activeInstructionBatchEditor.value = null;
              },
            ),
          ),
        if (isCalculatorVisible.value)
          Positioned.fill(
            child: MemoryToolResultCalculatorDialog(
              results: selectedResults
                  .map((result) => result.toSearchResult())
                  .toList(growable: false),
              livePreviewsAsync: resolvedLivePreviewsAsync,
              onClose: () {
                isCalculatorVisible.value = false;
              },
            ),
          ),
        if (assemblyPreviewAddresses.value != null)
          Positioned.fill(
            child: MemoryToolAssemblyPreviewDialog(
              pid: selectedProcess.pid,
              addresses: assemblyPreviewAddresses.value!,
              onClose: () {
                assemblyPreviewAddresses.value = null;
              },
            ),
          ),
      ],
    );
  }
}

class _MemoryToolBrowseEmptyState extends StatelessWidget {
  const _MemoryToolBrowseEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.r),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.66),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MemoryToolBrowseLoadingMask extends StatelessWidget {
  const _MemoryToolBrowseLoadingMask();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.12),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18.r),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.r, vertical: 14.r),
              child: SizedBox(
                width: 28.r,
                height: 28.r,
                child: CircularProgressIndicator(strokeWidth: 2.4.r),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoryToolBrowseEdgeLoader extends StatelessWidget {
  const _MemoryToolBrowseEdgeLoader({required this.isTop});

  final bool isTop;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 10.r),
            child: SizedBox(
              width: 14.r,
              height: 14.r,
              child: CircularProgressIndicator(strokeWidth: 2.r),
            ),
          ),
        ),
      ),
    );
  }
}
