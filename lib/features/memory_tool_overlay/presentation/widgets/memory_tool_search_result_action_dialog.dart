import 'package:JsxposedX/common/widgets/overlay_window/overlay_panel_dialog.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolSearchResultActionDialog extends StatelessWidget {
  const MemoryToolSearchResultActionDialog({
    super.key,
    required this.result,
    required this.displayValue,
    required this.onClose,
  });

  final SearchResult result;
  final String displayValue;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return OverlayPanelDialog.card(
      onClose: onClose,
      maxWidthPortrait: 372.r,
      maxWidthLandscape: 420.r,
      maxHeightPortrait: 420.r,
      maxHeightLandscape: 340.r,
      cardBorderRadius: 18.r,
      childBuilder: (context, viewport, layout) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(14.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.memoryToolResultActionTitle,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6.r),
              Text(
                displayValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: context.colorScheme.primary,
                ),
              ),
              SizedBox(height: 4.r),
              Text(
                '${context.l10n.memoryToolResultAddress}: ${formatMemoryToolSearchResultAddress(result.address)}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.66),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12.r),
              _MemoryToolSearchResultActionItem(
                icon: Icons.check_circle_outline_rounded,
                title: context.l10n.memoryToolResultActionSelectCurrent,
                subtitle:
                    context.l10n.memoryToolResultActionSelectCurrentHint,
              ),
              SizedBox(height: 8.r),
              _MemoryToolSearchResultActionItem(
                icon: Icons.select_all_rounded,
                title: context.l10n.memoryToolResultActionStartMultiSelect,
                subtitle:
                    context.l10n.memoryToolResultActionStartMultiSelectHint,
              ),
              SizedBox(height: 8.r),
              _MemoryToolSearchResultActionItem(
                icon: Icons.edit_note_rounded,
                title: context.l10n.memoryToolResultActionBatchEdit,
                subtitle: context.l10n.memoryToolResultActionBatchEditHint,
              ),
              SizedBox(height: 8.r),
              _MemoryToolSearchResultActionItem(
                icon: Icons.visibility_rounded,
                title: context.l10n.memoryToolResultActionAddWatch,
                subtitle: context.l10n.memoryToolResultActionAddWatchHint,
              ),
              SizedBox(height: 8.r),
              _MemoryToolSearchResultActionItem(
                icon: Icons.ac_unit_rounded,
                title: context.l10n.memoryToolResultActionFreeze,
                subtitle: context.l10n.memoryToolResultActionFreezeHint,
              ),
              SizedBox(height: 14.r),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: onClose,
                  child: Text(context.l10n.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MemoryToolSearchResultActionItem extends StatelessWidget {
  const _MemoryToolSearchResultActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 34.r,
              height: 34.r,
              decoration: BoxDecoration(
                color: context.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                icon,
                size: 18.r,
                color: context.colorScheme.primary,
              ),
            ),
            SizedBox(width: 10.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3.r),
                  Text(
                    subtitle,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurface.withValues(
                        alpha: 0.66,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.r),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colorScheme.onSurface.withValues(alpha: 0.42),
            ),
          ],
        ),
      ),
    );
  }
}
