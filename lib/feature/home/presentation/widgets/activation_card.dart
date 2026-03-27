import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/core/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ActivationCard extends StatelessWidget {
  final bool isActivated;
  final String title;
  final bool isAI;
  final String? subTitle;

  const ActivationCard({
    super.key,
    required this.isActivated,
    required this.title,
    this.subTitle,
  }) : isAI = false;

  const ActivationCard.ai({
    super.key,
    required this.isActivated,
    required this.title,
    this.subTitle,
  }) : isAI = true;

  @override
  Widget build(BuildContext context) {
    final aiGradient = const LinearGradient(
      colors: [Color(0xFF70D7F9), Color(0xFFAD98FF), Color(0xFFFFB385)],
    );

    if (!isAI) {
      final accentColor = _accentColor(context);
      final statusText = isActivated
          ? context.l10n.activated
          : context.l10n.notActivated;
      final subtitleText = subTitle == null ? statusText : '$statusText ($subTitle)';

      return Container(
        margin: EdgeInsets.symmetric(horizontal: 10.w),
        constraints: BoxConstraints(minHeight: 96.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: accentColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.18 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isActivated ? 0.16 : 0.10),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(
                _statusIcon(),
                size: 23.sp,
                color: isActivated ? accentColor : accentColor.withValues(alpha: 0.72),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: context.isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(
                            alpha: isActivated ? 0.16 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    subtitleText,
                    style: TextStyle(
                      fontSize: 13.sp,
                      height: 1.4,
                      color: context.isDark
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10.w),
      constraints: BoxConstraints(minHeight: 96.h),
      decoration: isAI
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: isActivated
                  ? [
                      BoxShadow(
                        color: const Color(0xFF70D7F9).withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFFAD98FF).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(5, 5),
                      ),
                    ]
                  : null,
              gradient: isActivated ? aiGradient : null,
              color: isActivated ? null : Colors.grey.withValues(alpha: 0.2),
            )
          : null,
      padding: (isAI && isActivated)
          ? EdgeInsets.all(2.w)
          : EdgeInsets.zero,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: isActivated
              ? (context.isDark ? const Color(0xFF1E1E1E) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(isAI ? 14.r : 12.r),
          boxShadow: !isAI
              ? [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isAI && isActivated)
              ShaderMask(
                shaderCallback: (bounds) => aiGradient.createShader(bounds),
                child: Icon(Icons.check, size: 42.sp, color: Colors.white),
              )
            else
              Icon(
                isActivated ? Icons.check : Icons.error_outline,
                size: 42.sp,
                color: isAI
                    ? (isActivated ? const Color(0xFFAD98FF) : Colors.grey)
                    : Colors.white,
              ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isAI && isActivated)
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          aiGradient.createShader(bounds),
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: isAI
                            ? (context.isDark
                                  ? Colors.white
                                  : AppColors.textPrimary)
                            : Colors.white,
                      ),
                    ),
                  if (isAI && isActivated)
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          aiGradient.createShader(bounds),
                      child: Text(
                        context.l10n.activated,
                        style: TextStyle(fontSize: 12.sp, color: Colors.white),
                      ),
                    )
                  else
                    Text(
                      "${isActivated ? context.l10n.activated : context.l10n.notActivated}${subTitle != null ? "($subTitle)" : ""}",
                      style: TextStyle(
                        fontSize: 12.sp,
                        height: 1.4,
                        color: isAI
                            ? (context.isDark
                                  ? Colors.white70
                                  : AppColors.textSecondary)
                            : Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _accentColor(BuildContext context) {
    switch (title) {
      case 'Root':
        return const Color(0xFF38B26D);
      case 'Xposed':
        return const Color(0xFFFFA94D);
      case 'Frida':
        return const Color(0xFF5B8CFF);
      default:
        return context.colorScheme.primary;
    }
  }

  IconData _statusIcon() {
    switch (title) {
      case 'Root':
        return Icons.admin_panel_settings_rounded;
      case 'Xposed':
        return Icons.extension_rounded;
      case 'Frida':
        return Icons.memory_rounded;
      default:
        return isActivated ? Icons.check_circle : Icons.error_outline;
    }
  }
}
