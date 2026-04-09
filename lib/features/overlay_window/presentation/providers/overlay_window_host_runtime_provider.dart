import 'dart:async';
import 'dart:ui';

import 'package:JsxposedX/features/overlay_window/domain/models/overlay_host_layout.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_viewport_metrics.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_payload.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_presentation.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_runtime_message.dart';
import 'package:JsxposedX/features/overlay_window/presentation/models/overlay_scene_definition.dart';
import 'package:JsxposedX/features/overlay_window/presentation/models/overlay_window_host_runtime_state.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_scene_registry_provider.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_action_provider.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_query_provider.dart';
import 'package:JsxposedX/features/overlay_window/presentation/utils/overlay_window_geometry.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final overlayWindowHostRuntimeProvider =
    NotifierProvider<
      OverlayWindowHostRuntimeNotifier,
      OverlayWindowHostRuntimeState
    >(OverlayWindowHostRuntimeNotifier.new);

class OverlayWindowHostRuntimeNotifier
    extends Notifier<OverlayWindowHostRuntimeState> {
  StreamSubscription<OverlayWindowRuntimeMessage>? _subscription;
  Timer? _toastTimer;

  @override
  OverlayWindowHostRuntimeState build() {
    _subscription ??= ref
        .read(overlayWindowQueryRepositoryProvider)
        .overlayEvents
        .listen(_handleRuntimeMessage);
    ref.onDispose(() async {
      _toastTimer?.cancel();
      _toastTimer = null;
      await _subscription?.cancel();
      _subscription = null;
    });
    unawaited(refreshViewportMetrics(syncBubblePosition: true));
    return OverlayWindowHostRuntimeState(payload: _initialPayload());
  }

  Future<void> onMetricsChanged() async {
    await refreshViewportMetrics(
      syncBubblePosition:
          state.payload.isBubble && !state.isTransitioningToPanel,
    );
  }

  Future<void> setDisplayMode(OverlayWindowDisplayMode displayMode) async {
    if (state.payload.displayMode == displayMode) {
      return;
    }

    if (displayMode == OverlayWindowDisplayMode.panel) {
      state = state.copyWith(isTransitioningToPanel: true);
      await WidgetsBinding.instance.endOfFrame;
      final updated = await ref
          .read(overlayWindowActionRepositoryProvider)
          .updateOverlayHost(OverlayHostLayout.panel());
      if (!updated) {
        state = state.copyWith(isTransitioningToPanel: false);
        return;
      }

      final nextPayload = state.payload.copyWith(
        displayMode: OverlayWindowDisplayMode.panel,
      );
      state = state.copyWith(
        payload: nextPayload,
        isTransitioningToPanel: false,
      );
      await ref
          .read(overlayWindowActionRepositoryProvider)
          .sharePayload(nextPayload);
      return;
    }

    final viewport = await _ensureViewportMetrics();
    if (viewport == null) {
      return;
    }

    final bubbleSize = _bubbleSizeForScene(state.payload.sceneId);
    final bubbleVisualOffset = OverlayWindowGeometry.clampBubbleVisualOffset(
      state.bubbleVisualOffset ??
          OverlayWindowGeometry.defaultBubbleVisualOffset(
            viewport: viewport,
            bubbleSize: bubbleSize,
          ),
      viewport: viewport,
      bubbleSize: bubbleSize,
    );

    final updated = await ref
        .read(overlayWindowActionRepositoryProvider)
        .updateOverlayHost(
          OverlayHostLayout(
            width: OverlayWindowGeometry.bubbleHostExtent(bubbleSize).round(),
            height: OverlayWindowGeometry.bubbleHostExtent(bubbleSize).round(),
            position: OverlayWindowGeometry.hostPositionFromVisualOffset(
              bubbleVisualOffset,
            ),
            enableDrag: true,
            displayMode: OverlayWindowDisplayMode.bubble,
          ),
        );
    if (!updated) {
      return;
    }

    final nextPayload = state.payload.copyWith(
      displayMode: OverlayWindowDisplayMode.bubble,
    );
    state = state.copyWith(
      payload: nextPayload,
      bubbleVisualOffset: bubbleVisualOffset,
    );
    await ref
        .read(overlayWindowActionRepositoryProvider)
        .sharePayload(nextPayload);
  }

  Future<void> closeOverlay() async {
    _toastTimer?.cancel();
    _toastTimer = null;
    await ref.read(overlayWindowActionRepositoryProvider).closeOverlay();
  }

  void clearActiveToast() {
    _toastTimer?.cancel();
    _toastTimer = null;
    state = state.copyWith(clearActiveToast: true);
  }

  Future<void> refreshViewportMetrics({
    required bool syncBubblePosition,
  }) async {
    final viewport = await ref
        .read(overlayWindowQueryRepositoryProvider)
        .getOverlayViewportMetrics();

    state = state.copyWith(
      viewportMetrics: viewport,
      bubbleVisualOffset: state.bubbleVisualOffset == null
          ? null
          : OverlayWindowGeometry.clampBubbleVisualOffset(
              state.bubbleVisualOffset!,
              viewport: viewport,
              bubbleSize: _bubbleSizeForScene(state.payload.sceneId),
            ),
    );

    if (syncBubblePosition &&
        state.payload.isBubble &&
        !state.isTransitioningToPanel) {
      await syncBubbleVisualOffsetFromHost();
    }
  }

  Future<void> syncBubbleVisualOffsetFromHost() async {
    final viewport = await _ensureViewportMetrics();
    if (viewport == null) {
      return;
    }

    final bubbleSize = _bubbleSizeForScene(state.payload.sceneId);
    final hostPosition = await ref
        .read(overlayWindowQueryRepositoryProvider)
        .getOverlayPosition();
    final visualOffset = OverlayWindowGeometry.clampBubbleVisualOffset(
      OverlayWindowGeometry.visualOffsetFromHostPosition(hostPosition),
      viewport: viewport,
      bubbleSize: bubbleSize,
    );
    state = state.copyWith(bubbleVisualOffset: visualOffset);
  }

  Future<void> moveBubbleHostToVisualOffset(Offset bubbleVisualOffset) async {
    state = state.copyWith(bubbleVisualOffset: bubbleVisualOffset);
    await ref
        .read(overlayWindowActionRepositoryProvider)
        .moveOverlay(
          OverlayWindowGeometry.hostPositionFromVisualOffset(
            bubbleVisualOffset,
          ),
        );
  }

  OverlayWindowPayload _initialPayload() {
    return OverlayWindowPayload(
      sceneId: _defaultSceneId(),
      displayMode: OverlayWindowDisplayMode.bubble,
      localeLanguageCode: 'zh',
      localeCountryCode: 'CN',
      isDarkTheme: false,
      primaryColorValue: 0xFF98D2D5,
    );
  }

  int _defaultSceneId() {
    final registry = ref.read(overlaySceneRegistryProvider);
    if (registry.isEmpty) {
      return -1;
    }
    return registry.keys.first;
  }

  double _bubbleSizeForScene(int sceneId) {
    return _scene(sceneId)?.bubbleSize ??
        OverlayWindowPresentation.defaultBubbleSize;
  }

  OverlaySceneDefinition? _scene(int sceneId) {
    return ref.read(overlaySceneRegistryProvider)[sceneId];
  }

  Future<OverlayViewportMetrics?> _ensureViewportMetrics() async {
    if (state.viewportMetrics != null) {
      return state.viewportMetrics;
    }
    await refreshViewportMetrics(syncBubblePosition: false);
    return state.viewportMetrics;
  }

  void _handleRuntimeMessage(OverlayWindowRuntimeMessage message) {
    message.map(
      payload: (payloadMessage) {
        state = state.copyWith(payload: payloadMessage.payload);
        if (payloadMessage.payload.isBubble && !state.isTransitioningToPanel) {
          unawaited(syncBubbleVisualOffsetFromHost());
        }
      },
      event: (eventMessage) {
        final event = eventMessage.event;
        if (!state.payload.isBubble || state.isTransitioningToPanel) {
          return;
        }
        if (event.isBubbleTap) {
          unawaited(setDisplayMode(OverlayWindowDisplayMode.panel));
          return;
        }
        if (!event.isBubbleDragEnd) {
          return;
        }

        final hostPosition = event.hostPosition;
        final viewport = state.viewportMetrics;
        if (hostPosition == null || viewport == null) {
          return;
        }

        final snappedVisualOffset =
            OverlayWindowGeometry.snapBubbleVisualOffset(
              OverlayWindowGeometry.visualOffsetFromHostPosition(hostPosition),
              viewport: viewport,
              bubbleSize: _bubbleSizeForScene(state.payload.sceneId),
            );
        unawaited(moveBubbleHostToVisualOffset(snappedVisualOffset));
      },
      toast: (toastMessage) {
        _toastTimer?.cancel();
        state = state.copyWith(activeToast: toastMessage.toast);
        _toastTimer = Timer(
          Duration(milliseconds: toastMessage.toast.durationMs),
          clearActiveToast,
        );
      },
    );
  }
}
