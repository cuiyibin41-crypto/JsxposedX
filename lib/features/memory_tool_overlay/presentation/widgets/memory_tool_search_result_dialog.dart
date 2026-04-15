import 'package:JsxposedX/common/widgets/overlay_window/overlay_panel_dialog.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolSearchResultDialog extends StatelessWidget {
  const MemoryToolSearchResultDialog({
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
      maxWidthPortrait: 360.r,
      maxWidthLandscape: 420.r,
      maxHeightPortrait: 360.r,
      maxHeightLandscape: 320.r,
      cardBorderRadius: 18.r,
      childBuilder: (context, viewport, layout) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(14.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.memoryToolResultDetailTitle,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 12.r),
              Text(
                context.l10n.memoryToolResultValue,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.r),
              Text(
                displayValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: context.colorScheme.primary,
                ),
              ),
              SizedBox(height: 12.r),
              Text(
                context.l10n.memoryToolResultDetailActionsLabel,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.r),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.38,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.r,
                        vertical: 2.r,
                      ),
                      leading: Icon(
                        Icons.edit_rounded,
                        color: context.colorScheme.primary,
                      ),
                      title: Text(
                        context.l10n.memoryToolResultDetailActionEdit,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: context.colorScheme.onSurface.withValues(
                          alpha: 0.42,
                        ),
                      ),
                      onTap: () {},
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: context.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.r,
                        vertical: 2.r,
                      ),
                      leading: Icon(
                        Icons.visibility_rounded,
                        color: context.colorScheme.primary,
                      ),
                      title: Text(
                        context.l10n.memoryToolResultDetailActionWatch,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: context.colorScheme.onSurface.withValues(
                          alpha: 0.42,
                        ),
                      ),
                      onTap: () {},
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: context.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.r,
                        vertical: 2.r,
                      ),
                      leading: Icon(
                        Icons.content_copy_rounded,
                        color: context.colorScheme.primary,
                      ),
                      title: Text(
                        context.l10n.memoryToolResultDetailActionCopyAddress,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: context.colorScheme.onSurface.withValues(
                          alpha: 0.42,
                        ),
                      ),
                      onTap: () {},
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: context.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.r,
                        vertical: 2.r,
                      ),
                      leading: Icon(
                        Icons.pin_outlined,
                        color: context.colorScheme.primary,
                      ),
                      title: Text(
                        context.l10n.memoryToolResultDetailActionCopyValue,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: context.colorScheme.onSurface.withValues(
                          alpha: 0.42,
                        ),
                      ),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}