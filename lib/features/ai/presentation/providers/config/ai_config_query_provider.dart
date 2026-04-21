import 'package:JsxposedX/core/models/ai_config.dart';
import 'package:JsxposedX/core/networks/http_service.dart';
import 'package:JsxposedX/core/providers/pinia_provider.dart';
import 'package:JsxposedX/features/ai/data/datasources/config/ai_config_action_datasource.dart';
import 'package:JsxposedX/features/ai/data/datasources/config/ai_config_query_datasource.dart';
import 'package:JsxposedX/features/ai/data/repositories/config/ai_config_query_repository_impl.dart'
    as impl;
import 'package:JsxposedX/features/ai/domain/constants/builtin_ai_config.dart';
import 'package:JsxposedX/features/ai/domain/models/ai_model.dart';
import 'package:JsxposedX/features/ai/domain/repositories/config/ai_config_query_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_config_query_provider.g.dart';

@riverpod
AiConfigQueryRepository aiConfigQueryRepository(Ref ref) {
  final storage = ref.watch(piniaStorageLocalProvider);
  final httpService = ref.watch(httpServiceProvider);
  final dataSource = AiConfigQueryDatasource(
    storage: storage,
    httpService: httpService,
  );
  return impl.AiConfigQueryRepositoryImpl(dataSource: dataSource);
}

/// 获取 AI 配置
@riverpod
Future<List<AiModel>> aiModels(Ref ref) async {
  final config = await ref.watch(aiConfigProvider.future);
  return await ref
      .watch(aiConfigQueryRepositoryProvider)
      .getModels(config: config);
}

final aiModelsRefreshActionProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final config = await ref.read(aiConfigProvider.future);
    await ref
        .read(aiConfigQueryRepositoryProvider)
        .getModels(config: config, forceRefresh: true);
    ref.invalidate(aiModelsProvider);
  };
});

/// 获取 AI 配置
@riverpod
Future<AiConfig> aiConfig(Ref ref) async {
  return await ref.watch(aiConfigQueryRepositoryProvider).getConfig();
}

/// 获取 AI 配置列表
@riverpod
Future<List<AiConfig>> aiConfigList(Ref ref) async {
  final storage = ref.watch(piniaStorageLocalProvider);
  final actionDataSource = AiConfigActionDatasource(storage: storage);
  final queryDataSource = AiConfigQueryDatasource(storage: storage);
  final dtos = await actionDataSource.getConfigList();
  final builtinConfigs = await queryDataSource.getBuiltinConfigs();
  return [
    ...builtinConfigs.map((dto) => dto.toEntity()),
    ...dtos.map((dto) => dto.toEntity()),
  ];
}

class ActiveAiConfigMeta {
  const ActiveAiConfigMeta({
    required this.config,
    required this.isBuiltin,
    required this.displayLabel,
  });

  final AiConfig config;
  final bool isBuiltin;
  final String displayLabel;
}

final activeAiConfigMetaProvider = Provider<AsyncValue<ActiveAiConfigMeta>>((
  ref,
) {
  final configAsync = ref.watch(aiConfigProvider);
  return configAsync.whenData((config) {
    return ActiveAiConfigMeta(
      config: config,
      isBuiltin: isBuiltinAiConfig(config),
      displayLabel: config.name,
    );
  });
});
