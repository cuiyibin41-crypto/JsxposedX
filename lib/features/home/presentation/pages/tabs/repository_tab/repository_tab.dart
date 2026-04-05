import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/common/widgets/cache_image.dart';
import 'package:JsxposedX/common/widgets/custom_dIalog.dart';
import 'package:JsxposedX/common/widgets/custom_tab_bar.dart';
import 'package:JsxposedX/common/widgets/custom_text_field.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/core/utils/url_helper.dart';
import 'package:JsxposedX/features/home/domain/models/user_detail.dart';
import 'package:JsxposedX/features/home/presentation/pages/tabs/repository_tab/tabs/new_script_tab.dart';
import 'package:JsxposedX/features/home/presentation/pages/tabs/repository_tab/tabs/star_script_tab.dart';
import 'package:JsxposedX/features/home/presentation/providers/repository_token_login_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const String _repositoryTutorialUrl =
    'https://www.yuque.com/ababa-haoqq/hake3e/mfz6382mb4gt4gyu?singleDoc';

/// 仓库 Tab
class RepositoryTab extends HookConsumerWidget {
  const RepositoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabController = useTabController(initialLength: 2);
    final loginState = ref.watch(repositoryTokenLoginProvider);

    return Scaffold(
      appBar: AppBar(
        title: CustomTabBar(
          tabController: tabController,
          tabs: [
            Tab(text: context.l10n.news),
            Tab(text: context.l10n.star),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: loginState.when(
              data: (user) => _RepositoryAvatarAction(
                user: user,
                isLoading: false,
                onTap: () => _handleAvatarTap(context, ref, user: user),
              ),
              loading: () =>
                  const _RepositoryAvatarAction(user: null, isLoading: true),
              error: (_, _) => _RepositoryAvatarAction(
                user: null,
                isLoading: false,
                onTap: () => _showTokenDialog(context, ref),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
        child: TabBarView(
          controller: tabController,
          children: const [NewScriptTab(), StarScriptTab()],
        ),
      ),
    );
  }

  void _handleAvatarTap(
    BuildContext context,
    WidgetRef ref, {
    required UserDetail? user,
  }) {
    if (user == null) {
      _showTokenDialog(context, ref);
      return;
    }
    _showUserInfoDialog(context, ref, user: user);
  }

  void _showTokenDialog(
    BuildContext context,
    WidgetRef ref, {
    bool isReplace = false,
  }) {
    SmartDialog.show(
      builder: (_) => _RepositoryTokenLoginDialog(isReplace: isReplace),
    );
  }

  Future<void> _showUserInfoDialog(
    BuildContext context,
    WidgetRef ref, {
    required UserDetail user,
  }) {
    return CustomDialog.show<void>(
      title: Text(context.l10n.repositoryAccountInfo),
      hasClose: true,
      width: 0.86.sw,
      child: _RepositoryUserInfoContent(user: user),
      actionButtons: [
        TextButton(
          onPressed: () => SmartDialog.dismiss(),
          child: Text(context.l10n.close),
        ),
        TextButton(
          onPressed: () async {
            await SmartDialog.dismiss();
            if (context.mounted) {
              _showTokenDialog(context, ref, isReplace: true);
            }
          },
          child: Text(context.l10n.repositoryReplaceToken),
        ),
      ],
    );
  }
}

class _RepositoryAvatarAction extends StatelessWidget {
  const _RepositoryAvatarAction({
    required this.user,
    required this.isLoading,
    this.onTap,
  });

  final UserDetail? user;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.r),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Stack(
          alignment: Alignment.center,
          children: [
            _RepositoryAvatar(imageUrl: user?.avatarUrl, size: 35.sp),
            if (isLoading)
              SizedBox(
                width: 35.sp,
                height: 35.sp,
                child: CircularProgressIndicator(strokeWidth: 2.w),
              ),
          ],
        ),
      ),
    );
  }
}

class _RepositoryTokenLoginDialog extends HookConsumerWidget {
  const _RepositoryTokenLoginDialog({required this.isReplace});

  final bool isReplace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenController = useTextEditingController();
    final isSubmitting = useState(false);

    return CustomDialog(
      title: Text(
        isReplace
            ? context.l10n.repositoryReplaceToken
            : context.l10n.repositoryTokenLogin,
      ),
      hasClose: !isSubmitting.value,
      width: 0.86.sw,
      actionButtons: [
        TextButton(
          onPressed: isSubmitting.value
              ? null
              : () => UrlHelper.openUrlInBrowser(url: _repositoryTutorialUrl),
          child: Text(context.l10n.aiTutorial),
        ),
        TextButton(
          onPressed: isSubmitting.value ? null : () => SmartDialog.dismiss(),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: isSubmitting.value
              ? null
              : () async {
                  final token = tokenController.text.trim();
                  if (token.isEmpty) {
                    ToastMessage.show(context.l10n.repositoryTokenEmpty);
                    return;
                  }

                  isSubmitting.value = true;
                  try {
                    final notifier = ref.read(
                      repositoryTokenLoginProvider.notifier,
                    );
                    if (isReplace) {
                      await notifier.replaceToken(token);
                    } else {
                      await notifier.loginWithToken(token);
                    }

                    if (!context.mounted) {
                      return;
                    }

                    ToastMessage.show(context.l10n.repositoryTokenLoginSuccess);
                    await SmartDialog.dismiss();
                  } catch (_) {
                    if (!context.mounted) {
                      return;
                    }
                    ToastMessage.show(context.l10n.repositoryTokenInvalid);
                  } finally {
                    if (context.mounted) {
                      isSubmitting.value = false;
                    }
                  }
                },
          child: isSubmitting.value
              ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: CircularProgressIndicator(strokeWidth: 2.w),
                )
              : Text(context.l10n.repositoryVerifyAndLogin),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            controller: tokenController,
            labelText: 'Token',
            hintText: context.l10n.repositoryTokenHint,
          ),
        ],
      ),
    );
  }
}

class _RepositoryUserInfoContent extends StatelessWidget {
  const _RepositoryUserInfoContent({required this.user});

  final UserDetail user;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RepositoryAvatar(imageUrl: user.avatarUrl, size: 64.sp),
        SizedBox(height: 14.h),
        Text(
          user.nickname.isEmpty
              ? context.l10n.repositoryUnnamedUser
              : user.nickname,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 16.h),
        _RepositoryInfoRow(
          label: context.l10n.repositoryMxid,
          value: user.mxid.isEmpty ? '-' : user.mxid,
        ),
        SizedBox(height: 10.h),
        _RepositoryInfoRow(
          label: context.l10n.repositoryVip,
          value: user.isVip
              ? context.l10n.repositoryVipActive
              : context.l10n.repositoryVipInactive,
        ),
      ],
    );
  }
}

class _RepositoryInfoRow extends StatelessWidget {
  const _RepositoryInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64.w,
          child: Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RepositoryAvatar extends StatelessWidget {
  const _RepositoryAvatar({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = imageUrl?.trim() ?? '';
    if (resolvedUrl.isNotEmpty) {
      return ClipOval(
        child: CacheImage(imageUrl: resolvedUrl, size: size),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colorScheme.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.58,
        color: context.colorScheme.primary,
      ),
    );
  }
}
