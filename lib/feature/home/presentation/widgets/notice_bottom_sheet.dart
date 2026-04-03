import 'package:JsxposedX/common/widgets/custom_dIalog.dart';
import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/common/widgets/ref_error.dart';
import 'package:JsxposedX/core/constants/assets_constants.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/core/utils/url_helper.dart';
import 'package:JsxposedX/feature/home/presentation/providers/check_query_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class NoticeBottomSheet extends HookConsumerWidget {
  const NoticeBottomSheet({super.key});

  static const String _projectUrl = 'https://github.com/dugongzi/jsxposed_x';
  static const String _websiteUrl = 'https://jsxposed.org';
  static const String _afdianUrl = 'https://afdian.com/a/wanfengyyds/plan';
  static const String _paypalUrl =
      'https://www.paypal.com/qrcodes/p2pqrc/6Q6REWSAVE4VC';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticeAsync = ref.watch(noticeInfoProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: context.screenHeight * 0.55),
      child: noticeAsync.when(
        data: (notice) {
          final content = notice.msg.content.trim();

          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNoticeCard(context, content),
                SizedBox(height: 16.h),
                _buildSponsorSection(context),
              ],
            ),
          );
        },
        error: (error, stack) => RefError(
          error: error,
          onRetry: () => ref.invalidate(noticeInfoProvider),
        ),
        loading: () => const Loading(),
      ),
    );
  }

  Widget _buildNoticeCard(BuildContext context, String content) {
    final colorScheme = context.colorScheme;
    final title = context.isZh ? '最新公告' : 'Latest Notice';
    final emptyText = context.isZh
        ? '当前暂无新的公告内容。'
        : 'No notice available right now.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.campaign_rounded,
                  color: colorScheme.primary,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            content.isEmpty ? emptyText : content,
            style: context.textTheme.bodyMedium?.copyWith(height: 1.65),
          ),
        ],
      ),
    );
  }

  Widget _buildSponsorSection(BuildContext context) {
    final colorScheme = context.colorScheme;
    final title = context.isZh ? '赞助作者' : 'Support the Author';
    final subtitle = context.isZh
        ? '如果这个项目帮到了你，欢迎支持作者持续维护与更新。'
        : 'If this project helps you, consider supporting the author to keep it maintained.';
    final footnote = context.isZh
        ? '暂时不方便赞助也没关系，去 GitHub 点个 Star 也很有帮助。'
        : 'If sponsoring is not convenient, starring the repo also helps a lot.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: colorScheme.primary,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
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
          SizedBox(height: 14.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14.r,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.person_rounded,
                    size: 16.sp,
                    color: colorScheme.primary,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    '@dugongzi',
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  context.isZh ? '持续维护中' : 'Active maintenance',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                ),
              ),
              child: AspectRatio(
                aspectRatio: 1885 / 624,
                child: Image.asset(
                  AssetsConstants.wx,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: [
              FilledButton.icon(
                onPressed: () => _showSponsorDialog(context),
                icon: Icon(Icons.favorite_border_rounded, size: 18.sp),
                label: Text(context.isZh ? '赞助作者' : 'Sponsor'),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => UrlHelper.openUrlInBrowser(url: _projectUrl),
                icon: Icon(Icons.star_rounded, size: 18.sp),
                label: Text(context.isZh ? '项目仓库' : 'Repository'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.35),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => UrlHelper.openUrlInBrowser(url: _websiteUrl),
                icon: Icon(Icons.public_rounded, size: 18.sp),
                label: Text(context.isZh ? '项目主页' : 'Website'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: 6.w,
                    vertical: 12.h,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            footnote,
            style: context.textTheme.bodySmall?.copyWith(
              height: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSponsorDialog(BuildContext context) {
    final colorScheme = context.colorScheme;
    final title = context.isZh ? '选择赞助方式' : 'Choose a Sponsor Method';
    final subtitle = context.isZh
        ? '感谢你的支持，这将帮助作者持续维护项目。'
        : 'Thanks for the support — it helps keep the project actively maintained.';

    return CustomDialog.show<void>(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volunteer_activism_rounded, color: colorScheme.primary),
          SizedBox(width: 8.w),
          Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      hasClose: true,
      width: 0.84.sw,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: context.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await SmartDialog.dismiss();
                await UrlHelper.openUrlInBrowser(url: _afdianUrl);
              },
              icon: Icon(Icons.favorite_rounded, size: 18.sp),
              label: Text(context.isZh ? '爱发电' : 'Afdian'),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await SmartDialog.dismiss();
                await UrlHelper.openUrlInBrowser(url: _paypalUrl);
              },
              icon: Icon(Icons.payments_rounded, size: 18.sp),
              label: const Text('PayPal'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.35),
                ),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ),
        ],
      )
    );
  }
}

