import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_fuzzy_mode_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_match_mode_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_preset_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_section_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_value_category_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_value_type_option_enum.dart';

const Map<MemorySearchValueCategoryEnum, MemorySearchValueTypeOptionEnum?>
memorySearchCategoryDefaults = <MemorySearchValueCategoryEnum, MemorySearchValueTypeOptionEnum?>{
  MemorySearchValueCategoryEnum.integer: MemorySearchValueTypeOptionEnum.i32,
  MemorySearchValueCategoryEnum.decimal: MemorySearchValueTypeOptionEnum.f32,
  MemorySearchValueCategoryEnum.bytes: MemorySearchValueTypeOptionEnum.bytes,
  MemorySearchValueCategoryEnum.text: MemorySearchValueTypeOptionEnum.text,
  MemorySearchValueCategoryEnum.advanced: null,
};

const Map<MemorySearchValueCategoryEnum, List<MemorySearchValueTypeOptionEnum>>
memorySearchAdvancedValueOptions = <MemorySearchValueCategoryEnum, List<MemorySearchValueTypeOptionEnum>>{
  MemorySearchValueCategoryEnum.advanced: <MemorySearchValueTypeOptionEnum>[
    MemorySearchValueTypeOptionEnum.i8,
    MemorySearchValueTypeOptionEnum.i16,
    MemorySearchValueTypeOptionEnum.i32,
    MemorySearchValueTypeOptionEnum.i64,
    MemorySearchValueTypeOptionEnum.f32,
    MemorySearchValueTypeOptionEnum.f64,
    MemorySearchValueTypeOptionEnum.xor,
    MemorySearchValueTypeOptionEnum.auto,
  ],
};

const List<MemorySearchMatchModeEnum> memorySearchMatchModes =
    <MemorySearchMatchModeEnum>[
      MemorySearchMatchModeEnum.exact,
      MemorySearchMatchModeEnum.fuzzy,
    ];

const List<MemorySearchFuzzyModeEnum> memorySearchFuzzyInitialModes =
    <MemorySearchFuzzyModeEnum>[MemorySearchFuzzyModeEnum.unknown];

const List<MemorySearchFuzzyModeEnum> memorySearchFuzzyFollowUpModes =
    <MemorySearchFuzzyModeEnum>[
      MemorySearchFuzzyModeEnum.unchanged,
      MemorySearchFuzzyModeEnum.changed,
      MemorySearchFuzzyModeEnum.increased,
      MemorySearchFuzzyModeEnum.decreased,
    ];

const Map<MemorySearchRangePresetEnum, List<MemorySearchRangeSectionEnum>>
memorySearchRangePresetSections = <MemorySearchRangePresetEnum, List<MemorySearchRangeSectionEnum>>{
  MemorySearchRangePresetEnum.common: <MemorySearchRangeSectionEnum>[
    MemorySearchRangeSectionEnum.anonymous,
    MemorySearchRangeSectionEnum.cAlloc,
    MemorySearchRangeSectionEnum.other,
  ],
  MemorySearchRangePresetEnum.java: <MemorySearchRangeSectionEnum>[
    MemorySearchRangeSectionEnum.java,
    MemorySearchRangeSectionEnum.javaHeap,
  ],
  MemorySearchRangePresetEnum.native: <MemorySearchRangeSectionEnum>[
    MemorySearchRangeSectionEnum.anonymous,
    MemorySearchRangeSectionEnum.cAlloc,
    MemorySearchRangeSectionEnum.cHeap,
  ],
  MemorySearchRangePresetEnum.code: <MemorySearchRangeSectionEnum>[
    MemorySearchRangeSectionEnum.codeApp,
    MemorySearchRangeSectionEnum.codeSys,
    MemorySearchRangeSectionEnum.cData,
    MemorySearchRangeSectionEnum.cBss,
  ],
  MemorySearchRangePresetEnum.all: MemorySearchRangeSectionEnum.values,
  MemorySearchRangePresetEnum.custom: <MemorySearchRangeSectionEnum>[],
};
