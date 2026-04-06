import 'package:JsxposedX/common/widgets/cache_image.dart';
import 'package:JsxposedX/core/constants/assets_constants.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomeCenterDockButton extends StatelessWidget {
  const HomeCenterDockButton({
    super.key,
    required this.colorScheme,
    required this.size,
    required this.onPressed,
  });

  final ColorScheme colorScheme;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const aiGradient = LinearGradient(
      colors: [Color(0xFF70D7F9), Color(0xFFAD98FF), Color(0xFFFFB385)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: aiGradient,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF70D7F9).withValues(
              alpha: context.isDark ? 0.34 : 0.30,
            ),
            blurRadius: 15,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFFAD98FF).withValues(
              alpha: context.isDark ? 0.32 : 0.30,
            ),
            blurRadius: 20,
            offset: const Offset(5, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.14 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        elevation: 0,
        highlightElevation: 0,
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onPrimary,
        shape: const CircleBorder(),
        child: Padding(
          padding: EdgeInsets.all(2.w),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.isDark ? const Color(0xFF1E1E1E) : Colors.white,
            ),
            child: Padding(
              padding: EdgeInsets.all(1.w),
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
    );
  }
}

class LowerCenterDockedFabLocation extends FloatingActionButtonLocation {
  const LowerCenterDockedFabLocation({required this.offsetY});

  final double offsetY;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final baseOffset = FloatingActionButtonLocation.centerDocked.getOffset(
      scaffoldGeometry,
    );
    return Offset(baseOffset.dx, baseOffset.dy + offsetY);
  }
}
