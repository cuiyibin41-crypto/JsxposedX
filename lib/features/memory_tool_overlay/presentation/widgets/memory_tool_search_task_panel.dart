import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/core/utils/format_utils.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_task_progress_resolver.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolSearchTaskPanel extends StatelessWidget {
  const MemoryToolSearchTaskPanel({
    super.key,
    required this.state,
    required this.onCancel,
  });

  final SearchTaskState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final progress = resolveMemoryToolSearchTaskProgress(state);

    return SafeArea(
      minimum: EdgeInsets.all(12.r),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxPanelHeight = (constraints.maxHeight - 12.r)
              .clamp(220.r, double.infinity)
              .toDouble();

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 340.r,
                minWidth: 240.r,
                maxHeight: maxPanelHeight,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18.r,
                      offset: Offset(0, 10.r),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        state.isFirstScan
                            ? context.l10n.memoryToolTaskFirstScanTitle
                            : context.l10n.memoryToolTaskNextScanTitle,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6.r),
                      Text(
                        context.l10n.memoryToolTaskRunningHint,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.68,
                          ),
                        ),
                      ),
                      SizedBox(height: 14.r),
                      progress == null
                          ? const Loading()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999.r),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8.r,
                                  ),
                                ),
                                SizedBox(height: 8.r),
                                Text(
                                  '${(progress * 100).toStringAsFixed(1)}%',
                                  style: context.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                      SizedBox(height: 14.r),
                      Wrap(
                        spacing: 8.r,
                        runSpacing: 8.r,
                        children: <Widget>[
                          _MemoryToolTaskMetricChip(
                            label: context.l10n.memoryToolTaskElapsedLabel,
                            value: formatDurationShort(state.elapsedMilliseconds),
                          ),
                          if (state.totalRegions > 0)
                            _MemoryToolTaskMetricChip(
                              label: context.l10n.memoryToolTaskRegionsLabel,
                              value:
                                  '${state.processedRegions}/${state.totalRegions}',
                            ),
                          if (state.totalEntries > 0)
                            _MemoryToolTaskMetricChip(
                              label: context.l10n.memoryToolTaskEntriesLabel,
                              value:
                                  '${state.processedEntries}/${state.totalEntries}',
                            ),
                          if (state.totalBytes > 0)
                            _MemoryToolTaskMetricChip(
                              label: context.l10n.memoryToolTaskBytesLabel,
                              value:
                                  '${formatBytesCompact(state.processedBytes)}/${formatBytesCompact(state.totalBytes)}',
                            ),
                          _MemoryToolTaskMetricChip(
                            label: context.l10n.memoryToolTaskResultCountLabel,
                            value: state.resultCount.toString(),
                          ),
                        ],
                      ),
                      SizedBox(height: 14.r),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: state.canCancel ? onCancel : null,
                          child: Text(context.l10n.memoryToolTaskCancelAction),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MemoryToolTaskMetricChip extends StatelessWidget {
  const _MemoryToolTaskMetricChip({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.72,
        ),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 8.r),
        child: Text(
          '$label $value',
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
