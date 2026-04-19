import 'dart:math' as math;
import 'dart:ui';

import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/ai_overlay_ui_state_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/ai_overlay_collapsed_ball.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AiOverlay extends HookConsumerWidget {
  const AiOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final isPanelVisible = ref.watch(
      overlayWindowHostRuntimeProvider.select(
        (state) => state.payload.isPanel && !state.isTransitioningToPanel,
      ),
    );

    if (!isPanelVisible || selectedProcess == null) {
      return const SizedBox.shrink();
    }

    final mediaQuery = MediaQuery.of(context);
    final portraitTopInset = mediaQuery.orientation == Orientation.portrait
        ? mediaQuery.padding.top
        : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : mediaQuery.size.width,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : mediaQuery.size.height,
        );
        return _AiOverlayViewport(
          selectedPid: selectedProcess.pid,
          viewportSize: viewportSize,
          portraitTopInset: portraitTopInset,
        );
      },
    );
  }
}

class _AiOverlayViewport extends HookConsumerWidget {
  const _AiOverlayViewport({
    required this.selectedPid,
    required this.viewportSize,
    required this.portraitTopInset,
  });

  final int selectedPid;
  final Size viewportSize;
  final double portraitTopInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlayState = ref.watch(aiOverlayUiStateControllerProvider);
    final overlayStateNotifier = ref.read(aiOverlayUiStateControllerProvider.notifier);
    final isExpanded = overlayState.isExpanded;
    final offset = overlayState.offset;
    final persistedPanelSize = overlayState.panelSize;
    final dragStartGlobal = useRef<Offset?>(null);
    final dragStartOffset = useRef<Offset?>(null);
    final resizeStartGlobal = useRef<Offset?>(null);
    final resizeStartSize = useRef<Size?>(null);
    final isResizing = useRef(false);
    final pendingBoundPid = useRef<int?>(null);
    final pendingLayoutKey = useRef<String?>(null);
    final collapsedDiameter = 44.r;
    final defaultExpandedSize = Size(236.r, 156.r);
    final minExpandedSize = Size(190.r, 128.r);
    final safePadding = 12.r;
    final expandedBorderRadius = 20.r;
    final collapsedBorderRadius = 14.r;
    final resizeHandleHighlightExtent = 28.r;
    final resizeHandleHitExtent = 34.r;
    final availableExpandedWidth = math.max(
      viewportSize.width - (safePadding * 2),
      collapsedDiameter,
    );
    final availableExpandedHeight = math.max(
      viewportSize.height - portraitTopInset - (safePadding * 2),
      collapsedDiameter,
    );
    final effectiveMinExpandedWidth = math.min(
      minExpandedSize.width,
      availableExpandedWidth,
    );
    final effectiveMinExpandedHeight = math.min(
      minExpandedSize.height,
      availableExpandedHeight,
    );

    Size clampExpandedSize(Size size) {
      return Size(
        size.width.clamp(effectiveMinExpandedWidth, availableExpandedWidth),
        size.height.clamp(
          effectiveMinExpandedHeight,
          availableExpandedHeight,
        ),
      );
    }

    final expandedSize = clampExpandedSize(
      persistedPanelSize ?? defaultExpandedSize,
    );

    Size currentSize() => isExpanded
        ? expandedSize
        : Size(collapsedDiameter, collapsedDiameter);

    Offset defaultOffset(Size size) => Offset(
      viewportSize.width - size.width - 20.r,
      portraitTopInset + 88.r,
    );

    Offset clampOffset(Offset value, Size size) {
      final minX = safePadding;
      final maxX = math.max(
        minX,
        viewportSize.width - size.width - safePadding,
      );
      final minY = portraitTopInset + safePadding;
      final maxY = math.max(
        minY,
        viewportSize.height - size.height - safePadding,
      );
      return Offset(value.dx.clamp(minX, maxX), value.dy.clamp(minY, maxY));
    }

    useEffect(() {
      final size = Size(collapsedDiameter, collapsedDiameter);
      final nextOffset = clampOffset(defaultOffset(size), size);
      if (pendingBoundPid.value == selectedPid) {
        return null;
      }
      pendingBoundPid.value = selectedPid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        pendingBoundPid.value = null;
        if (!context.mounted) {
          return;
        }
        overlayStateNotifier.bindProcess(
          pid: selectedPid,
          initialOffset: nextOffset,
          initialPanelSize: clampExpandedSize(defaultExpandedSize),
        );
      });
      return null;
    }, [selectedPid]);

    useEffect(
      () {
        final nextPanelSize = clampExpandedSize(
          persistedPanelSize ?? defaultExpandedSize,
        );
        final panelSizeChanged = persistedPanelSize != nextPanelSize;
        final size = isExpanded
            ? nextPanelSize
            : Size(collapsedDiameter, collapsedDiameter);
        final nextOffset = clampOffset(offset ?? defaultOffset(size), size);
        final layoutKey =
            '${viewportSize.width}:${viewportSize.height}:$portraitTopInset:$isExpanded:${nextPanelSize.width}:${nextPanelSize.height}:${nextOffset.dx}:${nextOffset.dy}:${panelSizeChanged ? 1 : 0}';
        if (pendingLayoutKey.value == layoutKey) {
          return null;
        }
        pendingLayoutKey.value = layoutKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          pendingLayoutKey.value = null;
          if (!context.mounted) {
            return;
          }
          if (panelSizeChanged) {
            overlayStateNotifier.setPanelSize(nextPanelSize);
          }
          overlayStateNotifier.setOffset(nextOffset);
        });
        return null;
      },
      [
        viewportSize.width,
        viewportSize.height,
        portraitTopInset,
        isExpanded,
        persistedPanelSize?.width,
        persistedPanelSize?.height,
      ],
    );

    final resolvedSize = currentSize();
    final resolvedOffset = clampOffset(
      offset ?? defaultOffset(resolvedSize),
      resolvedSize,
    );
    final showExpandedPanel =
        isExpanded &&
        resolvedSize.width > (collapsedDiameter + 4.r) &&
        resolvedSize.height > (collapsedDiameter + 4.r);

    return Stack(
      children: [
        Positioned(
          left: resolvedOffset.dx,
          top: resolvedOffset.dy,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (details) {
              if (isResizing.value) {
                return;
              }
              dragStartGlobal.value = details.globalPosition;
              dragStartOffset.value = resolvedOffset;
            },
            onPanUpdate: (details) {
              if (isResizing.value) {
                return;
              }
              final startGlobal = dragStartGlobal.value;
              final startOffset = dragStartOffset.value;
              if (startGlobal == null || startOffset == null) {
                return;
              }
              final delta = details.globalPosition - startGlobal;
              overlayStateNotifier.setOffset(
                clampOffset(startOffset + delta, resolvedSize),
              );
            },
            onPanEnd: (_) {
              dragStartGlobal.value = null;
              dragStartOffset.value = null;
            },
            onPanCancel: () {
              dragStartGlobal.value = null;
              dragStartOffset.value = null;
            },
            child: CustomPaint(
              foregroundPainter: showExpandedPanel
                  ? _AiOverlayResizeBorderHighlightPainter(
                      color: context.colorScheme.primary.withValues(alpha: 0.94),
                      borderRadius: expandedBorderRadius,
                      clipExtent: resizeHandleHighlightExtent,
                    )
                  : null,
              child: Container(
                width: resolvedSize.width,
                height: resolvedSize.height,
                decoration: BoxDecoration(
                  color: showExpandedPanel
                      ? context.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.76,
                        )
                      : null,
                  gradient: showExpandedPanel
                      ? null
                      : RadialGradient(
                          center: Alignment.center,
                          radius: 0.95,
                          colors: <Color>[
                            context.colorScheme.primary,
                            Color.lerp(
                                  context.colorScheme.primary,
                                  context.colorScheme.primaryContainer,
                                  0.58,
                                ) ??
                                context.colorScheme.primaryContainer,
                          ],
                          stops: const <double>[0.38, 1],
                        ),
                  borderRadius: BorderRadius.circular(
                    showExpandedPanel
                        ? expandedBorderRadius
                        : collapsedBorderRadius,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color:
                          (showExpandedPanel
                                  ? Colors.black
                                  : context.colorScheme.primary)
                              .withValues(alpha: showExpandedPanel ? 0.1 : 0.18),
                      blurRadius: showExpandedPanel ? 16.r : 10.r,
                      offset: Offset(0, showExpandedPanel ? 6.r : 4.r),
                    ),
                    if (!showExpandedPanel)
                      BoxShadow(
                        color: context.colorScheme.primary.withValues(alpha: 0.32),
                        blurRadius: 14.r,
                        spreadRadius: 1.2.r,
                      ),
                  ],
                  border: Border.all(
                    color: showExpandedPanel
                        ? context.colorScheme.outlineVariant.withValues(
                            alpha: 0.34,
                          )
                        : context.colorScheme.onPrimary.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: showExpandedPanel
                    ? Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: ColoredBox(
                                color: context.colorScheme.surface.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(14.r, 12.r, 12.r, 12.r),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                color: context.colorScheme.surface.withValues(
                                  alpha: 0.28,
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12.r),
                                  onTap: () {
                                    overlayStateNotifier.setExpanded(false);
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(4.r),
                                    child: Icon(
                                      Icons.remove_rounded,
                                      size: 16.r,
                                      color: context.colorScheme.onSurface
                                          .withValues(alpha: 0.82),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (details) {
                                isResizing.value = true;
                                resizeStartGlobal.value = details.globalPosition;
                                resizeStartSize.value = expandedSize;
                              },
                              onPanUpdate: (details) {
                                final startGlobal = resizeStartGlobal.value;
                                final startSize = resizeStartSize.value;
                                if (startGlobal == null || startSize == null) {
                                  return;
                                }
                                final delta =
                                    details.globalPosition - startGlobal;
                                final nextSize = clampExpandedSize(
                                  Size(
                                    startSize.width + delta.dx,
                                    startSize.height + delta.dy,
                                  ),
                                );
                                overlayStateNotifier.setPanelSize(nextSize);
                                overlayStateNotifier.setOffset(
                                  clampOffset(resolvedOffset, nextSize),
                                );
                              },
                              onPanEnd: (_) {
                                resizeStartGlobal.value = null;
                                resizeStartSize.value = null;
                                isResizing.value = false;
                              },
                              onPanCancel: () {
                                resizeStartGlobal.value = null;
                                resizeStartSize.value = null;
                                isResizing.value = false;
                              },
                              child: SizedBox(
                                width: resizeHandleHitExtent,
                                height: resizeHandleHitExtent,
                              ),
                            ),
                          ),
                        ],
                      )
                    : AiOverlayCollapsedBall(
                        onTap: () {
                          overlayStateNotifier.setExpanded(true);
                        },
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AiOverlayResizeBorderHighlightPainter extends CustomPainter {
  const _AiOverlayResizeBorderHighlightPainter({
    required this.color,
    required this.borderRadius,
    required this.clipExtent,
  });

  final Color color;
  final double borderRadius;
  final double clipExtent;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.2;
    const glowStrokeWidth = 4.2;
    final clipPadding = 6.0;
    final glowStroke = Paint()
      ..color = color.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowStrokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final outerRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    final glowRRect = outerRRect.deflate(glowStrokeWidth / 2);
    final rRect = outerRRect.deflate(strokeWidth / 2);

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        size.width - clipExtent - clipPadding,
        size.height - clipExtent - clipPadding,
        clipExtent + clipPadding,
        clipExtent + clipPadding,
      ),
    );
    canvas.drawRRect(glowRRect, glowStroke);
    canvas.drawRRect(rRect, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(
    covariant _AiOverlayResizeBorderHighlightPainter oldDelegate,
  ) {
    return oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.clipExtent != clipExtent;
  }
}
