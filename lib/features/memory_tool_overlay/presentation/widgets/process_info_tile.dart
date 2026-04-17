import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';

class ProcessInfoTile extends StatelessWidget {
  const ProcessInfoTile({
    super.key,
    required this.process,
    this.onTap,
    this.scale = 1.0,
  });

  final ProcessInfo process;
  final VoidCallback? onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final icon = process.icon;
    final effectiveScale = scale.clamp(0.5, 1.0);
    final tileHeight = 82.0 * effectiveScale;
    final borderRadius = 12.0 * effectiveScale;
    final iconSize = 38.0 * effectiveScale;
    final iconRadius = 10.0 * effectiveScale;
    final horizontalPadding = 10.0 * effectiveScale;
    final titleFontSize = 14.0 * effectiveScale;
    final packageFontSize = 11.5 * effectiveScale;
    final pidFontSize = 10.0 * effectiveScale;
    final gap = 10.0 * effectiveScale;
    final fallbackIconSize = 20.0 * effectiveScale;

    return Material(
      color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: SizedBox(
          height: tileHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(iconRadius),
                    color: context.colorScheme.surfaceContainer,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(iconRadius),
                    child: icon != null && icon.isNotEmpty
                        ? Image.memory(icon, fit: BoxFit.cover)
                        : Icon(
                            Icons.memory_rounded,
                            size: fallbackIconSize,
                            color: context.colorScheme.primary,
                          ),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        process.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: titleFontSize,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: 3.0 * effectiveScale),
                      Text(
                        process.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: packageFontSize,
                          height: 1.0,
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.68,
                          ),
                        ),
                      ),
                      SizedBox(height: 2.0 * effectiveScale),
                      Text(
                        'pid: ${process.pid}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: pidFontSize,
                          height: 1.0,
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
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
