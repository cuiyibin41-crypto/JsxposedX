import 'dart:io';

import 'package:JsxposedX/common/widgets/cache_image.dart';
import 'package:JsxposedX/core/constants/assets_constants.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/overlay_window/data/datasources/overlay_window_platform_gateway.dart';
import 'package:JsxposedX/features/overlay_window/data/models/overlay_toast_dto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class ToastMessage {
  const ToastMessage._();

  static void show(dynamic msg) {
    SmartDialog.showToast(
      '',
      alignment: Alignment.bottomCenter,
      builder: (context) => Container(
        margin: EdgeInsets.only(bottom: 100.h),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: context.theme.primaryColor,
          borderRadius: BorderRadius.circular(20.r),
        ),
        constraints: BoxConstraints(
          maxHeight: 0.9.sw,
          maxWidth: 0.8.sw, // 限制最大宽度为屏幕宽度的 80%
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 加上图标
            CacheImage(imageUrl: AssetsConstants.logo, size: 24.sp),
            SizedBox(width: 10.w),
            Flexible(
              child: Text(
                msg.toString(),
                maxLines: 15,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ToastOverlayMessage {
  const ToastOverlayMessage._();

  static const OverlayWindowPlatformGateway _gateway =
      FlutterOverlayWindowPlatformGateway();

  static Future<void> show(
    dynamic msg, {
    Duration duration = const Duration(milliseconds: 2200),
  }) async {
    final message = msg.toString().trim();
    if (message.isEmpty) {
      return;
    }

    if (kIsWeb || !Platform.isAndroid) {
      ToastMessage.show(message);
      return;
    }

    try {
      final active = await _gateway.isActive();
      if (!active) {
        ToastMessage.show(message);
        return;
      }

      final dto = OverlayToastDto(
        message: message,
        durationMs: duration.inMilliseconds,
        id: DateTime.now().microsecondsSinceEpoch,
      );
      await _gateway.shareData(dto.toJson());
    } catch (_) {
      ToastMessage.show(message);
    }
  }
}
