import 'package:JsxposedX/common/widgets/overlay_window/overlay_window.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/process_avatar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/process_picker_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/selected_process_panel.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolOverlay extends HookConsumerWidget {
  const MemoryToolOverlay({super.key});

  OverlayWindowConfig get overlayConfig => OverlayWindowConfig(
    sceneId: 0,
    bubbleSize: OverlayWindowPresentation.defaultBubbleSize,
    notificationTitle: (context) => context.l10n.overlayMemoryToolTitle,
    notificationContent: (context) =>
        context.l10n.overlayWindowNotificationContent,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final isPickerVisible = useState(false);
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);

    return Stack(
      children: [
        OverlayWindowScaffold(
          overlayConfig: overlayConfig,
          overlayBar: OverlayWindowBar(
            backgroundColor: context.colorScheme.surface.withValues(alpha: 0.3),
            title: Text(
              context.l10n.overlayMemoryToolTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            leadingWidth: 48.r,
            leading: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                isPickerVisible.value = true;
              },
              icon: ProcessAvatar(process: selectedProcess),
            ),
            showMinimizeAction: true,
            showCloseAction: false,
          ),
          backgroundColor: context.colorScheme.surface.withValues(alpha: 0.6),
          body: SelectedProcessPanel(selectedProcess: selectedProcess),
        ),
        if (isPickerVisible.value)
          Positioned.fill(
            child: MemoryToolProcessPickerDialog(
              onClose: () {
                isPickerVisible.value = false;
              },
              onSelected: (process) {
                ref
                    .read(memoryToolSelectedProcessProvider.notifier)
                    .select(process);
                isPickerVisible.value = false;
              },
              onRetry: () {
                ref.invalidate(getProcessInfoProvider(offset: 0, limit: 20));
              },
            ),
          ),
      ],
    );
  }
}
