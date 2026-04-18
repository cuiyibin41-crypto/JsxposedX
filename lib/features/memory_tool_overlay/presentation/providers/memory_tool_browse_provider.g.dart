// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_tool_browse_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(currentBrowseResults)
const currentBrowseResultsProvider = CurrentBrowseResultsProvider._();

final class CurrentBrowseResultsProvider
    extends
        $FunctionalProvider<
          List<SearchResult>,
          List<SearchResult>,
          List<SearchResult>
        >
    with $Provider<List<SearchResult>> {
  const CurrentBrowseResultsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentBrowseResultsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentBrowseResultsHash();

  @$internal
  @override
  $ProviderElement<List<SearchResult>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<SearchResult> create(Ref ref) {
    return currentBrowseResults(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SearchResult> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SearchResult>>(value),
    );
  }
}

String _$currentBrowseResultsHash() =>
    r'77a5461cc7a0774f1b1d71ecd171fa1f2c2c55a6';

@ProviderFor(currentBrowseResultLivePreviews)
const currentBrowseResultLivePreviewsProvider =
    CurrentBrowseResultLivePreviewsProvider._();

final class CurrentBrowseResultLivePreviewsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, MemoryValuePreview>>,
          Map<int, MemoryValuePreview>,
          FutureOr<Map<int, MemoryValuePreview>>
        >
    with
        $FutureModifier<Map<int, MemoryValuePreview>>,
        $FutureProvider<Map<int, MemoryValuePreview>> {
  const CurrentBrowseResultLivePreviewsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentBrowseResultLivePreviewsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentBrowseResultLivePreviewsHash();

  @$internal
  @override
  $FutureProviderElement<Map<int, MemoryValuePreview>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<int, MemoryValuePreview>> create(Ref ref) {
    return currentBrowseResultLivePreviews(ref);
  }
}

String _$currentBrowseResultLivePreviewsHash() =>
    r'632bb4e9e054322961fd498c45ed4092db19d425';

@ProviderFor(MemoryToolBrowseController)
const memoryToolBrowseControllerProvider =
    MemoryToolBrowseControllerProvider._();

final class MemoryToolBrowseControllerProvider
    extends
        $NotifierProvider<MemoryToolBrowseController, MemoryToolBrowseState> {
  const MemoryToolBrowseControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryToolBrowseControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryToolBrowseControllerHash();

  @$internal
  @override
  MemoryToolBrowseController create() => MemoryToolBrowseController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryToolBrowseState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryToolBrowseState>(value),
    );
  }
}

String _$memoryToolBrowseControllerHash() =>
    r'fee7ba2a0c44e43b105c9158f385761001af1a87';

abstract class _$MemoryToolBrowseController
    extends $Notifier<MemoryToolBrowseState> {
  MemoryToolBrowseState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<MemoryToolBrowseState, MemoryToolBrowseState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MemoryToolBrowseState, MemoryToolBrowseState>,
              MemoryToolBrowseState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
