import 'package:JsxposedX/generated/memory_tool.g.dart'
    show PointerScanRequest, PointerScanResult;

class PointerChainLayerState {
  const PointerChainLayerState({
    required this.request,
    this.results = const <PointerScanResult>[],
    this.totalResultCount = 0,
    this.isLoadingInitial = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.errorText,
  });

  final PointerScanRequest request;
  final List<PointerScanResult> results;
  final int totalResultCount;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorText;

  PointerChainLayerState copyWith({
    PointerScanRequest? request,
    List<PointerScanResult>? results,
    int? totalResultCount,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorText,
    bool clearErrorText = false,
  }) {
    return PointerChainLayerState(
      request: request ?? this.request,
      results: results ?? this.results,
      totalResultCount: totalResultCount ?? this.totalResultCount,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorText: clearErrorText ? null : errorText ?? this.errorText,
    );
  }
}

class MemoryToolPointerState {
  const MemoryToolPointerState({
    this.layers = const <PointerChainLayerState>[],
    this.currentLayerIndex = -1,
  });

  final List<PointerChainLayerState> layers;
  final int currentLayerIndex;

  PointerChainLayerState? get currentLayer {
    if (currentLayerIndex < 0 || currentLayerIndex >= layers.length) {
      return null;
    }
    return layers[currentLayerIndex];
  }

  bool get hasLayers => currentLayer != null;

  MemoryToolPointerState copyWith({
    List<PointerChainLayerState>? layers,
    int? currentLayerIndex,
  }) {
    return MemoryToolPointerState(
      layers: layers ?? this.layers,
      currentLayerIndex: currentLayerIndex ?? this.currentLayerIndex,
    );
  }
}
