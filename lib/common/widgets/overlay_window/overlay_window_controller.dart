import 'dart:io';

import 'package:JsxposedX/common/widgets/overlay_window/overlay_scene.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayWindowController extends ChangeNotifier {
  OverlayWindowController._();

  static final OverlayWindowController instance = OverlayWindowController._();
  static const double defaultBubbleSize = 58;

  OverlayWindowStatus _status = const OverlayWindowStatus(
    isSupported: true,
    hasPermission: false,
    isActive: false,
  );

  OverlayWindowStatus get status => _status;

  Future<OverlayWindowStatus> refresh() async {
    if (!_isSupportedPlatform) {
      _status = const OverlayWindowStatus(
        isSupported: false,
        hasPermission: false,
        isActive: false,
      );
      notifyListeners();
      return _status;
    }

    final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    final isActive = await FlutterOverlayWindow.isActive();
    _status = OverlayWindowStatus(
      isSupported: true,
      hasPermission: hasPermission,
      isActive: isActive,
    );
    notifyListeners();
    return _status;
  }

  Future<bool> ensurePermission() async {
    if (!_isSupportedPlatform) {
      return false;
    }

    final current = await refresh();
    if (current.hasPermission) {
      return true;
    }

    final granted = await FlutterOverlayWindow.requestPermission() ?? false;
    await refresh();
    return granted;
  }

  Future<OverlayWindowStatus> show(
    BuildContext context, {
    required int scene,
    OverlayWindowPresentation presentation = const OverlayWindowPresentation(),
  }) async {
    if (!_isSupportedPlatform) {
      return refresh();
    }

    final notificationTitle =
        presentation.notificationTitle ?? context.l10n.appName;
    final notificationContent =
        presentation.notificationContent ?? context.l10n.loading;
    final granted = await ensurePermission();
    if (!granted) {
      return status;
    }

    final currentStatus = await refresh();
    if (!currentStatus.isActive) {
      await _showOverlayHost(
        notificationTitle: notificationTitle,
        notificationContent: notificationContent,
      );
    }
    await _sharePayload(
      OverlayWindowPayload(
        scene: scene,
        displayMode: OverlayWindowDisplayMode.bubble,
      ),
    );
    return refresh();
  }

  Future<void> expand(
    BuildContext context, {
    required int scene,
    OverlayWindowPresentation presentation = const OverlayWindowPresentation(),
  }) async {
    if (!_isSupportedPlatform) {
      return;
    }

    final currentStatus = await refresh();
    if (!currentStatus.isActive) {
      return;
    }

    await _sharePayload(
      OverlayWindowPayload(
        scene: scene,
        displayMode: OverlayWindowDisplayMode.panel,
      ),
    );
    await refresh();
  }

  Future<void> collapse(
    BuildContext context, {
    required int scene,
    OverlayWindowPresentation presentation = const OverlayWindowPresentation(),
  }) async {
    if (!_isSupportedPlatform) {
      return;
    }

    final currentStatus = await refresh();
    if (!currentStatus.isActive) {
      return;
    }

    await _sharePayload(
      OverlayWindowPayload(
        scene: scene,
        displayMode: OverlayWindowDisplayMode.bubble,
      ),
    );
    await refresh();
  }

  Future<OverlayWindowStatus> hide() async {
    if (_isSupportedPlatform) {
      await FlutterOverlayWindow.closeOverlay();
    }
    return refresh();
  }

  bool get _isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  Future<void> _sharePayload(OverlayWindowPayload payload) {
    return FlutterOverlayWindow.shareData(payload.toMap());
  }

  Future<void> _showOverlayHost({
    required String notificationTitle,
    required String notificationContent,
  }) {
    return FlutterOverlayWindow.showOverlay(
      width: WindowSize.matchParent,
      height: WindowSize.fullCover,
      alignment: OverlayAlignment.topLeft,
      positionGravity: PositionGravity.none,
      enableDrag: false,
      flag: OverlayFlag.focusPointer,
      visibility: NotificationVisibility.visibilityPublic,
      overlayTitle: notificationTitle,
      overlayContent: notificationContent,
      startPosition: const OverlayPosition(0, 0),
    );
  }
}

class OverlayWindowPresentation {
  const OverlayWindowPresentation({
    this.width,
    this.height,
    this.bubbleSize = OverlayWindowController.defaultBubbleSize,
    this.enableDrag = true,
    this.notificationTitle,
    this.notificationContent,
  });

  final double? width;
  final double? height;
  final double bubbleSize;
  final bool enableDrag;
  final String? notificationTitle;
  final String? notificationContent;
}

class OverlayWindowStatus {
  const OverlayWindowStatus({
    required this.isSupported,
    required this.hasPermission,
    required this.isActive,
  });

  final bool isSupported;
  final bool hasPermission;
  final bool isActive;

  bool get canShow => isSupported && hasPermission;
}
