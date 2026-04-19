import 'dart:async';

import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/debug_tabs/memory_tool_debug_breakpoints_tab.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/debug_tabs/memory_tool_debug_detail_tab.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/debug_tabs/memory_tool_debug_writers_tab.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_breakpoint_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_pointer_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_debug_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_debug_primitives.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_pointer_scan_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_stats_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_action_dialog.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolDebugTab extends HookConsumerWidget {
  const MemoryToolDebugTab({
    super.key,
    required this.onOpenBrowseTab,
    required this.onOpenPointerTab,
  });

  final VoidCallback onOpenBrowseTab;
  final VoidCallback onOpenPointerTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final pid = selectedProcess?.pid;
    final selectedBreakpointId = ref.watch(memoryBreakpointSelectedIdProvider);
    final breakpointActionState = ref.watch(memoryBreakpointActionProvider);
    final browseNotifier = ref.read(memoryToolBrowseControllerProvider.notifier);
    final pointerNotifier = ref.read(memoryToolPointerControllerProvider.notifier);
    final savedItemsNotifier = ref.read(memoryToolSavedItemsProvider.notifier);
    final selectedWriterKey = useState<String?>(null);
    final selectedHitKey = useState<String?>(null);
    final activePointerScanAddress = useState<int?>(null);
    final activeAutoChaseAddress = useState<int?>(null);
    final activeDetailActions =
        useState<List<MemoryToolSearchResultActionItemData>?>(null);
    final compactTabController = useTabController(initialLength: 3);
    final landscapeDetailTabController = useTabController(initialLength: 2);
    final stateAsync = pid == null
        ? AsyncValue<MemoryBreakpointState>.data(
            MemoryBreakpointState(
              isSupported: true,
              isProcessPaused: false,
              activeBreakpointCount: 0,
              pendingHitCount: 0,
              architecture: '',
              lastError: '',
            ),
          )
        : ref.watch(getMemoryBreakpointStateProvider(pid: pid));
    final breakpointsAsync = pid == null
        ? const AsyncValue<List<MemoryBreakpoint>>.data(<MemoryBreakpoint>[])
        : ref.watch(getMemoryBreakpointsProvider(pid: pid));
    final hitsAsync = pid == null
        ? const AsyncValue<List<MemoryBreakpointHit>>.data(
            <MemoryBreakpointHit>[],
          )
        : ref.watch(getMemoryBreakpointHitsProvider(pid: pid));
    final breakpoints =
        breakpointsAsync.asData?.value ?? const <MemoryBreakpoint>[];
    final allHits = hitsAsync.asData?.value ?? const <MemoryBreakpointHit>[];

    useEffect(() {
      selectedWriterKey.value = null;
      selectedHitKey.value = null;
      compactTabController.index = 0;
      landscapeDetailTabController.index = 0;
      return null;
    }, [pid]);

    useEffect(() {
      if (pid == null) {
        return null;
      }
      final timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
        ref.invalidate(getMemoryBreakpointStateProvider(pid: pid));
        ref.invalidate(getMemoryBreakpointsProvider(pid: pid));
        ref.invalidate(getMemoryBreakpointHitsProvider(pid: pid));
      });
      return timer.cancel;
    }, [pid]);

    useEffect(() {
      if (pid == null) {
        return null;
      }
      if (breakpoints.isEmpty) {
        if (selectedBreakpointId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(memoryBreakpointSelectedIdProvider.notifier).clear();
          });
        }
        return null;
      }
      final hasSelection = breakpoints.any(
        (breakpoint) => breakpoint.id == selectedBreakpointId,
      );
      if (!hasSelection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(memoryBreakpointSelectedIdProvider.notifier)
              .set(breakpoints.first.id);
        });
      }
      return null;
    }, [pid, breakpoints, selectedBreakpointId]);

    final selectedBreakpoint = resolveMemoryToolDebugSelectedBreakpoint(
      breakpoints: breakpoints,
      selectedBreakpointId: selectedBreakpointId,
    );
    final hits = selectedBreakpoint == null
        ? const <MemoryBreakpointHit>[]
        : allHits
              .where((hit) => hit.breakpointId == selectedBreakpoint.id)
              .toList(growable: false);
    final writerGroups = buildMemoryToolDebugWriterGroups(hits);

    useEffect(() {
      if (pid == null) {
        return null;
      }
      final currentKey = selectedWriterKey.value;
      if (writerGroups.isEmpty) {
        if (currentKey != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            selectedWriterKey.value = null;
          });
        }
        return null;
      }
      final hasSelection = writerGroups.any((group) => group.key == currentKey);
      if (!hasSelection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          selectedWriterKey.value = writerGroups.first.key;
        });
      }
      return null;
    }, [pid, selectedBreakpoint?.id, writerGroups, selectedWriterKey.value]);

    final selectedWriterGroup = resolveMemoryToolDebugSelectedWriterGroup(
      groups: writerGroups,
      selectedWriterKey: selectedWriterKey.value,
    );

    useEffect(() {
      final currentKey = selectedHitKey.value;
      final groupHits =
          selectedWriterGroup?.hits ?? const <MemoryBreakpointHit>[];
      if (groupHits.isEmpty) {
        if (currentKey != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            selectedHitKey.value = null;
          });
        }
        return null;
      }
      final hasSelection = groupHits.any(
        (hit) => buildMemoryToolDebugHitKey(hit) == currentKey,
      );
      if (!hasSelection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          selectedHitKey.value = buildMemoryToolDebugHitKey(groupHits.first);
        });
      }
      return null;
    }, [selectedWriterGroup?.key, selectedHitKey.value]);

    final selectedHit = resolveMemoryToolDebugSelectedHit(
      hits: selectedWriterGroup?.hits ?? const <MemoryBreakpointHit>[],
      selectedHitKey: selectedHitKey.value,
    );
    final selectedValueInfo = resolveMemoryToolDebugBreakpointValueInfo(
      breakpoint: selectedBreakpoint,
      hit: selectedHit,
    );
    final state = stateAsync.asData?.value;
    final isPaused = state?.isProcessPaused ?? false;

    if (pid == null) {
      return Padding(
        padding: EdgeInsets.all(12.r),
        child: const MemoryToolDebugProcessEmptyState(),
      );
    }

    Future<void> refreshAll() async {
      ref.invalidate(getMemoryBreakpointStateProvider(pid: pid));
      ref.invalidate(getMemoryBreakpointsProvider(pid: pid));
      ref.invalidate(getMemoryBreakpointHitsProvider(pid: pid));
    }

    Future<void> copyText(String value) async {
      final copied = await FlutterOverlayWindow.setClipboardData(value);
      ref.read(overlayWindowHostRuntimeProvider.notifier).showToast(
        copied ? context.l10n.codeCopied : context.l10n.error,
      );
    }

    Future<void> previewRawAddress({
      required int targetAddress,
      required SearchValueType type,
      required int bytesLength,
    }) async {
      try {
        await browseNotifier.previewRawAddress(
          targetAddress: targetAddress,
          type: type,
          bytesLength: bytesLength,
        );
        onOpenBrowseTab();
      } catch (_) {
        await ToastOverlayMessage.show(
          context.l10n.memoryToolOffsetPreviewUnreadable,
          duration: const Duration(milliseconds: 1200),
        );
      }
    }

    Future<void> saveBreakpointValue() async {
      if (selectedBreakpoint == null || selectedValueInfo == null) {
        return;
      }
      savedItemsNotifier.saveOne(
        pid: pid,
        result: selectedValueInfo.result,
        preview: selectedValueInfo.preview,
        isFrozen: false,
      );
      await ToastOverlayMessage.show(
        context.l10n.memoryToolSavedToSavedMessage(1),
        duration: const Duration(milliseconds: 1200),
      );
    }

    void openDetailActions(List<MemoryToolSearchResultActionItemData> actions) {
      if (actions.isEmpty) {
        return;
      }
      activeDetailActions.value = actions;
    }

    List<MemoryToolSearchResultActionItemData> buildCurrentValueActions() {
      if (selectedValueInfo == null || selectedHit == null) {
        return const <MemoryToolSearchResultActionItemData>[];
      }
      final valueInfo = selectedValueInfo;
      return <MemoryToolSearchResultActionItemData>[
        MemoryToolSearchResultActionItemData(
          icon: Icons.tune_rounded,
          title: context.l10n.memoryToolDebugActionCopyValue,
          onTap: () async {
            await copyText(valueInfo.displayValue);
            activeDetailActions.value = null;
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.data_array_rounded,
          title:
              '${context.l10n.memoryToolDebugActionCopyHex}: ${formatMemoryToolSearchResultHex(valueInfo.rawBytes)}',
          onTap: () async {
            await copyText(
              formatMemoryToolSearchResultHex(valueInfo.rawBytes),
            );
            activeDetailActions.value = null;
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.swap_horiz_rounded,
          title:
              '${context.l10n.memoryToolDebugActionCopyReverseHex}: ${formatMemoryToolSearchResultReverseHex(valueInfo.rawBytes)}',
          onTap: () async {
            await copyText(
              formatMemoryToolSearchResultReverseHex(valueInfo.rawBytes),
            );
            activeDetailActions.value = null;
          },
        ),
      ];
    }

    List<MemoryToolSearchResultActionItemData> buildAddressActions() {
      if (selectedBreakpoint == null) {
        return const <MemoryToolSearchResultActionItemData>[];
      }
      final breakpoint = selectedBreakpoint;
      return <MemoryToolSearchResultActionItemData>[
        MemoryToolSearchResultActionItemData(
          icon: Icons.preview_rounded,
          title: context.l10n.memoryToolDebugActionBrowseAddress,
          onTap: () async {
            activeDetailActions.value = null;
            await previewRawAddress(
              targetAddress: breakpoint.address,
              type: breakpoint.type,
              bytesLength: breakpoint.length,
            );
          },
        ),
        if (selectedValueInfo != null && selectedHit != null)
          MemoryToolSearchResultActionItemData(
            icon: Icons.save_alt_rounded,
            title: context.l10n.memoryToolResultActionSaveToSaved,
            onTap: () async {
              activeDetailActions.value = null;
              await saveBreakpointValue();
            },
          ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.account_tree_rounded,
          title: context.l10n.memoryToolDebugActionPointerScan,
          onTap: () async {
            activeDetailActions.value = null;
            activePointerScanAddress.value = breakpoint.address;
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.auto_mode_rounded,
          title: context.l10n.memoryToolDebugActionAutoChase,
          onTap: () async {
            activeDetailActions.value = null;
            activeAutoChaseAddress.value = breakpoint.address;
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.copy_all_rounded,
          title:
              '${context.l10n.memoryToolDebugActionCopyAddress}: ${formatMemoryToolSearchResultAddress(breakpoint.address)}',
          onTap: () async {
            await copyText(
              formatMemoryToolSearchResultAddress(breakpoint.address),
            );
            activeDetailActions.value = null;
          },
        ),
      ];
    }

    List<MemoryToolSearchResultActionItemData> buildPointerActions() {
      if (selectedWriterGroup == null) {
        return const <MemoryToolSearchResultActionItemData>[];
      }
      final writerGroup = selectedWriterGroup;
      return <MemoryToolSearchResultActionItemData>[
        MemoryToolSearchResultActionItemData(
          icon: Icons.preview_rounded,
          title: context.l10n.memoryToolDebugActionBrowseAddress,
          onTap: () async {
            activeDetailActions.value = null;
            await previewRawAddress(
              targetAddress: writerGroup.pc,
              type: SearchValueType.bytes,
              bytesLength: 4,
            );
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.copy_all_rounded,
          title:
              '${context.l10n.memoryToolDebugActionCopyAddress}: ${formatMemoryToolSearchResultAddress(writerGroup.pc)}',
          onTap: () async {
            await copyText(
              formatMemoryToolSearchResultAddress(writerGroup.pc),
            );
            activeDetailActions.value = null;
          },
        ),
      ];
    }

    List<MemoryToolSearchResultActionItemData> buildCopyOnlyActions({
      required String title,
      required String value,
      required IconData icon,
    }) {
      if (value.trim().isEmpty) {
        return const <MemoryToolSearchResultActionItemData>[];
      }
      return <MemoryToolSearchResultActionItemData>[
        MemoryToolSearchResultActionItemData(
          icon: icon,
          title: '$title: $value',
          onTap: () async {
            await copyText(value);
            activeDetailActions.value = null;
          },
        ),
      ];
    }

    List<MemoryToolSearchResultActionItemData> buildHitActions(
      MemoryBreakpointHit hit,
    ) {
      final resolvedType = selectedBreakpoint?.type ?? SearchValueType.bytes;
      final displayValue = resolveMemoryToolSearchResultValueByType(
        type: resolvedType,
        rawBytes: hit.newValue,
        fallbackDisplayValue: formatMemoryToolDebugBytes(hit.newValue),
      );
      return <MemoryToolSearchResultActionItemData>[
        MemoryToolSearchResultActionItemData(
          icon: Icons.tune_rounded,
          title: '${context.l10n.memoryToolDebugActionCopyValue}: $displayValue',
          onTap: () async {
            await copyText(displayValue);
            activeDetailActions.value = null;
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.data_array_rounded,
          title:
              '${context.l10n.memoryToolDebugActionCopyHex}: ${formatMemoryToolSearchResultHex(hit.newValue)}',
          onTap: () async {
            await copyText(formatMemoryToolSearchResultHex(hit.newValue));
            activeDetailActions.value = null;
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.swap_horiz_rounded,
          title:
              '${context.l10n.memoryToolDebugActionCopyReverseHex}: ${formatMemoryToolSearchResultReverseHex(hit.newValue)}',
          onTap: () async {
            await copyText(
              formatMemoryToolSearchResultReverseHex(hit.newValue),
            );
            activeDetailActions.value = null;
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.preview_rounded,
          title: context.l10n.memoryToolDebugActionBrowseHitPointer,
          onTap: () async {
            activeDetailActions.value = null;
            await previewRawAddress(
              targetAddress: hit.pc,
              type: SearchValueType.bytes,
              bytesLength: 4,
            );
          },
        ),
      ];
    }

    return Stack(
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            final isWide =
                constraints.maxWidth >= 1280 && constraints.maxHeight >= 480;
            final isMedium = constraints.maxWidth >= 760;
            final isShortHeight = constraints.maxHeight < 320;
            final useLandscapeWorkbench = isLandscape && isMedium && !isWide;
            final outerSpacing = isShortHeight ? 6.r : 8.r;
            final workbenchPadding = isShortHeight ? 8.r : 10.r;
            final selectedModuleOffset = selectedWriterGroup == null
                ? null
                : formatMemoryToolDebugModuleOffset(
                    selectedWriterGroup,
                    anonymousModuleLabel:
                        context.l10n.memoryToolDebugAnonymousModule,
                  );
            final selectedInstructionText =
                selectedWriterGroup?.instructionText.trim() ?? '';
            final selectedTransition = selectedWriterGroup?.topTransition;

            final breakpointTab = MemoryToolDebugBreakpointsTab(
              breakpointsAsync: breakpointsAsync,
              selectedBreakpointId: selectedBreakpoint?.id,
              onSelect: (breakpointId) {
                ref
                    .read(memoryBreakpointSelectedIdProvider.notifier)
                    .set(breakpointId);
                if (useLandscapeWorkbench) {
                  landscapeDetailTabController.animateTo(0);
                } else if (!isMedium) {
                  compactTabController.animateTo(1);
                }
              },
              onToggleEnabled: (breakpoint) async {
                await ref
                    .read(memoryBreakpointActionProvider.notifier)
                    .setMemoryBreakpointEnabled(
                      pid: pid,
                      breakpointId: breakpoint.id,
                      enabled: !breakpoint.enabled,
                    );
              },
              onRemove: (breakpoint) async {
                await ref
                    .read(memoryBreakpointActionProvider.notifier)
                    .removeMemoryBreakpoint(
                      pid: pid,
                      breakpointId: breakpoint.id,
                    );
              },
            );

            final writersTab = MemoryToolDebugWritersTab(
              groups: writerGroups,
              selectedWriterKey: selectedWriterKey.value,
              onSelectWriter: (group) {
                selectedWriterKey.value = group.key;
                if (useLandscapeWorkbench) {
                  landscapeDetailTabController.animateTo(1);
                } else if (!isMedium) {
                  compactTabController.animateTo(2);
                }
              },
            );

            final detailTab = MemoryToolDebugDetailTab(
              group: selectedWriterGroup,
              breakpoint: selectedBreakpoint,
              selectedHit: selectedHit,
              valueInfo: selectedValueInfo,
              onOpenCurrentValueActions: () {
                openDetailActions(buildCurrentValueActions());
              },
              onOpenAddressActions: () {
                openDetailActions(buildAddressActions());
              },
              onOpenPointerActions: () {
                openDetailActions(buildPointerActions());
              },
              onOpenModuleActions: () {
                if (selectedModuleOffset == null) {
                  return;
                }
                openDetailActions(
                  buildCopyOnlyActions(
                    title: context.l10n.memoryToolDebugActionCopyModuleOffset,
                    value: selectedModuleOffset,
                    icon: Icons.copy_all_rounded,
                  ),
                );
              },
              onOpenInstructionActions: selectedInstructionText.isEmpty
                  ? null
                  : () {
                      openDetailActions(
                        buildCopyOnlyActions(
                          title: context.l10n.memoryToolDebugActionCopyInstruction,
                          value: selectedInstructionText,
                          icon: Icons.copy_all_rounded,
                        ),
                      );
                    },
              onOpenRewriteActions: selectedTransition == null
                  ? null
                  : () {
                      openDetailActions(
                        buildCopyOnlyActions(
                          title: context.l10n.memoryToolDebugActionCopyRewrite,
                          value: selectedTransition.summary,
                          icon: Icons.copy_all_rounded,
                        ),
                      );
                    },
              onSelectHit: (hit) {
                selectedHitKey.value = buildMemoryToolDebugHitKey(hit);
              },
              onOpenHitActions: (hit) {
                openDetailActions(buildHitActions(hit));
              },
            );

            final body = isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(flex: 9, child: breakpointTab),
                      const _MemoryToolDebugPanelDivider(vertical: true),
                      Expanded(flex: 10, child: writersTab),
                      const _MemoryToolDebugPanelDivider(vertical: true),
                      Expanded(flex: 11, child: detailTab),
                    ],
                  )
                : useLandscapeWorkbench
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(
                            flex: constraints.maxWidth >= 960 ? 8 : 9,
                            child: breakpointTab,
                          ),
                          const _MemoryToolDebugPanelDivider(vertical: true),
                          Expanded(
                            flex: constraints.maxWidth >= 960 ? 14 : 12,
                            child: _MemoryToolDebugLandscapeDetailWorkbench(
                              controller: landscapeDetailTabController,
                              writersTab: writersTab,
                              detailTab: detailTab,
                            ),
                          ),
                        ],
                      )
                    : isMedium
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Expanded(flex: 9, child: breakpointTab),
                              const _MemoryToolDebugPanelDivider(vertical: true),
                              Expanded(
                                flex: 12,
                                child: Column(
                                  children: <Widget>[
                                    Expanded(child: writersTab),
                                    const _MemoryToolDebugPanelDivider(vertical: false),
                                    Expanded(child: detailTab),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : _MemoryToolDebugCompactWorkbench(
                            controller: compactTabController,
                            breakpointTab: breakpointTab,
                            writersTab: writersTab,
                            detailTab: detailTab,
                          );

            return Padding(
              padding: EdgeInsets.all(isShortHeight ? 8.r : 12.r),
              child: Column(
                children: <Widget>[
                  MemoryToolResultSelectionBar(
                    actions: <MemoryToolResultSelectionActionData>[
                      MemoryToolResultSelectionActionData(
                        icon: Icons.refresh_rounded,
                        onTap: breakpointActionState.isLoading ? null : refreshAll,
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.play_arrow_rounded,
                        onTap: breakpointActionState.isLoading || !isPaused
                            ? null
                            : () async {
                                await ref
                                    .read(memoryBreakpointActionProvider.notifier)
                                    .resumeAfterBreakpoint(pid: pid);
                              },
                      ),
                      MemoryToolResultSelectionActionData(
                        icon: Icons.layers_clear_rounded,
                        onTap: breakpointActionState.isLoading
                            ? null
                            : () async {
                                await ref
                                    .read(memoryBreakpointActionProvider.notifier)
                                    .clearMemoryBreakpointHits(pid: pid);
                              },
                      ),
                    ],
                  ),
                  SizedBox(height: outerSpacing),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.colorScheme.surface.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: context.colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(workbenchPadding),
                        child: body,
                      ),
                    ),
                  ),
                  if (!useLandscapeWorkbench) ...<Widget>[
                    SizedBox(height: isShortHeight ? 4.r : 6.r),
                    _MemoryToolDebugStatsBar(
                      state: state,
                      selectedBreakpoint: selectedBreakpoint,
                      hitCount: hits.length,
                      breakpointCount: breakpoints.length,
                      writerCount: writerGroups.length,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        if (activePointerScanAddress.value case final targetAddress?)
          Positioned.fill(
            child: MemoryToolPointerScanDialog(
              pid: pid,
              targetAddress: targetAddress,
              onConfirm: (request) async {
                onOpenPointerTab();
                await pointerNotifier.startRootScan(request: request);
              },
              onClose: () {
                activePointerScanAddress.value = null;
              },
            ),
          ),
        if (activeAutoChaseAddress.value case final targetAddress?)
          Positioned.fill(
            child: MemoryToolPointerScanDialog(
              pid: pid,
              targetAddress: targetAddress,
              showMaxDepthField: true,
              onConfirmAutoChase: (request, maxDepth) async {
                onOpenPointerTab();
                await pointerNotifier.startAutoChase(
                  request: request,
                  maxDepth: maxDepth,
                );
              },
              onClose: () {
                activeAutoChaseAddress.value = null;
              },
            ),
          ),
        if (activeDetailActions.value case final actions?)
          Positioned.fill(
            child: MemoryToolSearchResultActionDialog(
              actions: actions,
              onClose: () {
                activeDetailActions.value = null;
              },
            ),
          ),
      ],
    );
  }
}

class _MemoryToolDebugCompactWorkbench extends StatelessWidget {
  const _MemoryToolDebugCompactWorkbench({
    required this.controller,
    required this.breakpointTab,
    required this.writersTab,
    required this.detailTab,
  });

  final TabController controller;
  final Widget breakpointTab;
  final Widget writersTab;
  final Widget detailTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TabBar(
          controller: controller,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            color: context.colorScheme.primary.withValues(alpha: 0.12),
          ),
          labelColor: context.colorScheme.primary,
          unselectedLabelColor: context.colorScheme.onSurfaceVariant,
          labelStyle: context.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          tabs: <Widget>[
            Tab(text: context.l10n.memoryToolDebugBreakpointsTab),
            Tab(text: context.l10n.memoryToolDebugWritersTitle),
            Tab(text: context.l10n.memoryToolDebugDetailTitle),
          ],
        ),
        SizedBox(height: 10.r),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: <Widget>[
              breakpointTab,
              writersTab,
              detailTab,
            ],
          ),
        ),
      ],
    );
  }
}

class _MemoryToolDebugLandscapeDetailWorkbench extends StatelessWidget {
  const _MemoryToolDebugLandscapeDetailWorkbench({
    required this.controller,
    required this.writersTab,
    required this.detailTab,
  });

  final TabController controller;
  final Widget writersTab;
  final Widget detailTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: TabBar(
            controller: controller,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(10.r),
              color: context.colorScheme.primary.withValues(alpha: 0.12),
            ),
            labelColor: context.colorScheme.primary,
            unselectedLabelColor: context.colorScheme.onSurfaceVariant,
            labelStyle: context.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            tabs: <Widget>[
              Tab(text: context.l10n.memoryToolDebugWritersTitle),
              Tab(text: context.l10n.memoryToolDebugDetailTitle),
            ],
          ),
        ),
        SizedBox(height: 8.r),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: <Widget>[
              writersTab,
              detailTab,
            ],
          ),
        ),
      ],
    );
  }
}

class _MemoryToolDebugPanelDivider extends StatelessWidget {
  const _MemoryToolDebugPanelDivider({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.r),
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.r),
      child: Divider(
        height: 1,
        thickness: 1,
        color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
    );
  }
}

class _MemoryToolDebugStatsBar extends StatelessWidget {
  const _MemoryToolDebugStatsBar({
    required this.state,
    required this.selectedBreakpoint,
    required this.hitCount,
    required this.breakpointCount,
    required this.writerCount,
  });

  final MemoryBreakpointState? state;
  final MemoryBreakpoint? selectedBreakpoint;
  final int hitCount;
  final int breakpointCount;
  final int writerCount;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            MemoryToolResultStatChip(
              label: context.l10n.memoryToolDebugStatBreakpoints,
              value: breakpointCount,
            ),
            SizedBox(width: 6.r),
            MemoryToolResultStatChip(
              label: context.l10n.memoryToolDebugStatActive,
              value: state?.activeBreakpointCount ?? 0,
            ),
            SizedBox(width: 6.r),
            MemoryToolResultStatChip(
              label: context.l10n.memoryToolDebugStatWriters,
              value: writerCount,
            ),
            SizedBox(width: 6.r),
            MemoryToolResultStatChip(
              label: context.l10n.memoryToolDebugStatCurrentHits,
              value: hitCount,
            ),
            SizedBox(width: 6.r),
            MemoryToolResultStatChip(
              label: context.l10n.memoryToolDebugStatPending,
              value: state?.pendingHitCount ?? 0,
            ),
            if (selectedBreakpoint != null) ...<Widget>[
              SizedBox(width: 6.r),
              MemoryToolResultStatChip(
                label: context.l10n.memoryToolDebugStatLength,
                value: selectedBreakpoint!.length,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
