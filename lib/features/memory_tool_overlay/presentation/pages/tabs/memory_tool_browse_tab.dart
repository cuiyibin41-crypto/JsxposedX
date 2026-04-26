import 'dart:async';
import 'dart:typed_data';

import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_display_item.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_entry_kind.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_breakpoint_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_instruction_history_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_pointer_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_export_util.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_pointer_utils.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_browse_result_list.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_batch_edit_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_debug_instruction_editor_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_group_search_chain_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_calculator_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_stats_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_settings_dialog.dart';
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
    final isToolConfigVisible = useState(false);
    final isBatchEditVisible = useState(false);
    final isCalculatorVisible = useState(false);
    final isGroupSearchChainVisible = useState(false);
    final activeInstructionBatchEditor = useState<String?>(null);
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
          final shouldAutoFillViewport = position.maxScrollExtent <= 0;
          if (!shouldAutoFillViewport) {
            return;
          }
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
        browseState.focusRequestId,
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
    List<MemoryToolDisplayItem> resolveDisplayOrderedResults(
      List<MemoryToolDisplayItem> results,
    ) {
      final anchorAddress = browseState.anchorAddress;
      if (anchorAddress == null) {
        return results;
      }
      final anchorIndex = results.indexWhere(
        (result) => result.address == anchorAddress,
      );
      if (anchorIndex < 0 || anchorIndex >= results.length) {
        return results;
      }
      return <MemoryToolDisplayItem>[
        ...results.take(anchorIndex).toList(growable: false).reversed,
        results[anchorIndex],
        ...results.skip(anchorIndex + 1),
      ];
    }

    final displayOrderedResults = resolveDisplayOrderedResults(visibleResults);
    final selectedResults = displayOrderedResults
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
      return selectedInstructionResults
          .map((result) => result.effectiveDisplayValue.trim())
          .join('\n');
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
          savedItemsNotifier.saveEntry(
            pid: selectedProcess.pid,
            result: result.toSearchResult(),
            preview: resolvedPreviewMap[result.address],
            isFrozen: currentFrozenAddresses.contains(result.address),
            entryKind: MemoryToolEntryKind.instruction,
            instructionText: result.effectiveDisplayValue,
          );
        } else {
          valueResults.add(result.toSearchResult());
        }
      }
      if (valueResults.isNotEmpty) {
        savedItemsNotifier.saveEntries(
          pid: selectedProcess.pid,
          results: valueResults,
          previewsByAddress: resolvedPreviewMap,
          frozenAddresses: currentFrozenAddresses,
        );
      }
      await showSavedToast(resultList.length);
    }

    Future<void> exportSelectedResults(
      List<MemoryToolDisplayItem> results,
    ) async {
      if (results.isEmpty) {
        return;
      }
      await exportMemoryToolItemsToLocal(
        context: context,
        ref: ref,
        sourceKey: 'browse',
        pid: selectedProcess.pid,
        items: results
            .map((result) {
              final preview = resolvedPreviewMap[result.address];
              final isInstruction = result.isInstruction;
              final resolvedDisplayValue = isInstruction
                  ? result.effectiveDisplayValue
                  : (preview?.displayValue ?? result.displayValue);
              return MemoryToolExportItem(
                pid: selectedProcess.pid,
                address: result.address,
                regionStart: result.regionStart,
                regionTypeKey: result.regionTypeKey,
                valueType: preview?.type ?? result.type,
                displayValue: resolvedDisplayValue,
                rawBytes: preview?.rawBytes ?? result.rawBytes,
                isFrozen: currentFrozenAddresses.contains(result.address),
                entryKind: result.entryKind,
                instructionText: isInstruction
                    ? result.effectiveDisplayValue
                    : null,
              );
            })
            .toList(growable: false),
        meta: <String, Object?>{
          'anchor_address': browseState.anchorAddress == null
              ? null
              : formatMemoryToolSearchResultAddress(browseState.anchorAddress!),
        },
      );
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
      final rawLines = value
          .split('\n')
          .map((line) => line.trim())
          .toList(growable: false);
      final nonEmptyLines = rawLines
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      if (nonEmptyLines.isEmpty) {
        return context.isZh ? '指令不能为空' : 'Instruction is required';
      }
      if (rawLines.any((line) => line.isEmpty) && nonEmptyLines.length > 1) {
        return context.isZh
            ? '每一行都要有指令'
            : 'Each line must contain an instruction';
      }

      late final List<String> instructions;
      if (nonEmptyLines.length == 1) {
        instructions = List<String>.filled(
          selectedInstructionResults.length,
          nonEmptyLines.first,
        );
      } else if (nonEmptyLines.length == selectedInstructionResults.length) {
        instructions = nonEmptyLines;
      } else {
        return context.isZh
            ? '请输入1行，或与选中条目数一致的指令行数'
            : 'Enter one line, or the same number of instruction lines as selected items';
      }

      var patchedCount = 0;
      var failedCount = 0;
      final historyNotifier = ref.read(
        memoryToolInstructionHistoryProvider.notifier,
      );
      for (
        var index = 0;
        index < selectedInstructionResults.length;
        index += 1
      ) {
        final result = selectedInstructionResults[index];
        final instruction = instructions[index];
        try {
          final patchResult = await ref
              .read(memoryValueActionProvider.notifier)
              .patchMemoryInstruction(
                request: MemoryInstructionPatchRequest(
                  pid: selectedProcess.pid,
                  address: result.address,
                  instruction: instruction,
                ),
              );
          historyNotifier.record(
            pid: selectedProcess.pid,
            address: result.address,
            previousBytes: patchResult.beforeBytes,
            previousDisplayValue: result.effectiveDisplayValue,
          );
          patchedCount += 1;
        } catch (_) {
          failedCount += 1;
        }
      }

      if (patchedCount == 0) {
        return context.isZh ? '修改失败' : 'Patch failed';
      }

      activeInstructionBatchEditor.value = null;
      unawaited(
        ToastOverlayMessage.show(
          context.isZh
              ? (failedCount == 0
                    ? '已批量修改$patchedCount条指令'
                    : '已修改$patchedCount条，失败$failedCount条')
              : (failedCount == 0
                    ? 'Patched $patchedCount instructions'
                    : 'Patched $patchedCount, failed $failedCount'),
          duration: const Duration(milliseconds: 1400),
        ),
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
                groups: <MemoryToolResultSelectionActionGroupData>[
                  MemoryToolResultSelectionActionGroupData(
                    icon: Icons.explore_rounded,
                    label: context.isZh ? '定位与进程' : 'Locate & Process',
                    actions: <MemoryToolResultSelectionActionData>[
                      MemoryToolResultSelectionActionData(
                        icon: Icons.my_location_rounded,
                        label: context.isZh ? '回到锚点' : 'Recenter Anchor',
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
                        label: processPausedAsync.asData?.value ?? false
                            ? (context.isZh ? '继续进程' : 'Resume Process')
                            : (context.isZh ? '暂停进程' : 'Pause Process'),
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
                                        memoryProcessControlActionProvider
                                            .notifier,
                                      )
                                      .setProcessPaused(
                                        pid: selectedProcess.pid,
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
                                browseNotifier.selectVisible(visibleResults);
                              },
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.flip_rounded,
                        label: context.isZh ? '反选可见' : 'Invert Visible',
                        onTap: visibleResults.isEmpty
                            ? null
                            : () {
                                browseNotifier.invertVisible(visibleResults);
                              },
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.layers_clear_rounded,
                        label: context.isZh ? '清空选择' : 'Clear Selection',
                        onTap: visibleResults.isEmpty
                            ? null
                            : browseNotifier.clearSelection,
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
                                await saveResultsToSaved(selectedResults);
                              },
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.ios_share_rounded,
                        label: context.isZh ? '导出' : 'Export',
                        onTap: selectedResults.isEmpty
                            ? null
                            : () async {
                                await exportSelectedResults(selectedResults);
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
                        onTap: canCalculateSelectedResults
                            ? () {
                                isCalculatorVisible.value = true;
                              }
                            : null,
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.link_rounded,
                        label: context.isZh ? '复制联合特征链' : 'Copy Chain',
                        onTap: selectedValueResults.length >= 2
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
                        label: context.isZh ? '恢复上次值' : 'Restore Previous',
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
                                        .read(
                                          memoryValueActionProvider.notifier,
                                        )
                                        .restorePreviousValues(
                                          addresses: browseState
                                              .selectionState
                                              .selectedAddresses,
                                          littleEndian:
                                              sessionState.littleEndian,
                                        );
                                  }
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
        if (isGroupSearchChainVisible.value)
          Positioned.fill(
            child: MemoryToolGroupSearchChainDialog(
              results: selectedValueResults
                  .map((result) => result.toSearchResult())
                  .toList(growable: false),
              livePreviewsAsync: resolvedLivePreviewsAsync,
              onClose: () {
                isGroupSearchChainVisible.value = false;
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
