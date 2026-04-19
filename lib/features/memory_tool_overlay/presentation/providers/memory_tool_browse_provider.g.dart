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
          List<MemoryToolDisplayItem>,
          List<MemoryToolDisplayItem>,
          List<MemoryToolDisplayItem>
        >
    with $Provider<List<MemoryToolDisplayItem>> {
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
  $ProviderElement<List<MemoryToolDisplayItem>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<MemoryToolDisplayItem> create(Ref ref) {
    return currentBrowseResults(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<MemoryToolDisplayItem> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<MemoryToolDisplayItem>>(value),
    );
  }
}

String _$currentBrowseResultsHash() =>
    r'b9fb2c170bd47544c1a1e559b7558e98f10229bc';

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
    r'ab3a80bc084e8a94adf538f7474e6137d7e93164';

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
    r'465d3cd0096af74bd500588c40aac003c6671e27';

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
