import 'dart:ui';

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
    final screenSize = mediaQuery.size;
    final portraitTopInset =
        mediaQuery.orientation == Orientation.portrait ? mediaQuery.padding.top : 0.0;
    final isExpanded = useState(false);
    final offset = useState<Offset?>(null);
    final dragStartGlobal = useRef<Offset?>(null);
    final dragStartOffset = useRef<Offset?>(null);
    final collapsedDiameter = 52.r;
    final expandedSize = Size(236.r, 156.r);
    final safePadding = 12.r;

    Size currentSize() => isExpanded.value
        ? expandedSize
        : Size(collapsedDiameter, collapsedDiameter);

    Offset defaultOffset(Size size) => Offset(
      screenSize.width - size.width - 20.r,
      portraitTopInset + 88.r,
    );

    Offset clampOffset(Offset value, Size size) {
      final minX = safePadding;
      final maxX = (screenSize.width - size.width - safePadding).clamp(minX, double.infinity);
      final minY = portraitTopInset + safePadding;
      final maxY =
          (screenSize.height - size.height - safePadding).clamp(minY, double.infinity);
      return Offset(
        value.dx.clamp(minX, maxX),
        value.dy.clamp(minY, maxY),
      );
    }

    useEffect(() {
      isExpanded.value = false;
      final size = Size(collapsedDiameter, collapsedDiameter);
      offset.value = clampOffset(defaultOffset(size), size);
      return null;
    }, [selectedProcess.pid]);

    useEffect(() {
      final size = currentSize();
      offset.value = clampOffset(offset.value ?? defaultOffset(size), size);
      return null;
    }, [
      screenSize.width,
      screenSize.height,
      portraitTopInset,
      isExpanded.value,
    ]);

    final resolvedSize = currentSize();
    final resolvedOffset =
        clampOffset(offset.value ?? defaultOffset(resolvedSize), resolvedSize);

    return Positioned(
      left: resolvedOffset.dx,
      top: resolvedOffset.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (details) {
          dragStartGlobal.value = details.globalPosition;
          dragStartOffset.value = resolvedOffset;
        },
        onPanUpdate: (details) {
          final startGlobal = dragStartGlobal.value;
          final startOffset = dragStartOffset.value;
          if (startGlobal == null || startOffset == null) {
            return;
          }
          final delta = details.globalPosition - startGlobal;
          offset.value = clampOffset(startOffset + delta, resolvedSize);
        },
        onPanEnd: (_) {
          dragStartGlobal.value = null;
          dragStartOffset.value = null;
        },
        onPanCancel: () {
          dragStartGlobal.value = null;
          dragStartOffset.value = null;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: resolvedSize.width,
          height: resolvedSize.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isExpanded.value ? 22.r : 26.r),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF7C3AED),
                Color(0xFF2563EB),
                Color(0xFF06B6D4),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                blurRadius: 18.r,
                offset: Offset(0, 6.r),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: isExpanded.value
              ? _AiOverlayExpandedPanel(
                  onCollapse: () {
                    isExpanded.value = false;
                  },
                )
              : _AiOverlayCollapsedBall(
                  onTap: () {
                    isExpanded.value = true;
                  },
                ),
        ),
      ),
    );
  }
}

class _AiOverlayCollapsedBall extends StatelessWidget {
  const _AiOverlayCollapsedBall({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              top: 9.r,
              right: 10.r,
              child: Container(
                width: 7.r,
                height: 7.r,
                decoration: BoxDecoration(
                  color: const Color(0xFFBAE6FD),
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFFBAE6FD).withValues(alpha: 0.55),
                      blurRadius: 8.r,
                    ),
                  ],
                ),
              ),
            ),
            Icon(
              Icons.auto_awesome_rounded,
              size: 24.r,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _AiOverlayExpandedPanel extends StatelessWidget {
  const _AiOverlayExpandedPanel({required this.onCollapse});

  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ColoredBox(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(14.r, 12.r, 12.r, 12.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 26.r,
                    height: 26.r,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 15.r,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8.r),
                  Expanded(
                    child: Text(
                      'AI Assistant',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: onCollapse,
                      child: Padding(
                        padding: EdgeInsets.all(4.r),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16.r,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.r),
              Text(
                'Click behavior is now local.\nThis panel no longer depends on hiding and reopening the outer overlay.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.94),
                  fontSize: 12.sp,
                  height: 1.35,
                ),
              ),
              const Spacer(),
              Container(
                height: 34.r,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  'AI Overlay Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
