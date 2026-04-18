import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_badge.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolSearchResultTile extends StatelessWidget {
  const MemoryToolSearchResultTile({
    super.key,
    required this.result,
    required this.displayValue,
    this.previousDisplayValue,
    this.isFrozen = false,
    this.isAnchor = false,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onDeleteRecord,
    this.onTap,
    this.onLongProcess,
  });

  final SearchResult result;
  final String displayValue;
  final String? previousDisplayValue;
  final bool isFrozen;
  final bool isAnchor;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onDeleteRecord;
  final VoidCallback? onTap;
  final VoidCallback? onLongProcess;

  @override
  Widget build(BuildContext context) {
    final previousValue = previousDisplayValue?.trim();
    final shouldShowPreviousValue =
        previousValue != null &&
        previousValue.isNotEmpty &&
        previousValue != displayValue.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongProcess,
        borderRadius: BorderRadius.circular(14.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colorScheme.primaryContainer.withValues(alpha: 0.72)
                : context.colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: isAnchor
                  ? const Color(0xFFF08C2B)
                  : isSelected
                  ? context.colorScheme.primary
                  : context.colorScheme.outlineVariant.withValues(alpha: 0.42),
              width: isAnchor ? 1.6 : 1,
            ),
          ),
          padding: EdgeInsets.all(12.r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final valueMaxWidth = constraints.maxWidth * 0.52;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: valueMaxWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                displayValue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: context.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: context.colorScheme.primary,
                                ),
                              ),
                              if (shouldShowPreviousValue) ...<Widget>[
                                SizedBox(height: 2.r),
                                Text(
                                  '${context.l10n.memoryToolResultPreviousValue}: $previousValue',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: context.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: context.colorScheme.onSurface
                                        .withValues(alpha: 0.62),
                                  ),
                                ),
                              ],
                              SizedBox(height: 2.r),
                              Wrap(
                                spacing: 6.r,
                                runSpacing: 6.r,
                                children: <Widget>[
                                  MemoryToolResultBadge(
                                    label: mapMemoryToolSearchResultTypeLabel(
                                      type: result.type,
                                      displayValue: displayValue,
                                    ),
                                    backgroundColor:
                                        mapMemoryToolSearchResultTypeBadgeBackground(
                                          result.type,
                                        ),
                                    foregroundColor:
                                        mapMemoryToolSearchResultTypeBadgeForeground(
                                          result.type,
                                        ),
                                  ),
                                  if (isFrozen)
                                    MemoryToolResultBadge(
                                      label: context.l10n.memoryToolFrozenBadge,
                                      backgroundColor: context
                                          .colorScheme
                                          .errorContainer
                                          .withValues(alpha: 0.9),
                                      foregroundColor:
                                          context.colorScheme.onErrorContainer,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10.r),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                formatMemoryToolSearchResultAddress(
                                  result.address,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2.r),
                              Align(
                                alignment: Alignment.centerRight,
                                child: MemoryToolResultBadge(
                                  label:
                                      mapMemoryToolSearchResultRegionTypeLabel(
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
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 6.r),
                        InkWell(
                          borderRadius: BorderRadius.circular(10.r),
                          onTap: onDeleteRecord,
                          child: SizedBox(
                            width: 28.r,
                            height: 28.r,
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 18.r,
                              color: context.colorScheme.error.withValues(
                                alpha: 0.84,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
