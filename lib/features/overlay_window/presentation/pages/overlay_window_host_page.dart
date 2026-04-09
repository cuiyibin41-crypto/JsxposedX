import 'dart:async';

import 'package:JsxposedX/common/widgets/overlay_window/overlay_bubble.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_window.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_toast.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_payload.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_presentation.dart';
import 'package:JsxposedX/features/overlay_window/presentation/models/overlay_scene_definition.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_scene_registry_provider.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class OverlayWindowHostPage extends HookConsumerWidget {
  const OverlayWindowHostPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(overlayWindowHostRuntimeProvider.notifier);
    final metricsObserver = useMemoized(
      () => _OverlayMetricsObserver(
        onMetricsChanged: () {
          unawaited(controller.onMetricsChanged());
        },
      ),
      <Object>[controller],
    );
    useEffect(() {
      WidgetsBinding.instance.addObserver(metricsObserver);
      return () => WidgetsBinding.instance.removeObserver(metricsObserver);
    }, <Object>[metricsObserver]);

    final runtimeState = ref.watch(overlayWindowHostRuntimeProvider);
    final payload = runtimeState.payload;
    final content = runtimeState.isTransitioningToPanel
        ? const SizedBox.expand()
        : payload.isPanel
        ? _buildPanelWindow(context, ref, payload.sceneId)
        : _buildBubble(ref, payload.sceneId);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          content,
          if (runtimeState.activeToast != null)
            _OverlayToastView(toast: runtimeState.activeToast!),
        ],
      ),
    );
  }
}

class _OverlayMetricsObserver with WidgetsBindingObserver {
  _OverlayMetricsObserver({required this.onMetricsChanged});

  final VoidCallback onMetricsChanged;

  @override
  void didChangeMetrics() {
    onMetricsChanged();
  }
}

OverlaySceneDefinition? _scene(WidgetRef ref, int sceneId) {
  return ref.read(overlaySceneRegistryProvider)[sceneId];
}

Widget _buildPanelWindow(BuildContext context, WidgetRef ref, int sceneId) {
  final scene = _scene(ref, sceneId);
  final controller = ref.read(overlayWindowHostRuntimeProvider.notifier);
  final controls = OverlayWindowPanelControls(
    minimize: () => controller.setDisplayMode(OverlayWindowDisplayMode.bubble),
    close: () {
      unawaited(controller.closeOverlay());
    },
  );

  if (scene == null) {
    return _buildUnknownScene(context, ref);
  }

  return OverlayWindowPanelScope(
    controls: controls,
    child: scene.panelBuilder(context),
  );
}

Widget _buildBubble(WidgetRef ref, int sceneId) {
  return SizedBox.expand(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: OverlayBubble(size: _bubbleSizeForScene(ref, sceneId)),
    ),
  );
}

Widget _buildUnknownScene(BuildContext context, WidgetRef ref) {
  return OverlayWindowScaffold(
    overlayBar: OverlayWindowBar(
      title: Text(context.l10n.overlayWindowFallbackTitle),
      subtitle: Text(context.l10n.overlayFloatingToolWindow),
      showMinimizeAction: true,
      showCloseAction: true,
    ),
    onBackdropTap: () {
      unawaited(ref.read(overlayWindowHostRuntimeProvider.notifier).closeOverlay());
    },
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.overlayWindowUnknownSceneTitle,
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          context.l10n.overlayWindowUnknownSceneDescription,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        SizedBox(height: 16.h),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () {
              unawaited(
                ref.read(overlayWindowHostRuntimeProvider.notifier).closeOverlay(),
              );
            },
            child: Text(context.l10n.close),
          ),
        ),
      ],
    ),
  );
}

double _bubbleSizeForScene(WidgetRef ref, int sceneId) {
  return _scene(ref, sceneId)?.bubbleSize ??
      OverlayWindowPresentation.defaultBubbleSize;
}

class _OverlayToastView extends StatelessWidget {
  const _OverlayToastView({required this.toast});

  final OverlayToast toast;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20.w,
              right: 20.w,
              bottom: 32.h,
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 18),
                    child: child,
                  ),
                );
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colorScheme.primary.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(22.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18.r,
                      offset: Offset(0, 8.h),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 12.h,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 0.82.sw),
                    child: Text(
                      toast.message,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
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
