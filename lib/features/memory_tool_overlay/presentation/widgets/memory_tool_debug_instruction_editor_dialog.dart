import 'package:JsxposedX/common/widgets/custom_text_field.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_panel_dialog.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_text_input_context_menu.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolDebugInstructionEditorDialog extends HookWidget {
  const MemoryToolDebugInstructionEditorDialog({
    super.key,
    required this.initialValue,
    required this.onSave,
    required this.onClose,
  });

  final String initialValue;
  final Future<String?> Function(String value) onSave;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: initialValue);
    useEffect(() {
      controller
        ..text = initialValue
        ..selection = TextSelection.collapsed(offset: initialValue.length);
      return null;
    }, [controller, initialValue]);
    useListenable(controller);
    final isSaving = useState(false);
    final errorText = useState<String?>(null);
    final trimmedValue = controller.text.trim();
    final canSave = !isSaving.value && trimmedValue != initialValue.trim();

    useEffect(() {
      errorText.value = null;
      return null;
    }, [trimmedValue]);

    return OverlayPanelDialog.card(
      onClose: onClose,
      maxWidthPortrait: 420.r,
      maxWidthLandscape: 520.r,
      maxHeightPortrait: 320.r,
      maxHeightLandscape: 320.r,
      cardBorderRadius: 18.r,
      childBuilder: (context, viewport, layout) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(14.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.isZh ? '编辑指令' : 'Edit Instruction',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12.r),
              CustomTextField(
                controller: controller,
                labelText: context.isZh ? '指令' : 'Instruction',
                contextMenuBuilder: buildOverlayTextInputContextMenu,
                maxLines: 6,
                fillColor: context.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.22),
                focusedBorderColor: context.colorScheme.primary,
                enabledBorderColor: context.colorScheme.outlineVariant
                    .withValues(alpha: 0.34),
              ),
              if (errorText.value case final message?) ...<Widget>[
                SizedBox(height: 8.r),
                Text(
                  message,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              SizedBox(height: 14.r),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onClose,
                      child: Text(context.l10n.close),
                    ),
                  ),
                  SizedBox(width: 10.r),
                  Expanded(
                    child: FilledButton(
                      onPressed: canSave
                          ? () async {
                              isSaving.value = true;
                              try {
                                errorText.value = await onSave(trimmedValue);
                              } finally {
                                if (context.mounted) {
                                  isSaving.value = false;
                                }
                              }
                            }
                          : null,
                      child: isSaving.value
                          ? SizedBox(
                              width: 16.r,
                              height: 16.r,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colorScheme.onPrimary,
                              ),
                            )
                          : Text(context.l10n.save),
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
}
