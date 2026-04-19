import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_debug_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_debug_primitives.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolDebugBreakpointsTab extends StatelessWidget {
  const MemoryToolDebugBreakpointsTab({
    super.key,
    required this.breakpointsAsync,
    required this.selectedBreakpointId,
    required this.onSelect,
    required this.onToggleEnabled,
    required this.onRemove,
  });

  final AsyncValue<List<MemoryBreakpoint>> breakpointsAsync;
  final String? selectedBreakpointId;
  final ValueChanged<String> onSelect;
  final Future<void> Function(MemoryBreakpoint breakpoint) onToggleEnabled;
  final Future<void> Function(MemoryBreakpoint breakpoint) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.memoryToolDebugBreakpointsTitle,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8.r),
        Expanded(
          child: breakpointsAsync.when(
            data: (breakpoints) {
              if (breakpoints.isEmpty) {
                return MemoryToolDebugEmptyState(
                  message: context.l10n.memoryToolDebugEmptyBreakpoints,
                );
              }
              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: breakpoints.length,
                separatorBuilder: (_, _) => SizedBox(height: 6.r),
                itemBuilder: (context, index) {
                  final breakpoint = breakpoints[index];
                  final isSelected = breakpoint.id == selectedBreakpointId;
                  return MemoryToolDebugListItemShell(
                    selected: isSelected,
                    onTap: () {
                      onSelect(breakpoint.id);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '0x${breakpoint.address.toRadixString(16).toUpperCase()}',
                                style: context.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            MemoryToolDebugInlineChip(
                              text: breakpoint.enabled
                                  ? context.l10n.memoryToolDebugEnabled
                                  : context.l10n.memoryToolDebugDisabled,
                              active: breakpoint.enabled,
                            ),
                          ],
                        ),
                        SizedBox(height: 6.r),
                        Wrap(
                          spacing: 6.r,
                          runSpacing: 6.r,
                          children: <Widget>[
                            MemoryToolDebugInlineChip(
                              text: formatMemoryToolDebugAccessType(
                                context.l10n,
                                breakpoint.accessType,
                              ),
                            ),
                            MemoryToolDebugInlineChip(
                              text: '${breakpoint.length}B',
                            ),
                            MemoryToolDebugInlineChip(
                              text: breakpoint.pauseProcessOnHit
                                  ? context.l10n.memoryToolDebugPauseOnHit
                                  : context.l10n.memoryToolDebugRecordOnly,
                            ),
                            MemoryToolDebugInlineChip(
                              text:
                                  '${breakpoint.hitCount} ${context.l10n.memoryToolDebugHitCountUnit}',
                            ),
                          ],
                        ),
                        if (breakpoint.lastHitAtMillis != null) ...<Widget>[
                          SizedBox(height: 6.r),
                          Text(
                            '${context.l10n.memoryToolDebugLastHitPrefix} ${formatMemoryToolDebugTimestamp(breakpoint.lastHitAtMillis!)}',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (breakpoint.lastError.isNotEmpty) ...<Widget>[
                          SizedBox(height: 6.r),
                          Text(
                            breakpoint.lastError,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.error,
                            ),
                          ),
                        ],
                        SizedBox(height: 6.r),
                        Row(
                          children: <Widget>[
                            Switch.adaptive(
                              value: breakpoint.enabled,
                              onChanged: (_) async {
                                await onToggleEnabled(breakpoint);
                              },
                            ),
                            const Spacer(),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () async {
                                await onRemove(breakpoint);
                              },
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            error: (error, _) =>
                MemoryToolDebugEmptyState(message: error.toString()),
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
          ),
        ),
      ],
    );
  }
}
