// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_tool_pointer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(hasRunningPointerTask)
const hasRunningPointerTaskProvider = HasRunningPointerTaskProvider._();

final class HasRunningPointerTaskProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  const HasRunningPointerTaskProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasRunningPointerTaskProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasRunningPointerTaskHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return hasRunningPointerTask(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hasRunningPointerTaskHash() =>
    r'6ff861d72a29ad427538714c5d808197e9978e84';

@ProviderFor(currentPointerResults)
const currentPointerResultsProvider = CurrentPointerResultsProvider._();

final class CurrentPointerResultsProvider
    extends
        $FunctionalProvider<
          List<PointerScanResult>,
          List<PointerScanResult>,
          List<PointerScanResult>
        >
    with $Provider<List<PointerScanResult>> {
  const CurrentPointerResultsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentPointerResultsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentPointerResultsHash();

  @$internal
  @override
  $ProviderElement<List<PointerScanResult>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<PointerScanResult> create(Ref ref) {
    return currentPointerResults(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<PointerScanResult> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<PointerScanResult>>(value),
    );
  }
}

String _$currentPointerResultsHash() =>
    r'135dc2be69074234402bdef7e475476c41aa4674';

@ProviderFor(MemoryToolPointerSearchForm)
const memoryToolPointerSearchFormProvider =
    MemoryToolPointerSearchFormProvider._();

final class MemoryToolPointerSearchFormProvider
    extends
        $NotifierProvider<
          MemoryToolPointerSearchForm,
          MemoryToolPointerFormState
        > {
  const MemoryToolPointerSearchFormProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryToolPointerSearchFormProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryToolPointerSearchFormHash();

  @$internal
  @override
  MemoryToolPointerSearchForm create() => MemoryToolPointerSearchForm();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryToolPointerFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryToolPointerFormState>(value),
    );
  }
}

String _$memoryToolPointerSearchFormHash() =>
    r'4569aa9738d99aafde88938e4794f5dce182c9ff';

abstract class _$MemoryToolPointerSearchForm
    extends $Notifier<MemoryToolPointerFormState> {
  MemoryToolPointerFormState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<MemoryToolPointerFormState, MemoryToolPointerFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                MemoryToolPointerFormState,
                MemoryToolPointerFormState
              >,
              MemoryToolPointerFormState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(MemoryToolPointerController)
const memoryToolPointerControllerProvider =
    MemoryToolPointerControllerProvider._();

final class MemoryToolPointerControllerProvider
    extends
        $NotifierProvider<MemoryToolPointerController, MemoryToolPointerState> {
  const MemoryToolPointerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryToolPointerControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryToolPointerControllerHash();

  @$internal
  @override
  MemoryToolPointerController create() => MemoryToolPointerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryToolPointerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryToolPointerState>(value),
    );
  }
}

String _$memoryToolPointerControllerHash() =>
    r'2cd0daf2405808c4070409919e1fa4020e93d2de';

abstract class _$MemoryToolPointerController
    extends $Notifier<MemoryToolPointerState> {
  MemoryToolPointerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<MemoryToolPointerState, MemoryToolPointerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MemoryToolPointerState, MemoryToolPointerState>,
              MemoryToolPointerState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
