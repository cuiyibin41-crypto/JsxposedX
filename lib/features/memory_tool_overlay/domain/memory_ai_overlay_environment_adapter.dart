import 'dart:typed_data';

import 'package:JsxposedX/features/ai/domain/contracts/ai_chat_environment_adapter.dart';
import 'package:JsxposedX/features/ai/domain/models/ai_chat_environment_snapshot.dart';
import 'package:JsxposedX/features/ai/domain/services/tool_executor.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/memory_ai_overlay_chat_tools_spec.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/memory_ai_overlay_prompt_builder.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/memory_ai_overlay_tool_handlers.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_action_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_pointer_action_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_pointer_auto_chase_action_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_pointer_auto_chase_query_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_pointer_query_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_query_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_saved_item.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_instruction_history_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_value_history_state.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';

class MemoryAiOverlayEnvironmentAdapter implements AiChatEnvironmentAdapter {
  const MemoryAiOverlayEnvironmentAdapter({
    required this.processInfo,
    required this.isZh,
    required MemoryQueryRepository memoryQueryRepository,
    required MemoryActionRepository memoryActionRepository,
    required MemoryPointerQueryRepository memoryPointerQueryRepository,
    required MemoryPointerActionRepository memoryPointerActionRepository,
    required MemoryPointerAutoChaseQueryRepository
    memoryPointerAutoChaseQueryRepository,
    required MemoryPointerAutoChaseActionRepository
    memoryPointerAutoChaseActionRepository,
    required this.listSavedItems,
    required this.saveSavedItem,
    required this.saveSavedItems,
    required this.removeSavedItems,
    required this.clearSavedItems,
    required this.listValueHistoryEntries,
    required this.listInstructionHistoryEntries,
    required this.writeMemoryValueAction,
    required this.writeMemoryValuesAction,
    required this.patchMemoryInstructionAction,
    required this.setMemoryFreezeAction,
    required this.setMemoryFreezesAction,
    required this.restorePreviousValuesAction,
    required this.recordInstructionHistory,
  }) : _memoryQueryRepository = memoryQueryRepository,
       _memoryActionRepository = memoryActionRepository,
       _memoryPointerQueryRepository = memoryPointerQueryRepository,
       _memoryPointerActionRepository = memoryPointerActionRepository,
       _memoryPointerAutoChaseQueryRepository =
           memoryPointerAutoChaseQueryRepository,
       _memoryPointerAutoChaseActionRepository =
           memoryPointerAutoChaseActionRepository;

  final ProcessInfo processInfo;
  final bool isZh;
  final MemoryQueryRepository _memoryQueryRepository;
  final MemoryActionRepository _memoryActionRepository;
  final MemoryPointerQueryRepository _memoryPointerQueryRepository;
  final MemoryPointerActionRepository _memoryPointerActionRepository;
  final MemoryPointerAutoChaseQueryRepository
  _memoryPointerAutoChaseQueryRepository;
  final MemoryPointerAutoChaseActionRepository
  _memoryPointerAutoChaseActionRepository;
  final List<MemoryToolSavedItem> Function() listSavedItems;
  final void Function({
    required int pid,
    required SearchResult result,
    MemoryValuePreview? preview,
    required bool isFrozen,
    bool isInstructionPatch,
    String? instructionText,
  })
  saveSavedItem;
  final void Function({
    required int pid,
    required List<SearchResult> results,
    Map<int, MemoryValuePreview> previewsByAddress,
    Set<int> frozenAddresses,
  })
  saveSavedItems;
  final void Function({
    required int pid,
    required Iterable<int> addresses,
  })
  removeSavedItems;
  final void Function(int pid) clearSavedItems;
  final Map<int, MemoryToolValueHistoryEntryState> Function()
  listValueHistoryEntries;
  final Map<int, MemoryToolInstructionHistoryEntry> Function()
  listInstructionHistoryEntries;
  final Future<void> Function({
    required MemoryWriteRequest request,
    MemoryValuePreview? previousPreview,
  })
  writeMemoryValueAction;
  final Future<void> Function({
    required List<MemoryWriteRequest> requests,
    required List<MemoryValuePreview> previousPreviews,
  })
  writeMemoryValuesAction;
  final Future<MemoryInstructionPatchResult> Function({
    required MemoryInstructionPatchRequest request,
  })
  patchMemoryInstructionAction;
  final Future<void> Function({
    required MemoryFreezeRequest request,
  })
  setMemoryFreezeAction;
  final Future<void> Function({
    required List<MemoryFreezeRequest> requests,
  })
  setMemoryFreezesAction;
  final Future<int> Function({
    required List<int> addresses,
    required bool littleEndian,
  })
  restorePreviousValuesAction;
  final void Function({
    required int pid,
    required int address,
    required Uint8List previousBytes,
    required String previousDisplayValue,
  })
  recordInstructionHistory;

  @override
  String get scopeId =>
      'memory_overlay_${processInfo.packageName}_${processInfo.pid}';

  @override
  String get environmentVersion =>
      'memory_overlay:${isZh ? "zh" : "en"}:${MemoryAiOverlayPromptBuilder.promptVersion}:${MemoryAiOverlayChatToolsSpec.catalogVersion}';

  @override
  Future<AiChatEnvironmentSnapshot> initialize() async {
    final runtimeSummary = await _buildRuntimeSummary();
    final systemPrompt = MemoryAiOverlayPromptBuilder(isZh: isZh)
        .withProcessInfo(processInfo)
        .withRuntimeSummary(runtimeSummary)
        .withTools()
        .buildSystemPrompt();

    final toolContext = MemoryAiOverlayToolRuntimeContext(
      processInfo: processInfo,
      isZh: isZh,
      memoryQueryRepository: _memoryQueryRepository,
      memoryActionRepository: _memoryActionRepository,
      memoryPointerQueryRepository: _memoryPointerQueryRepository,
      memoryPointerActionRepository: _memoryPointerActionRepository,
      memoryPointerAutoChaseQueryRepository:
          _memoryPointerAutoChaseQueryRepository,
      memoryPointerAutoChaseActionRepository:
          _memoryPointerAutoChaseActionRepository,
      listSavedItems: listSavedItems,
      saveSavedItem: saveSavedItem,
      saveSavedItems: saveSavedItems,
      removeSavedItems: removeSavedItems,
      clearSavedItems: clearSavedItems,
      listValueHistoryEntries: listValueHistoryEntries,
      listInstructionHistoryEntries: listInstructionHistoryEntries,
      writeMemoryValueAction: writeMemoryValueAction,
      writeMemoryValuesAction: writeMemoryValuesAction,
      patchMemoryInstructionAction: patchMemoryInstructionAction,
      setMemoryFreezeAction: setMemoryFreezeAction,
      setMemoryFreezesAction: setMemoryFreezesAction,
      restorePreviousValuesAction: restorePreviousValuesAction,
      recordInstructionHistory: recordInstructionHistory,
    );

    return AiChatEnvironmentSnapshot.ready(
      scopeId: scopeId,
      environmentVersion: environmentVersion,
      systemPrompt: systemPrompt,
      toolsSpec: MemoryAiOverlayChatToolsSpec(),
      toolExecutor: ToolExecutor(
        handlers: buildMemoryAiOverlayToolHandlers(context: toolContext),
      ),
    );
  }

  Future<String> _buildRuntimeSummary() async {
    final lines = <String>[];

    try {
      final paused = await _memoryActionRepository.isProcessPaused(
        pid: processInfo.pid,
      );
      lines.add(isZh ? '当前暂停状态: ${paused ? "已暂停" : "运行中"}' : 'Paused: $paused');
    } catch (error) {
      lines.add(isZh ? '暂停状态读取失败: $error' : 'Pause state failed: $error');
    }

    try {
      final frozenValues = await _memoryActionRepository.getFrozenMemoryValues();
      final frozenCount = frozenValues
          .where((value) => value.pid == processInfo.pid)
          .length;
      lines.add(isZh ? '冻结值数量: $frozenCount' : 'Frozen values: $frozenCount');
    } catch (error) {
      lines.add(isZh ? '冻结值读取失败: $error' : 'Frozen values failed: $error');
    }

    try {
      final session = await _memoryQueryRepository.getSearchSessionState();
      if (session.hasActiveSession) {
        lines.add(
          isZh
              ? '搜索会话: pid=${session.pid}, resultCount=${session.resultCount}, littleEndian=${session.littleEndian}'
              : 'Search session: pid=${session.pid}, resultCount=${session.resultCount}, littleEndian=${session.littleEndian}',
        );
      } else {
        lines.add(isZh ? '搜索会话: 无活动会话' : 'Search session: none');
      }
    } catch (error) {
      lines.add(isZh ? '搜索会话读取失败: $error' : 'Search session failed: $error');
    }

    try {
      final breakpointState = await _memoryQueryRepository.getMemoryBreakpointState(
        pid: processInfo.pid,
      );
      lines.add(
        isZh
            ? '断点状态: active=${breakpointState.activeBreakpointCount}, pendingHits=${breakpointState.pendingHitCount}, arch=${breakpointState.architecture}'
            : 'Breakpoints: active=${breakpointState.activeBreakpointCount}, pendingHits=${breakpointState.pendingHitCount}, arch=${breakpointState.architecture}',
      );
    } catch (error) {
      lines.add(isZh ? '断点状态读取失败: $error' : 'Breakpoint state failed: $error');
    }

    try {
      final pointerSession = await _memoryPointerQueryRepository
          .getPointerScanSessionState();
      if (pointerSession.hasActiveSession) {
        lines.add(
          isZh
              ? '指针扫描: pid=${pointerSession.pid}, target=${pointerSession.targetAddress}, resultCount=${pointerSession.resultCount}'
              : 'Pointer scan: pid=${pointerSession.pid}, target=${pointerSession.targetAddress}, resultCount=${pointerSession.resultCount}',
        );
      } else {
        lines.add(isZh ? '指针扫描: 无活动会话' : 'Pointer scan: none');
      }
    } catch (error) {
      lines.add(isZh ? '指针扫描读取失败: $error' : 'Pointer scan failed: $error');
    }

    try {
      final autoChase = await _memoryPointerAutoChaseQueryRepository
          .getPointerAutoChaseState();
      lines.add(
        isZh
            ? '自动追链: running=${autoChase.isRunning}, depth=${autoChase.currentDepth}/${autoChase.maxDepth}, layers=${autoChase.layers.length}'
            : 'Auto chase: running=${autoChase.isRunning}, depth=${autoChase.currentDepth}/${autoChase.maxDepth}, layers=${autoChase.layers.length}',
      );
    } catch (error) {
      lines.add(isZh ? '自动追链读取失败: $error' : 'Auto chase failed: $error');
    }

    return lines.join('\n').trim();
  }

  @override
  Future<void> dispose() async {}
}
