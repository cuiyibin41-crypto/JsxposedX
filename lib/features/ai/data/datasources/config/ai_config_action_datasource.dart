import 'dart:convert';

import 'package:JsxposedX/core/providers/pinia_provider.dart';
import 'package:JsxposedX/features/ai/data/models/ai_config_dto.dart';
import 'package:JsxposedX/features/ai/domain/constants/builtin_ai_config.dart';

/// AI 配置操作数据源
class AiConfigActionDatasource {
  static const _currentConfigStorageKey = "ai_config";
  static const _configListStorageKey = "ai_config_list";
  static const _builtinConfigOverrideKeyPrefix = "ai_builtin_config_";

  final PiniaStorage _storage;

  AiConfigActionDatasource({required PiniaStorage storage})
    : _storage = storage;

  /// 保存当前 AI 配置
  Future<void> saveConfig(AiConfigDto config) async {
    if (isBuiltinAiConfigId(config.id)) {
      await _storage.setString(
        builtinApiKeyStorageKeyForId(config.id),
        config.apiKey,
      );
      await _storage.setString(
        _builtinConfigOverrideKey(config.id),
        jsonEncode(config.toJson()),
      );
    }
    await _storage.setString(
      _currentConfigStorageKey,
      jsonEncode(config.toJson()),
    );
  }

  /// 获取配置列表
  Future<List<AiConfigDto>> getConfigList() async {
    final configListStr = await _storage.getString(_configListStorageKey);
    if (configListStr.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> jsonList = jsonDecode(configListStr);
      return jsonList
          .map((json) => AiConfigDto.fromJson(json))
          .where((config) => !isBuiltinAiConfigId(config.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 保存配置列表
  Future<void> saveConfigList(List<AiConfigDto> configs) async {
    await _storage.setString(
      _configListStorageKey,
      jsonEncode(configs.map((c) => c.toJson()).toList()),
    );
  }

  /// 添加新配置到列表
  Future<void> addConfig(AiConfigDto config) async {
    final list = await getConfigList();
    list.add(config);
    await saveConfigList(list);
  }

  /// 更新配置列表中的某个配置
  Future<void> updateConfig(AiConfigDto config) async {
    if (isBuiltinAiConfigId(config.id)) {
      await saveConfig(config);
      return;
    }
    final list = await getConfigList();
    final index = list.indexWhere((c) => c.id == config.id);
    if (index != -1) {
      list[index] = config;
      await saveConfigList(list);
    }
  }

  /// 删除配置
  Future<void> deleteConfig(String id) async {
    if (isBuiltinAiConfigId(id)) {
      return;
    }
    final list = await getConfigList();
    list.removeWhere((c) => c.id == id);
    await saveConfigList(list);
  }

  /// 切换配置（将指定配置设为当前配置）
  Future<void> switchConfig(String id) async {
    final builtinSpec = getBuiltinAiConfigSpecById(id);
    if (builtinSpec != null) {
      final builtinConfig = await _readBuiltinConfigOverride(id);
      final builtinApiKey = await _storage.getString(
        builtinSpec.apiKeyStorageKey,
      );
      await saveConfig(
        (builtinConfig ?? _builtinConfigDto(builtinSpec)).copyWith(
          apiKey: builtinApiKey,
        ),
      );
      return;
    }
    final list = await getConfigList();
    final config = list.firstWhere((c) => c.id == id);
    await saveConfig(config);
  }

  AiConfigDto _builtinConfigDto(
    BuiltinAiConfigSpec spec, {
    String apiKey = '',
  }) {
    return AiConfigDto(
      id: spec.id,
      name: spec.name,
      apiKey: apiKey,
      apiUrl: spec.apiUrl,
      moduleName: spec.moduleName,
      maxToken: spec.maxToken,
      temperature: spec.temperature,
      memoryRounds: spec.memoryRounds,
      apiType: spec.apiType.name,
    );
  }

  Future<AiConfigDto?> _readBuiltinConfigOverride(String id) async {
    final raw = await _storage.getString(_builtinConfigOverrideKey(id));
    if (raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final dto = AiConfigDto.fromJson(decoded);
      if (dto.id != id) {
        return null;
      }
      return dto;
    } catch (_) {
      return null;
    }
  }

  String _builtinConfigOverrideKey(String id) =>
      '$_builtinConfigOverrideKeyPrefix$id';
}
