import 'dart:async';

import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_panel_dialog.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolSettingsDialog extends ConsumerWidget {
  const MemoryToolSettingsDialog({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(memoryToolSettingsProvider);

    return OverlayPanelDialog.card(
      onClose: onClose,
      barrierOpacity: 0.32,
      maxWidthPortrait: 340.r,
      maxWidthLandscape: 360.r,
      maxHeightPortrait: 300.r,
      maxHeightLandscape: 260.r,
      landscapeHeightFactor: 1.0,
      cardMinWidth: 260.r,
      cardMaxWidth: 360.r,
      cardBorderRadius: 16.r,
      childBuilder: (context, viewport, layout) {
        return Padding(
          padding: EdgeInsets.all(14.r),
          child: settingsAsync.when(
            data: (settings) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.isZh ? 'Memory Tool 配置' : 'Memory Tool Settings',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 12.r),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: context.colorScheme.outlineVariant.withValues(
                          alpha: 0.34,
                        ),
                      ),
                    ),
                    child: SwitchListTile.adaptive(
                      value: settings.autoPauseOnOverlayOpen,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.r,
                        vertical: 4.r,
                      ),
                      title: Text(
                        context.isZh
                            ? '展开悬浮窗时暂停进程'
                            : 'Pause process when opening overlay',
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onChanged: (value) {
                        unawaited(_updateAutoPause(context, ref, value));
                      },
                    ),
                  ),
                  SizedBox(height: 14.r),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: onClose,
                      child: Text(context.l10n.confirm),
                    ),
                  ),
                ],
              );
            },
            error: (error, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.isZh ? 'Memory Tool 配置' : 'Memory Tool Settings',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 12.r),
                  Text(
                    error.toString().replaceFirst('Exception: ', ''),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.error,
                    ),
                  ),
                  SizedBox(height: 14.r),
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
                          onPressed: () {
                            ref.invalidate(memoryToolSettingsProvider);
                          },
                          child: Text(context.l10n.retry),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => SizedBox(height: 120.r, child: const Loading()),
          ),
        );
      },
    );
  }

  Future<void> _updateAutoPause(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    try {
      await ref
          .read(memoryToolSettingsProvider.notifier)
          .setAutoPauseOnOverlayOpen(value);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      await ToastOverlayMessage.show(
        error.toString().replaceFirst('Exception: ', ''),
        duration: const Duration(milliseconds: 1400),
      );
    }
  }
}
