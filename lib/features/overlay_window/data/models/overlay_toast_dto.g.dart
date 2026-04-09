// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overlay_toast_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OverlayToastDto _$OverlayToastDtoFromJson(Map<String, dynamic> json) =>
    _OverlayToastDto(
      message: json['message'] as String? ?? '',
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 2200,
      id: (json['id'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$OverlayToastDtoToJson(_OverlayToastDto instance) =>
    <String, dynamic>{
      'message': instance.message,
      'durationMs': instance.durationMs,
      'id': instance.id,
    };
