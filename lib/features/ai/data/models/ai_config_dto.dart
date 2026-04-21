import 'package:JsxposedX/core/enums/ai_api_type.dart';
import 'package:JsxposedX/core/models/ai_config.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_config_dto.freezed.dart';
part 'ai_config_dto.g.dart';

@freezed
abstract class AiConfigDto with _$AiConfigDto {
  const AiConfigDto._();

  const factory AiConfigDto({
    @Default("") String id,
    @Default("") String name,
    @Default("") String apiKey,
    @Default("") String apiUrl,
    @Default("") String moduleName,
    @Default(300) int maxToken,
    @Default(0.8) double temperature,
    @Default(10) double memoryRounds,
    @Default('openai') String apiType,
  }) = _AiConfigDto;

  factory AiConfigDto.fromJson(Map<String, dynamic> json) =>
      _$AiConfigDtoFromJson(json);

  factory AiConfigDto.fromEntity(AiConfig config) {
    return AiConfigDto(
      id: config.id,
      name: config.name,
      apiKey: config.apiKey,
      apiUrl: config.apiUrl,
      moduleName: config.moduleName,
      maxToken: config.maxToken,
      temperature: config.temperature,
      memoryRounds: config.memoryRounds,
      apiType: config.apiType.name,
    );
  }

  AiConfig toEntity() {
    return AiConfig(
      id: id,
      name: name,
      apiKey: apiKey,
      apiUrl: apiUrl,
      moduleName: moduleName,
      maxToken: maxToken,
      temperature: temperature,
      memoryRounds: memoryRounds,
      apiType: AiApiType.fromString(apiType),
    );
  }
}
