import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolDebugListItemShell extends StatelessWidget {
  const MemoryToolDebugListItemShell({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected
                ? context.colorScheme.primaryContainer.withValues(alpha: 0.72)
                : context.colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: selected
                  ? context.colorScheme.primary
                  : context.colorScheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          padding: EdgeInsets.all(12.r),
          child: child,
        ),
      ),
    );
  }
}

class MemoryToolDebugInlineChip extends StatelessWidget {
  const MemoryToolDebugInlineChip({
    super.key,
    required this.text,
    this.active = false,
  });

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? context.colorScheme.primary.withValues(alpha: 0.08)
            : context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 4.r),
        child: Text(
          text,
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: active ? context.colorScheme.primary : null,
          ),
        ),
      ),
    );
  }
}

class MemoryToolDebugEmptyState extends StatelessWidget {
  const MemoryToolDebugEmptyState({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.r),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.66),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class MemoryToolDebugProcessEmptyState extends StatelessWidget {
  const MemoryToolDebugProcessEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(18.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.bug_report_rounded,
                size: 28.r,
                color: context.colorScheme.primary,
              ),
              SizedBox(height: 10.r),
              Text(
                context.l10n.memoryToolDebugSelectProcessFirst,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6.r),
              Text(
                context.l10n.memoryToolDebugSelectProcessHint,
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
