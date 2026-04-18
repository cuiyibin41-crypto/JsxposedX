// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_action_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(memoryActionDatasource)
const memoryActionDatasourceProvider = MemoryActionDatasourceProvider._();

final class MemoryActionDatasourceProvider
    extends
        $FunctionalProvider<
          MemoryActionDatasource,
          MemoryActionDatasource,
          MemoryActionDatasource
        >
    with $Provider<MemoryActionDatasource> {
  const MemoryActionDatasourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryActionDatasourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryActionDatasourceHash();

  @$internal
  @override
  $ProviderElement<MemoryActionDatasource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemoryActionDatasource create(Ref ref) {
    return memoryActionDatasource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryActionDatasource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryActionDatasource>(value),
    );
  }
}

String _$memoryActionDatasourceHash() =>
    r'706720e91a37ed105232560556c9a5e985f9fcf7';

@ProviderFor(memoryActionRepository)
const memoryActionRepositoryProvider = MemoryActionRepositoryProvider._();

final class MemoryActionRepositoryProvider
    extends
        $FunctionalProvider<
          MemoryActionRepository,
          MemoryActionRepository,
          MemoryActionRepository
        >
    with $Provider<MemoryActionRepository> {
  const MemoryActionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryActionRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryActionRepositoryHash();

  @$internal
  @override
  $ProviderElement<MemoryActionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemoryActionRepository create(Ref ref) {
    return memoryActionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryActionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryActionRepository>(value),
    );
  }
}

String _$memoryActionRepositoryHash() =>
    r'8a4a775f3c3eacc458ab76ea3b35db05325edcb9';

@ProviderFor(currentFrozenMemoryValues)
const currentFrozenMemoryValuesProvider = CurrentFrozenMemoryValuesProvider._();

final class CurrentFrozenMemoryValuesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FrozenMemoryValue>>,
          List<FrozenMemoryValue>,
          FutureOr<List<FrozenMemoryValue>>
        >
    with
        $FutureModifier<List<FrozenMemoryValue>>,
        $FutureProvider<List<FrozenMemoryValue>> {
  const CurrentFrozenMemoryValuesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentFrozenMemoryValuesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentFrozenMemoryValuesHash();

  @$internal
  @override
  $FutureProviderElement<List<FrozenMemoryValue>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FrozenMemoryValue>> create(Ref ref) {
    return currentFrozenMemoryValues(ref);
  }
}

String _$currentFrozenMemoryValuesHash() =>
    r'39fd747ea7d8cbe965820acd8676c7b396fc8077';

@ProviderFor(processPaused)
const processPausedProvider = ProcessPausedFamily._();

final class ProcessPausedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  const ProcessPausedProvider._({
    required ProcessPausedFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'processPausedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$processPausedHash();

  @override
  String toString() {
    return r'processPausedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as int;
    return processPaused(ref, pid: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProcessPausedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$processPausedHash() => r'ac507b4cfc299b9fc62d5cfd01700952bbd170f0';

final class ProcessPausedFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, int> {
  const ProcessPausedFamily._()
    : super(
        retry: null,
        name: r'processPausedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProcessPausedProvider call({required int pid}) =>
      ProcessPausedProvider._(argument: pid, from: this);

  @override
  String toString() => r'processPausedProvider';
}

@ProviderFor(MemoryValueHistory)
const memoryValueHistoryProvider = MemoryValueHistoryProvider._();

final class MemoryValueHistoryProvider
    extends
        $NotifierProvider<
          MemoryValueHistory,
          Map<int, MemoryToolValueHistoryEntryState>
        > {
  const MemoryValueHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryValueHistoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryValueHistoryHash();

  @$internal
  @override
  MemoryValueHistory create() => MemoryValueHistory();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, MemoryToolValueHistoryEntryState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Map<int, MemoryToolValueHistoryEntryState>>(value),
    );
  }
}

String _$memoryValueHistoryHash() =>
    r'1fff257f8116c2c027b5ccff4479606b72661b4e';

abstract class _$MemoryValueHistory
    extends $Notifier<Map<int, MemoryToolValueHistoryEntryState>> {
  Map<int, MemoryToolValueHistoryEntryState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              Map<int, MemoryToolValueHistoryEntryState>,
              Map<int, MemoryToolValueHistoryEntryState>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<int, MemoryToolValueHistoryEntryState>,
                Map<int, MemoryToolValueHistoryEntryState>
              >,
              Map<int, MemoryToolValueHistoryEntryState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(MemorySearchAction)
const memorySearchActionProvider = MemorySearchActionProvider._();

final class MemorySearchActionProvider
    extends $NotifierProvider<MemorySearchAction, AsyncValue<void>> {
  const MemorySearchActionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memorySearchActionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memorySearchActionHash();

  @$internal
  @override
  MemorySearchAction create() => MemorySearchAction();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$memorySearchActionHash() =>
    r'9094564fab2ed69723c4bcda0431e4a22773745f';

abstract class _$MemorySearchAction extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(MemoryValueAction)
const memoryValueActionProvider = MemoryValueActionProvider._();

final class MemoryValueActionProvider
    extends $NotifierProvider<MemoryValueAction, AsyncValue<void>> {
  const MemoryValueActionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryValueActionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryValueActionHash();

  @$internal
  @override
  MemoryValueAction create() => MemoryValueAction();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$memoryValueActionHash() => r'6b15bb2d8de6fd2a653dc80fe02eea53f0b65d70';

abstract class _$MemoryValueAction extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(MemoryProcessControlAction)
const memoryProcessControlActionProvider =
    MemoryProcessControlActionProvider._();

final class MemoryProcessControlActionProvider
    extends $NotifierProvider<MemoryProcessControlAction, AsyncValue<void>> {
  const MemoryProcessControlActionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryProcessControlActionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryProcessControlActionHash();

  @$internal
  @override
  MemoryProcessControlAction create() => MemoryProcessControlAction();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$memoryProcessControlActionHash() =>
    r'966abb162b9a9808b57d750317523d05e3d98857';

abstract class _$MemoryProcessControlAction
    extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
