import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:JsxposedX/features/ai/domain/contracts/ai_chat_tool_handler.dart';
import 'package:JsxposedX/features/ai/domain/models/ai_tool_call.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_action_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_pointer_action_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_pointer_auto_chase_action_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_pointer_auto_chase_query_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_pointer_query_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_query_repository.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_saved_item.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_ai_pending_interaction_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_instruction_history_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_value_history_state.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';

class MemoryAiOverlayToolRuntimeContext {
  const MemoryAiOverlayToolRuntimeContext({
    required this.processInfo,
    required this.isZh,
    required this.memoryQueryRepository,
    required this.memoryActionRepository,
    required this.memoryPointerQueryRepository,
    required this.memoryPointerActionRepository,
    required this.memoryPointerAutoChaseQueryRepository,
    required this.memoryPointerAutoChaseActionRepository,
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
    required this.requestUserChoice,
  });

  final ProcessInfo processInfo;
  final bool isZh;
  final MemoryQueryRepository memoryQueryRepository;
  final MemoryActionRepository memoryActionRepository;
  final MemoryPointerQueryRepository memoryPointerQueryRepository;
  final MemoryPointerActionRepository memoryPointerActionRepository;
  final MemoryPointerAutoChaseQueryRepository
  memoryPointerAutoChaseQueryRepository;
  final MemoryPointerAutoChaseActionRepository
  memoryPointerAutoChaseActionRepository;
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
  final void Function({required int pid, required Iterable<int> addresses})
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
  final Future<void> Function({required MemoryFreezeRequest request})
  setMemoryFreezeAction;
  final Future<void> Function({required List<MemoryFreezeRequest> requests})
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
  final Future<String> Function({
    required String toolName,
    required String title,
    required String description,
    required List<MemoryAiPendingInteractionOption> options,
    String? cancelLabel,
  })
  requestUserChoice;

  int get pid => processInfo.pid;
}

Iterable<AiChatToolHandler> buildMemoryAiOverlayToolHandlers({
  required MemoryAiOverlayToolRuntimeContext context,
}) sync* {
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'get_process_summary',
    onHandle: (call) async => _buildProcessSummary(context),
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'list_memory_regions',
    onHandle: (call) async {
      final regions = await context.memoryQueryRepository.getMemoryRegions(
        pid: context.pid,
        offset: _getOptionalInt(call, 'offset', 0),
        limit: _getOptionalInt(call, 'limit', 50),
        readableOnly: _getOptionalBool(call, 'readableOnly', true),
        includeAnonymous: _getOptionalBool(call, 'includeAnonymous', true),
        includeFileBacked: _getOptionalBool(call, 'includeFileBacked', true),
      );
      if (regions.isEmpty) {
        return '未找到符合条件的内存区。';
      }
      final buffer = StringBuffer()..writeln('共 ${regions.length} 个内存区：');
      for (final region in regions) {
        buffer.writeln(_formatRegion(region));
      }
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'get_search_overview',
    onHandle: (call) async {
      final session = await context.memoryQueryRepository
          .getSearchSessionState();
      final task = await context.memoryQueryRepository.getSearchTaskState();
      final buffer = StringBuffer()
        ..writeln('搜索会话：')
        ..writeln(_formatSearchSessionState(session, currentPid: context.pid))
        ..writeln()
        ..writeln('搜索任务：')
        ..writeln(_formatSearchTaskState(task));
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'get_search_results',
    onHandle: (call) async {
      final results = await context.memoryQueryRepository.getSearchResults(
        offset: _getOptionalInt(call, 'offset', 0),
        limit: _getOptionalInt(call, 'limit', 50),
      );
      if (results.isEmpty) {
        return '当前没有搜索结果。';
      }
      final buffer = StringBuffer()..writeln('共返回 ${results.length} 条搜索结果：');
      for (final result in results) {
        buffer.writeln(_formatSearchResult(result));
      }
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'start_first_scan',
    onHandleWithProgress: (call, {onProgress}) async {
      final request = FirstScanRequest(
        pid: context.pid,
        value: _buildSearchValueFromToolCall(call, isFirstScan: true),
        matchMode: SearchMatchMode.exact,
        rangeSectionKeys: _getStringList(call, 'rangeSectionKeys'),
        scanAllReadableRegions: _getOptionalBool(
          call,
          'scanAllReadableRegions',
          true,
        ),
      );
      final startTracker = _trackBackgroundAction(
        context.memoryActionRepository.firstScan(request: request),
      );
      final task = await _waitForSearchTaskToSettle(
        context,
        title: '首次搜索',
        onProgress: onProgress,
        startTracker: startTracker,
      );
      startTracker.throwIfFailed();
      final session = await context.memoryQueryRepository
          .getSearchSessionState();
      return _buildSearchTaskCompletionResult(
        context: context,
        title: '首次搜索',
        task: task,
        session: session,
      );
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'continue_next_scan',
    onHandleWithProgress: (call, {onProgress}) async {
      final request = NextScanRequest(
        value: _buildSearchValueFromToolCall(call, isFirstScan: false),
        matchMode: SearchMatchMode.exact,
      );
      final startTracker = _trackBackgroundAction(
        context.memoryActionRepository.nextScan(request: request),
      );
      final task = await _waitForSearchTaskToSettle(
        context,
        title: '继续筛选',
        onProgress: onProgress,
        startTracker: startTracker,
      );
      startTracker.throwIfFailed();
      final session = await context.memoryQueryRepository
          .getSearchSessionState();
      return _buildSearchTaskCompletionResult(
        context: context,
        title: '继续筛选',
        task: task,
        session: session,
      );
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'cancel_search',
    onHandle: (call) async {
      await context.memoryActionRepository.cancelSearch();
      return '搜索任务已取消。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'reset_search_session',
    onHandleWithProgress: (call, {onProgress}) async {
      final session = await context.memoryQueryRepository.getSearchSessionState();
      if (!session.hasActiveSession) {
        return '当前没有活动搜索会话。';
      }
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'reset_search_session',
        title: context.isZh ? '确认重置搜索会话' : 'Confirm search reset',
        description: context.isZh
            ? '当前搜索会话有 ${session.resultCount} 条结果，重置后会直接清空当前搜索现场。'
            : 'The current search session contains ${session.resultCount} results. Resetting it will clear the active search state.',
        confirmLabel: context.isZh ? '重置搜索会话' : 'Reset search session',
        cancelLabel: context.isZh ? '保留当前搜索会话' : 'Keep current search session',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消重置搜索会话。' : 'Search session reset cancelled.';
      }
      await context.memoryActionRepository.resetSearchSession();
      return '搜索会话已重置。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'list_saved_items',
    onHandle: (call) async {
      final items = context.listSavedItems()
        ..sort((left, right) => left.address.compareTo(right.address));
      final page = _slicePage(
        items,
        offset: _getOptionalInt(call, 'offset', 0),
        limit: _getOptionalInt(call, 'limit', 50),
      );
      if (page.isEmpty) {
        return items.isEmpty ? '当前进程暂存区为空。' : '该分页范围内没有暂存条目。';
      }
      final buffer = StringBuffer()
        ..writeln('当前进程暂存区共 ${items.length} 条，本次返回 ${page.length} 条：');
      for (final item in page) {
        buffer.writeln(_formatSavedItem(item));
      }
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'save_search_results_to_saved',
    onHandle: (call) async {
      final offset = _getOptionalInt(call, 'offset', 0);
      final limit = _getOptionalInt(call, 'limit', 50);
      final markFrozen = _getOptionalBool(call, 'markFrozen', false);
      final results = await context.memoryQueryRepository.getSearchResults(
        offset: offset,
        limit: limit,
      );
      if (results.isEmpty) {
        return '当前分页内没有可保存的搜索结果。';
      }
      final previews = await _readValuePreviewsForResults(context, results);
      context.saveSavedItems(
        pid: context.pid,
        results: results,
        previewsByAddress: previews,
        frozenAddresses: markFrozen
            ? results.map((result) => result.address).toSet()
            : const <int>{},
      );
      return markFrozen
          ? '已将 ${results.length} 条搜索结果保存到暂存区，并标记为冻结条目。'
          : '已将 ${results.length} 条搜索结果保存到暂存区。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'save_memory_addresses_to_saved',
    onHandle: (call) async {
      final addresses = _parseAddressList(call, 'addresses');
      if (addresses.isEmpty) {
        throw ArgumentError('addresses 不能为空');
      }
      final markFrozen = _getOptionalBool(call, 'markFrozen', false);
      final markInstructionPatch = _getOptionalBool(
        call,
        'markInstructionPatch',
        false,
      );
      final existingSavedItems = <int, MemoryToolSavedItem>{
        for (final item in context.listSavedItems()) item.address: item,
      };

      if (markInstructionPatch) {
        final previews = await context.memoryQueryRepository.disassembleMemory(
          pid: context.pid,
          addresses: addresses,
        );
        if (previews.isEmpty) {
          return '未读取到任何指令预览，暂存失败。';
        }
        final metadataByAddress = await _resolveAddressMetadataMap(
          context,
          previews.map((preview) => preview.address).toList(growable: false),
          existingItemsByAddress: existingSavedItems,
        );
        for (final preview in previews) {
          final metadata =
              metadataByAddress[preview.address] ??
              _AddressMetadata(
                regionStart: preview.address,
                regionTypeKey: 'other',
              );
          context.saveSavedItem(
            pid: context.pid,
            result: SearchResult(
              address: preview.address,
              regionStart: metadata.regionStart,
              regionTypeKey: metadata.regionTypeKey,
              type: SearchValueType.bytes,
              rawBytes: preview.rawBytes,
              displayValue: preview.instructionText,
            ),
            isFrozen: markFrozen,
            isInstructionPatch: true,
            instructionText: preview.instructionText,
          );
        }
        return '已将 ${previews.length} 个地址按指令补丁条目保存到暂存区。';
      }

      final valueType = _parseRawSearchValueType(
        _getRequiredString(call, 'valueType'),
      );
      final length = _resolveReadLength(
        valueType,
        _getOptionalIntOrNull(call, 'length'),
      );
      final previews = await context.memoryQueryRepository.readMemoryValues(
        requests: addresses
            .map(
              (address) => MemoryReadRequest(
                pid: context.pid,
                address: address,
                type: valueType,
                length: length,
              ),
            )
            .toList(growable: false),
      );
      if (previews.isEmpty) {
        return '未读取到任何内存值，暂存失败。';
      }
      final metadataByAddress = await _resolveAddressMetadataMap(
        context,
        previews.map((preview) => preview.address).toList(growable: false),
        existingItemsByAddress: existingSavedItems,
      );
      for (final preview in previews) {
        final metadata =
            metadataByAddress[preview.address] ??
            _AddressMetadata(
              regionStart: preview.address,
              regionTypeKey: 'other',
            );
        context.saveSavedItem(
          pid: context.pid,
          result: SearchResult(
            address: preview.address,
            regionStart: metadata.regionStart,
            regionTypeKey: metadata.regionTypeKey,
            type: preview.type,
            rawBytes: preview.rawBytes,
            displayValue: preview.displayValue,
          ),
          preview: preview,
          isFrozen: markFrozen,
        );
      }
      return markFrozen
          ? '已将 ${previews.length} 个地址保存到暂存区，并标记为冻结条目。'
          : '已将 ${previews.length} 个地址保存到暂存区。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'remove_saved_items',
    onHandleWithProgress: (call, {onProgress}) async {
      final savedItems = context.listSavedItems();
      final explicitAddresses = _parseOptionalAddressList(call, 'addresses');
      if (explicitAddresses == null && savedItems.isEmpty) {
        return '当前进程暂存区为空。';
      }
      final addresses =
          explicitAddresses ??
          await _resolveAddressesFromChoices(
            context,
            toolName: 'remove_saved_items',
            title: context.isZh ? '选择要移除的暂存条目' : 'Choose saved items to remove',
            description: context.isZh
                ? '当前没有明确指定 addresses，需要你决定移除哪个暂存地址，或一次移除全部。'
                : 'No explicit addresses were provided. Choose which saved address to remove, or remove them all.',
            availableAddresses: savedItems
                .map((item) => item.address)
                .toList(growable: false),
            labelBuilder: (address) => _formatAddress(address),
            descriptionBuilder: (address) {
              MemoryToolSavedItem? item;
              for (final saved in savedItems) {
                if (saved.address == address) {
                  item = saved;
                  break;
                }
              }
              if (item == null) {
                return null;
              }
              return 'type=${item.type.name} | frozen=${item.isFrozen}';
            },
            onProgress: onProgress,
          );
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'remove_saved_items',
        title: context.isZh ? '确认移除暂存条目' : 'Confirm saved item removal',
        description: context.isZh
            ? '即将从暂存区移除 ${addresses.length} 个地址：${_formatAddressPreview(addresses)}'
            : 'About to remove ${addresses.length} saved addresses: ${_formatAddressPreview(addresses)}',
        confirmLabel: context.isZh ? '移除这些条目' : 'Remove selected items',
        cancelLabel: context.isZh ? '保留暂存条目' : 'Keep saved items',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消移除暂存条目。' : 'Saved item removal cancelled.';
      }
      context.removeSavedItems(pid: context.pid, addresses: addresses);
      return '已从暂存区移除 ${addresses.length} 个地址。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'clear_saved_items',
    onHandleWithProgress: (call, {onProgress}) async {
      final savedItems = context.listSavedItems();
      if (savedItems.isEmpty) {
        return '当前进程暂存区为空。';
      }
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'clear_saved_items',
        title: context.isZh ? '确认清空暂存区' : 'Confirm clearing saved items',
        description: context.isZh
            ? '当前进程暂存区共有 ${savedItems.length} 条条目，清空后会删除当前暂存现场。'
            : 'The current process has ${savedItems.length} saved items. Clearing them will remove the saved working set.',
        confirmLabel: context.isZh ? '清空暂存区' : 'Clear saved items',
        cancelLabel: context.isZh ? '保留暂存区' : 'Keep saved items',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消清空暂存区。' : 'Clearing saved items cancelled.';
      }
      context.clearSavedItems(context.pid);
      return '当前进程暂存区已清空。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'read_memory',
    onHandle: (call) async {
      final valueType = _parseRawSearchValueType(
        _getRequiredString(call, 'valueType'),
      );
      final addresses = _parseAddressList(call, 'addresses');
      if (addresses.isEmpty) {
        throw ArgumentError('addresses 不能为空');
      }
      final length = _resolveReadLength(
        valueType,
        _getOptionalIntOrNull(call, 'length'),
      );
      final previews = await context.memoryQueryRepository.readMemoryValues(
        requests: addresses
            .map(
              (address) => MemoryReadRequest(
                pid: context.pid,
                address: address,
                type: valueType,
                length: length,
              ),
            )
            .toList(growable: false),
      );
      if (previews.isEmpty) {
        return '未读取到任何内存值。';
      }
      final buffer = StringBuffer()..writeln('共读取 ${previews.length} 个地址：');
      for (final preview in previews) {
        buffer.writeln(_formatValuePreview(preview));
      }
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'disassemble_memory',
    onHandle: (call) async {
      final addresses = _parseAddressList(call, 'addresses');
      if (addresses.isEmpty) {
        throw ArgumentError('addresses 不能为空');
      }
      final previews = await context.memoryQueryRepository.disassembleMemory(
        pid: context.pid,
        addresses: addresses,
      );
      if (previews.isEmpty) {
        return '未读取到任何反汇编结果。';
      }
      final buffer = StringBuffer()..writeln('共反汇编 ${previews.length} 个地址：');
      for (final preview in previews) {
        buffer.writeln(_formatInstructionPreview(preview));
      }
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'write_memory_value',
    onHandleWithProgress: (call, {onProgress}) async {
      final address = _parseRequiredAddress(call, 'address');
      final rawValue = _getRequiredString(call, 'value');
      final value = _buildWriteValueFromToolCall(call);
      final preview = await _readValuePreviewOrNull(
        context,
        address: address,
        type: value.type,
        length: _resolveReadLength(value.type, _resolveWriteValueLength(value)),
      );
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'write_memory_value',
        title: context.isZh ? '确认写入' : 'Confirm write',
        description: context.isZh
            ? '地址: ${_formatAddress(address)}\n当前: ${preview?.displayValue ?? "未知"}\n写入: ${_formatPendingValuePreview(rawValue)} (${value.type.name})'
            : 'Address: ${_formatAddress(address)}\nCurrent: ${preview?.displayValue ?? "unknown"}\nWrite: ${_formatPendingValuePreview(rawValue)} (${value.type.name})',
        confirmLabel: context.isZh ? '写入' : 'Write',
        cancelLabel: context.isZh ? '取消' : 'Cancel',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消内存写入。' : 'Memory write cancelled.';
      }
      await context.writeMemoryValueAction(
        request: MemoryWriteRequest(address: address, value: value),
        previousPreview: preview,
      );
      return '已写入地址 ${_formatAddress(address)}。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'write_memory_values',
    onHandleWithProgress: (call, {onProgress}) async {
      final addresses = _parseAddressList(call, 'addresses');
      if (addresses.isEmpty) {
        throw ArgumentError('addresses 不能为空');
      }
      final rawValues = _getStringList(call, 'values');
      if (rawValues.isEmpty) {
        throw ArgumentError('values 不能为空');
      }
      final resolvedValues = _resolveParallelStringValues(
        addresses: addresses,
        rawValues: rawValues,
        argumentName: 'values',
      );
      final requests = <MemoryWriteRequest>[];
      final previewRequests = <MemoryReadRequest>[];
      for (var index = 0; index < addresses.length; index += 1) {
        final value = _buildWriteValue(
          valueType: _normalizeLower(_getRequiredString(call, 'valueType')),
          rawValue: resolvedValues[index],
          littleEndian: _getOptionalBool(call, 'littleEndian', true),
          bytesMode: _normalizeLower(
            _getOptionalString(call, 'bytesMode', 'auto'),
          ),
        );
        requests.add(
          MemoryWriteRequest(address: addresses[index], value: value),
        );
        previewRequests.add(
          MemoryReadRequest(
            pid: context.pid,
            address: addresses[index],
            type: value.type,
            length: _resolveReadLength(
              value.type,
              _resolveWriteValueLength(value),
            ),
          ),
        );
      }
      final previousPreviews = await context.memoryQueryRepository
          .readMemoryValues(requests: previewRequests);
      final batchValuePreview = rawValues.length == 1
          ? _formatPendingValuePreview(rawValues.first)
          : (context.isZh ? '多组值' : 'multiple values');
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'write_memory_values',
        title: context.isZh ? '确认批量写入' : 'Confirm batch write',
        description: context.isZh
            ? '数量: ${requests.length}\n写入: $batchValuePreview (${requests.first.value.type.name})\n地址: ${_formatAddressPreview(addresses)}'
            : 'Count: ${requests.length}\nWrite: $batchValuePreview (${requests.first.value.type.name})\nAddresses: ${_formatAddressPreview(addresses)}',
        confirmLabel: context.isZh ? '写入' : 'Write',
        cancelLabel: context.isZh ? '取消' : 'Cancel',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消批量内存写入。' : 'Batch memory write cancelled.';
      }
      await context.writeMemoryValuesAction(
        requests: requests,
        previousPreviews: previousPreviews,
      );
      return '已批量写入 ${requests.length} 个地址。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'patch_memory_instruction',
    onHandleWithProgress: (call, {onProgress}) async {
      final address = _parseRequiredAddress(call, 'address');
      final instruction = _getRequiredString(call, 'instruction');
      final previousInstruction = await _readInstructionPreviewOrNull(
        context,
        address: address,
      );
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'patch_memory_instruction',
        title: context.isZh ? '确认修改指令' : 'Confirm instruction patch',
        description: context.isZh
            ? '即将修改地址 ${_formatAddress(address)} 的机器指令。\n当前指令: ${previousInstruction?.instructionText ?? "未知"}\n新指令: $instruction'
            : 'About to patch the instruction at ${_formatAddress(address)}.\nCurrent instruction: ${previousInstruction?.instructionText ?? "unknown"}\nNew instruction: $instruction',
        confirmLabel: context.isZh ? '执行补丁' : 'Patch instruction',
        cancelLabel: context.isZh ? '取消补丁' : 'Cancel patch',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消指令补丁。' : 'Instruction patch cancelled.';
      }
      final result = await context.patchMemoryInstructionAction(
        request: MemoryInstructionPatchRequest(
          pid: context.pid,
          address: address,
          instruction: instruction,
        ),
      );
      context.recordInstructionHistory(
        pid: context.pid,
        address: address,
        previousBytes: result.beforeBytes,
        previousDisplayValue:
            previousInstruction?.instructionText.isNotEmpty == true
            ? previousInstruction!.instructionText
            : _formatHex(result.beforeBytes),
      );
      return [
        '指令补丁已完成：',
        '地址: ${_formatAddress(result.address)}',
        '架构: ${result.architecture}',
        '指令大小: ${result.instructionSize}',
        '修改前: ${_formatHex(result.beforeBytes)}',
        '修改后: ${_formatHex(result.afterBytes)}',
        '指令文本: ${result.instructionText}',
      ].join('\n');
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'list_value_history',
    onHandle: (call) async {
      final entries = context.listValueHistoryEntries().values.toList(
        growable: false,
      )..sort((left, right) => left.address.compareTo(right.address));
      final page = _slicePage(
        entries,
        offset: _getOptionalInt(call, 'offset', 0),
        limit: _getOptionalInt(call, 'limit', 50),
      );
      if (page.isEmpty) {
        return entries.isEmpty ? '当前没有旧值历史。' : '该分页范围内没有旧值历史。';
      }
      final buffer = StringBuffer()
        ..writeln('当前共有 ${entries.length} 条旧值历史，本次返回 ${page.length} 条：');
      for (final entry in page) {
        buffer.writeln(_formatValueHistoryEntry(entry));
      }
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'restore_previous_values',
    onHandleWithProgress: (call, {onProgress}) async {
      final historyByAddress = context.listValueHistoryEntries();
      final explicitAddresses = _parseOptionalAddressList(call, 'addresses');
      if (explicitAddresses == null && historyByAddress.isEmpty) {
        return '当前没有旧值历史。';
      }
      final addresses =
          explicitAddresses ??
          await _resolveAddressesFromChoices(
            context,
            toolName: 'restore_previous_values',
            title: context.isZh ? '选择要恢复旧值的地址' : 'Choose addresses to restore',
            description: context.isZh
                ? '当前没有明确指定 addresses，需要你决定恢复哪个地址的旧值，或一次恢复全部。'
                : 'No explicit addresses were provided. Choose which address to restore, or restore them all.',
            availableAddresses: historyByAddress.keys.toList(growable: false)
              ..sort(),
            labelBuilder: _formatAddress,
            descriptionBuilder: (address) {
              final entry = historyByAddress[address];
              return entry == null ? null : 'type=${entry.type.name} | value=${entry.displayValue}';
            },
            onProgress: onProgress,
          );
      final littleEndian =
          _getOptionalBoolOrNull(call, 'littleEndian') ??
          (await context.memoryQueryRepository.getSearchSessionState())
              .littleEndian;
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'restore_previous_values',
        title: context.isZh ? '确认恢复旧值' : 'Confirm value restore',
        description: context.isZh
            ? '即将恢复 ${addresses.length} 个地址的旧值：${_formatAddressPreview(addresses)}'
            : 'About to restore previous values for ${addresses.length} addresses: ${_formatAddressPreview(addresses)}',
        confirmLabel: context.isZh ? '恢复这些旧值' : 'Restore previous values',
        cancelLabel: context.isZh ? '取消恢复' : 'Cancel restore',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消旧值恢复。' : 'Previous value restore cancelled.';
      }
      final restoredCount = await context.restorePreviousValuesAction(
        addresses: addresses,
        littleEndian: littleEndian,
      );
      return restoredCount > 0 ? '已恢复 $restoredCount 个地址的旧值。' : '没有可恢复的旧值历史。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'set_memory_freeze',
    onHandleWithProgress: (call, {onProgress}) async {
      final address = _parseRequiredAddress(call, 'address');
      final value = _buildWriteValueFromToolCall(call);
      final enabled = _getRequiredBool(call, 'enabled');
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'set_memory_freeze',
        title: enabled
            ? (context.isZh ? '确认启用冻结' : 'Confirm enabling freeze')
            : (context.isZh ? '确认关闭冻结' : 'Confirm disabling freeze'),
        description: context.isZh
            ? '即将对地址 ${_formatAddress(address)}${enabled ? "启用" : "关闭"}冻结。'
            : 'About to ${enabled ? "enable" : "disable"} freeze at ${_formatAddress(address)}.',
        confirmLabel: enabled
            ? (context.isZh ? '启用冻结' : 'Enable freeze')
            : (context.isZh ? '关闭冻结' : 'Disable freeze'),
        cancelLabel: context.isZh ? '取消本次操作' : 'Cancel action',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消冻结操作。' : 'Freeze operation cancelled.';
      }
      await context.setMemoryFreezeAction(
        request: MemoryFreezeRequest(
          address: address,
          value: value,
          enabled: enabled,
        ),
      );
      return enabled
          ? '已对地址 ${_formatAddress(address)} 启用冻结。'
          : '已对地址 ${_formatAddress(address)} 关闭冻结。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'set_memory_freezes',
    onHandleWithProgress: (call, {onProgress}) async {
      final addresses = _parseAddressList(call, 'addresses');
      if (addresses.isEmpty) {
        throw ArgumentError('addresses 不能为空');
      }
      final rawValues = _getStringList(call, 'values');
      if (rawValues.isEmpty) {
        throw ArgumentError('values 不能为空');
      }
      final resolvedValues = _resolveParallelStringValues(
        addresses: addresses,
        rawValues: rawValues,
        argumentName: 'values',
      );
      final enabled = _getRequiredBool(call, 'enabled');
      final requests = <MemoryFreezeRequest>[];
      for (var index = 0; index < addresses.length; index += 1) {
        requests.add(
          MemoryFreezeRequest(
            address: addresses[index],
            value: _buildWriteValue(
              valueType: _normalizeLower(_getRequiredString(call, 'valueType')),
              rawValue: resolvedValues[index],
              littleEndian: _getOptionalBool(call, 'littleEndian', true),
              bytesMode: _normalizeLower(
                _getOptionalString(call, 'bytesMode', 'auto'),
              ),
            ),
            enabled: enabled,
          ),
        );
      }
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'set_memory_freezes',
        title: enabled
            ? (context.isZh ? '确认批量启用冻结' : 'Confirm batch freeze enable')
            : (context.isZh ? '确认批量关闭冻结' : 'Confirm batch freeze disable'),
        description: context.isZh
            ? '即将对 ${requests.length} 个地址${enabled ? "启用" : "关闭"}冻结：${_formatAddressPreview(addresses)}'
            : 'About to ${enabled ? "enable" : "disable"} freeze for ${requests.length} addresses: ${_formatAddressPreview(addresses)}',
        confirmLabel: enabled
            ? (context.isZh ? '批量启用冻结' : 'Enable freezes')
            : (context.isZh ? '批量关闭冻结' : 'Disable freezes'),
        cancelLabel: context.isZh ? '取消本次操作' : 'Cancel action',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消批量冻结操作。' : 'Batch freeze operation cancelled.';
      }
      await context.setMemoryFreezesAction(requests: requests);
      return enabled
          ? '已批量启用 ${requests.length} 个冻结值。'
          : '已批量关闭 ${requests.length} 个冻结值。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'list_frozen_memory_values',
    onHandle: (call) async {
      final allValues = await context.memoryActionRepository
          .getFrozenMemoryValues();
      final values = allValues
          .where((value) => value.pid == context.pid)
          .toList(growable: false);
      if (values.isEmpty) {
        return '当前进程没有冻结值。';
      }
      final buffer = StringBuffer()..writeln('当前进程共有 ${values.length} 个冻结值：');
      for (final value in values) {
        buffer.writeln(_formatFrozenMemoryValue(value));
      }
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'list_instruction_patch_history',
    onHandle: (call) async {
      final entries = context.listInstructionHistoryEntries().values.toList(
        growable: false,
      )..sort((left, right) => left.address.compareTo(right.address));
      final page = _slicePage(
        entries,
        offset: _getOptionalInt(call, 'offset', 0),
        limit: _getOptionalInt(call, 'limit', 50),
      );
      if (page.isEmpty) {
        return entries.isEmpty ? '当前没有指令补丁历史。' : '该分页范围内没有指令补丁历史。';
      }
      final buffer = StringBuffer()
        ..writeln('当前共有 ${entries.length} 条指令补丁历史，本次返回 ${page.length} 条：');
      for (final entry in page) {
        buffer.writeln(_formatInstructionHistoryEntry(entry));
      }
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'restore_instruction_patches',
    onHandleWithProgress: (call, {onProgress}) async {
      final historyByAddress = context.listInstructionHistoryEntries();
      final explicitAddresses = _parseOptionalAddressList(call, 'addresses');
      if (explicitAddresses == null && historyByAddress.isEmpty) {
        return '当前没有指令补丁历史。';
      }
      final addresses =
          explicitAddresses ??
          await _resolveAddressesFromChoices(
            context,
            toolName: 'restore_instruction_patches',
            title: context.isZh ? '选择要恢复补丁的地址' : 'Choose patches to restore',
            description: context.isZh
                ? '当前没有明确指定 addresses，需要你决定恢复哪个地址的指令补丁，或一次恢复全部。'
                : 'No explicit addresses were provided. Choose which patched address to restore, or restore them all.',
            availableAddresses: historyByAddress.keys.toList(growable: false)
              ..sort(),
            labelBuilder: _formatAddress,
            descriptionBuilder: (address) {
              final entry = historyByAddress[address];
              return entry == null ? null : 'previous=${entry.previousDisplayValue}';
            },
            onProgress: onProgress,
          );
      final savedItemsByAddress = <int, MemoryToolSavedItem>{
        for (final item in context.listSavedItems()) item.address: item,
      };
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'restore_instruction_patches',
        title: context.isZh ? '确认恢复指令补丁' : 'Confirm patch restore',
        description: context.isZh
            ? '即将恢复 ${addresses.length} 个地址的指令补丁：${_formatAddressPreview(addresses)}'
            : 'About to restore instruction patches for ${addresses.length} addresses: ${_formatAddressPreview(addresses)}',
        confirmLabel: context.isZh ? '恢复这些补丁' : 'Restore patches',
        cancelLabel: context.isZh ? '取消恢复' : 'Cancel restore',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消指令补丁恢复。' : 'Instruction patch restore cancelled.';
      }
      var restoredCount = 0;
      for (final address in addresses) {
        final entry = historyByAddress[address];
        if (entry == null) {
          continue;
        }
        final currentInstruction = await _readInstructionPreviewOrNull(
          context,
          address: address,
        );
        final result = await context.patchMemoryInstructionAction(
          request: MemoryInstructionPatchRequest(
            pid: context.pid,
            address: address,
            instruction: _formatHex(entry.previousBytes),
          ),
        );
        context.recordInstructionHistory(
          pid: context.pid,
          address: address,
          previousBytes: result.beforeBytes,
          previousDisplayValue:
              currentInstruction?.instructionText.isNotEmpty == true
              ? currentInstruction!.instructionText
              : _formatHex(result.beforeBytes),
        );
        final savedItem = savedItemsByAddress[address];
        if (savedItem != null) {
          context.saveSavedItem(
            pid: context.pid,
            result: SearchResult(
              address: address,
              regionStart: savedItem.regionStart,
              regionTypeKey: savedItem.regionTypeKey,
              type: SearchValueType.bytes,
              rawBytes: result.afterBytes,
              displayValue: result.instructionText,
            ),
            isFrozen: false,
            isInstructionPatch: true,
            instructionText: result.instructionText,
          );
        }
        restoredCount += 1;
      }
      return restoredCount > 0
          ? '已恢复 $restoredCount 个地址的指令补丁。'
          : '没有可恢复的指令补丁历史。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'set_process_paused',
    onHandleWithProgress: (call, {onProgress}) async {
      final paused = await _resolvePausedTargetChoice(
        context,
        call,
        onProgress: onProgress,
      );
      final isCurrentlyPaused = await context.memoryActionRepository
          .isProcessPaused(pid: context.pid);
      if (paused == isCurrentlyPaused) {
        return paused ? '当前进程已处于暂停状态。' : '当前进程已经在运行。';
      }
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'set_process_paused',
        title: paused
            ? (context.isZh ? '确认暂停进程' : 'Confirm pausing process')
            : (context.isZh ? '确认恢复进程' : 'Confirm resuming process'),
        description: context.isZh
            ? '当前进程${isCurrentlyPaused ? "已暂停" : "正在运行"}，即将切换为${paused ? "暂停" : "运行"}状态。'
            : 'The process is currently ${isCurrentlyPaused ? "paused" : "running"} and will be switched to ${paused ? "paused" : "running"}.',
        confirmLabel: paused
            ? (context.isZh ? '暂停进程' : 'Pause process')
            : (context.isZh ? '恢复进程' : 'Resume process'),
        cancelLabel: context.isZh ? '取消本次操作' : 'Cancel action',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消进程状态切换。' : 'Process state change cancelled.';
      }
      await context.memoryActionRepository.setProcessPaused(
        pid: context.pid,
        paused: paused,
      );
      return paused ? '当前进程已暂停。' : '当前进程已恢复运行。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'get_breakpoint_overview',
    onHandle: (call) async {
      final state = await context.memoryQueryRepository
          .getMemoryBreakpointState(pid: context.pid);
      return _formatBreakpointState(state);
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'list_memory_breakpoints',
    onHandle: (call) async {
      final breakpoints = await context.memoryQueryRepository
          .listMemoryBreakpoints(pid: context.pid);
      if (breakpoints.isEmpty) {
        return '当前进程没有断点。';
      }
      final buffer = StringBuffer()
        ..writeln('当前进程共有 ${breakpoints.length} 个断点：');
      for (final breakpoint in breakpoints) {
        buffer.writeln(_formatBreakpoint(breakpoint));
      }
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'get_memory_breakpoint_hits',
    onHandle: (call) async {
      final hits = await context.memoryQueryRepository.getMemoryBreakpointHits(
        pid: context.pid,
        offset: _getOptionalInt(call, 'offset', 0),
        limit: _getOptionalInt(call, 'limit', 50),
      );
      if (hits.isEmpty) {
        return '当前没有断点命中记录。';
      }
      final buffer = StringBuffer()..writeln('共返回 ${hits.length} 条断点命中：');
      for (final hit in hits) {
        buffer.writeln(_formatBreakpointHit(hit));
      }
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'add_memory_breakpoint',
    onHandleWithProgress: (call, {onProgress}) async {
      final valueType = _parseRawSearchValueType(
        _getRequiredString(call, 'valueType'),
      );
      final length = _resolveReadLength(
        valueType,
        _getOptionalIntOrNull(call, 'length'),
      );
      final pauseProcessOnHit = await _resolveBreakpointPauseProcessOnHit(
        context,
        call,
        onProgress: onProgress,
      );
      final accessType = await _resolveBreakpointAccessType(
        context,
        call,
        onProgress: onProgress,
      );
      final enabled = await _resolveBreakpointEnabled(
        context,
        call,
        onProgress: onProgress,
      );
      final breakpoint = await context.memoryActionRepository
          .addMemoryBreakpoint(
            request: AddMemoryBreakpointRequest(
              pid: context.pid,
              address: _parseRequiredAddress(call, 'address'),
              type: valueType,
              length: length,
              accessType: accessType,
              enabled: enabled,
              pauseProcessOnHit: pauseProcessOnHit,
            ),
          );
      return '断点已创建：\n${_formatBreakpoint(breakpoint)}';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'remove_memory_breakpoint',
    onHandleWithProgress: (call, {onProgress}) async {
      final breakpointId = await _resolveBreakpointId(
        context,
        toolName: 'remove_memory_breakpoint',
        argumentName: 'breakpointId',
        title: context.isZh ? '选择要删除的断点' : 'Choose breakpoint to remove',
        description: context.isZh
            ? '当前没有明确指定 breakpointId，需要你决定删除哪个断点。'
            : 'No explicit breakpointId was provided. Choose which breakpoint to remove.',
        call: call,
        onProgress: onProgress,
      );
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'remove_memory_breakpoint',
        title: context.isZh ? '确认删除断点' : 'Confirm breakpoint removal',
        description: context.isZh
            ? '即将删除断点 $breakpointId。'
            : 'About to remove breakpoint $breakpointId.',
        confirmLabel: context.isZh ? '删除断点' : 'Remove breakpoint',
        cancelLabel: context.isZh ? '保留断点' : 'Keep breakpoint',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消删除断点。' : 'Breakpoint removal cancelled.';
      }
      await context.memoryActionRepository.removeMemoryBreakpoint(
        breakpointId: breakpointId,
      );
      return '断点 $breakpointId 已删除。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'set_memory_breakpoint_enabled',
    onHandleWithProgress: (call, {onProgress}) async {
      final breakpointId = await _resolveBreakpointId(
        context,
        toolName: 'set_memory_breakpoint_enabled',
        argumentName: 'breakpointId',
        title: context.isZh ? '选择要修改的断点' : 'Choose breakpoint to update',
        description: context.isZh
            ? '当前没有明确指定 breakpointId，需要你决定修改哪个断点。'
            : 'No explicit breakpointId was provided. Choose which breakpoint to update.',
        call: call,
        onProgress: onProgress,
      );
      final enabled =
          _getOptionalBoolOrNull(call, 'enabled') ??
          await _requestUserChoiceForTool(
                context,
                toolName: 'set_memory_breakpoint_enabled',
                title: context.isZh ? '选择断点状态' : 'Choose breakpoint state',
                description: context.isZh
                    ? '当前没有明确指定 enabled，需要决定该断点是启用还是禁用。'
                    : 'No explicit enabled flag was provided. Choose whether the breakpoint should be enabled or disabled.',
                options: <MemoryAiPendingInteractionOption>[
                  MemoryAiPendingInteractionOption(
                    id: _breakpointEnabledOptionId,
                    label: context.isZh ? '启用断点' : 'Enable breakpoint',
                  ),
                  MemoryAiPendingInteractionOption(
                    id: _breakpointDisabledOptionId,
                    label: context.isZh ? '禁用断点' : 'Disable breakpoint',
                  ),
                ],
                cancelLabel: context.isZh ? '取消本次操作' : 'Cancel this action',
                onProgress: onProgress,
              ) ==
              _breakpointEnabledOptionId;
      await context.memoryActionRepository.setMemoryBreakpointEnabled(
        breakpointId: breakpointId,
        enabled: enabled,
      );
      return enabled ? '断点 $breakpointId 已启用。' : '断点 $breakpointId 已禁用。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'clear_memory_breakpoint_hits',
    onHandleWithProgress: (call, {onProgress}) async {
      final breakpointState = await context.memoryQueryRepository
          .getMemoryBreakpointState(pid: context.pid);
      if (breakpointState.pendingHitCount <= 0) {
        return '当前没有断点命中记录。';
      }
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'clear_memory_breakpoint_hits',
        title: context.isZh ? '确认清空断点命中' : 'Confirm clearing breakpoint hits',
        description: context.isZh
            ? '当前有 ${breakpointState.pendingHitCount} 条待处理断点命中记录，清空后无法直接回看。'
            : 'There are ${breakpointState.pendingHitCount} pending breakpoint hits. Clearing them removes the current hit history.',
        confirmLabel: context.isZh ? '清空命中记录' : 'Clear hit records',
        cancelLabel: context.isZh ? '保留命中记录' : 'Keep hit records',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消清空断点命中记录。' : 'Clearing breakpoint hits cancelled.';
      }
      await context.memoryActionRepository.clearMemoryBreakpointHits(
        pid: context.pid,
      );
      return '断点命中记录已清空。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'resume_after_breakpoint',
    onHandleWithProgress: (call, {onProgress}) async {
      final breakpointState = await context.memoryQueryRepository
          .getMemoryBreakpointState(pid: context.pid);
      if (!breakpointState.isProcessPaused) {
        return context.isZh
            ? '当前进程没有处于断点暂停状态。'
            : 'The process is not currently paused by a breakpoint.';
      }
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'resume_after_breakpoint',
        title: context.isZh ? '确认恢复进程执行' : 'Confirm resume after breakpoint',
        description: context.isZh
            ? '当前进程正处于断点暂停状态，继续执行后会恢复目标进程运行。'
            : 'The process is currently paused at a breakpoint. Resuming will let the target process continue.',
        confirmLabel: context.isZh ? '恢复执行' : 'Resume execution',
        cancelLabel: context.isZh ? '保持暂停' : 'Keep paused',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消恢复进程执行。' : 'Resume after breakpoint cancelled.';
      }
      await context.memoryActionRepository.resumeAfterBreakpoint(
        pid: context.pid,
      );
      return '已从断点暂停状态恢复进程执行。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'get_pointer_scan_overview',
    onHandle: (call) async {
      final session = await context.memoryPointerQueryRepository
          .getPointerScanSessionState();
      final task = await context.memoryPointerQueryRepository
          .getPointerScanTaskState();
      final buffer = StringBuffer()
        ..writeln('指针扫描会话：')
        ..writeln(_formatPointerScanSession(session, currentPid: context.pid))
        ..writeln()
        ..writeln('指针扫描任务：')
        ..writeln(_formatPointerScanTask(task));
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'get_pointer_scan_results',
    onHandle: (call) async {
      final results = await context.memoryPointerQueryRepository
          .getPointerScanResults(
            offset: _getOptionalInt(call, 'offset', 0),
            limit: _getOptionalInt(call, 'limit', 50),
          );
      if (results.isEmpty) {
        return '当前没有指针扫描结果。';
      }
      final buffer = StringBuffer()..writeln('共返回 ${results.length} 条指针结果：');
      for (final result in results) {
        buffer.writeln(_formatPointerResult(result));
      }
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'get_pointer_scan_chase_hint',
    onHandle: (call) async {
      final hint = await context.memoryPointerQueryRepository
          .getPointerScanChaseHint();
      return _formatPointerChaseHint(hint);
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'start_pointer_scan',
    onHandleWithProgress: (call, {onProgress}) async {
      final request = _buildPointerScanRequest(call, context);
      final startTracker = _trackBackgroundAction(
        context.memoryPointerActionRepository.startPointerScan(
          request: request,
        ),
      );
      final task = await _waitForPointerScanTaskToSettle(
        context,
        onProgress: onProgress,
        startTracker: startTracker,
      );
      startTracker.throwIfFailed();
      final session = await context.memoryPointerQueryRepository
          .getPointerScanSessionState();
      return _buildPointerScanCompletionResult(
        context: context,
        task: task,
        session: session,
      );
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'cancel_pointer_scan',
    onHandle: (call) async {
      await context.memoryPointerActionRepository.cancelPointerScan();
      return '指针扫描已取消。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'reset_pointer_scan_session',
    onHandleWithProgress: (call, {onProgress}) async {
      final session = await context.memoryPointerQueryRepository
          .getPointerScanSessionState();
      if (!session.hasActiveSession) {
        return '当前没有活动指针扫描会话。';
      }
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'reset_pointer_scan_session',
        title: context.isZh ? '确认重置指针扫描会话' : 'Confirm pointer scan reset',
        description: context.isZh
            ? '当前指针扫描已有 ${session.resultCount} 条结果，重置后会清空当前指针扫描现场。'
            : 'The current pointer scan contains ${session.resultCount} results. Resetting it will clear the current pointer scan state.',
        confirmLabel: context.isZh ? '重置指针扫描' : 'Reset pointer scan',
        cancelLabel: context.isZh ? '保留当前会话' : 'Keep current session',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消重置指针扫描会话。' : 'Pointer scan reset cancelled.';
      }
      await context.memoryPointerActionRepository.resetPointerScanSession();
      return '指针扫描会话已重置。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'get_pointer_auto_chase_overview',
    onHandle: (call) async {
      final state = await context.memoryPointerAutoChaseQueryRepository
          .getPointerAutoChaseState();
      return _formatPointerAutoChaseState(state);
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'get_pointer_auto_chase_layer_results',
    onHandle: (call) async {
      final layerIndex = _getOptionalInt(call, 'layerIndex', -1);
      if (layerIndex < 0) {
        throw ArgumentError('layerIndex 必须是大于等于 0 的整数');
      }
      final results = await context.memoryPointerAutoChaseQueryRepository
          .getPointerAutoChaseLayerResults(
            layerIndex: layerIndex,
            offset: _getOptionalInt(call, 'offset', 0),
            limit: _getOptionalInt(call, 'limit', 50),
          );
      if (results.isEmpty) {
        return '当前层没有结果。';
      }
      final buffer = StringBuffer()
        ..writeln('自动追链第 $layerIndex 层共返回 ${results.length} 条结果：');
      for (final result in results) {
        buffer.writeln(_formatPointerResult(result));
      }
      return buffer.toString().trim();
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'start_pointer_auto_chase',
    onHandleWithProgress: (call, {onProgress}) async {
      final baseRequest = _buildPointerScanRequest(call, context);
      final maxDepth = _getOptionalInt(call, 'maxDepth', 0);
      if (maxDepth < 1) {
        throw ArgumentError('maxDepth 必须是大于等于 1 的整数');
      }
      final startTracker = _trackBackgroundAction(
        context.memoryPointerAutoChaseActionRepository.startPointerAutoChase(
          request: PointerAutoChaseRequest(
            pid: baseRequest.pid,
            targetAddress: baseRequest.targetAddress,
            pointerWidth: baseRequest.pointerWidth,
            maxOffset: baseRequest.maxOffset,
            alignment: baseRequest.alignment,
            maxDepth: maxDepth,
            rangeSectionKeys: baseRequest.rangeSectionKeys,
            scanAllReadableRegions: baseRequest.scanAllReadableRegions,
          ),
        ),
      );
      final state = await _waitForPointerAutoChaseToSettle(
        context,
        onProgress: onProgress,
        startTracker: startTracker,
      );
      startTracker.throwIfFailed();
      return _buildPointerAutoChaseCompletionResult(state);
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'cancel_pointer_auto_chase',
    onHandle: (call) async {
      await context.memoryPointerAutoChaseActionRepository
          .cancelPointerAutoChase();
      return '自动指针追链已取消。';
    },
  );
  yield _MemoryAiOverlayCallbackToolHandler(
    toolName: 'reset_pointer_auto_chase',
    onHandleWithProgress: (call, {onProgress}) async {
      final state = await context.memoryPointerAutoChaseQueryRepository
          .getPointerAutoChaseState();
      if (!state.isRunning && state.layers.isEmpty) {
        return '当前没有自动指针追链状态可重置。';
      }
      final confirmed = await _confirmDangerousAction(
        context,
        toolName: 'reset_pointer_auto_chase',
        title: context.isZh ? '确认重置自动追链' : 'Confirm auto chase reset',
        description: context.isZh
            ? '当前自动追链共有 ${state.layers.length} 层结果，重置后会清空追链状态与结果。'
            : 'The current auto chase has ${state.layers.length} result layers. Resetting it will clear the chase state and results.',
        confirmLabel: context.isZh ? '重置自动追链' : 'Reset auto chase',
        cancelLabel: context.isZh ? '保留当前状态' : 'Keep current state',
        onProgress: onProgress,
      );
      if (!confirmed) {
        return context.isZh ? '已取消重置自动追链。' : 'Auto chase reset cancelled.';
      }
      await context.memoryPointerAutoChaseActionRepository
          .resetPointerAutoChase();
      return '自动指针追链状态已重置。';
    },
  );
}

class _MemoryAiOverlayCallbackToolHandler implements AiChatToolHandler {
  const _MemoryAiOverlayCallbackToolHandler({
    required this.toolName,
    Future<String> Function(AiToolCall call)? onHandle,
    Future<String> Function(
      AiToolCall call, {
      AiToolProgressCallback? onProgress,
    })?
    onHandleWithProgress,
  }) : _onHandle = onHandle,
       _onHandleWithProgress = onHandleWithProgress;

  @override
  final String toolName;

  final Future<String> Function(AiToolCall call)? _onHandle;
  final Future<String> Function(
    AiToolCall call, {
    AiToolProgressCallback? onProgress,
  })?
  _onHandleWithProgress;

  @override
  Future<String> handle(
    AiToolCall call, {
    AiToolProgressCallback? onProgress,
  }) async {
    try {
      if (_onHandleWithProgress != null) {
        return await _onHandleWithProgress!(call, onProgress: onProgress);
      }
      if (_onHandle != null) {
        return await _onHandle!(call);
      }
      throw const _MemoryAiOverlayToolException('工具处理器未实现。');
    } catch (error) {
      throw _MemoryAiOverlayToolException(_normalizeToolError(error));
    }
  }
}

class _MemoryAiOverlayToolException implements Exception {
  const _MemoryAiOverlayToolException(this.message);

  final String message;

  @override
  String toString() => message;
}

const String _breakpointPauseOnHitOptionId = 'pause_process_on_hit';
const String _breakpointContinueOnHitOptionId = 'keep_process_running';
const String _confirmExecuteOptionId = 'confirm_execute';
const String _confirmCancelOptionId = 'cancel_execute';
const String _selectAllOptionId = 'select_all';
const String _breakpointAccessReadOptionId = 'breakpoint_access_read';
const String _breakpointAccessWriteOptionId = 'breakpoint_access_write';
const String _breakpointAccessReadWriteOptionId =
    'breakpoint_access_read_write';
const String _breakpointEnabledOptionId = 'breakpoint_enabled';
const String _breakpointDisabledOptionId = 'breakpoint_disabled';
const String _processPauseOptionId = 'process_pause';
const String _processResumeOptionId = 'process_resume';

Future<bool> _resolveBreakpointPauseProcessOnHit(
  MemoryAiOverlayToolRuntimeContext context,
  AiToolCall call, {
  AiToolProgressCallback? onProgress,
}) async {
  final explicitChoice = _getOptionalBoolOrNull(call, 'pauseProcessOnHit');
  if (explicitChoice != null) {
    return explicitChoice;
  }
  final title = context.isZh ? '等待用户确认' : 'Awaiting user confirmation';
  final description = context.isZh
      ? '断点命中后，是否立即暂停目标应用进程？'
      : 'Should the target process pause immediately when this breakpoint hits?';
  final options = <MemoryAiPendingInteractionOption>[
    MemoryAiPendingInteractionOption(
      id: _breakpointPauseOnHitOptionId,
      label: context.isZh ? '命中就暂停' : 'Pause on hit',
      description: context.isZh
          ? '每次命中断点都暂停目标进程，便于立即检查寄存器和上下文。'
          : 'Pause the target process on every hit so you can inspect context immediately.',
    ),
    MemoryAiPendingInteractionOption(
      id: _breakpointContinueOnHitOptionId,
      label: context.isZh ? '只记录不暂停' : 'Log only',
      description: context.isZh
          ? '断点继续记录命中，但不打断目标进程运行。'
          : 'Keep recording hits without interrupting the target process.',
    ),
  ];

  final selectedOptionId = await _requestUserChoiceForTool(
    context,
    toolName: 'add_memory_breakpoint',
    title: title,
    description: description,
    options: options,
    cancelLabel: context.isZh ? '取消本次创建' : 'Cancel breakpoint creation',
    onProgress: onProgress,
  );

  return selectedOptionId == _breakpointPauseOnHitOptionId;
}

Future<String> _requestUserChoiceForTool(
  MemoryAiOverlayToolRuntimeContext context, {
  required String toolName,
  required String title,
  required String description,
  required List<MemoryAiPendingInteractionOption> options,
  String? cancelLabel,
  AiToolProgressCallback? onProgress,
}) {
  onProgress?.call(
    _buildPendingInteractionProgress(
      context,
      title: title,
      description: description,
    ),
  );
  return context.requestUserChoice(
    toolName: toolName,
    title: title,
    description: description,
    options: options,
    cancelLabel: cancelLabel,
  );
}

Future<bool> _confirmDangerousAction(
  MemoryAiOverlayToolRuntimeContext context, {
  required String toolName,
  required String description,
  String? title,
  String? confirmLabel,
  String? cancelLabel,
  AiToolProgressCallback? onProgress,
}) async {
  final selected = await _requestUserChoiceForTool(
    context,
    toolName: toolName,
    title: title ?? (context.isZh ? '请确认是否执行' : 'Confirm action'),
    description: description,
    options: <MemoryAiPendingInteractionOption>[
      MemoryAiPendingInteractionOption(
        id: _confirmExecuteOptionId,
        label: confirmLabel ?? (context.isZh ? '确认执行' : 'Proceed'),
      ),
      MemoryAiPendingInteractionOption(
        id: _confirmCancelOptionId,
        label: cancelLabel ?? (context.isZh ? '取消本次操作' : 'Cancel action'),
      ),
    ],
    onProgress: onProgress,
  );
  return selected == _confirmExecuteOptionId;
}

String _buildPendingInteractionProgress(
  MemoryAiOverlayToolRuntimeContext context, {
  required String title,
  required String description,
}) {
  final normalizedDescription = description.trim();
  if (normalizedDescription.isEmpty) {
    return title;
  }
  return '$title\n$normalizedDescription';
}

Future<String> _buildProcessSummary(
  MemoryAiOverlayToolRuntimeContext context,
) async {
  final processPausedFuture = context.memoryActionRepository.isProcessPaused(
    pid: context.pid,
  );
  final frozenValuesFuture = context.memoryActionRepository
      .getFrozenMemoryValues();
  final searchSessionFuture = context.memoryQueryRepository
      .getSearchSessionState();
  final searchTaskFuture = context.memoryQueryRepository.getSearchTaskState();
  final breakpointStateFuture = context.memoryQueryRepository
      .getMemoryBreakpointState(pid: context.pid);
  final pointerSessionFuture = context.memoryPointerQueryRepository
      .getPointerScanSessionState();
  final pointerTaskFuture = context.memoryPointerQueryRepository
      .getPointerScanTaskState();
  final autoChaseFuture = context.memoryPointerAutoChaseQueryRepository
      .getPointerAutoChaseState();

  final processPaused = await processPausedFuture;
  final frozenValues = await frozenValuesFuture;
  final searchSession = await searchSessionFuture;
  final searchTask = await searchTaskFuture;
  final breakpointState = await breakpointStateFuture;
  final pointerSession = await pointerSessionFuture;
  final pointerTask = await pointerTaskFuture;
  final autoChaseState = await autoChaseFuture;

  final currentFrozenCount = frozenValues
      .where((value) => value.pid == context.pid)
      .length;

  return [
    '目标进程:',
    '- 进程名: ${context.processInfo.name}',
    '- 包名: ${context.processInfo.packageName}',
    '- PID: ${context.pid}',
    '- 当前是否暂停: ${processPaused ? "是" : "否"}',
    '- 冻结值数量: $currentFrozenCount',
    '',
    '搜索会话:',
    _formatSearchSessionState(searchSession, currentPid: context.pid),
    _formatSearchTaskState(searchTask),
    '',
    '断点状态:',
    _formatBreakpointState(breakpointState),
    '',
    '指针扫描:',
    _formatPointerScanSession(pointerSession, currentPid: context.pid),
    _formatPointerScanTask(pointerTask),
    '',
    '自动追链:',
    _formatPointerAutoChaseState(autoChaseState),
  ].join('\n').trim();
}

SearchValue _buildSearchValueFromToolCall(
  AiToolCall call, {
  required bool isFirstScan,
}) {
  final valueType = _normalizeLower(_getRequiredString(call, 'valueType'));
  final matchMode = _normalizeLower(
    _getOptionalString(call, 'matchMode', 'exact'),
  );
  final littleEndian = _getOptionalBool(call, 'littleEndian', true);
  final value = _getOptionalString(call, 'value', '').trim();
  final bytesMode = _normalizeLower(
    _getOptionalString(call, 'bytesMode', 'auto'),
  );
  final fuzzyMode = _normalizeLower(
    _getOptionalString(call, 'fuzzyMode', isFirstScan ? 'unknown' : 'changed'),
  );

  if (matchMode == 'fuzzy') {
    final numericType = _parseRawSearchValueType(valueType);
    if (numericType == SearchValueType.bytes) {
      throw ArgumentError('fuzzy 搜索仅支持数值类型');
    }
    final effectiveFuzzyMode = isFirstScan
        ? 'unknown'
        : (fuzzyMode == 'unknown' ? 'changed' : fuzzyMode);
    if (!_supportedFuzzyModes.contains(effectiveFuzzyMode)) {
      throw ArgumentError('不支持的 fuzzyMode: $effectiveFuzzyMode');
    }
    return SearchValue(
      type: numericType,
      textValue: '__jsx_fuzzy__:$effectiveFuzzyMode',
      littleEndian: littleEndian,
    );
  }

  if (value.isEmpty) {
    throw ArgumentError('value 不能为空');
  }

  switch (valueType) {
    case 'text':
      final bytes =
          bytesMode == 'utf16le' || (bytesMode == 'auto' && littleEndian)
          ? _encodeUtf16Le(value)
          : Uint8List.fromList(utf8.encode(value));
      final prefix =
          bytesMode == 'utf16le' || (bytesMode == 'auto' && littleEndian)
          ? '__jsx_text_utf16le__:'
          : '__jsx_text_utf8__:';
      return SearchValue(
        type: SearchValueType.bytes,
        textValue: '$prefix$value',
        bytesValue: bytes,
        littleEndian: littleEndian,
      );
    case 'xor':
      return SearchValue(
        type: SearchValueType.i32,
        textValue: '__jsx_xor__:$value',
        littleEndian: littleEndian,
      );
    case 'auto':
      return SearchValue(
        type: SearchValueType.bytes,
        textValue: '__jsx_auto__:$value',
        littleEndian: littleEndian,
      );
    case 'bytes':
      final resolvedMode = bytesMode == 'auto'
          ? (_looksLikeHexByteSequence(value) ? 'hex' : 'utf8')
          : bytesMode;
      if (resolvedMode == 'hex') {
        return SearchValue(
          type: SearchValueType.bytes,
          bytesValue: _parseHexBytes(value),
          littleEndian: littleEndian,
        );
      }
      final isUtf16Le = resolvedMode == 'utf16le';
      final bytes = isUtf16Le
          ? _encodeUtf16Le(value)
          : Uint8List.fromList(utf8.encode(value));
      return SearchValue(
        type: SearchValueType.bytes,
        textValue:
            '${isUtf16Le ? "__jsx_text_utf16le__:" : "__jsx_text_utf8__:"}$value',
        bytesValue: bytes,
        littleEndian: littleEndian,
      );
    default:
      return SearchValue(
        type: _parseRawSearchValueType(valueType),
        textValue: value,
        littleEndian: littleEndian,
      );
  }
}

SearchValue _buildWriteValueFromToolCall(AiToolCall call) {
  return _buildWriteValue(
    valueType: _normalizeLower(_getRequiredString(call, 'valueType')),
    rawValue: _getRequiredString(call, 'value').trim(),
    littleEndian: _getOptionalBool(call, 'littleEndian', true),
    bytesMode: _normalizeLower(_getOptionalString(call, 'bytesMode', 'auto')),
  );
}

SearchValue _buildWriteValue({
  required String valueType,
  required String rawValue,
  required bool littleEndian,
  required String bytesMode,
}) {
  final value = rawValue.trim();
  if (value.isEmpty) {
    throw ArgumentError('value 不能为空');
  }

  if (valueType == 'text') {
    final useUtf16Le =
        bytesMode == 'utf16le' || (bytesMode == 'auto' && littleEndian);
    final bytes = useUtf16Le
        ? _encodeUtf16Le(value)
        : Uint8List.fromList(utf8.encode(value));
    return SearchValue(
      type: SearchValueType.bytes,
      textValue:
          '${useUtf16Le ? "__jsx_text_utf16le__:" : "__jsx_text_utf8__:"}$value',
      bytesValue: bytes,
      littleEndian: littleEndian,
    );
  }

  if (valueType == 'bytes') {
    final resolvedMode = bytesMode == 'auto'
        ? (_looksLikeHexByteSequence(value) ? 'hex' : 'utf8')
        : bytesMode;
    if (resolvedMode == 'hex') {
      return SearchValue(
        type: SearchValueType.bytes,
        bytesValue: _parseHexBytes(value),
        littleEndian: littleEndian,
      );
    }
    final useUtf16Le = resolvedMode == 'utf16le';
    final bytes = useUtf16Le
        ? _encodeUtf16Le(value)
        : Uint8List.fromList(utf8.encode(value));
    return SearchValue(
      type: SearchValueType.bytes,
      textValue:
          '${useUtf16Le ? "__jsx_text_utf16le__:" : "__jsx_text_utf8__:"}$value',
      bytesValue: bytes,
      littleEndian: littleEndian,
    );
  }

  return SearchValue(
    type: _parseRawSearchValueType(valueType),
    textValue: value,
    littleEndian: littleEndian,
  );
}

Future<MemoryValuePreview?> _readValuePreviewOrNull(
  MemoryAiOverlayToolRuntimeContext context, {
  required int address,
  required SearchValueType type,
  required int length,
}) async {
  final previews = await context.memoryQueryRepository.readMemoryValues(
    requests: <MemoryReadRequest>[
      MemoryReadRequest(
        pid: context.pid,
        address: address,
        type: type,
        length: length,
      ),
    ],
  );
  if (previews.isEmpty) {
    return null;
  }
  return previews.first;
}

Future<MemoryInstructionPreview?> _readInstructionPreviewOrNull(
  MemoryAiOverlayToolRuntimeContext context, {
  required int address,
}) async {
  final previews = await context.memoryQueryRepository.disassembleMemory(
    pid: context.pid,
    addresses: <int>[address],
  );
  if (previews.isEmpty) {
    return null;
  }
  return previews.first;
}

Future<Map<int, MemoryValuePreview>> _readValuePreviewsForResults(
  MemoryAiOverlayToolRuntimeContext context,
  List<SearchResult> results,
) async {
  if (results.isEmpty) {
    return const <int, MemoryValuePreview>{};
  }
  final previews = await context.memoryQueryRepository.readMemoryValues(
    requests: results
        .map(
          (result) => MemoryReadRequest(
            pid: context.pid,
            address: result.address,
            type: result.type,
            length: _resolveReadLength(result.type, result.rawBytes.length),
          ),
        )
        .toList(growable: false),
  );
  return <int, MemoryValuePreview>{
    for (final preview in previews) preview.address: preview,
  };
}

int? _resolveWriteValueLength(SearchValue value) {
  if (value.type != SearchValueType.bytes) {
    return null;
  }
  final explicitBytes = value.bytesValue;
  if (explicitBytes != null && explicitBytes.isNotEmpty) {
    return explicitBytes.length;
  }
  final textValue = value.textValue?.trim();
  if (textValue == null || textValue.isEmpty) {
    return null;
  }
  if (textValue.startsWith('__jsx_text_utf16le__:')) {
    return _encodeUtf16Le(
      textValue.substring('__jsx_text_utf16le__:'.length),
    ).length;
  }
  if (textValue.startsWith('__jsx_text_utf8__:')) {
    return utf8.encode(textValue.substring('__jsx_text_utf8__:'.length)).length;
  }
  return null;
}

PointerScanRequest _buildPointerScanRequest(
  AiToolCall call,
  MemoryAiOverlayToolRuntimeContext context,
) {
  final pointerWidth = _getOptionalInt(call, 'pointerWidth', 8);
  final maxOffset = _parseFlexibleInt(
    _getRequiredString(call, 'maxOffset'),
    argumentName: 'maxOffset',
  );
  final alignment = _getOptionalInt(call, 'alignment', pointerWidth);
  return PointerScanRequest(
    pid: context.pid,
    targetAddress: _parseRequiredAddress(call, 'targetAddress'),
    pointerWidth: pointerWidth,
    maxOffset: maxOffset,
    alignment: alignment,
    rangeSectionKeys: _getStringList(call, 'rangeSectionKeys'),
    scanAllReadableRegions: _getOptionalBool(
      call,
      'scanAllReadableRegions',
      true,
    ),
  );
}

List<T> _slicePage<T>(
  List<T> items, {
  required int offset,
  required int limit,
}) {
  if (items.isEmpty || limit <= 0 || offset >= items.length) {
    return <T>[];
  }
  final safeOffset = offset < 0 ? 0 : offset;
  final end = safeOffset + limit > items.length
      ? items.length
      : safeOffset + limit;
  return items.sublist(safeOffset, end);
}

List<String> _resolveParallelStringValues({
  required List<int> addresses,
  required List<String> rawValues,
  required String argumentName,
}) {
  if (rawValues.length == 1) {
    return List<String>.filled(addresses.length, rawValues.first);
  }
  if (rawValues.length != addresses.length) {
    throw ArgumentError('$argumentName 长度必须为 1，或与 addresses 长度一致');
  }
  return rawValues;
}

Future<Map<int, _AddressMetadata>> _resolveAddressMetadataMap(
  MemoryAiOverlayToolRuntimeContext context,
  List<int> addresses, {
  required Map<int, MemoryToolSavedItem> existingItemsByAddress,
}) async {
  if (addresses.isEmpty) {
    return const <int, _AddressMetadata>{};
  }
  final metadata = <int, _AddressMetadata>{};
  final pendingAddresses = <int>{};
  for (final address in addresses) {
    final existing = existingItemsByAddress[address];
    if (existing != null) {
      metadata[address] = _AddressMetadata(
        regionStart: existing.regionStart,
        regionTypeKey: existing.regionTypeKey,
      );
    } else {
      pendingAddresses.add(address);
    }
  }
  if (pendingAddresses.isEmpty) {
    return metadata;
  }

  final regions = <MemoryRegion>[];
  var offset = 0;
  const pageSize = 200;
  while (true) {
    final page = await context.memoryQueryRepository.getMemoryRegions(
      pid: context.pid,
      offset: offset,
      limit: pageSize,
      readableOnly: false,
      includeAnonymous: true,
      includeFileBacked: true,
    );
    if (page.isEmpty) {
      break;
    }
    regions.addAll(page);
    offset += page.length;
    if (page.length < pageSize) {
      break;
    }
  }
  for (final address in pendingAddresses) {
    MemoryRegion? region;
    for (final candidate in regions) {
      if (address >= candidate.startAddress && address < candidate.endAddress) {
        region = candidate;
        break;
      }
    }
    metadata[address] = _AddressMetadata(
      regionStart: region?.startAddress ?? address,
      regionTypeKey: region == null ? 'other' : _mapRegionTypeKey(region),
    );
  }
  return metadata;
}

String _mapRegionTypeKey(MemoryRegion region) {
  final lowerPath = (region.path ?? '').toLowerCase();
  final executable = region.perms.length > 2 && region.perms[2] == 'x';
  final isAppPath =
      lowerPath.startsWith('/data/app/') ||
      lowerPath.startsWith('/data/data/') ||
      lowerPath.startsWith('/mnt/expand/');
  final isSystemPath =
      lowerPath.startsWith('/system/') ||
      lowerPath.startsWith('/apex/') ||
      lowerPath.startsWith('/vendor/') ||
      lowerPath.startsWith('/product/');

  if (region.perms.isEmpty || region.perms[0] != 'r') {
    return 'bad';
  }
  if (lowerPath.contains('[stack')) {
    return 'stack';
  }
  if (lowerPath.contains('ashmem')) {
    return lowerPath.contains('dalvik') ? 'javaHeap' : 'ashmem';
  }
  if (lowerPath.contains('dalvik-main space') ||
      lowerPath.contains('dalvik-allocspace') ||
      lowerPath.contains('dalvik-large object space') ||
      lowerPath.contains('dalvik-free list large object space') ||
      lowerPath.contains('dalvik-non moving space') ||
      lowerPath.contains('dalvik-zygote space')) {
    return 'javaHeap';
  }
  if (lowerPath.contains('dalvik') ||
      lowerPath.contains('.art') ||
      lowerPath.contains('.oat') ||
      lowerPath.contains('.odex')) {
    return 'java';
  }
  if (lowerPath.contains('[heap]')) {
    return 'cHeap';
  }
  if (lowerPath.contains('malloc') ||
      lowerPath.contains('scudo:') ||
      lowerPath.contains('jemalloc') ||
      lowerPath.contains('[anon:libc_malloc]')) {
    return 'cAlloc';
  }
  if (lowerPath.contains('.bss') || lowerPath.contains('[anon:.bss')) {
    return 'cBss';
  }
  if (executable) {
    if (isAppPath) {
      return 'codeApp';
    }
    if (isSystemPath || !region.isAnonymous) {
      return 'codeSys';
    }
  }
  if (!region.isAnonymous) {
    if (isAppPath || isSystemPath || lowerPath.contains('.so')) {
      return 'cData';
    }
    return 'other';
  }
  return 'anonymous';
}

String _formatRegion(MemoryRegion region) {
  final endExclusive = region.endAddress;
  final path = region.path?.trim();
  return [
    '${_formatAddress(region.startAddress)}-${_formatAddress(endExclusive)}',
    'size=${_formatByteCount(region.size)}',
    'perms=${region.perms}',
    'anonymous=${region.isAnonymous}',
    if (path != null && path.isNotEmpty) 'path=$path',
  ].join(' | ');
}

String _formatSavedItem(MemoryToolSavedItem item) {
  return [
    _formatAddress(item.address),
    'regionStart=${_formatAddress(item.regionStart)}',
    'regionType=${item.regionTypeKey}',
    'type=${item.type.name}',
    'value=${item.isInstructionPatch ? item.effectiveInstructionText : item.displayValue}',
    'hex=${_formatHex(item.rawBytes)}',
    'frozen=${item.isFrozen}',
    'instructionPatch=${item.isInstructionPatch}',
  ].join(' | ');
}

String _formatSearchSessionState(
  SearchSessionState state, {
  required int currentPid,
}) {
  if (!state.hasActiveSession) {
    return '- 当前没有活动搜索会话';
  }
  return [
    '- hasActiveSession: true',
    '- pid: ${state.pid}${state.pid == currentPid ? " (当前进程)" : " (其他进程)"}',
    '- resultCount: ${state.resultCount}',
    '- littleEndian: ${state.littleEndian}',
  ].join('\n');
}

String _formatSearchTaskState(SearchTaskState state) {
  final message = _normalizeTaskMessage(
    state.message,
    domain: _TaskMessageDomain.search,
  );
  return [
    '- status: ${state.status.name}',
    '- processedRegions: ${state.processedRegions}/${state.totalRegions}',
    '- processedBytes: ${state.processedBytes}/${state.totalBytes}',
    '- resultCount: ${state.resultCount}',
    '- elapsedMs: ${state.elapsedMilliseconds}',
    '- canCancel: ${state.canCancel}',
    if (message.isNotEmpty) '- message: $message',
  ].join('\n');
}

String _formatSearchResult(SearchResult result) {
  return [
    _formatAddress(result.address),
    'regionStart=${_formatAddress(result.regionStart)}',
    'regionType=${result.regionTypeKey}',
    'type=${result.type.name}',
    'value=${result.displayValue}',
    'hex=${_formatHex(result.rawBytes)}',
  ].join(' | ');
}

String _formatValuePreview(MemoryValuePreview preview) {
  return [
    _formatAddress(preview.address),
    'type=${preview.type.name}',
    'value=${preview.displayValue}',
    'hex=${_formatHex(preview.rawBytes)}',
  ].join(' | ');
}

String _formatInstructionPreview(MemoryInstructionPreview preview) {
  return [
    _formatAddress(preview.address),
    'arch=${preview.architecture}',
    'size=${preview.instructionSize}',
    'bytes=${_formatHex(preview.rawBytes)}',
    'asm=${preview.instructionText}',
  ].join(' | ');
}

String _formatFrozenMemoryValue(FrozenMemoryValue value) {
  return [
    _formatAddress(value.address),
    'type=${value.type.name}',
    'value=${value.displayValue}',
    'hex=${_formatHex(value.rawBytes)}',
  ].join(' | ');
}

String _formatValueHistoryEntry(MemoryToolValueHistoryEntryState entry) {
  return [
    _formatAddress(entry.address),
    'type=${entry.type.name}',
    'value=${entry.displayValue}',
    'hex=${_formatHex(entry.rawBytes)}',
  ].join(' | ');
}

String _formatInstructionHistoryEntry(MemoryToolInstructionHistoryEntry entry) {
  return [
    _formatAddress(entry.address),
    'previous=${entry.previousDisplayValue}',
    'hex=${_formatHex(entry.previousBytes)}',
  ].join(' | ');
}

String _formatBreakpointState(MemoryBreakpointState state) {
  return [
    '- isSupported: ${state.isSupported}',
    '- isProcessPaused: ${state.isProcessPaused}',
    '- activeBreakpointCount: ${state.activeBreakpointCount}',
    '- pendingHitCount: ${state.pendingHitCount}',
    '- architecture: ${state.architecture}',
    if (state.lastError.trim().isNotEmpty)
      '- lastError: ${state.lastError.trim()}',
  ].join('\n');
}

String _formatBreakpoint(MemoryBreakpoint breakpoint) {
  return [
    'id=${breakpoint.id}',
    'address=${_formatAddress(breakpoint.address)}',
    'type=${breakpoint.type.name}',
    'length=${breakpoint.length}',
    'access=${_formatBreakpointAccessType(breakpoint.accessType)}',
    'enabled=${breakpoint.enabled}',
    'pauseOnHit=${breakpoint.pauseProcessOnHit}',
    'hitCount=${breakpoint.hitCount}',
    if (breakpoint.lastHitAtMillis != null)
      'lastHit=${breakpoint.lastHitAtMillis}',
    if (breakpoint.lastError.trim().isNotEmpty)
      'lastError=${breakpoint.lastError.trim()}',
  ].join(' | ');
}

String _formatBreakpointHit(MemoryBreakpointHit hit) {
  return [
    'breakpointId=${hit.breakpointId}',
    'address=${_formatAddress(hit.address)}',
    'access=${_formatBreakpointAccessType(hit.accessType)}',
    'threadId=${hit.threadId}',
    'time=${hit.timestampMillis}',
    'old=${_formatHex(hit.oldValue)}',
    'new=${_formatHex(hit.newValue)}',
    'pc=${_formatAddress(hit.pc)}',
    'module=${hit.moduleName}',
    'moduleOffset=${_formatAddress(hit.moduleOffset)}',
    'instruction=${hit.instructionText}',
  ].join(' | ');
}

Future<MemoryBreakpointAccessType> _resolveBreakpointAccessType(
  MemoryAiOverlayToolRuntimeContext context,
  AiToolCall call, {
  AiToolProgressCallback? onProgress,
}) async {
  final explicitValue = _getOptionalStringOrNull(call, 'accessType');
  if (explicitValue != null) {
    return _parseBreakpointAccessType(explicitValue);
  }

  final selected = await _requestUserChoiceForTool(
    context,
    toolName: 'add_memory_breakpoint',
    title: context.isZh ? '选择断点触发方式' : 'Choose breakpoint access type',
    description: context.isZh
        ? '当前没有明确指定 accessType，需要你决定断点监听读、写，还是读写都监听。'
        : 'No explicit accessType was provided. Choose whether the breakpoint should watch reads, writes, or both.',
    options: <MemoryAiPendingInteractionOption>[
      MemoryAiPendingInteractionOption(
        id: _breakpointAccessReadOptionId,
        label: 'read',
        description: context.isZh
            ? '仅在读取该地址时触发。'
            : 'Trigger only when this address is read.',
      ),
      MemoryAiPendingInteractionOption(
        id: _breakpointAccessWriteOptionId,
        label: 'write',
        description: context.isZh
            ? '仅在写入该地址时触发。'
            : 'Trigger only when this address is written.',
      ),
      MemoryAiPendingInteractionOption(
        id: _breakpointAccessReadWriteOptionId,
        label: 'readWrite',
        description: context.isZh
            ? '读写该地址时都触发。'
            : 'Trigger on both reads and writes.',
      ),
    ],
    cancelLabel: context.isZh ? '取消本次创建' : 'Cancel breakpoint creation',
    onProgress: onProgress,
  );

  return switch (selected) {
    _breakpointAccessReadOptionId => MemoryBreakpointAccessType.read,
    _breakpointAccessWriteOptionId => MemoryBreakpointAccessType.write,
    _breakpointAccessReadWriteOptionId => MemoryBreakpointAccessType.readWrite,
    _ => throw const _MemoryAiOverlayToolException('未选择有效的断点访问方式。'),
  };
}

Future<bool> _resolveBreakpointEnabled(
  MemoryAiOverlayToolRuntimeContext context,
  AiToolCall call, {
  AiToolProgressCallback? onProgress,
}) async {
  final explicitValue = _getOptionalBoolOrNull(call, 'enabled');
  if (explicitValue != null) {
    return explicitValue;
  }

  final selected = await _requestUserChoiceForTool(
    context,
    toolName: 'add_memory_breakpoint',
    title: context.isZh ? '选择断点初始状态' : 'Choose initial breakpoint state',
    description: context.isZh
        ? '当前没有明确指定 enabled，需要决定断点创建后是立即启用，还是先保留为禁用状态。'
        : 'No explicit enabled flag was provided. Choose whether the breakpoint should start enabled or disabled.',
    options: <MemoryAiPendingInteractionOption>[
      MemoryAiPendingInteractionOption(
        id: _breakpointEnabledOptionId,
        label: context.isZh ? '创建后立即启用' : 'Enable immediately',
        description: context.isZh
            ? '断点创建成功后立刻开始生效。'
            : 'The breakpoint becomes active immediately after creation.',
      ),
      MemoryAiPendingInteractionOption(
        id: _breakpointDisabledOptionId,
        label: context.isZh ? '先创建为禁用' : 'Create disabled',
        description: context.isZh
            ? '先保存断点配置，但暂时不生效。'
            : 'Create the breakpoint but keep it inactive for now.',
      ),
    ],
    cancelLabel: context.isZh ? '取消本次创建' : 'Cancel breakpoint creation',
    onProgress: onProgress,
  );

  return selected == _breakpointEnabledOptionId;
}

Future<String> _resolveBreakpointId(
  MemoryAiOverlayToolRuntimeContext context, {
  required String toolName,
  required String argumentName,
  required String title,
  required String description,
  AiToolCall? call,
  AiToolProgressCallback? onProgress,
}) async {
  final explicitValue = call == null
      ? null
      : _getOptionalStringOrNull(call, argumentName);
  if (explicitValue != null) {
    return explicitValue;
  }

  final breakpoints = await context.memoryQueryRepository.listMemoryBreakpoints(
    pid: context.pid,
  );
  if (breakpoints.isEmpty) {
    throw const _MemoryAiOverlayToolException('当前进程没有可操作的断点。');
  }
  if (breakpoints.length == 1) {
    return breakpoints.single.id;
  }

  final selected = await _requestUserChoiceForTool(
    context,
    toolName: toolName,
    title: title,
    description: description,
    options: breakpoints
        .map(
          (breakpoint) => MemoryAiPendingInteractionOption(
            id: breakpoint.id,
            label:
                '${breakpoint.id} · ${_formatAddress(breakpoint.address)} · ${_formatBreakpointAccessType(breakpoint.accessType)}',
            description:
                'enabled=${breakpoint.enabled} | pauseOnHit=${breakpoint.pauseProcessOnHit} | hitCount=${breakpoint.hitCount}',
          ),
        )
        .toList(growable: false),
    cancelLabel: context.isZh ? '取消本次操作' : 'Cancel this action',
    onProgress: onProgress,
  );
  return selected;
}

Future<List<int>> _resolveAddressesFromChoices(
  MemoryAiOverlayToolRuntimeContext context, {
  required String toolName,
  required String title,
  required String description,
  required List<int> availableAddresses,
  required String Function(int address) labelBuilder,
  String? Function(int address)? descriptionBuilder,
  bool allowSelectAll = true,
  AiToolProgressCallback? onProgress,
}) async {
  if (availableAddresses.isEmpty) {
    throw const _MemoryAiOverlayToolException('当前没有可供选择的地址。');
  }
  if (availableAddresses.length == 1) {
    return <int>[availableAddresses.single];
  }

  final options = <MemoryAiPendingInteractionOption>[
    if (allowSelectAll)
      MemoryAiPendingInteractionOption(
        id: _selectAllOptionId,
        label: context.isZh ? '对全部地址执行' : 'Apply to all addresses',
        description: context.isZh
            ? '一次性对当前可用的全部地址执行此操作。'
            : 'Apply this action to all currently available addresses.',
      ),
    ...availableAddresses.map(
      (address) => MemoryAiPendingInteractionOption(
        id: address.toString(),
        label: labelBuilder(address),
        description: descriptionBuilder?.call(address),
      ),
    ),
  ];

  final selected = await _requestUserChoiceForTool(
    context,
    toolName: toolName,
    title: title,
    description: description,
    options: options,
    cancelLabel: context.isZh ? '取消本次操作' : 'Cancel this action',
    onProgress: onProgress,
  );

  if (selected == _selectAllOptionId) {
    return List<int>.from(availableAddresses);
  }
  final parsed = int.tryParse(selected);
  if (parsed == null) {
    throw const _MemoryAiOverlayToolException('未选择有效地址。');
  }
  return <int>[parsed];
}

Future<bool> _resolvePausedTargetChoice(
  MemoryAiOverlayToolRuntimeContext context,
  AiToolCall call, {
  AiToolProgressCallback? onProgress,
}) async {
  final explicitValue = _getOptionalBoolOrNull(call, 'paused');
  if (explicitValue != null) {
    return explicitValue;
  }

  final selected = await _requestUserChoiceForTool(
    context,
    toolName: 'set_process_paused',
    title: context.isZh ? '选择进程状态' : 'Choose process state',
    description: context.isZh
        ? '当前没有明确指定 paused，需要决定是暂停进程，还是恢复进程运行。'
        : 'No explicit paused flag was provided. Choose whether to pause the process or resume it.',
    options: <MemoryAiPendingInteractionOption>[
      MemoryAiPendingInteractionOption(
        id: _processPauseOptionId,
        label: context.isZh ? '暂停进程' : 'Pause process',
        description: context.isZh
            ? '立即挂起当前目标进程。'
            : 'Suspend the current target process immediately.',
      ),
      MemoryAiPendingInteractionOption(
        id: _processResumeOptionId,
        label: context.isZh ? '恢复运行' : 'Resume process',
        description: context.isZh
            ? '让当前目标进程继续执行。'
            : 'Allow the current target process to continue running.',
      ),
    ],
    cancelLabel: context.isZh ? '取消本次操作' : 'Cancel this action',
    onProgress: onProgress,
  );
  return selected == _processPauseOptionId;
}

String _formatAddressPreview(List<int> addresses, {int maxItems = 3}) {
  if (addresses.isEmpty) {
    return '-';
  }
  final preview = addresses
      .take(maxItems)
      .map(_formatAddress)
      .toList(growable: false)
      .join(', ');
  if (addresses.length <= maxItems) {
    return preview;
  }
  return '$preview ... (${addresses.length} total)';
}

String _formatPendingValuePreview(String value, {int maxLength = 32}) {
  final normalized = value.trim();
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return '${normalized.substring(0, maxLength)}...';
}

String _formatPointerScanSession(
  PointerScanSessionState state, {
  required int currentPid,
}) {
  if (!state.hasActiveSession) {
    return '- 当前没有活动指针扫描会话';
  }
  return [
    '- hasActiveSession: true',
    '- pid: ${state.pid}${state.pid == currentPid ? " (当前进程)" : " (其他进程)"}',
    '- targetAddress: ${_formatAddress(state.targetAddress)}',
    '- pointerWidth: ${state.pointerWidth}',
    '- maxOffset: ${_formatAddress(state.maxOffset)}',
    '- alignment: ${state.alignment}',
    '- regionCount: ${state.regionCount}',
    '- resultCount: ${state.resultCount}',
  ].join('\n');
}

String _formatPointerScanTask(PointerScanTaskState state) {
  final message = _normalizeTaskMessage(
    state.message,
    domain: _TaskMessageDomain.pointerScan,
  );
  return [
    '- status: ${state.status.name}',
    '- processedRegions: ${state.processedRegions}/${state.totalRegions}',
    '- processedEntries: ${state.processedEntries}/${state.totalEntries}',
    '- processedBytes: ${state.processedBytes}/${state.totalBytes}',
    '- resultCount: ${state.resultCount}',
    '- elapsedMs: ${state.elapsedMilliseconds}',
    '- canCancel: ${state.canCancel}',
    if (message.isNotEmpty) '- message: $message',
  ].join('\n');
}

String _formatPointerResult(PointerScanResult result) {
  return [
    'pointer=${_formatAddress(result.pointerAddress)}',
    'base=${_formatAddress(result.baseAddress)}',
    'target=${_formatAddress(result.targetAddress)}',
    'offset=${_formatAddress(result.offset)}',
    'regionStart=${_formatAddress(result.regionStart)}',
    'regionType=${result.regionTypeKey}',
  ].join(' | ');
}

String _formatPointerChaseHint(PointerScanChaseHint hint) {
  return [
    'isTerminalStaticCandidate=${hint.isTerminalStaticCandidate}',
    'stopReasonKey=${hint.stopReasonKey}',
    if (hint.result != null) 'result=${_formatPointerResult(hint.result!)}',
  ].join('\n');
}

String _formatPointerAutoChaseState(PointerAutoChaseState state) {
  final message = _normalizeTaskMessage(
    state.message,
    domain: _TaskMessageDomain.autoChase,
  );
  final buffer = StringBuffer()
    ..writeln('- isRunning: ${state.isRunning}')
    ..writeln('- pid: ${state.pid}')
    ..writeln('- currentDepth: ${state.currentDepth}/${state.maxDepth}');
  if (message.isNotEmpty) {
    buffer.writeln('- message: $message');
  }
  if (state.layers.isEmpty) {
    buffer.writeln('- 当前没有追链层数据');
    return buffer.toString().trim();
  }
  buffer.writeln('- layers: ${state.layers.length}');
  for (final layer in state.layers) {
    buffer.writeln(
      '  - layer=${layer.layerIndex} target=${_formatAddress(layer.targetAddress)} selectedPointer=${layer.selectedPointerAddress == null ? "-" : _formatAddress(layer.selectedPointerAddress!)} resultCount=${layer.resultCount} hasMore=${layer.hasMore} terminal=${layer.isTerminalLayer} stopReason=${layer.stopReasonKey}',
    );
  }
  return buffer.toString().trim();
}

MemoryBreakpointAccessType _parseBreakpointAccessType(String rawValue) {
  return switch (_normalizeLower(rawValue)) {
    'read' => MemoryBreakpointAccessType.read,
    'write' => MemoryBreakpointAccessType.write,
    'readwrite' => MemoryBreakpointAccessType.readWrite,
    _ => throw ArgumentError('不支持的 accessType: $rawValue'),
  };
}

SearchValueType _parseRawSearchValueType(String rawValue) {
  return switch (_normalizeLower(rawValue)) {
    'i8' => SearchValueType.i8,
    'i16' => SearchValueType.i16,
    'i32' => SearchValueType.i32,
    'i64' => SearchValueType.i64,
    'f32' => SearchValueType.f32,
    'f64' => SearchValueType.f64,
    'bytes' || 'text' => SearchValueType.bytes,
    _ => throw ArgumentError('不支持的 valueType: $rawValue'),
  };
}

String _formatBreakpointAccessType(MemoryBreakpointAccessType type) {
  return switch (type) {
    MemoryBreakpointAccessType.read => 'read',
    MemoryBreakpointAccessType.write => 'write',
    MemoryBreakpointAccessType.readWrite => 'readWrite',
  };
}

int _resolveReadLength(SearchValueType type, int? explicitLength) {
  if (explicitLength != null && explicitLength > 0) {
    return explicitLength;
  }
  return switch (type) {
    SearchValueType.i8 => 1,
    SearchValueType.i16 => 2,
    SearchValueType.i32 || SearchValueType.f32 => 4,
    SearchValueType.i64 || SearchValueType.f64 => 8,
    SearchValueType.bytes => 16,
  };
}

int _parseRequiredAddress(AiToolCall call, String key) {
  return _parseFlexibleInt(_getRequiredString(call, key), argumentName: key);
}

List<int> _parseAddressList(AiToolCall call, String key) {
  return _getStringList(call, key)
      .map((value) => _parseFlexibleInt(value, argumentName: key))
      .toList(growable: false);
}

List<int>? _parseOptionalAddressList(AiToolCall call, String key) {
  final rawValues = _getStringList(call, key);
  if (rawValues.isEmpty) {
    return null;
  }
  return rawValues
      .map((value) => _parseFlexibleInt(value, argumentName: key))
      .toList(growable: false);
}

String _getRequiredString(AiToolCall call, String key) {
  final raw = call.arguments[key];
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) {
    throw ArgumentError('$key 不能为空');
  }
  return value;
}

String _getOptionalString(AiToolCall call, String key, String defaultValue) {
  final raw = call.arguments[key];
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) {
    return defaultValue;
  }
  return value;
}

String? _getOptionalStringOrNull(AiToolCall call, String key) {
  final raw = call.arguments[key];
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

int _getOptionalInt(AiToolCall call, String key, int defaultValue) {
  final value = _getOptionalIntOrNull(call, key);
  return value ?? defaultValue;
}

int? _getOptionalIntOrNull(AiToolCall call, String key) {
  final raw = call.arguments[key];
  if (raw == null) {
    return null;
  }
  if (raw is int) {
    return raw;
  }
  return int.tryParse(raw.toString().trim());
}

bool _getRequiredBool(AiToolCall call, String key) {
  final raw = call.arguments[key];
  if (raw is bool) {
    return raw;
  }
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  throw ArgumentError('$key 必须是布尔值');
}

bool _getOptionalBool(AiToolCall call, String key, bool defaultValue) {
  final raw = call.arguments[key];
  if (raw == null) {
    return defaultValue;
  }
  if (raw is bool) {
    return raw;
  }
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return defaultValue;
}

bool? _getOptionalBoolOrNull(AiToolCall call, String key) {
  final raw = call.arguments[key];
  if (raw == null) {
    return null;
  }
  if (raw is bool) {
    return raw;
  }
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return null;
}

List<String> _getStringList(AiToolCall call, String key) {
  final raw = call.arguments[key];
  if (raw is List) {
    return raw.map((value) => value.toString()).toList(growable: false);
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

int _parseFlexibleInt(String rawValue, {required String argumentName}) {
  final value = rawValue.trim();
  if (value.isEmpty) {
    throw ArgumentError('$argumentName 不能为空');
  }
  final normalized = value.toLowerCase().startsWith('0x')
      ? value.substring(2)
      : value;
  final radix = value.toLowerCase().startsWith('0x') ? 16 : 10;
  final parsed = int.tryParse(normalized, radix: radix);
  if (parsed == null) {
    throw ArgumentError('$argumentName 不是合法整数: $rawValue');
  }
  return parsed;
}

String _normalizeLower(String value) {
  return value.trim().toLowerCase();
}

String _formatAddress(int value) {
  return '0x${value.toRadixString(16).toUpperCase()}';
}

String _formatByteCount(int value) {
  if (value >= 1024 * 1024) {
    return '${(value / (1024 * 1024)).toStringAsFixed(2)}MB';
  }
  if (value >= 1024) {
    return '${(value / 1024).toStringAsFixed(2)}KB';
  }
  return '${value}B';
}

String _formatHex(Uint8List bytes) {
  if (bytes.isEmpty) {
    return '(empty)';
  }
  return bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

bool _looksLikeHexByteSequence(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return false;
  }
  final sanitized = normalized
      .replaceAll(RegExp(r'0x', caseSensitive: false), '')
      .replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  return sanitized.isNotEmpty && sanitized.length.isEven;
}

Uint8List _parseHexBytes(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'0x', caseSensitive: false), '')
      .replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (sanitized.isEmpty || sanitized.length.isOdd) {
    throw const FormatException('非法字节序列');
  }
  final bytes = <int>[];
  for (var index = 0; index < sanitized.length; index += 2) {
    final byte = int.tryParse(sanitized.substring(index, index + 2), radix: 16);
    if (byte == null) {
      throw const FormatException('非法字节序列');
    }
    bytes.add(byte);
  }
  return Uint8List.fromList(bytes);
}

Uint8List _encodeUtf16Le(String value) {
  final bytes = <int>[];
  for (final unit in value.codeUnits) {
    bytes.add(unit & 0xFF);
    bytes.add((unit >> 8) & 0xFF);
  }
  return Uint8List.fromList(bytes);
}

Future<SearchTaskState> _waitForSearchTaskToSettle(
  MemoryAiOverlayToolRuntimeContext context, {
  required String title,
  AiToolProgressCallback? onProgress,
  _BackgroundActionTracker? startTracker,
}) async {
  const timeout = Duration(minutes: 5);
  const pollInterval = Duration(milliseconds: 400);
  const startupGrace = Duration(seconds: 2);
  final startedAt = DateTime.now();
  var observedRunning = false;
  String? lastProgressContent;

  while (true) {
    startTracker?.throwIfFailed();
    final latest = await context.memoryQueryRepository.getSearchTaskState();
    final session = await context.memoryQueryRepository.getSearchSessionState();
    if (latest.status == SearchTaskStatus.running) {
      observedRunning = true;
    }
    final progressContent = _buildSearchTaskProgressResult(
      context: context,
      title: title,
      task: latest,
      session: session,
    );
    if (progressContent != lastProgressContent) {
      lastProgressContent = progressContent;
      onProgress?.call(progressContent);
    }

    final elapsed = DateTime.now().difference(startedAt);
    final isTerminal =
        latest.status == SearchTaskStatus.completed ||
        latest.status == SearchTaskStatus.cancelled ||
        latest.status == SearchTaskStatus.failed;

    if (isTerminal && (observedRunning || elapsed >= startupGrace)) {
      startTracker?.throwIfFailed();
      return latest;
    }
    if (latest.status == SearchTaskStatus.idle && elapsed < startupGrace) {
      await Future.delayed(pollInterval);
      continue;
    }
    if (latest.status != SearchTaskStatus.running &&
        latest.status != SearchTaskStatus.idle) {
      return latest;
    }
    if (elapsed >= timeout) {
      throw const _MemoryAiOverlayToolException('等待搜索任务完成超时。');
    }
    await Future.delayed(pollInterval);
  }
}

Future<PointerScanTaskState> _waitForPointerScanTaskToSettle(
  MemoryAiOverlayToolRuntimeContext context, {
  AiToolProgressCallback? onProgress,
  _BackgroundActionTracker? startTracker,
}) async {
  const timeout = Duration(minutes: 5);
  const pollInterval = Duration(milliseconds: 400);
  const startupGrace = Duration(seconds: 2);
  final startedAt = DateTime.now();
  var observedRunning = false;
  String? lastProgressContent;

  while (true) {
    startTracker?.throwIfFailed();
    final latest = await context.memoryPointerQueryRepository
        .getPointerScanTaskState();
    final session = await context.memoryPointerQueryRepository
        .getPointerScanSessionState();
    if (latest.status == SearchTaskStatus.running) {
      observedRunning = true;
    }
    final progressContent = _buildPointerScanProgressResult(
      context: context,
      task: latest,
      session: session,
    );
    if (progressContent != lastProgressContent) {
      lastProgressContent = progressContent;
      onProgress?.call(progressContent);
    }

    final elapsed = DateTime.now().difference(startedAt);
    final isTerminal =
        latest.status == SearchTaskStatus.completed ||
        latest.status == SearchTaskStatus.cancelled ||
        latest.status == SearchTaskStatus.failed;

    if (isTerminal && (observedRunning || elapsed >= startupGrace)) {
      startTracker?.throwIfFailed();
      return latest;
    }
    if (latest.status == SearchTaskStatus.idle && elapsed < startupGrace) {
      await Future.delayed(pollInterval);
      continue;
    }
    if (latest.status != SearchTaskStatus.running &&
        latest.status != SearchTaskStatus.idle) {
      return latest;
    }
    if (elapsed >= timeout) {
      throw const _MemoryAiOverlayToolException('等待指针扫描完成超时。');
    }
    await Future.delayed(pollInterval);
  }
}

Future<PointerAutoChaseState> _waitForPointerAutoChaseToSettle(
  MemoryAiOverlayToolRuntimeContext context, {
  AiToolProgressCallback? onProgress,
  _BackgroundActionTracker? startTracker,
}) async {
  const timeout = Duration(minutes: 5);
  const pollInterval = Duration(milliseconds: 400);
  const startupGrace = Duration(seconds: 2);
  final startedAt = DateTime.now();
  var observedRunning = false;
  String? lastProgressContent;

  while (true) {
    startTracker?.throwIfFailed();
    final latest = await context.memoryPointerAutoChaseQueryRepository
        .getPointerAutoChaseState();
    if (latest.isRunning) {
      observedRunning = true;
    }
    final progressContent = _buildPointerAutoChaseProgressResult(latest);
    if (progressContent != lastProgressContent) {
      lastProgressContent = progressContent;
      onProgress?.call(progressContent);
    }

    final elapsed = DateTime.now().difference(startedAt);
    if (!latest.isRunning && (observedRunning || elapsed >= startupGrace)) {
      startTracker?.throwIfFailed();
      return latest;
    }
    if (elapsed >= timeout) {
      throw const _MemoryAiOverlayToolException('等待自动追链完成超时。');
    }
    await Future.delayed(pollInterval);
  }
}

_BackgroundActionTracker _trackBackgroundAction(Future<void> future) {
  final tracker = _BackgroundActionTracker();
  unawaited(
    future
        .then(tracker.complete)
        .catchError(tracker.completeError, test: (_) => true),
  );
  return tracker;
}

class _BackgroundActionTracker {
  bool _isCompleted = false;
  Object? _error;
  StackTrace? _stackTrace;

  bool get isCompleted => _isCompleted;

  void complete([Object? _]) {
    _isCompleted = true;
  }

  void completeError(Object error, StackTrace stackTrace) {
    _error = error;
    _stackTrace = stackTrace;
    _isCompleted = true;
  }

  void throwIfFailed() {
    if (!_isCompleted || _error == null) {
      return;
    }
    Error.throwWithStackTrace(_error!, _stackTrace ?? StackTrace.current);
  }
}

String _buildSearchTaskCompletionResult({
  required MemoryAiOverlayToolRuntimeContext context,
  required String title,
  required SearchTaskState task,
  required SearchSessionState session,
}) {
  final summary = switch (task.status) {
    SearchTaskStatus.completed => '$title已完成。',
    SearchTaskStatus.cancelled => '$title已取消。',
    SearchTaskStatus.failed => '$title失败。',
    SearchTaskStatus.running => '$title仍在运行。',
    SearchTaskStatus.idle => '$title未开始。',
  };
  return [
    summary,
    '搜索会话：',
    _formatSearchSessionState(session, currentPid: context.pid),
    '搜索任务：',
    _formatSearchTaskState(task),
  ].join('\n');
}

String _buildSearchTaskProgressResult({
  required MemoryAiOverlayToolRuntimeContext context,
  required String title,
  required SearchTaskState task,
  required SearchSessionState session,
}) {
  final summary = switch (task.status) {
    SearchTaskStatus.running => '$title进行中。',
    SearchTaskStatus.completed => '$title已完成。',
    SearchTaskStatus.cancelled => '$title已取消。',
    SearchTaskStatus.failed => '$title失败。',
    SearchTaskStatus.idle => '$title准备中。',
  };
  return [
    summary,
    '搜索会话：',
    _formatSearchSessionState(session, currentPid: context.pid),
    '搜索任务：',
    _formatSearchTaskState(task),
  ].join('\n');
}

String _buildPointerScanCompletionResult({
  required MemoryAiOverlayToolRuntimeContext context,
  required PointerScanTaskState task,
  required PointerScanSessionState session,
}) {
  final summary = switch (task.status) {
    SearchTaskStatus.completed => '指针扫描已完成。',
    SearchTaskStatus.cancelled => '指针扫描已取消。',
    SearchTaskStatus.failed => '指针扫描失败。',
    SearchTaskStatus.running => '指针扫描仍在运行。',
    SearchTaskStatus.idle => '指针扫描未开始。',
  };
  return [
    summary,
    '指针扫描会话：',
    _formatPointerScanSession(session, currentPid: context.pid),
    '指针扫描任务：',
    _formatPointerScanTask(task),
  ].join('\n');
}

String _buildPointerScanProgressResult({
  required MemoryAiOverlayToolRuntimeContext context,
  required PointerScanTaskState task,
  required PointerScanSessionState session,
}) {
  final summary = switch (task.status) {
    SearchTaskStatus.running => '指针扫描进行中。',
    SearchTaskStatus.completed => '指针扫描已完成。',
    SearchTaskStatus.cancelled => '指针扫描已取消。',
    SearchTaskStatus.failed => '指针扫描失败。',
    SearchTaskStatus.idle => '指针扫描准备中。',
  };
  return [
    summary,
    '指针扫描会话：',
    _formatPointerScanSession(session, currentPid: context.pid),
    '指针扫描任务：',
    _formatPointerScanTask(task),
  ].join('\n');
}

String _buildPointerAutoChaseCompletionResult(PointerAutoChaseState state) {
  final summary = state.isRunning ? '自动指针追链仍在运行。' : '自动指针追链已完成。';
  return [summary, '自动追链：', _formatPointerAutoChaseState(state)].join('\n');
}

String _buildPointerAutoChaseProgressResult(PointerAutoChaseState state) {
  final summary = state.isRunning ? '自动指针追链进行中。' : '自动指针追链已完成。';
  return [summary, '自动追链：', _formatPointerAutoChaseState(state)].join('\n');
}

enum _TaskMessageDomain { search, pointerScan, autoChase }

String _normalizeTaskMessage(
  String rawMessage, {
  required _TaskMessageDomain domain,
}) {
  final message = rawMessage.trim();
  if (message.isEmpty) {
    return '';
  }

  final normalized = message.toLowerCase();
  switch (domain) {
    case _TaskMessageDomain.search:
      if (normalized == 'first scan is running.') {
        return '首次搜索进行中';
      }
      if (normalized == 'next scan is running.') {
        return '继续筛选进行中';
      }
      if (normalized == 'search task completed.') {
        return '搜索任务已完成';
      }
      if (normalized == 'search task cancelled.') {
        return '搜索任务已取消';
      }
      if (normalized == 'search task failed.') {
        return '搜索任务失败';
      }
      if (normalized == 'no active search session.') {
        return '当前没有活动搜索会话';
      }
      return message;
    case _TaskMessageDomain.pointerScan:
      if (normalized == 'pointer scan is running.') {
        return '指针扫描进行中';
      }
      if (normalized == 'pointer scan completed.') {
        return '指针扫描已完成';
      }
      if (normalized == 'pointer scan cancelled.') {
        return '指针扫描已取消';
      }
      if (normalized == 'pointer scan failed.') {
        return '指针扫描失败';
      }
      return message;
    case _TaskMessageDomain.autoChase:
      if (normalized == 'pointer auto chase is running.') {
        return '自动追链进行中';
      }
      if (normalized == 'pointer auto chase completed.') {
        return '自动追链已完成';
      }
      if (normalized == 'pointer auto chase cancelled.') {
        return '自动追链已取消';
      }
      if (normalized == 'pointer auto chase failed.') {
        return '自动追链失败';
      }
      return message;
  }
}

String _normalizeToolError(Object error) {
  var message = error.toString().trim();
  if (message.isEmpty) {
    return '工具执行失败。';
  }

  final platformExceptionMatch = RegExp(
    r'PlatformException\([^,]+,\s*([^,\)]+)',
    caseSensitive: false,
  ).firstMatch(message);
  if (platformExceptionMatch != null) {
    message = platformExceptionMatch.group(1)?.trim() ?? message;
  }

  message = message
      .replaceFirst(RegExp(r'^Bad state:\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '')
      .replaceFirst(
        RegExp(r'^java\.lang\.[A-Za-z0-9_$.]+:\s*', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'^Invalid argument\(s\):\s*'), '')
      .trim();

  final lines = message
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where(
        (line) =>
            !line.startsWith('at ') &&
            !line.startsWith('#0') &&
            !line.startsWith('#1') &&
            !line.startsWith('#2') &&
            !line.startsWith('dart:') &&
            !line.startsWith('package:'),
      )
      .toList(growable: false);

  if (lines.isEmpty) {
    return '工具执行失败。';
  }

  final primary = lines.first;
  final normalized = primary.toLowerCase();
  if (normalized.contains('no active search session')) {
    return '当前没有活动搜索会话。';
  }
  if (normalized.contains('no active pointer scan session')) {
    return '当前没有活动指针扫描会话。';
  }
  if (normalized.contains('no active pointer auto chase')) {
    return '当前没有活动自动追链任务。';
  }
  return primary;
}

const Set<String> _supportedFuzzyModes = <String>{
  'unknown',
  'unchanged',
  'changed',
  'increased',
  'decreased',
};

class _AddressMetadata {
  const _AddressMetadata({
    required this.regionStart,
    required this.regionTypeKey,
  });

  final int regionStart;
  final String regionTypeKey;
}
