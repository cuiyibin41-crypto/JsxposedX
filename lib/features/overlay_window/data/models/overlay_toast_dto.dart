import 'package:JsxposedX/features/overlay_window/domain/models/overlay_toast.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'overlay_toast_dto.freezed.dart';
part 'overlay_toast_dto.g.dart';

@freezed
abstract class OverlayToastDto with _$OverlayToastDto {
  const OverlayToastDto._();

  const factory OverlayToastDto({
    @Default('') String message,
    @Default(2200) int durationMs,
    @Default(0) int id,
  }) = _OverlayToastDto;

  factory OverlayToastDto.fromJson(Map<String, dynamic> json) =>
      _$OverlayToastDtoFromJson(json);

  OverlayToast toEntity() {
    return OverlayToast(
      message: message,
      durationMs: durationMs,
      id: id,
    );
  }
}
