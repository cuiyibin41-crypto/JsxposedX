import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_result_selection_state.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';

class MemoryToolBrowseState {
  const MemoryToolBrowseState({
    this.anchorResult,
    this.regions = const <MemoryRegion>[],
    this.results = const <SearchResult>[],
    this.selectionState = const MemoryToolResultSelectionState(),
    this.hiddenAddresses = const <int>{},
    this.topNextStep = 1,
    this.bottomNextStep = 1,
    this.isInitializing = false,
    this.isLoadingAbove = false,
    this.isLoadingBelow = false,
    this.reachedTopBoundary = false,
    this.reachedBottomBoundary = false,
    this.errorText,
  });

  final SearchResult? anchorResult;
  final List<MemoryRegion> regions;
  final List<SearchResult> results;
  final MemoryToolResultSelectionState selectionState;
  final Set<int> hiddenAddresses;
  final int topNextStep;
  final int bottomNextStep;
  final bool isInitializing;
  final bool isLoadingAbove;
  final bool isLoadingBelow;
  final bool reachedTopBoundary;
  final bool reachedBottomBoundary;
  final String? errorText;

  bool get hasAnchor => anchorResult != null;

  int? get anchorAddress => anchorResult?.address;

  int get strideBytes {
    final rawBytes = anchorResult?.rawBytes;
    if (rawBytes == null || rawBytes.isEmpty) {
      return 1;
    }
    return rawBytes.length;
  }

  SearchValueType get browseType => anchorResult?.type ?? SearchValueType.i32;

  MemoryToolBrowseState copyWith({
    SearchResult? anchorResult,
    bool clearAnchorResult = false,
    List<MemoryRegion>? regions,
    List<SearchResult>? results,
    MemoryToolResultSelectionState? selectionState,
    Set<int>? hiddenAddresses,
    int? topNextStep,
    int? bottomNextStep,
    bool? isInitializing,
    bool? isLoadingAbove,
    bool? isLoadingBelow,
    bool? reachedTopBoundary,
    bool? reachedBottomBoundary,
    String? errorText,
    bool clearErrorText = false,
  }) {
    return MemoryToolBrowseState(
      anchorResult: clearAnchorResult ? null : anchorResult ?? this.anchorResult,
      regions: regions ?? this.regions,
      results: results ?? this.results,
      selectionState: selectionState ?? this.selectionState,
      hiddenAddresses: hiddenAddresses ?? this.hiddenAddresses,
      topNextStep: topNextStep ?? this.topNextStep,
      bottomNextStep: bottomNextStep ?? this.bottomNextStep,
      isInitializing: isInitializing ?? this.isInitializing,
      isLoadingAbove: isLoadingAbove ?? this.isLoadingAbove,
      isLoadingBelow: isLoadingBelow ?? this.isLoadingBelow,
      reachedTopBoundary: reachedTopBoundary ?? this.reachedTopBoundary,
      reachedBottomBoundary:
          reachedBottomBoundary ?? this.reachedBottomBoundary,
      errorText: clearErrorText ? null : errorText ?? this.errorText,
    );
  }
}
