import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_debug_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_debug_primitives.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_debug_tiles.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolDebugDetailTab extends StatelessWidget {
  const MemoryToolDebugDetailTab({
    super.key,
    required this.group,
    required this.breakpoint,
    required this.selectedHit,
    required this.valueInfo,
    required this.onOpenCurrentValueActions,
    required this.onOpenAddressActions,
    required this.onOpenPointerActions,
    required this.onOpenModuleActions,
    required this.onOpenInstructionActions,
    required this.onOpenRewriteActions,
    required this.onSelectHit,
    required this.onOpenHitActions,
  });

  final MemoryToolDebugWriterGroup? group;
  final MemoryBreakpoint? breakpoint;
  final MemoryBreakpointHit? selectedHit;
  final MemoryToolDebugBreakpointValueInfo? valueInfo;
  final VoidCallback onOpenCurrentValueActions;
  final VoidCallback onOpenAddressActions;
  final VoidCallback onOpenPointerActions;
  final VoidCallback onOpenModuleActions;
  final VoidCallback? onOpenInstructionActions;
  final VoidCallback? onOpenRewriteActions;
  final ValueChanged<MemoryBreakpointHit> onSelectHit;
  final ValueChanged<MemoryBreakpointHit> onOpenHitActions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.memoryToolDebugDetailTitle,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8.r),
        Expanded(
          child: group == null
              ? MemoryToolDebugEmptyState(
                  message: context.l10n.memoryToolDebugEmptyDetail,
                )
              : _MemoryToolDebugDetailContent(
                  group: group!,
                  breakpoint: breakpoint,
                  selectedHit: selectedHit,
                  valueInfo: valueInfo,
                  onOpenCurrentValueActions: onOpenCurrentValueActions,
                  onOpenAddressActions: onOpenAddressActions,
                  onOpenPointerActions: onOpenPointerActions,
                  onOpenModuleActions: onOpenModuleActions,
                  onOpenInstructionActions: onOpenInstructionActions,
                  onOpenRewriteActions: onOpenRewriteActions,
                  onSelectHit: onSelectHit,
                  onOpenHitActions: onOpenHitActions,
                ),
        ),
      ],
    );
  }
}

class _MemoryToolDebugDetailContent extends StatelessWidget {
  const _MemoryToolDebugDetailContent({
    required this.group,
    required this.breakpoint,
    required this.selectedHit,
    required this.valueInfo,
    required this.onOpenCurrentValueActions,
    required this.onOpenAddressActions,
    required this.onOpenPointerActions,
    required this.onOpenModuleActions,
    required this.onOpenInstructionActions,
    required this.onOpenRewriteActions,
    required this.onSelectHit,
    required this.onOpenHitActions,
  });

  final MemoryToolDebugWriterGroup group;
  final MemoryBreakpoint? breakpoint;
  final MemoryBreakpointHit? selectedHit;
  final MemoryToolDebugBreakpointValueInfo? valueInfo;
  final VoidCallback onOpenCurrentValueActions;
  final VoidCallback onOpenAddressActions;
  final VoidCallback onOpenPointerActions;
  final VoidCallback onOpenModuleActions;
  final VoidCallback? onOpenInstructionActions;
  final VoidCallback? onOpenRewriteActions;
  final ValueChanged<MemoryBreakpointHit> onSelectHit;
  final ValueChanged<MemoryBreakpointHit> onOpenHitActions;

  @override
  Widget build(BuildContext context) {
    final detailTiles = <Widget>[
      MemoryToolDebugDetailInfoTile(
        title: context.l10n.memoryToolDebugCurrentValue,
        value: selectedHit == null
            ? context.l10n.memoryToolDebugNoHitYet
            : (valueInfo?.displayValue ?? '--'),
        monospace:
            selectedHit != null && breakpoint?.type == SearchValueType.bytes,
        onLongPress: selectedHit == null ? null : onOpenCurrentValueActions,
      ),
      SizedBox(height: 6.r),
      MemoryToolDebugDetailInfoTile(
        title: context.l10n.memoryToolDebugBreakpointAddress,
        value: breakpoint == null
            ? '--'
            : '0x${breakpoint!.address.toRadixString(16).toUpperCase()}',
        monospace: true,
        onLongPress: onOpenAddressActions,
      ),
      SizedBox(height: 6.r),
      MemoryToolDebugDetailInfoTile(
        title: context.l10n.memoryToolDebugPointer,
        value: '0x${group.pc.toRadixString(16).toUpperCase()}',
        monospace: true,
        onLongPress: onOpenPointerActions,
      ),
      SizedBox(height: 6.r),
      MemoryToolDebugDetailInfoTile(
        title: context.l10n.memoryToolDebugModuleOffset,
        value: formatMemoryToolDebugModuleOffset(
          group,
          anonymousModuleLabel: context.l10n.memoryToolDebugAnonymousModule,
        ),
        monospace: true,
        onLongPress: onOpenModuleActions,
      ),
    ];

    if (group.instructionText.isNotEmpty) {
      detailTiles.addAll(<Widget>[
        SizedBox(height: 6.r),
        MemoryToolDebugDetailInfoTile(
          title: context.l10n.memoryToolDebugInstruction,
          value: group.instructionText.trim(),
          monospace: true,
          onLongPress: onOpenInstructionActions,
        ),
      ]);
    }

    if (group.topTransition != null) {
      detailTiles.addAll(<Widget>[
        SizedBox(height: 6.r),
        MemoryToolDebugDetailInfoTile(
          title: context.l10n.memoryToolDebugCommonRewrite,
          value: group.topTransition!.summary,
          monospace: true,
          onLongPress: onOpenRewriteActions,
        ),
      ]);
    }

    detailTiles.addAll(<Widget>[
      SizedBox(height: 10.r),
      Text(
        context.l10n.memoryToolDebugRecentHits,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      SizedBox(height: 8.r),
    ]);

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: detailTiles,
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final hit = group.hits[index];
              return Padding(
                padding: EdgeInsets.only(bottom: 6.r),
                child: MemoryToolDebugHitEntryTile(
                  hit: hit,
                  selected:
                      buildMemoryToolDebugHitKey(hit) ==
                      buildMemoryToolDebugHitKey(selectedHit),
                  onTap: () {
                    onSelectHit(hit);
                  },
                  onLongPress: () {
                    onOpenHitActions(hit);
                  },
                ),
              );
            },
            childCount: group.hits.length,
          ),
        ),
      ],
    );
  }
}
