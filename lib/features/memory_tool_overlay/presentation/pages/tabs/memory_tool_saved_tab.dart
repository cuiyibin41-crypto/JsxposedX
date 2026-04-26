import 'dart:async';
import 'dart:typed_data';

import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_entry_kind.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_saved_item.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_breakpoint_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_instruction_history_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_pointer_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_export_util.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_pointer_utils.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_batch_edit_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_breakpoint_config_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_debug_instruction_editor_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_group_search_chain_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_copy_value_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_offset_preview_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_pointer_scan_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_calculator_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_stats_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_action_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_tile.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_settings_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart'
    show
        MemoryInstructionPreview,
        MemoryValuePreview,
        SearchResult,
        SearchValueType,
        MemoryInstructionPatchRequest;
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
    final selectionState = ref.watch(memoryToolSavedItemSelectionProvider);
    final selectionNotifier = ref.read(
      memoryToolSavedItemSelectionProvider.notifier,
    );
    final savedItemsNotifier = ref.read(memoryToolSavedItemsProvider.notifier);
    final browseNotifier = ref.read(
      memoryToolBrowseControllerProvider.notifier,
    );
    final pointerNotifier = ref.read(
      memoryToolPointerControllerProvider.notifier,
    );
    final livePreviewsAsync = ref.watch(currentSavedItemLivePreviewsProvider);
    final instructionPreviewsAsync = ref.watch(
      currentSavedInstructionPreviewsProvider,
    );
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
    final isGroupSearchChainVisible = useState(false);
    final isToolConfigVisible = useState(false);
    final activeInstructionBatchEditor = useState<String?>(null);
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
    final activeInstructionEditor = useState<MemoryToolSavedItem?>(null);

    useEffect(() {
      selectionNotifier.retainVisible(
        savedItems.map((item) => item.address).toList(growable: false),
      );
      return null;
    }, [selectedPid, savedItems]);

    final previewMap =
        livePreviewsAsync.asData?.value ?? const <int, MemoryValuePreview>{};
    final instructionPreviewMap =
        instructionPreviewsAsync.asData?.value ??
        const <int, MemoryInstructionPreview>{};
    final currentFrozenAddresses = selectedPid == null
        ? null
        : frozenValuesAsync.asData?.value
              ?.where((value) => value.pid == selectedPid)
              .map((value) => value.address)
              .toSet();
    final selectedItems = savedItems
        .where((item) => selectionState.contains(item.address))
        .toList(growable: false);
    final selectedInstructionItems = selectedItems
        .where((item) => item.isInstruction)
        .toList(growable: false);
    final selectedValueItems = selectedItems
        .where((item) => !item.isInstruction)
        .toList(growable: false);
    final totalSavedEntryCount = savedItems.length;
    final totalListItemCount = totalSavedEntryCount;
    final previousValueByAddress = <int, String>{
      for (final entry in valueHistoryState.entries)
        entry.key: entry.value.displayValue,
    };
    final canRestorePrevious = selectedItems.any(
      (item) => item.isInstruction
          ? instructionHistoryByAddress.containsKey(item.address)
          : valueHistoryState.containsKey(item.address),
    );
    final canEditSelectedValues =
        selectedValueItems.isNotEmpty && selectedInstructionItems.isEmpty;
    final canEditSelectedInstructions =
        selectedInstructionItems.isNotEmpty && selectedValueItems.isEmpty;
    final canCalculateSelectedResults = selectedItems.length >= 2;
    final totalSelectedCount = selectionState.selectedCount;

    void clearAllSelection() {
      selectionNotifier.clearSelection();
    }

    void selectAllVisible() {
      selectionNotifier.selectVisible(savedItems.map((item) => item.address));
    }

    void invertAllVisible() {
      selectionNotifier.invertVisible(savedItems.map((item) => item.address));
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
        await ToastOverlayMessage.show(
          error.toString().replaceFirst('Exception: ', ''),
          duration: const Duration(milliseconds: 1400),
        );
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

    String resolveSavedItemDisplayValue(MemoryToolSavedItem item) {
      if (!item.isInstruction) {
        return previewMap[item.address]?.displayValue ?? item.displayValue;
      }
      return instructionPreviewMap[item.address]?.instructionText ??
          item.effectiveInstructionText;
    }

    Uint8List resolveSavedItemRawBytes(MemoryToolSavedItem item) {
      if (!item.isInstruction) {
        return previewMap[item.address]?.rawBytes ?? item.rawBytes;
      }
      return instructionPreviewMap[item.address]?.rawBytes ?? item.rawBytes;
    }

    MemoryToolSavedItem resolveSavedItem(MemoryToolSavedItem item) {
      return item.copyWith(
        rawBytes: resolveSavedItemRawBytes(item),
        displayValue: resolveSavedItemDisplayValue(item),
        instructionText: item.isInstruction
            ? resolveSavedItemDisplayValue(item)
            : item.instructionText,
      );
    }

    Future<void> previewSavedItemAsValue(MemoryToolSavedItem item) async {
      await previewAndOpenBrowse(
        () => browseNotifier.previewValueFromSearchResult(
          result: resolveSavedItem(item).toSearchResult(),
          preview: previewMap[item.address],
          displayValue: resolveSavedItemDisplayValue(item),
        ),
      );
    }

    Future<void> previewSavedItemAsInstruction(MemoryToolSavedItem item) async {
      await previewAndOpenBrowse(
        () => browseNotifier.previewInstructionFromSearchResult(
          result: resolveSavedItem(item).toSearchResult(),
          preview: previewMap[item.address],
          displayValue: resolveSavedItemDisplayValue(item),
        ),
      );
    }

    Future<void> convertSavedItemToValue(MemoryToolSavedItem item) async {
      try {
        await savedItemsNotifier.saveResultAsValue(
          pid: item.pid,
          result: resolveSavedItem(item).toSearchResult(),
          isFrozen: item.isInstruction
              ? false
              : (currentFrozenAddresses?.contains(item.address) ??
                    item.isFrozen),
          type: item.type,
          bytesLength: resolveSavedItemRawBytes(item).isEmpty
              ? 1
              : resolveSavedItemRawBytes(item).length,
        );
        if (!context.mounted) {
          return;
        }
        await ToastOverlayMessage.show(
          context.isZh ? '已切换为数值条目' : 'Converted to value entry',
          duration: const Duration(milliseconds: 1200),
        );
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        final message = error.toString().replaceFirst('Exception: ', '').trim();
        await ToastOverlayMessage.show(
          message.isEmpty ? context.l10n.error : message,
          duration: const Duration(milliseconds: 1600),
        );
      }
    }

    Future<void> convertSavedItemToInstruction(MemoryToolSavedItem item) async {
      try {
        await savedItemsNotifier.saveResultAsInstruction(
          pid: item.pid,
          result: resolveSavedItem(item).toSearchResult(),
        );
        if (!context.mounted) {
          return;
        }
        await ToastOverlayMessage.show(
          context.isZh ? '已切换为汇编条目' : 'Converted to ASM entry',
          duration: const Duration(milliseconds: 1200),
        );
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        final message = error.toString().replaceFirst('Exception: ', '').trim();
        await ToastOverlayMessage.show(
          message.isEmpty ? context.l10n.error : message,
          duration: const Duration(milliseconds: 1600),
        );
      }
    }

    final resolvedSelectedItems = selectedItems
        .map(resolveSavedItem)
        .toList(growable: false);

    Future<void> exportSelectedItemsToLocal() async {
      if (resolvedSelectedItems.isEmpty) {
        return;
      }
      await exportMemoryToolItemsToLocal(
        context: context,
        ref: ref,
        sourceKey: 'saved',
        pid: selectedPid,
        items: resolvedSelectedItems
            .map((item) {
              final resolvedDisplayValue = resolveSavedItemDisplayValue(item);
              return MemoryToolExportItem(
                pid: item.pid,
                address: item.address,
                regionStart: item.regionStart,
                regionTypeKey: item.regionTypeKey,
                valueType: item.type,
                displayValue: resolvedDisplayValue,
                rawBytes: resolveSavedItemRawBytes(item),
                isFrozen: item.isInstruction
                    ? false
                    : (currentFrozenAddresses?.contains(item.address) ??
                          item.isFrozen),
                entryKind: item.entryKind,
                instructionText: item.isInstruction
                    ? resolvedDisplayValue
                    : null,
              );
            })
            .toList(growable: false),
      );
    }

    Future<void> jumpToPointer(MemoryToolSavedItem item) async {
      final preview = previewMap[item.address];
      final targetAddress = decodeMemoryToolPointerAddress(
        item.isInstruction
            ? resolveSavedItemRawBytes(item)
            : (preview?.rawBytes ?? item.rawBytes),
      );
      if (targetAddress == null) {
        ref
            .read(overlayWindowHostRuntimeProvider.notifier)
            .showToast(context.l10n.memoryToolOffsetPreviewUnreadable);
        return;
      }

      await previewAndOpenBrowse(
        () => item.isInstruction
            ? browseNotifier.previewInstructionFromAddress(
                sourceResult: resolveSavedItem(item).toSearchResult(),
                sourcePreview: preview,
                targetAddress: targetAddress,
              )
            : browseNotifier.previewValueFromAddress(
                sourceResult: resolveSavedItem(item).toSearchResult(),
                sourcePreview: preview,
                targetAddress: targetAddress,
              ),
      );
    }

    Future<String?> saveInstructionPatch(
      MemoryToolSavedItem item,
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
                address: item.address,
                instruction: trimmedValue,
              ),
            );
        ref
            .read(memoryToolInstructionHistoryProvider.notifier)
            .record(
              pid: selectedPid,
              address: item.address,
              previousBytes: result.beforeBytes,
              previousDisplayValue: item.effectiveInstructionText,
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
        final resolvedMessage = message.isEmpty
            ? fallbackErrorMessage
            : message;
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

    String resolveBatchInstructionInitialValue() {
      return selectedInstructionItems
          .map((item) => resolveSavedItemDisplayValue(item).trim())
          .join('\n');
    }

    Future<String?> patchSelectedInstructions(String value) async {
      if (selectedPid == null) {
        return context.l10n.selectApp;
      }
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
          selectedInstructionItems.length,
          nonEmptyLines.first,
        );
      } else if (nonEmptyLines.length == selectedInstructionItems.length) {
        instructions = nonEmptyLines;
      } else {
        return context.isZh
            ? '请输入1行，或与选中条目数一致的指令行数'
            : 'Enter one line, or the same number of instruction lines as selected items';
      }

      var patchedCount = 0;
      for (var index = 0; index < selectedInstructionItems.length; index += 1) {
        final item = selectedInstructionItems[index];
        final instruction = instructions[index];
        final resolvedItem = resolveSavedItem(item);
        try {
          final result = await ref
              .read(memoryValueActionProvider.notifier)
              .patchMemoryInstruction(
                request: MemoryInstructionPatchRequest(
                  pid: selectedPid,
                  address: item.address,
                  instruction: instruction,
                ),
              );
          ref
              .read(memoryToolInstructionHistoryProvider.notifier)
              .record(
                pid: selectedPid,
                address: item.address,
                previousBytes: result.beforeBytes,
                previousDisplayValue: resolvedItem.effectiveInstructionText,
              );
          patchedCount += 1;
        } catch (_) {
          continue;
        }
      }

      if (patchedCount == 0) {
        return context.isZh ? '修改失败' : 'Patch failed';
      }

      activeInstructionBatchEditor.value = null;
      unawaited(
        ToastOverlayMessage.show(
          context.isZh ? '指令已修改' : 'Instruction patched',
          duration: const Duration(milliseconds: 1200),
        ),
      );
      return null;
    }

    Future<void> restoreInstructionPatches(
      List<MemoryToolSavedItem> items,
    ) async {
      if (selectedPid == null) {
        return;
      }
      for (final item in items) {
        final entry = instructionHistoryByAddress[item.address];
        if (entry == null) {
          continue;
        }
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
          ref
              .read(memoryToolInstructionHistoryProvider.notifier)
              .record(
                pid: selectedPid,
                address: entry.address,
                previousBytes: result.beforeBytes,
                previousDisplayValue: item.effectiveInstructionText,
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
                groups: <MemoryToolResultSelectionActionGroupData>[
                  MemoryToolResultSelectionActionGroupData(
                    icon: Icons.check_box_rounded,
                    label: context.isZh ? '选择' : 'Selection',
                    actions: <MemoryToolResultSelectionActionData>[
                      MemoryToolResultSelectionActionData(
                        icon: Icons.done_all_rounded,
                        label: context.isZh ? '全选可见' : 'Select All',
                        onTap: totalSavedEntryCount == 0
                            ? null
                            : selectAllVisible,
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.flip_rounded,
                        label: context.isZh ? '反选' : 'Invert',
                        onTap: totalSavedEntryCount == 0
                            ? null
                            : invertAllVisible,
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.layers_clear_rounded,
                        label: context.isZh ? '清空选择' : 'Clear Selection',
                        onTap: totalSelectedCount == 0
                            ? null
                            : clearAllSelection,
                      ),
                    ],
                  ),
                  MemoryToolResultSelectionActionGroupData(
                    icon: Icons.tune_rounded,
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
                                    selectedInstructionItems.length == 1
                                    ? resolveSavedItemDisplayValue(
                                        selectedInstructionItems.single,
                                      )
                                    : resolveBatchInstructionInitialValue();
                              }
                            : null,
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.undo_rounded,
                        label: context.isZh ? '恢复上次值' : 'Restore Previous',
                        onTap: canRestorePrevious && !valueActionState.isLoading
                            ? () async {
                                if (selectedValueItems.isNotEmpty) {
                                  await restoreAddresses(
                                    selectedValueItems
                                        .map((item) => item.address)
                                        .toList(growable: false),
                                  );
                                }
                                if (selectedInstructionItems.isNotEmpty) {
                                  await restoreInstructionPatches(
                                    selectedInstructionItems,
                                  );
                                }
                              }
                            : null,
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
                        onTap: selectedValueItems.length >= 2
                            ? () {
                                isGroupSearchChainVisible.value = true;
                              }
                            : null,
                      ),
                    ],
                  ),
                  MemoryToolResultSelectionActionGroupData(
                    icon: Icons.ios_share_rounded,
                    label: context.isZh ? '导出与删除' : 'Export & Delete',
                    actions: <MemoryToolResultSelectionActionData>[
                      MemoryToolResultSelectionActionData(
                        icon: Icons.outbox_rounded,
                        label: context.isZh ? '导出' : 'Export',
                        onTap: selectedItems.isEmpty
                            ? null
                            : () async {
                                await exportSelectedItemsToLocal();
                              },
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.delete_sweep_rounded,
                        label: context.isZh ? '删除选中' : 'Delete Selected',
                        onTap: selectedItems.isEmpty
                            ? null
                            : () {
                                if (selectionState
                                    .selectedAddresses
                                    .isNotEmpty) {
                                  savedItemsNotifier.removeSelected(
                                    pid: selectedPid,
                                    addresses: selectionState.selectedAddresses,
                                  );
                                }
                                for (final item in selectedInstructionItems) {
                                  ref
                                      .read(
                                        memoryToolInstructionHistoryProvider
                                            .notifier,
                                      )
                                      .remove(
                                        pid: selectedPid,
                                        address: item.address,
                                      );
                                }
                                clearAllSelection();
                              },
                      ),
                    ],
                  ),
                  MemoryToolResultSelectionActionGroupData(
                    icon: Icons.tune_rounded,
                    label: context.isZh ? '设置' : 'Settings',
                    actions: <MemoryToolResultSelectionActionData>[
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
                child: savedItems.isEmpty
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
                          final item = savedItems[index];
                          final displayValue = resolveSavedItemDisplayValue(
                            item,
                          );
                          final isFrozen = item.isInstruction
                              ? false
                              : (currentFrozenAddresses?.contains(
                                      item.address,
                                    ) ??
                                    item.isFrozen);
                          return MemoryToolSearchResultTile(
                            result: resolveSavedItem(item).toSearchResult(),
                            displayValue: displayValue,
                            entryKind: item.entryKind,
                            instructionText: item.isInstruction
                                ? displayValue
                                : null,
                            typeLabelOverride: item.isInstruction
                                ? mapMemoryToolEntryTypeLabel(
                                    type: item.type,
                                    entryKind: item.entryKind,
                                    displayValue: displayValue,
                                  )
                                : null,
                            previousDisplayValue: item.isInstruction
                                ? instructionHistoryByAddress[item.address]
                                      ?.previousDisplayValue
                                : previousValueByAddress[item.address],
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
                              if (item.isInstruction) {
                                ref
                                    .read(
                                      memoryToolInstructionHistoryProvider
                                          .notifier,
                                    )
                                    .remove(
                                      pid: selectedPid,
                                      address: item.address,
                                    );
                              }
                            },
                            onTap: () {
                              activeActionDialog.value = null;
                              if (item.isInstruction) {
                                activeInstructionEditor.value = item;
                                return;
                              }
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
                    await jumpToPointer(dialog.item);
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.preview_rounded,
                  title: context.isZh
                      ? '以数值预览此地址'
                      : 'Preview This Address as Value',
                  onTap: () async {
                    await previewSavedItemAsValue(dialog.item);
                    activeActionDialog.value = null;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.code_rounded,
                  title: context.isZh
                      ? '以汇编预览此地址'
                      : 'Preview This Address as ASM',
                  onTap: () async {
                    await previewSavedItemAsInstruction(dialog.item);
                    activeActionDialog.value = null;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.swap_horiz_rounded,
                  title: context.isZh ? '切换为数值条目' : 'Convert to Value Entry',
                  onTap: () async {
                    await convertSavedItemToValue(dialog.item);
                    activeActionDialog.value = null;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.memory_rounded,
                  title: context.isZh ? '切换为汇编条目' : 'Convert to ASM Entry',
                  onTap: () async {
                    await convertSavedItemToInstruction(dialog.item);
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
                      '${context.l10n.memoryToolResultActionCopyHex}: ${formatMemoryToolSearchResultHex(resolveSavedItemRawBytes(dialog.item))}',
                  onTap: () async {
                    await copyText(
                      formatMemoryToolSearchResultHex(
                        resolveSavedItemRawBytes(dialog.item),
                      ),
                    );
                    activeActionDialog.value = null;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.swap_horiz_rounded,
                  title:
                      '${context.l10n.memoryToolResultActionCopyReverseHex}: ${formatMemoryToolSearchResultReverseHex(resolveSavedItemRawBytes(dialog.item))}',
                  onTap: () async {
                    await copyText(
                      formatMemoryToolSearchResultReverseHex(
                        resolveSavedItemRawBytes(dialog.item),
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
        if (activeInstructionEditor.value case final patch?)
          Positioned.fill(
            child: MemoryToolDebugInstructionEditorDialog(
              initialValue: patch.effectiveInstructionText,
              onSave: (value) async {
                return await saveInstructionPatch(patch, value);
              },
              onClose: () {
                activeInstructionEditor.value = null;
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
              result: resolveSavedItem(item).toSearchResult(),
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
              result: resolveSavedItem(dialog.item).toSearchResult(),
              displayValue: dialog.displayValue,
              livePreviewsAsync: livePreviewsAsync,
              onConfirm: (targetAddress) async {
                activeOffsetPreviewDialog.value = null;
                await previewAndOpenBrowse(
                  () => browseNotifier.previewValueFromAddress(
                    sourceResult: resolveSavedItem(
                      dialog.item,
                    ).toSearchResult(),
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
              result: resolveSavedItem(dialog.item).toSearchResult(),
              displayValue: dialog.displayValue,
              livePreviewsAsync: livePreviewsAsync,
              onClose: () {
                activeCopyValueDialog.value = null;
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
              results: selectedValueItems
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
              results: resolvedSelectedItems
                  .map((item) => item.toSearchResult())
                  .toList(growable: false),
              livePreviewsAsync: livePreviewsAsync,
              onClose: () {
                isCalculatorVisible.value = false;
              },
            ),
          ),
        if (isGroupSearchChainVisible.value)
          Positioned.fill(
            child: MemoryToolGroupSearchChainDialog(
              results: selectedValueItems
                  .map((item) => resolveSavedItem(item).toSearchResult())
                  .toList(growable: false),
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
