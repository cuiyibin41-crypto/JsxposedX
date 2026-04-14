import 'dart:math' as math;

import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolSearchTaskOverlay extends StatelessWidget {
  const MemoryToolSearchTaskOverlay({
    super.key,
    required this.taskStateAsync,
    required this.onCancel,
  });

  final AsyncValue<SearchTaskState> taskStateAsync;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return taskStateAsync.when(
      skipLoadingOnRefresh: true,
      data: (state) {
        if (state.status != SearchTaskStatus.running) {
          return const SizedBox.shrink();
        }

        final progress = _resolveProgress(state);
        return Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.34),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 340.r, minWidth: 240.r),
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
                  child: Padding(
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
                                    style: context.textTheme.labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
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
                              value: _formatDuration(state.elapsedMilliseconds),
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
                                    '${_formatBytes(state.processedBytes)}/${_formatBytes(state.totalBytes)}',
                              ),
                            _MemoryToolTaskMetricChip(
                              label:
                                  context.l10n.memoryToolTaskResultCountLabel,
                              value: state.resultCount.toString(),
                            ),
                          ],
                        ),
                        SizedBox(height: 14.r),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            onPressed: state.canCancel ? onCancel : null,
                            child: Text(
                              context.l10n.memoryToolTaskCancelAction,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }

  double? _resolveProgress(SearchTaskState state) {
    if (state.totalBytes > 0) {
      return math.min(1.0, state.processedBytes / state.totalBytes);
    }
    if (state.totalEntries > 0) {
      return math.min(1.0, state.processedEntries / state.totalEntries);
    }
    if (state.totalRegions > 0) {
      return math.min(1.0, state.processedRegions / state.totalRegions);
    }
    return null;
  }

  String _formatDuration(int milliseconds) {
    final totalSeconds = (milliseconds / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes <= 0) {
      return '${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  String _formatBytes(int value) {
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (value >= 1024) {
      return '${(value / 1024).toStringAsFixed(1)} KB';
    }
    return '$value B';
  }
}

class _MemoryToolTaskMetricChip extends StatelessWidget {
  const _MemoryToolTaskMetricChip({required this.label, required this.value});

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
