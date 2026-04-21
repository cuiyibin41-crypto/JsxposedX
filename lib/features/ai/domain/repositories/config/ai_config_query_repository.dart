import 'package:JsxposedX/core/models/ai_config.dart';
import 'package:JsxposedX/features/ai/domain/models/ai_model.dart';

/// AI 配置查询仓储接口
abstract class AiConfigQueryRepository {
  /// 获取当前配置
  Future<AiConfig> getConfig();
  Future<List<AiModel>> getModels({
    required AiConfig config,
    bool forceRefresh = false,
  });
}
