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
}

@Riverpod(keepAlive: true)
class MemoryToolPointerController extends _$MemoryToolPointerController {
  @override
  MemoryToolPointerState build() {
    return const MemoryToolPointerState();
  }

  Future<void> startRootScan({required PointerScanRequest request}) async {
    state = MemoryToolPointerState(
      layers: <PointerChainLayerState>[
        PointerChainLayerState(request: request, isLoadingInitial: true),
      ],
      currentLayerIndex: 0,
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
          ),
        ],
        currentLayerIndex: 0,
      );
    }
  }

  Future<void> continueScan({
    required PointerScanResult result,
    required PointerScanRequest baseRequest,
  }) async {
    final request = PointerScanRequest(
      pid: baseRequest.pid,
      targetAddress: result.pointerAddress,
      pointerWidth: baseRequest.pointerWidth,
      maxOffset: baseRequest.maxOffset,
      alignment: baseRequest.alignment,
      rangeSectionKeys: baseRequest.rangeSectionKeys,
      scanAllReadableRegions: baseRequest.scanAllReadableRegions,
    );
    final nextLayers = <PointerChainLayerState>[
      ...state.layers,
      PointerChainLayerState(request: request, isLoadingInitial: true),
    ];
    state = state.copyWith(
      layers: nextLayers,
      currentLayerIndex: nextLayers.length - 1,
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

  Future<void> refreshCurrentLayer() async {
    final currentLayer = state.currentLayer;
    if (currentLayer == null) {
      return;
    }

    try {
      final sessionState = await ref.read(getPointerScanSessionStateProvider.future);
      if (!_matchesSession(currentLayer.request, sessionState)) {
        return;
      }

      final results = await ref.read(
        memoryPointerQueryRepositoryProvider,
      ).getPointerScanResults(offset: 0, limit: memoryToolPointerPageSize);
      _updateLayer(
        state.currentLayerIndex,
        currentLayer.copyWith(
          results: results,
          totalResultCount: sessionState.resultCount,
          isLoadingInitial: false,
          hasMore: results.length < sessionState.resultCount,
          clearErrorText: true,
        ),
      );
    } catch (error) {
      _updateLayer(
        state.currentLayerIndex,
        currentLayer.copyWith(
          isLoadingInitial: false,
          errorText: error.toString(),
        ),
      );
    }
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

    state = state.copyWith(currentLayerIndex: index);
    final targetLayer = state.currentLayer;
    if (targetLayer == null) {
      return;
    }

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

    _updateLayer(
      index,
      targetLayer.copyWith(isLoadingInitial: true, clearErrorText: true),
    );
    try {
      await ref
          .read(memoryPointerActionProvider.notifier)
          .startPointerScan(request: targetLayer.request);
    } catch (error) {
      _updateLayer(
        index,
        targetLayer.copyWith(
          isLoadingInitial: false,
          errorText: error.toString(),
        ),
      );
    }
  }

  Future<void> clear() async {
    state = const MemoryToolPointerState();
  }

  void markCurrentLayerError(String message) {
    final currentLayer = state.currentLayer;
    if (currentLayer == null) {
      return;
    }
    _updateLayer(
      state.currentLayerIndex,
      currentLayer.copyWith(
        isLoadingInitial: false,
        isLoadingMore: false,
        errorText: message,
      ),
    );
  }

  void markCurrentLayerLoading() {
    final currentLayer = state.currentLayer;
    if (currentLayer == null) {
      return;
    }
    _updateLayer(
      state.currentLayerIndex,
      currentLayer.copyWith(isLoadingInitial: true, clearErrorText: true),
    );
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

  void _updateLayer(int index, PointerChainLayerState nextLayer) {
    final nextLayers = List<PointerChainLayerState>.from(state.layers);
    if (index < 0 || index >= nextLayers.length) {
      return;
    }
    nextLayers[index] = nextLayer;
    state = state.copyWith(layers: nextLayers);
  }
}
