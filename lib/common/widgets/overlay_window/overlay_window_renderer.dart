import 'dart:async';

import 'package:JsxposedX/common/widgets/cache_image.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_scene.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_window.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_window_controller.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_window_scope.dart';
import 'package:JsxposedX/core/constants/assets_constants.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/memory_tool_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayWindowRenderer extends StatefulWidget {
  const OverlayWindowRenderer({super.key});

  @override
  State<OverlayWindowRenderer> createState() => _OverlayWindowRendererState();
}

class _OverlayWindowRendererState extends State<OverlayWindowRenderer> {
  static const double _bubbleEdgePadding = 16;
  static const double _bubbleHostPadding = 16;
  static const double _panelMaxWidth = 560;
  static const double _panelMaxHeight = 720;

  StreamSubscription<dynamic>? _subscription;
  OverlayWindowPayload _payload = const OverlayWindowPayload(
    scene: OverlaySceneEnum.memoryTool,
  );
  _OverlayViewport? _fullViewport;
  Offset? _bubbleVisualOffset;
  bool _needsBubbleHostSync = true;

  @override
  void initState() {
    super.initState();
    _subscription = FlutterOverlayWindow.overlayListener.listen(_handlePayload);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final safePadding = MediaQuery.of(context).viewPadding;
          final bubbleSize = _bubbleSizeForScene(_payload.scene);
          final hostSize = Size(constraints.maxWidth, constraints.maxHeight);
          final isFullscreenHost = _isFullscreenHost(
            hostSize: hostSize,
            bubbleSize: bubbleSize,
          );
          _captureViewport(
            hostSize: hostSize,
            safePadding: safePadding,
            bubbleSize: bubbleSize,
          );

          if (_payload.isBubble &&
              _needsBubbleHostSync &&
              _fullViewport != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_payload.isBubble || !_needsBubbleHostSync) {
                return;
              }
              unawaited(_syncOverlayHost());
            });
          }

          if (_payload.isPanel) {
            if (!isFullscreenHost) {
              return const SizedBox.expand();
            }
            return OverlayWindow(
              title: _resolveTitle(_payload.scene),
              subtitle: 'Floating tool window',
              onBackdropTap: () =>
                  _setDisplayMode(OverlayWindowDisplayMode.bubble),
              onMinimize: () =>
                  _setDisplayMode(OverlayWindowDisplayMode.bubble),
              onClose: () {
                unawaited(OverlayWindowScope.of(context).hide());
              },
              maxWidth: _panelMaxWidth,
              maxHeight: _panelMaxHeight,
              child: _buildScene(_payload.scene),
            );
          }

          return SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.all(_bubbleHostPadding),
              child: _OverlayBubble(size: bubbleSize),
            ),
          );
        },
      ),
    );
  }

  void _handlePayload(dynamic rawPayload) {
    final overlayEvent = OverlayWindowEvent.maybeFromRaw(rawPayload);
    if (overlayEvent != null) {
      _handleOverlayEvent(overlayEvent);
      return;
    }

    final nextPayload = OverlayWindowPayload.fromRaw(rawPayload);
    if (!mounted) {
      return;
    }

    setState(() {
      _payload = nextPayload;
      if (nextPayload.isPanel) {
        _needsBubbleHostSync = false;
      } else {
        _needsBubbleHostSync = true;
      }
    });

    unawaited(_syncOverlayHost());
  }

  void _handleOverlayEvent(OverlayWindowEvent event) {
    if (!mounted || !_payload.isBubble) {
      return;
    }

    if (event.isBubbleTap) {
      unawaited(_setDisplayMode(OverlayWindowDisplayMode.panel));
      return;
    }

    if (!event.isBubbleDragEnd) {
      return;
    }

    final hostPosition = event.hostPosition;
    final viewport = _fullViewport;
    if (hostPosition == null || viewport == null) {
      return;
    }

    final bubbleSize = _bubbleSizeForScene(_payload.scene);
    final visualOffset = Offset(
      hostPosition.x + _bubbleHostPadding,
      hostPosition.y + _bubbleHostPadding,
    );
    final snappedVisualOffset = _snapBubbleVisualOffset(
      visualOffset,
      viewport: viewport,
      bubbleSize: bubbleSize,
    );

    setState(() {
      _bubbleVisualOffset = snappedVisualOffset;
    });
    unawaited(_moveBubbleHostToVisualOffset(snappedVisualOffset));
  }

  Future<void> _setDisplayMode(String displayMode) async {
    if (_payload.displayMode == displayMode) {
      return;
    }

    final nextPayload = _payload.copyWith(displayMode: displayMode);
    setState(() {
      _payload = nextPayload;
      if (nextPayload.isPanel) {
        _needsBubbleHostSync = false;
      } else {
        _needsBubbleHostSync = true;
      }
    });

    await _syncOverlayHost();
  }

  Future<void> _syncOverlayHost() async {
    final overlayFlag = _payload.isPanel
        ? OverlayFlag.defaultFlag
        : OverlayFlag.focusPointer;

    if (_payload.isPanel) {
      await FlutterOverlayWindow.resizeOverlay(
        WindowSize.matchParent,
        WindowSize.fullCover,
        false,
      );
      await FlutterOverlayWindow.moveOverlay(const OverlayPosition(0, 0));
      await FlutterOverlayWindow.updateFlag(overlayFlag);
      return;
    }

    final viewport = _fullViewport;
    if (viewport == null) {
      _needsBubbleHostSync = true;
      await FlutterOverlayWindow.updateFlag(overlayFlag);
      return;
    }

    final bubbleSize = _bubbleSizeForScene(_payload.scene);
    final bubbleVisualOffset = _resolvedBubbleVisualOffset(
      viewport: viewport,
      bubbleSize: bubbleSize,
    );
    final hostExtent = _bubbleHostExtent(bubbleSize);
    _bubbleVisualOffset = bubbleVisualOffset;
    _needsBubbleHostSync = false;

    await FlutterOverlayWindow.resizeOverlay(
      hostExtent.round(),
      hostExtent.round(),
      true,
    );
    await _moveBubbleHostToVisualOffset(bubbleVisualOffset);
    await FlutterOverlayWindow.updateFlag(overlayFlag);
  }

  void _captureViewport({
    required Size hostSize,
    required EdgeInsets safePadding,
    required double bubbleSize,
  }) {
    final isFullscreenHost = _isFullscreenHost(
      hostSize: hostSize,
      bubbleSize: bubbleSize,
    );
    if (!isFullscreenHost) {
      return;
    }

    final nextViewport = _OverlayViewport(
      size: hostSize,
      safePadding: safePadding,
    );
    if (_fullViewport == nextViewport) {
      return;
    }

    _fullViewport = nextViewport;
    if (_payload.isBubble) {
      _needsBubbleHostSync = true;
    }
  }

  double _bubbleHostExtent(double bubbleSize) {
    return bubbleSize + (_bubbleHostPadding * 2);
  }

  bool _isFullscreenHost({required Size hostSize, required double bubbleSize}) {
    final bubbleExtent = _bubbleHostExtent(bubbleSize);
    return hostSize.width > bubbleExtent + 1 ||
        hostSize.height > bubbleExtent + 1;
  }

  Future<void> _moveBubbleHostToVisualOffset(Offset bubbleVisualOffset) async {
    await FlutterOverlayWindow.moveOverlay(
      OverlayPosition(
        bubbleVisualOffset.dx - _bubbleHostPadding,
        bubbleVisualOffset.dy - _bubbleHostPadding,
      ),
    );
  }

  Offset _resolvedBubbleVisualOffset({
    required _OverlayViewport viewport,
    required double bubbleSize,
  }) {
    final currentOffset =
        _bubbleVisualOffset ??
        _defaultBubbleVisualOffset(viewport: viewport, bubbleSize: bubbleSize);
    return _clampBubbleVisualOffset(
      currentOffset,
      viewport: viewport,
      bubbleSize: bubbleSize,
    );
  }

  Offset _defaultBubbleVisualOffset({
    required _OverlayViewport viewport,
    required double bubbleSize,
  }) {
    final bounds = _bubbleBounds(viewport: viewport, bubbleSize: bubbleSize);
    final centerY = bounds.top + (bounds.height / 2);
    return Offset(bounds.right, centerY);
  }

  Offset _clampBubbleVisualOffset(
    Offset offset, {
    required _OverlayViewport viewport,
    required double bubbleSize,
  }) {
    final bounds = _bubbleBounds(viewport: viewport, bubbleSize: bubbleSize);
    return Offset(
      offset.dx.clamp(bounds.left, bounds.right).toDouble(),
      offset.dy.clamp(bounds.top, bounds.bottom).toDouble(),
    );
  }

  Offset _snapBubbleVisualOffset(
    Offset offset, {
    required _OverlayViewport viewport,
    required double bubbleSize,
  }) {
    final bounds = _bubbleBounds(viewport: viewport, bubbleSize: bubbleSize);
    final bubbleCenterX = offset.dx + (bubbleSize / 2);
    final targetX = bubbleCenterX < (viewport.size.width / 2)
        ? bounds.left
        : bounds.right;
    return Offset(
      targetX,
      offset.dy.clamp(bounds.top, bounds.bottom).toDouble(),
    );
  }

  _BubbleBounds _bubbleBounds({
    required _OverlayViewport viewport,
    required double bubbleSize,
  }) {
    final left = viewport.safePadding.left + _bubbleEdgePadding;
    final top = viewport.safePadding.top + _bubbleEdgePadding;
    final right =
        (viewport.size.width -
                bubbleSize -
                viewport.safePadding.right -
                _bubbleEdgePadding)
            .clamp(left, double.infinity)
            .toDouble();
    final bottom =
        (viewport.size.height -
                bubbleSize -
                viewport.safePadding.bottom -
                _bubbleEdgePadding)
            .clamp(top, double.infinity)
            .toDouble();
    return _BubbleBounds(left: left, top: top, right: right, bottom: bottom);
  }

  Widget _buildScene(int scene) {
    switch (scene) {
      case OverlaySceneEnum.memoryTool:
        return const MemoryToolOverlay();
      default:
        return const SizedBox.shrink();
    }
  }

  double _bubbleSizeForScene(int scene) {
    switch (scene) {
      case OverlaySceneEnum.memoryTool:
        return OverlayWindowController.defaultBubbleSize;
      default:
        return OverlayWindowController.defaultBubbleSize;
    }
  }

  String _resolveTitle(int scene) {
    switch (scene) {
      case OverlaySceneEnum.memoryTool:
        return 'Memory Tool';
      default:
        return 'Overlay Window';
    }
  }
}

class _OverlayBubble extends StatelessWidget {
  const _OverlayBubble({required this.size});

  final double size;

  static const LinearGradient _bubbleGradient = LinearGradient(
    colors: <Color>[Color(0xFF70D7F9), Color(0xFFAD98FF), Color(0xFFFFB385)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _bubbleGradient,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(
                0xFF70D7F9,
              ).withValues(alpha: isDark ? 0.34 : 0.30),
              blurRadius: 15,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: const Color(
                0xFFAD98FF,
              ).withValues(alpha: isDark ? 0.32 : 0.30),
              blurRadius: 20,
              offset: const Offset(5, 5),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: ClipOval(
                  child: CacheImage(
                    imageUrl: AssetsConstants.logo,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleBounds {
  const _BubbleBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get height => bottom - top;
}

class _OverlayViewport {
  const _OverlayViewport({required this.size, required this.safePadding});

  final Size size;
  final EdgeInsets safePadding;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _OverlayViewport &&
        other.size == size &&
        other.safePadding == safePadding;
  }

  @override
  int get hashCode => Object.hash(size, safePadding);
}
