import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/ai/presentation/widgets/ai_chat_compact_scope.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_ai_overlay_selection_provider.dart';
import 'package:flutter/material.dart';

class MemoryAiSelectionTagBar extends StatelessWidget {
  const MemoryAiSelectionTagBar({super.key, required this.tags});

  final List<MemoryAiOverlaySelectionTag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final scale = AiChatCompactScope.scaleOf(context);
    return SizedBox(
      height: 30 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: tags.length,
        separatorBuilder: (_, __) => SizedBox(width: 8 * scale),
        itemBuilder: (context, index) {
          return _MemoryAiSelectionTagChip(tag: tags[index]);
        },
      ),
    );
  }
}

class _MemoryAiSelectionTagChip extends StatelessWidget {
  const _MemoryAiSelectionTagChip({required this.tag});

  final MemoryAiOverlaySelectionTag tag;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    final theme = _MemoryAiSelectionChipTheme.resolve(context, tag.source);
    final summary = '${tag.addressLabel} = ${tag.valueLabel}';
    return Container(
      constraints: BoxConstraints(maxWidth: 182 * scale),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(theme.radius * scale),
        border: Border.all(color: theme.borderColor, width: theme.borderWidth),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 8 * scale,
          vertical: 4 * scale,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 18 * scale,
              height: 18 * scale,
              decoration: BoxDecoration(
                color: theme.iconBackgroundColor,
                borderRadius: BorderRadius.circular(theme.iconRadius * scale),
              ),
              child: Icon(theme.icon, size: 11 * scale, color: theme.iconColor),
            ),
            SizedBox(width: 6 * scale),
            Flexible(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: theme.valueColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10 * scale,
                ),
              ),
            ),
            SizedBox(width: 6 * scale),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 5 * scale,
                vertical: 1 * scale,
              ),
              decoration: BoxDecoration(
                color: theme.badgeBackgroundColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag.typeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelSmall?.copyWith(
                  color: theme.badgeForegroundColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 8.5 * scale,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryAiSelectionChipTheme {
  const _MemoryAiSelectionChipTheme({
    required this.icon,
    required this.radius,
    required this.iconRadius,
    required this.borderWidth,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.valueColor,
    required this.badgeBackgroundColor,
    required this.badgeForegroundColor,
  });

  final IconData icon;
  final double radius;
  final double iconRadius;
  final double borderWidth;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final Color valueColor;
  final Color badgeBackgroundColor;
  final Color badgeForegroundColor;

  static _MemoryAiSelectionChipTheme resolve(
    BuildContext context,
    MemoryAiOverlaySelectionSource source,
  ) {
    return switch (source) {
      MemoryAiOverlaySelectionSource.search => _MemoryAiSelectionChipTheme(
        icon: Icons.search_rounded,
        radius: 18,
        iconRadius: 999,
        borderWidth: 1.2,
        backgroundColor: context.isDark
            ? const Color(0xFF10232A)
            : const Color(0xFFF2FBFF),
        borderColor: const Color(0xFF70D7F9).withValues(alpha: 0.9),
        iconBackgroundColor: const Color(0xFF70D7F9).withValues(alpha: 0.18),
        iconColor: const Color(0xFF0D8FB8),
        valueColor: context.colorScheme.onSurfaceVariant,
        badgeBackgroundColor: const Color(0xFF70D7F9).withValues(alpha: 0.16),
        badgeForegroundColor: const Color(0xFF0D8FB8),
      ),
      MemoryAiOverlaySelectionSource.browse => _MemoryAiSelectionChipTheme(
        icon: Icons.visibility_rounded,
        radius: 10,
        iconRadius: 6,
        borderWidth: 1,
        backgroundColor: context.isDark
            ? const Color(0xFF241B2E)
            : const Color(0xFFF7F2FF),
        borderColor: const Color(0xFFAD98FF).withValues(alpha: 0.88),
        iconBackgroundColor: const Color(0xFFAD98FF).withValues(alpha: 0.2),
        iconColor: const Color(0xFF6F56D9),
        valueColor: context.colorScheme.onSurfaceVariant,
        badgeBackgroundColor: const Color(0xFFAD98FF).withValues(alpha: 0.18),
        badgeForegroundColor: const Color(0xFF6F56D9),
      ),
      MemoryAiOverlaySelectionSource.saved => _MemoryAiSelectionChipTheme(
        icon: Icons.bookmark_rounded,
        radius: 16,
        iconRadius: 8,
        borderWidth: 1,
        backgroundColor: context.isDark
            ? const Color(0xFF2B1D14)
            : const Color(0xFFFFF4EB),
        borderColor: const Color(0xFFFFB385).withValues(alpha: 0.92),
        iconBackgroundColor: const Color(0xFFFFB385).withValues(alpha: 0.24),
        iconColor: const Color(0xFFC96A2A),
        valueColor: context.colorScheme.onSurfaceVariant,
        badgeBackgroundColor: const Color(0xFFFFB385).withValues(alpha: 0.2),
        badgeForegroundColor: const Color(0xFFC96A2A),
      ),
    };
  }
}
