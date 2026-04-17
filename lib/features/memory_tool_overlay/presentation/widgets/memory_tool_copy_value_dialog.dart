import 'dart:typed_data';

import 'package:JsxposedX/common/widgets/overlay_window/overlay_panel_dialog.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolCopyValueDialog extends HookConsumerWidget {
  const MemoryToolCopyValueDialog({
    super.key,
    required this.result,
    required this.displayValue,
    required this.livePreviewsAsync,
    required this.onClose,
  });

  final SearchResult result;
  final String displayValue;
  final AsyncValue<Map<int, MemoryValuePreview>> livePreviewsAsync;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final livePreview = livePreviewsAsync.asData?.value[result.address];
    final currentRawBytes = livePreview?.rawBytes ?? result.rawBytes;
    final currentDisplayValue = livePreview?.displayValue ?? displayValue;
    final currentType = livePreview?.type ?? result.type;
    final previewRequests = useMemoized(
      () => SearchValueType.values
          .map(
            (type) => MemoryReadRequest(
              address: result.address,
              type: type,
              length: resolveMemoryToolReadLengthForType(
                type: type,
                bytesLength: currentRawBytes.length,
              ),
            ),
          )
          .toList(growable: false),
      <Object>[result.address, currentRawBytes.length],
    );
    final typedPreviewAsync = ref.watch(
      readMemoryValuesProvider(requests: previewRequests),
    );
    final typedPreviewByType = <SearchValueType, MemoryValuePreview>{
      for (final preview in typedPreviewAsync.asData?.value ?? <MemoryValuePreview>[])
        preview.type: preview,
    };
    final entries = _buildEntries(
      currentType: currentType,
      rawBytes: currentRawBytes,
      sourceDisplayValue: currentDisplayValue,
      typedPreviewByType: typedPreviewByType,
      copyHexLabel: context.l10n.memoryToolResultActionCopyHex,
      copyReverseHexLabel: context.l10n.memoryToolResultActionCopyReverseHex,
    );

    Future<void> copyValue(String value) async {
      final copied = await FlutterOverlayWindow.setClipboardData(value);
      ref.read(overlayWindowHostRuntimeProvider.notifier).showToast(
        copied ? context.l10n.codeCopied : context.l10n.error,
      );
    }

    return OverlayPanelDialog.card(
      onClose: onClose,
      maxWidthPortrait: 408.r,
      maxWidthLandscape: 460.r,
      maxHeightPortrait: 520.r,
      maxHeightLandscape: 440.r,
      cardBorderRadius: 18.r,
      childBuilder: (context, viewport, layout) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.memoryToolResultDetailActionCopyValue,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4.r),
              Text(
                '${context.l10n.memoryToolResultAddress}: ${formatMemoryToolSearchResultAddress(result.address)}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.66),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12.r),
              for (int index = 0; index < entries.length; index++) ...<Widget>[
                if (index > 0) SizedBox(height: 8.r),
                _CopyValueTile(
                  label: entries[index].label,
                  value: entries[index].value,
                  onTap: () async {
                    await copyValue(entries[index].value);
                  },
                ),
              ],
              SizedBox(height: 14.r),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onClose,
                  child: Text(context.l10n.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_CopyValueEntry> _buildEntries({
    required SearchValueType currentType,
    required Uint8List rawBytes,
    required String sourceDisplayValue,
    required Map<SearchValueType, MemoryValuePreview> typedPreviewByType,
    required String copyHexLabel,
    required String copyReverseHexLabel,
  }) {
    final entries = <_CopyValueEntry>[
      for (final type in SearchValueType.values)
        _CopyValueEntry(
          label: mapMemoryToolSearchResultTypeLabel(
            type: type,
            displayValue: type == SearchValueType.bytes ? sourceDisplayValue : '',
          ),
          value: _resolveDisplayValueForType(
            type: type,
            currentType: currentType,
            rawBytes: rawBytes,
            sourceDisplayValue: sourceDisplayValue,
            typedPreviewByType: typedPreviewByType,
          ),
        ),
      _CopyValueEntry(
        label: copyHexLabel,
        value: formatMemoryToolSearchResultHex(rawBytes),
      ),
      _CopyValueEntry(
        label: copyReverseHexLabel,
        value: formatMemoryToolSearchResultReverseHex(rawBytes),
      ),
    ];

    return entries;
  }
}

String _resolveDisplayValueForType({
  required SearchValueType type,
  required SearchValueType currentType,
  required Uint8List rawBytes,
  required String sourceDisplayValue,
  required Map<SearchValueType, MemoryValuePreview> typedPreviewByType,
}) {
  if (type == currentType) {
    return sourceDisplayValue;
  }
  final previewValue = typedPreviewByType[type]?.displayValue;
  if (previewValue != null && previewValue.isNotEmpty) {
    return previewValue;
  }
  final requiredLength = resolveMemoryToolReadLengthForType(
    type: type,
    bytesLength: rawBytes.length,
  );
  if (rawBytes.length >= requiredLength) {
    return resolveMemoryToolSearchResultValueByType(
      type: type,
      rawBytes: rawBytes,
      fallbackDisplayValue: sourceDisplayValue,
    );
  }
  return '...';
}

class _CopyValueEntry {
  const _CopyValueEntry({required this.label, required this.value});

  final String label;
  final String value;
}

class _CopyValueTile extends StatelessWidget {
  const _CopyValueTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () async {
          await onTap();
        },
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 10.r),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.42,
            ),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3.r),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.r),
              Icon(
                Icons.copy_rounded,
                size: 16.r,
                color: context.colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
