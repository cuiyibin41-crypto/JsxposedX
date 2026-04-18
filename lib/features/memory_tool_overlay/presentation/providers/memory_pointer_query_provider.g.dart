// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_pointer_query_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(memoryPointerQueryRepository)
const memoryPointerQueryRepositoryProvider =
    MemoryPointerQueryRepositoryProvider._();

final class MemoryPointerQueryRepositoryProvider
    extends
        $FunctionalProvider<
          MemoryPointerQueryRepository,
          MemoryPointerQueryRepository,
          MemoryPointerQueryRepository
        >
    with $Provider<MemoryPointerQueryRepository> {
  const MemoryPointerQueryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryPointerQueryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryPointerQueryRepositoryHash();

  @$internal
  @override
  $ProviderElement<MemoryPointerQueryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemoryPointerQueryRepository create(Ref ref) {
    return memoryPointerQueryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryPointerQueryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryPointerQueryRepository>(value),
    );
  }
}

String _$memoryPointerQueryRepositoryHash() =>
    r'e7c034afbced832570313633fe8913ff6198cc24';

@ProviderFor(getPointerScanSessionState)
const getPointerScanSessionStateProvider =
    GetPointerScanSessionStateProvider._();

final class GetPointerScanSessionStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<PointerScanSessionState>,
          PointerScanSessionState,
          FutureOr<PointerScanSessionState>
        >
    with
        $FutureModifier<PointerScanSessionState>,
        $FutureProvider<PointerScanSessionState> {
  const GetPointerScanSessionStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getPointerScanSessionStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getPointerScanSessionStateHash();

  @$internal
  @override
  $FutureProviderElement<PointerScanSessionState> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PointerScanSessionState> create(Ref ref) {
    return getPointerScanSessionState(ref);
  }
}

String _$getPointerScanSessionStateHash() =>
    r'bbfb25e8c8ba5f4cd5189f3e3bb9b05626297d53';

@ProviderFor(getPointerScanTaskState)
const getPointerScanTaskStateProvider = GetPointerScanTaskStateProvider._();

final class GetPointerScanTaskStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<PointerScanTaskState>,
          PointerScanTaskState,
          FutureOr<PointerScanTaskState>
        >
    with
        $FutureModifier<PointerScanTaskState>,
        $FutureProvider<PointerScanTaskState> {
  const GetPointerScanTaskStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getPointerScanTaskStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getPointerScanTaskStateHash();

  @$internal
  @override
  $FutureProviderElement<PointerScanTaskState> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PointerScanTaskState> create(Ref ref) {
    return getPointerScanTaskState(ref);
  }
}

String _$getPointerScanTaskStateHash() =>
    r'40cb9c2af1996d2f6d744d292b76cec22eea190a';

@ProviderFor(getPointerScanResults)
const getPointerScanResultsProvider = GetPointerScanResultsFamily._();

final class GetPointerScanResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PointerScanResult>>,
          List<PointerScanResult>,
          FutureOr<List<PointerScanResult>>
        >
    with
        $FutureModifier<List<PointerScanResult>>,
        $FutureProvider<List<PointerScanResult>> {
  const GetPointerScanResultsProvider._({
    required GetPointerScanResultsFamily super.from,
    required ({int offset, int limit}) super.argument,
  }) : super(
         retry: null,
         name: r'getPointerScanResultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getPointerScanResultsHash();

  @override
  String toString() {
    return r'getPointerScanResultsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<PointerScanResult>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PointerScanResult>> create(Ref ref) {
    final argument = this.argument as ({int offset, int limit});
    return getPointerScanResults(
      ref,
      offset: argument.offset,
      limit: argument.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GetPointerScanResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getPointerScanResultsHash() =>
    r'1e65b1cd1d6ecb244472dd7c851806ea53485767';

final class GetPointerScanResultsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<PointerScanResult>>,
          ({int offset, int limit})
        > {
  const GetPointerScanResultsFamily._()
    : super(
        retry: null,
        name: r'getPointerScanResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetPointerScanResultsProvider call({
    required int offset,
    required int limit,
  }) => GetPointerScanResultsProvider._(
    argument: (offset: offset, limit: limit),
    from: this,
  );

  @override
  String toString() => r'getPointerScanResultsProvider';
}
