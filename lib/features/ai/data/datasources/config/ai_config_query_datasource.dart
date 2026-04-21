import 'dart:convert';

import 'package:JsxposedX/core/networks/http_service.dart';
import 'package:JsxposedX/core/providers/pinia_provider.dart';
import 'package:JsxposedX/features/ai/data/models/ai_config_dto.dart';
import 'package:JsxposedX/features/ai/data/models/ai_model_dto.dart';
import 'package:JsxposedX/features/ai/domain/constants/builtin_ai_config.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// AI 配置查询数据源
class AiConfigQueryDatasource {
  static const _currentConfigStorageKey = "ai_config";
  static const _modelsCacheKeyPrefix = "ai_models_cache_";
  static const _builtinConfigOverrideKeyPrefix = "ai_builtin_config_";

  final PiniaStorage _storage;
  final HttpService? _httpService;

  AiConfigQueryDatasource({
    required PiniaStorage storage,
    HttpService? httpService,
  }) : _storage = storage,
       _httpService = httpService;

  Future<List<AiModelDto>> getModels({
    required AiConfigDto config,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _modelsCacheKeyOf(config);
    if (!forceRefresh) {
      final cachedModels = await _readCachedModels(cacheKey);
      if (cachedModels.isNotEmpty) {
        return cachedModels;
      }
    }

    final response = await _httpService!.get(
      _resolveModelsUrl(config),
      options: _buildModelsRequestOptions(config),
    );
    final responseData = response.data;
    final rawModels = switch (responseData) {
      Map<String, dynamic>() => responseData['data'],
      _ => responseData,
    };
    if (rawModels is! List) {
      throw const FormatException('Invalid models response payload');
    }

    final models = <AiModelDto>[
      for (final model in rawModels)
        if (model is Map<String, dynamic>) AiModelDto.fromJson(model),
    ];
    await _storage.setString(
      cacheKey,
      jsonEncode(models.map((model) => model.toJson()).toList(growable: false)),
    );
    return models;
  }

  Future<AiConfigDto> getBuiltinConfig([String id = builtinAiConfigId]) async {
    final spec = getBuiltinAiConfigSpecById(id) ?? defaultBuiltinAiConfigSpec;
    final builtinApiKey = await _storage.getString(spec.apiKeyStorageKey);
    final overrideConfig = await _readBuiltinConfigOverride(spec.id);
    return (overrideConfig ?? _builtinConfigDto(spec)).copyWith(
      apiKey: builtinApiKey,
    );
  }

  Future<List<AiConfigDto>> getBuiltinConfigs() async {
    final result = <AiConfigDto>[];
    for (final spec in builtinAiConfigSpecs) {
      result.add(await getBuiltinConfig(spec.id));
    }
    return result;
  }

  /// 获取 AI 配置
  Future<AiConfigDto> getConfig() async {
    final configStr = await _storage.getString(_currentConfigStorageKey);
    if (configStr.isNotEmpty) {
      try {
        final config = AiConfigDto.fromJson(jsonDecode(configStr));
        if (isBuiltinAiConfigId(config.id)) {
          final builtinConfig = await getBuiltinConfig(config.id);
          return config.copyWith(
            name: config.name.isNotEmpty ? config.name : builtinConfig.name,
            apiUrl: config.apiUrl.isNotEmpty
                ? config.apiUrl
                : builtinConfig.apiUrl,
            apiKey: builtinConfig.apiKey.isNotEmpty
                ? builtinConfig.apiKey
                : config.apiKey,
            moduleName: config.moduleName.isNotEmpty
                ? config.moduleName
                : builtinConfig.moduleName,
            maxToken: config.maxToken > 0
                ? config.maxToken
                : builtinConfig.maxToken,
            temperature: config.temperature,
            memoryRounds: config.memoryRounds,
            apiType: config.apiType.isNotEmpty
                ? config.apiType
                : builtinConfig.apiType,
          );
        }
        // 如果配置没有 id，生成一个默认的
        if (config.id.isEmpty) {
          final hasCustomContent =
              config.apiUrl.isNotEmpty ||
              config.apiKey.isNotEmpty ||
              config.moduleName.isNotEmpty ||
              config.name.isNotEmpty;
          if (hasCustomContent) {
            return config.copyWith(
              id: const Uuid().v4(),
              name: config.name.isEmpty ? '迁移配置' : config.name,
            );
          }
          return getBuiltinConfig();
        }
        return config;
      } catch (e) {
        return getBuiltinConfig();
      }
    }
    return getBuiltinConfig();
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

  Future<List<AiModelDto>> _readCachedModels(String cacheKey) async {
    final cached = await _storage.getString(cacheKey);
    if (cached.isEmpty) {
      return const <AiModelDto>[];
    }

    try {
      final jsonList = jsonDecode(cached);
      if (jsonList is! List) {
        return const <AiModelDto>[];
      }
      return <AiModelDto>[
        for (final item in jsonList)
          if (item is Map<String, dynamic>) AiModelDto.fromJson(item),
      ];
    } catch (_) {
      return const <AiModelDto>[];
    }
  }

  Options _buildModelsRequestOptions(AiConfigDto config) {
    return Options(
      headers: <String, dynamic>{
        if (config.apiKey.isNotEmpty)
          'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      },
    );
  }

  String _resolveModelsUrl(AiConfigDto config) {
    final rawBaseUrl = config.apiUrl.trim();
    final normalizedBaseUrl = rawBaseUrl.endsWith('/')
        ? rawBaseUrl.substring(0, rawBaseUrl.length - 1)
        : rawBaseUrl;

    if (normalizedBaseUrl.endsWith('/v1/models')) {
      return normalizedBaseUrl;
    }
    if (normalizedBaseUrl.endsWith('/chat/completions')) {
      return normalizedBaseUrl.replaceFirst(
        RegExp(r'/chat/completions$'),
        '/models',
      );
    }
    if (normalizedBaseUrl.endsWith('/responses')) {
      return normalizedBaseUrl.replaceFirst(RegExp(r'/responses$'), '/models');
    }
    if (normalizedBaseUrl.endsWith('/messages')) {
      return normalizedBaseUrl.replaceFirst(RegExp(r'/messages$'), '/models');
    }
    if (normalizedBaseUrl.endsWith('/v1')) {
      return '$normalizedBaseUrl/models';
    }
    return '$normalizedBaseUrl/v1/models';
  }

  String _modelsCacheKeyOf(AiConfigDto config) {
    final source = <String>[
      config.id,
      config.apiUrl,
      config.apiType,
      config.apiKey,
    ].join('|');
    final digest = sha256.convert(utf8.encode(source)).toString();
    return '$_modelsCacheKeyPrefix$digest';
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
