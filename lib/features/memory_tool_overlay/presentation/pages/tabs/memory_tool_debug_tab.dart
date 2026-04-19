import 'dart:async';
import 'dart:typed_data';

import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_breakpoint_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_pointer_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_action_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_stats_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_pointer_scan_dialog.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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
        ? const AsyncValue<List<MemoryBreakpointHit>>.data(<MemoryBreakpointHit>[])
        : ref.watch(getMemoryBreakpointHitsProvider(pid: pid));
    final breakpoints = breakpointsAsync.asData?.value ?? const <MemoryBreakpoint>[];
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

    final selectedBreakpoint = _resolveSelectedBreakpoint(
      breakpoints: breakpoints,
      selectedBreakpointId: selectedBreakpointId,
    );
    final hits = selectedBreakpoint == null
        ? const <MemoryBreakpointHit>[]
        : allHits
              .where((hit) => hit.breakpointId == selectedBreakpoint.id)
              .toList(growable: false);
    final writerGroups = _buildWriterGroups(hits);

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

    final selectedWriterGroup = _resolveSelectedWriterGroup(
      groups: writerGroups,
      selectedWriterKey: selectedWriterKey.value,
    );
    useEffect(() {
      final currentKey = selectedHitKey.value;
      final hits = selectedWriterGroup?.hits ?? const <MemoryBreakpointHit>[];
      if (hits.isEmpty) {
        if (currentKey != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            selectedHitKey.value = null;
          });
        }
        return null;
      }
      final hasSelection = hits.any((hit) => _buildHitKey(hit) == currentKey);
      if (!hasSelection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          selectedHitKey.value = _buildHitKey(hits.first);
        });
      }
      return null;
    }, [selectedWriterGroup?.key, selectedHitKey.value]);
    final selectedHit = _resolveSelectedHit(
      hits: selectedWriterGroup?.hits ?? const <MemoryBreakpointHit>[],
      selectedHitKey: selectedHitKey.value,
    );
    final selectedValueInfo = _resolveBreakpointValueInfo(
      breakpoint: selectedBreakpoint,
      hit: selectedHit,
    );
    final state = stateAsync.asData?.value;
    final isPaused = state?.isProcessPaused ?? false;

    if (pid == null) {
      return Padding(
        padding: EdgeInsets.all(12.r),
        child: const _DebugProcessEmptyState(),
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
      final valueInfo = selectedValueInfo!;
      return <MemoryToolSearchResultActionItemData>[
        MemoryToolSearchResultActionItemData(
          icon: Icons.tune_rounded,
          title: context.isZh ? '复制值' : 'Copy Value',
          onTap: () async {
            await copyText(valueInfo.displayValue);
            activeDetailActions.value = null;
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.data_array_rounded,
          title:
              '${context.isZh ? '复制 Hex' : 'Copy Hex'}: ${formatMemoryToolSearchResultHex(valueInfo.rawBytes)}',
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
              '${context.isZh ? '复制反序 Hex' : 'Copy Reverse Hex'}: ${formatMemoryToolSearchResultReverseHex(valueInfo.rawBytes)}',
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
      final breakpoint = selectedBreakpoint!;
      return <MemoryToolSearchResultActionItemData>[
        MemoryToolSearchResultActionItemData(
          icon: Icons.preview_rounded,
          title: context.isZh ? '浏览地址' : 'Browse Address',
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
            title: context.isZh ? '加入暂存' : 'Save To Saved',
            onTap: () async {
              activeDetailActions.value = null;
              await saveBreakpointValue();
            },
          ),
          MemoryToolSearchResultActionItemData(
            icon: Icons.account_tree_rounded,
            title: context.isZh ? '指针扫描' : 'Pointer Scan',
            onTap: () async {
              activeDetailActions.value = null;
              activePointerScanAddress.value = breakpoint.address;
            },
          ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.auto_mode_rounded,
          title: context.isZh ? '自动追踪' : 'Auto Chase',
          onTap: () async {
            activeDetailActions.value = null;
            activeAutoChaseAddress.value = breakpoint.address;
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.copy_all_rounded,
          title:
              '${context.isZh ? '复制地址' : 'Copy Address'}: ${formatMemoryToolSearchResultAddress(breakpoint.address)}',
          onTap: () async {
            await copyText(
              formatMemoryToolSearchResultAddress(breakpoint.address),
            );
            activeDetailActions.value = null;
          },
        ),
      ];
    }

    List<MemoryToolSearchResultActionItemData> buildPcActions() {
      if (selectedWriterGroup == null) {
        return const <MemoryToolSearchResultActionItemData>[];
      }
      final writerGroup = selectedWriterGroup!;
      return <MemoryToolSearchResultActionItemData>[
        MemoryToolSearchResultActionItemData(
          icon: Icons.preview_rounded,
          title: context.isZh ? '浏览地址' : 'Browse Address',
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
              '${context.isZh ? '复制地址' : 'Copy Address'}: ${formatMemoryToolSearchResultAddress(writerGroup.pc)}',
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
        fallbackDisplayValue: _formatBytes(hit.newValue),
      );
      return <MemoryToolSearchResultActionItemData>[
        MemoryToolSearchResultActionItemData(
          icon: Icons.tune_rounded,
          title: '${context.isZh ? '复制值' : 'Copy Value'}: $displayValue',
          onTap: () async {
            await copyText(displayValue);
            activeDetailActions.value = null;
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.data_array_rounded,
          title:
              '${context.isZh ? '复制 Hex' : 'Copy Hex'}: ${formatMemoryToolSearchResultHex(hit.newValue)}',
          onTap: () async {
            await copyText(formatMemoryToolSearchResultHex(hit.newValue));
            activeDetailActions.value = null;
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.swap_horiz_rounded,
          title:
              '${context.isZh ? '复制反序 Hex' : 'Copy Reverse Hex'}: ${formatMemoryToolSearchResultReverseHex(hit.newValue)}',
          onTap: () async {
            await copyText(
              formatMemoryToolSearchResultReverseHex(hit.newValue),
            );
            activeDetailActions.value = null;
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.preview_rounded,
          title: context.isZh ? '浏览该命中指针' : 'Browse Hit PC',
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

            final breakpointPanel = _DebugSection(
              title: context.isZh ? '断点列表' : 'Breakpoints',
              child: _BreakpointList(
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
              ),
            );

            final writerPanel = _DebugSection(
              title: context.isZh ? '写入源' : 'Writers',
              child: _WriterGroupList(
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
              ),
            );
            final selectedModuleOffset = selectedWriterGroup == null
                ? null
                : _formatModuleOffset(selectedWriterGroup);
            final selectedInstructionText =
                selectedWriterGroup?.instructionText.trim() ?? '';
            final selectedTransition = selectedWriterGroup?.topTransition;

            final detailPanel = _DebugSection(
              title: context.isZh ? '详情' : 'Detail',
              child: _WriterDetail(
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
                onOpenPcActions: () {
                  openDetailActions(buildPcActions());
                },
                onOpenModuleActions: () {
                  if (selectedModuleOffset == null) {
                    return;
                  }
                  openDetailActions(
                    buildCopyOnlyActions(
                      title: context.isZh ? '复制模块偏移' : 'Copy Module Offset',
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
                            title: context.isZh ? '复制指令' : 'Copy Instruction',
                            value: selectedInstructionText,
                            icon: Icons.copy_all_rounded,
                          ),
                        );
                      },
                onOpenTransitionActions: selectedTransition == null
                    ? null
                    : () {
                        openDetailActions(
                          buildCopyOnlyActions(
                            title: context.isZh ? '复制改写文本' : 'Copy Rewrite',
                            value: selectedTransition.summary,
                            icon: Icons.copy_all_rounded,
                          ),
                        );
                      },
                onSelectHit: (hit) {
                  selectedHitKey.value = _buildHitKey(hit);
                },
                onOpenHitActions: (hit) {
                  openDetailActions(buildHitActions(hit));
                },
              ),
            );

            final body = isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(flex: 9, child: breakpointPanel),
                      _PanelDivider(vertical: true),
                      Expanded(flex: 10, child: writerPanel),
                      _PanelDivider(vertical: true),
                      Expanded(flex: 11, child: detailPanel),
                    ],
                  )
                : useLandscapeWorkbench
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(
                            flex: constraints.maxWidth >= 960 ? 8 : 9,
                            child: breakpointPanel,
                          ),
                          _PanelDivider(vertical: true),
                          Expanded(
                            flex: constraints.maxWidth >= 960 ? 14 : 12,
                            child: _LandscapeDetailWorkbench(
                              controller: landscapeDetailTabController,
                              writerPanel: writerPanel,
                              detailPanel: detailPanel,
                            ),
                          ),
                        ],
                      )
                    : isMedium
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Expanded(flex: 9, child: breakpointPanel),
                              _PanelDivider(vertical: true),
                              Expanded(
                                flex: 12,
                                child: Column(
                                  children: <Widget>[
                                    Expanded(child: writerPanel),
                                    _PanelDivider(vertical: false),
                                    Expanded(child: detailPanel),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : _CompactWorkbench(
                            controller: compactTabController,
                            breakpointPanel: breakpointPanel,
                            writerPanel: writerPanel,
                            detailPanel: detailPanel,
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
                    _DebugStatsBar(
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

class _CompactWorkbench extends StatelessWidget {
  const _CompactWorkbench({
    required this.controller,
    required this.breakpointPanel,
    required this.writerPanel,
    required this.detailPanel,
  });

  final TabController controller;
  final Widget breakpointPanel;
  final Widget writerPanel;
  final Widget detailPanel;

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
            Tab(text: context.isZh ? '断点' : 'Breakpoints'),
            Tab(text: context.isZh ? '写入源' : 'Writers'),
            Tab(text: context.isZh ? '详情' : 'Detail'),
          ],
        ),
        SizedBox(height: 10.r),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: <Widget>[
              breakpointPanel,
              writerPanel,
              detailPanel,
            ],
          ),
        ),
      ],
    );
  }
}

class _LandscapeDetailWorkbench extends StatelessWidget {
  const _LandscapeDetailWorkbench({
    required this.controller,
    required this.writerPanel,
    required this.detailPanel,
  });

  final TabController controller;
  final Widget writerPanel;
  final Widget detailPanel;

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
              Tab(text: context.isZh ? '写入源' : 'Writers'),
              Tab(text: context.isZh ? '详情' : 'Detail'),
            ],
          ),
        ),
        SizedBox(height: 8.r),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: <Widget>[
              writerPanel,
              detailPanel,
            ],
          ),
        ),
      ],
    );
  }
}

class _DebugSection extends StatelessWidget {
  const _DebugSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8.r),
        Expanded(child: child),
      ],
    );
  }
}

class _BreakpointList extends StatelessWidget {
  const _BreakpointList({
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
    return breakpointsAsync.when(
      data: (breakpoints) {
        if (breakpoints.isEmpty) {
          return _DebugEmptyState(
            message: context.isZh ? '还没有断点' : 'No breakpoints yet',
          );
        }
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: breakpoints.length,
          separatorBuilder: (_, _) => SizedBox(height: 6.r),
          itemBuilder: (context, index) {
            final breakpoint = breakpoints[index];
            final isSelected = breakpoint.id == selectedBreakpointId;
            return _ListItemShell(
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
                      _InlineChip(
                        text: breakpoint.enabled
                            ? (context.isZh ? '已启用' : 'Enabled')
                            : (context.isZh ? '已禁用' : 'Disabled'),
                        active: breakpoint.enabled,
                      ),
                    ],
                  ),
                  SizedBox(height: 6.r),
                  Wrap(
                    spacing: 6.r,
                    runSpacing: 6.r,
                    children: <Widget>[
                      _InlineChip(
                        text: _mapAccessType(context, breakpoint.accessType),
                      ),
                      _InlineChip(text: '${breakpoint.length}B'),
                      _InlineChip(
                        text: breakpoint.pauseProcessOnHit
                            ? (context.isZh ? '命中即暂停' : 'Pause On Hit')
                            : (context.isZh ? '仅记录' : 'Record Only'),
                      ),
                      _InlineChip(
                        text: '${breakpoint.hitCount}${context.isZh ? ' 次命中' : ' hits'}',
                      ),
                    ],
                  ),
                  if (breakpoint.lastHitAtMillis != null) ...<Widget>[
                    SizedBox(height: 6.r),
                    Text(
                      context.isZh
                          ? '最近命中 ${_formatTimestamp(breakpoint.lastHitAtMillis!)}'
                          : 'Last hit ${_formatTimestamp(breakpoint.lastHitAtMillis!)}',
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
      error: (error, _) => _DebugEmptyState(message: error.toString()),
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
    );
  }

  String _mapAccessType(BuildContext context, MemoryBreakpointAccessType type) {
    return switch (type) {
      MemoryBreakpointAccessType.read => context.isZh ? '读' : 'Read',
      MemoryBreakpointAccessType.write => context.isZh ? '写' : 'Write',
      MemoryBreakpointAccessType.readWrite => context.isZh ? '读写' : 'Read/Write',
    };
  }
}

class _WriterGroupList extends StatelessWidget {
  const _WriterGroupList({
    required this.groups,
    required this.selectedWriterKey,
    required this.onSelectWriter,
  });

  final List<_WriterGroup> groups;
  final String? selectedWriterKey;
  final ValueChanged<_WriterGroup> onSelectWriter;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _DebugEmptyState(
        message: context.isZh ? '这个断点还没有命中' : 'No writer groups for the selected breakpoint',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: groups.length,
      separatorBuilder: (_, _) => SizedBox(height: 6.r),
      itemBuilder: (context, index) {
        final group = groups[index];
        final isSelected = group.key == selectedWriterKey;
        return _ListItemShell(
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
                      _formatTimestamp(group.latestTimestamp),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _InlineChip(
                    text: '${group.threadCount} ${context.isZh ? '线程' : 'thr'}',
                  ),
                ],
              ),
              SizedBox(height: 4.r),
              Text(
                'PC 0x${group.pc.toRadixString(16).toUpperCase()}',
                style: context.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (group.instructionText.isNotEmpty) ...<Widget>[
                SizedBox(height: 3.r),
                Text(
                  _formatInstruction(group.instructionText),
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
                '${group.moduleName.isEmpty ? '[anonymous]' : group.moduleName}+0x${group.moduleOffset.toRadixString(16).toUpperCase()}',
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
                  _InlineChip(
                    text: '${group.hitCount}${context.isZh ? ' 次命中' : ' hits'}',
                    active: true,
                  ),
                  if (group.topTransition != null)
                    _InlineChip(text: group.topTransition!.summary),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WriterDetail extends StatelessWidget {
  const _WriterDetail({
    required this.group,
    required this.breakpoint,
    required this.selectedHit,
    required this.valueInfo,
    required this.onOpenCurrentValueActions,
    required this.onOpenAddressActions,
    required this.onOpenPcActions,
    required this.onOpenModuleActions,
    required this.onOpenInstructionActions,
    required this.onOpenTransitionActions,
    required this.onSelectHit,
    required this.onOpenHitActions,
  });

  final _WriterGroup? group;
  final MemoryBreakpoint? breakpoint;
  final MemoryBreakpointHit? selectedHit;
  final _BreakpointValueInfo? valueInfo;
  final VoidCallback onOpenCurrentValueActions;
  final VoidCallback onOpenAddressActions;
  final VoidCallback onOpenPcActions;
  final VoidCallback onOpenModuleActions;
  final VoidCallback? onOpenInstructionActions;
  final VoidCallback? onOpenTransitionActions;
  final ValueChanged<MemoryBreakpointHit> onSelectHit;
  final ValueChanged<MemoryBreakpointHit> onOpenHitActions;

  @override
  Widget build(BuildContext context) {
    if (group == null) {
      return _DebugEmptyState(
        message: context.isZh ? '选择一个写入源查看详情' : 'Select a writer group to inspect details',
      );
    }

    final detailTiles = <Widget>[
      _DetailInfoTile(
        title: context.isZh ? '当前值' : 'Current Value',
        value: selectedHit == null
            ? (context.isZh ? '暂无命中' : 'No hit yet')
            : (valueInfo?.displayValue ?? '--'),
        monospace:
            selectedHit != null && breakpoint?.type == SearchValueType.bytes,
        onLongPress: selectedHit == null ? null : onOpenCurrentValueActions,
      ),
      SizedBox(height: 6.r),
      _DetailInfoTile(
        title: context.isZh ? '断点地址' : 'Breakpoint Address',
        value: breakpoint == null
            ? '--'
            : '0x${breakpoint!.address.toRadixString(16).toUpperCase()}',
        monospace: true,
        onLongPress: onOpenAddressActions,
      ),
      SizedBox(height: 6.r),
      _DetailInfoTile(
        title: context.isZh ? '指针' : 'PC',
        value: '0x${group!.pc.toRadixString(16).toUpperCase()}',
        monospace: true,
        onLongPress: onOpenPcActions,
      ),
      SizedBox(height: 6.r),
      _DetailInfoTile(
        title: context.isZh ? '模块偏移' : 'Module Offset',
        value: _formatModuleOffset(group!),
        monospace: true,
        onLongPress: onOpenModuleActions,
      ),
    ];

    if (group!.instructionText.isNotEmpty) {
      detailTiles.addAll(<Widget>[
        SizedBox(height: 6.r),
        _DetailInfoTile(
          title: context.isZh ? '指令' : 'Instruction',
          value: group!.instructionText.trim(),
          monospace: true,
          onLongPress: onOpenInstructionActions,
        ),
      ]);
    }

    if (group!.topTransition != null) {
      detailTiles.addAll(<Widget>[
        SizedBox(height: 6.r),
        _DetailInfoTile(
          title: context.isZh ? '常见改写' : 'Common Rewrite',
          value: group!.topTransition!.summary,
          monospace: true,
          onLongPress: onOpenTransitionActions,
        ),
      ]);
    }

    detailTiles.addAll(<Widget>[
      SizedBox(height: 10.r),
      Text(
        context.isZh ? '最近命中' : 'Recent Hits',
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
              final hit = group!.hits[index];
              return Padding(
                padding: EdgeInsets.only(bottom: 6.r),
                child: _HitEntryTile(
                  hit: hit,
                  selected: _buildHitKey(hit) == _buildHitKey(selectedHit),
                  onTap: () {
                    onSelectHit(hit);
                  },
                  onLongPress: () {
                    onOpenHitActions(hit);
                  },
                ),
              );
            },
            childCount: group!.hits.length,
          ),
        ),
      ],
    );
  }
}

class _HitEntryTile extends StatelessWidget {
  const _HitEntryTile({
    required this.hit,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final MemoryBreakpointHit hit;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(14.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: selected
                  ? context.colorScheme.primaryContainer.withValues(alpha: 0.72)
                  : context.colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: selected
                    ? context.colorScheme.primary
                    : context.colorScheme.outlineVariant.withValues(alpha: 0.42),
              ),
            ),
            padding: EdgeInsets.all(12.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _formatTimestamp(hit.timestampMillis),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _InlineChip(text: 'TID ${hit.threadId}'),
                  ],
                ),
                SizedBox(height: 4.r),
                Text(
                  _formatTransition(hit.oldValue, hit.newValue),
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    color: selected ? context.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailInfoTile extends StatelessWidget {
  const _DetailInfoTile({
    required this.title,
    required this.value,
    this.monospace = false,
    this.onLongPress,
  });

  final String title;
  final String value;
  final bool monospace;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(14.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: context.colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.42),
              ),
            ),
            padding: EdgeInsets.all(12.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.r),
                Text(
                  value,
                  softWrap: true,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontFamily: monospace ? 'monospace' : null,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _buildHitKey(MemoryBreakpointHit? hit) {
  if (hit == null) {
    return '';
  }
  return '${hit.timestampMillis}_${hit.threadId}_${hit.pc}_${_formatTransition(hit.oldValue, hit.newValue)}';
}

MemoryBreakpointHit? _resolveSelectedHit({
  required List<MemoryBreakpointHit> hits,
  required String? selectedHitKey,
}) {
  for (final hit in hits) {
    if (_buildHitKey(hit) == selectedHitKey) {
      return hit;
    }
  }
  if (hits.isEmpty) {
    return null;
  }
  return hits.first;
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider({required this.vertical});

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

class _DebugStatsBar extends StatelessWidget {
  const _DebugStatsBar({
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
              label: context.isZh ? '断点' : 'Breakpoints',
              value: breakpointCount,
            ),
            SizedBox(width: 6.r),
            MemoryToolResultStatChip(
              label: context.isZh ? '活动' : 'Active',
              value: state?.activeBreakpointCount ?? 0,
            ),
            SizedBox(width: 6.r),
            MemoryToolResultStatChip(
              label: context.isZh ? '写入源' : 'Writers',
              value: writerCount,
            ),
            SizedBox(width: 6.r),
            MemoryToolResultStatChip(
              label: context.isZh ? '当前命中' : 'Hits',
              value: hitCount,
            ),
            SizedBox(width: 6.r),
            MemoryToolResultStatChip(
              label: context.isZh ? '待处理' : 'Pending',
              value: state?.pendingHitCount ?? 0,
            ),
            if (selectedBreakpoint != null) ...<Widget>[
              SizedBox(width: 6.r),
              MemoryToolResultStatChip(
                label: context.isZh ? '长度' : 'Length',
                value: selectedBreakpoint!.length,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListItemShell extends StatelessWidget {
  const _ListItemShell({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected
                ? context.colorScheme.primaryContainer.withValues(alpha: 0.72)
                : context.colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: selected
                  ? context.colorScheme.primary
                  : context.colorScheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          padding: EdgeInsets.all(12.r),
          child: child,
        ),
      ),
    );
  }
}

class _InlineChip extends StatelessWidget {
  const _InlineChip({required this.text, this.active = false});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? context.colorScheme.primary.withValues(alpha: 0.08)
            : context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 4.r),
        child: Text(
          text,
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: active ? context.colorScheme.primary : null,
          ),
        ),
      ),
    );
  }
}

class _DebugEmptyState extends StatelessWidget {
  const _DebugEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.r),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.66),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DebugProcessEmptyState extends StatelessWidget {
  const _DebugProcessEmptyState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(18.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.bug_report_rounded,
                size: 28.r,
                color: context.colorScheme.primary,
              ),
              SizedBox(height: 10.r),
              Text(
                context.isZh ? '请先选择进程' : 'Select a process first',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6.r),
              Text(
                context.isZh
                    ? '长按搜索结果、预览结果或暂存结果创建断点后，这里会显示命中记录和写入指令。'
                    : 'Create a watchpoint from a long-press result to inspect hit records here.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

MemoryBreakpoint? _resolveSelectedBreakpoint({
  required List<MemoryBreakpoint> breakpoints,
  required String? selectedBreakpointId,
}) {
  for (final breakpoint in breakpoints) {
    if (breakpoint.id == selectedBreakpointId) {
      return breakpoint;
    }
  }
  if (breakpoints.isEmpty) {
    return null;
  }
  return breakpoints.first;
}

_WriterGroup? _resolveSelectedWriterGroup({
  required List<_WriterGroup> groups,
  required String? selectedWriterKey,
}) {
  for (final group in groups) {
    if (group.key == selectedWriterKey) {
      return group;
    }
  }
  if (groups.isEmpty) {
    return null;
  }
  return groups.first;
}

List<_WriterGroup> _buildWriterGroups(List<MemoryBreakpointHit> hits) {
  final grouped = <String, List<MemoryBreakpointHit>>{};
  for (final hit in hits) {
    grouped.putIfAbsent(_buildWriterKey(hit), () => <MemoryBreakpointHit>[]).add(hit);
  }
  final groups = grouped.entries.map((entry) {
    final sortedHits = entry.value.toList(growable: false)
      ..sort((left, right) => right.timestampMillis.compareTo(left.timestampMillis));
    final transitions = _buildTransitions(sortedHits);
    return _WriterGroup(
      key: entry.key,
      pc: sortedHits.first.pc,
      moduleName: sortedHits.first.moduleName,
      moduleOffset: sortedHits.first.moduleOffset,
      instructionText: sortedHits.first.instructionText,
      hitCount: sortedHits.length,
      threadCount: sortedHits.map((hit) => hit.threadId).toSet().length,
      latestTimestamp: sortedHits.first.timestampMillis,
      hits: sortedHits,
      topTransition: transitions.isEmpty ? null : transitions.first,
    );
  }).toList(growable: false)
    ..sort((left, right) {
      final countCompare = right.hitCount.compareTo(left.hitCount);
      if (countCompare != 0) {
        return countCompare;
      }
      return right.latestTimestamp.compareTo(left.latestTimestamp);
    });
  return groups;
}

List<_WriterTransition> _buildTransitions(List<MemoryBreakpointHit> hits) {
  final grouped = <String, List<MemoryBreakpointHit>>{};
  for (final hit in hits) {
    grouped.putIfAbsent(_formatTransition(hit.oldValue, hit.newValue), () => <MemoryBreakpointHit>[]).add(hit);
  }
  final transitions = grouped.entries.map((entry) {
    final sortedHits = entry.value.toList(growable: false)
      ..sort((left, right) => right.timestampMillis.compareTo(left.timestampMillis));
    return _WriterTransition(
      summary: entry.key,
      count: sortedHits.length,
      latestTimestamp: sortedHits.first.timestampMillis,
    );
  }).toList(growable: false)
    ..sort((left, right) {
      final countCompare = right.count.compareTo(left.count);
      if (countCompare != 0) {
        return countCompare;
      }
      return right.latestTimestamp.compareTo(left.latestTimestamp);
    });
  return transitions;
}

String _buildWriterKey(MemoryBreakpointHit hit) {
  return '${hit.pc}_${hit.moduleName}_${hit.moduleOffset}_${hit.instructionText}';
}

String _formatInstruction(String instruction) {
  return instruction.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _formatTransition(Uint8List oldValue, Uint8List newValue) {
  return '${_formatBytes(oldValue)} -> ${_formatBytes(newValue)}';
}

String _formatBytes(Uint8List bytes) {
  if (bytes.isEmpty) {
    return '--';
  }
  return bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

String _formatTimestamp(int millis) {
  final time = DateTime.fromMillisecondsSinceEpoch(millis);
  final year = time.year.toString().padLeft(4, '0');
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final second = time.second.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute:$second';
}

String _formatModuleOffset(_WriterGroup group) {
  return '${group.moduleName.isEmpty ? '[anonymous]' : group.moduleName}+0x${group.moduleOffset.toRadixString(16).toUpperCase()}';
}

_BreakpointValueInfo? _resolveBreakpointValueInfo({
  required MemoryBreakpoint? breakpoint,
  required MemoryBreakpointHit? hit,
}) {
  if (breakpoint == null) {
    return null;
  }
  final hasHitValue = hit != null;
  final rawBytes = hasHitValue ? hit!.newValue : Uint8List(0);
  final displayValue = hasHitValue
      ? resolveMemoryToolSearchResultValueByType(
          type: breakpoint.type,
          rawBytes: rawBytes,
          fallbackDisplayValue: _formatBytes(rawBytes),
        )
      : '--';
  final preview = MemoryValuePreview(
    address: breakpoint.address,
    type: breakpoint.type,
    rawBytes: rawBytes,
    displayValue: displayValue,
  );
  final result = SearchResult(
    address: breakpoint.address,
    regionStart: breakpoint.address,
    regionTypeKey: 'other',
    type: breakpoint.type,
    rawBytes: rawBytes,
    displayValue: displayValue,
  );
  return _BreakpointValueInfo(
    rawBytes: rawBytes,
    displayValue: displayValue,
    preview: preview,
    result: result,
  );
}

class _BreakpointValueInfo {
  const _BreakpointValueInfo({
    required this.rawBytes,
    required this.displayValue,
    required this.preview,
    required this.result,
  });

  final Uint8List rawBytes;
  final String displayValue;
  final MemoryValuePreview preview;
  final SearchResult result;
}

class _WriterGroup {
  const _WriterGroup({
    required this.key,
    required this.pc,
    required this.moduleName,
    required this.moduleOffset,
    required this.instructionText,
    required this.hitCount,
    required this.threadCount,
    required this.latestTimestamp,
    required this.hits,
    required this.topTransition,
  });

  final String key;
  final int pc;
  final String moduleName;
  final int moduleOffset;
  final String instructionText;
  final int hitCount;
  final int threadCount;
  final int latestTimestamp;
  final List<MemoryBreakpointHit> hits;
  final _WriterTransition? topTransition;
}

class _WriterTransition {
  const _WriterTransition({
    required this.summary,
    required this.count,
    required this.latestTimestamp,
  });

  final String summary;
  final int count;
  final int latestTimestamp;
}
