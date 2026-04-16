import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_fuzzy_mode_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_match_mode_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_preset_maps.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_preset_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_section_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_value_category_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_value_type_option_enum.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'memory_tool_search_state.freezed.dart';

enum MemoryToolSearchValidationError {
  valueRequired,
  invalidBytes,
  invalidInteger,
  integerOutOfRange,
  invalidDecimal,
  unsupportedType,
}

@freezed
abstract class MemoryToolSearchState with _$MemoryToolSearchState {
  const MemoryToolSearchState._();

  const factory MemoryToolSearchState({
    @Default('') String value,
    @Default(MemorySearchMatchModeEnum.exact)
    MemorySearchMatchModeEnum selectedMatchMode,
    @Default(MemorySearchFuzzyModeEnum.unknown)
    MemorySearchFuzzyModeEnum selectedFuzzyMode,
    @Default(MemorySearchValueCategoryEnum.integer)
    MemorySearchValueCategoryEnum selectedValueCategory,
    @Default(MemorySearchValueTypeOptionEnum.i32)
    MemorySearchValueTypeOptionEnum selectedValueTypeOption,
    @Default(MemorySearchRangePresetEnum.all)
    MemorySearchRangePresetEnum selectedRangePreset,
    @Default(<MemorySearchRangeSectionEnum>[])
    List<MemorySearchRangeSectionEnum> customRangeSections,
    @Default(true) bool isLittleEndian,
    MemoryToolSearchValidationError? validationError,
  }) = _MemoryToolSearchState;

  MemorySearchValueTypeOptionEnum get effectiveValueTypeOption {
    final defaultOption = memorySearchCategoryDefaults[selectedValueCategory];
    if (selectedValueCategory == MemorySearchValueCategoryEnum.advanced) {
      return selectedValueTypeOption;
    }
    return defaultOption ?? selectedValueTypeOption;
  }

  SearchValueType? get nativeSearchValueType => effectiveValueTypeOption.nativeType;

  SearchValueType get requestSearchValueType => effectiveValueTypeOption.requestType;

  bool get supportsCurrentType => effectiveValueTypeOption.isImplemented;

  bool get isFuzzyMatchMode =>
      selectedMatchMode == MemorySearchMatchModeEnum.fuzzy;

  bool get supportsSelectedMatchMode =>
      supportsCurrentType &&
      (!isFuzzyMatchMode || effectiveValueTypeOption.supportsFuzzySearch);

  bool get isBytesType =>
      effectiveValueTypeOption == MemorySearchValueTypeOptionEnum.bytes;

  bool get isTextType =>
      effectiveValueTypeOption == MemorySearchValueTypeOptionEnum.text;

  bool get isXorType =>
      effectiveValueTypeOption == MemorySearchValueTypeOptionEnum.xor;

  bool get isAutoType =>
      effectiveValueTypeOption == MemorySearchValueTypeOptionEnum.auto;

  bool get usesUtf16LeTextEncoding => isTextType && isLittleEndian;

  bool get shouldShowAdvancedTypeSelector =>
      selectedValueCategory == MemorySearchValueCategoryEnum.advanced;

  bool get shouldShowCustomRangeSections =>
      selectedRangePreset == MemorySearchRangePresetEnum.custom;

  bool get shouldHideValueField => isFuzzyMatchMode;

  List<MemorySearchRangeSectionEnum> get effectiveRangeSections {
    if (shouldShowCustomRangeSections) {
      return customRangeSections;
    }
    return memorySearchRangePresetSections[selectedRangePreset] ??
        const <MemorySearchRangeSectionEnum>[];
  }
}
