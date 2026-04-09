import 'dart:ui';

import 'package:JsxposedX/features/overlay_window/data/datasources/overlay_window_platform_gateway.dart';
import 'package:JsxposedX/features/overlay_window/data/models/overlay_host_layout_dto.dart';
import 'package:JsxposedX/features/overlay_window/data/models/overlay_window_payload_dto.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_payload.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayWindowActionDatasource {
  const OverlayWindowActionDatasource({
    required OverlayWindowPlatformGateway gateway,
  }) : _gateway = gateway;

  final OverlayWindowPlatformGateway _gateway;

  Future<bool> requestPermission() async {
    return await _gateway.requestPermission() ?? false;
  }

  Future<void> showOverlayHost({
    required OverlayHostLayoutDto layout,
    required String notificationTitle,
    required String notificationContent,
  }) {
    return _gateway.showOverlay(
      width: layout.width,
      height: layout.height,
      position: OverlayPosition(layout.x, layout.y),
      enableDrag: layout.enableDrag,
      flag: _flagFromDisplayMode(layout.displayMode),
      overlayTitle: notificationTitle,
      overlayContent: notificationContent,
    );
  }

  Future<bool> updateOverlayHost(OverlayHostLayoutDto layout) async {
    final updated = await _gateway.updateOverlayLayout(
      width: layout.width,
      height: layout.height,
      position: OverlayPosition(layout.x, layout.y),
      enableDrag: layout.enableDrag,
      flag: _flagFromDisplayMode(layout.displayMode),
    );
    return updated ?? false;
  }

  Future<bool> moveOverlay(Offset position) async {
    final moved = await _gateway.moveOverlay(
      OverlayPosition(position.dx, position.dy),
    );
    return moved ?? false;
  }

  Future<void> sharePayload(OverlayWindowPayloadDto payload) {
    return _gateway.shareData(payload.toRaw());
  }

  Future<bool> closeOverlay() async {
    return await _gateway.closeOverlay() ?? false;
  }

  OverlayFlag _flagFromDisplayMode(OverlayWindowDisplayMode displayMode) {
    return displayMode == OverlayWindowDisplayMode.panel
        ? OverlayFlag.focusPointer
        : OverlayFlag.defaultFlag;
  }
}
