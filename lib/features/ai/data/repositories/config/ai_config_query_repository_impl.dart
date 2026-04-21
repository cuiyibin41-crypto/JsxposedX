import 'package:JsxposedX/core/models/ai_config.dart';
import 'package:JsxposedX/features/ai/data/datasources/config/ai_config_query_datasource.dart';
import 'package:JsxposedX/features/ai/data/models/ai_config_dto.dart';
import 'package:JsxposedX/features/ai/domain/models/ai_model.dart';
import 'package:JsxposedX/features/ai/domain/repositories/config/ai_config_query_repository.dart';

/// AI 配置查询仓储实现
class AiConfigQueryRepositoryImpl implements AiConfigQueryRepository {
  final AiConfigQueryDatasource dataSource;

  AiConfigQueryRepositoryImpl({required this.dataSource});

  @override
  Future<AiConfig> getConfig() async {
    final dto = await dataSource.getConfig();
    return dto.toEntity();
  }

  @override
  Future<List<AiModel>> getModels({
    required AiConfig config,
    bool forceRefresh = false,
  }) async {
    final dtos = await dataSource.getModels(
      config: AiConfigDto.fromEntity(config),
      forceRefresh: forceRefresh,
    );
    return dtos.map((e) => e.toEntity()).toList();
  }
}
