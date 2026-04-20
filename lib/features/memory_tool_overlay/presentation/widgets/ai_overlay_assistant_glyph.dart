import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/core/themes/ai_activation_theme.dart';
import 'package:flutter/material.dart';

class AiOverlayAssistantGlyph extends StatelessWidget {
  const AiOverlayAssistantGlyph({
    required this.size,
    this.isHighlighted = true,
    this.onTap,
    this.outerKey,
    this.innerKey,
    super.key,
  });

  final double size;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final Key? outerKey;
  final Key? innerKey;

  @override
  Widget build(BuildContext context) {
    final outerRadius = BorderRadius.circular(size * 0.375);
    final framePadding = size * 0.05;
    final innerRadius = BorderRadius.circular(size * 0.34);
    final inactiveCore = Color.lerp(
          context.colorScheme.primary,
          context.colorScheme.primaryContainer,
          0.2,
        ) ??
        context.colorScheme.primary;
    final inactiveEdge = Color.lerp(
          context.colorScheme.primaryContainer,
          context.colorScheme.surface,
          0.12,
        ) ??
        context.colorScheme.primaryContainer;
    final icon = Icon(
      Icons.auto_awesome_rounded,
      size: size * 0.5,
      color: isHighlighted
          ? context.colorScheme.onSurface
          : context.colorScheme.onPrimary.withValues(alpha: 0.96),
    );

    final inner = Container(
      key: innerKey,
      decoration: BoxDecoration(
        gradient: isHighlighted
            ? null
            : RadialGradient(
                center: Alignment.center,
                radius: 0.92,
                colors: <Color>[
                  inactiveCore.withValues(alpha: 0.98),
                  inactiveEdge.withValues(alpha: 0.92),
                ],
                stops: const <double>[0.22, 1],
              ),
        color: isHighlighted
            ? context.colorScheme.surface.withValues(alpha: 0.44)
            : null,
        borderRadius: innerRadius,
        border: isHighlighted
            ? null
            : Border.all(
                color: context.colorScheme.onPrimary.withValues(alpha: 0.14),
              ),
        boxShadow: isHighlighted
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: inactiveCore.withValues(alpha: 0.18),
                  blurRadius: size * 0.12,
                  offset: Offset(0, size * 0.04),
                ),
                BoxShadow(
                  color: inactiveCore.withValues(alpha: 0.08),
                  blurRadius: size * 0.18,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: innerRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: innerRadius,
          onTap: onTap,
          child: Center(child: icon),
        ),
      ),
    );

    if (!isHighlighted) {
      return SizedBox(
        width: size,
        height: size,
        child: inner,
      );
    }

    return Container(
      key: outerKey,
      width: size,
      height: size,
      padding: EdgeInsets.all(framePadding),
      decoration: BoxDecoration(
        gradient: aiActivationGradient,
        borderRadius: outerRadius,
        boxShadow: buildAiActivationGlowShadows(compact: true),
      ),
      child: inner,
    );
  }
}
