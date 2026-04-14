import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_preset_maps.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_preset_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_section_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_value_category_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_value_type_option_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_search_state.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_label_mapper.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolSearchFormCard extends StatelessWidget {
  const MemoryToolSearchFormCard({
    super.key,
    required this.valueController,
    required this.state,
    required this.actionState,
    required this.hasRunningTask,
    required this.canRunNextScan,
    required this.onValueChanged,
    required this.onValueCategoryChanged,
    required this.onValueTypeOptionChanged,
    required this.onRangePresetChanged,
    required this.onCustomRangeSectionToggled,
    required this.onEndianChanged,
    required this.onFirstScan,
    required this.onNextScan,
    required this.onReset,
    this.taskStatus,
  });

  final TextEditingController valueController;
  final MemoryToolSearchState state;
  final AsyncValue<void> actionState;
  final bool hasRunningTask;
  final bool canRunNextScan;
  final ValueChanged<String> onValueChanged;
  final ValueChanged<MemorySearchValueCategoryEnum> onValueCategoryChanged;
  final ValueChanged<MemorySearchValueTypeOptionEnum> onValueTypeOptionChanged;
  final ValueChanged<MemorySearchRangePresetEnum> onRangePresetChanged;
  final ValueChanged<MemorySearchRangeSectionEnum> onCustomRangeSectionToggled;
  final ValueChanged<bool> onEndianChanged;
  final Future<void> Function() onFirstScan;
  final Future<void> Function() onNextScan;
  final Future<void> Function() onReset;
  final Widget? taskStatus;

  @override
  Widget build(BuildContext context) {
    final isRunning = actionState.isLoading || hasRunningTask;
    final isTypeSupported = state.supportsCurrentType;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldLabel(label: context.l10n.memoryToolFieldValueCategory),
        SizedBox(height: 6.r),
        _MemoryToolChoiceChipWrap<MemorySearchValueCategoryEnum>(
          values: memorySearchPrimaryValueCategories,
          selectedValue: state.selectedValueCategory,
          labelBuilder: (category) =>
              mapMemorySearchValueCategoryLabel(context, category),
          onSelected: isRunning ? null : onValueCategoryChanged,
        ),
        if (state.shouldShowAdvancedTypeSelector) ...<Widget>[
          SizedBox(height: 12.r),
          _FieldLabel(label: context.l10n.memoryToolFieldValueTypeOption),
          SizedBox(height: 6.r),
          _MemoryToolChoiceChipWrap<MemorySearchValueTypeOptionEnum>(
            values:
                memorySearchAdvancedValueOptions[MemorySearchValueCategoryEnum
                    .advanced] ??
                const <MemorySearchValueTypeOptionEnum>[],
            selectedValue: state.selectedValueTypeOption,
            labelBuilder: (option) =>
                mapMemorySearchValueTypeOptionLabel(context, option),
            onSelected: isRunning ? null : onValueTypeOptionChanged,
          ),
        ],
        if (!isTypeSupported) ...<Widget>[
          SizedBox(height: 10.r),
          _InlineHint(
            message: context.l10n.memoryToolSearchTypePendingHint,
            color: context.colorScheme.error,
          ),
        ],
        SizedBox(height: 12.r),
        _FieldLabel(label: context.l10n.memoryToolFieldValue),
        SizedBox(height: 6.r),
        _MemoryToolSearchValueField(
          controller: valueController,
          valueTypeOption: state.effectiveValueTypeOption,
          selectedType: state.nativeSearchValueType,
          onChanged: onValueChanged,
        ),
        SizedBox(height: 12.r),
        _FieldLabel(label: context.l10n.memoryToolFieldScope),
        SizedBox(height: 6.r),
        _MemoryToolChoiceChipWrap<MemorySearchRangePresetEnum>(
          values: MemorySearchRangePresetEnum.values,
          selectedValue: state.selectedRangePreset,
          labelBuilder: (preset) =>
              mapMemorySearchRangePresetLabel(context, preset),
          onSelected: isRunning ? null : onRangePresetChanged,
        ),
        if (state.selectedRangePreset != MemorySearchRangePresetEnum.all) ...<
          Widget
        >[
          SizedBox(height: 10.r),
          _InlineHint(
            message: context.l10n.memoryToolRangePresetPendingHint,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ],
        if (state.shouldShowCustomRangeSections) ...<Widget>[
          SizedBox(height: 12.r),
          _FieldLabel(label: context.l10n.memoryToolFieldRangeSection),
          SizedBox(height: 6.r),
          _MemoryToolCustomRangeSectionWrap(
            selectedSections: state.customRangeSections,
            onToggled: isRunning ? null : onCustomRangeSectionToggled,
          ),
        ],
        SizedBox(height: 12.r),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.52,
            ),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.r),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.l10n.memoryToolEndianLabel,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: state.isLittleEndian,
                  onChanged: isRunning ? null : onEndianChanged,
                ),
              ],
            ),
          ),
        ),
        if (state.validationError != null) ...<Widget>[
          SizedBox(height: 10.r),
          Text(
            _validationMessage(context, state.validationError!),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (taskStatus != null) ...<Widget>[
          SizedBox(height: 10.r),
          taskStatus!,
        ],
        if (actionState.hasError) ...<Widget>[
          SizedBox(height: 10.r),
          Text(
            actionState.error.toString(),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.error,
            ),
          ),
        ],
        SizedBox(height: 12.r),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton(
                onPressed: isRunning || !isTypeSupported
                    ? null
                    : () async {
                        await onFirstScan();
                      },
                child: Text(context.l10n.memoryToolActionFirstScan),
              ),
            ),
            SizedBox(width: 10.r),
            Expanded(
              child: FilledButton.tonal(
                onPressed: isRunning || !canRunNextScan || !isTypeSupported
                    ? null
                    : () async {
                        await onNextScan();
                      },
                child: Text(context.l10n.memoryToolActionNextScan),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.r),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: isRunning
                ? null
                : () async {
                    await onReset();
                  },
            child: Text(context.l10n.memoryToolActionReset),
          ),
        ),
      ],
    );
  }

  String _validationMessage(
    BuildContext context,
    MemoryToolSearchValidationError validationError,
  ) {
    return switch (validationError) {
      MemoryToolSearchValidationError.valueRequired =>
        context.l10n.memoryToolValidationValueRequired,
      MemoryToolSearchValidationError.invalidBytes =>
        context.l10n.memoryToolValidationBytesInvalid,
      MemoryToolSearchValidationError.unsupportedType =>
        context.l10n.memoryToolValidationTypeUnsupported,
    };
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: context.colorScheme.onSurface.withValues(alpha: 0.82),
      ),
    );
  }
}

class _InlineHint extends StatelessWidget {
  const _InlineHint({
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: context.textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MemoryToolSearchValueField extends StatelessWidget {
  const _MemoryToolSearchValueField({
    required this.controller,
    required this.valueTypeOption,
    required this.selectedType,
    required this.onChanged,
  });

  final TextEditingController controller;
  final MemorySearchValueTypeOptionEnum valueTypeOption;
  final SearchValueType? selectedType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isBytes = valueTypeOption == MemorySearchValueTypeOptionEnum.bytes;
    final isText = valueTypeOption == MemorySearchValueTypeOptionEnum.text;
    final isFloatType =
        selectedType == SearchValueType.f32 || selectedType == SearchValueType.f64;
    final keyboardType = isBytes
        ? TextInputType.visiblePassword
        : isText
        ? TextInputType.text
        : TextInputType.numberWithOptions(decimal: isFloatType, signed: true);

    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: isBytes
          ? <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-FxX ]')),
            ]
          : null,
      style: context.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: _valueHint(context),
        filled: true,
        fillColor: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        enabledBorder: _inputBorder(context),
        focusedBorder: _inputBorder(
          context,
          color: context.colorScheme.primary.withValues(alpha: 0.9),
          width: 1.4,
        ),
        border: _inputBorder(context),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 14.r),
      ),
    );
  }

  String _valueHint(BuildContext context) {
    if (valueTypeOption == MemorySearchValueTypeOptionEnum.bytes) {
      return context.l10n.memoryToolSearchBytesHint;
    }
    if (valueTypeOption == MemorySearchValueTypeOptionEnum.text) {
      return context.l10n.memoryToolSearchTextHint;
    }
    return context.l10n.memoryToolFieldValueHint;
  }

  OutlineInputBorder _inputBorder(
    BuildContext context, {
    Color? color,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide(
        color:
            color ??
            context.colorScheme.outlineVariant.withValues(alpha: 0.7),
        width: width,
      ),
    );
  }
}

class _MemoryToolChoiceChipWrap<T> extends StatelessWidget {
  const _MemoryToolChoiceChipWrap({
    required this.values,
    required this.selectedValue,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<T> values;
  final T selectedValue;
  final String Function(T value) labelBuilder;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.r,
      runSpacing: 8.r,
      children: values
          .map(
            (value) => ChoiceChip(
              label: Text(labelBuilder(value)),
              selected: value == selectedValue,
              onSelected: onSelected == null
                  ? null
                  : (_) {
                      onSelected!(value);
                    },
              labelStyle: context.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              visualDensity: VisualDensity.compact,
            ),
          )
          .toList(),
    );
  }
}

class _MemoryToolCustomRangeSectionWrap extends StatelessWidget {
  const _MemoryToolCustomRangeSectionWrap({
    required this.selectedSections,
    required this.onToggled,
  });

  final List<MemorySearchRangeSectionEnum> selectedSections;
  final ValueChanged<MemorySearchRangeSectionEnum>? onToggled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.r,
      runSpacing: 8.r,
      children: MemorySearchRangeSectionEnum.values
          .map(
            (section) => FilterChip(
              label: Text(mapMemorySearchRangeSectionLabel(context, section)),
              selected: selectedSections.contains(section),
              onSelected: onToggled == null
                  ? null
                  : (_) {
                      onToggled!(section);
                    },
              labelStyle: context.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              visualDensity: VisualDensity.compact,
            ),
          )
          .toList(),
    );
  }
}
