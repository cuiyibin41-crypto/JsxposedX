import 'dart:async';
import 'dart:async';
import 'dart:typed_data';

import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_saved_item.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_breakpoint_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_instruction_history_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_pointer_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_instruction_patches_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_pointer_utils.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_batch_edit_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_breakpoint_config_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_debug_instruction_editor_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_copy_value_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_offset_preview_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_pointer_scan_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_calculator_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_stats_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_action_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_tile.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart'
    show MemoryValuePreview, PointerScanRequest, SearchResult, SearchValueType, MemoryInstructionPatchRequest;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolSavedTab extends HookConsumerWidget {
  const MemoryToolSavedTab({
    super.key,
    required this.onOpenBrowseTab,
    required this.onOpenPointerTab,
    required this.onOpenDebugTab,
  });

  final VoidCallback onOpenBrowseTab;
  final VoidCallback onOpenPointerTab;
  final VoidCallback onOpenDebugTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final selectedPid = selectedProcess?.pid;
    final savedItems = ref.watch(savedItemsForSelectedProcessProvider);
    final savedInstructionPatches = ref.watch(
      memoryToolSavedInstructionPatchesProvider.select(
        (state) => selectedPid == null
            ? const <MemoryToolSavedInstructionPatch>[]
            : (state.patchesByPid[selectedPid] ??
                      const <int, MemoryToolSavedInstructionPatch>{})
                  .values
                  .toList(growable: false)
              ..sort((left, right) => left.address.compareTo(right.address)),
      ),
    );
    final selectionState = ref.watch(memoryToolSavedItemSelectionProvider);
    final selectionNotifier = ref.read(
      memoryToolSavedItemSelectionProvider.notifier,
    );
    final savedItemsNotifier = ref.read(memoryToolSavedItemsProvider.notifier);
    final savedInstructionPatchesNotifier = ref.read(
      memoryToolSavedInstructionPatchesProvider.notifier,
    );
    final browseNotifier = ref.read(
      memoryToolBrowseControllerProvider.notifier,
    );
    final pointerNotifier = ref.read(
      memoryToolPointerControllerProvider.notifier,
    );
    final livePreviewsAsync = ref.watch(currentSavedItemLivePreviewsProvider);
    final frozenValuesAsync = ref.watch(currentFrozenMemoryValuesProvider);
    final valueHistoryState = ref.watch(memoryValueHistoryProvider);
    final instructionHistoryByAddress = ref.watch(
      memoryToolInstructionHistoryProvider.select(
        (state) => selectedPid == null
            ? const <int, MemoryToolInstructionHistoryEntry>{}
            : (state.entriesByPid[selectedPid] ??
                  const <int, MemoryToolInstructionHistoryEntry>{}),
      ),
    );
    final valueActionState = ref.watch(memoryValueActionProvider);
    final isBatchEditVisible = useState(false);
    final isCalculatorVisible = useState(false);
    final activeDialog =
        useState<({MemoryToolSavedItem item, String displayValue})?>(null);
    final activeActionDialog =
        useState<({MemoryToolSavedItem item, String displayValue})?>(null);
    final activeCopyValueDialog =
        useState<({MemoryToolSavedItem item, String displayValue})?>(null);
    final activeOffsetPreviewDialog =
        useState<({MemoryToolSavedItem item, String displayValue})?>(null);
    final activeAutoChaseDialog = useState<MemoryToolSavedItem?>(null);
    final activePointerScanDialog = useState<MemoryToolSavedItem?>(null);
    final activeBreakpointDialog = useState<MemoryToolSavedItem?>(null);
    final activeInstructionActionDialog =
        useState<MemoryToolSavedInstructionPatch?>(null);
    final activeInstructionEditor =
        useState<MemoryToolSavedInstructionPatch?>(null);
    final selectedInstructionAddresses = useState<Set<int>>(<int>{});

    useEffect(() {
      selectionNotifier.retainVisible(
        savedItems.map((item) => item.address).toList(growable: false),
      );
      return null;
    }, [selectedPid, savedItems]);

    useEffect(() {
      final visibleAddresses = savedInstructionPatches
          .map((item) => item.address)
          .toSet();
      final nextSelected = selectedInstructionAddresses.value
          .where(visibleAddresses.contains)
          .toSet();
      if (nextSelected.length != selectedInstructionAddresses.value.length) {
        selectedInstructionAddresses.value = nextSelected;
      }
      return null;
    }, [selectedPid, savedInstructionPatches]);

    final previewMap =
        livePreviewsAsync.asData?.value ?? const <int, MemoryValuePreview>{};
    final currentFrozenAddresses = selectedPid == null
        ? null
        : frozenValuesAsync.asData?.value
              ?.where((value) => value.pid == selectedPid)
              .map((value) => value.address)
              .toSet();
    final selectedItems = savedItems
        .where((item) => selectionState.contains(item.address))
        .toList(growable: false);
    final selectedInstructionPatches = savedInstructionPatches
        .where((item) => selectedInstructionAddresses.value.contains(item.address))
        .toList(growable: false);
    final hasInstructionSection = savedInstructionPatches.isNotEmpty;
    final hasValueSection = savedItems.isNotEmpty;
    final totalSavedEntryCount =
        savedInstructionPatches.length + savedItems.length;
    final totalListItemCount =
        totalSavedEntryCount +
        (hasInstructionSection ? 1 : 0) +
        (hasValueSection ? 1 : 0);
    final previousValueByAddress = <int, String>{
      for (final entry in valueHistoryState.entries)
        entry.key: entry.value.displayValue,
    };
    final canRestorePrevious = selectionState.selectedAddresses.any(
      valueHistoryState.containsKey,
    );
    final canRestorePreviousInstructions = selectedInstructionAddresses.value.any(
      instructionHistoryByAddress.containsKey,
    );
    final totalSelectedCount =
        selectionState.selectedCount + selectedInstructionAddresses.value.length;

    void clearAllSelection() {
      selectionNotifier.clearSelection();
      selectedInstructionAddresses.value = <int>{};
    }

    void selectAllVisible() {
      selectionNotifier.selectVisible(savedItems.map((item) => item.address));
      selectedInstructionAddresses.value = savedInstructionPatches
          .map((item) => item.address)
          .toSet();
    }

    void invertAllVisible() {
      selectionNotifier.invertVisible(savedItems.map((item) => item.address));
      final visibleInstructionAddresses = savedInstructionPatches
          .map((item) => item.address)
          .toSet();
      final currentSelected = selectedInstructionAddresses.value;
      selectedInstructionAddresses.value = <int>{
        for (final address in visibleInstructionAddresses)
          if (!currentSelected.contains(address)) address,
      };
    }

    void toggleInstructionSelection(int address) {
      final nextSelected = <int>{...selectedInstructionAddresses.value};
      if (!nextSelected.add(address)) {
        nextSelected.remove(address);
      }
      selectedInstructionAddresses.value = nextSelected;
    }

    Future<void> restoreAddresses(List<int> addresses) async {
      try {
        final sessionState = await ref.read(
          getSearchSessionStateProvider.future,
        );
        await ref
            .read(memoryValueActionProvider.notifier)
            .restorePreviousValues(
              addresses: addresses,
              littleEndian: sessionState.littleEndian,
            );
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }

    Future<void> copyText(String value) async {
      final copied = await FlutterOverlayWindow.setClipboardData(value);
      ref
          .read(overlayWindowHostRuntimeProvider.notifier)
          .showToast(copied ? context.l10n.codeCopied : context.l10n.error);
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
        ref
            .read(overlayWindowHostRuntimeProvider.notifier)
            .showToast(context.l10n.memoryToolOffsetPreviewUnreadable);
      }
    }

    Future<void> jumpToPointer(
      MemoryToolSavedItem item,
      String displayValue,
    ) async {
      final preview = previewMap[item.address];
      final targetAddress = decodeMemoryToolPointerAddress(
        preview?.rawBytes ?? item.rawBytes,
      );
      if (targetAddress == null) {
        ref
            .read(overlayWindowHostRuntimeProvider.notifier)
            .showToast(context.l10n.memoryToolOffsetPreviewUnreadable);
        return;
      }

      await previewAndOpenBrowse(
        () => browseNotifier.previewFromAddress(
          sourceResult: item.toSearchResult(),
          sourcePreview: preview,
          targetAddress: targetAddress,
        ),
      );
    }

    Future<String?> saveInstructionPatch(
      MemoryToolSavedInstructionPatch patch,
      String value,
    ) async {
      final trimmedValue = value.trim();
      if (selectedPid == null) {
        return context.l10n.selectApp;
      }
      final failurePrefix = context.isZh ? '修改失败' : 'Patch failed';
      final fallbackErrorMessage = context.l10n.error;
      try {
        final result = await ref
            .read(memoryValueActionProvider.notifier)
            .patchMemoryInstruction(
              request: MemoryInstructionPatchRequest(
                pid: selectedPid,
                address: patch.address,
                instruction: trimmedValue,
              ),
            );
        ref.read(memoryToolInstructionHistoryProvider.notifier).record(
          pid: selectedPid,
          address: patch.address,
          previousBytes: result.beforeBytes,
        );
        savedInstructionPatchesNotifier.saveOne(
          pid: selectedPid,
          address: patch.address,
          instructionText: result.instructionText,
        );
        activeInstructionEditor.value = null;
        unawaited(
          ToastOverlayMessage.show(
            context.isZh ? '指令已修改' : 'Instruction patched',
            duration: const Duration(milliseconds: 1200),
          ),
        );
        return null;
      } catch (error) {
        final message = error.toString().replaceFirst('Exception: ', '').trim();
        final resolvedMessage =
            message.isEmpty ? fallbackErrorMessage : message;
        unawaited(
          ToastOverlayMessage.show(
            '$failurePrefix: $resolvedMessage',
            duration: const Duration(milliseconds: 1600),
          ),
        );
        return resolvedMessage;
      }
    }

    String encodeInstructionBytesHex(Uint8List bytes) {
      return <String>[
        for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
      ].join(' ');
    }

    Future<void> restoreInstructionPatches(List<int> addresses) async {
      if (selectedPid == null) {
        return;
      }
      final historyEntries = addresses
          .map((address) => instructionHistoryByAddress[address])
          .whereType<MemoryToolInstructionHistoryEntry>()
          .toList(growable: false);
      if (historyEntries.isEmpty) {
        return;
      }

      for (final entry in historyEntries) {
        try {
          final result = await ref
              .read(memoryValueActionProvider.notifier)
              .patchMemoryInstruction(
                request: MemoryInstructionPatchRequest(
                  pid: selectedPid,
                  address: entry.address,
                  instruction: encodeInstructionBytesHex(entry.previousBytes),
                ),
              );
          ref.read(memoryToolInstructionHistoryProvider.notifier).record(
            pid: selectedPid,
            address: entry.address,
            previousBytes: result.beforeBytes,
          );
          savedInstructionPatchesNotifier.saveOne(
            pid: selectedPid,
            address: entry.address,
            instructionText: result.instructionText,
          );
        } catch (_) {
          continue;
        }
      }
    }

    if (selectedPid == null) {
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

    return Stack(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(12.r),
          child: Column(
            children: <Widget>[
              MemoryToolResultSelectionBar(
                actions: <MemoryToolResultSelectionActionData>[
                  MemoryToolResultSelectionActionData(
                    icon: Icons.done_all_rounded,
                    onTap: totalSavedEntryCount == 0 ? null : selectAllVisible,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.flip_rounded,
                    onTap: totalSavedEntryCount == 0 ? null : invertAllVisible,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.layers_clear_rounded,
                    onTap: totalSelectedCount == 0 ? null : clearAllSelection,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.edit_rounded,
                    onTap: selectedItems.isNotEmpty
                        ? () {
                            isBatchEditVisible.value = true;
                          }
                        : selectedInstructionPatches.length == 1
                        ? () {
                            activeInstructionEditor.value =
                                selectedInstructionPatches.single;
                          }
                        : null,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.calculate_outlined,
                    onTap: selectedItems.length >= 2
                        ? () {
                            isCalculatorVisible.value = true;
                          }
                        : null,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.undo_rounded,
                    onTap:
                        (canRestorePrevious ||
                            canRestorePreviousInstructions) &&
                            !valueActionState.isLoading
                        ? () async {
                            if (selectionState.selectedAddresses.isNotEmpty) {
                              await restoreAddresses(
                                selectionState.selectedAddresses,
                              );
                            }
                            if (selectedInstructionAddresses.value.isNotEmpty) {
                              await restoreInstructionPatches(
                                selectedInstructionAddresses.value
                                    .toList(growable: false),
                              );
                            }
                          }
                        : null,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.delete_sweep_rounded,
                    onTap:
                        selectedItems.isEmpty &&
                            selectedInstructionPatches.isEmpty
                        ? null
                        : () {
                            if (selectionState.selectedAddresses.isNotEmpty) {
                              savedItemsNotifier.removeSelected(
                                pid: selectedPid,
                                addresses: selectionState.selectedAddresses,
                              );
                            }
                            for (final patch in selectedInstructionPatches) {
                              savedInstructionPatchesNotifier.removeOne(
                                pid: selectedPid,
                                address: patch.address,
                              );
                              ref
                                  .read(
                                    memoryToolInstructionHistoryProvider.notifier,
                                  )
                                  .remove(pid: selectedPid, address: patch.address);
                            }
                            clearAllSelection();
                          },
                  ),
                ],
              ),
              SizedBox(height: 8.r),
              Expanded(
                child: savedItems.isEmpty && savedInstructionPatches.isEmpty
                    ? Center(
                        child: Text(
                          context.l10n.memoryToolSavedEmpty,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurface.withValues(
                              alpha: 0.66,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        key: PageStorageKey<String>(
                          'memory_tool_saved_results_$selectedPid',
                        ),
                        padding: EdgeInsets.zero,
                        itemCount: totalListItemCount,
                        separatorBuilder: (_, index) => SizedBox(
                          height: index == totalListItemCount - 1 ? 6.r : 4.r,
                        ),
                        itemBuilder: (context, index) {
                          var cursor = 0;
                          if (hasInstructionSection && index == cursor) {
                            return _MemoryToolSavedSectionHeader(
                              title: context.isZh
                                  ? '已保存指令'
                                  : 'Saved Instructions',
                              count: savedInstructionPatches.length,
                            );
                          }
                          if (hasInstructionSection) {
                            cursor += 1;
                          }
                          if (index < cursor + savedInstructionPatches.length) {
                            final patch =
                                savedInstructionPatches[index - cursor];
                            return _MemoryToolSavedInstructionPatchTile(
                              patch: patch,
                              isSelected: selectedInstructionAddresses.value
                                  .contains(patch.address),
                              onToggleSelection: () {
                                toggleInstructionSelection(patch.address);
                              },
                              onTap: () {
                                activeInstructionEditor.value = patch;
                              },
                              onLongPress: () {
                                activeInstructionActionDialog.value = patch;
                              },
                              onDelete: () {
                                savedInstructionPatchesNotifier.removeOne(
                                  pid: selectedPid,
                                  address: patch.address,
                                );
                                ref
                                    .read(
                                      memoryToolInstructionHistoryProvider.notifier,
                                    )
                                    .remove(pid: selectedPid, address: patch.address);
                              },
                            );
                          }
                          cursor += savedInstructionPatches.length;
                          if (hasValueSection && index == cursor) {
                            return _MemoryToolSavedSectionHeader(
                              title: context.isZh ? '已保存数值' : 'Saved Values',
                              count: savedItems.length,
                            );
                          }
                          if (hasValueSection) {
                            cursor += 1;
                          }
                          final itemIndex = index - cursor;
                          final item = savedItems[itemIndex];
                          final preview = previewMap[item.address];
                          final displayValue =
                              preview?.displayValue ?? item.displayValue;
                          final isFrozen =
                              currentFrozenAddresses?.contains(item.address) ??
                              item.isFrozen;
                          return MemoryToolSearchResultTile(
                            result: item.toSearchResult(),
                            displayValue: displayValue,
                            previousDisplayValue:
                                previousValueByAddress[item.address],
                            isFrozen: isFrozen,
                            isSelected: selectionState.contains(item.address),
                            onToggleSelection: () {
                              selectionNotifier.toggle(item.address);
                            },
                            onDeleteRecord: () {
                              selectionNotifier.removeAddress(item.address);
                              savedItemsNotifier.removeOne(
                                pid: selectedPid,
                                address: item.address,
                              );
                            },
                            onTap: () {
                              activeActionDialog.value = null;
                              activeDialog.value = (
                                item: item,
                                displayValue: displayValue,
                              );
                            },
                            onLongProcess: () {
                              activeDialog.value = null;
                              activeActionDialog.value = (
                                item: item,
                                displayValue: displayValue,
                              );
                            },
                          );
                        },
                      ),
              ),
              SizedBox(height: 6.r),
              MemoryToolResultStatsBar(
                resultCount: totalSavedEntryCount,
                selectedCount: totalSelectedCount,
                renderedCount: totalSavedEntryCount,
                pageCount: 0,
              ),
            ],
          ),
        ),
        if (activeDialog.value case final dialog?)
          Positioned.fill(
            child: MemoryToolSearchResultDialog(
              result: dialog.item.toSearchResult(),
              displayValue: dialog.displayValue,
              livePreviewsAsync: livePreviewsAsync,
              processPid: dialog.item.pid,
              initialFrozenState:
                  currentFrozenAddresses?.contains(dialog.item.address) ??
                  dialog.item.isFrozen,
              onClose: () {
                activeDialog.value = null;
              },
            ),
          ),
        if (activeActionDialog.value case final dialog?)
          Positioned.fill(
            child: MemoryToolSearchResultActionDialog(
              actions: <MemoryToolSearchResultActionItemData>[
                MemoryToolSearchResultActionItemData(
                  icon: Icons.auto_mode_rounded,
                  title: context.l10n.memoryToolResultActionAutoChaseStatic,
                  onTap: () async {
                    activeActionDialog.value = null;
                    activeAutoChaseDialog.value = dialog.item;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.account_tree_rounded,
                  title: context.l10n.memoryToolResultActionPointerScan,
                  onTap: () async {
                    activeActionDialog.value = null;
                    activePointerScanDialog.value = dialog.item;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.bug_report_rounded,
                  title: context.isZh ? '断点调试' : 'Breakpoint Debug',
                  onTap: () async {
                    activeActionDialog.value = null;
                    activeBreakpointDialog.value = dialog.item;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.subdirectory_arrow_right_rounded,
                  title: context.l10n.memoryToolResultActionJumpToPointer,
                  onTap: () async {
                    activeActionDialog.value = null;
                    await jumpToPointer(dialog.item, dialog.displayValue);
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.preview_rounded,
                  title: context.l10n.memoryToolResultActionPreviewMemoryBlock,
                  onTap: () async {
                    await previewAndOpenBrowse(
                      () => browseNotifier.previewFromSearchResult(
                        result: dialog.item.toSearchResult(),
                        preview: previewMap[dialog.item.address],
                        displayValue: dialog.displayValue,
                      ),
                    );
                    activeActionDialog.value = null;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.calculate_rounded,
                  title: context.l10n.memoryToolResultActionOffsetPreview,
                  onTap: () async {
                    activeActionDialog.value = null;
                    activeOffsetPreviewDialog.value = (
                      item: dialog.item,
                      displayValue: dialog.displayValue,
                    );
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.tune_rounded,
                  title: context.l10n.memoryToolResultDetailActionCopyValue,
                  onTap: () async {
                    activeActionDialog.value = null;
                    activeCopyValueDialog.value = (
                      item: dialog.item,
                      displayValue: dialog.displayValue,
                    );
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.copy_all_rounded,
                  title:
                      '${context.l10n.memoryToolResultDetailActionCopyAddress}: ${formatMemoryToolSearchResultAddress(dialog.item.address)}',
                  onTap: () async {
                    await copyText(
                      formatMemoryToolSearchResultAddress(dialog.item.address),
                    );
                    activeActionDialog.value = null;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.data_array_rounded,
                  title:
                      '${context.l10n.memoryToolResultActionCopyHex}: ${formatMemoryToolSearchResultHex(previewMap[dialog.item.address]?.rawBytes ?? dialog.item.rawBytes)}',
                  onTap: () async {
                    await copyText(
                      formatMemoryToolSearchResultHex(
                        previewMap[dialog.item.address]?.rawBytes ??
                            dialog.item.rawBytes,
                      ),
                    );
                    activeActionDialog.value = null;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.swap_horiz_rounded,
                  title:
                      '${context.l10n.memoryToolResultActionCopyReverseHex}: ${formatMemoryToolSearchResultReverseHex(previewMap[dialog.item.address]?.rawBytes ?? dialog.item.rawBytes)}',
                  onTap: () async {
                    await copyText(
                      formatMemoryToolSearchResultReverseHex(
                        previewMap[dialog.item.address]?.rawBytes ??
                            dialog.item.rawBytes,
                      ),
                    );
                    activeActionDialog.value = null;
                  },
                ),
              ],
              onClose: () {
                activeActionDialog.value = null;
              },
            ),
          ),
        if (activeInstructionActionDialog.value case final patch?)
          Positioned.fill(
            child: MemoryToolSearchResultActionDialog(
              actions: <MemoryToolSearchResultActionItemData>[
                MemoryToolSearchResultActionItemData(
                  icon: Icons.copy_all_rounded,
                  title:
                      '${context.isZh ? '复制指令' : 'Copy Instruction'}: ${patch.instructionText}',
                  onTap: () async {
                    await copyText(patch.instructionText);
                    activeInstructionActionDialog.value = null;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.pin_drop_rounded,
                  title:
                      '${context.isZh ? '复制地址' : 'Copy Address'}: ${formatMemoryToolSearchResultAddress(patch.address)}',
                  onTap: () async {
                    await copyText(
                      formatMemoryToolSearchResultAddress(patch.address),
                    );
                    activeInstructionActionDialog.value = null;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.preview_rounded,
                  title: context.isZh ? '浏览地址' : 'Browse Address',
                  onTap: () async {
                    activeInstructionActionDialog.value = null;
                    await previewAndOpenBrowse(
                      () => browseNotifier.previewRawAddress(
                        targetAddress: patch.address,
                        type: SearchValueType.bytes,
                        bytesLength: 4,
                      ),
                    );
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.bug_report_rounded,
                  title: context.isZh ? '切到断点调试' : 'Open Debug Tab',
                  onTap: () async {
                    activeInstructionActionDialog.value = null;
                    onOpenDebugTab();
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.delete_outline_rounded,
                  title: context.isZh ? '从暂存区移除' : 'Remove from Saved',
                  onTap: () async {
                    savedInstructionPatchesNotifier.removeOne(
                      pid: selectedPid,
                      address: patch.address,
                    );
                    ref
                        .read(memoryToolInstructionHistoryProvider.notifier)
                        .remove(pid: selectedPid, address: patch.address);
                    activeInstructionActionDialog.value = null;
                  },
                ),
              ],
              onClose: () {
                activeInstructionActionDialog.value = null;
              },
            ),
          ),
        if (activeInstructionEditor.value case final patch?)
          Positioned.fill(
            child: MemoryToolDebugInstructionEditorDialog(
              initialValue: patch.instructionText,
              onSave: (value) async {
                return await saveInstructionPatch(patch, value);
              },
              onClose: () {
                activeInstructionEditor.value = null;
              },
            ),
          ),
        if (activeAutoChaseDialog.value case final item?)
          Positioned.fill(
            child: MemoryToolPointerScanDialog(
              pid: item.pid,
              targetAddress: item.address,
              showMaxDepthField: true,
              onConfirmAutoChase: (request, maxDepth) async {
                onOpenPointerTab();
                await pointerNotifier.startAutoChase(
                  request: request,
                  maxDepth: maxDepth,
                );
              },
              onClose: () {
                activeAutoChaseDialog.value = null;
              },
            ),
          ),
        if (activePointerScanDialog.value case final item?)
          Positioned.fill(
            child: MemoryToolPointerScanDialog(
              pid: item.pid,
              targetAddress: item.address,
              onConfirm: (request) async {
                onOpenPointerTab();
                await pointerNotifier.startRootScan(request: request);
              },
              onClose: () {
                activePointerScanDialog.value = null;
              },
            ),
          ),
        if (activeBreakpointDialog.value case final item?)
          Positioned.fill(
            child: MemoryToolBreakpointConfigDialog(
              pid: item.pid,
              result: item.toSearchResult(),
              preview: previewMap[item.address],
              onConfirm: (request) async {
                final created = await ref
                    .read(memoryBreakpointActionProvider.notifier)
                    .addMemoryBreakpoint(request: request);
                ref
                    .read(memoryBreakpointSelectedIdProvider.notifier)
                    .set(created.id);
                onOpenDebugTab();
                activeBreakpointDialog.value = null;
              },
              onClose: () {
                activeBreakpointDialog.value = null;
              },
            ),
          ),
        if (activeOffsetPreviewDialog.value case final dialog?)
          Positioned.fill(
            child: MemoryToolOffsetPreviewDialog(
              result: dialog.item.toSearchResult(),
              displayValue: dialog.displayValue,
              livePreviewsAsync: livePreviewsAsync,
              onConfirm: (targetAddress) async {
                activeOffsetPreviewDialog.value = null;
                await previewAndOpenBrowse(
                  () => browseNotifier.previewFromAddress(
                    sourceResult: dialog.item.toSearchResult(),
                    sourcePreview: previewMap[dialog.item.address],
                    targetAddress: targetAddress,
                  ),
                );
              },
              onClose: () {
                activeOffsetPreviewDialog.value = null;
              },
            ),
          ),
        if (activeCopyValueDialog.value case final dialog?)
          Positioned.fill(
            child: MemoryToolCopyValueDialog(
              result: dialog.item.toSearchResult(),
              displayValue: dialog.displayValue,
              livePreviewsAsync: livePreviewsAsync,
              onClose: () {
                activeCopyValueDialog.value = null;
              },
            ),
          ),
        if (isBatchEditVisible.value)
          Positioned.fill(
            child: MemoryToolBatchEditDialog(
              results: selectedItems
                  .map((item) => item.toSearchResult())
                  .toList(growable: false),
              livePreviewsAsync: livePreviewsAsync,
              savedSyncMode: MemoryToolBatchEditSavedSyncMode.all,
              onClose: () {
                isBatchEditVisible.value = false;
              },
            ),
          ),
        if (isCalculatorVisible.value)
          Positioned.fill(
            child: MemoryToolResultCalculatorDialog(
              results: selectedItems
                  .map((item) => item.toSearchResult())
                  .toList(growable: false),
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

class _MemoryToolSavedSectionHeader extends StatelessWidget {
  const _MemoryToolSavedSectionHeader({
    required this.title,
    required this.count,
  });

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 4.r, bottom: 2.r),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.colorScheme.onSurface.withValues(alpha: 0.88),
              ),
            ),
          ),
          Text(
            '$count',
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryToolSavedInstructionPatchTile extends StatelessWidget {
  const _MemoryToolSavedInstructionPatchTile({
    required this.patch,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  final MemoryToolSavedInstructionPatch patch;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colorScheme.primaryContainer.withValues(alpha: 0.72)
                : context.colorScheme.surface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: isSelected
                  ? context.colorScheme.primary
                  : context.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Transform.scale(
                scale: 0.9,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10.r),
                  onTap: onToggleSelection,
                  child: Padding(
                    padding: EdgeInsets.all(2.r),
                    child: Icon(
                      isSelected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 22.r,
                      color: isSelected
                          ? context.colorScheme.primary
                          : context.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.72,
                            ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 4.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      patch.instructionText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.r),
                    Text(
                      formatMemoryToolSearchResultAddress(patch.address),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.r),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.close_rounded),
                color: context.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
