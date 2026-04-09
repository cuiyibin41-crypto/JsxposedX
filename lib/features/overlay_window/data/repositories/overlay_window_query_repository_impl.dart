import 'dart:io';
import 'dart:ui';

import 'package:JsxposedX/features/overlay_window/data/datasources/overlay_window_query_datasource.dart';
import 'package:JsxposedX/features/overlay_window/data/models/overlay_toast_dto.dart';
import 'package:JsxposedX/features/overlay_window/data/models/overlay_window_event_dto.dart';
import 'package:JsxposedX/features/overlay_window/data/models/overlay_window_payload_dto.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_viewport_metrics.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_runtime_message.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_status.dart';
import 'package:JsxposedX/features/overlay_window/domain/repositories/overlay_window_query_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class OverlayWindowQueryRepositoryImpl implements OverlayWindowQueryRepository {
  const OverlayWindowQueryRepositoryImpl({
    required OverlayWindowQueryDatasource dataSource,
  }) : _dataSource = dataSource;

  final OverlayWindowQueryDatasource _dataSource;

  @override
  bool get isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  @override
  Stream<OverlayWindowRuntimeMessage> get overlayEvents async* {
    await for (final rawMessage in _dataSource.overlayEvents) {
      final runtimeMessage = _mapRuntimeMessage(rawMessage);
      if (runtimeMessage != null) {
        yield runtimeMessage;
      }
    }
  }

  @override
  Future<bool> isActive() async {
    if (!isSupportedPlatform) {
      return false;
    }
    return _dataSource.isActive();
  }

  @override
  Future<bool> isPermissionGranted() async {
    if (!isSupportedPlatform) {
      return false;
    }
    return _dataSource.isPermissionGranted();
  }

  @override
  Future<Offset> getOverlayPosition() async {
    if (!isSupportedPlatform) {
      return Offset.zero;
    }
    final position = await _dataSource.getOverlayPosition();
    return Offset(position.x, position.y);
  }

  @override
  Future<OverlayViewportMetrics> getOverlayViewportMetrics() async {
    if (!isSupportedPlatform) {
      return const OverlayViewportMetrics(
        width: 0,
        height: 0,
        safePadding: EdgeInsets.zero,
      );
    }
    return (await _dataSource.getOverlayViewportMetrics()).toEntity();
  }

  @override
  Future<OverlayWindowStatus> getStatus() async {
    if (!isSupportedPlatform) {
      return const OverlayWindowStatus(
        isSupported: false,
        hasPermission: false,
        isActive: false,
      );
    }

    final hasPermission = await isPermissionGranted();
    final active = await isActive();
    return OverlayWindowStatus(
      isSupported: true,
      hasPermission: hasPermission,
      isActive: active,
    );
  }

  OverlayWindowRuntimeMessage? _mapRuntimeMessage(dynamic rawMessage) {
    final eventDto = OverlayWindowEventDto.maybeFromRaw(rawMessage);
    if (eventDto != null) {
      return OverlayWindowRuntimeMessage.event(eventDto.toEntity());
    }

    final toastDto = _parseOverlayToastDto(rawMessage);
    if (toastDto != null) {
      return OverlayWindowRuntimeMessage.toast(toastDto.toEntity());
    }

    final payloadDto = OverlayWindowPayloadDto.maybeFromRaw(rawMessage);
    if (payloadDto != null) {
      return OverlayWindowRuntimeMessage.payload(payloadDto.toEntity());
    }

    return null;
  }

  OverlayToastDto? _parseOverlayToastDto(dynamic rawMessage) {
    if (rawMessage is! Map) {
      return null;
    }

    final normalized = rawMessage.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    final message = normalized['message']?.toString().trim() ?? '';
    if (message.isEmpty) {
      return null;
    }

    return OverlayToastDto.fromJson(<String, dynamic>{
      'message': message,
      'durationMs': (_parseInt(normalized['durationMs']) ?? 2200).clamp(
        500,
        10000,
      ),
      'id':
          _parseInt(normalized['id']) ?? DateTime.now().microsecondsSinceEpoch,
    });
  }

  int? _parseInt(Object? raw) {
    return switch (raw) {
      int value => value,
      String value => int.tryParse(value),
      _ => null,
    };
  }
}
