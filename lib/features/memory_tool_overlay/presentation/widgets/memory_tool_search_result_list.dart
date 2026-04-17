import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_search_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_copy_value_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_action_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_result_selection_state.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_tile.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolSearchResultList extends HookConsumerWidget {
  const MemoryToolSearchResultList({
    super.key,
    required this.listStorageKey,
    required this.results,
    required this.selectionState,
    required this.selectionNotifier,
    required this.livePreviewsAsync,
    required this.previousValueByAddress,
    this.processPid,
    this.initialFrozenStateByAddress = const <int, bool>{},
  });

  final PageStorageKey<String> listStorageKey;
  final List<SearchResult> results;
  final MemoryToolResultSelectionState selectionState;
  final MemoryToolResultSelection selectionNotifier;
  final AsyncValue<Map<int, MemoryValuePreview>> livePreviewsAsync;
  final Map<int, String> previousValueByAddress;
  final int? processPid;
  final Map<int, bool> initialFrozenStateByAddress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeResultDialog =
        useState<({SearchResult result, String displayValue})?>(null);
    final activeResultActionDialog =
        useState<({SearchResult result, String displayValue})?>(null);
    final activeCopyValueDialog =
        useState<({SearchResult result, String displayValue})?>(null);
    final removedResultNotifier = ref.read(
      memoryToolRemovedResultProvider.notifier,
    );
    final savedItemsNotifier = ref.read(memoryToolSavedItemsProvider.notifier);

    Future<void> copyText(String value) async {
      final copied = await FlutterOverlayWindow.setClipboardData(value);
      ref.read(overlayWindowHostRuntimeProvider.notifier).showToast(
        copied ? context.l10n.codeCopied : context.l10n.error,
      );
    }

    Future<void> saveResultToSaved(SearchResult result) async {
      final selectedPid = ref.read(memoryToolSelectedProcessProvider)?.pid;
      if (selectedPid == null) {
        return;
      }

      savedItemsNotifier.saveOne(
        pid: selectedPid,
        result: result,
        preview: livePreviewsAsync.asData?.value[result.address],
        isFrozen: initialFrozenStateByAddress[result.address] ?? false,
      );
      await ToastOverlayMessage.show(
        context.l10n.memoryToolSavedToSavedMessage(1),
        duration: const Duration(milliseconds: 1200),
      );
    }

    MemoryValuePreview? resolvePreview(SearchResult result) {
      return livePreviewsAsync.asData?.value[result.address];
    }

    return Stack(
      children: <Widget>[
        ListView.separated(
          key: listStorageKey,
          padding: EdgeInsets.zero,
          itemCount: results.length,
          separatorBuilder: (_, index) =>
              SizedBox(height: index == results.length - 1 ? 6.r : 4.r),
          itemBuilder: (BuildContext context, int index) {
            final result = results[index];
            final displayValue = resolveMemoryToolSearchResultDisplayValue(
              result: result,
              livePreviewsAsync: livePreviewsAsync,
            );
            return MemoryToolSearchResultTile(
              result: result,
              displayValue: displayValue,
              previousDisplayValue: previousValueByAddress[result.address],
              isFrozen: initialFrozenStateByAddress[result.address] ?? false,
              isSelected: selectionState.contains(result.address),
              onToggleSelection: () {
                selectionNotifier.toggle(result);
              },
              onDeleteRecord: () {
                selectionNotifier.removeAddress(result.address);
                removedResultNotifier.remove(result.address);
              },
              onTap: () {
                activeResultActionDialog.value = null;
                activeResultDialog.value = (
                  result: result,
                  displayValue: displayValue,
                );
              },
              onLongProcess: () {
                activeResultDialog.value = null;
                activeResultActionDialog.value = (
                  result: result,
                  displayValue: displayValue,
                );
              },
            );
          },
        ),
        if (activeResultDialog.value case final dialog?)
          Positioned.fill(
            child: MemoryToolSearchResultDialog(
              result: dialog.result,
              displayValue: dialog.displayValue,
              livePreviewsAsync: livePreviewsAsync,
              processPid: processPid,
              initialFrozenState:
                  initialFrozenStateByAddress[dialog.result.address],
              onClose: () {
                activeResultDialog.value = null;
              },
            ),
          ),
        if (activeResultActionDialog.value case final dialog?)
          Positioned.fill(
            child: MemoryToolSearchResultActionDialog(
              actions: <MemoryToolSearchResultActionItemData>[
                MemoryToolSearchResultActionItemData(
                  icon: Icons.save_alt_rounded,
                  title: context.l10n.memoryToolResultActionSaveToSaved,
                  onTap: () async {
                    await saveResultToSaved(dialog.result);
                    activeResultActionDialog.value = null;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.copy_all_rounded,
                  title:
                      '${context.l10n.memoryToolResultDetailActionCopyAddress}: ${formatMemoryToolSearchResultAddress(dialog.result.address)}',
                  onTap: () async {
                    await copyText(
                      formatMemoryToolSearchResultAddress(dialog.result.address),
                    );
                    activeResultActionDialog.value = null;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.tune_rounded,
                  title: context.l10n.memoryToolResultDetailActionCopyValue,
                  onTap: () async {
                    activeResultActionDialog.value = null;
                    activeCopyValueDialog.value = (
                      result: dialog.result,
                      displayValue: dialog.displayValue,
                    );
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.data_array_rounded,
                  title:
                      '${context.l10n.memoryToolResultActionCopyHex}: ${formatMemoryToolSearchResultHex(resolvePreview(dialog.result)?.rawBytes ?? dialog.result.rawBytes)}',
                  onTap: () async {
                    final preview = resolvePreview(dialog.result);
                    await copyText(
                      formatMemoryToolSearchResultHex(
                        preview?.rawBytes ?? dialog.result.rawBytes,
                      ),
                    );
                    activeResultActionDialog.value = null;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.swap_horiz_rounded,
                  title:
                      '${context.l10n.memoryToolResultActionCopyReverseHex}: ${formatMemoryToolSearchResultReverseHex(resolvePreview(dialog.result)?.rawBytes ?? dialog.result.rawBytes)}',
                  onTap: () async {
                    final preview = resolvePreview(dialog.result);
                    await copyText(
                      formatMemoryToolSearchResultReverseHex(
                        preview?.rawBytes ?? dialog.result.rawBytes,
                      ),
                    );
                    activeResultActionDialog.value = null;
                  },
                ),
              ],
              onClose: () {
                activeResultActionDialog.value = null;
              },
            ),
          ),
        if (activeCopyValueDialog.value case final dialog?)
          Positioned.fill(
            child: MemoryToolCopyValueDialog(
              result: dialog.result,
              displayValue: dialog.displayValue,
              livePreviewsAsync: livePreviewsAsync,
              onClose: () {
                activeCopyValueDialog.value = null;
              },
            ),
          ),
      ],
    );
  }
}
