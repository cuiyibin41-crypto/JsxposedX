import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_pointer_utils.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_copy_value_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_offset_preview_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_pointer_scan_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_action_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_tile.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart'
    show MemoryValuePreview, PointerScanRequest, SearchResult;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolBrowseResultList extends HookConsumerWidget {
  const MemoryToolBrowseResultList({
    super.key,
    required this.listStorageKey,
    required this.focusRequestId,
    required this.scrollController,
    required this.results,
    required this.anchorAddress,
    required this.isSelected,
    required this.onToggleSelection,
    required this.livePreviewsAsync,
    required this.previousValueByAddress,
    this.processPid,
    this.initialFrozenStateByAddress = const <int, bool>{},
    this.onPreviewMemoryAddress,
    this.onStartPointerScan,
  });

  final PageStorageKey<String> listStorageKey;
  final int focusRequestId;
  final ScrollController scrollController;
  final List<SearchResult> results;
  final int? anchorAddress;
  final bool Function(int address) isSelected;
  final void Function(SearchResult result) onToggleSelection;
  final AsyncValue<Map<int, MemoryValuePreview>> livePreviewsAsync;
  final Map<int, String> previousValueByAddress;
  final int? processPid;
  final Map<int, bool> initialFrozenStateByAddress;
  final Future<void> Function(
    SearchResult result,
    MemoryValuePreview? preview,
    String displayValue,
    int targetAddress,
  )? onPreviewMemoryAddress;
  final Future<void> Function(PointerScanRequest request)? onStartPointerScan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeResultDialog =
        useState<({SearchResult result, String displayValue})?>(null);
    final activeResultActionDialog =
        useState<({SearchResult result, String displayValue})?>(null);
    final activeCopyValueDialog =
        useState<({SearchResult result, String displayValue})?>(null);
    final activeOffsetPreviewDialog =
        useState<({SearchResult result, String displayValue})?>(null);
    final activePointerScanDialog = useState<SearchResult?>(null);
    final anchorExtent = useState<double>(94.r);
    final centerSliverKey = useMemoized(
      () => GlobalKey(debugLabel: 'memory_tool_browse_center_$focusRequestId'),
      [focusRequestId],
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

    Widget buildResultTile(SearchResult result) {
      final displayValue = resolveMemoryToolSearchResultDisplayValue(
        result: result,
        livePreviewsAsync: livePreviewsAsync,
      );
      return MemoryToolSearchResultTile(
        result: result,
        displayValue: displayValue,
        previousDisplayValue: previousValueByAddress[result.address],
        isFrozen: initialFrozenStateByAddress[result.address] ?? false,
        isAnchor: anchorAddress == result.address,
        isSelected: isSelected(result.address),
        onToggleSelection: () {
          onToggleSelection(result);
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
    }

    Widget buildMeasuredAnchorTile(SearchResult result) {
      return _MeasureSize(
        onChange: (size) {
          if ((anchorExtent.value - size.height).abs() <= 0.5) {
            return;
          }
          anchorExtent.value = size.height;
        },
        child: buildResultTile(result),
      );
    }

    final resolvedAnchorAddress = anchorAddress;
    final anchorIndex = resolvedAnchorAddress == null
        ? -1
        : results.indexWhere((result) => result.address == resolvedAnchorAddress);
    if (anchorIndex < 0 || anchorIndex >= results.length) {
      return const SizedBox.shrink();
    }

    final aboveResults = results.take(anchorIndex).toList(growable: false);
    final anchorResult = results[anchorIndex];
    final belowResults = results.skip(anchorIndex + 1).toList(growable: false);

    return Stack(
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final viewportHeight = constraints.maxHeight;
            final anchorFraction = viewportHeight <= 0
                ? 0.5
                : ((viewportHeight - anchorExtent.value) / 2 / viewportHeight)
                      .clamp(0.0, 1.0)
                      .toDouble();

            return CustomScrollView(
              key: listStorageKey,
              controller: scrollController,
              center: centerSliverKey,
              anchor: anchorFraction,
              slivers: <Widget>[
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final result = aboveResults[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == aboveResults.length - 1 ? 6.r : 4.r,
                      ),
                      child: buildResultTile(result),
                    );
                  }, childCount: aboveResults.length),
                ),
                SliverToBoxAdapter(
                  key: centerSliverKey,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: belowResults.isEmpty ? 6.r : 4.r),
                    child: buildMeasuredAnchorTile(anchorResult),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final result = belowResults[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == belowResults.length - 1 ? 6.r : 4.r,
                      ),
                      child: buildResultTile(result),
                    );
                  }, childCount: belowResults.length),
                ),
              ],
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
                if (onStartPointerScan != null && processPid != null)
                  MemoryToolSearchResultActionItemData(
                    icon: Icons.account_tree_rounded,
                    title: context.l10n.memoryToolResultActionPointerScan,
                    onTap: () async {
                      activeResultActionDialog.value = null;
                      activePointerScanDialog.value = dialog.result;
                    },
                  ),
                if (onPreviewMemoryAddress != null &&
                    canInterpretMemoryToolPointer(
                      resolvePreview(dialog.result)?.rawBytes ??
                          dialog.result.rawBytes,
                    ))
                  MemoryToolSearchResultActionItemData(
                    icon: Icons.subdirectory_arrow_right_rounded,
                    title: context.l10n.memoryToolResultActionJumpToPointer,
                    onTap: () async {
                      final targetAddress = decodeMemoryToolPointerAddress(
                        resolvePreview(dialog.result)?.rawBytes ??
                            dialog.result.rawBytes,
                      );
                      if (targetAddress == null) {
                        return;
                      }
                      await onPreviewMemoryAddress!(
                        dialog.result,
                        resolvePreview(dialog.result),
                        dialog.displayValue,
                        targetAddress,
                      );
                      activeResultActionDialog.value = null;
                    },
                  ),
                if (onPreviewMemoryAddress != null)
                  MemoryToolSearchResultActionItemData(
                    icon: Icons.calculate_rounded,
                    title: context.l10n.memoryToolResultActionOffsetPreview,
                    onTap: () async {
                      activeResultActionDialog.value = null;
                      activeOffsetPreviewDialog.value = (
                        result: dialog.result,
                        displayValue: dialog.displayValue,
                      );
                    },
                  ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.save_alt_rounded,
                  title: context.l10n.memoryToolResultActionSaveToSaved,
                  onTap: () async {
                    await saveResultToSaved(dialog.result);
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
        if (activePointerScanDialog.value case final result?)
          Positioned.fill(
            child: MemoryToolPointerScanDialog(
              pid: processPid!,
              targetAddress: result.address,
              onConfirm: (request) async {
                await onStartPointerScan!(request);
              },
              onClose: () {
                activePointerScanDialog.value = null;
              },
            ),
          ),
        if (activeOffsetPreviewDialog.value case final dialog?)
          Positioned.fill(
            child: MemoryToolOffsetPreviewDialog(
              result: dialog.result,
              displayValue: dialog.displayValue,
              livePreviewsAsync: livePreviewsAsync,
              onConfirm: (targetAddress) async {
                activeOffsetPreviewDialog.value = null;
                await onPreviewMemoryAddress!(
                  dialog.result,
                  resolvePreview(dialog.result),
                  dialog.displayValue,
                  targetAddress,
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

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({
    required this.onChange,
    required super.child,
  });

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChange);

  ValueChanged<Size> onChange;
  Size? _previousSize;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _previousSize) {
      return;
    }
    _previousSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(size);
    });
  }
}
