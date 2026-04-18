import 'package:JsxposedX/common/widgets/overlay_window/overlay_panel_dialog.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_text_input_context_menu.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_preset_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_search_range_section_enum.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/enums/memory_tool_pointer_alignment_option.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_pointer_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_pointer_form_state.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_label_mapper.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_range_key_mapper.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart' show PointerScanRequest;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolPointerScanDialog extends HookConsumerWidget {
  const MemoryToolPointerScanDialog({
    super.key,
    required this.pid,
    required this.targetAddress,
    required this.onConfirm,
    required this.onClose,
  });

  final int pid;
  final int targetAddress;
  final Future<void> Function(PointerScanRequest request) onConfirm;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(memoryToolPointerSearchFormProvider);
    final formNotifier = ref.read(memoryToolPointerSearchFormProvider.notifier);
    final maxOffsetController = useTextEditingController(
      text: formState.maxOffsetInput,
    );

    useEffect(() {
      if (maxOffsetController.text == formState.maxOffsetInput) {
        return null;
      }
      maxOffsetController.value = TextEditingValue(
        text: formState.maxOffsetInput,
        selection: TextSelection.collapsed(
          offset: formState.maxOffsetInput.length,
        ),
      );
      return null;
    }, [formState.maxOffsetInput, maxOffsetController]);

    Future<void> handleConfirm() async {
      final maxOffset = formNotifier.tryParseMaxOffset();
      if (maxOffset == null) {
        return;
      }
      await onConfirm(
        PointerScanRequest(
          pid: pid,
          targetAddress: targetAddress,
          pointerWidth: formState.pointerWidth,
          maxOffset: maxOffset,
          alignment: formState.effectiveAlignment,
          rangeSectionKeys: formState.effectiveRangeSections
              .map(mapMemorySearchRangeSectionKey)
              .toList(growable: false),
          scanAllReadableRegions:
              formState.selectedRangePreset == MemorySearchRangePresetEnum.all,
        ),
      );
      if (context.mounted) {
        onClose();
      }
    }

    return OverlayPanelDialog.card(
      onClose: onClose,
      maxWidthPortrait: 388.r,
      maxWidthLandscape: 520.r,
      maxHeightPortrait: 560.r,
      maxHeightLandscape: 460.r,
      cardBorderRadius: 18.r,
      childBuilder: (context, viewport, layout) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.memoryToolPointerScanTitle,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12.r),
              _PointerDialogLabel(
                label: context.l10n.memoryToolPointerTargetAddressLabel,
              ),
              SizedBox(height: 6.r),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.42,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 12.r),
                  child: Text(
                    formatMemoryToolSearchResultAddress(targetAddress),
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.r),
              _PointerDialogLabel(label: context.l10n.memoryToolPointerWidthLabel),
              SizedBox(height: 6.r),
              Wrap(
                spacing: 8.r,
                runSpacing: 8.r,
                children: const <int>[4, 8].map((width) {
                  return ChoiceChip(
                    label: Text(width.toString()),
                    selected: formState.pointerWidth == width,
                    onSelected: (_) {
                      formNotifier.updatePointerWidth(width);
                    },
                  );
                }).toList(growable: false),
              ),
              SizedBox(height: 12.r),
              _PointerDialogLabel(
                label: context.l10n.memoryToolPointerMaxOffsetLabel,
              ),
              SizedBox(height: 6.r),
              TextField(
                controller: maxOffsetController,
                keyboardType: TextInputType.visiblePassword,
                enableInteractiveSelection: true,
                contextMenuBuilder: buildOverlayTextInputContextMenu,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-FxX]')),
                ],
                onChanged: formNotifier.updateMaxOffsetInput,
                decoration: InputDecoration(
                  hintText: '400',
                  errorText: switch (formState.validationError) {
                    MemoryToolPointerFormValidationError.invalidMaxOffset =>
                      context.l10n.memoryToolPointerInvalidMaxOffset,
                    null => null,
                  },
                  suffixIconConstraints: BoxConstraints(
                    minWidth: 116.r,
                    minHeight: 48.r,
                  ),
                  suffixIcon: Padding(
                    padding: EdgeInsets.only(right: 6.r),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          context.l10n.memoryToolOffsetPreviewHexLabel,
                          style: context.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4.r),
                        Switch.adaptive(
                          value: formState.isHexOffset,
                          onChanged: formNotifier.updateHexOffset,
                        ),
                      ],
                    ),
                  ),
                  filled: true,
                  fillColor: context.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.42),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 12.r),
              _PointerDialogLabel(
                label: context.l10n.memoryToolPointerAlignmentLabel,
              ),
              SizedBox(height: 6.r),
              Wrap(
                spacing: 8.r,
                runSpacing: 8.r,
                children: MemoryToolPointerAlignmentOption.values.map((option) {
                  return ChoiceChip(
                    label: Text(_alignmentLabel(context, option)),
                    selected: formState.selectedAlignment == option,
                    onSelected: (_) {
                      formNotifier.updateAlignment(option);
                    },
                  );
                }).toList(growable: false),
              ),
              SizedBox(height: 12.r),
              _PointerDialogLabel(label: context.l10n.memoryToolFieldScope),
              SizedBox(height: 6.r),
              Wrap(
                spacing: 8.r,
                runSpacing: 8.r,
                children: MemorySearchRangePresetEnum.values.map((preset) {
                  return ChoiceChip(
                    label: Text(mapMemorySearchRangePresetLabel(context, preset)),
                    selected: formState.selectedRangePreset == preset,
                    onSelected: (_) {
                      formNotifier.updateRangePreset(preset);
                    },
                  );
                }).toList(growable: false),
              ),
              if (formState.shouldShowCustomRangeSections) ...<Widget>[
                SizedBox(height: 12.r),
                _PointerDialogLabel(label: context.l10n.memoryToolFieldRangeSection),
                SizedBox(height: 6.r),
                Wrap(
                  spacing: 8.r,
                  runSpacing: 8.r,
                  children: MemorySearchRangeSectionEnum.values.map((section) {
                    return FilterChip(
                      label: Text(mapMemorySearchRangeSectionLabel(context, section)),
                      selected: formState.customRangeSections.contains(section),
                      onSelected: (_) {
                        formNotifier.toggleCustomRangeSection(section);
                      },
                    );
                  }).toList(growable: false),
                ),
              ],
              SizedBox(height: 16.r),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onClose,
                      child: Text(context.l10n.cancel),
                    ),
                  ),
                  SizedBox(width: 10.r),
                  Expanded(
                    child: FilledButton(
                      onPressed: handleConfirm,
                      child: Text(context.l10n.confirm),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _alignmentLabel(
    BuildContext context,
    MemoryToolPointerAlignmentOption option,
  ) {
    return switch (option) {
      MemoryToolPointerAlignmentOption.followPointerWidth =>
        context.l10n.memoryToolPointerAlignmentPointerWidth,
      MemoryToolPointerAlignmentOption.one => '1',
      MemoryToolPointerAlignmentOption.four => '4',
      MemoryToolPointerAlignmentOption.eight => '8',
      MemoryToolPointerAlignmentOption.sixteen => '16',
    };
  }
}

class _PointerDialogLabel extends StatelessWidget {
  const _PointerDialogLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
