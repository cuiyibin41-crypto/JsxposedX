import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_preset_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_section_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_tool_pointer_alignment_option.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_pointer_form_state.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_pointer_state.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart'
    show
        PointerScanRequest,
        PointerScanChaseHint,
        PointerScanResult,
        PointerScanSessionState,
        SearchTaskStatus;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_tool_pointer_provider.g.dart';

const int memoryToolPointerPageSize = 100;

@riverpod
bool hasRunningPointerTask(Ref ref) {
  final taskStateAsync = ref.watch(getPointerScanTaskStateProvider);
  return taskStateAsync.maybeWhen(
    data: (state) => state.status == SearchTaskStatus.running,
    orElse: () => false,
  );
}

@riverpod
List<PointerScanResult> currentPointerResults(Ref ref) {
  return ref.watch(
    memoryToolPointerControllerProvider.select(
      (state) => state.currentLayer?.results ?? const <PointerScanResult>[],
    ),
  );
}

@Riverpod(keepAlive: true)
class MemoryToolPointerSearchForm extends _$MemoryToolPointerSearchForm {
  @override
  MemoryToolPointerFormState build() {
    return const MemoryToolPointerFormState();
  }

  void updatePointerWidth(int pointerWidth) {
    state = state.copyWith(
      pointerWidth: pointerWidth,
      clearValidationError: true,
    );
  }

  void updateMaxOffsetInput(String value) {
    state = state.copyWith(
      maxOffsetInput: value,
      clearValidationError: true,
    );
  }

  void updateMaxDepthInput(String value) {
    state = state.copyWith(
      maxDepthInput: value,
      clearValidationError: true,
    );
  }

  void updateHexOffset(bool value) {
    state = state.copyWith(isHexOffset: value, clearValidationError: true);
  }

  void updateAlignment(MemoryToolPointerAlignmentOption option) {
    state = state.copyWith(
      selectedAlignment: option,
      clearValidationError: true,
    );
  }

  void updateRangePreset(MemorySearchRangePresetEnum preset) {
    final shouldSeedCustomSections =
        preset == MemorySearchRangePresetEnum.custom &&
        state.customRangeSections.isEmpty;
    state = state.copyWith(
      selectedRangePreset: preset,
      customRangeSections: shouldSeedCustomSections
          ? const <MemorySearchRangeSectionEnum>[
              MemorySearchRangeSectionEnum.anonymous,
              MemorySearchRangeSectionEnum.cAlloc,
              MemorySearchRangeSectionEnum.other,
            ]
          : state.customRangeSections,
      clearValidationError: true,
    );
  }

  void toggleCustomRangeSection(MemorySearchRangeSectionEnum section) {
    final nextSections = List<MemorySearchRangeSectionEnum>.from(
      state.customRangeSections,
    );
    if (nextSections.contains(section)) {
      nextSections.remove(section);
    } else {
      nextSections.add(section);
      nextSections.sort((left, right) => left.index.compareTo(right.index));
    }
    state = state.copyWith(
      customRangeSections: nextSections,
      clearValidationError: true,
    );
  }

  int? tryParseMaxOffset() {
    final rawValue = state.maxOffsetInput.trim();
    if (rawValue.isEmpty) {
      state = state.copyWith(
        validationError: MemoryToolPointerFormValidationError.invalidMaxOffset,
      );
      return null;
    }

    final normalized = state.isHexOffset
        ? rawValue.replaceFirst(RegExp(r'^0x', caseSensitive: false), '')
        : rawValue;
    final parsed = int.tryParse(
      normalized,
      radix: state.isHexOffset ? 16 : 10,
    );
    if (parsed == null || parsed < 0) {
      state = state.copyWith(
        validationError: MemoryToolPointerFormValidationError.invalidMaxOffset,
      );
      return null;
    }
    state = state.copyWith(clearValidationError: true);
    return parsed;
  }

  int? tryParseMaxDepth() {
    final rawValue = state.maxDepthInput.trim();
    final parsed = int.tryParse(rawValue);
    if (parsed == null || parsed < 1 || parsed > 12) {
      state = state.copyWith(
        validationError: MemoryToolPointerFormValidationError.invalidMaxDepth,
      );
      return null;
    }
    state = state.copyWith(clearValidationError: true);
    return parsed;
  }
}

@Riverpod(keepAlive: true)
class MemoryToolPointerController extends _$MemoryToolPointerController {
  static const Set<String> _staticRegionTypeKeys = <String>{'cData', 'cBss'};

  @override
  MemoryToolPointerState build() {
    return const MemoryToolPointerState();
  }

  Future<void> startRootScan({required PointerScanRequest request}) async {
    await _startFreshScan(
      request: request,
      isAutoChasing: false,
      autoChaseMaxDepth: 0,
    );
  }

  Future<void> startAutoChase({
    required PointerScanRequest request,
    required int maxDepth,
  }) async {
    await _startFreshScan(
      request: request,
      isAutoChasing: true,
      autoChaseMaxDepth: maxDepth,
    );
  }

  Future<void> continueScan({
    required PointerScanResult result,
    required PointerScanRequest baseRequest,
  }) async {
    final request = _buildNextRequest(
      baseRequest: baseRequest,
      targetAddress: result.pointerAddress,
    );
    final nextLayers = <PointerChainLayerState>[
      ...state.layers,
      PointerChainLayerState(
        request: request,
        isLoadingInitial: true,
        staticOnlyMode: false,
      ),
    ];
    state = state.copyWith(
      layers: nextLayers,
      currentLayerIndex: nextLayers.length - 1,
      isAutoChasing: false,
      autoChaseMaxDepth: 0,
    );
    try {
      await ref.read(memoryPointerActionProvider.notifier).startPointerScan(
        request: request,
      );
    } catch (error) {
      _updateLayer(
        nextLayers.length - 1,
        PointerChainLayerState(
          request: request,
          isLoadingInitial: false,
          errorText: error.toString(),
        ),
      );
    }
  }

  Future<void> handleTaskCompleted() async {
    try {
      final sessionState = await ref.read(getPointerScanSessionStateProvider.future);
      final layerIndex = await _refreshLayerForSession(sessionState);
      if (layerIndex < 0 || !state.isAutoChasing) {
        return;
      }

      final refreshedLayer = state.layers[layerIndex];
      late final PointerScanChaseHint chaseHint;
      try {
        chaseHint = await ref
            .read(memoryPointerQueryRepositoryProvider)
            .getPointerScanChaseHint();
      } catch (error) {
        _updateLayer(
          layerIndex,
          refreshedLayer.copyWith(
            autoStopReasonKey: 'failed',
            errorText: error.toString(),
          ),
        );
        _stopAutoChaseState();
        return;
      }
      final hintResult = chaseHint.result;
      final resolvedStopReason = _normalizeAutoStopReason(
        chaseHint.stopReasonKey,
      );

      if (hintResult == null) {
        _updateLayer(
          layerIndex,
          refreshedLayer.copyWith(
            clearSelectedPointerAddress: true,
            isAutoSelectedLayer: false,
            isTerminalLayer: false,
            autoStopReasonKey: resolvedStopReason,
            clearErrorText: true,
          ),
        );
        _stopAutoChaseState();
        return;
      }

      final nextLayer = refreshedLayer.copyWith(
        selectedPointerAddress: hintResult.pointerAddress,
        isAutoSelectedLayer: true,
        isTerminalLayer: chaseHint.isTerminalStaticCandidate,
        autoStopReasonKey: chaseHint.isTerminalStaticCandidate
            ? resolvedStopReason
            : null,
        clearAutoStopReasonKey: !chaseHint.isTerminalStaticCandidate,
        clearErrorText: true,
      );
      _updateLayer(layerIndex, nextLayer);

      if (chaseHint.isTerminalStaticCandidate) {
        _stopAutoChaseState();
        return;
      }

      if (layerIndex + 1 >= state.autoChaseMaxDepth) {
        _updateLayer(
          layerIndex,
          nextLayer.copyWith(
            autoStopReasonKey: 'maxDepth',
            clearErrorText: true,
          ),
        );
        _stopAutoChaseState();
        return;
      }

      await _appendAutoChaseLayer(
        request: _buildNextRequest(
          baseRequest: refreshedLayer.request,
          targetAddress: hintResult.pointerAddress,
        ),
      );
    } catch (error) {
      final fallbackLayerIndex = _findActiveScanLayerIndex();
      final targetLayerIndex = fallbackLayerIndex >= 0
          ? fallbackLayerIndex
          : state.currentLayerIndex;
      if (targetLayerIndex >= 0 && targetLayerIndex < state.layers.length) {
        _updateLayer(
          targetLayerIndex,
          state.layers[targetLayerIndex].copyWith(
            isLoadingInitial: false,
            isLoadingMore: false,
            autoStopReasonKey: state.isAutoChasing ? 'failed' : null,
            clearAutoStopReasonKey: !state.isAutoChasing,
            errorText: error.toString(),
          ),
        );
      }
      _stopAutoChaseState();
    }
  }

  void handleTaskStopped({
    required SearchTaskStatus status,
    required String message,
  }) {
    final layerIndex = _findActiveScanLayerIndex();
    if (layerIndex < 0) {
      _stopAutoChaseState();
      return;
    }

    final targetLayer = state.layers[layerIndex];
    final isCancelled = status == SearchTaskStatus.cancelled;
    final nextStopReason = state.isAutoChasing
        ? isCancelled
              ? 'cancelled'
              : 'failed'
        : targetLayer.autoStopReasonKey;
    _updateLayer(
      layerIndex,
      targetLayer.copyWith(
        isLoadingInitial: false,
        isLoadingMore: false,
        errorText: isCancelled ? null : message,
        autoStopReasonKey: nextStopReason,
        clearErrorText: isCancelled,
      ),
    );
    _stopAutoChaseState();
  }

  Future<void> cancelAutoChase() async {
    _stopAutoChaseState();
    await ref.read(memoryPointerActionProvider.notifier).cancelPointerScan();
  }

  Future<void> loadMore() async {
    final layerIndex = state.currentLayerIndex;
    final currentLayer = state.currentLayer;
    if (currentLayer == null ||
        currentLayer.isLoadingInitial ||
        currentLayer.isLoadingMore ||
        !currentLayer.hasMore) {
      return;
    }

    try {
      final sessionState = await ref.read(getPointerScanSessionStateProvider.future);
      if (!_matchesSession(currentLayer.request, sessionState)) {
        return;
      }

      _updateLayer(
        layerIndex,
        currentLayer.copyWith(isLoadingMore: true, clearErrorText: true),
      );

      final nextPage = await ref.read(
        memoryPointerQueryRepositoryProvider,
      ).getPointerScanResults(
        offset: currentLayer.results.length,
        limit: memoryToolPointerPageSize,
      );
      final mergedResults = <PointerScanResult>[
        ...currentLayer.results,
        ...nextPage,
      ];
      _updateLayer(
        layerIndex,
        currentLayer.copyWith(
          results: mergedResults,
          totalResultCount: sessionState.resultCount,
          isLoadingMore: false,
          hasMore: mergedResults.length < sessionState.resultCount,
          clearErrorText: true,
        ),
      );
    } catch (error) {
      _updateLayer(
        layerIndex,
        currentLayer.copyWith(
          isLoadingMore: false,
          errorText: error.toString(),
        ),
      );
    }
  }

  Future<void> selectLayer(int index) async {
    if (index < 0 || index >= state.layers.length || index == state.currentLayerIndex) {
      return;
    }

    final targetLayer = state.layers[index];
    state = state.copyWith(currentLayerIndex: index);

    PointerScanSessionState? sessionState;
    try {
      sessionState = await ref.read(getPointerScanSessionStateProvider.future);
    } catch (_) {
      sessionState = null;
    }

    if (sessionState != null &&
        _matchesSession(targetLayer.request, sessionState)) {
      if (targetLayer.totalResultCount == 0 && sessionState.resultCount > 0) {
        _updateLayer(
          index,
          targetLayer.copyWith(
            totalResultCount: sessionState.resultCount,
            hasMore: targetLayer.results.length < sessionState.resultCount,
          ),
        );
      }
      return;
    }
  }

  Future<void> clear() async {
    state = const MemoryToolPointerState();
  }

  PointerScanRequest _buildNextRequest({
    required PointerScanRequest baseRequest,
    required int targetAddress,
  }) {
    return PointerScanRequest(
      pid: baseRequest.pid,
      targetAddress: targetAddress,
      pointerWidth: baseRequest.pointerWidth,
      maxOffset: baseRequest.maxOffset,
      alignment: baseRequest.alignment,
      rangeSectionKeys: baseRequest.rangeSectionKeys,
      scanAllReadableRegions: baseRequest.scanAllReadableRegions,
    );
  }

  Future<void> _startFreshScan({
    required PointerScanRequest request,
    required bool isAutoChasing,
    required int autoChaseMaxDepth,
  }) async {
    state = MemoryToolPointerState(
      layers: <PointerChainLayerState>[
        PointerChainLayerState(
          request: request,
          isLoadingInitial: true,
          staticOnlyMode: isAutoChasing,
        ),
      ],
      currentLayerIndex: 0,
      isAutoChasing: isAutoChasing,
      autoChaseMaxDepth: autoChaseMaxDepth,
    );
    try {
      await ref.read(memoryPointerActionProvider.notifier).startPointerScan(
        request: request,
      );
    } catch (error) {
      state = MemoryToolPointerState(
        layers: <PointerChainLayerState>[
          PointerChainLayerState(
            request: request,
            isLoadingInitial: false,
            errorText: error.toString(),
            autoStopReasonKey: isAutoChasing ? 'failed' : null,
            staticOnlyMode: isAutoChasing,
          ),
        ],
        currentLayerIndex: 0,
      );
    }
  }

  Future<int> _refreshLayerForSession(
    PointerScanSessionState sessionState,
  ) async {
    try {
      final layerIndex = _findLayerIndexBySession(sessionState);
      if (layerIndex < 0) {
        return -1;
      }

      final targetLayer = state.layers[layerIndex];
      final results = await ref.read(
        memoryPointerQueryRepositoryProvider,
      ).getPointerScanResults(offset: 0, limit: memoryToolPointerPageSize);
      _updateLayer(
        layerIndex,
        targetLayer.copyWith(
          results: results,
          totalResultCount: sessionState.resultCount,
          isLoadingInitial: false,
          hasMore: results.length < sessionState.resultCount,
          clearErrorText: true,
        ),
      );
      return layerIndex;
    } catch (error) {
      handleTaskStopped(
        status: SearchTaskStatus.failed,
        message: error.toString(),
      );
      return -1;
    }
  }

  Future<void> _appendAutoChaseLayer({
    required PointerScanRequest request,
  }) async {
    final nextLayers = <PointerChainLayerState>[
      ...state.layers,
      PointerChainLayerState(
        request: request,
        isLoadingInitial: true,
        staticOnlyMode: true,
      ),
    ];
    final autoChaseMaxDepth = state.autoChaseMaxDepth;
    state = state.copyWith(
      layers: nextLayers,
      currentLayerIndex: nextLayers.length - 1,
      isAutoChasing: true,
      autoChaseMaxDepth: autoChaseMaxDepth,
    );
    try {
      await ref.read(memoryPointerActionProvider.notifier).startPointerScan(
        request: request,
      );
    } catch (error) {
      _updateLayer(
        nextLayers.length - 1,
        PointerChainLayerState(
          request: request,
          isLoadingInitial: false,
          errorText: error.toString(),
          autoStopReasonKey: 'failed',
          staticOnlyMode: true,
        ),
      );
      _stopAutoChaseState();
    }
  }

  bool isStaticRegionType(String regionTypeKey) {
    return _staticRegionTypeKeys.contains(regionTypeKey);
  }

  String _normalizeAutoStopReason(String rawKey) {
    return switch (rawKey) {
      'staticReached' => 'staticReached',
      'maxDepth' => 'maxDepth',
      'cancelled' => 'cancelled',
      'failed' => 'failed',
      'noSession' || 'noMorePointers' || '' => 'noMorePointers',
      _ => 'noMorePointers',
    };
  }

  bool _matchesSession(
    PointerScanRequest request,
    PointerScanSessionState sessionState,
  ) {
    return sessionState.hasActiveSession &&
        request.pid == sessionState.pid &&
        request.targetAddress == sessionState.targetAddress &&
        request.pointerWidth == sessionState.pointerWidth &&
        request.maxOffset == sessionState.maxOffset &&
        request.alignment == sessionState.alignment;
  }

  int _findActiveScanLayerIndex() {
    for (var index = state.layers.length - 1; index >= 0; index -= 1) {
      final layer = state.layers[index];
      if (layer.isLoadingInitial || layer.isLoadingMore) {
        return index;
      }
    }
    return -1;
  }

  int _findLayerIndexBySession(PointerScanSessionState sessionState) {
    if (!sessionState.hasActiveSession) {
      return -1;
    }
    for (var index = state.layers.length - 1; index >= 0; index -= 1) {
      if (_matchesSession(state.layers[index].request, sessionState)) {
        return index;
      }
    }
    return -1;
  }

  void _stopAutoChaseState() {
    if (!state.isAutoChasing && state.autoChaseMaxDepth == 0) {
      return;
    }
    state = state.copyWith(isAutoChasing: false, autoChaseMaxDepth: 0);
  }

  void _updateLayer(int index, PointerChainLayerState nextLayer) {
    final nextLayers = List<PointerChainLayerState>.from(state.layers);
    if (index < 0 || index >= nextLayers.length) {
      return;
    }
    nextLayers[index] = nextLayer;
    state = state.copyWith(layers: nextLayers);
  }
}
