import 'dart:async';

import 'package:JsxposedX/core/services/app_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const String _autoPauseOnOverlayOpenKey =
    'memory_tool.auto_pause_on_overlay_open';

class MemoryToolSettingsState {
  const MemoryToolSettingsState({this.autoPauseOnOverlayOpen = false});

  final bool autoPauseOnOverlayOpen;

  MemoryToolSettingsState copyWith({bool? autoPauseOnOverlayOpen}) {
    return MemoryToolSettingsState(
      autoPauseOnOverlayOpen:
          autoPauseOnOverlayOpen ?? this.autoPauseOnOverlayOpen,
    );
  }
}

final memoryToolSettingsProvider =
    AsyncNotifierProvider<MemoryToolSettingsNotifier, MemoryToolSettingsState>(
      MemoryToolSettingsNotifier.new,
    );

class MemoryToolSettingsNotifier
    extends AsyncNotifier<MemoryToolSettingsState> {
  @override
  FutureOr<MemoryToolSettingsState> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return MemoryToolSettingsState(
      autoPauseOnOverlayOpen:
          prefs.getBool(_autoPauseOnOverlayOpenKey) ?? false,
    );
  }

  Future<void> setAutoPauseOnOverlayOpen(bool value) async {
    final previous = state.asData?.value ?? const MemoryToolSettingsState();
    state = AsyncData(previous.copyWith(autoPauseOnOverlayOpen: value));
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final saved = await prefs.setBool(_autoPauseOnOverlayOpenKey, value);
      if (!saved) {
        throw StateError('Failed to save MemoryTool settings.');
      }
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
