import 'package:JsxposedX/common/widgets/app_bootstrap.dart';
import 'package:JsxposedX/core/themes/app_theme.dart';
import 'package:JsxposedX/features/overlay_window/presentation/pages/overlay_window_host_page.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class OverlaySubApp extends ConsumerWidget {
  const OverlaySubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = ref.watch(
      overlayWindowHostRuntimeProvider.select((state) => state.payload),
    );
    final locale = Locale(
      payload.localeLanguageCode,
      payload.localeCountryCode.isEmpty ? null : payload.localeCountryCode,
    );
    final lightTheme = _buildOverlayTheme(
      AppTheme.lightTheme(Color(payload.primaryColorValue)),
    );
    final darkTheme = _buildOverlayTheme(
      AppTheme.darkTheme(Color(payload.primaryColorValue)),
    );

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'JsxposedX Overlay',
          locale: locale,
          localizationsDelegates: AppBootstrap.localizationsDelegates,
          supportedLocales: AppBootstrap.supportedLocales,
          localeResolutionCallback: (deviceLocale, supportedLocales) => locale,
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: payload.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
          home: const OverlayWindowHostPage(),
        );
      },
    );
  }

  ThemeData _buildOverlayTheme(ThemeData theme) {
    return theme.copyWith(
      canvasColor: Colors.transparent,
      cardColor: Colors.transparent,
      dialogTheme: const DialogThemeData(backgroundColor: Colors.transparent),
    );
  }
}
