import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_preset_maps.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_preset_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_section_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_tool_pointer_alignment_option.dart';

enum MemoryToolPointerFormValidationError {
  invalidMaxOffset,
}

class MemoryToolPointerFormState {
  const MemoryToolPointerFormState({
    this.pointerWidth = 8,
    this.maxOffsetInput = '400',
    this.isHexOffset = true,
    this.selectedAlignment = MemoryToolPointerAlignmentOption.followPointerWidth,
    this.selectedRangePreset = MemorySearchRangePresetEnum.all,
    this.customRangeSections = const <MemorySearchRangeSectionEnum>[],
    this.validationError,
  });

  final int pointerWidth;
  final String maxOffsetInput;
  final bool isHexOffset;
  final MemoryToolPointerAlignmentOption selectedAlignment;
  final MemorySearchRangePresetEnum selectedRangePreset;
  final List<MemorySearchRangeSectionEnum> customRangeSections;
  final MemoryToolPointerFormValidationError? validationError;

  bool get shouldShowCustomRangeSections =>
      selectedRangePreset == MemorySearchRangePresetEnum.custom;

  List<MemorySearchRangeSectionEnum> get effectiveRangeSections {
    if (shouldShowCustomRangeSections) {
      return customRangeSections;
    }
    return memorySearchRangePresetSections[selectedRangePreset] ??
        const <MemorySearchRangeSectionEnum>[];
  }

  int get effectiveAlignment {
    return switch (selectedAlignment) {
      MemoryToolPointerAlignmentOption.followPointerWidth => pointerWidth,
      MemoryToolPointerAlignmentOption.one => 1,
      MemoryToolPointerAlignmentOption.four => 4,
      MemoryToolPointerAlignmentOption.eight => 8,
      MemoryToolPointerAlignmentOption.sixteen => 16,
    };
  }

  MemoryToolPointerFormState copyWith({
    int? pointerWidth,
    String? maxOffsetInput,
    bool? isHexOffset,
    MemoryToolPointerAlignmentOption? selectedAlignment,
    MemorySearchRangePresetEnum? selectedRangePreset,
    List<MemorySearchRangeSectionEnum>? customRangeSections,
    MemoryToolPointerFormValidationError? validationError,
    bool clearValidationError = false,
  }) {
    return MemoryToolPointerFormState(
      pointerWidth: pointerWidth ?? this.pointerWidth,
      maxOffsetInput: maxOffsetInput ?? this.maxOffsetInput,
      isHexOffset: isHexOffset ?? this.isHexOffset,
      selectedAlignment: selectedAlignment ?? this.selectedAlignment,
      selectedRangePreset: selectedRangePreset ?? this.selectedRangePreset,
      customRangeSections: customRangeSections ?? this.customRangeSections,
      validationError: clearValidationError
          ? null
          : validationError ?? this.validationError,
    );
  }
}
