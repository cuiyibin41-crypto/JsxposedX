// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overlay_scene_registry_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(overlaySceneRegistry)
const overlaySceneRegistryProvider = OverlaySceneRegistryProvider._();

final class OverlaySceneRegistryProvider
    extends
        $FunctionalProvider<
          Map<int, OverlaySceneDefinition>,
          Map<int, OverlaySceneDefinition>,
          Map<int, OverlaySceneDefinition>
        >
    with $Provider<Map<int, OverlaySceneDefinition>> {
  const OverlaySceneRegistryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'overlaySceneRegistryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$overlaySceneRegistryHash();

  @$internal
  @override
  $ProviderElement<Map<int, OverlaySceneDefinition>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<int, OverlaySceneDefinition> create(Ref ref) {
    return overlaySceneRegistry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, OverlaySceneDefinition> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<int, OverlaySceneDefinition>>(
        value,
      ),
    );
  }
}

String _$overlaySceneRegistryHash() =>
    r'2fd95b1a3d6f9250e4c380563cb7af56c80a0418';
