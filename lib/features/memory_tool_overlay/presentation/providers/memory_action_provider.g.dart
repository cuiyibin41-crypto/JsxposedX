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
    r'5649317fb70f2ca013f075385645e8283584f9b5';

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
