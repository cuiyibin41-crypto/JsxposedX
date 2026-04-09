import 'package:freezed_annotation/freezed_annotation.dart';

part 'overlay_toast.freezed.dart';

@freezed
abstract class OverlayToast with _$OverlayToast {
  const OverlayToast._();

  const factory OverlayToast({
    required String message,
    required int durationMs,
    required int id,
  }) = _OverlayToast;
}
