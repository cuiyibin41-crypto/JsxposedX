import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_badge.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_action_dialog.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart'
    show PointerScanRequest, PointerScanResult;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolPointerResultList extends HookWidget {
  const MemoryToolPointerResultList({
    super.key,
    required this.results,
    required this.request,
    required this.scrollController,
    required this.onContinueSearch,
    required this.onJumpToTarget,
  });

  final List<PointerScanResult> results;
  final PointerScanRequest request;
  final ScrollController scrollController;
  final Future<void> Function(PointerScanResult result) onContinueSearch;
  final Future<void> Function(PointerScanResult result) onJumpToTarget;

  @override
  Widget build(BuildContext context) {
    final activeActionDialog = useState<PointerScanResult?>(null);

    return Stack(
      children: <Widget>[
        ListView.separated(
          controller: scrollController,
          padding: EdgeInsets.zero,
          itemCount: results.length,
          separatorBuilder: (_, index) =>
              SizedBox(height: index == results.length - 1 ? 6.r : 4.r),
          itemBuilder: (context, index) {
            final result = results[index];
            return _MemoryToolPointerResultTile(
              result: result,
              pointerWidth: request.pointerWidth,
              onOpenActions: () {
                activeActionDialog.value = result;
              },
            );
          },
        ),
        if (activeActionDialog.value case final result?)
          Positioned.fill(
            child: MemoryToolSearchResultActionDialog(
              actions: <MemoryToolSearchResultActionItemData>[
                MemoryToolSearchResultActionItemData(
                  icon: Icons.account_tree_rounded,
                  title: context.l10n.memoryToolPointerActionContinueSearch,
                  onTap: () async {
                    await onContinueSearch(result);
                    activeActionDialog.value = null;
                  },
                ),
                MemoryToolSearchResultActionItemData(
                  icon: Icons.subdirectory_arrow_right_rounded,
                  title: context.l10n.memoryToolPointerActionJumpToTarget,
                  onTap: () async {
                    await onJumpToTarget(result);
                    activeActionDialog.value = null;
                  },
                ),
              ],
              onClose: () {
                activeActionDialog.value = null;
              },
            ),
          ),
      ],
    );
  }
}

class _MemoryToolPointerResultTile extends StatelessWidget {
  const _MemoryToolPointerResultTile({
    required this.result,
    required this.pointerWidth,
    required this.onOpenActions,
  });

  final PointerScanResult result;
  final int pointerWidth;
  final VoidCallback onOpenActions;

  @override
  Widget build(BuildContext context) {
    final offsetHex = result.offset.toRadixString(16).toUpperCase();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenActions,
        onLongPress: onOpenActions,
        borderRadius: BorderRadius.circular(14.r),
        child: Ink(
          decoration: BoxDecoration(
            color: context.colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          padding: EdgeInsets.all(12.r),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${context.l10n.memoryToolPointerOffsetLabel}: +0x$offsetHex',
                      style: context.textTheme.titleSmall?.copyWith(
                        color: context.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4.r),
                    Text(
                      '${context.l10n.memoryToolPointerBaseAddressLabel}: ${formatMemoryToolSearchResultAddress(result.baseAddress)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.r),
                    Text(
                      '${context.l10n.memoryToolPointerTargetAddressLabel}: ${formatMemoryToolSearchResultAddress(result.targetAddress)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurface.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6.r),
                    Wrap(
                      spacing: 6.r,
                      runSpacing: 6.r,
                      children: <Widget>[
                        MemoryToolResultBadge(
                          label: 'PTR$pointerWidth',
                          backgroundColor: const Color(0xFFEAF2FF),
                          foregroundColor: const Color(0xFF3157C8),
                        ),
                        MemoryToolResultBadge(
                          label: mapMemoryToolSearchResultRegionTypeLabel(
                            context,
                            result.regionTypeKey,
                          ),
                          backgroundColor:
                              mapMemoryToolSearchResultRegionBadgeBackground(
                                result.regionTypeKey,
                              ),
                          foregroundColor:
                              mapMemoryToolSearchResultRegionBadgeForeground(
                                result.regionTypeKey,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.r),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatMemoryToolSearchResultAddress(result.pointerAddress),
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4.r),
                  Text(
                    context.l10n.memoryToolPointerPointerAddressLabel,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurface.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
