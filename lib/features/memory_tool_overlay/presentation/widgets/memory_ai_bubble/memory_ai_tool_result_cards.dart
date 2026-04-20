import 'dart:async';

import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/core/utils/format_utils.dart';
import 'package:JsxposedX/features/ai/presentation/widgets/ai_chat_compact_scope.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_auto_chase_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_ai_pending_interaction_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_task_progress_resolver.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_ai_bubble/memory_ai_tool_result_parser.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryAiToolResultView extends ConsumerWidget {
  const MemoryAiToolResultView({
    super.key,
    required this.data,
    this.packageName,
  });

  final MemoryAiToolResultData data;
  final String? packageName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (packageName != null &&
        data.isPending &&
        data.toolName != null &&
        ref.watch(memoryAiPendingInteractionProvider(packageName!))?.toolName ==
            data.toolName) {
      return _MemoryAiPendingInteractionCard(
        scopeId: packageName!,
        toolName: data.toolName!,
      );
    }

    final scale = AiChatCompactScope.scaleOf(context);
    final children = <Widget>[_MemoryAiToolBanner(data: data)];
    final liveTaskCard = _buildPendingTaskCard();

    if (liveTaskCard != null) {
      children.add(SizedBox(height: 10 * scale));
      children.add(liveTaskCard);
    }

    for (final section
        in liveTaskCard == null
            ? data.sections
            : _stripLiveTaskSections(data.sections)) {
      if (!section.hasContent) {
        continue;
      }
      children.add(SizedBox(height: 10 * scale));
      children.add(_MemoryAiSection(section: section));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget? _buildPendingTaskCard() {
    if (!data.isPending) {
      return null;
    }
    return switch (data.toolName) {
      'start_first_scan' ||
      'continue_next_scan' => const _MemoryAiLiveSearchTaskCard(),
      'start_pointer_scan' => const _MemoryAiLivePointerScanTaskCard(),
      'start_pointer_auto_chase' => const _MemoryAiLivePointerAutoChaseCard(),
      _ when packageName != null && data.toolName != null =>
        _MemoryAiPendingInteractionCard(
          scopeId: packageName!,
          toolName: data.toolName!,
        ),
      _ => null,
    };
  }

  List<MemoryAiToolSectionData> _stripLiveTaskSections(
    List<MemoryAiToolSectionData> sections,
  ) {
    return sections
        .where((section) {
          final title = section.title?.trim() ?? '';
          if (title.contains('搜索任务') ||
              title.contains('Search Task') ||
              title.contains('指针扫描任务') ||
              title.contains('Pointer Scan Task') ||
              title.contains('自动追链') ||
              title.contains('Auto Chase') ||
              title.contains('等待用户确认') ||
              title.contains('Awaiting user confirmation')) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }
}

class _MemoryAiLiveSearchTaskCard extends HookConsumerWidget {
  const _MemoryAiLiveSearchTaskCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskStateAsync = ref.watch(getSearchTaskStateProvider);
    useEffect(() {
      final timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        ref.invalidate(getSearchTaskStateProvider);
      });
      return timer.cancel;
    }, const []);

    return taskStateAsync.when(
      data: (state) => _MemoryAiSearchTaskCardFromState(state: state),
      loading: () => const _MemoryAiPendingLoadingCard(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MemoryAiLivePointerScanTaskCard extends HookConsumerWidget {
  const _MemoryAiLivePointerScanTaskCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskStateAsync = ref.watch(getPointerScanTaskStateProvider);
    useEffect(() {
      final timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        ref.invalidate(getPointerScanTaskStateProvider);
      });
      return timer.cancel;
    }, const []);

    return taskStateAsync.when(
      data: (state) => _MemoryAiPointerScanTaskCardFromState(state: state),
      loading: () => const _MemoryAiPendingLoadingCard(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MemoryAiLivePointerAutoChaseCard extends HookConsumerWidget {
  const _MemoryAiLivePointerAutoChaseCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoChaseStateAsync = ref.watch(getPointerAutoChaseStateProvider);
    useEffect(() {
      final timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        ref.invalidate(getPointerAutoChaseStateProvider);
      });
      return timer.cancel;
    }, const []);

    return autoChaseStateAsync.when(
      data: (state) => _MemoryAiPointerAutoChaseCardFromState(state: state),
      loading: () => const _MemoryAiPendingLoadingCard(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MemoryAiPendingInteractionCard extends ConsumerWidget {
  const _MemoryAiPendingInteractionCard({
    required this.scopeId,
    required this.toolName,
  });

  final String scopeId;
  final String toolName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interaction = ref.watch(memoryAiPendingInteractionProvider(scopeId));
    if (interaction == null || interaction.toolName != toolName) {
      return const _MemoryAiPendingLoadingCard();
    }

    final scale = AiChatCompactScope.scaleOf(context);
    final controller = ref.read(
      memoryAiPendingInteractionProvider(scopeId).notifier,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(18 * scale),
        border: Border.all(color: const Color(0xFF8BB8F8)),
      ),
      padding: EdgeInsets.all(14 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 18 * scale,
                color: const Color(0xFF2C7BE5),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  interaction.title,
                  style: TextStyle(
                    fontSize: 12.2 * scale,
                    fontWeight: FontWeight.w800,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          Text(
            interaction.description,
            style: TextStyle(
              fontSize: 11.2 * scale,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface.withValues(alpha: 0.76),
            ),
          ),
          SizedBox(height: 12 * scale),
          ...interaction.options.map(
            (option) => Padding(
              padding: EdgeInsets.only(bottom: 8 * scale),
              child: _MemoryAiPendingInteractionOptionButton(
                option: option,
                onPressed: () => controller.resolve(option.id),
              ),
            ),
          ),
          if (interaction.cancelLabel != null &&
              interaction.cancelLabel!.trim().isNotEmpty) ...[
            SizedBox(height: 4 * scale),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: controller.cancel,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2 * scale,
                    vertical: 4 * scale,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(interaction.cancelLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemoryAiPendingInteractionOptionButton extends StatelessWidget {
  const _MemoryAiPendingInteractionOptionButton({
    required this.option,
    required this.onPressed,
  });

  final MemoryAiPendingInteractionOption option;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.symmetric(
            horizontal: 12 * scale,
            vertical: 12 * scale,
          ),
          side: BorderSide(
            color: context.colorScheme.primary.withValues(alpha: 0.22),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14 * scale),
          ),
          backgroundColor: context.colorScheme.surface.withValues(alpha: 0.92),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.label,
              style: TextStyle(
                fontSize: 11.6 * scale,
                fontWeight: FontWeight.w800,
                color: context.colorScheme.onSurface,
              ),
            ),
            if (option.description != null &&
                option.description!.trim().isNotEmpty) ...[
              SizedBox(height: 4 * scale),
              Text(
                option.description!,
                style: TextStyle(
                  fontSize: 10.6 * scale,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemoryAiPendingLoadingCard extends StatelessWidget {
  const _MemoryAiPendingLoadingCard();

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEDF5FF),
        borderRadius: BorderRadius.circular(18 * scale),
        border: Border.all(color: const Color(0xFF8BB8F8)),
      ),
      padding: EdgeInsets.all(14 * scale),
      child: Text(
        context.isZh ? '正在同步实时进度...' : 'Syncing live progress...',
        style: TextStyle(
          fontSize: 11.2 * scale,
          fontWeight: FontWeight.w700,
          color: context.colorScheme.onSurface.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _MemoryAiSection extends StatelessWidget {
  const _MemoryAiSection({required this.section});

  final MemoryAiToolSectionData section;

  @override
  Widget build(BuildContext context) {
    if (_isSearchTaskOverview(section.title, section.overviewFields)) {
      return _MemoryAiSearchTaskOverviewCard(
        title: section.title,
        fields: section.overviewFields,
      );
    }
    final scale = AiChatCompactScope.scaleOf(context);
    final children = <Widget>[];

    if (section.title != null && section.title!.trim().isNotEmpty) {
      children.add(_MemoryAiSectionTitle(title: section.title!));
      children.add(SizedBox(height: 6 * scale));
    }

    if (section.overviewFields.isNotEmpty) {
      children.add(
        _MemoryAiOverviewCard(
          title: section.title,
          fields: section.overviewFields,
        ),
      );
    }

    for (final row in section.rows) {
      if (children.isNotEmpty) {
        children.add(SizedBox(height: 8 * scale));
      }
      children.add(_buildRowCard(context, row));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildRowCard(BuildContext context, MemoryAiToolRowData row) {
    switch (row.type) {
      case MemoryAiToolRowType.searchResult:
        return _MemoryAiSearchResultCard(row: row);
      case MemoryAiToolRowType.valuePreview:
        return _MemoryAiValuePreviewCard(row: row);
      case MemoryAiToolRowType.instructionPreview:
        return _MemoryAiInstructionCard(row: row);
      case MemoryAiToolRowType.breakpoint:
        return _MemoryAiBreakpointCard(row: row);
      case MemoryAiToolRowType.breakpointHit:
        return _MemoryAiBreakpointHitCard(row: row);
      case MemoryAiToolRowType.pointerResult:
        return _MemoryAiPointerResultCard(row: row);
      case MemoryAiToolRowType.pointerChaseHint:
        return _MemoryAiPointerChaseHintCard(row: row);
      case MemoryAiToolRowType.autoChaseLayer:
        return _MemoryAiAutoChaseLayerCard(row: row);
      case MemoryAiToolRowType.raw:
        return _MemoryAiRawLineCard(raw: row.raw);
    }
  }
}

class _MemoryAiToolBanner extends StatelessWidget {
  const _MemoryAiToolBanner({required this.data});

  final MemoryAiToolResultData data;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    final tone = _MemoryAiCardTone(
      accent: data.isPending
          ? const Color(0xFF2C7BE5)
          : data.isSuccess
          ? const Color(0xFF2E9B62)
          : const Color(0xFFC84E4E),
      icon: data.isPending
          ? Icons.hourglass_top_rounded
          : data.isSuccess
          ? Icons.memory_rounded
          : Icons.error_outline_rounded,
    );

    return Container(
      decoration: BoxDecoration(
        color: tone.accent.withValues(alpha: context.isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(color: tone.accent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 28 * scale,
                  height: 28 * scale,
                  decoration: BoxDecoration(
                    color: tone.accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tone.icon, size: 16 * scale, color: tone.accent),
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Text(
                    data.summary,
                    style: TextStyle(
                      fontSize: 12.8 * scale,
                      fontWeight: FontWeight.w800,
                      color: tone.accent,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            if (data.tokens.isNotEmpty) ...<Widget>[
              SizedBox(height: 10 * scale),
              Wrap(
                spacing: 6 * scale,
                runSpacing: 6 * scale,
                children: data.tokens
                    .take(4)
                    .map(
                      (token) =>
                          _MemoryAiChip(text: token, accent: tone.accent),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemoryAiOverviewCard extends StatelessWidget {
  const _MemoryAiOverviewCard({required this.title, required this.fields});

  final String? title;
  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final tone = _resolveOverviewTone(title, fields);
    if (_isTaskOverview(fields)) {
      return _MemoryAiTaskOverviewCard(
        title: title,
        fields: fields,
        tone: tone,
      );
    }
    return _MemoryAiCardFrame(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields.entries
            .map(
              (entry) => _MemoryAiFactRow(label: entry.key, value: entry.value),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _MemoryAiTaskOverviewCard extends StatelessWidget {
  const _MemoryAiTaskOverviewCard({
    required this.title,
    required this.fields,
    required this.tone,
  });

  final String? title;
  final Map<String, String> fields;
  final _MemoryAiCardTone tone;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    final progressItems = _buildProgressItems(context, fields);
    final statusValue = _value(fields, 'status');
    final statusLabel = _statusLabel(context, statusValue);
    final statusColor = _statusColor(statusValue);
    final message = _normalizeTaskMessageDisplay(
      context,
      _value(fields, 'message'),
    );
    final stats = _buildTaskStatItems(context, fields);
    final extraFacts = fields.entries
        .where((entry) => !_taskPrimaryKeys.contains(entry.key))
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) => _MemoryAiFactRow(label: entry.key, value: entry.value))
        .toList(growable: false);

    return _MemoryAiCardFrame(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 28 * scale,
                height: 28 * scale,
                decoration: BoxDecoration(
                  color: tone.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10 * scale),
                ),
                child: Icon(tone.icon, size: 16 * scale, color: tone.accent),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      (title?.trim().isNotEmpty ?? false)
                          ? title!
                          : _fallbackText(
                              context,
                              zh: '任务状态',
                              en: 'Task State',
                            ),
                      style: TextStyle(
                        fontSize: 12.4 * scale,
                        fontWeight: FontWeight.w800,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    if (message.isNotEmpty) ...<Widget>[
                      SizedBox(height: 2 * scale),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 11.2 * scale,
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (statusLabel.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * scale,
                    vertical: 4 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10.2 * scale,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
            ],
          ),
          if (progressItems.isNotEmpty) ...<Widget>[
            SizedBox(height: 12 * scale),
            ...progressItems.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 10 * scale),
                child: _MemoryAiProgressRow(item: item, accent: tone.accent),
              ),
            ),
          ],
          if (stats.isNotEmpty) ...<Widget>[
            SizedBox(height: 2 * scale),
            Wrap(
              spacing: 8 * scale,
              runSpacing: 8 * scale,
              children: stats
                  .map(
                    (item) =>
                        _MemoryAiStatPill(item: item, accent: tone.accent),
                  )
                  .toList(growable: false),
            ),
          ],
          if (extraFacts.isNotEmpty) ...<Widget>[
            SizedBox(height: 2 * scale),
            ...extraFacts.map(
              (fact) => Padding(
                padding: EdgeInsets.only(bottom: 6 * scale),
                child: fact,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemoryAiSearchTaskOverviewCard extends StatelessWidget {
  const _MemoryAiSearchTaskOverviewCard({
    required this.title,
    required this.fields,
  });

  final String? title;
  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    final state = _buildSearchTaskState(fields, title: title);
    final progress = resolveMemoryToolSearchTaskProgress(state);
    final isRunning = state.status == SearchTaskStatus.running;
    final borderColor = const Color(0xFF8BB8F8);
    final backgroundColor = const Color(0xFFEDF5FF);
    final chipBackground = const Color(0xFFDDEBFF);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18 * scale),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.all(14 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 34 * scale,
                  height: 34 * scale,
                  decoration: BoxDecoration(
                    color: chipBackground,
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                  child: Icon(
                    Icons.query_stats_rounded,
                    size: 18 * scale,
                    color: const Color(0xFF2C7BE5),
                  ),
                ),
                SizedBox(width: 10 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        state.isFirstScan
                            ? context.l10n.memoryToolTaskFirstScanTitle
                            : context.l10n.memoryToolTaskNextScanTitle,
                        style: TextStyle(
                          fontSize: 12.8 * scale,
                          fontWeight: FontWeight.w900,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        _searchTaskHint(context, state),
                        style: TextStyle(
                          fontSize: 10.8 * scale,
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.68,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10 * scale,
                    vertical: 5 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    _statusLabel(context, state.status.name),
                    style: TextStyle(
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.w800,
                      color: _statusColor(state.status.name),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14 * scale),
            if (progress != null) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8 * scale,
                  backgroundColor: const Color(0xFFBFD8FB),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF2C7BE5),
                  ),
                ),
              ),
              SizedBox(height: 8 * scale),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w800,
                  color: context.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 12 * scale),
            ],
            Wrap(
              spacing: 8 * scale,
              runSpacing: 8 * scale,
              children: <Widget>[
                _MemoryAiTaskMetricChip(
                  label: context.l10n.memoryToolTaskElapsedLabel,
                  value: _formatElapsedForSearchCard(context, state),
                ),
                if (state.totalRegions > 0)
                  _MemoryAiTaskMetricChip(
                    label: context.l10n.memoryToolTaskRegionsLabel,
                    value: '${state.processedRegions}/${state.totalRegions}',
                  ),
                if (state.totalBytes > 0)
                  _MemoryAiTaskMetricChip(
                    label: context.l10n.memoryToolTaskBytesLabel,
                    value:
                        '${formatBytesCompact(state.processedBytes)}/${formatBytesCompact(state.totalBytes)}',
                  ),
                _MemoryAiTaskMetricChip(
                  label: context.l10n.memoryToolTaskResultCountLabel,
                  value: state.resultCount.toString(),
                ),
                _MemoryAiTaskMetricChip(
                  label: context.l10n.memoryToolTaskCancelAction,
                  value: state.canCancel
                      ? (context.isZh ? '可用' : 'Enabled')
                      : (context.isZh ? '不可用' : 'Disabled'),
                ),
              ],
            ),
            if (!isRunning) ...<Widget>[
              SizedBox(height: 12 * scale),
              Text(
                _searchTaskTerminalHint(context, state),
                style: TextStyle(
                  fontSize: 10.8 * scale,
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemoryAiSearchTaskCardFromState extends StatelessWidget {
  const _MemoryAiSearchTaskCardFromState({required this.state});

  final SearchTaskState state;

  @override
  Widget build(BuildContext context) {
    return _MemoryAiSearchTaskOverviewCard(
      title: state.isFirstScan
          ? context.l10n.memoryToolTaskFirstScanTitle
          : context.l10n.memoryToolTaskNextScanTitle,
      fields: _buildSearchTaskOverviewFields(state),
    );
  }
}

class _MemoryAiPointerScanTaskCardFromState extends StatelessWidget {
  const _MemoryAiPointerScanTaskCardFromState({required this.state});

  final PointerScanTaskState state;

  @override
  Widget build(BuildContext context) {
    return _MemoryAiTaskOverviewCard(
      title: context.isZh ? '指针扫描任务' : 'Pointer Scan Task',
      fields: _buildPointerScanTaskOverviewFields(state),
      tone: const _MemoryAiCardTone(
        accent: Color(0xFF7B61FF),
        icon: Icons.account_tree_rounded,
      ),
    );
  }
}

class _MemoryAiPointerAutoChaseCardFromState extends StatelessWidget {
  const _MemoryAiPointerAutoChaseCardFromState({required this.state});

  final PointerAutoChaseState state;

  @override
  Widget build(BuildContext context) {
    return _MemoryAiTaskOverviewCard(
      title: context.isZh ? '自动追链任务' : 'Pointer Auto Chase',
      fields: _buildPointerAutoChaseOverviewFields(state),
      tone: const _MemoryAiCardTone(
        accent: Color(0xFF7B61FF),
        icon: Icons.track_changes_rounded,
      ),
    );
  }
}

class _MemoryAiSearchResultCard extends StatelessWidget {
  const _MemoryAiSearchResultCard({required this.row});

  final MemoryAiToolRowData row;

  @override
  Widget build(BuildContext context) {
    final fields = row.fields;
    return _MemoryAiEntityCard(
      tone: const _MemoryAiCardTone(
        accent: Color(0xFF2C7BE5),
        icon: Icons.manage_search_rounded,
      ),
      title: _value(fields, 'address'),
      subtitle: _value(fields, 'value'),
      chips: <String>[
        if (_value(fields, 'type').isNotEmpty)
          _chip(context, 'type', _value(fields, 'type')),
        if (_value(fields, 'regionType').isNotEmpty)
          _chip(context, 'regionType', _value(fields, 'regionType')),
      ],
      facts: <_MemoryAiFact>[
        _MemoryAiFact('regionStart', _value(fields, 'regionStart')),
        _MemoryAiFact('hex', _value(fields, 'hex')),
      ],
    );
  }
}

class _MemoryAiValuePreviewCard extends StatelessWidget {
  const _MemoryAiValuePreviewCard({required this.row});

  final MemoryAiToolRowData row;

  @override
  Widget build(BuildContext context) {
    final fields = row.fields;
    return _MemoryAiEntityCard(
      tone: const _MemoryAiCardTone(
        accent: Color(0xFF149D8F),
        icon: Icons.data_object_rounded,
      ),
      title: _value(fields, 'address'),
      subtitle: _value(fields, 'value'),
      chips: <String>[
        if (_value(fields, 'type').isNotEmpty)
          _chip(context, 'type', _value(fields, 'type')),
      ],
      facts: <_MemoryAiFact>[_MemoryAiFact('hex', _value(fields, 'hex'))],
    );
  }
}

class _MemoryAiInstructionCard extends StatelessWidget {
  const _MemoryAiInstructionCard({required this.row});

  final MemoryAiToolRowData row;

  @override
  Widget build(BuildContext context) {
    final fields = row.fields;
    return _MemoryAiEntityCard(
      tone: const _MemoryAiCardTone(
        accent: Color(0xFFE07A1F),
        icon: Icons.code_rounded,
      ),
      title: _value(fields, 'address'),
      subtitle: _value(fields, 'asm'),
      chips: <String>[
        if (_value(fields, 'arch').isNotEmpty)
          _chip(context, 'arch', _value(fields, 'arch')),
        if (_value(fields, 'size').isNotEmpty)
          _chip(context, 'size', _value(fields, 'size')),
      ],
      facts: <_MemoryAiFact>[_MemoryAiFact('bytes', _value(fields, 'bytes'))],
    );
  }
}

class _MemoryAiBreakpointCard extends StatelessWidget {
  const _MemoryAiBreakpointCard({required this.row});

  final MemoryAiToolRowData row;

  @override
  Widget build(BuildContext context) {
    final fields = row.fields;
    return _MemoryAiEntityCard(
      tone: const _MemoryAiCardTone(
        accent: Color(0xFFC84E4E),
        icon: Icons.bug_report_rounded,
      ),
      title: _value(fields, 'id'),
      subtitle: _value(fields, 'address'),
      chips: <String>[
        if (_value(fields, 'type').isNotEmpty)
          _chip(context, 'type', _value(fields, 'type')),
        if (_value(fields, 'access').isNotEmpty)
          _chip(context, 'access', _value(fields, 'access')),
        if (_value(fields, 'enabled').isNotEmpty)
          _chip(context, 'enabled', _value(fields, 'enabled')),
        if (_value(fields, 'pauseOnHit').isNotEmpty)
          _chip(context, 'pauseOnHit', _value(fields, 'pauseOnHit')),
        if (_value(fields, 'hitCount').isNotEmpty)
          _chip(context, 'hitCount', _value(fields, 'hitCount')),
      ],
      facts: <_MemoryAiFact>[
        _MemoryAiFact('length', _value(fields, 'length')),
        _MemoryAiFact('lastHit', _value(fields, 'lastHit')),
        _MemoryAiFact('lastError', _value(fields, 'lastError')),
      ],
    );
  }
}

class _MemoryAiBreakpointHitCard extends StatelessWidget {
  const _MemoryAiBreakpointHitCard({required this.row});

  final MemoryAiToolRowData row;

  @override
  Widget build(BuildContext context) {
    final fields = row.fields;
    final scale = AiChatCompactScope.scaleOf(context);

    return _MemoryAiEntityCard(
      tone: const _MemoryAiCardTone(
        accent: Color(0xFFD15A6A),
        icon: Icons.notifications_active_rounded,
      ),
      title: _value(fields, 'breakpointId'),
      subtitle: _value(fields, 'address'),
      chips: <String>[
        if (_value(fields, 'access').isNotEmpty)
          _chip(context, 'access', _value(fields, 'access')),
        if (_value(fields, 'threadId').isNotEmpty)
          _chip(context, 'threadId', _value(fields, 'threadId')),
      ],
      facts: <_MemoryAiFact>[
        _MemoryAiFact('time', _value(fields, 'time')),
        _MemoryAiFact('pc', _value(fields, 'pc')),
        _MemoryAiFact('module', _value(fields, 'module')),
        _MemoryAiFact('moduleOffset', _value(fields, 'moduleOffset')),
        _MemoryAiFact('instruction', _value(fields, 'instruction')),
      ],
      extra: Row(
        children: <Widget>[
          Expanded(
            child: _MemoryAiCodeBox(
              label: 'old',
              value: _value(fields, 'old'),
              accent: const Color(0xFFD15A6A),
            ),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: _MemoryAiCodeBox(
              label: 'new',
              value: _value(fields, 'new'),
              accent: const Color(0xFFD15A6A),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryAiPointerResultCard extends StatelessWidget {
  const _MemoryAiPointerResultCard({required this.row});

  final MemoryAiToolRowData row;

  @override
  Widget build(BuildContext context) {
    final fields = row.fields;
    return _MemoryAiEntityCard(
      tone: const _MemoryAiCardTone(
        accent: Color(0xFF6A5AE0),
        icon: Icons.account_tree_rounded,
      ),
      title: _value(fields, 'pointer'),
      subtitle: _factText(context, 'target', _value(fields, 'target')),
      chips: <String>[
        if (_value(fields, 'offset').isNotEmpty)
          _chip(context, 'offset', _value(fields, 'offset')),
        if (_value(fields, 'regionType').isNotEmpty)
          _chip(context, 'regionType', _value(fields, 'regionType')),
      ],
      facts: <_MemoryAiFact>[
        _MemoryAiFact('base', _value(fields, 'base')),
        _MemoryAiFact('target', _value(fields, 'target')),
        _MemoryAiFact('regionStart', _value(fields, 'regionStart')),
      ],
    );
  }
}

class _MemoryAiPointerChaseHintCard extends StatelessWidget {
  const _MemoryAiPointerChaseHintCard({required this.row});

  final MemoryAiToolRowData row;

  @override
  Widget build(BuildContext context) {
    final fields = row.fields;
    final resultFields = <String, String>{};
    final nested = fields['result'];
    if (nested != null && nested.isNotEmpty) {
      resultFields.addAll(MemoryAiToolResultParser.parseInlineFields(nested));
    }
    for (final entry in fields.entries) {
      if (entry.key == 'base' ||
          entry.key == 'target' ||
          entry.key == 'offset' ||
          entry.key == 'regionStart' ||
          entry.key == 'regionType') {
        resultFields.putIfAbsent(entry.key, () => entry.value);
      }
    }

    return _MemoryAiEntityCard(
      tone: const _MemoryAiCardTone(
        accent: Color(0xFF7B61FF),
        icon: Icons.route_rounded,
      ),
      title: _value(
        fields,
        'stopReasonKey',
        fallback: _fallbackText(context, zh: '追链提示', en: 'Chase Hint'),
      ),
      subtitle: _value(fields, 'isTerminalStaticCandidate', fallback: 'false'),
      chips: <String>[
        _chip(
          context,
          'terminal',
          _value(fields, 'isTerminalStaticCandidate', fallback: '-'),
        ),
      ],
      facts: <_MemoryAiFact>[
        if (resultFields.isNotEmpty)
          _MemoryAiFact('pointer', _value(resultFields, 'pointer')),
        if (resultFields.isNotEmpty)
          _MemoryAiFact('base', _value(resultFields, 'base')),
        if (resultFields.isNotEmpty)
          _MemoryAiFact('target', _value(resultFields, 'target')),
        if (resultFields.isNotEmpty)
          _MemoryAiFact('offset', _value(resultFields, 'offset')),
      ],
    );
  }
}

class _MemoryAiAutoChaseLayerCard extends StatelessWidget {
  const _MemoryAiAutoChaseLayerCard({required this.row});

  final MemoryAiToolRowData row;

  @override
  Widget build(BuildContext context) {
    final fields = row.fields;
    return _MemoryAiEntityCard(
      tone: const _MemoryAiCardTone(
        accent: Color(0xFF8C63D7),
        icon: Icons.layers_rounded,
      ),
      title: _factText(context, 'layer', _value(fields, 'layer')),
      subtitle: _factText(context, 'target', _value(fields, 'target')),
      chips: <String>[
        if (_value(fields, 'resultCount').isNotEmpty)
          _chip(context, 'resultCount', _value(fields, 'resultCount')),
        if (_value(fields, 'hasMore').isNotEmpty)
          _chip(context, 'hasMore', _value(fields, 'hasMore')),
        if (_value(fields, 'terminal').isNotEmpty)
          _chip(context, 'terminal', _value(fields, 'terminal')),
      ],
      facts: <_MemoryAiFact>[
        _MemoryAiFact('selectedPointer', _value(fields, 'selectedPointer')),
        _MemoryAiFact('stopReason', _value(fields, 'stopReason')),
      ],
    );
  }
}

class _MemoryAiRawLineCard extends StatelessWidget {
  const _MemoryAiRawLineCard({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10 * scale),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        raw,
        style: TextStyle(
          fontSize: 11.5 * scale,
          height: 1.45,
          fontFamily: 'monospace',
          color: context.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _MemoryAiEntityCard extends StatelessWidget {
  const _MemoryAiEntityCard({
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.facts,
    this.extra,
  });

  final _MemoryAiCardTone tone;
  final String title;
  final String subtitle;
  final List<String> chips;
  final List<_MemoryAiFact> facts;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    final visibleFacts = facts.where((fact) => fact.value.isNotEmpty).toList();

    return _MemoryAiCardFrame(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 28 * scale,
                height: 28 * scale,
                decoration: BoxDecoration(
                  color: tone.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10 * scale),
                ),
                child: Icon(tone.icon, size: 16 * scale, color: tone.accent),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.4 * scale,
                        fontWeight: FontWeight.w800,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...<Widget>[
                      SizedBox(height: 2 * scale),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.2 * scale,
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...<Widget>[
            SizedBox(height: 10 * scale),
            Wrap(
              spacing: 6 * scale,
              runSpacing: 6 * scale,
              children: chips
                  .where((chip) => chip.trim().isNotEmpty)
                  .map((chip) => _MemoryAiChip(text: chip, accent: tone.accent))
                  .toList(growable: false),
            ),
          ],
          if (visibleFacts.isNotEmpty) ...<Widget>[
            SizedBox(height: 10 * scale),
            ...visibleFacts.map(
              (fact) => Padding(
                padding: EdgeInsets.only(bottom: 6 * scale),
                child: _MemoryAiFactRow(label: fact.label, value: fact.value),
              ),
            ),
          ],
          if (extra != null) ...<Widget>[SizedBox(height: 10 * scale), extra!],
        ],
      ),
    );
  }
}

class _MemoryAiCardFrame extends StatelessWidget {
  const _MemoryAiCardFrame({required this.tone, required this.child});

  final _MemoryAiCardTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tone.accent.withValues(alpha: context.isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(color: tone.accent.withValues(alpha: 0.2)),
      ),
      child: Padding(padding: EdgeInsets.all(12 * scale), child: child),
    );
  }
}

class _MemoryAiChip extends StatelessWidget {
  const _MemoryAiChip({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10 * scale,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

class _MemoryAiSectionTitle extends StatelessWidget {
  const _MemoryAiSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4 * scale),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.2 * scale,
          fontWeight: FontWeight.w900,
          color: context.colorScheme.onSurface.withValues(alpha: 0.68),
        ),
      ),
    );
  }
}

class _MemoryAiFactRow extends StatelessWidget {
  const _MemoryAiFactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    final displayLabel = _label(context, label);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 94 * scale,
          child: Text(
            displayLabel,
            style: TextStyle(
              fontSize: 10.8 * scale,
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface.withValues(alpha: 0.56),
            ),
          ),
        ),
        SizedBox(width: 8 * scale),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.2 * scale,
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
              fontFamily: _usesMonospace(value) ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _MemoryAiProgressRow extends StatelessWidget {
  const _MemoryAiProgressRow({required this.item, required this.accent});

  final _MemoryAiProgressItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    final percentText = item.ratio == null
        ? ''
        : '${(item.ratio! * 100).clamp(0.0, 100.0).toStringAsFixed(item.ratio! >= 0.1 ? 0 : 1)}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 10.8 * scale,
                  fontWeight: FontWeight.w800,
                  color: context.colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              item.valueText,
              style: TextStyle(
                fontSize: 10.6 * scale,
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface.withValues(alpha: 0.72),
                fontFamily: 'monospace',
              ),
            ),
            if (percentText.isNotEmpty) ...<Widget>[
              SizedBox(width: 8 * scale),
              Text(
                percentText,
                style: TextStyle(
                  fontSize: 10.6 * scale,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 6 * scale),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: item.ratio,
            minHeight: 7 * scale,
            backgroundColor: accent.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ],
    );
  }
}

class _MemoryAiStatPill extends StatelessWidget {
  const _MemoryAiStatPill({required this.item, required this.accent});

  final _MemoryAiStatItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 7 * scale,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            item.label,
            style: TextStyle(
              fontSize: 10 * scale,
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface.withValues(alpha: 0.58),
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 11.2 * scale,
              fontWeight: FontWeight.w800,
              color: context.colorScheme.onSurface,
              fontFamily: _usesMonospace(item.value) ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryAiTaskMetricChip extends StatelessWidget {
  const _MemoryAiTaskMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF8BB8F8).withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 8 * scale,
        ),
        child: Text(
          '$label $value',
          style: TextStyle(
            fontSize: 10.4 * scale,
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _MemoryAiCodeBox extends StatelessWidget {
  const _MemoryAiCodeBox({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scale = AiChatCompactScope.scaleOf(context);
    return Container(
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: context.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 10 * scale,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            value.isEmpty ? '-' : value,
            style: TextStyle(
              fontSize: 10.8 * scale,
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryAiCardTone {
  const _MemoryAiCardTone({required this.accent, required this.icon});

  final Color accent;
  final IconData icon;
}

class _MemoryAiFact {
  const _MemoryAiFact(this.label, this.value);

  final String label;
  final String value;
}

class _MemoryAiProgressItem {
  const _MemoryAiProgressItem({
    required this.label,
    required this.valueText,
    required this.ratio,
  });

  final String label;
  final String valueText;
  final double? ratio;
}

class _MemoryAiStatItem {
  const _MemoryAiStatItem({required this.label, required this.value});

  final String label;
  final String value;
}

_MemoryAiCardTone _resolveOverviewTone(
  String? title,
  Map<String, String> fields,
) {
  final titleText = title ?? '';
  if (titleText.contains('断点') || fields.containsKey('activeBreakpointCount')) {
    return const _MemoryAiCardTone(
      accent: Color(0xFFC84E4E),
      icon: Icons.bug_report_rounded,
    );
  }
  if (titleText.contains('指针') ||
      titleText.contains('追链') ||
      fields.containsKey('currentDepth')) {
    return const _MemoryAiCardTone(
      accent: Color(0xFF7B61FF),
      icon: Icons.account_tree_rounded,
    );
  }
  if (titleText.contains('搜索') ||
      fields.containsKey('processedRegions') ||
      fields.containsKey('processedEntries')) {
    return const _MemoryAiCardTone(
      accent: Color(0xFF2C7BE5),
      icon: Icons.query_stats_rounded,
    );
  }
  return const _MemoryAiCardTone(
    accent: Color(0xFF149D8F),
    icon: Icons.memory_rounded,
  );
}

bool _isSearchTaskOverview(String? title, Map<String, String> fields) {
  return !fields.containsKey('processedEntries') &&
      !fields.containsKey('currentDepth') &&
      fields.containsKey('processedRegions') &&
      fields.containsKey('processedBytes') &&
      (title?.contains('搜索') ?? false);
}

Map<String, String> _buildSearchTaskOverviewFields(SearchTaskState state) {
  return <String, String>{
    'status': state.status.name,
    'processedRegions': '${state.processedRegions}/${state.totalRegions}',
    'processedBytes': '${state.processedBytes}/${state.totalBytes}',
    'resultCount': state.resultCount.toString(),
    'elapsedMs': state.elapsedMilliseconds.toString(),
    'canCancel': state.canCancel.toString(),
    if (state.message.trim().isNotEmpty) 'message': state.message.trim(),
  };
}

Map<String, String> _buildPointerScanTaskOverviewFields(
  PointerScanTaskState state,
) {
  return <String, String>{
    'status': state.status.name,
    'processedRegions': '${state.processedRegions}/${state.totalRegions}',
    'processedEntries': '${state.processedEntries}/${state.totalEntries}',
    'processedBytes': '${state.processedBytes}/${state.totalBytes}',
    'resultCount': state.resultCount.toString(),
    'elapsedMs': state.elapsedMilliseconds.toString(),
    'canCancel': state.canCancel.toString(),
    if (state.message.trim().isNotEmpty) 'message': state.message.trim(),
  };
}

Map<String, String> _buildPointerAutoChaseOverviewFields(
  PointerAutoChaseState state,
) {
  final normalizedMessage = state.message.trim();
  final status = state.isRunning
      ? 'running'
      : normalizedMessage.isNotEmpty
      ? 'failed'
      : 'completed';
  return <String, String>{
    'status': status,
    'currentDepth': '${state.currentDepth}/${state.maxDepth}',
    'resultCount': state.layers.isEmpty
        ? '0'
        : state.layers.last.resultCount.toString(),
    if (normalizedMessage.isNotEmpty) 'message': normalizedMessage,
    if (state.pid > 0) 'pid': state.pid.toString(),
    'layers': state.layers.length.toString(),
  };
}

SearchTaskState _buildSearchTaskState(
  Map<String, String> fields, {
  String? title,
}) {
  final message = _normalizeTaskMessageForState(_value(fields, 'message'));
  return SearchTaskState(
    status: _parseSearchTaskStatus(_value(fields, 'status')),
    isFirstScan:
        message.contains('首次') ||
        (title?.contains('首次') ?? false) ||
        !message.contains('继续筛选'),
    pid: 0,
    processedRegions: _parseTaskCurrent(fields, 'processedRegions'),
    totalRegions: _parseTaskTotal(fields, 'processedRegions'),
    processedEntries: _parseTaskCurrent(fields, 'processedEntries'),
    totalEntries: _parseTaskTotal(fields, 'processedEntries'),
    processedBytes: _parseTaskCurrent(fields, 'processedBytes'),
    totalBytes: _parseTaskTotal(fields, 'processedBytes'),
    resultCount: int.tryParse(_value(fields, 'resultCount')) ?? 0,
    elapsedMilliseconds: _parseElapsedMilliseconds(_value(fields, 'elapsedMs')),
    canCancel: _parseBoolValue(_value(fields, 'canCancel')),
    message: message,
  );
}

SearchTaskStatus _parseSearchTaskStatus(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'running':
      return SearchTaskStatus.running;
    case 'completed':
      return SearchTaskStatus.completed;
    case 'cancelled':
    case 'canceled':
      return SearchTaskStatus.cancelled;
    case 'failed':
      return SearchTaskStatus.failed;
    case 'idle':
    default:
      return SearchTaskStatus.idle;
  }
}

int _parseTaskCurrent(Map<String, String> fields, String key) {
  final value = _value(fields, key);
  final match = RegExp(r'^\s*(\d+)').firstMatch(value);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

int _parseTaskTotal(Map<String, String> fields, String key) {
  final value = _value(fields, key);
  final match = RegExp(r'/\s*(\d+)\s*$').firstMatch(value);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

int _parseElapsedMilliseconds(String raw) {
  final digits = RegExp(r'\d+').firstMatch(raw)?.group(0);
  return int.tryParse(digits ?? '') ?? 0;
}

bool _parseBoolValue(String raw) {
  return raw.trim().toLowerCase() == 'true';
}

String _searchTaskHint(BuildContext context, SearchTaskState state) {
  final message = state.message.trim();
  if (message.isNotEmpty) {
    return message;
  }
  if (state.status == SearchTaskStatus.running) {
    return context.l10n.memoryToolTaskRunningHint;
  }
  return _searchTaskTerminalHint(context, state);
}

String _searchTaskTerminalHint(BuildContext context, SearchTaskState state) {
  switch (state.status) {
    case SearchTaskStatus.completed:
      return context.isZh ? '搜索任务已完成' : 'Search task completed';
    case SearchTaskStatus.cancelled:
      return context.isZh ? '搜索任务已取消' : 'Search task canceled';
    case SearchTaskStatus.failed:
      return context.isZh ? '搜索任务失败' : 'Search task failed';
    case SearchTaskStatus.idle:
      return context.isZh ? '当前没有活动搜索任务' : 'No active search task';
    case SearchTaskStatus.running:
      return context.l10n.memoryToolTaskRunningHint;
  }
}

String _formatElapsedForSearchCard(
  BuildContext context,
  SearchTaskState state,
) {
  final raw = formatDurationShort(state.elapsedMilliseconds);
  if (!context.isZh) {
    return raw;
  }
  return raw.replaceAll('m', '分 ').replaceAll('s', '秒').trim();
}

String _normalizeTaskMessageForState(String value) {
  final message = value.trim();
  if (message.isEmpty) {
    return '';
  }
  final normalized = message.toLowerCase();
  if (normalized == 'first scan is running.') {
    return '首次搜索进行中';
  }
  if (normalized == 'next scan is running.') {
    return '继续筛选进行中';
  }
  if (normalized == 'search task completed.') {
    return '搜索任务已完成';
  }
  if (normalized == 'search task cancelled.' ||
      normalized == 'search task canceled.') {
    return '搜索任务已取消';
  }
  if (normalized == 'search task failed.') {
    return '搜索任务失败';
  }
  return message;
}

String _value(Map<String, String> fields, String key, {String fallback = ''}) {
  final value = fields[key];
  if (value == null || value.trim().isEmpty || value.trim() == '-') {
    return fallback;
  }
  return value.trim();
}

bool _usesMonospace(String value) {
  return value.contains('0x') ||
      value.contains('/') ||
      value.contains('\\') ||
      value.contains('=') ||
      value.contains('.');
}

bool _isTaskOverview(Map<String, String> fields) {
  return fields.containsKey('status') ||
      fields.containsKey('processedRegions') ||
      fields.containsKey('processedEntries') ||
      fields.containsKey('processedBytes') ||
      fields.containsKey('currentDepth');
}

List<_MemoryAiProgressItem> _buildProgressItems(
  BuildContext context,
  Map<String, String> fields,
) {
  final items = <_MemoryAiProgressItem>[];

  void addFractionItem(String key, String labelKey) {
    final value = _value(fields, key);
    if (value.isEmpty) {
      return;
    }
    items.add(
      _MemoryAiProgressItem(
        label: _label(context, labelKey),
        valueText: value,
        ratio: _parseFractionRatio(value),
      ),
    );
  }

  addFractionItem('processedRegions', 'processedRegions');
  addFractionItem('processedEntries', 'processedEntries');
  addFractionItem('processedBytes', 'processedBytes');
  addFractionItem('currentDepth', 'currentDepth');

  return items;
}

List<_MemoryAiStatItem> _buildTaskStatItems(
  BuildContext context,
  Map<String, String> fields,
) {
  final items = <_MemoryAiStatItem>[];

  void addItem(String key) {
    final value = _value(fields, key);
    if (value.isEmpty) {
      return;
    }
    items.add(
      _MemoryAiStatItem(
        label: _label(context, key),
        value: _displayTaskValue(context, key, value),
      ),
    );
  }

  addItem('resultCount');
  addItem('elapsedMs');
  addItem('canCancel');

  return items;
}

double? _parseFractionRatio(String value) {
  final match = RegExp(r'^\s*(\d+)\s*/\s*(\d+)\s*$').firstMatch(value);
  if (match == null) {
    return null;
  }
  final current = int.tryParse(match.group(1)!);
  final total = int.tryParse(match.group(2)!);
  if (current == null || total == null || total <= 0) {
    return null;
  }
  final ratio = current / total;
  if (ratio.isNaN || ratio.isInfinite) {
    return null;
  }
  return ratio.clamp(0.0, 1.0).toDouble();
}

String _statusLabel(BuildContext context, String status) {
  final normalized = status.trim().toLowerCase();
  return switch (normalized) {
    'running' => _fallbackText(context, zh: '运行中', en: 'Running'),
    'completed' => _fallbackText(context, zh: '已完成', en: 'Completed'),
    'idle' => _fallbackText(context, zh: '空闲', en: 'Idle'),
    'cancelled' => _fallbackText(context, zh: '已取消', en: 'Canceled'),
    'canceled' => _fallbackText(context, zh: '已取消', en: 'Canceled'),
    'failed' => _fallbackText(context, zh: '失败', en: 'Failed'),
    _ => status,
  };
}

Color _statusColor(String status) {
  final normalized = status.trim().toLowerCase();
  return switch (normalized) {
    'running' => const Color(0xFF2C7BE5),
    'completed' => const Color(0xFF2E9B62),
    'idle' => const Color(0xFF7A8794),
    'cancelled' => const Color(0xFFE07A1F),
    'canceled' => const Color(0xFFE07A1F),
    'failed' => const Color(0xFFC84E4E),
    _ => const Color(0xFF7A8794),
  };
}

String _chip(BuildContext context, String key, String value) {
  return '${_label(context, key)} $value';
}

String _displayTaskValue(BuildContext context, String key, String value) {
  if (key == 'canCancel') {
    if (value == 'true') {
      return _fallbackText(context, zh: '可取消', en: 'Cancelable');
    }
    if (value == 'false') {
      return _fallbackText(context, zh: '不可取消', en: 'Locked');
    }
  }
  if (key == 'elapsedMs') {
    final milliseconds = int.tryParse(value);
    if (milliseconds == null) {
      return value;
    }
    if (milliseconds >= 1000) {
      final seconds = milliseconds / 1000;
      return context.isZh
          ? '${seconds.toStringAsFixed(seconds >= 10 ? 0 : 1)} 秒'
          : '${seconds.toStringAsFixed(seconds >= 10 ? 0 : 1)} s';
    }
    return context.isZh ? '${milliseconds} 毫秒' : '${milliseconds} ms';
  }
  return value;
}

String _normalizeTaskMessageDisplay(BuildContext context, String value) {
  final message = value.trim();
  if (message.isEmpty) {
    return '';
  }
  final normalized = message.toLowerCase();
  if (normalized == 'first scan is running.') {
    return _fallbackText(context, zh: '首次搜索进行中', en: 'First scan is running');
  }
  if (normalized == 'next scan is running.') {
    return _fallbackText(context, zh: '继续筛选进行中', en: 'Next scan is running');
  }
  if (normalized == 'pointer scan is running.') {
    return _fallbackText(context, zh: '指针扫描进行中', en: 'Pointer scan is running');
  }
  if (normalized == 'pointer auto chase is running.') {
    return _fallbackText(
      context,
      zh: '自动追链进行中',
      en: 'Pointer auto chase is running',
    );
  }
  return message;
}

String _factText(BuildContext context, String key, String value) {
  if (value.isEmpty) {
    return '';
  }
  return '${_label(context, key)} $value';
}

String _label(BuildContext context, String key) {
  final labels = context.isZh
      ? <String, String>{
          'type': '类型',
          'regionType': '区域',
          'regionStart': '区域起点',
          'hex': '十六进制',
          'arch': '架构',
          'size': '长度',
          'bytes': '字节',
          'access': '访问',
          'enabled': '启用',
          'pauseOnHit': '命中暂停',
          'hitCount': '命中',
          'length': '长度',
          'lastHit': '上次命中',
          'lastError': '错误',
          'time': '时间',
          'pc': 'PC',
          'module': '模块',
          'moduleOffset': '模块偏移',
          'instruction': '指令',
          'threadId': '线程',
          'target': '目标',
          'offset': '偏移',
          'processedRegions': '区域进度',
          'processedEntries': '条目进度',
          'processedBytes': '字节进度',
          'currentDepth': '深度进度',
          'resultCount': '结果',
          'elapsedMs': '耗时',
          'canCancel': '取消',
          'status': '状态',
          'message': '说明',
          'pointer': '指针',
          'base': '基址',
          'terminal': '终止',
          'layer': '层级',
          'hasMore': '更多',
          'selectedPointer': '已选指针',
          'stopReason': '停止原因',
          'stopReasonKey': '停止原因',
          'isTerminalStaticCandidate': '静态候选',
          'breakpointId': '断点',
          'id': 'ID',
          'address': '地址',
          'value': '值',
        }
      : <String, String>{
          'type': 'Type',
          'regionType': 'Region',
          'regionStart': 'Region Start',
          'hex': 'Hex',
          'arch': 'Arch',
          'size': 'Size',
          'bytes': 'Bytes',
          'access': 'Access',
          'enabled': 'Enabled',
          'pauseOnHit': 'Pause',
          'hitCount': 'Hits',
          'length': 'Length',
          'lastHit': 'Last Hit',
          'lastError': 'Error',
          'time': 'Time',
          'pc': 'PC',
          'module': 'Module',
          'moduleOffset': 'Module Offset',
          'instruction': 'Instruction',
          'threadId': 'Thread',
          'target': 'Target',
          'offset': 'Offset',
          'processedRegions': 'Regions',
          'processedEntries': 'Entries',
          'processedBytes': 'Bytes',
          'currentDepth': 'Depth',
          'resultCount': 'Results',
          'elapsedMs': 'Elapsed',
          'canCancel': 'Cancel',
          'status': 'Status',
          'message': 'Message',
          'pointer': 'Pointer',
          'base': 'Base',
          'terminal': 'Terminal',
          'layer': 'Layer',
          'hasMore': 'More',
          'selectedPointer': 'Selected',
          'stopReason': 'Stop Reason',
          'stopReasonKey': 'Stop Reason',
          'isTerminalStaticCandidate': 'Static Candidate',
          'breakpointId': 'Breakpoint',
          'id': 'ID',
          'address': 'Address',
          'value': 'Value',
        };
  return labels[key] ?? key;
}

String _fallbackText(
  BuildContext context, {
  required String zh,
  required String en,
}) {
  return context.isZh ? zh : en;
}

const Set<String> _taskPrimaryKeys = <String>{
  'status',
  'processedRegions',
  'processedEntries',
  'processedBytes',
  'currentDepth',
  'message',
  'resultCount',
  'elapsedMs',
  'canCancel',
};
