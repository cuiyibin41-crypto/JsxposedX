import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_event.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_toast.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_payload.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'overlay_window_runtime_message.freezed.dart';

@freezed
abstract class OverlayWindowRuntimeMessage with _$OverlayWindowRuntimeMessage {
  const OverlayWindowRuntimeMessage._();

  const factory OverlayWindowRuntimeMessage.payload(
    OverlayWindowPayload payload,
  ) = OverlayWindowPayloadMessage;

  const factory OverlayWindowRuntimeMessage.event(OverlayWindowEvent event) =
      OverlayWindowEventMessage;

  const factory OverlayWindowRuntimeMessage.toast(OverlayToast toast) =
      OverlayWindowToastMessage;
}
