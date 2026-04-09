import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/common/widgets/cache_image.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_window.dart';
import 'package:JsxposedX/core/constants/assets_constants.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolOverlay extends HookConsumerWidget {
  const MemoryToolOverlay({super.key});

  OverlayWindowConfig get overlayConfig => OverlayWindowConfig(
    sceneId: 0,
    bubbleSize: OverlayWindowPresentation.defaultBubbleSize,
    notificationTitle: (context) => context.l10n.overlayMemoryToolTitle,
    notificationContent: (context) =>
        context.l10n.overlayWindowNotificationContent,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OverlayWindowScaffold(
      overlayConfig: overlayConfig,
      overlayBar: OverlayWindowBar(
        title: Text(
          context.l10n.overlayMemoryToolTitle,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: CacheImage(imageUrl: AssetsConstants.logo,size: 40.sp,)
        ),
        showMinimizeAction: true,
        showCloseAction: false,
      ),
      margin: EdgeInsets.all(8.r),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              children: const <Widget>[ListTile(title: Text('data'))],
            ),
          ),
        ],
      ),
      bottomBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),

    );
  }
}
