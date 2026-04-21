import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/ai/domain/models/ai_model.dart';
import 'package:JsxposedX/features/ai/domain/models/padi_chat_options.dart';
import 'package:JsxposedX/features/ai/presentation/providers/config/ai_config_query_provider.dart';
import 'package:JsxposedX/features/ai/presentation/providers/runtime/ai_chat_runtime_provider.dart';
import 'package:JsxposedX/features/ai/presentation/widgets/ai_chat_compact_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PadiChatOptionsBar extends HookConsumerWidget {
  const PadiChatOptionsBar({
    super.key,
    required this.packageName,
    this.isCompact = false,
  });

  final String packageName;
  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopeCompact = AiChatCompactScope.of(context);
    final scopeScale = AiChatCompactScope.scaleOf(context);
    final effectiveCompact = isCompact || scopeCompact;
    final expanded = useState(false);
    final isRefreshing = useState(false);
    final chatState = ref.watch(
      aiChatRuntimeProvider(packageName: packageName),
    );
    final notifier = ref.read(
      aiChatRuntimeProvider(packageName: packageName).notifier,
    );
    final modelsAsync = ref.watch(aiModelsProvider);
    final refreshModels = ref.read(aiModelsRefreshActionProvider);
    final displayModels = _resolveDisplayModels(
      loadedModels: modelsAsync.asData?.value,
      currentModel: chatState.currentPadiModel,
      currentSupportsReasoning: chatState.currentPadiSupportsReasoning,
    );
    final selectedModel = _findModelById(
      displayModels,
      chatState.currentPadiModel,
    );
    final supportsReasoning = _supportsReasoningForModel(
      selectedModel,
      chatState.currentPadiSupportsReasoning,
    );
    final supportedEfforts = PadiChatOptions.supportedEffortsForModel(
      chatState.currentPadiModel,
    );

    useEffect(() {
      final loadedModels = modelsAsync.asData?.value;
      if (loadedModels == null || loadedModels.isEmpty) {
        return null;
      }
      if (loadedModels.any((model) => model.id == chatState.currentPadiModel)) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.updatePadiChatOptions(
          model: loadedModels.first.id,
          supportsReasoning: _supportsReasoningForModel(
            loadedModels.first,
            false,
          ),
        );
      });
      return null;
    }, [modelsAsync.asData?.value, chatState.currentPadiModel]);

    return Container(
      margin: EdgeInsets.only(
        top: 4 * scopeScale,
        bottom: (effectiveCompact ? 4 : 6) * scopeScale,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: (effectiveCompact ? 8 : 10) * scopeScale,
          vertical: (effectiveCompact ? 6 : 8) * scopeScale,
        ),
        decoration: BoxDecoration(
          color: context.isDark
              ? context.colorScheme.surfaceContainerLow
              : Colors.white,
          borderRadius: BorderRadius.circular(
            (effectiveCompact ? 10 : 12) * scopeScale,
          ),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => expanded.value = !expanded.value,
              borderRadius: BorderRadius.circular(
                (effectiveCompact ? 8 : 10) * scopeScale,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: (effectiveCompact ? 2 : 4) * scopeScale,
                  vertical: (effectiveCompact ? 1 : 2) * scopeScale,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        supportsReasoning
                            ? '${context.l10n.aiBuiltinConfigName} · ${chatState.currentPadiModel} · ${_localizedEffort(context, chatState.currentPadiReasoningEffort)}'
                            : '${context.l10n.aiBuiltinConfigName} · ${chatState.currentPadiModel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: (effectiveCompact ? 10.5 : 12) * scopeScale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: (effectiveCompact ? 4 : 8) * scopeScale),
                    if (modelsAsync.isLoading || isRefreshing.value)
                      SizedBox(
                        width: (effectiveCompact ? 14 : 16) * scopeScale,
                        height: (effectiveCompact ? 14 : 16) * scopeScale,
                        child: CircularProgressIndicator(
                          strokeWidth: 2 * scopeScale,
                        ),
                      )
                    else
                      InkWell(
                        onTap: () async {
                          if (isRefreshing.value) {
                            return;
                          }
                          isRefreshing.value = true;
                          try {
                            await refreshModels();
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          } finally {
                            if (context.mounted) {
                              isRefreshing.value = false;
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(999 * scopeScale),
                        child: Padding(
                          padding: EdgeInsets.all(4 * scopeScale),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: (effectiveCompact ? 14 : 16) * scopeScale,
                            color: context.theme.hintColor,
                          ),
                        ),
                      ),
                    SizedBox(width: (effectiveCompact ? 4 : 8) * scopeScale),
                    if (!effectiveCompact)
                      Text(
                        expanded.value
                            ? context.l10n.aiPadiOptionsCollapse
                            : context.l10n.aiPadiOptionsExpand,
                        style: TextStyle(
                          fontSize: 11 * scopeScale,
                          color: context.theme.hintColor,
                        ),
                      ),
                    if (!effectiveCompact) SizedBox(width: 4 * scopeScale),
                    Icon(
                      expanded.value
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: (effectiveCompact ? 16 : 18) * scopeScale,
                      color: context.theme.hintColor,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded.value) ...[
              SizedBox(height: (effectiveCompact ? 6 : 8) * scopeScale),
              _OptionsRow(
                title: context.l10n.aiPadiModelLabel,
                isCompact: effectiveCompact,
                children: displayModels
                    .map(
                      (model) => _OptionChip(
                        label: model.id,
                        selected: chatState.currentPadiModel == model.id,
                        isCompact: effectiveCompact,
                        onTap: () => notifier.updatePadiChatOptions(
                          model: model.id,
                          supportsReasoning: _supportsReasoningForModel(
                            model,
                            false,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              if (supportsReasoning) ...[
                SizedBox(height: (effectiveCompact ? 4 : 6) * scopeScale),
                _OptionsRow(
                  title: context.l10n.aiPadiReasoningLabel,
                  isCompact: effectiveCompact,
                  children: supportedEfforts
                      .map(
                        (effort) => _OptionChip(
                          label: _localizedEffort(context, effort),
                          selected:
                              chatState.currentPadiReasoningEffort == effort,
                          isCompact: effectiveCompact,
                          onTap: () => notifier.updatePadiChatOptions(
                            reasoningEffort: effort,
                            supportsReasoning: true,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _localizedEffort(BuildContext context, String effort) {
    switch (effort) {
      case PadiChatOptions.effortNone:
        return context.l10n.aiPadiEffortNone;
      case PadiChatOptions.effortLow:
        return context.l10n.aiPadiEffortLow;
      case PadiChatOptions.effortMedium:
        return context.l10n.aiPadiEffortMedium;
      case PadiChatOptions.effortHigh:
        return context.l10n.aiPadiEffortHigh;
      case PadiChatOptions.effortXHigh:
        return context.l10n.aiPadiEffortXHigh;
      default:
        return effort;
    }
  }
}

List<AiModel> _resolveDisplayModels({
  required List<AiModel>? loadedModels,
  required String currentModel,
  required bool currentSupportsReasoning,
}) {
  final models = <AiModel>[
    ...(loadedModels == null || loadedModels.isEmpty
        ? PadiChatOptions.models.map(
            (model) => AiModel(
              id: model,
              object: 'model',
              created: 0,
              ownedBy: 'codex',
              supportedEndpointTypes: const <String>[],
            ),
          )
        : loadedModels),
  ];
  if (models.any((model) => model.id == currentModel)) {
    return models;
  }
  return <AiModel>[
    AiModel(
      id: currentModel,
      object: 'model',
      created: 0,
      ownedBy: currentSupportsReasoning ? 'codex' : '',
      supportedEndpointTypes: const <String>[],
    ),
    ...models,
  ];
}

AiModel? _findModelById(List<AiModel> models, String modelId) {
  for (final model in models) {
    if (model.id == modelId) {
      return model;
    }
  }
  return null;
}

bool _supportsReasoningForModel(AiModel? model, bool fallback) {
  if (model == null) {
    return fallback;
  }
  return model.ownedBy.trim().toLowerCase() == 'codex';
}

class _OptionsRow extends StatelessWidget {
  const _OptionsRow({
    required this.title,
    required this.isCompact,
    required this.children,
  });

  final String title;
  final bool isCompact;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scopeScale = AiChatCompactScope.scaleOf(context);
    return SizedBox(
      height: ((isCompact ? 30 : 34) * scopeScale),
      child: Row(
        children: [
          SizedBox(
            width: (isCompact ? 48 : 60) * scopeScale,
            child: Text(
              title,
              style: TextStyle(
                fontSize: (isCompact ? 10 : 11.5) * scopeScale,
                fontWeight: FontWeight.w600,
                color: context.theme.hintColor,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.isCompact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isCompact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scopeScale = AiChatCompactScope.scaleOf(context);
    final primary = context.colorScheme.primary;
    return Padding(
      padding: EdgeInsets.only(right: (isCompact ? 6 : 8) * scopeScale),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999 * scopeScale),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: (isCompact ? 10 : 12) * scopeScale,
            vertical: (isCompact ? 5 : 6) * scopeScale,
          ),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.14)
                : (context.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white),
            borderRadius: BorderRadius.circular(999 * scopeScale),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.55)
                  : context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: (isCompact ? 10.5 : 11.5) * scopeScale,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? primary
                  : context.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.82,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
