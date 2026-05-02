class PadiChatOptions {
  const PadiChatOptions({
    required this.model,
    required this.reasoningEffort,
    required this.supportsReasoning,
  });

  final String model;
  final String reasoningEffort;
  final bool supportsReasoning;

  static const String defaultModel = 'gpt-5.4';
  static const String defaultReasoningEffort = 'medium';
  static const String effortNone = 'none';
  static const String effortLow = 'low';
  static const String effortMedium = 'medium';
  static const String effortHigh = 'high';
  static const String effortXHigh = 'xhigh';
  static const List<String> models = [
  'gpt-5.5',
  'gpt-5.4',
  'gpt-5.3-codex',
  // 智谱主流模型，加在这里
  'glm-4-flash',
  'glm-4',
  'glm-3-turbo',
  'chatglm3-6b',
];

  static const List<String> models = [
    'gpt-5.5',
    'gpt-5.4',
    'gpt-5.3-codex',
  ];

  static const Map<String, List<String>> supportedEffortsByModel = {
    'gpt-5.5': [effortLow, effortMedium, effortHigh, effortXHigh],
    'gpt-5.4': [effortNone, effortLow, effortMedium, effortHigh, effortXHigh],
    'gpt-5.3-codex': [effortLow, effortMedium, effortHigh, effortXHigh],
  };

  factory PadiChatOptions.defaults() {
    return const PadiChatOptions(
      model: defaultModel,
      reasoningEffort: defaultReasoningEffort,
      supportsReasoning: true,
    );
  }

  factory PadiChatOptions.fromJson(Map<String, dynamic> json) {
    final rawModel = json['model']?.toString() ?? defaultModel;
    final model = rawModel.trim().isEmpty ? defaultModel : rawModel;
    final rawEffort =
        json['reasoningEffort']?.toString() ?? defaultReasoningEffort;
    final supportsReasoning = json['supportsReasoning'] as bool? ?? true;
    return PadiChatOptions(
      model: model,
      reasoningEffort: normalizeEffort(model, rawEffort),
      supportsReasoning: supportsReasoning,
    );
  }

  Map<String, dynamic> toJson() => {
    'model': model,
    'reasoningEffort': reasoningEffort,
    'supportsReasoning': supportsReasoning,
  };

  PadiChatOptions copyWith({
    String? model,
    String? reasoningEffort,
    bool? supportsReasoning,
  }) {
    final nextModel = model ?? this.model;
    return PadiChatOptions(
      model: nextModel,
      reasoningEffort: normalizeEffort(
        nextModel,
        reasoningEffort ?? this.reasoningEffort,
      ),
      supportsReasoning: supportsReasoning ?? this.supportsReasoning,
    );
  }

  static List<String> supportedEffortsForModel(String model) {
    return supportedEffortsByModel[_normalizeModelId(model)] ??
        supportedEffortsByModel[defaultModel]!;
  }

  static bool supportsReasoningModel(String model) {
    return supportedEffortsByModel.containsKey(_normalizeModelId(model));
  }

  static String normalizeEffort(String model, String effort) {
    final supported = supportedEffortsForModel(model);
    if (supported.contains(effort)) {
      return effort;
    }
    if (supported.contains(defaultReasoningEffort)) {
      return defaultReasoningEffort;
    }
    return supported.first;
  }

  static String _normalizeModelId(String model) {
    return model.trim().toLowerCase();
  }
}
