// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_query_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(memoryQueryRepository)
const memoryQueryRepositoryProvider = MemoryQueryRepositoryProvider._();

final class MemoryQueryRepositoryProvider
    extends
        $FunctionalProvider<
          MemoryQueryRepository,
          MemoryQueryRepository,
          MemoryQueryRepository
        >
    with $Provider<MemoryQueryRepository> {
  const MemoryQueryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryQueryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryQueryRepositoryHash();

  @$internal
  @override
  $ProviderElement<MemoryQueryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemoryQueryRepository create(Ref ref) {
    return memoryQueryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryQueryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryQueryRepository>(value),
    );
  }
}

String _$memoryQueryRepositoryHash() =>
    r'88ddefa708f22d96e30c431ad34a0dfeda794284';

@ProviderFor(getPid)
const getPidProvider = GetPidFamily._();

final class GetPidProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  const GetPidProvider._({
    required GetPidFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'getPidProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getPidHash();

  @override
  String toString() {
    return r'getPidProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as String;
    return getPid(ref, packageName: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GetPidProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getPidHash() => r'811869c5dbdf7467cecc16849ca657f1a68c880e';

final class GetPidFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  const GetPidFamily._()
    : super(
        retry: null,
        name: r'getPidProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetPidProvider call({required String packageName}) =>
      GetPidProvider._(argument: packageName, from: this);

  @override
  String toString() => r'getPidProvider';
}

@ProviderFor(getProcessInfo)
const getProcessInfoProvider = GetProcessInfoFamily._();

final class GetProcessInfoProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProcessInfo>>,
          List<ProcessInfo>,
          FutureOr<List<ProcessInfo>>
        >
    with
        $FutureModifier<List<ProcessInfo>>,
        $FutureProvider<List<ProcessInfo>> {
  const GetProcessInfoProvider._({
    required GetProcessInfoFamily super.from,
    required ({int offset, int limit}) super.argument,
  }) : super(
         retry: null,
         name: r'getProcessInfoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getProcessInfoHash();

  @override
  String toString() {
    return r'getProcessInfoProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<ProcessInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ProcessInfo>> create(Ref ref) {
    final argument = this.argument as ({int offset, int limit});
    return getProcessInfo(ref, offset: argument.offset, limit: argument.limit);
  }

  @override
  bool operator ==(Object other) {
    return other is GetProcessInfoProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getProcessInfoHash() => r'e08882ac06baf3ae337972a851c0d0502a8ff27a';

final class GetProcessInfoFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ProcessInfo>>,
          ({int offset, int limit})
        > {
  const GetProcessInfoFamily._()
    : super(
        retry: null,
        name: r'getProcessInfoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetProcessInfoProvider call({required int offset, required int limit}) =>
      GetProcessInfoProvider._(
        argument: (offset: offset, limit: limit),
        from: this,
      );

  @override
  String toString() => r'getProcessInfoProvider';
}

@ProviderFor(getMemoryRegions)
const getMemoryRegionsProvider = GetMemoryRegionsFamily._();

final class GetMemoryRegionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MemoryRegion>>,
          List<MemoryRegion>,
          FutureOr<List<MemoryRegion>>
        >
    with
        $FutureModifier<List<MemoryRegion>>,
        $FutureProvider<List<MemoryRegion>> {
  const GetMemoryRegionsProvider._({
    required GetMemoryRegionsFamily super.from,
    required ({
      int pid,
      int offset,
      int limit,
      bool readableOnly,
      bool includeAnonymous,
      bool includeFileBacked,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'getMemoryRegionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getMemoryRegionsHash();

  @override
  String toString() {
    return r'getMemoryRegionsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<MemoryRegion>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MemoryRegion>> create(Ref ref) {
    final argument =
        this.argument
            as ({
              int pid,
              int offset,
              int limit,
              bool readableOnly,
              bool includeAnonymous,
              bool includeFileBacked,
            });
    return getMemoryRegions(
      ref,
      pid: argument.pid,
      offset: argument.offset,
      limit: argument.limit,
      readableOnly: argument.readableOnly,
      includeAnonymous: argument.includeAnonymous,
      includeFileBacked: argument.includeFileBacked,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GetMemoryRegionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getMemoryRegionsHash() => r'f2b7dfa7be335fe46d7f40af3a3035df4f10d08b';

final class GetMemoryRegionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<MemoryRegion>>,
          ({
            int pid,
            int offset,
            int limit,
            bool readableOnly,
            bool includeAnonymous,
            bool includeFileBacked,
          })
        > {
  const GetMemoryRegionsFamily._()
    : super(
        retry: null,
        name: r'getMemoryRegionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetMemoryRegionsProvider call({
    required int pid,
    required int offset,
    required int limit,
    bool readableOnly = true,
    bool includeAnonymous = true,
    bool includeFileBacked = true,
  }) => GetMemoryRegionsProvider._(
    argument: (
      pid: pid,
      offset: offset,
      limit: limit,
      readableOnly: readableOnly,
      includeAnonymous: includeAnonymous,
      includeFileBacked: includeFileBacked,
    ),
    from: this,
  );

  @override
  String toString() => r'getMemoryRegionsProvider';
}

@ProviderFor(getSearchSessionState)
const getSearchSessionStateProvider = GetSearchSessionStateProvider._();

final class GetSearchSessionStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<SearchSessionState>,
          SearchSessionState,
          FutureOr<SearchSessionState>
        >
    with
        $FutureModifier<SearchSessionState>,
        $FutureProvider<SearchSessionState> {
  const GetSearchSessionStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getSearchSessionStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getSearchSessionStateHash();

  @$internal
  @override
  $FutureProviderElement<SearchSessionState> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SearchSessionState> create(Ref ref) {
    return getSearchSessionState(ref);
  }
}

String _$getSearchSessionStateHash() =>
    r'36d80a242c90e296647922a54e58b9229c2af0bf';

@ProviderFor(getSearchTaskState)
const getSearchTaskStateProvider = GetSearchTaskStateProvider._();

final class GetSearchTaskStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<SearchTaskState>,
          SearchTaskState,
          FutureOr<SearchTaskState>
        >
    with $FutureModifier<SearchTaskState>, $FutureProvider<SearchTaskState> {
  const GetSearchTaskStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getSearchTaskStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getSearchTaskStateHash();

  @$internal
  @override
  $FutureProviderElement<SearchTaskState> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SearchTaskState> create(Ref ref) {
    return getSearchTaskState(ref);
  }
}

String _$getSearchTaskStateHash() =>
    r'eb31d63a30a8dd9905354e22385e50af45b96f88';

@ProviderFor(getSearchResults)
const getSearchResultsProvider = GetSearchResultsFamily._();

final class GetSearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SearchResult>>,
          List<SearchResult>,
          FutureOr<List<SearchResult>>
        >
    with
        $FutureModifier<List<SearchResult>>,
        $FutureProvider<List<SearchResult>> {
  const GetSearchResultsProvider._({
    required GetSearchResultsFamily super.from,
    required ({int offset, int limit}) super.argument,
  }) : super(
         retry: null,
         name: r'getSearchResultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getSearchResultsHash();

  @override
  String toString() {
    return r'getSearchResultsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<SearchResult>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SearchResult>> create(Ref ref) {
    final argument = this.argument as ({int offset, int limit});
    return getSearchResults(
      ref,
      offset: argument.offset,
      limit: argument.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GetSearchResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getSearchResultsHash() => r'5e908c706a1c67d9c94410ec4357c436a20d7be4';

final class GetSearchResultsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<SearchResult>>,
          ({int offset, int limit})
        > {
  const GetSearchResultsFamily._()
    : super(
        retry: null,
        name: r'getSearchResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetSearchResultsProvider call({required int offset, required int limit}) =>
      GetSearchResultsProvider._(
        argument: (offset: offset, limit: limit),
        from: this,
      );

  @override
  String toString() => r'getSearchResultsProvider';
}

@ProviderFor(readMemoryValues)
const readMemoryValuesProvider = ReadMemoryValuesFamily._();

final class ReadMemoryValuesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MemoryValuePreview>>,
          List<MemoryValuePreview>,
          FutureOr<List<MemoryValuePreview>>
        >
    with
        $FutureModifier<List<MemoryValuePreview>>,
        $FutureProvider<List<MemoryValuePreview>> {
  const ReadMemoryValuesProvider._({
    required ReadMemoryValuesFamily super.from,
    required List<MemoryReadRequest> super.argument,
  }) : super(
         retry: null,
         name: r'readMemoryValuesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readMemoryValuesHash();

  @override
  String toString() {
    return r'readMemoryValuesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MemoryValuePreview>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MemoryValuePreview>> create(Ref ref) {
    final argument = this.argument as List<MemoryReadRequest>;
    return readMemoryValues(ref, requests: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReadMemoryValuesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readMemoryValuesHash() => r'bf385112a080cc1e2503c9625fd5bc49319f2523';

final class ReadMemoryValuesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<MemoryValuePreview>>,
          List<MemoryReadRequest>
        > {
  const ReadMemoryValuesFamily._()
    : super(
        retry: null,
        name: r'readMemoryValuesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReadMemoryValuesProvider call({required List<MemoryReadRequest> requests}) =>
      ReadMemoryValuesProvider._(argument: requests, from: this);

  @override
  String toString() => r'readMemoryValuesProvider';
}

@ProviderFor(MemoryToolSelectedProcess)
const memoryToolSelectedProcessProvider = MemoryToolSelectedProcessProvider._();

final class MemoryToolSelectedProcessProvider
    extends $NotifierProvider<MemoryToolSelectedProcess, ProcessInfo?> {
  const MemoryToolSelectedProcessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryToolSelectedProcessProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryToolSelectedProcessHash();

  @$internal
  @override
  MemoryToolSelectedProcess create() => MemoryToolSelectedProcess();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProcessInfo? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProcessInfo?>(value),
    );
  }
}

String _$memoryToolSelectedProcessHash() =>
    r'3c0f000a0a3c10181da1e32f3c98673589c17eae';

abstract class _$MemoryToolSelectedProcess extends $Notifier<ProcessInfo?> {
  ProcessInfo? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ProcessInfo?, ProcessInfo?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ProcessInfo?, ProcessInfo?>,
              ProcessInfo?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
