import 'dart:async';

import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/common/widgets/ref_error.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/core/providers/status_management_provider.dart';
import 'package:JsxposedX/core/routes/routes/home_route.dart';
import 'package:JsxposedX/core/utils/url_helper.dart';
import 'package:JsxposedX/feature/ai/presentation/providers/chat/ai_chat_action_provider.dart';
import 'package:JsxposedX/feature/frida/presentation/providers/frida_query_provider.dart';
import 'package:JsxposedX/feature/home/presentation/widgets/activation_card.dart';
import 'package:JsxposedX/feature/home/presentation/widgets/info_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 首页 Tab
class HomeTab extends HookConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRootAsync = ref.watch(isRootProvider);
    final isHookAsync = ref.watch(isHookProvider);
    final isFridaAsync = ref.watch(isFridaProvider);
    final aiStatusAsync = ref.watch(aiStatusProvider);
    final isZygiskModuleInstalledAsync = ref.watch(
      isZygiskModuleInstalledProvider,
    );
    final isRoot_ = useState(false);
    final isHook_ = useState(false);
    final isInitingFrida = useState(false);

    // LSPosed service is sometimes bound a bit later than app startup.
    // Keep refreshing hook status for a short window until it turns true.
    useEffect(() {
      Timer? timer;
      timer = Timer.periodic(const Duration(seconds: 2), (_) {
        final current = ref.read(isHookProvider);
        if (current.value == true) {
          timer?.cancel();
          return;
        }
        if (!current.isLoading) {
          ref.invalidate(isHookProvider);
        }
      });
      return () => timer?.cancel();
    }, const []);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(0, 8.h, 0, 24.h),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _titleArea(context, hasAi: aiStatusAsync.value ?? false),
              SizedBox(height: 8.h),
              aiStatusAsync.when(
                data: (isOnline) =>
                    ActivationCard.ai(isActivated: isOnline, title: 'AI'),
                error: (e, s) =>
                    ActivationCard.ai(isActivated: false, title: 'AI'),
                loading: () => const Loading(),
              ),
              SizedBox(height: 8.h),
              isRootAsync.when(
                data: (isRoot) {
                  isRoot_.value = isRoot;
                  return ActivationCard(isActivated: isRoot, title: 'Root');
                },
                error: (error, stack) =>
                    RefError(onRetry: () => ref.invalidate(isRootProvider)),
                loading: () => const Loading(),
              ),
              SizedBox(height: 8.h),
              isHookAsync.when(
                data: (isHooK) {
                  isHook_.value = isHooK;
                  return ActivationCard(isActivated: isHooK, title: 'Xposed');
                },
                error: (error, stack) =>
                    RefError(onRetry: () => ref.invalidate(isHookProvider)),
                loading: () => const Loading(),
              ),
              SizedBox(height: 8.h),
              isFridaAsync.when(
                data: (isFrida) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ActivationCard(
                        isActivated: isFrida.status,
                        title: 'Frida',
                        subTitle: switch (isFrida.type) {
                          0 => context.l10n.fridaInitAbnormal,
                          1 => null,
                          -1 => context.l10n.fridaNotInstalledShort,
                          _ => context.l10n.fridaUnknown,
                        },
                      ),

                      isZygiskModuleInstalledAsync.when(
                        data: (isZygiskModuleInstalled) {
                          if (isZygiskModuleInstalled) {
                            return SizedBox();
                          } else {
                            return Padding(
                              padding: EdgeInsets.only(right: 10.w, top: 6.h),
                              child: TextButton(
                                onPressed: () => UrlHelper.openUrlInBrowser(
                                  url:
                                      "https://www.yuque.com/ababa-haoqq/hake3e/ts43ti2b0a0n52cw?singleDoc",
                                ),
                                child: Text(
                                  context.isChinese
                                      ? "下载Magisk模块"
                                      : "Download module for Magisk",
                                ),
                              ),
                            );
                          }
                        },
                        error: (error, stack) => RefError(
                          onRetry: () =>
                              ref.invalidate(isZygiskModuleInstalledProvider),
                        ),
                        loading: () => const Loading(),
                      ),
                    ],
                  );
                },
                error: (error, stack) =>
                    RefError(onRetry: () => ref.invalidate(isFridaProvider)),
                loading: () => const Loading(),
              ),
              SizedBox(height: 12.h),
              InfoCard(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _titleArea(BuildContext context, {bool hasAi = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: hasAi
                  ? [
                      Color(0xFF70D7F9),
                      Color(0xFFAD98FF),
                      Color(0xFFFFB385),
                    ]
                  : [
                      context.colorScheme.primary,
                      context.colorScheme.secondary,
                    ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: Text(
              context.l10n.appName.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 31.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
