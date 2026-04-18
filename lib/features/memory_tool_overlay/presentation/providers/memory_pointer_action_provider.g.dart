// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_pointer_action_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(memoryPointerActionDatasource)
const memoryPointerActionDatasourceProvider =
    MemoryPointerActionDatasourceProvider._();

final class MemoryPointerActionDatasourceProvider
    extends
        $FunctionalProvider<
          MemoryPointerActionDatasource,
          MemoryPointerActionDatasource,
          MemoryPointerActionDatasource
        >
    with $Provider<MemoryPointerActionDatasource> {
  const MemoryPointerActionDatasourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryPointerActionDatasourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryPointerActionDatasourceHash();

  @$internal
  @override
  $ProviderElement<MemoryPointerActionDatasource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemoryPointerActionDatasource create(Ref ref) {
    return memoryPointerActionDatasource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryPointerActionDatasource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryPointerActionDatasource>(
        value,
      ),
    );
  }
}

String _$memoryPointerActionDatasourceHash() =>
    r'c72cd2ded1743adb91f0a7b1e86b2b0f7e20a795';

@ProviderFor(memoryPointerActionRepository)
const memoryPointerActionRepositoryProvider =
    MemoryPointerActionRepositoryProvider._();

final class MemoryPointerActionRepositoryProvider
    extends
        $FunctionalProvider<
          MemoryPointerActionRepository,
          MemoryPointerActionRepository,
          MemoryPointerActionRepository
        >
    with $Provider<MemoryPointerActionRepository> {
  const MemoryPointerActionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryPointerActionRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryPointerActionRepositoryHash();

  @$internal
  @override
  $ProviderElement<MemoryPointerActionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemoryPointerActionRepository create(Ref ref) {
    return memoryPointerActionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryPointerActionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryPointerActionRepository>(
        value,
      ),
    );
  }
}

String _$memoryPointerActionRepositoryHash() =>
    r'7efb2ead33f9df18e46c094cbd2627fb4b7b45f8';

@ProviderFor(MemoryPointerAction)
const memoryPointerActionProvider = MemoryPointerActionProvider._();

final class MemoryPointerActionProvider
    extends $NotifierProvider<MemoryPointerAction, AsyncValue<void>> {
  const MemoryPointerActionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryPointerActionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryPointerActionHash();

  @$internal
  @override
  MemoryPointerAction create() => MemoryPointerAction();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$memoryPointerActionHash() =>
    r'2e832d20f574450bece154968c3ef68811ef8f19';

abstract class _$MemoryPointerAction extends $Notifier<AsyncValue<void>> {
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
