import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/ai_overlay_assistant_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AiOverlayCollapsedBall extends StatelessWidget {
  const AiOverlayCollapsedBall({
    required this.onTap,
    this.isHighlighted = false,
    super.key,
  });

  static const Key highlightRingKey = ValueKey<String>(
    'ai_overlay_collapsed_ball_highlight_ring',
  );
  static const Key innerBallKey = ValueKey<String>(
    'ai_overlay_collapsed_ball_inner',
  );

  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44.r,
      height: 44.r,
      child: AiOverlayAssistantGlyph(
        size: 44.r,
        isHighlighted: isHighlighted,
        onTap: onTap,
        outerKey: highlightRingKey,
        innerKey: innerBallKey,
      ),
    );
  }
}
