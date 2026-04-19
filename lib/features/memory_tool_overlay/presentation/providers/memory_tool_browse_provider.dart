import 'dart:typed_data';

import 'package:JsxposedX/features/memory_tool_overlay/presentation/models/memory_tool_display_item.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_browse_state.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_result_selection_state.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_tool_browse_provider.g.dart';

const int _memoryToolBrowseInitialExpandCount = 20;
const int _memoryToolBrowseLoadMoreCount = 20;
const int _memoryToolBrowseRegionPageSize = 200;

@riverpod
List<MemoryToolDisplayItem> currentBrowseResults(Ref ref) {
  final results = ref.watch(
    memoryToolBrowseControllerProvider.select((state) => state.results),
  );
  final hiddenAddresses = ref.watch(
    memoryToolBrowseControllerProvider.select((state) => state.hiddenAddresses),
  );
  return results
      .where((item) => !hiddenAddresses.contains(item.address))
      .toList(growable: false);
}

@riverpod
Future<Map<int, MemoryValuePreview>> currentBrowseResultLivePreviews(
  Ref ref,
) async {
  final visibleResults = ref.watch(currentBrowseResultsProvider);
  final anchorAddress = ref.watch(
    memoryToolBrowseControllerProvider.select((state) => state.anchorAddress),
  );
  final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
  final isPanelVisible = ref.watch(
    overlayWindowHostRuntimeProvider.select(
      (state) => state.payload.isPanel && !state.isTransitioningToPanel,
    ),
  );

  if (!isPanelVisible ||
      anchorAddress == null ||
      visibleResults.isEmpty ||
      selectedProcess == null) {
    return const <int, MemoryValuePreview>{};
  }

  final previews = await ref
      .watch(memoryQueryRepositoryProvider)
      .readMemoryValues(
        requests: visibleResults
            .map(
              (result) => MemoryReadRequest(
                pid: selectedProcess.pid,
                address: result.address,
                type: result.isInstruction
                    ? SearchValueType.bytes
                    : result.type,
                length: resolveMemoryToolReadLengthForType(
                  type: result.isInstruction
                      ? SearchValueType.bytes
                      : result.type,
                  bytesLength: result.rawBytes.isEmpty
                      ? 1
                      : result.rawBytes.length,
                ),
              ),
            )
            .toList(growable: false),
      );

  return <int, MemoryValuePreview>{
    for (final preview in previews) preview.address: preview,
  };
}

@Riverpod(keepAlive: true)
class MemoryToolBrowseController extends _$MemoryToolBrowseController {
  int? _cachedReadableRegionsPid;
  List<MemoryRegion>? _cachedReadableRegions;
  Future<List<MemoryRegion>>? _readableRegionsLoadFuture;

  @override
  MemoryToolBrowseState build() {
    return const MemoryToolBrowseState();
  }

  Future<List<MemoryRegion>> ensureReadableRegions({
    required int pid,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedReadableRegionsPid == pid &&
        _cachedReadableRegions != null) {
      return _cachedReadableRegions!;
    }

    if (!forceRefresh &&
        _cachedReadableRegionsPid == pid &&
        _readableRegionsLoadFuture != null) {
      return _readableRegionsLoadFuture!;
    }

    final future = _loadReadableRegions(pid: pid);
    _cachedReadableRegionsPid = pid;
    _readableRegionsLoadFuture = future;
    try {
      final regions = await future;
      if (_cachedReadableRegionsPid == pid) {
        _cachedReadableRegions = regions;
      }
      return regions;
    } finally {
      if (_cachedReadableRegionsPid == pid) {
        _readableRegionsLoadFuture = null;
      }
    }
  }

  Future<void> previewRawAddress({
    required int targetAddress,
    SearchValueType? type,
    int? bytesLength,
  }) async {
    final selectedProcess = ref.read(memoryToolSelectedProcessProvider);
    if (selectedProcess == null) {
      return;
    }

    final hasCompatibleAnchor =
        state.hasAnchor &&
        _cachedReadableRegionsPid == selectedProcess.pid &&
        state.strideBytes > 0;
    final resolvedType =
        type ?? (hasCompatibleAnchor ? state.browseType : SearchValueType.i32);
    final resolvedBytesLength =
        bytesLength ??
        (hasCompatibleAnchor
            ? state.strideBytes
            : resolveMemoryToolReadLengthForType(
                type: resolvedType,
                bytesLength: 0,
              ));
    final readableRegions = await ensureReadableRegions(
      pid: selectedProcess.pid,
    );
    final targetRegion = _resolveRegionForAddress(
      regions: readableRegions,
      address: targetAddress,
      strideBytes: resolvedBytesLength,
    );
    if (targetRegion == null) {
      throw Exception('Target address is unreadable.');
    }

    final targetPreview = await _readTargetPreviewOrNull(
      selectedPid: selectedProcess.pid,
      address: targetAddress,
      bytesLength: resolvedBytesLength,
    );
    if (targetPreview == null) {
      throw Exception('Target address is unreadable.');
    }

    final anchorItem = MemoryToolDisplayItem(
      address: targetAddress,
      regionStart: targetRegion.startAddress,
      regionTypeKey: _mapBrowseRegionTypeKey(targetRegion),
      type: resolvedType,
      rawBytes: targetPreview.rawBytes,
      displayValue: resolveMemoryToolSearchResultValueByType(
        type: resolvedType,
        rawBytes: targetPreview.rawBytes,
        fallbackDisplayValue: targetPreview.displayValue,
      ),
    );

    await _previewAnchorResult(
      selectedPid: selectedProcess.pid,
      anchorItem: anchorItem,
      knownReadableRegions: readableRegions,
    );
  }

  Future<void> previewFromSearchResult({
    required SearchResult result,
    MemoryValuePreview? preview,
    required String displayValue,
    bool preferInstructionMode = false,
  }) async {
    await previewFromAddress(
      sourceResult: result,
      sourcePreview: preview,
      targetAddress: result.address,
      anchorDisplayValue: displayValue,
      preferInstructionMode: preferInstructionMode,
    );
  }

  Future<void> previewFromAddress({
    required SearchResult sourceResult,
    MemoryValuePreview? sourcePreview,
    required int targetAddress,
    String? anchorDisplayValue,
    bool preferInstructionMode = false,
  }) async {
    final selectedProcess = ref.read(memoryToolSelectedProcessProvider);
    if (selectedProcess == null) {
      return;
    }

    final shouldUseInstructionMode =
        preferInstructionMode ||
        isMemoryToolInstructionDisplayValue(
          anchorDisplayValue ?? sourceResult.displayValue,
        );
    final sourceRawBytes = _resolveAnchorRawBytes(
      preview: sourcePreview,
      result: sourceResult,
    );
    final strideBytes = sourceRawBytes.isEmpty ? 1 : sourceRawBytes.length;
    var readableRegions = _resolveCachedReadableRegions(
      pid: selectedProcess.pid,
    );
    MemoryToolDisplayItem nextAnchorItem;
    if (shouldUseInstructionMode) {
      final instructionPreview = await _readInstructionPreviewOrNull(
        selectedPid: selectedProcess.pid,
        address: targetAddress,
      );
      if (instructionPreview == null) {
        throw Exception('Target address is unreadable.');
      }
      var targetRegion = _resolveRegionForAddress(
        regions: readableRegions,
        address: targetAddress,
        strideBytes: instructionPreview.rawBytes.isEmpty
            ? 1
            : instructionPreview.rawBytes.length,
      );
      if (targetRegion == null) {
        readableRegions = await ensureReadableRegions(pid: selectedProcess.pid);
        targetRegion = _resolveRegionForAddress(
          regions: readableRegions,
          address: targetAddress,
          strideBytes: instructionPreview.rawBytes.isEmpty
              ? 1
              : instructionPreview.rawBytes.length,
        );
      }
      if (targetRegion == null) {
        throw Exception('Target address is unreadable.');
      }
      nextAnchorItem = MemoryToolDisplayItem(
        address: targetAddress,
        regionStart: targetRegion.startAddress,
        regionTypeKey: _mapBrowseRegionTypeKey(targetRegion),
        type: SearchValueType.bytes,
        rawBytes: instructionPreview.rawBytes,
        displayValue: instructionPreview.instructionText,
        kind: MemoryToolDisplayItemKind.instruction,
        instructionText: instructionPreview.instructionText,
      );
    } else {
      var targetRegion = _resolveRegionForAddress(
        regions: readableRegions,
        address: targetAddress,
        strideBytes: strideBytes,
      );
      if (targetRegion == null) {
        readableRegions = await ensureReadableRegions(pid: selectedProcess.pid);
        targetRegion = _resolveRegionForAddress(
          regions: readableRegions,
          address: targetAddress,
          strideBytes: strideBytes,
        );
      }
      if (targetRegion == null) {
        throw Exception('Target address is unreadable.');
      }

      final targetPreview = await _readTargetPreviewOrNull(
        selectedPid: selectedProcess.pid,
        address: targetAddress,
        bytesLength: strideBytes,
      );
      if (targetPreview == null) {
        throw Exception('Target address is unreadable.');
      }

      final resolvedAnchorDisplayValue =
          resolveMemoryToolSearchResultValueByType(
            type: sourceResult.type,
            rawBytes: targetPreview.rawBytes,
            fallbackDisplayValue: targetPreview.displayValue,
          );

      nextAnchorItem = MemoryToolDisplayItem(
        address: targetAddress,
        regionStart: targetRegion.startAddress,
        regionTypeKey: _mapBrowseRegionTypeKey(targetRegion),
        type: sourceResult.type,
        rawBytes: targetPreview.rawBytes,
        displayValue: resolvedAnchorDisplayValue,
      );
    }

    await _previewAnchorResult(
      selectedPid: selectedProcess.pid,
      anchorItem: nextAnchorItem,
      knownReadableRegions: readableRegions,
    );
  }

  Future<void> refreshInstructionBrowseWindowIfVisible({
    required SearchResult sourceResult,
    required String instructionText,
  }) async {
    final currentState = state;
    final anchorAddress = currentState.anchorAddress;
    if (anchorAddress == null ||
        !currentState.isInstructionMode ||
        currentState.isInitializing ||
        !currentState.results.any(
          (result) => result.address == sourceResult.address,
        )) {
      return;
    }

    await previewFromAddress(
      sourceResult: sourceResult,
      targetAddress: anchorAddress,
      anchorDisplayValue: instructionText,
      preferInstructionMode: true,
    );
  }

  Future<void> refreshVisibleInstructionResults({
    required Iterable<int> addresses,
  }) async {
    final currentState = state;
    final selectedProcess = ref.read(memoryToolSelectedProcessProvider);
    if (selectedProcess == null ||
        !currentState.isInstructionMode ||
        currentState.isInitializing ||
        currentState.results.isEmpty) {
      return;
    }

    final targetAddresses = addresses.toSet().intersection(
      currentState.results.map((result) => result.address).toSet(),
    );
    if (targetAddresses.isEmpty) {
      return;
    }

    final previews = await ref
        .read(memoryQueryRepositoryProvider)
        .disassembleMemory(
          pid: selectedProcess.pid,
          addresses: targetAddresses.toList(growable: false),
        );
    if (previews.isEmpty) {
      return;
    }

    final previewByAddress = <int, MemoryInstructionPreview>{
      for (final preview in previews) preview.address: preview,
    };
    var nextResults = currentState.results;
    MemoryToolDisplayItem? nextAnchorItem = currentState.anchorItem;
    for (final result in currentState.results) {
      final preview = previewByAddress[result.address];
      if (preview == null) {
        continue;
      }
      final nextResult = result.copyWith(
        rawBytes: preview.rawBytes,
        displayValue: preview.instructionText,
        instructionText: preview.instructionText,
      );
      nextResults = _replaceBrowseResult(nextResults, nextResult);
      if (nextAnchorItem?.address == nextResult.address) {
        nextAnchorItem = nextResult;
      }
    }

    state = currentState.copyWith(
      anchorItem: nextAnchorItem,
      results: nextResults,
      clearErrorText: true,
    );
  }

  Future<void> recenter() async {
    final anchorItem = state.anchorItem;
    final selectedProcess = ref.read(memoryToolSelectedProcessProvider);
    if (anchorItem == null ||
        state.regions.isEmpty ||
        selectedProcess == null) {
      return;
    }

    state = state.copyWith(
      isInitializing: true,
      isLoadingAbove: false,
      isLoadingBelow: false,
      clearErrorText: true,
    );

    try {
      final nextState = await _buildWindowState(
        selectedPid: selectedProcess.pid,
        anchorItem: anchorItem,
        readableRegions: state.regions,
        preservedHiddenAddresses: state.hiddenAddresses,
      );
      state = nextState.copyWith(
        isInitializing: false,
        clearErrorText: true,
        focusRequestId: state.focusRequestId + 1,
      );
    } catch (error) {
      state = state.copyWith(
        isInitializing: false,
        errorText: error.toString(),
      );
    }
  }

  Future<void> loadMoreAbove() async {
    final anchorItem = state.anchorItem;
    final selectedProcess = ref.read(memoryToolSelectedProcessProvider);
    if (anchorItem == null ||
        state.regions.isEmpty ||
        selectedProcess == null ||
        state.isLoadingAbove ||
        state.reachedTopBoundary) {
      return;
    }

    state = state.copyWith(isLoadingAbove: true, clearErrorText: true);

    try {
      final collected = _collectAlignedAddresses(
        anchorAddress: anchorItem.address,
        strideBytes: state.strideBytes,
        startStep: state.topNextStep,
        targetCount: _memoryToolBrowseLoadMoreCount,
        isAbove: true,
        regions: state.regions,
      );
      final loadedResults = await _readBrowseResults(
        selectedPid: selectedProcess.pid,
        anchorItem: anchorItem,
        readableRegions: state.regions,
        addresses: collected.addresses.reversed.toList(growable: false),
      );
      state = state.copyWith(
        results: _mergeBrowseResults(loadedResults, state.results),
        topNextStep: collected.nextStep,
        reachedTopBoundary: collected.reachedBoundary,
        isLoadingAbove: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingAbove: false,
        errorText: error.toString(),
      );
    }
  }

  Future<void> loadMoreBelow() async {
    final anchorItem = state.anchorItem;
    final selectedProcess = ref.read(memoryToolSelectedProcessProvider);
    if (anchorItem == null ||
        state.regions.isEmpty ||
        selectedProcess == null ||
        state.isLoadingBelow ||
        state.reachedBottomBoundary) {
      return;
    }

    state = state.copyWith(isLoadingBelow: true, clearErrorText: true);

    try {
      final collected = _collectAlignedAddresses(
        anchorAddress: anchorItem.address,
        strideBytes: state.strideBytes,
        startStep: state.bottomNextStep,
        targetCount: _memoryToolBrowseLoadMoreCount,
        isAbove: false,
        regions: state.regions,
      );
      final loadedResults = await _readBrowseResults(
        selectedPid: selectedProcess.pid,
        anchorItem: anchorItem,
        readableRegions: state.regions,
        addresses: collected.addresses,
      );
      state = state.copyWith(
        results: _mergeBrowseResults(state.results, loadedResults),
        bottomNextStep: collected.nextStep,
        reachedBottomBoundary: collected.reachedBoundary,
        isLoadingBelow: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingBelow: false,
        errorText: error.toString(),
      );
    }
  }

  void updateSelectionLimit(int limit) {
    final clampedLimit = limit < 1 ? 1 : limit;
    final nextSelectionState = state.selectionState.copyWith(
      selectionLimit: clampedLimit,
      selectedAddresses: state.selectionState.selectedAddresses
          .take(clampedLimit)
          .toList(growable: false),
    );
    state = state.copyWith(selectionState: nextSelectionState);
  }

  void toggle(MemoryToolDisplayItem result) {
    final selected = List<int>.from(state.selectionState.selectedAddresses);
    final address = result.address;
    final existingIndex = selected.indexOf(address);
    if (existingIndex >= 0) {
      selected.removeAt(existingIndex);
    } else if (state.selectionState.selectionLimit == 1) {
      selected
        ..clear()
        ..add(address);
    } else if (selected.length < state.selectionState.selectionLimit) {
      selected.add(address);
    }

    state = state.copyWith(
      selectionState: state.selectionState.copyWith(
        selectedAddresses: selected,
      ),
    );
  }

  void selectVisible(List<MemoryToolDisplayItem> results) {
    state = state.copyWith(
      selectionState: state.selectionState.copyWith(
        selectedAddresses: results
            .take(state.selectionState.selectionLimit)
            .map((result) => result.address)
            .toList(growable: false),
      ),
    );
  }

  void invertVisible(List<MemoryToolDisplayItem> results) {
    final visibleAddresses = results.map((result) => result.address).toSet();
    final preserved = state.selectionState.selectedAddresses
        .where((address) => !visibleAddresses.contains(address))
        .toList(growable: false);
    final selectedVisible = state.selectionState.selectedAddresses.toSet();
    final nextSelected = <int>[...preserved];
    for (final result in results) {
      if (selectedVisible.contains(result.address) ||
          nextSelected.length >= state.selectionState.selectionLimit) {
        continue;
      }
      nextSelected.add(result.address);
    }

    state = state.copyWith(
      selectionState: state.selectionState.copyWith(
        selectedAddresses: nextSelected
            .take(state.selectionState.selectionLimit)
            .toList(growable: false),
      ),
    );
  }

  void clearSelection() {
    if (state.selectionState.selectedAddresses.isEmpty) {
      return;
    }

    state = state.copyWith(
      selectionState: state.selectionState.copyWith(
        selectedAddresses: const <int>[],
      ),
    );
  }

  void hideAddress(int address) {
    if (state.anchorAddress == address ||
        state.hiddenAddresses.contains(address)) {
      return;
    }

    final nextHiddenAddresses = <int>{...state.hiddenAddresses, address};
    final nextSelectedAddresses = state.selectionState.selectedAddresses
        .where((selectedAddress) => selectedAddress != address)
        .toList(growable: false);
    state = state.copyWith(
      hiddenAddresses: nextHiddenAddresses,
      selectionState: state.selectionState.copyWith(
        selectedAddresses: nextSelectedAddresses,
      ),
    );
  }

  void hideMany(Iterable<int> addresses) {
    final filteredAddresses = addresses
        .where((address) => address != state.anchorAddress)
        .toSet();
    if (filteredAddresses.isEmpty) {
      return;
    }

    final nextHiddenAddresses = <int>{
      ...state.hiddenAddresses,
      ...filteredAddresses,
    };
    final nextSelectedAddresses = state.selectionState.selectedAddresses
        .where(
          (selectedAddress) => !filteredAddresses.contains(selectedAddress),
        )
        .toList(growable: false);
    state = state.copyWith(
      hiddenAddresses: nextHiddenAddresses,
      selectionState: state.selectionState.copyWith(
        selectedAddresses: nextSelectedAddresses,
      ),
    );
  }

  void clear() {
    if (!state.hasAnchor &&
        state.results.isEmpty &&
        state.hiddenAddresses.isEmpty &&
        state.selectionState.selectedAddresses.isEmpty) {
      _clearReadableRegionCache();
      return;
    }
    _clearReadableRegionCache();
    state = const MemoryToolBrowseState();
  }

  Future<MemoryToolBrowseState> _buildWindowState({
    required int selectedPid,
    required MemoryToolDisplayItem anchorItem,
    required List<MemoryRegion> readableRegions,
    required Set<int> preservedHiddenAddresses,
  }) async {
    final aboveCollected = _collectAlignedAddresses(
      anchorAddress: anchorItem.address,
      strideBytes: anchorItem.rawBytes.isEmpty ? 1 : anchorItem.rawBytes.length,
      startStep: 1,
      targetCount: _memoryToolBrowseInitialExpandCount,
      isAbove: true,
      regions: readableRegions,
    );
    final belowCollected = _collectAlignedAddresses(
      anchorAddress: anchorItem.address,
      strideBytes: anchorItem.rawBytes.isEmpty ? 1 : anchorItem.rawBytes.length,
      startStep: 1,
      targetCount: _memoryToolBrowseInitialExpandCount,
      isAbove: false,
      regions: readableRegions,
    );
    final aboveResults = await _readBrowseResults(
      selectedPid: selectedPid,
      anchorItem: anchorItem,
      readableRegions: readableRegions,
      addresses: aboveCollected.addresses.reversed.toList(growable: false),
    );
    final belowResults = await _readBrowseResults(
      selectedPid: selectedPid,
      anchorItem: anchorItem,
      readableRegions: readableRegions,
      addresses: belowCollected.addresses,
    );

    return MemoryToolBrowseState(
      anchorItem: anchorItem,
      regions: readableRegions,
      results: <MemoryToolDisplayItem>[
        ...aboveResults,
        anchorItem,
        ...belowResults,
      ],
      hiddenAddresses: preservedHiddenAddresses,
      selectionState: const MemoryToolResultSelectionState(),
      topNextStep: aboveCollected.nextStep,
      bottomNextStep: belowCollected.nextStep,
      reachedTopBoundary: aboveCollected.reachedBoundary,
      reachedBottomBoundary: belowCollected.reachedBoundary,
    );
  }

  Future<List<MemoryRegion>> _loadReadableRegions({required int pid}) async {
    final repository = ref.read(memoryQueryRepositoryProvider);
    final regions = <MemoryRegion>[];

    for (int offset = 0; ; offset += _memoryToolBrowseRegionPageSize) {
      final page = await repository.getMemoryRegions(
        pid: pid,
        offset: offset,
        limit: _memoryToolBrowseRegionPageSize,
        readableOnly: true,
        includeAnonymous: true,
        includeFileBacked: true,
      );
      if (page.isEmpty) {
        break;
      }

      regions.addAll(page);
      if (page.length < _memoryToolBrowseRegionPageSize) {
        break;
      }
    }

    regions.sort(
      (left, right) => left.startAddress.compareTo(right.startAddress),
    );
    return regions;
  }

  Future<List<MemoryToolDisplayItem>> _readBrowseResults({
    required int selectedPid,
    required MemoryToolDisplayItem anchorItem,
    required List<MemoryRegion> readableRegions,
    required List<int> addresses,
  }) async {
    if (addresses.isEmpty) {
      return const <MemoryToolDisplayItem>[];
    }

    final strideBytes = anchorItem.rawBytes.isEmpty
        ? 1
        : anchorItem.rawBytes.length;
    if (anchorItem.isInstruction) {
      final instructions = await ref
          .read(memoryQueryRepositoryProvider)
          .disassembleMemory(pid: selectedPid, addresses: addresses);
      final instructionByAddress = <int, MemoryInstructionPreview>{
        for (final instruction in instructions)
          instruction.address: instruction,
      };
      final results = <MemoryToolDisplayItem>[];
      for (final address in addresses) {
        final instruction = instructionByAddress[address];
        final region = _resolveRegionForAddress(
          regions: readableRegions,
          address: address,
          strideBytes: strideBytes,
        );
        if (instruction == null || region == null) {
          continue;
        }
        results.add(
          MemoryToolDisplayItem(
            address: address,
            regionStart: region.startAddress,
            regionTypeKey: _mapBrowseRegionTypeKey(region),
            type: anchorItem.type,
            rawBytes: instruction.rawBytes,
            displayValue: instruction.instructionText,
            kind: MemoryToolDisplayItemKind.instruction,
            instructionText: instruction.instructionText,
          ),
        );
      }
      return results;
    }

    final previews = await ref
        .read(memoryQueryRepositoryProvider)
        .readMemoryValues(
          requests: addresses
              .map(
                (address) => MemoryReadRequest(
                  pid: selectedPid,
                  address: address,
                  type: SearchValueType.bytes,
                  length: strideBytes,
                ),
              )
              .toList(growable: false),
        );

    final previewByAddress = <int, MemoryValuePreview>{
      for (final preview in previews) preview.address: preview,
    };

    final results = <MemoryToolDisplayItem>[];
    for (final address in addresses) {
      final preview = previewByAddress[address];
      final region = _resolveRegionForAddress(
        regions: readableRegions,
        address: address,
        strideBytes: strideBytes,
      );
      if (preview == null || region == null) {
        continue;
      }

      results.add(
        MemoryToolDisplayItem(
          address: address,
          regionStart: region.startAddress,
          regionTypeKey: _mapBrowseRegionTypeKey(region),
          type: anchorItem.type,
          rawBytes: preview.rawBytes,
          displayValue: resolveMemoryToolSearchResultValueByType(
            type: anchorItem.type,
            rawBytes: preview.rawBytes,
            fallbackDisplayValue: anchorItem.displayValue,
          ),
        ),
      );
    }
    return results;
  }

  Future<List<MemoryToolDisplayItem>> _extendResultsAroundAnchor({
    required int selectedPid,
    required MemoryToolDisplayItem anchorItem,
    required MemoryRegion anchorRegion,
    required List<MemoryToolDisplayItem> existingResults,
  }) async {
    final strideBytes = anchorItem.rawBytes.isEmpty
        ? 1
        : anchorItem.rawBytes.length;
    final localRegions = <MemoryRegion>[anchorRegion];
    final aboveCollected = _collectAlignedAddresses(
      anchorAddress: anchorItem.address,
      strideBytes: strideBytes,
      startStep: 1,
      targetCount: _memoryToolBrowseInitialExpandCount,
      isAbove: true,
      regions: localRegions,
    );
    final belowCollected = _collectAlignedAddresses(
      anchorAddress: anchorItem.address,
      strideBytes: strideBytes,
      startStep: 1,
      targetCount: _memoryToolBrowseInitialExpandCount,
      isAbove: false,
      regions: localRegions,
    );
    final aboveResults = await _readBrowseResults(
      selectedPid: selectedPid,
      anchorItem: anchorItem,
      readableRegions: localRegions,
      addresses: aboveCollected.addresses.reversed.toList(growable: false),
    );
    final belowResults = await _readBrowseResults(
      selectedPid: selectedPid,
      anchorItem: anchorItem,
      readableRegions: localRegions,
      addresses: belowCollected.addresses,
    );
    return _mergeBrowseResults(existingResults, <MemoryToolDisplayItem>[
      ...aboveResults,
      anchorItem,
      ...belowResults,
    ]);
  }

  Future<void> _previewAnchorResult({
    required int selectedPid,
    required MemoryToolDisplayItem anchorItem,
    List<MemoryRegion>? knownReadableRegions,
  }) async {
    final nextAnchorRegion = _resolveRegionForAddress(
      regions: state.regions,
      address: anchorItem.address,
      strideBytes: anchorItem.rawBytes.isEmpty ? 1 : anchorItem.rawBytes.length,
    );
    final resolvedAnchorResult = nextAnchorRegion == null
        ? anchorItem
        : _resolveAnchorResultWithRegion(
            anchorItem: anchorItem,
            region: nextAnchorRegion,
          );

    if (_canReuseCurrentWindow(
      state: state,
      anchorItem: resolvedAnchorResult,
    )) {
      final nextHiddenAddresses = <int>{...state.hiddenAddresses}
        ..remove(resolvedAnchorResult.address);
      final nextResults = _replaceBrowseResult(
        state.results,
        resolvedAnchorResult,
      );
      final paginationState = _resolveBrowsePaginationState(
        anchorAddress: resolvedAnchorResult.address,
        strideBytes: resolvedAnchorResult.rawBytes.isEmpty
            ? 1
            : resolvedAnchorResult.rawBytes.length,
        regions: state.regions,
        loadedResults: nextResults,
      );
      state = state.copyWith(
        anchorItem: resolvedAnchorResult,
        results: nextResults,
        hiddenAddresses: nextHiddenAddresses,
        selectionState: const MemoryToolResultSelectionState(),
        focusRequestId: state.focusRequestId + 1,
        isInitializing: false,
        isLoadingAbove: false,
        isLoadingBelow: false,
        topNextStep: paginationState.topNextStep,
        bottomNextStep: paginationState.bottomNextStep,
        reachedTopBoundary: paginationState.reachedTopBoundary,
        reachedBottomBoundary: paginationState.reachedBottomBoundary,
        clearErrorText: true,
      );
      return;
    }

    if (_canReuseCurrentRegion(
      state: state,
      anchorItem: resolvedAnchorResult,
      anchorRegion: nextAnchorRegion,
    )) {
      try {
        final nextResults = await _extendResultsAroundAnchor(
          selectedPid: selectedPid,
          anchorItem: resolvedAnchorResult,
          anchorRegion: nextAnchorRegion!,
          existingResults: state.results,
        );
        final nextHiddenAddresses = <int>{...state.hiddenAddresses}
          ..remove(resolvedAnchorResult.address);
        final paginationState = _resolveBrowsePaginationState(
          anchorAddress: resolvedAnchorResult.address,
          strideBytes: resolvedAnchorResult.rawBytes.isEmpty
              ? 1
              : resolvedAnchorResult.rawBytes.length,
          regions: state.regions,
          loadedResults: nextResults,
        );
        state = state.copyWith(
          anchorItem: resolvedAnchorResult,
          results: nextResults,
          hiddenAddresses: nextHiddenAddresses,
          selectionState: const MemoryToolResultSelectionState(),
          focusRequestId: state.focusRequestId + 1,
          isInitializing: false,
          isLoadingAbove: false,
          isLoadingBelow: false,
          topNextStep: paginationState.topNextStep,
          bottomNextStep: paginationState.bottomNextStep,
          reachedTopBoundary: paginationState.reachedTopBoundary,
          reachedBottomBoundary: paginationState.reachedBottomBoundary,
          clearErrorText: true,
        );
        return;
      } catch (error) {
        state = state.copyWith(errorText: error.toString());
      }
    }

    if (_canReuseKnownRegions(
      state: state,
      anchorItem: resolvedAnchorResult,
      anchorRegion: nextAnchorRegion,
    )) {
      final nextHiddenAddresses = <int>{...state.hiddenAddresses}
        ..remove(resolvedAnchorResult.address);
      state = state.copyWith(
        isInitializing: true,
        isLoadingAbove: false,
        isLoadingBelow: false,
        clearErrorText: true,
      );
      try {
        final nextState = await _buildWindowState(
          selectedPid: selectedPid,
          anchorItem: resolvedAnchorResult,
          readableRegions: state.regions,
          preservedHiddenAddresses: nextHiddenAddresses,
        );
        _updateReadableRegionCache(
          pid: selectedPid,
          regions: nextState.regions,
        );
        state = nextState.copyWith(
          isInitializing: false,
          clearErrorText: true,
          focusRequestId: state.focusRequestId + 1,
        );
        return;
      } catch (error) {
        state = state.copyWith(
          isInitializing: false,
          errorText: error.toString(),
        );
      }
    }

    state = state.copyWith(
      isInitializing: true,
      isLoadingAbove: false,
      isLoadingBelow: false,
      clearErrorText: true,
    );

    try {
      final readableRegions =
          knownReadableRegions ?? await ensureReadableRegions(pid: selectedPid);
      if (readableRegions.isEmpty) {
        _updateReadableRegionCache(pid: selectedPid, regions: readableRegions);
        state = state.copyWith(
          results: const <MemoryToolDisplayItem>[],
          regions: const <MemoryRegion>[],
          selectionState: const MemoryToolResultSelectionState(),
          hiddenAddresses: const <int>{},
          isInitializing: false,
          reachedTopBoundary: true,
          reachedBottomBoundary: true,
          errorText: 'No readable memory region.',
        );
        return;
      }

      final finalAnchorRegion = _resolveRegionForAddress(
        regions: readableRegions,
        address: resolvedAnchorResult.address,
        strideBytes: resolvedAnchorResult.rawBytes.isEmpty
            ? 1
            : resolvedAnchorResult.rawBytes.length,
      );
      final finalAnchorResult = finalAnchorRegion == null
          ? resolvedAnchorResult
          : _resolveAnchorResultWithRegion(
              anchorItem: resolvedAnchorResult,
              region: finalAnchorRegion,
            );
      final nextState = await _buildWindowState(
        selectedPid: selectedPid,
        anchorItem: finalAnchorResult,
        readableRegions: readableRegions,
        preservedHiddenAddresses: const <int>{},
      );
      _updateReadableRegionCache(pid: selectedPid, regions: nextState.regions);
      state = nextState.copyWith(
        isInitializing: false,
        clearErrorText: true,
        focusRequestId: state.focusRequestId + 1,
      );
    } catch (error) {
      state = state.copyWith(
        isInitializing: false,
        errorText: error.toString(),
      );
    }
  }

  Future<MemoryValuePreview?> _readTargetPreviewOrNull({
    required int selectedPid,
    required int address,
    required int bytesLength,
  }) async {
    try {
      final previews = await ref
          .read(memoryQueryRepositoryProvider)
          .readMemoryValues(
            requests: <MemoryReadRequest>[
              MemoryReadRequest(
                pid: selectedPid,
                address: address,
                type: SearchValueType.bytes,
                length: bytesLength < 1 ? 1 : bytesLength,
              ),
            ],
          );
      if (previews.isEmpty) {
        return null;
      }
      return previews.first;
    } catch (_) {
      return null;
    }
  }

  Future<MemoryInstructionPreview?> _readInstructionPreviewOrNull({
    required int selectedPid,
    required int address,
  }) async {
    try {
      final previews = await ref
          .read(memoryQueryRepositoryProvider)
          .disassembleMemory(pid: selectedPid, addresses: <int>[address]);
      if (previews.isEmpty) {
        return null;
      }
      return previews.first;
    } catch (_) {
      return null;
    }
  }

  List<MemoryRegion> _resolveCachedReadableRegions({required int pid}) {
    if (_cachedReadableRegionsPid == pid && _cachedReadableRegions != null) {
      return _cachedReadableRegions!;
    }
    return const <MemoryRegion>[];
  }

  void _updateReadableRegionCache({
    required int pid,
    required List<MemoryRegion> regions,
  }) {
    _cachedReadableRegionsPid = pid;
    _cachedReadableRegions = regions;
  }

  void _clearReadableRegionCache() {
    _cachedReadableRegionsPid = null;
    _cachedReadableRegions = null;
    _readableRegionsLoadFuture = null;
  }
}

MemoryToolDisplayItem _resolveAnchorResultWithRegion({
  required MemoryToolDisplayItem anchorItem,
  required MemoryRegion region,
}) {
  return anchorItem.copyWith(
    regionStart: region.startAddress,
    regionTypeKey: _mapBrowseRegionTypeKey(region),
  );
}

bool _canReuseCurrentWindow({
  required MemoryToolBrowseState state,
  required MemoryToolDisplayItem anchorItem,
}) {
  if (!state.hasAnchor ||
      state.regions.isEmpty ||
      state.results.isEmpty ||
      state.isInitializing) {
    return false;
  }

  if (state.isInstructionMode != anchorItem.isInstruction ||
      state.browseType != anchorItem.type ||
      state.strideBytes != anchorItem.rawBytes.length) {
    return false;
  }

  return state.results.any((result) => result.address == anchorItem.address);
}

bool _canReuseCurrentRegion({
  required MemoryToolBrowseState state,
  required MemoryToolDisplayItem anchorItem,
  required MemoryRegion? anchorRegion,
}) {
  if (!_hasCompatibleBrowseShape(state: state, anchorItem: anchorItem) ||
      anchorRegion == null ||
      state.anchorItem == null) {
    return false;
  }
  return anchorRegion.startAddress == state.anchorItem!.regionStart;
}

bool _canReuseKnownRegions({
  required MemoryToolBrowseState state,
  required MemoryToolDisplayItem anchorItem,
  required MemoryRegion? anchorRegion,
}) {
  return _hasCompatibleBrowseShape(state: state, anchorItem: anchorItem) &&
      anchorRegion != null;
}

bool _hasCompatibleBrowseShape({
  required MemoryToolBrowseState state,
  required MemoryToolDisplayItem anchorItem,
}) {
  if (!state.hasAnchor ||
      state.regions.isEmpty ||
      state.results.isEmpty ||
      state.isInitializing) {
    return false;
  }

  if (state.isInstructionMode != anchorItem.isInstruction ||
      state.browseType != anchorItem.type ||
      state.strideBytes != anchorItem.rawBytes.length) {
    return false;
  }

  return true;
}

List<MemoryToolDisplayItem> _replaceBrowseResult(
  List<MemoryToolDisplayItem> results,
  MemoryToolDisplayItem nextResult,
) {
  return results
      .map(
        (result) => result.address == nextResult.address ? nextResult : result,
      )
      .toList(growable: false);
}

({
  int topNextStep,
  int bottomNextStep,
  bool reachedTopBoundary,
  bool reachedBottomBoundary,
})
_resolveBrowsePaginationState({
  required int anchorAddress,
  required int strideBytes,
  required List<MemoryRegion> regions,
  required List<MemoryToolDisplayItem> loadedResults,
}) {
  final loadedAddresses = loadedResults.map((result) => result.address).toSet();
  final aboveState = _resolveNextStep(
    anchorAddress: anchorAddress,
    strideBytes: strideBytes,
    regions: regions,
    loadedAddresses: loadedAddresses,
    isAbove: true,
  );
  final belowState = _resolveNextStep(
    anchorAddress: anchorAddress,
    strideBytes: strideBytes,
    regions: regions,
    loadedAddresses: loadedAddresses,
    isAbove: false,
  );
  return (
    topNextStep: aboveState.nextStep,
    bottomNextStep: belowState.nextStep,
    reachedTopBoundary: aboveState.reachedBoundary,
    reachedBottomBoundary: belowState.reachedBoundary,
  );
}

({int nextStep, bool reachedBoundary}) _resolveNextStep({
  required int anchorAddress,
  required int strideBytes,
  required List<MemoryRegion> regions,
  required Set<int> loadedAddresses,
  required bool isAbove,
}) {
  if (regions.isEmpty) {
    return (nextStep: 1, reachedBoundary: true);
  }

  final minReadableAddress = regions.first.startAddress;
  final maxReadableAddress = regions.last.endAddress;
  var nextStep = 1;

  while (true) {
    final candidate = isAbove
        ? anchorAddress - (nextStep * strideBytes)
        : anchorAddress + (nextStep * strideBytes);
    final isOutOfTopBoundary = candidate < minReadableAddress;
    final isOutOfBottomBoundary = candidate + strideBytes > maxReadableAddress;
    if (isOutOfTopBoundary || isOutOfBottomBoundary) {
      return (nextStep: nextStep, reachedBoundary: true);
    }

    final hasValidRegion =
        _resolveRegionForAddress(
          regions: regions,
          address: candidate,
          strideBytes: strideBytes,
        ) !=
        null;
    if (hasValidRegion && !loadedAddresses.contains(candidate)) {
      return (nextStep: nextStep, reachedBoundary: false);
    }
    nextStep += 1;
  }
}

({List<int> addresses, int nextStep, bool reachedBoundary})
_collectAlignedAddresses({
  required int anchorAddress,
  required int strideBytes,
  required int startStep,
  required int targetCount,
  required bool isAbove,
  required List<MemoryRegion> regions,
}) {
  if (regions.isEmpty) {
    return (
      addresses: const <int>[],
      nextStep: startStep,
      reachedBoundary: true,
    );
  }

  final minReadableAddress = regions.first.startAddress;
  final maxReadableAddress = regions.last.endAddress;
  final addresses = <int>[];
  var nextStep = startStep;

  while (addresses.length < targetCount) {
    final candidate = isAbove
        ? anchorAddress - (nextStep * strideBytes)
        : anchorAddress + (nextStep * strideBytes);
    final isOutOfTopBoundary = candidate < minReadableAddress;
    final isOutOfBottomBoundary = candidate + strideBytes > maxReadableAddress;
    if (isOutOfTopBoundary || isOutOfBottomBoundary) {
      return (addresses: addresses, nextStep: nextStep, reachedBoundary: true);
    }

    if (_resolveRegionForAddress(
          regions: regions,
          address: candidate,
          strideBytes: strideBytes,
        ) !=
        null) {
      addresses.add(candidate);
    }
    nextStep += 1;
  }

  return (addresses: addresses, nextStep: nextStep, reachedBoundary: false);
}

MemoryRegion? _resolveRegionForAddress({
  required List<MemoryRegion> regions,
  required int address,
  required int strideBytes,
}) {
  for (final region in regions) {
    if (address < region.startAddress) {
      return null;
    }
    if (address >= region.startAddress &&
        address + strideBytes <= region.endAddress) {
      return region;
    }
    if (address < region.endAddress) {
      return null;
    }
  }
  return null;
}

String _mapBrowseRegionTypeKey(MemoryRegion region) {
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
    if (lowerPath.contains('dalvik')) {
      return 'javaHeap';
    }
    return 'ashmem';
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

Uint8List _resolveAnchorRawBytes({
  required MemoryValuePreview? preview,
  required SearchResult result,
}) {
  final rawBytes = preview?.rawBytes ?? result.rawBytes;
  if (rawBytes.isNotEmpty) {
    return rawBytes;
  }
  final fallbackLength = resolveMemoryToolReadLengthForType(
    type: preview?.type ?? result.type,
    bytesLength: rawBytes.length,
  );
  return Uint8List(fallbackLength);
}

List<MemoryToolDisplayItem> _mergeBrowseResults(
  List<MemoryToolDisplayItem> leading,
  List<MemoryToolDisplayItem> trailing,
) {
  final merged = <int, MemoryToolDisplayItem>{
    for (final result in leading) result.address: result,
    for (final result in trailing) result.address: result,
  };
  final sorted = merged.values.toList(growable: false)
    ..sort((left, right) => left.address.compareTo(right.address));
  return sorted;
}
