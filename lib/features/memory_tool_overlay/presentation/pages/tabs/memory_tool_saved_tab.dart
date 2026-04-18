import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_saved_item.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_pointer_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_pointer_utils.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_batch_edit_dialog.dart';
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
    show MemoryValuePreview, PointerScanRequest, SearchResult;
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
  });

  final VoidCallback onOpenBrowseTab;
  final VoidCallback onOpenPointerTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final savedItems = ref.watch(savedItemsForSelectedProcessProvider);
    final selectionState = ref.watch(memoryToolSavedItemSelectionProvider);
    final selectionNotifier = ref.read(
      memoryToolSavedItemSelectionProvider.notifier,
    );
    final savedItemsNotifier = ref.read(memoryToolSavedItemsProvider.notifier);
    final browseNotifier = ref.read(memoryToolBrowseControllerProvider.notifier);
    final pointerNotifier = ref.read(memoryToolPointerControllerProvider.notifier);
    final livePreviewsAsync = ref.watch(currentSavedItemLivePreviewsProvider);
    final frozenValuesAsync = ref.watch(currentFrozenMemoryValuesProvider);
    final valueHistoryState = ref.watch(memoryValueHistoryProvider);
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
    final activePointerScanDialog = useState<MemoryToolSavedItem?>(null);

    useEffect(() {
      selectionNotifier.retainVisible(
        savedItems.map((item) => item.address).toList(growable: false),
      );
      return null;
    }, [selectedProcess?.pid, savedItems]);

    final previewMap =
        livePreviewsAsync.asData?.value ?? const <int, MemoryValuePreview>{};
    final currentFrozenAddresses = selectedProcess == null
        ? null
        : frozenValuesAsync.asData?.value
              ?.where((value) => value.pid == selectedProcess.pid)
              .map((value) => value.address)
              .toSet();
    final selectedItems = savedItems
        .where((item) => selectionState.contains(item.address))
        .toList(growable: false);
    final previousValueByAddress = <int, String>{
      for (final entry in valueHistoryState.entries)
        entry.key: entry.value.displayValue,
    };
    final canRestorePrevious = selectionState.selectedAddresses.any(
      valueHistoryState.containsKey,
    );

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
      ref.read(overlayWindowHostRuntimeProvider.notifier).showToast(
        copied ? context.l10n.codeCopied : context.l10n.error,
      );
    }

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
                    onTap: savedItems.isEmpty
                        ? null
                        : () {
                            selectionNotifier.selectVisible(
                              savedItems.map((item) => item.address),
                            );
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.flip_rounded,
                    onTap: savedItems.isEmpty
                        ? null
                        : () {
                            selectionNotifier.invertVisible(
                              savedItems.map((item) => item.address),
                            );
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.layers_clear_rounded,
                    onTap: savedItems.isEmpty
                        ? null
                        : selectionNotifier.clearSelection,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.edit_rounded,
                    onTap: selectedItems.isEmpty
                        ? null
                        : () {
                            isBatchEditVisible.value = true;
                          },
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
                    onTap: canRestorePrevious && !valueActionState.isLoading
                        ? () async {
                            await restoreAddresses(
                              selectionState.selectedAddresses,
                            );
                          }
                        : null,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.delete_sweep_rounded,
                    onTap: selectedItems.isEmpty
                        ? null
                        : () {
                            savedItemsNotifier.removeSelected(
                              pid: selectedProcess.pid,
                              addresses: selectionState.selectedAddresses,
                            );
                            selectionNotifier.clearSelection();
                          },
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
                          'memory_tool_saved_results_${selectedProcess.pid}',
                        ),
                        padding: EdgeInsets.zero,
                        itemCount: savedItems.length,
                        separatorBuilder: (_, index) => SizedBox(
                          height: index == savedItems.length - 1 ? 6.r : 4.r,
                        ),
                        itemBuilder: (context, index) {
                          final item = savedItems[index];
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
                                pid: selectedProcess.pid,
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
                resultCount: savedItems.length,
                selectedCount: selectionState.selectedCount,
                renderedCount: savedItems.length,
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
                  icon: Icons.account_tree_rounded,
                  title: context.l10n.memoryToolResultActionPointerScan,
                  onTap: () async {
                    activeActionDialog.value = null;
                    activePointerScanDialog.value = dialog.item;
                  },
                ),
                if (canInterpretMemoryToolPointer(
                  previewMap[dialog.item.address]?.rawBytes ?? dialog.item.rawBytes,
                ))
                  MemoryToolSearchResultActionItemData(
                    icon: Icons.subdirectory_arrow_right_rounded,
                    title: context.l10n.memoryToolResultActionJumpToPointer,
                    onTap: () async {
                      final targetAddress = decodeMemoryToolPointerAddress(
                        previewMap[dialog.item.address]?.rawBytes ??
                            dialog.item.rawBytes,
                      );
                      if (targetAddress == null) {
                        return;
                      }
                      onOpenBrowseTab();
                      await browseNotifier.previewFromAddress(
                        sourceResult: dialog.item.toSearchResult(),
                        sourcePreview: previewMap[dialog.item.address],
                        sourceDisplayValue: dialog.displayValue,
                        targetAddress: targetAddress,
                      );
                      activeActionDialog.value = null;
                    },
                  ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.preview_rounded,
                  title: context.l10n.memoryToolResultActionPreviewMemoryBlock,
                  onTap: () async {
                    onOpenBrowseTab();
                    await browseNotifier.previewFromSearchResult(
                      result: dialog.item.toSearchResult(),
                      preview: previewMap[dialog.item.address],
                      displayValue: dialog.displayValue,
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
        if (activeOffsetPreviewDialog.value case final dialog?)
          Positioned.fill(
            child: MemoryToolOffsetPreviewDialog(
              result: dialog.item.toSearchResult(),
              displayValue: dialog.displayValue,
              livePreviewsAsync: livePreviewsAsync,
              onConfirm: (targetAddress) async {
                activeOffsetPreviewDialog.value = null;
                onOpenBrowseTab();
                await browseNotifier.previewFromAddress(
                  sourceResult: dialog.item.toSearchResult(),
                  sourcePreview: previewMap[dialog.item.address],
                  sourceDisplayValue: dialog.displayValue,
                  targetAddress: targetAddress,
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
