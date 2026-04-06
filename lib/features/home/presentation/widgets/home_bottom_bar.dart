import 'dart:math' as math;

import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomeBottomNavItemData {
  const HomeBottomNavItemData({
    required this.label,
    required this.outlinedIcon,
    required this.filledIcon,
  });

  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;
}

class HomeBottomBar extends StatelessWidget {
  const HomeBottomBar({
    super.key,
    required this.navItems,
    required this.currentIndex,
    required this.onTap,
    required this.fabSize,
    required this.fabOffsetY,
    required this.height,
  });

  final List<HomeBottomNavItemData> navItems;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double fabSize;
  final double fabOffsetY;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final shape = _HalfCircleNotchedShape(
      cornerRadius: 28.r,
      notchMargin: 1.w,
    );

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(12.w, 0, 12.w, 10.h),
      child: CustomPaint(
        foregroundPainter: _BottomBarBorderPainter(
          shape: shape,
          guestDiameter: fabSize,
          guestCenterY: fabOffsetY,
          color: colorScheme.outline.withValues(
            alpha: context.isDark ? 0.34 : 0.18,
          ),
          strokeWidth: 1.1,
        ),
        child: PhysicalShape(
          clipper: _BottomBarClipper(
            shape: shape,
            guestDiameter: fabSize,
            guestCenterY: fabOffsetY,
          ),
          color: colorScheme.surface,
          elevation: 12,
          shadowColor: Colors.black.withValues(
            alpha: context.isDark ? 0.50 : 0.20,
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _BottomNavItem(
                      item: navItems[0],
                      selected: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      item: navItems[1],
                      selected: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                  ),
                  SizedBox(width: 76.w),
                  Expanded(
                    child: _BottomNavItem(
                      item: navItems[2],
                      selected: currentIndex == 2,
                      onTap: () => onTap(2),
                    ),
                  ),
                  Expanded(
                    child: _BottomNavItem(
                      item: navItems[3],
                      selected: currentIndex == 3,
                      onTap: () => onTap(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HalfCircleNotchedShape extends NotchedShape {
  const _HalfCircleNotchedShape({
    required this.cornerRadius,
    required this.notchMargin,
  });

  final double cornerRadius;
  final double notchMargin;

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    if (guest == null || !host.overlaps(guest)) {
      return Path()
        ..addRRect(
          RRect.fromRectAndRadius(host, Radius.circular(cornerRadius)),
        );
    }

    return getOuterPathWithGuestMetrics(
      host,
      guestDiameter: guest.width,
      guestCenterY: guest.center.dy,
    );
  }

  Path getOuterPathWithGuestMetrics(
    Rect host, {
    required double guestDiameter,
    required double guestCenterY,
  }) {
    if (guestDiameter <= 0) {
      return Path()
        ..addRRect(
          RRect.fromRectAndRadius(host, Radius.circular(cornerRadius)),
        );
    }

    final double notchRadius = guestDiameter / 2.0 + notchMargin;
    final Offset center = Offset(host.center.dx, guestCenterY);

    const double s1 = 15.0;
    const double s2 = 1.0;

    final double r = notchRadius;
    final double a = -1.0 * r - s2;
    final double b = host.top - center.dy;

    final double n2 = math.sqrt(b * b * r * r * (a * a + b * b - r * r));
    final double p2xA = ((a * r * r) - n2) / (a * a + b * b);
    final double p2xB = ((a * r * r) + n2) / (a * a + b * b);
    final double p2yA = math.sqrt(r * r - p2xA * p2xA);
    final double p2yB = math.sqrt(r * r - p2xB * p2xB);

    final List<Offset> p = List<Offset>.filled(6, Offset.zero);

    p[0] = Offset(a - s1, b);
    p[1] = Offset(a, b);
    final double cmpx = b < 0 ? -1.0 : 1.0;
    p[2] = cmpx * p2yA > cmpx * p2yB
        ? Offset(p2xA, p2yA)
        : Offset(p2xB, p2yB);
    p[3] = Offset(-1.0 * p[2].dx, p[2].dy);
    p[4] = Offset(-1.0 * p[1].dx, p[1].dy);
    p[5] = Offset(-1.0 * p[0].dx, p[0].dy);

    for (int i = 0; i < p.length; i++) {
      p[i] = p[i] + center;
    }

    final path = Path();
    path.moveTo(host.left + cornerRadius, host.top);
    path.lineTo(p[0].dx, p[0].dy);
    path.quadraticBezierTo(p[1].dx, p[1].dy, p[2].dx, p[2].dy);
    path.arcToPoint(
      p[3],
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    path.quadraticBezierTo(p[4].dx, p[4].dy, p[5].dx, p[5].dy);
    path.lineTo(host.right - cornerRadius, host.top);
    path.arcToPoint(
      Offset(host.right, host.top + cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(host.right, host.bottom - cornerRadius);
    path.arcToPoint(
      Offset(host.right - cornerRadius, host.bottom),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(host.left + cornerRadius, host.bottom);
    path.arcToPoint(
      Offset(host.left, host.bottom - cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(host.left, host.top + cornerRadius);
    path.arcToPoint(
      Offset(host.left + cornerRadius, host.top),
      radius: Radius.circular(cornerRadius),
    );
    path.close();
    return path;
  }
}

class _BottomBarClipper extends CustomClipper<Path> {
  const _BottomBarClipper({
    required this.shape,
    required this.guestDiameter,
    required this.guestCenterY,
  });

  final _HalfCircleNotchedShape shape;
  final double guestDiameter;
  final double guestCenterY;

  @override
  Path getClip(Size size) {
    return shape.getOuterPathWithGuestMetrics(
      Offset.zero & size,
      guestDiameter: guestDiameter,
      guestCenterY: guestCenterY,
    );
  }

  @override
  bool shouldReclip(covariant _BottomBarClipper oldClipper) {
    return oldClipper.shape != shape ||
        oldClipper.guestDiameter != guestDiameter ||
        oldClipper.guestCenterY != guestCenterY;
  }
}

class _BottomBarBorderPainter extends CustomPainter {
  const _BottomBarBorderPainter({
    required this.shape,
    required this.guestDiameter,
    required this.guestCenterY,
    required this.color,
    required this.strokeWidth,
  });

  final _HalfCircleNotchedShape shape;
  final double guestDiameter;
  final double guestCenterY;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = shape.getOuterPathWithGuestMetrics(
      rect,
      guestDiameter: guestDiameter,
      guestCenterY: guestCenterY,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BottomBarBorderPainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.guestDiameter != guestDiameter ||
        oldDelegate.guestCenterY != guestCenterY ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final HomeBottomNavItemData item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final iconColor = selected
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.50);
    final labelColor = selected
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.44);

    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: onTap,
      child: SizedBox(
        height: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: 42.w,
              height: 30.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                color: selected
                    ? colorScheme.primary.withValues(
                        alpha: context.isDark ? 0.16 : 0.10,
                      )
                    : Colors.transparent,
              ),
              child: Icon(
                selected ? item.filledIcon : item.outlinedIcon,
                size: 22.sp,
                color: iconColor,
              ),
            ),
            SizedBox(height: 2.h),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: 10.sp,
                color: labelColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                height: 1.2,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
