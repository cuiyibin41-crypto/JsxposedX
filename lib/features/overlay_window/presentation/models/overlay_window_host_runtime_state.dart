import 'dart:ui';

import 'package:JsxposedX/features/overlay_window/domain/models/overlay_toast.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_viewport_metrics.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_payload.dart';

class OverlayWindowHostRuntimeState {
  const OverlayWindowHostRuntimeState({
    required this.payload,
    this.viewportMetrics,
    this.bubbleVisualOffset,
    this.activeToast,
    this.isTransitioningToPanel = false,
  });

  final OverlayWindowPayload payload;
  final OverlayViewportMetrics? viewportMetrics;
  final Offset? bubbleVisualOffset;
  final OverlayToast? activeToast;
  final bool isTransitioningToPanel;

  OverlayWindowHostRuntimeState copyWith({
    OverlayWindowPayload? payload,
    OverlayViewportMetrics? viewportMetrics,
    Offset? bubbleVisualOffset,
    OverlayToast? activeToast,
    bool preserveBubbleVisualOffset = true,
    bool clearActiveToast = false,
    bool? isTransitioningToPanel,
  }) {
    return OverlayWindowHostRuntimeState(
      payload: payload ?? this.payload,
      viewportMetrics: viewportMetrics ?? this.viewportMetrics,
      bubbleVisualOffset: preserveBubbleVisualOffset
          ? bubbleVisualOffset ?? this.bubbleVisualOffset
          : bubbleVisualOffset,
      activeToast: clearActiveToast ? null : activeToast ?? this.activeToast,
      isTransitioningToPanel:
          isTransitioningToPanel ?? this.isTransitioningToPanel,
    );
  }
}
