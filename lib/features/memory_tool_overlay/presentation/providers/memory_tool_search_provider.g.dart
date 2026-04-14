// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_tool_search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(hasMatchingSearchSession)
const hasMatchingSearchSessionProvider = HasMatchingSearchSessionProvider._();

final class HasMatchingSearchSessionProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  const HasMatchingSearchSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasMatchingSearchSessionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasMatchingSearchSessionHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return hasMatchingSearchSession(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hasMatchingSearchSessionHash() =>
    r'64de4e9ebae599d1bc7cb1d90eb8ff682202f130';

@ProviderFor(hasRunningSearchTask)
const hasRunningSearchTaskProvider = HasRunningSearchTaskProvider._();

final class HasRunningSearchTaskProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  const HasRunningSearchTaskProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasRunningSearchTaskProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasRunningSearchTaskHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return hasRunningSearchTask(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hasRunningSearchTaskHash() =>
    r'7eee66a056808bfa565a6e27a2ae4380acd927a6';

@ProviderFor(currentSearchResults)
const currentSearchResultsProvider = CurrentSearchResultsProvider._();

final class CurrentSearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SearchResult>>,
          AsyncValue<List<SearchResult>>,
          AsyncValue<List<SearchResult>>
        >
    with $Provider<AsyncValue<List<SearchResult>>> {
  const CurrentSearchResultsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSearchResultsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSearchResultsHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<List<SearchResult>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<List<SearchResult>> create(Ref ref) {
    return currentSearchResults(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<SearchResult>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<SearchResult>>>(
        value,
      ),
    );
  }
}

String _$currentSearchResultsHash() =>
    r'fd2e43293c7636a5515dea3ef8f7d2afea9d8ef9';

@ProviderFor(MemoryToolSearchForm)
const memoryToolSearchFormProvider = MemoryToolSearchFormProvider._();

final class MemoryToolSearchFormProvider
    extends $NotifierProvider<MemoryToolSearchForm, MemoryToolSearchState> {
  const MemoryToolSearchFormProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryToolSearchFormProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryToolSearchFormHash();

  @$internal
  @override
  MemoryToolSearchForm create() => MemoryToolSearchForm();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryToolSearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryToolSearchState>(value),
    );
  }
}

String _$memoryToolSearchFormHash() =>
    r'9e3cfab0652cb45206e7dcc7ca44662d40f12933';

abstract class _$MemoryToolSearchForm extends $Notifier<MemoryToolSearchState> {
  MemoryToolSearchState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<MemoryToolSearchState, MemoryToolSearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MemoryToolSearchState, MemoryToolSearchState>,
              MemoryToolSearchState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
