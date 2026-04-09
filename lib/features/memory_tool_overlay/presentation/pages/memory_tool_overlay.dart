import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_window.dart';
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
        leading: const Icon(
          Icons.memory_rounded,
          color: Colors.white,
          size: 20,
        ),
        showMinimizeAction: true,
        showCloseAction: false,
      ),
      margin: EdgeInsets.all(8.r),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Text(
            context.l10n.overlayQuickWorkspace,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            context.l10n.overlayQuickWorkspaceDescription,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          SizedBox(height: 18.h),
          Wrap(spacing: 12.w, runSpacing: 12.h, children: <Widget>[]),
          SizedBox(height: 20.h),
          FilledButton.icon(
            onPressed: () {
              ToastOverlayMessage.show(context.l10n.overlayConnected);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(context.l10n.test),
          ),
        ],
      ),
    );
  }
}
