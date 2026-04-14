import 'dart:convert';
import 'dart:typed_data';

import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_preset_maps.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_preset_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_section_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_value_category_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_value_type_option_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_result_selection_state.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_search_state.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_range_key_mapper.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_tool_search_provider.g.dart';

@riverpod
bool hasMatchingSearchSession(Ref ref) {
  final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
  final sessionStateAsync = ref.watch(getSearchSessionStateProvider);

  return sessionStateAsync.maybeWhen(
    data: (state) =>
        selectedProcess != null &&
        state.hasActiveSession &&
        state.pid == selectedProcess.pid,
    orElse: () => false,
  );
}

@riverpod
bool hasRunningSearchTask(Ref ref) {
  final taskStateAsync = ref.watch(getSearchTaskStateProvider);
  return taskStateAsync.maybeWhen(
    data: (state) => state.status == SearchTaskStatus.running,
    orElse: () => false,
  );
}

@riverpod
AsyncValue<List<SearchResult>> currentSearchResults(Ref ref) {
  final hasMatchingSession = ref.watch(hasMatchingSearchSessionProvider);
  final renderLimit = ref.watch(
    memoryToolResultSelectionProvider.select((state) => state.selectionLimit),
  );
  if (!hasMatchingSession) {
    return const AsyncData<List<SearchResult>>(<SearchResult>[]);
  }

  return ref.watch(
    getSearchResultsProvider(
      offset: 0,
      limit: renderLimit,
    ),
  );
}

final memoryToolResultSelectionProvider = NotifierProvider<
  MemoryToolResultSelectionController,
  MemoryToolResultSelectionState
>(MemoryToolResultSelectionController.new);

final currentSearchResultLivePreviewsProvider =
    FutureProvider.autoDispose<Map<int, MemoryValuePreview>>((ref) async {
      final hasMatchingSession = ref.watch(hasMatchingSearchSessionProvider);
      final isPanelVisible = ref.watch(
        overlayWindowHostRuntimeProvider.select(
          (state) => state.payload.isPanel && !state.isTransitioningToPanel,
        ),
      );
      final renderLimit = ref.watch(
        memoryToolResultSelectionProvider.select((state) => state.selectionLimit),
      );

      if (!hasMatchingSession || !isPanelVisible) {
        return const <int, MemoryValuePreview>{};
      }

      final results = await ref.watch(
        getSearchResultsProvider(offset: 0, limit: renderLimit).future,
      );
      if (results.isEmpty) {
        return const <int, MemoryValuePreview>{};
      }

      final previews = await ref
          .watch(memoryQueryRepositoryProvider)
          .readMemoryValues(
            requests: results
                .take(renderLimit)
                .map(_buildMemoryReadRequestFromResult)
                .toList(growable: false),
          );

      return <int, MemoryValuePreview>{
        for (final preview in previews) preview.address: preview,
      };
    });

class MemoryToolResultSelectionController
    extends Notifier<MemoryToolResultSelectionState> {
  @override
  MemoryToolResultSelectionState build() {
    return const MemoryToolResultSelectionState();
  }

  void updateSelectionLimit(int limit) {
    final clampedLimit = limit < 1 ? 1 : limit;
    state = state.copyWith(
      selectionLimit: clampedLimit,
      selectedAddresses: state.selectedAddresses.take(clampedLimit).toList(),
    );
  }

  void toggle(SearchResult result) {
    final selected = List<int>.from(state.selectedAddresses);
    final address = result.address;
    final existingIndex = selected.indexOf(address);
    if (existingIndex >= 0) {
      selected.removeAt(existingIndex);
      state = state.copyWith(selectedAddresses: selected);
      return;
    }

    if (state.selectionLimit == 1) {
      state = state.copyWith(selectedAddresses: <int>[address]);
      return;
    }

    if (selected.length >= state.selectionLimit) {
      return;
    }

    selected.add(address);
    state = state.copyWith(selectedAddresses: selected);
  }

  void selectVisible(List<SearchResult> results) {
    state = state.copyWith(
      selectedAddresses: results
          .take(state.selectionLimit)
          .map((result) => result.address)
          .toList(),
    );
  }

  void invertVisible(List<SearchResult> results) {
    final visibleAddresses = results.map((result) => result.address).toSet();
    final preserved = state.selectedAddresses
        .where((address) => !visibleAddresses.contains(address))
        .toList();
    final selectedVisible = state.selectedAddresses.toSet();
    for (final result in results) {
      if (selectedVisible.contains(result.address)) {
        continue;
      }
      if (preserved.length >= state.selectionLimit) {
        break;
      }
      preserved.add(result.address);
    }

    state = state.copyWith(selectedAddresses: preserved);
  }

  void clear() {
    if (state.selectedAddresses.isEmpty) {
      return;
    }
    state = state.copyWith(selectedAddresses: const <int>[]);
  }
}

MemoryReadRequest _buildMemoryReadRequestFromResult(SearchResult result) {
  return MemoryReadRequest(
    address: result.address,
    type: result.type,
    length: result.rawBytes.length,
  );
}

@Riverpod(keepAlive: true)
class MemoryToolSearchForm extends _$MemoryToolSearchForm {
  @override
  MemoryToolSearchState build() {
    return const MemoryToolSearchState();
  }

  void updateValue(String value) {
    state = state.copyWith(value: value, validationError: null);
  }

  void updateValueCategory(MemorySearchValueCategoryEnum category) {
    final defaultOption = memorySearchCategoryDefaults[category];
    final advancedOptions =
        memorySearchAdvancedValueOptions[MemorySearchValueCategoryEnum.advanced] ??
        const <MemorySearchValueTypeOptionEnum>[];

    final nextTypeOption = switch (category) {
      MemorySearchValueCategoryEnum.advanced =>
        advancedOptions.contains(state.selectedValueTypeOption)
            ? state.selectedValueTypeOption
            : MemorySearchValueTypeOptionEnum.i8,
      _ => defaultOption ?? state.selectedValueTypeOption,
    };

    state = state.copyWith(
      selectedValueCategory: category,
      selectedValueTypeOption: nextTypeOption,
      validationError: null,
    );
  }

  void updateValueTypeOption(MemorySearchValueTypeOptionEnum option) {
    state = state.copyWith(
      selectedValueTypeOption: option,
      validationError: null,
    );
  }

  void updateRangePreset(MemorySearchRangePresetEnum preset) {
    final shouldSeedCustomSections =
        preset == MemorySearchRangePresetEnum.custom &&
        state.customRangeSections.isEmpty;

    state = state.copyWith(
      selectedRangePreset: preset,
      customRangeSections: shouldSeedCustomSections
          ? _defaultCustomRangeSections()
          : state.customRangeSections,
      validationError: null,
    );
  }

  void toggleCustomRangeSection(MemorySearchRangeSectionEnum section) {
    final nextSections = List<MemorySearchRangeSectionEnum>.from(
      state.customRangeSections,
    );

    if (nextSections.contains(section)) {
      nextSections.remove(section);
    } else {
      nextSections.add(section);
      nextSections.sort((left, right) => left.index.compareTo(right.index));
    }

    state = state.copyWith(
      customRangeSections: nextSections,
      validationError: null,
    );
  }

  void updateEndian(bool isLittleEndian) {
    state = state.copyWith(isLittleEndian: isLittleEndian);
  }

  Future<void> firstScan() async {
    final selectedProcess = ref.read(memoryToolSelectedProcessProvider);
    if (selectedProcess == null) {
      return;
    }

    final validationError = _validateValue(
      type: state.nativeSearchValueType,
      rawValue: state.value,
    );
    if (validationError != null) {
      state = state.copyWith(validationError: validationError);
      return;
    }

    final request = FirstScanRequest(
      pid: selectedProcess.pid,
      value: _buildSearchValue(),
      matchMode: SearchMatchMode.exact,
      rangeSectionKeys: state.effectiveRangeSections
          .map(mapMemorySearchRangeSectionKey)
          .toList(),
      scanAllReadableRegions:
          state.selectedRangePreset == MemorySearchRangePresetEnum.all,
    );

    state = state.copyWith(validationError: null);
    await ref
        .read(memorySearchActionProvider.notifier)
        .firstScan(request: request);
  }

  Future<void> nextScan() async {
    final selectedProcess = ref.read(memoryToolSelectedProcessProvider);
    if (selectedProcess == null) {
      return;
    }

    final validationError = _validateValue(
      type: state.nativeSearchValueType,
      rawValue: state.value,
    );
    if (validationError != null) {
      state = state.copyWith(validationError: validationError);
      return;
    }

    final latestSessionState = await ref.refresh(
      getSearchSessionStateProvider.future,
    );
    final hasMatchingSession =
        latestSessionState.hasActiveSession &&
        latestSessionState.pid == selectedProcess.pid;
    if (!hasMatchingSession) {
      throw StateError('当前没有可继续筛选的搜索会话，请先重新执行首次扫描。');
    }

    final request = NextScanRequest(
      value: _buildSearchValue(),
      matchMode: SearchMatchMode.exact,
    );

    state = state.copyWith(validationError: null);
    await ref
        .read(memorySearchActionProvider.notifier)
        .nextScan(request: request);
  }

  Future<void> resetSearchSession() async {
    state = state.copyWith(validationError: null);
    await ref.read(memorySearchActionProvider.notifier).resetSearchSession();
  }

  MemoryToolSearchValidationError? _validateValue({
    required SearchValueType? type,
    required String rawValue,
  }) {
    final trimmedValue = rawValue.trim();
    if (trimmedValue.isEmpty) {
      return MemoryToolSearchValidationError.valueRequired;
    }

    if (type == null) {
      return MemoryToolSearchValidationError.unsupportedType;
    }

    if (state.isBytesType && _parseBytes(trimmedValue) == null) {
      return MemoryToolSearchValidationError.invalidBytes;
    }

    return null;
  }

  SearchValue _buildSearchValue() {
    final trimmedValue = state.value.trim();
    final nativeType = state.nativeSearchValueType!;
    final bytesValue = state.isTextType
        ? Uint8List.fromList(utf8.encode(trimmedValue))
        : nativeType == SearchValueType.bytes
        ? _parseBytes(trimmedValue)
        : null;
    final textValue = state.isTextType
        ? trimmedValue
        : nativeType == SearchValueType.bytes
        ? null
        : trimmedValue;

    return SearchValue(
      type: nativeType,
      textValue: textValue,
      bytesValue: bytesValue,
      littleEndian: state.isLittleEndian,
    );
  }

  List<MemorySearchRangeSectionEnum> _defaultCustomRangeSections() {
    final sourcePreset = switch (state.selectedRangePreset) {
      MemorySearchRangePresetEnum.all ||
      MemorySearchRangePresetEnum.custom => MemorySearchRangePresetEnum.common,
      _ => state.selectedRangePreset,
    };
    final presetSections = memorySearchRangePresetSections[sourcePreset];
    if (presetSections != null && presetSections.isNotEmpty) {
      return List<MemorySearchRangeSectionEnum>.from(presetSections);
    }

    final allSections =
        memorySearchRangePresetSections[MemorySearchRangePresetEnum.all];
    return List<MemorySearchRangeSectionEnum>.from(
      allSections ?? const <MemorySearchRangeSectionEnum>[],
    );
  }

  Uint8List? _parseBytes(String rawValue) {
    final sanitized = rawValue
        .replaceAll(RegExp(r'0x', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9a-fA-F]'), '');

    if (sanitized.isEmpty || sanitized.length.isOdd) {
      return null;
    }

    final bytes = <int>[];
    for (int index = 0; index < sanitized.length; index += 2) {
      final value = int.tryParse(
        sanitized.substring(index, index + 2),
        radix: 16,
      );
      if (value == null) {
        return null;
      }
      bytes.add(value);
    }

    return Uint8List.fromList(bytes);
  }
}
