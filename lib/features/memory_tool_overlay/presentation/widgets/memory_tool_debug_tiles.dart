import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_debug_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_debug_primitives.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolDebugHitEntryTile extends StatelessWidget {
  const MemoryToolDebugHitEntryTile({
    super.key,
    required this.hit,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final MemoryBreakpointHit hit;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(14.r),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        formatMemoryToolDebugTimestamp(hit.timestampMillis),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    MemoryToolDebugInlineChip(text: 'TID ${hit.threadId}'),
                  ],
                ),
                SizedBox(height: 4.r),
                Text(
                  formatMemoryToolDebugTransition(hit.oldValue, hit.newValue),
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    color: selected ? context.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MemoryToolDebugDetailInfoTile extends StatelessWidget {
  const MemoryToolDebugDetailInfoTile({
    super.key,
    required this.title,
    required this.value,
    this.monospace = false,
    this.onLongPress,
  });

  final String title;
  final String value;
  final bool monospace;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(14.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: context.colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.42),
              ),
            ),
            padding: EdgeInsets.all(12.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.r),
                Text(
                  value,
                  softWrap: true,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontFamily: monospace ? 'monospace' : null,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
