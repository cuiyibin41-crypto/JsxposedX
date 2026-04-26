import 'dart:async';
import 'dart:typed_data';

import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_entry_kind.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_saved_item.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/debug_tabs/memory_tool_debug_breakpoints_tab.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/debug_tabs/memory_tool_debug_detail_tab.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/debug_tabs/memory_tool_debug_writers_tab.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_breakpoint_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_instruction_history_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_pointer_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_debug_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_export_util.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_debug_instruction_editor_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_debug_primitives.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_pointer_scan_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_stats_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_action_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_settings_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_value_editor_dialog.dart';
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
    useAutomaticKeepAlive();
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final pid = selectedProcess?.pid;
    final selectedBreakpointId = ref.watch(memoryBreakpointSelectedIdProvider);
    final breakpointActionState = ref.watch(memoryBreakpointActionProvider);
    final browseNotifier = ref.read(
      memoryToolBrowseControllerProvider.notifier,
    );
    final pointerNotifier = ref.read(
      memoryToolPointerControllerProvider.notifier,
    );
    final savedItems = ref.watch(savedItemsForSelectedProcessProvider);
    final savedItemsNotifier = ref.read(memoryToolSavedItemsProvider.notifier);
    final selectedWriterKey = useState<String?>(null);
    final selectedHitKey = useState<String?>(null);
    final breakpointEnabledOverrides = useState<Map<String, bool>>(
      <String, bool>{},
    );
    final pendingBreakpointIds = useState<Set<String>>(<String>{});
    final activePointerScanAddress = useState<int?>(null);
    final activeAutoChaseAddress = useState<int?>(null);
    final activeDetailActions =
        useState<List<MemoryToolSearchResultActionItemData>?>(null);
    final isToolConfigVisible = useState(false);
    final activeInstructionEditor =
        useState<_MemoryToolDebugInstructionEditorState?>(null);
    final activeValueEditor = useState<_MemoryToolDebugValueEditorState?>(null);
    final patchedInstructions =
        useState<Map<int, MemoryInstructionPatchResult>>(
          <int, MemoryInstructionPatchResult>{},
        );
    final editedValuePreviews = useState<Map<int, MemoryValuePreview>>(
      <int, MemoryValuePreview>{},
    );
    final pendingInstructionAddresses = useState<Set<int>>(<int>{});
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
    final savedInstructionItems = <int, MemoryToolSavedItem>{
      for (final item in savedItems)
        if (item.isInstruction) item.address: item,
    };

    useEffect(() {
      selectedWriterKey.value = null;
      selectedHitKey.value = null;
      activeInstructionEditor.value = null;
      activeValueEditor.value = null;
      patchedInstructions.value = <int, MemoryInstructionPatchResult>{};
      editedValuePreviews.value = <int, MemoryValuePreview>{};
      pendingInstructionAddresses.value = <int>{};
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
    final rawWriterGroups = buildMemoryToolDebugWriterGroups(hits);
    final effectivePatchedInstructionTexts = <int, String>{
      for (final entry in savedInstructionItems.entries)
        entry.key: entry.value.effectiveInstructionText,
      for (final entry in patchedInstructions.value.entries)
        entry.key: entry.value.instructionText,
    };
    final writerGroups = rawWriterGroups
        .map((group) {
          final override = effectivePatchedInstructionTexts[group.pc];
          if (override == null) {
            return group;
          }
          return MemoryToolDebugWriterGroup(
            key: group.key,
            pc: group.pc,
            moduleName: group.moduleName,
            moduleOffset: group.moduleOffset,
            instructionText: override,
            hitCount: group.hitCount,
            threadCount: group.threadCount,
            latestTimestamp: group.latestTimestamp,
            hits: group.hits,
            topTransition: group.topTransition,
          );
        })
        .toList(growable: false);

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

    useEffect(
      () {
        final nextOverrides = <String, bool>{};
        for (final entry in breakpointEnabledOverrides.value.entries) {
          MemoryBreakpoint? matchedBreakpoint;
          for (final breakpoint in breakpoints) {
            if (breakpoint.id == entry.key) {
              matchedBreakpoint = breakpoint;
              break;
            }
          }
          if (matchedBreakpoint != null &&
              matchedBreakpoint.enabled != entry.value) {
            nextOverrides[entry.key] = entry.value;
          }
        }
        if (nextOverrides.length != breakpointEnabledOverrides.value.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            breakpointEnabledOverrides.value = nextOverrides;
          });
        }

        final nextPending = pendingBreakpointIds.value
            .where((breakpointId) => nextOverrides.containsKey(breakpointId))
            .toSet();
        if (nextPending.length != pendingBreakpointIds.value.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            pendingBreakpointIds.value = nextPending;
          });
        }
        return null;
      },
      [
        breakpoints,
        breakpointEnabledOverrides.value,
        pendingBreakpointIds.value,
      ],
    );

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
    final resolvedValueInfo = resolveMemoryToolDebugBreakpointValueInfo(
      breakpoint: selectedBreakpoint,
      hit: selectedHit,
    );
    final selectedValuePreviewOverride = selectedBreakpoint == null
        ? null
        : editedValuePreviews.value[selectedBreakpoint.address];
    final selectedValueInfo =
        resolvedValueInfo == null || selectedValuePreviewOverride == null
        ? resolvedValueInfo
        : MemoryToolDebugBreakpointValueInfo(
            rawBytes: selectedValuePreviewOverride.rawBytes,
            displayValue: selectedValuePreviewOverride.displayValue,
            preview: selectedValuePreviewOverride,
            result: SearchResult(
              address: selectedValuePreviewOverride.address,
              regionStart: resolvedValueInfo.result.regionStart,
              regionTypeKey: resolvedValueInfo.result.regionTypeKey,
              type: selectedValuePreviewOverride.type,
              rawBytes: selectedValuePreviewOverride.rawBytes,
              displayValue: selectedValuePreviewOverride.displayValue,
            ),
          );
    final selectedHitChangeInfo = buildMemoryToolDebugHitChangeInfo(
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
      ref
          .read(overlayWindowHostRuntimeProvider.notifier)
          .showToast(copied ? context.l10n.codeCopied : context.l10n.error);
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
      savedItemsNotifier.saveEntry(
        pid: pid,
        result: selectedValueInfo.result,
        preview: selectedValueInfo.preview,
        isFrozen: false,
        entryKind: MemoryToolEntryKind.value,
      );
      await ToastOverlayMessage.show(
        context.l10n.memoryToolSavedToSavedMessage(1),
        duration: const Duration(milliseconds: 1200),
      );
    }

    Future<void> exportCurrentDebugContext() async {
      final breakpoint = selectedBreakpoint;
      if (breakpoint == null) {
        return;
      }
      final valueInfo = selectedValueInfo;
      final hit = selectedHit;
      final writerGroup = selectedWriterGroup;
      await exportMemoryToolItemsToLocal(
        context: context,
        ref: ref,
        sourceKey: 'debug',
        pid: pid,
        items: <MemoryToolExportItem>[
          MemoryToolExportItem(
            pid: pid,
            address: breakpoint.address,
            regionStart: valueInfo?.result.regionStart,
            regionTypeKey: valueInfo?.result.regionTypeKey,
            valueType: breakpoint.type,
            displayValue: valueInfo?.displayValue,
            rawBytes: valueInfo?.rawBytes,
            extra: <String, Object?>{
              'breakpoint_id': breakpoint.id,
              'length': breakpoint.length,
              'access_type': formatMemoryToolDebugAccessType(
                context.l10n,
                breakpoint.accessType,
              ),
              'enabled': breakpoint.enabled,
              'pause_process_on_hit': breakpoint.pauseProcessOnHit,
              'hit_count': breakpoint.hitCount,
              'selected_writer_pc': writerGroup == null
                  ? null
                  : formatMemoryToolSearchResultAddress(writerGroup.pc),
              'selected_writer_instruction': writerGroup?.instructionText,
              'selected_writer_transition': writerGroup?.topTransition?.summary,
              'selected_hit_thread_id': hit?.threadId,
              'selected_hit_timestamp': hit == null
                  ? null
                  : formatMemoryToolDebugTimestamp(hit.timestampMillis),
              'selected_hit_pc': hit == null
                  ? null
                  : formatMemoryToolSearchResultAddress(hit.pc),
              'selected_hit_change': selectedHitChangeInfo?.displayText,
            },
          ),
        ],
        meta: <String, Object?>{
          'is_process_paused': state?.isProcessPaused,
          'active_breakpoint_count': state?.activeBreakpointCount,
          'pending_hit_count': state?.pendingHitCount,
          'architecture': state?.architecture,
          'selected_breakpoint_hit_count': hits.length,
          'writer_group_count': writerGroups.length,
        },
      );
    }

    Future<void> storeEditedValuePreview({
      required int address,
      required SearchValueType type,
      required int sourceLength,
      required String fallbackDisplayValue,
    }) async {
      final previews = await ref
          .read(memoryQueryRepositoryProvider)
          .readMemoryValues(
            requests: <MemoryReadRequest>[
              MemoryReadRequest(
                pid: pid,
                address: address,
                type: type,
                length: resolveMemoryToolReadLengthForType(
                  type: type,
                  bytesLength: sourceLength,
                ),
              ),
            ],
          );
      final updatedPreview = previews.isNotEmpty
          ? previews.first
          : MemoryValuePreview(
              address: address,
              type: type,
              rawBytes: Uint8List(sourceLength),
              displayValue: fallbackDisplayValue,
            );
      editedValuePreviews.value = <int, MemoryValuePreview>{
        ...editedValuePreviews.value,
        address: updatedPreview,
      };
    }

    void openDetailActions(List<MemoryToolSearchResultActionItemData> actions) {
      if (actions.isEmpty) {
        return;
      }
      activeDetailActions.value = actions;
    }

    List<MemoryToolSearchResultActionItemData> buildCurrentValueActions() {
      if (selectedValueInfo == null ||
          selectedHit == null ||
          selectedBreakpoint == null) {
        return const <MemoryToolSearchResultActionItemData>[];
      }
      final valueInfo = selectedValueInfo;
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
        MemoryToolSearchResultActionItemData(
          icon: Icons.edit_outlined,
          title: context.isZh ? '修改当前值' : 'Edit Current Value',
          onTap: () async {
            activeDetailActions.value = null;
            activeValueEditor.value = _MemoryToolDebugValueEditorState(
              address: breakpoint.address,
              type: breakpoint.type,
              preview: valueInfo.preview,
              regionTypeKey: valueInfo.result.regionTypeKey,
            );
          },
        ),
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
            await copyText(formatMemoryToolSearchResultHex(valueInfo.rawBytes));
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
            await copyText(formatMemoryToolSearchResultAddress(writerGroup.pc));
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

    List<MemoryToolSearchResultActionItemData> buildInstructionActions({
      required int address,
      required String currentValue,
    }) {
      final trimmedCurrent = currentValue.trim();
      final savedPatch = savedInstructionItems[address];
      return <MemoryToolSearchResultActionItemData>[
        if (trimmedCurrent.isNotEmpty)
          MemoryToolSearchResultActionItemData(
            icon: Icons.copy_all_rounded,
            title:
                '${context.isZh ? '复制指令' : 'Copy Instruction'}: $trimmedCurrent',
            onTap: () async {
              await copyText(trimmedCurrent);
              activeDetailActions.value = null;
            },
          ),
        if (trimmedCurrent.isNotEmpty)
          MemoryToolSearchResultActionItemData(
            icon: Icons.save_alt_rounded,
            title: savedPatch == null
                ? context.l10n.memoryToolResultActionSaveToSaved
                : (context.isZh ? '更新暂存区' : 'Update Saved Patch'),
            onTap: () async {
              SearchResult savedResult;
              try {
                final previews = await ref
                    .read(memoryQueryRepositoryProvider)
                    .disassembleMemory(pid: pid, addresses: <int>[address]);
                final preview = previews.isEmpty ? null : previews.first;
                savedResult = SearchResult(
                  address: address,
                  regionStart: savedPatch?.regionStart ?? address,
                  regionTypeKey: savedPatch?.regionTypeKey ?? 'other',
                  type: SearchValueType.bytes,
                  rawBytes: preview?.rawBytes ?? Uint8List(0),
                  displayValue: preview?.instructionText ?? trimmedCurrent,
                );
              } catch (_) {
                savedResult = SearchResult(
                  address: address,
                  regionStart: savedPatch?.regionStart ?? address,
                  regionTypeKey: savedPatch?.regionTypeKey ?? 'other',
                  type: SearchValueType.bytes,
                  rawBytes: Uint8List(0),
                  displayValue: trimmedCurrent,
                );
              }
              savedItemsNotifier.saveEntry(
                pid: pid,
                result: savedResult,
                isFrozen: false,
                entryKind: MemoryToolEntryKind.instruction,
                instructionText: trimmedCurrent,
              );
              activeDetailActions.value = null;
              await ToastOverlayMessage.show(
                context.isZh ? '指令修改已保存到暂存区' : 'Instruction patch saved',
                duration: const Duration(milliseconds: 1200),
              );
            },
          ),
        if (savedPatch != null)
          MemoryToolSearchResultActionItemData(
            icon: Icons.remove_circle_outline_rounded,
            title: context.isZh ? '从暂存区移除' : 'Remove from Saved',
            onTap: () async {
              savedItemsNotifier.removeOne(pid: pid, address: address);
              ref
                  .read(memoryToolInstructionHistoryProvider.notifier)
                  .remove(pid: pid, address: address);
              activeDetailActions.value = null;
              await ToastOverlayMessage.show(
                context.isZh ? '已从暂存区移除' : 'Removed from saved patches',
                duration: const Duration(milliseconds: 1200),
              );
            },
          ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.preview_rounded,
          title: context.l10n.memoryToolDebugActionBrowseAddress,
          onTap: () async {
            activeDetailActions.value = null;
            await previewRawAddress(
              targetAddress: address,
              type: SearchValueType.bytes,
              bytesLength: 4,
            );
          },
        ),
        MemoryToolSearchResultActionItemData(
          icon: Icons.edit_outlined,
          title: context.isZh ? '编辑指令' : 'Edit Instruction',
          onTap: () async {
            activeDetailActions.value = null;
            activeInstructionEditor.value =
                _MemoryToolDebugInstructionEditorState(
                  address: address,
                  currentValue: currentValue,
                );
          },
        ),
      ];
    }

    List<MemoryToolSearchResultActionItemData> buildHitChangeActions() {
      if (selectedHitChangeInfo == null) {
        return const <MemoryToolSearchResultActionItemData>[];
      }
      return <MemoryToolSearchResultActionItemData>[
        MemoryToolSearchResultActionItemData(
          icon: Icons.copy_all_rounded,
          title: context.isZh ? '复制命中变化' : 'Copy Hit Changes',
          onTap: () async {
            await copyText(selectedHitChangeInfo.displayText);
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
          title:
              '${context.l10n.memoryToolDebugActionCopyValue}: $displayValue',
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

    Future<String?> saveInstructionEdit({
      required _MemoryToolDebugInstructionEditorState editor,
      required String value,
    }) async {
      final failurePrefix = context.isZh ? '修改失败' : 'Patch failed';
      final fallbackErrorMessage = context.l10n.error;
      final targetAddress = editor.address;
      final breakpointToDisable = selectedBreakpoint;
      final didDisableBreakpoint = breakpointToDisable?.enabled ?? false;
      final successMessage = context.isZh
          ? (didDisableBreakpoint ? '指令已修改，当前断点已停用' : '指令已修改')
          : (didDisableBreakpoint
                ? 'Instruction patched, breakpoint disabled'
                : 'Instruction patched');
      pendingInstructionAddresses.value = <int>{
        ...pendingInstructionAddresses.value,
        targetAddress,
      };
      try {
        final result = await ref
            .read(memoryValueActionProvider.notifier)
            .patchMemoryInstruction(
              request: MemoryInstructionPatchRequest(
                pid: pid,
                address: targetAddress,
                instruction: value,
              ),
            );
        patchedInstructions.value = <int, MemoryInstructionPatchResult>{
          ...patchedInstructions.value,
          targetAddress: result,
        };
        ref
            .read(memoryToolInstructionHistoryProvider.notifier)
            .record(
              pid: pid,
              address: targetAddress,
              previousBytes: result.beforeBytes,
              previousDisplayValue: editor.currentValue,
            );
        activeInstructionEditor.value = null;
        final nextPending = <int>{...pendingInstructionAddresses.value};
        nextPending.remove(targetAddress);
        pendingInstructionAddresses.value = nextPending;
        unawaited(refreshAll());

        try {
          if (breakpointToDisable != null && breakpointToDisable.enabled) {
            breakpointEnabledOverrides.value = <String, bool>{
              ...breakpointEnabledOverrides.value,
              breakpointToDisable.id: false,
            };
            pendingBreakpointIds.value = <String>{
              ...pendingBreakpointIds.value,
              breakpointToDisable.id,
            };
            try {
              await ref
                  .read(memoryBreakpointActionProvider.notifier)
                  .setMemoryBreakpointEnabled(
                    pid: pid,
                    breakpointId: breakpointToDisable.id,
                    enabled: false,
                  );
            } catch (_) {
              final nextOverrides = <String, bool>{
                ...breakpointEnabledOverrides.value,
              };
              nextOverrides.remove(breakpointToDisable.id);
              breakpointEnabledOverrides.value = nextOverrides;
              final nextPendingBreakpointIds = <String>{
                ...pendingBreakpointIds.value,
              };
              nextPendingBreakpointIds.remove(breakpointToDisable.id);
              pendingBreakpointIds.value = nextPendingBreakpointIds;
              rethrow;
            }
          }

          unawaited(
            ToastOverlayMessage.show(
              successMessage,
              duration: const Duration(milliseconds: 1200),
            ),
          );
        } catch (error) {
          final message = error
              .toString()
              .replaceFirst('Exception: ', '')
              .trim();
          final resolvedMessage = message.isEmpty
              ? fallbackErrorMessage
              : message;
          unawaited(
            ToastOverlayMessage.show(
              '$failurePrefix: $resolvedMessage',
              duration: const Duration(milliseconds: 1600),
            ),
          );
        }
        return null;
      } catch (error) {
        final message = error.toString().replaceFirst('Exception: ', '').trim();
        final resolvedMessage = message.isEmpty
            ? fallbackErrorMessage
            : message;
        unawaited(
          ToastOverlayMessage.show(
            '$failurePrefix: $resolvedMessage',
            duration: const Duration(milliseconds: 1600),
          ),
        );
        return resolvedMessage;
      } finally {
        final nextPending = <int>{...pendingInstructionAddresses.value};
        nextPending.remove(targetAddress);
        pendingInstructionAddresses.value = nextPending;
      }
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
            final isInstructionPatching =
                selectedWriterGroup != null &&
                pendingInstructionAddresses.value.contains(
                  selectedWriterGroup.pc,
                );

            final breakpointTab = MemoryToolDebugBreakpointsTab(
              breakpointsAsync: breakpointsAsync,
              selectedBreakpointId: selectedBreakpoint?.id,
              breakpointEnabledOverrides: breakpointEnabledOverrides.value,
              pendingBreakpointIds: pendingBreakpointIds.value,
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
              onToggleEnabled: (breakpoint, enabled) async {
                breakpointEnabledOverrides.value = <String, bool>{
                  ...breakpointEnabledOverrides.value,
                  breakpoint.id: enabled,
                };
                pendingBreakpointIds.value = <String>{
                  ...pendingBreakpointIds.value,
                  breakpoint.id,
                };
                try {
                  await ref
                      .read(memoryBreakpointActionProvider.notifier)
                      .setMemoryBreakpointEnabled(
                        pid: pid,
                        breakpointId: breakpoint.id,
                        enabled: enabled,
                      );
                } catch (_) {
                  final nextOverrides = <String, bool>{
                    ...breakpointEnabledOverrides.value,
                  };
                  nextOverrides.remove(breakpoint.id);
                  breakpointEnabledOverrides.value = nextOverrides;
                  final nextPending = <String>{...pendingBreakpointIds.value};
                  nextPending.remove(breakpoint.id);
                  pendingBreakpointIds.value = nextPending;
                  rethrow;
                }
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
              hitChangeInfo: selectedHitChangeInfo,
              isInstructionPatching: isInstructionPatching,
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
              onEditInstruction:
                  selectedWriterGroup == null || isInstructionPatching
                  ? null
                  : () {
                      activeInstructionEditor.value =
                          _MemoryToolDebugInstructionEditorState(
                            address: selectedWriterGroup.pc,
                            currentValue: selectedInstructionText,
                          );
                    },
              onOpenInstructionActions:
                  selectedInstructionText.isEmpty || isInstructionPatching
                  ? null
                  : () {
                      openDetailActions(
                        buildInstructionActions(
                          address: selectedWriterGroup!.pc,
                          currentValue: selectedInstructionText,
                        ),
                      );
                    },
              onOpenHitChangeActions: selectedHitChangeInfo == null
                  ? null
                  : () {
                      openDetailActions(buildHitChangeActions());
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
                    groups: <MemoryToolResultSelectionActionGroupData>[
                      MemoryToolResultSelectionActionGroupData(
                        icon: Icons.bug_report_rounded,
                        label: context.isZh ? '断点控制' : 'Breakpoint Control',
                        actions: <MemoryToolResultSelectionActionData>[
                          MemoryToolResultSelectionActionData(
                            icon: Icons.refresh_rounded,
                            label: context.isZh ? '刷新' : 'Refresh',
                            onTap: breakpointActionState.isLoading
                                ? null
                                : refreshAll,
                          ),
                          MemoryToolResultSelectionActionData(
                            icon: Icons.play_arrow_rounded,
                            label: context.isZh
                                ? '断点后继续'
                                : 'Resume After Breakpoint',
                            onTap: breakpointActionState.isLoading || !isPaused
                                ? null
                                : () async {
                                    await ref
                                        .read(
                                          memoryBreakpointActionProvider
                                              .notifier,
                                        )
                                        .resumeAfterBreakpoint(pid: pid);
                                  },
                          ),
                          MemoryToolResultSelectionActionData(
                            icon: Icons.layers_clear_rounded,
                            label: context.isZh ? '清空命中' : 'Clear Hits',
                            onTap: breakpointActionState.isLoading
                                ? null
                                : () async {
                                    await ref
                                        .read(
                                          memoryBreakpointActionProvider
                                              .notifier,
                                        )
                                        .clearMemoryBreakpointHits(pid: pid);
                                  },
                          ),
                        ],
                      ),
                      MemoryToolResultSelectionActionGroupData(
                        icon: Icons.ios_share_rounded,
                        label: context.isZh ? '导出' : 'Export',
                        actions: <MemoryToolResultSelectionActionData>[
                          MemoryToolResultSelectionActionData(
                            icon: Icons.outbox_rounded,
                            label: context.isZh ? '导出上下文' : 'Export Context',
                            onTap: selectedBreakpoint == null
                                ? null
                                : () async {
                                    await exportCurrentDebugContext();
                                  },
                          ),
                        ],
                      ),
                      MemoryToolResultSelectionActionGroupData(
                        icon: Icons.tune_rounded,
                        label: context.isZh ? '设置' : 'Settings',
                        actions: <MemoryToolResultSelectionActionData>[
                          MemoryToolResultSelectionActionData(
                            icon: Icons.settings_rounded,
                            label: context.isZh ? '配置' : 'Config',
                            onTap: () {
                              isToolConfigVisible.value = true;
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: outerSpacing),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.colorScheme.surface.withValues(
                          alpha: 0.84,
                        ),
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
        if (isToolConfigVisible.value)
          Positioned.fill(
            child: MemoryToolSettingsDialog(
              onClose: () {
                isToolConfigVisible.value = false;
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
        if (activeInstructionEditor.value case final editor?)
          Positioned.fill(
            child: MemoryToolDebugInstructionEditorDialog(
              initialValue: editor.currentValue,
              onSave: (value) async {
                return await saveInstructionEdit(editor: editor, value: value);
              },
              onClose: () {
                activeInstructionEditor.value = null;
              },
            ),
          ),
        if (activeValueEditor.value case final editor?)
          Positioned.fill(
            child: _MemoryToolDebugValueEditorDialog(
              editor: editor,
              onSaved: (preview) {
                editedValuePreviews.value = <int, MemoryValuePreview>{
                  ...editedValuePreviews.value,
                  preview.address: preview,
                };
              },
              onStoreEditedValuePreview:
                  ({
                    required int address,
                    required SearchValueType type,
                    required int sourceLength,
                    required String fallbackDisplayValue,
                  }) async {
                    await storeEditedValuePreview(
                      address: address,
                      type: type,
                      sourceLength: sourceLength,
                      fallbackDisplayValue: fallbackDisplayValue,
                    );
                  },
              onClose: () {
                activeValueEditor.value = null;
              },
            ),
          ),
      ],
    );
  }
}

class _MemoryToolDebugInstructionEditorState {
  const _MemoryToolDebugInstructionEditorState({
    required this.address,
    required this.currentValue,
  });

  final int address;
  final String currentValue;
}

class _MemoryToolDebugValueEditorState {
  const _MemoryToolDebugValueEditorState({
    required this.address,
    required this.type,
    required this.preview,
    required this.regionTypeKey,
  });

  final int address;
  final SearchValueType type;
  final MemoryValuePreview preview;
  final String regionTypeKey;
}

class _MemoryToolDebugValueEditorDialog extends HookConsumerWidget {
  const _MemoryToolDebugValueEditorDialog({
    required this.editor,
    required this.onSaved,
    required this.onStoreEditedValuePreview,
    required this.onClose,
  });

  final _MemoryToolDebugValueEditorState editor;
  final ValueChanged<MemoryValuePreview> onSaved;
  final Future<void> Function({
    required int address,
    required SearchValueType type,
    required int sourceLength,
    required String fallbackDisplayValue,
  })
  onStoreEditedValuePreview;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = useState(editor.type);
    final valueController = useTextEditingController(
      text: editor.preview.displayValue,
    );
    useListenable(valueController);
    final valueActionState = ref.watch(memoryValueActionProvider);

    Future<void> handleSave() async {
      try {
        var littleEndian = true;
        try {
          final searchSessionState = await ref.read(
            getSearchSessionStateProvider.future,
          );
          littleEndian = searchSessionState.littleEndian;
        } catch (_) {}

        final inputValue = valueController.text.trim();
        final writeValue = buildMemoryToolWriteValue(
          type: selectedType.value,
          input: inputValue,
          littleEndian: littleEndian,
          sourceType: editor.preview.type,
          sourceRawBytes: editor.preview.rawBytes,
          sourceDisplayValue: editor.preview.displayValue,
        );

        await ref
            .read(memoryValueActionProvider.notifier)
            .writeMemoryValue(
              request: MemoryWriteRequest(
                address: editor.address,
                value: writeValue,
              ),
              previousPreview: editor.preview,
            );

        await onStoreEditedValuePreview(
          address: editor.address,
          type: selectedType.value,
          sourceLength: editor.preview.rawBytes.length,
          fallbackDisplayValue: inputValue,
        );

        final selectedPid = ref.read(memoryToolSelectedProcessProvider)?.pid;
        if (selectedPid != null) {
          final updatedPreviews = await ref
              .read(memoryQueryRepositoryProvider)
              .readMemoryValues(
                requests: <MemoryReadRequest>[
                  MemoryReadRequest(
                    pid: selectedPid,
                    address: editor.address,
                    type: selectedType.value,
                    length: resolveMemoryToolReadLengthForType(
                      type: selectedType.value,
                      bytesLength: editor.preview.rawBytes.length,
                    ),
                  ),
                ],
              );
          if (updatedPreviews.isNotEmpty) {
            onSaved(updatedPreviews.first);
          }
        }

        if (!context.mounted) {
          return;
        }
        onClose();
      } catch (_) {
        return;
      }
    }

    return MemoryToolValueEditorDialog(
      title: context.isZh ? '修改当前值' : 'Edit Current Value',
      subtitle: formatMemoryToolSearchResultAddress(editor.address),
      selectedTypeLabel: mapMemoryToolSearchResultTypeLabel(
        type: selectedType.value,
        displayValue: selectedType.value == SearchValueType.bytes
            ? editor.preview.displayValue
            : '',
      ),
      typeLabelBuilder: (type) {
        return mapMemoryToolSearchResultTypeLabel(
          type: type,
          displayValue: type == SearchValueType.bytes
              ? editor.preview.displayValue
              : '',
        );
      },
      onSelectedType: (type) {
        selectedType.value = type;
      },
      valueController: valueController,
      metadata: <MemoryToolValueEditorMeta>[
        MemoryToolValueEditorMeta(
          label: context.l10n.memoryToolResultAddress,
          value: formatMemoryToolSearchResultAddress(editor.address),
        ),
        MemoryToolValueEditorMeta(
          label: context.l10n.memoryToolResultType,
          value: mapMemoryToolSearchResultTypeLabel(
            type: selectedType.value,
            displayValue: selectedType.value == SearchValueType.bytes
                ? editor.preview.displayValue
                : '',
          ),
        ),
        MemoryToolValueEditorMeta(
          label: context.l10n.memoryToolResultRegion,
          value: mapMemoryToolSearchResultRegionTypeLabel(
            context,
            editor.regionTypeKey,
          ),
        ),
      ],
      errorText: valueActionState.error?.toString(),
      canSave:
          valueController.text.trim().isNotEmpty && !valueActionState.isLoading,
      onSave: handleSave,
      onClose: onClose,
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
            children: <Widget>[breakpointTab, writersTab, detailTab],
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
            color: context.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.34,
            ),
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
            children: <Widget>[writersTab, detailTab],
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
