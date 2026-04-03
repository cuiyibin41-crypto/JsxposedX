import 'package:JsxposedX/common/widgets/cache_image.dart';
import 'package:JsxposedX/core/constants/assets_constants.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SettingsCommunityCard extends StatelessWidget {
  const SettingsCommunityCard({
    super.key,
    required this.forumHost,
    required this.onVisitForum,
    required this.onJoinDiscord,
    required this.onJoinQQGroup,
    required this.onOpenTargetRange,
  });

  final String forumHost;
  final VoidCallback onVisitForum;
  final VoidCallback onJoinDiscord;
  final VoidCallback onJoinQQGroup;
  final VoidCallback onOpenTargetRange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final shadowColor = Colors.black.withValues(
      alpha: context.isDark ? 0.2 : 0.08,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withValues(
                alpha: context.isDark ? 0.62 : 0.98,
              ),
              colorScheme.secondaryContainer.withValues(
                alpha: context.isDark ? 0.5 : 0.94,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.r),
          child: Stack(
            children: [
              Positioned(
                top: -18.h,
                right: -14.w,
                child: _DecorativeOrb(
                  size: 118.w,
                  color: Colors.white.withValues(
                    alpha: context.isDark ? 0.06 : 0.22,
                  ),
                ),
              ),
              Positioned(
                bottom: -26.h,
                left: -22.w,
                child: _DecorativeOrb(
                  size: 92.w,
                  color: colorScheme.primary.withValues(
                    alpha: context.isDark ? 0.1 : 0.08,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(18.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildTag(
                          context,
                          label: context.l10n.community,
                          icon: Icons.auto_awesome_rounded,
                        ),
                        const Spacer(),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54.w,
                          height: 54.w,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18.r),
                            border: Border.all(
                              color: colorScheme.primary.withValues(
                                alpha: 0.16,
                              ),
                            ),
                          ),
                          child: CacheImage(imageUrl: AssetsConstants.muxue),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.isChinese ? "沐雪社区" : "MuxuePro",
                                style: context.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                context.l10n.officialCommunity,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  height: 1.55,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28.w,
                            height: 28.w,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Icon(
                              Icons.language_rounded,
                              size: 16.sp,
                              color: colorScheme.primary,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              forumHost,
                              style: context.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 18.h),
                    _buildActionButtons(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final spacing = 10.w;
    final forumButton = _buildPrimaryAction(
      context,
      icon: Icons.open_in_new_rounded,
      label: context.l10n.visitForum,
      onPressed: onVisitForum,
    );
    final discordButton = _buildSecondaryAction(
      context,
      icon: Icons.chat_bubble_outline_rounded,
      label: context.l10n.joinDiscord,
      onPressed: onJoinDiscord,
    );
    final qqGroupButton = _buildSecondaryAction(
      context,
      icon: Icons.groups_rounded,
      label: context.l10n.joinQQGroup,
      onPressed: onJoinQQGroup,
    );
    final targetRangeButton = _buildSecondaryAction(
      context,
      icon: Icons.bug_report_rounded,
      label: context.l10n.targetRange,
      onPressed: onOpenTargetRange,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320.w) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: forumButton),
              SizedBox(height: 10.h),
              SizedBox(width: double.infinity, child: discordButton),
              SizedBox(height: 10.h),
              SizedBox(width: double.infinity, child: qqGroupButton),
              SizedBox(height: 10.h),
              SizedBox(width: double.infinity, child: targetRangeButton),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: forumButton),
                SizedBox(width: spacing),
                Expanded(child: discordButton),
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(child: qqGroupButton),
                SizedBox(width: spacing),
                Expanded(child: targetRangeButton),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTag(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final colorScheme = context.colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: colorScheme.primary),
          SizedBox(width: 6.w),
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostChip(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: context.isDark ? 0.08 : 0.55),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.travel_explore_rounded,
            size: 14.sp,
            color: colorScheme.primary,
          ),
          SizedBox(width: 6.w),
          Text(
            forumHost,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18.sp),
      label: Text(label),
      style: FilledButton.styleFrom(
        elevation: context.isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
      ),
    );
  }

  Widget _buildSecondaryAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final colorScheme = context.colorScheme;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18.sp),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.38),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.26)),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
      ),
    );
  }
}

class _DecorativeOrb extends StatelessWidget {
  const _DecorativeOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
