import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_fuzzy_mode_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_match_mode_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_preset_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_section_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_value_category_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_value_type_option_enum.dart';
import 'package:flutter/widgets.dart';

String mapMemorySearchValueCategoryLabel(
  BuildContext context,
  MemorySearchValueCategoryEnum category,
) {
  return switch (category) {
    MemorySearchValueCategoryEnum.integer =>
      context.l10n.memoryToolValueCategoryInteger,
    MemorySearchValueCategoryEnum.decimal =>
      context.l10n.memoryToolValueCategoryDecimal,
    MemorySearchValueCategoryEnum.bytes =>
      context.l10n.memoryToolValueCategoryBytes,
    MemorySearchValueCategoryEnum.text =>
      context.l10n.memoryToolValueCategoryText,
    MemorySearchValueCategoryEnum.advanced =>
      context.l10n.memoryToolValueCategoryAdvanced,
  };
}

String mapMemorySearchValueTypeOptionLabel(
  BuildContext context,
  MemorySearchValueTypeOptionEnum option,
) {
  return switch (option) {
    MemorySearchValueTypeOptionEnum.i8 => context.l10n.memoryToolValueTypeI8,
    MemorySearchValueTypeOptionEnum.i16 => context.l10n.memoryToolValueTypeI16,
    MemorySearchValueTypeOptionEnum.i32 => context.l10n.memoryToolValueTypeI32,
    MemorySearchValueTypeOptionEnum.i64 => context.l10n.memoryToolValueTypeI64,
    MemorySearchValueTypeOptionEnum.f32 => context.l10n.memoryToolValueTypeF32,
    MemorySearchValueTypeOptionEnum.f64 => context.l10n.memoryToolValueTypeF64,
    MemorySearchValueTypeOptionEnum.bytes =>
      context.l10n.memoryToolValueTypeBytes,
    MemorySearchValueTypeOptionEnum.xor => context.l10n.memoryToolValueTypeXor,
    MemorySearchValueTypeOptionEnum.auto =>
      context.l10n.memoryToolValueTypeAuto,
    MemorySearchValueTypeOptionEnum.text =>
      context.l10n.memoryToolValueTypeText,
  };
}

String mapMemorySearchMatchModeLabel(
  BuildContext context,
  MemorySearchMatchModeEnum mode,
) {
  return switch (mode) {
    MemorySearchMatchModeEnum.exact => context.l10n.memoryToolSearchExact,
    MemorySearchMatchModeEnum.fuzzy => context.l10n.memoryToolSearchFuzzy,
  };
}

String mapMemorySearchFuzzyModeLabel(
  BuildContext context,
  MemorySearchFuzzyModeEnum mode,
) {
  final isZh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
    'zh',
  );
  return switch (mode) {
    MemorySearchFuzzyModeEnum.unknown => isZh ? '未知初值' : 'Unknown Initial',
    MemorySearchFuzzyModeEnum.unchanged => isZh ? '无变化' : 'Unchanged',
    MemorySearchFuzzyModeEnum.changed => isZh ? '有变化' : 'Changed',
    MemorySearchFuzzyModeEnum.increased => isZh ? '增加了' : 'Increased',
    MemorySearchFuzzyModeEnum.decreased => isZh ? '减少了' : 'Decreased',
  };
}

String mapMemorySearchRangePresetLabel(
  BuildContext context,
  MemorySearchRangePresetEnum preset,
) {
  return switch (preset) {
    MemorySearchRangePresetEnum.common =>
      context.l10n.memoryToolRangePresetCommon,
    MemorySearchRangePresetEnum.java => context.l10n.memoryToolRangePresetJava,
    MemorySearchRangePresetEnum.native =>
      context.l10n.memoryToolRangePresetNative,
    MemorySearchRangePresetEnum.code => context.l10n.memoryToolRangePresetCode,
    MemorySearchRangePresetEnum.all => context.l10n.memoryToolRangePresetAll,
    MemorySearchRangePresetEnum.custom =>
      context.l10n.memoryToolRangePresetCustom,
  };
}

String mapMemorySearchRangeSectionLabel(
  BuildContext context,
  MemorySearchRangeSectionEnum section,
) {
  return switch (section) {
    MemorySearchRangeSectionEnum.anonymous =>
      context.l10n.memoryToolRangeSectionAnonymous,
    MemorySearchRangeSectionEnum.java =>
      context.l10n.memoryToolRangeSectionJava,
    MemorySearchRangeSectionEnum.javaHeap =>
      context.l10n.memoryToolRangeSectionJavaHeap,
    MemorySearchRangeSectionEnum.cAlloc =>
      context.l10n.memoryToolRangeSectionCAlloc,
    MemorySearchRangeSectionEnum.cHeap =>
      context.l10n.memoryToolRangeSectionCHeap,
    MemorySearchRangeSectionEnum.cData =>
      context.l10n.memoryToolRangeSectionCData,
    MemorySearchRangeSectionEnum.cBss =>
      context.l10n.memoryToolRangeSectionCBss,
    MemorySearchRangeSectionEnum.codeApp =>
      context.l10n.memoryToolRangeSectionCodeApp,
    MemorySearchRangeSectionEnum.codeSys =>
      context.l10n.memoryToolRangeSectionCodeSys,
    MemorySearchRangeSectionEnum.stack =>
      context.l10n.memoryToolRangeSectionStack,
    MemorySearchRangeSectionEnum.ashmem =>
      context.l10n.memoryToolRangeSectionAshmem,
    MemorySearchRangeSectionEnum.other =>
      context.l10n.memoryToolRangeSectionOther,
    MemorySearchRangeSectionEnum.bad => context.l10n.memoryToolRangeSectionBad,
  };
}
