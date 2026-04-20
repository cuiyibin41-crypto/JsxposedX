import 'package:JsxposedX/features/memory_tool_overlay/domain/memory_ai_overlay_environment_adapter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_auto_chase_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_auto_chase_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_instruction_history_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_ai_overlay_environment_provider.g.dart';

class MemoryAiOverlayEnvironmentArgs {
  const MemoryAiOverlayEnvironmentArgs({
    required this.processInfo,
    required this.isZh,
  });

  final ProcessInfo processInfo;
  final bool isZh;

  @override
  bool operator ==(Object other) {
    return other is MemoryAiOverlayEnvironmentArgs &&
        other.processInfo == processInfo &&
        other.isZh == isZh;
  }

  @override
  int get hashCode => Object.hash(processInfo, isZh);
}

@riverpod
MemoryAiOverlayEnvironmentAdapter memoryAiOverlayEnvironment(
  Ref ref,
  MemoryAiOverlayEnvironmentArgs args,
) {
  return MemoryAiOverlayEnvironmentAdapter(
    processInfo: args.processInfo,
    isZh: args.isZh,
    memoryQueryRepository: ref.watch(memoryQueryRepositoryProvider),
    memoryActionRepository: ref.watch(memoryActionRepositoryProvider),
    memoryPointerQueryRepository: ref.watch(memoryPointerQueryRepositoryProvider),
    memoryPointerActionRepository: ref.watch(
      memoryPointerActionRepositoryProvider,
    ),
    memoryPointerAutoChaseQueryRepository: ref.watch(
      memoryPointerAutoChaseQueryRepositoryProvider,
    ),
    memoryPointerAutoChaseActionRepository: ref.watch(
      memoryPointerAutoChaseActionRepositoryProvider,
    ),
    listSavedItems: () {
      final itemsByAddress = ref
          .read(memoryToolSavedItemsProvider)
          .itemsByPid[args.processInfo.pid];
      if (itemsByAddress == null || itemsByAddress.isEmpty) {
        return const [];
      }
      final items = itemsByAddress.values.toList(growable: false)
        ..sort((left, right) => left.address.compareTo(right.address));
      return items;
    },
    saveSavedItem: ({
      required pid,
      required result,
      preview,
      required isFrozen,
      isInstructionPatch = false,
      instructionText,
    }) {
      ref
          .read(memoryToolSavedItemsProvider.notifier)
          .saveOne(
            pid: pid,
            result: result,
            preview: preview,
            isFrozen: isFrozen,
            isInstructionPatch: isInstructionPatch,
            instructionText: instructionText,
          );
    },
    saveSavedItems: ({
      required pid,
      required results,
      previewsByAddress = const <int, MemoryValuePreview>{},
      frozenAddresses = const <int>{},
    }) {
      ref
          .read(memoryToolSavedItemsProvider.notifier)
          .saveMany(
            pid: pid,
            results: results,
            previewsByAddress: previewsByAddress,
            frozenAddresses: frozenAddresses,
          );
    },
    removeSavedItems: ({required pid, required addresses}) {
      ref
          .read(memoryToolSavedItemsProvider.notifier)
          .removeSelected(pid: pid, addresses: addresses);
    },
    clearSavedItems: (pid) {
      ref.read(memoryToolSavedItemsProvider.notifier).clearProcess(pid);
    },
    listValueHistoryEntries: () {
      return ref.read(memoryValueHistoryProvider);
    },
    listInstructionHistoryEntries: () {
      return ref
              .read(memoryToolInstructionHistoryProvider)
              .entriesByPid[args.processInfo.pid] ??
          const <int, MemoryToolInstructionHistoryEntry>{};
    },
    writeMemoryValueAction: ({required request, previousPreview}) {
      return ref
          .read(memoryValueActionProvider.notifier)
          .writeMemoryValue(
            request: request,
            previousPreview: previousPreview,
          );
    },
    writeMemoryValuesAction: ({
      required requests,
      required previousPreviews,
    }) {
      return ref
          .read(memoryValueActionProvider.notifier)
          .writeMemoryValues(
            requests: requests,
            previousPreviews: previousPreviews,
          );
    },
    patchMemoryInstructionAction: ({required request}) {
      return ref
          .read(memoryValueActionProvider.notifier)
          .patchMemoryInstruction(request: request);
    },
    setMemoryFreezeAction: ({required request}) {
      return ref
          .read(memoryValueActionProvider.notifier)
          .setMemoryFreeze(request: request);
    },
    setMemoryFreezesAction: ({required requests}) {
      return ref
          .read(memoryValueActionProvider.notifier)
          .setMemoryFreezes(requests: requests);
    },
    restorePreviousValuesAction: ({required addresses, required littleEndian}) {
      return ref
          .read(memoryValueActionProvider.notifier)
          .restorePreviousValues(
            addresses: addresses,
            littleEndian: littleEndian,
          );
    },
    recordInstructionHistory: ({
      required pid,
      required address,
      required previousBytes,
      required previousDisplayValue,
    }) {
      ref
          .read(memoryToolInstructionHistoryProvider.notifier)
          .record(
            pid: pid,
            address: address,
            previousBytes: previousBytes,
            previousDisplayValue: previousDisplayValue,
          );
    },
  );
}
