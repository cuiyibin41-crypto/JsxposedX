import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_search_state.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
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
    required this.onTypeChanged,
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
  final ValueChanged<SearchValueType> onTypeChanged;
  final ValueChanged<bool> onEndianChanged;
  final Future<void> Function() onFirstScan;
  final Future<void> Function() onNextScan;
  final Future<void> Function() onReset;
  final Widget? taskStatus;

  @override
  Widget build(BuildContext context) {
    final isRunning = actionState.isLoading || hasRunningTask;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(14.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.memoryToolSearchTabTitle,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4.r),
            Text(
              context.l10n.memoryToolSearchTabSubtitle,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.66),
              ),
            ),
            SizedBox(height: 12.r),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final useColumnLayout = constraints.maxWidth < 420;

                if (useColumnLayout) {
                  return Column(
                    children: <Widget>[
                      _MemoryToolSearchValueField(
                        controller: valueController,
                        selectedType: state.selectedType,
                        onChanged: onValueChanged,
                      ),
                      SizedBox(height: 10.r),
                      _MemoryToolSearchTypeField(
                        selectedType: state.selectedType,
                        onChanged: onTypeChanged,
                      ),
                    ],
                  );
                }

                return Row(
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: _MemoryToolSearchValueField(
                        controller: valueController,
                        selectedType: state.selectedType,
                        onChanged: onValueChanged,
                      ),
                    ),
                    SizedBox(width: 10.r),
                    Expanded(
                      flex: 2,
                      child: _MemoryToolSearchTypeField(
                        selectedType: state.selectedType,
                        onChanged: onTypeChanged,
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 10.r),
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.colorScheme.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 6.r),
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
            Wrap(
              spacing: 10.r,
              runSpacing: 10.r,
              children: <Widget>[
                FilledButton(
                  onPressed: isRunning
                      ? null
                      : () {
                          onFirstScan();
                        },
                  child: Text(context.l10n.memoryToolActionFirstScan),
                ),
                FilledButton.tonal(
                  onPressed: isRunning || !canRunNextScan
                      ? null
                      : () {
                          onNextScan();
                        },
                  child: Text(context.l10n.memoryToolActionNextScan),
                ),
                OutlinedButton(
                  onPressed: isRunning
                      ? null
                      : () {
                          onReset();
                        },
                  child: Text(context.l10n.memoryToolActionReset),
                ),
              ],
            ),
          ],
        ),
      ),
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
    };
  }
}

class _MemoryToolSearchValueField extends StatelessWidget {
  const _MemoryToolSearchValueField({
    required this.controller,
    required this.selectedType,
    required this.onChanged,
  });

  final TextEditingController controller;
  final SearchValueType selectedType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isBytes = selectedType == SearchValueType.bytes;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: context.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: context.l10n.memoryToolFieldValue,
        hintText: isBytes
            ? context.l10n.memoryToolSearchBytesHint
            : context.l10n.memoryToolFieldValueHint,
        filled: true,
        fillColor: context.colorScheme.surface.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 14.r),
      ),
    );
  }
}

class _MemoryToolSearchTypeField extends StatelessWidget {
  const _MemoryToolSearchTypeField({
    required this.selectedType,
    required this.onChanged,
  });

  final SearchValueType selectedType;
  final ValueChanged<SearchValueType> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<SearchValueType>(
      value: selectedType,
      items: SearchValueType.values
          .map(
            (type) => DropdownMenuItem<SearchValueType>(
              value: type,
              child: Text(_typeLabel(type)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) {
          return;
        }
        onChanged(value);
      },
      decoration: InputDecoration(
        labelText: context.l10n.memoryToolFieldType,
        filled: true,
        fillColor: context.colorScheme.surface.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 14.r),
      ),
    );
  }

  String _typeLabel(SearchValueType type) {
    return switch (type) {
      SearchValueType.i8 => 'I8',
      SearchValueType.i16 => 'I16',
      SearchValueType.i32 => 'I32',
      SearchValueType.i64 => 'I64',
      SearchValueType.f32 => 'F32',
      SearchValueType.f64 => 'F64',
      SearchValueType.bytes => 'AOB',
    };
  }
}
