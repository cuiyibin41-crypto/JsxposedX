import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_debug_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_debug_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolDebugWritersTab extends StatelessWidget {
  const MemoryToolDebugWritersTab({
    super.key,
    required this.groups,
    required this.selectedWriterKey,
    required this.onSelectWriter,
  });

  final List<MemoryToolDebugWriterGroup> groups;
  final String? selectedWriterKey;
  final ValueChanged<MemoryToolDebugWriterGroup> onSelectWriter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.memoryToolDebugWritersTitle,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8.r),
        Expanded(
          child: groups.isEmpty
              ? MemoryToolDebugEmptyState(
                  message: context.l10n.memoryToolDebugEmptyWriters,
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => SizedBox(height: 6.r),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final isSelected = group.key == selectedWriterKey;
                    return MemoryToolDebugListItemShell(
                      selected: isSelected,
                      onTap: () {
                        onSelectWriter(group);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  formatMemoryToolDebugTimestamp(
                                    group.latestTimestamp,
                                  ),
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: context.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              MemoryToolDebugInlineChip(
                                text:
                                    '${group.threadCount} ${context.l10n.memoryToolDebugThreadCountUnit}',
                              ),
                            ],
                          ),
                          SizedBox(height: 4.r),
                          Text(
                            '${context.l10n.memoryToolDebugPointer} 0x${group.pc.toRadixString(16).toUpperCase()}',
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (group.instructionText.isNotEmpty) ...<Widget>[
                            SizedBox(height: 3.r),
                            Text(
                              formatMemoryToolDebugInstruction(
                                group.instructionText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          SizedBox(height: 3.r),
                          Text(
                            formatMemoryToolDebugModuleOffset(
                              group,
                              anonymousModuleLabel:
                                  context.l10n.memoryToolDebugAnonymousModule,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 6.r),
                          Wrap(
                            spacing: 6.r,
                            runSpacing: 6.r,
                            children: <Widget>[
                              MemoryToolDebugInlineChip(
                                text:
                                    '${group.hitCount} ${context.l10n.memoryToolDebugHitCountUnit}',
                                active: true,
                              ),
                              if (group.topTransition != null)
                                MemoryToolDebugInlineChip(
                                  text: group.topTransition!.summary,
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
