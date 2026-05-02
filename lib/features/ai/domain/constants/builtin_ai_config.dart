import 'package:JsxposedX/core/enums/ai_api_type.dart';
import 'package:JsxposedX/core/models/ai_config.dart';

const String builtinAiConfigId = 'builtin_closeai_default';
const String builtinAiConfigName = '沐雪接口';
const String builtinAiConfigBaseUrl = 'https://muxueai.pro';
const String builtinLegacyBuiltinAiConfigId = 'builtin_closeai_kimi_k25';
const String builtinKimiAiConfigId = builtinLegacyBuiltinAiConfigId;

class BuiltinAiConfigSpec {
  const BuiltinAiConfigSpec({
    required this.id,
    required this.name,
    required this.apiUrl,
    required this.moduleName,
    required this.maxToken,
    required this.temperature,
    required this.memoryRounds,
    required this.apiType,
    required this.apiKeyStorageKey,
    required this.statusLabel,
    required this.badgeLabels,
    this.purchaseUrl,
    this.supportsPadiOptions = false,
  });

  final String id;
  final String name;
  final String apiUrl;
  final String moduleName;
  final int maxToken;
  final double temperature;
  final double memoryRounds;
  final AiApiType apiType;
  final String apiKeyStorageKey;
  final String statusLabel;
  final List<String> badgeLabels;
  final String? purchaseUrl;
  final bool supportsPadiOptions;

  AiConfig toConfig({String apiKey = ''}) {
    return AiConfig(
      id: id,
      name: name,
      apiKey: apiKey,
      apiUrl: apiUrl,
      moduleName: moduleName,
      maxToken: maxToken,
      temperature: temperature,
      memoryRounds: memoryRounds,
      apiType: apiType,
    );
  }
}

const List<BuiltinAiConfigSpec> builtinAiConfigSpecs = [
  BuiltinAiConfigSpec(
    id: builtinAiConfigId,
    name: builtinAiConfigName,
    apiUrl: builtinAiConfigBaseUrl,
    moduleName: 'gpt-5.4',
    maxToken: 4096,
    temperature: 1.0,
    memoryRounds: 6,
    apiType: AiApiType.openai,
    apiKeyStorageKey: 'ai_builtin_api_key',
    statusLabel: 'GPT-MAX',
    badgeLabels: ['Evil','Claude','ChatGPT','国产'],
    purchaseUrl: 'https://shop.zmfaka.cn/shop/SQGJ7S7P',
    supportsPadiOptions: true,
  ),
  BuiltinAiConfigSpec(
    id: builtinKimiAiConfigId,
    name: '帕帝无道德接口',
    apiUrl: 'https://kimi.closeai.hk/v1',
    moduleName: 'Pro/moonshotai/Kimi-K2.5',
    maxToken: 4096,
    temperature: 1.0,
    memoryRounds: 6,
    apiType: AiApiType.openai,
    apiKeyStorageKey: 'ai_builtin_api_key_builtin_closeai_kimi_k25',
    statusLabel: 'Evil',
    badgeLabels: ['Evil'],
    purchaseUrl: 'https://shop.zmfaka.cn/shop/5W176EN1',
  ),
  // 👇 新增智谱
  BuiltinAiConfigSpec(
    id: 'builtin_zhipu_glm',
    name: '智谱清言',
    apiUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    moduleName: 'glm-4-flash',
    maxToken: 4096,
    temperature: 1.0,
    memoryRounds: 6,
    apiType: AiApiType.openai,
    apiKeyStorageKey: 'ai_builtin_api_key_zhipu',
    statusLabel: 'GLM',
    badgeLabels: ['智谱', '国产'],
  ),
];

BuiltinAiConfigSpec get defaultBuiltinAiConfigSpec =>
    builtinAiConfigSpecs.first;

BuiltinAiConfigSpec? getBuiltinAiConfigSpecById(String id) {
  for (final spec in builtinAiConfigSpecs) {
    if (spec.id == id) {
      return spec;
    }
  }
  return null;
}

AiConfig buildBuiltinAiConfig({
  String id = builtinAiConfigId,
  String apiKey = '',
}) {
  final spec = getBuiltinAiConfigSpecById(id) ?? defaultBuiltinAiConfigSpec;
  return spec.toConfig(apiKey: apiKey);
}

List<AiConfig> buildBuiltinAiConfigs() {
  return builtinAiConfigSpecs
      .map((spec) => spec.toConfig())
      .toList(growable: false);
}

String builtinApiKeyStorageKeyForId(String id) {
  return (getBuiltinAiConfigSpecById(id) ?? defaultBuiltinAiConfigSpec)
      .apiKeyStorageKey;
}

bool isBuiltinAiConfigId(String id) => getBuiltinAiConfigSpecById(id) != null;

bool isBuiltinAiConfig(AiConfig config) => isBuiltinAiConfigId(config.id);

bool shouldUseBuiltinPadiOptions(AiConfig config) {
  return getBuiltinAiConfigSpecById(config.id)?.supportsPadiOptions ?? false;
}
