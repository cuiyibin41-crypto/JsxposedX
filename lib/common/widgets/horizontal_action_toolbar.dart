import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HorizontalActionToolbarItem {
  const HorizontalActionToolbarItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
}

class HorizontalActionToolbar extends StatelessWidget {
  const HorizontalActionToolbar({
    super.key,
    required this.items,
    this.borderRadius,
    this.contentPadding,
    this.itemSpacing,
  });

  final List<HorizontalActionToolbarItem> items;
  final double? borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final double? itemSpacing;

  @override
  Widget build(BuildContext context) {
    final resolvedBorderRadius = borderRadius ?? 16.r;
    final resolvedContentPadding =
        contentPadding ?? EdgeInsets.symmetric(horizontal: 8.r, vertical: 8.r);
    final resolvedItemSpacing = itemSpacing ?? 8.r;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(resolvedBorderRadius),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: resolvedContentPadding,
        child: Row(
          children: items
              .indexed
              .expand<Widget>((entry) {
                final index = entry.$1;
                final item = entry.$2;
                return <Widget>[
                  _HorizontalActionToolbarButton(item: item),
                  if (index != items.length - 1)
                    SizedBox(width: resolvedItemSpacing),
                ];
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _HorizontalActionToolbarButton extends StatelessWidget {
  const _HorizontalActionToolbarButton({required this.item});

  final HorizontalActionToolbarItem item;

  @override
  Widget build(BuildContext context) {
    final Color foregroundColor = item.onPressed == null
        ? context.colorScheme.onSurface.withValues(alpha: 0.36)
        : item.isPrimary
        ? context.colorScheme.onPrimary
        : context.colorScheme.onSurface;
    final Color backgroundColor = item.onPressed == null
        ? context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : item.isPrimary
        ? context.colorScheme.primary
        : context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onPressed,
        borderRadius: BorderRadius.circular(12.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.r),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: item.isPrimary
                  ? backgroundColor
                  : context.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(item.icon, size: 18.r, color: foregroundColor),
              SizedBox(width: 6.r),
              Text(
                item.label,
                style: context.textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
