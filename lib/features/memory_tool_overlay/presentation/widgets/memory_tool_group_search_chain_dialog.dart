import 'dart:math' as math;
import 'dart:typed_data';

import 'package:JsxposedX/common/widgets/overlay_window/overlay_panel_dialog.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_group_search_parser.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolGroupSearchChainDialog extends HookConsumerWidget {
  const MemoryToolGroupSearchChainDialog({
    super.key,
    required this.results,
    required this.livePreviewsAsync,
    required this.onClose,
  });

  final List<SearchResult> results;
  final AsyncValue<Map<int, MemoryValuePreview>> livePreviewsAsync;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPid = ref.watch(memoryToolSelectedProcessProvider)?.pid;
    final sortedResults = useMemoized(() {
      final byAddress = <int, SearchResult>{};
      for (final result in results) {
        byAddress[result.address] = result;
      }
      final values = byAddress.values.toList(growable: false);
      values.sort((left, right) => left.address.compareTo(right.address));
      return values;
    }, <Object>[results.length, for (final result in results) result.address]);
    final previewMap =
        livePreviewsAsync.asData?.value ?? const <int, MemoryValuePreview>{};
    final selectedTypes =
        useState<Map<int, SearchValueType>>(<int, SearchValueType>{
          for (final result in sortedResults)
            result.address: _defaultTypeFor(result, previewMap[result.address]),
        });
    final initialWindow = useMemoized(
      () => _defaultWindow(sortedResults),
      <Object>[for (final result in sortedResults) result.address],
    );
    final windowController = useTextEditingController(text: '$initialWindow');
    useListenable(windowController);

    final previewRequests = useMemoized(
      () {
        if (selectedPid == null) {
          return const <MemoryReadRequest>[];
        }
        return <MemoryReadRequest>[
          for (final result in sortedResults)
            for (final type in _chainValueTypes)
              MemoryReadRequest(
                pid: selectedPid,
                address: result.address,
                type: type,
                length: resolveMemoryToolReadLengthForType(
                  type: type,
                  bytesLength: _sourceRawBytes(result, previewMap).length,
                ),
              ),
        ];
      },
      <Object>[
        selectedPid ?? 0,
        for (final result in sortedResults) result.address,
        for (final result in sortedResults)
          _sourceRawBytes(result, previewMap).length,
      ],
    );
    final typedPreviewAsync = selectedPid == null
        ? const AsyncValue.data(<MemoryValuePreview>[])
        : ref.watch(readMemoryValuesProvider(requests: previewRequests));
    final typedPreviewByKey =
        <({int address, SearchValueType type}), MemoryValuePreview>{
          for (final preview
              in typedPreviewAsync.asData?.value ?? <MemoryValuePreview>[])
            (address: preview.address, type: preview.type): preview,
        };

    final window = int.tryParse(windowController.text.trim());
    final minWindow = _requiredWindow(sortedResults);
    final localError = _resolveLocalError(
      context: context,
      results: sortedResults,
      window: window,
      minWindow: minWindow,
    );
    final chain = localError == null
        ? _buildChain(
            results: sortedResults,
            selectedTypes: selectedTypes.value,
            previewMap: previewMap,
            typedPreviewByKey: typedPreviewByKey,
            window: window!,
          )
        : '';

    Future<void> copyChain() async {
      if (chain.isEmpty) {
        return;
      }
      final copiedMessage = context.l10n.codeCopied;
      final failedMessage = context.l10n.error;
      final toastNotifier = ref.read(overlayWindowHostRuntimeProvider.notifier);
      final copied = await FlutterOverlayWindow.setClipboardData(chain);
      toastNotifier.showToast(copied ? copiedMessage : failedMessage);
    }

    return OverlayPanelDialog.card(
      onClose: onClose,
      maxWidthPortrait: 430.r,
      maxWidthLandscape: 620.r,
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
                context.isZh ? '复制联合搜索特征链' : 'Copy Group Search Chain',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4.r),
              Text(
                context.isZh
                    ? '按地址排序生成 anchor + offset 特征'
                    : 'Builds anchor + offset features sorted by address',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.66),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12.r),
              TextField(
                controller: windowController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.isZh ? '窗口字节' : 'Window bytes',
                  hintText: '$minWindow',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.r),
              for (final result in sortedResults) ...<Widget>[
                _GroupChainFeatureTile(
                  result: result,
                  anchorAddress: sortedResults.first.address,
                  selectedType:
                      selectedTypes.value[result.address] ??
                      _defaultTypeFor(result, previewMap[result.address]),
                  preview: previewMap[result.address],
                  typedPreviewByKey: typedPreviewByKey,
                  onSelectedType: (type) {
                    selectedTypes.value = <int, SearchValueType>{
                      ...selectedTypes.value,
                      result.address: type,
                    };
                  },
                ),
                SizedBox(height: 8.r),
              ],
              if (localError != null) ...<Widget>[
                Text(
                  localError,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8.r),
              ],
              _ChainPreview(chain: chain),
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
                    child: FilledButton.icon(
                      onPressed: localError == null ? copyChain : null,
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(context.isZh ? '复制特征链' : 'Copy Chain'),
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

class _GroupChainFeatureTile extends StatelessWidget {
  const _GroupChainFeatureTile({
    required this.result,
    required this.anchorAddress,
    required this.selectedType,
    required this.preview,
    required this.typedPreviewByKey,
    required this.onSelectedType,
  });

  final SearchResult result;
  final int anchorAddress;
  final SearchValueType selectedType;
  final MemoryValuePreview? preview;
  final Map<({int address, SearchValueType type}), MemoryValuePreview>
  typedPreviewByKey;
  final ValueChanged<SearchValueType> onSelectedType;

  @override
  Widget build(BuildContext context) {
    final offset = result.address - anchorAddress;
    final displayValue = _resolveTypedDisplayValue(
      result: result,
      preview: preview,
      type: selectedType,
      typedPreviewByKey: typedPreviewByKey,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.38,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(10.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${formatMemoryToolSearchResultAddress(result.address)}'
                    '${offset == 0 ? '' : '  +$offset'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurface.withValues(
                        alpha: 0.68,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 8.r),
                Text(
                  displayValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.r),
            Wrap(
              spacing: 6.r,
              runSpacing: 6.r,
              children: <Widget>[
                for (final type in _chainValueTypes)
                  ChoiceChip(
                    label: Text(
                      mapMemoryToolSearchResultTypeLabel(
                        type: type,
                        displayValue: type == SearchValueType.bytes
                            ? displayValue
                            : '',
                      ),
                    ),
                    selected: selectedType == type,
                    onSelected: (_) {
                      onSelectedType(type);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChainPreview extends StatelessWidget {
  const _ChainPreview({required this.chain});

  final String chain;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.46,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(10.r),
        child: SelectableText(
          chain.isEmpty ? '...' : chain,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String? _resolveLocalError({
  required BuildContext context,
  required List<SearchResult> results,
  required int? window,
  required int minWindow,
}) {
  if (results.length < 2) {
    return context.isZh ? '至少选择两个数值结果' : 'Select at least two values.';
  }
  if (minWindow > memoryToolGroupSearchMaxWindow) {
    return context.isZh
        ? '选中地址跨度超过 4096 字节'
        : 'Selected address span exceeds 4096 bytes.';
  }
  if (window == null || window <= 0) {
    return context.isZh ? '窗口必须是正整数' : 'Window must be positive.';
  }
  if (window > memoryToolGroupSearchMaxWindow) {
    return context.isZh ? '窗口不能超过 4096 字节' : 'Window cannot exceed 4096 bytes.';
  }
  if (window < minWindow) {
    return context.isZh
        ? '窗口至少需要 $minWindow 字节'
        : 'Window must be at least $minWindow bytes.';
  }
  return null;
}

String _buildChain({
  required List<SearchResult> results,
  required Map<int, SearchValueType> selectedTypes,
  required Map<int, MemoryValuePreview> previewMap,
  required Map<({int address, SearchValueType type}), MemoryValuePreview>
  typedPreviewByKey,
  required int window,
}) {
  final anchorAddress = results.first.address;
  final conditions = <String>[];
  for (final result in results) {
    final type =
        selectedTypes[result.address] ??
        _defaultTypeFor(result, previewMap[result.address]);
    final value = _resolveDslValue(
      result: result,
      preview: previewMap[result.address],
      type: type,
      typedPreviewByKey: typedPreviewByKey,
    );
    final offset = result.address - anchorAddress;
    conditions.add(
      offset == 0
          ? '${_dslType(type)}:$value'
          : '${_dslType(type)}:$value@$offset',
    );
  }
  return '${conditions.join(';')}::$window';
}

int _defaultWindow(List<SearchResult> results) {
  final requiredWindow = _requiredWindow(results);
  return math.min(memoryToolGroupSearchMaxWindow, math.max(32, requiredWindow));
}

int _requiredWindow(List<SearchResult> results) {
  if (results.length < 2) {
    return 1;
  }
  final anchorAddress = results.first.address;
  return results
      .map((result) => result.address - anchorAddress)
      .fold<int>(1, math.max);
}

SearchValueType _defaultTypeFor(
  SearchResult result,
  MemoryValuePreview? preview,
) {
  final type = preview?.type ?? result.type;
  return _chainValueTypes.contains(type) ? type : SearchValueType.i32;
}

Uint8List _sourceRawBytes(
  SearchResult result,
  Map<int, MemoryValuePreview> previewMap,
) {
  final rawBytes = previewMap[result.address]?.rawBytes ?? result.rawBytes;
  return rawBytes.isEmpty ? Uint8List.fromList(<int>[0]) : rawBytes;
}

String _resolveDslValue({
  required SearchResult result,
  required MemoryValuePreview? preview,
  required SearchValueType type,
  required Map<({int address, SearchValueType type}), MemoryValuePreview>
  typedPreviewByKey,
}) {
  if (type == SearchValueType.bytes) {
    final rawBytes =
        typedPreviewByKey[(address: result.address, type: type)]?.rawBytes ??
        preview?.rawBytes ??
        result.rawBytes;
    return formatMemoryToolSearchResultHex(rawBytes);
  }
  return _resolveTypedDisplayValue(
    result: result,
    preview: preview,
    type: type,
    typedPreviewByKey: typedPreviewByKey,
  );
}

String _resolveTypedDisplayValue({
  required SearchResult result,
  required MemoryValuePreview? preview,
  required SearchValueType type,
  required Map<({int address, SearchValueType type}), MemoryValuePreview>
  typedPreviewByKey,
}) {
  final typedPreview = typedPreviewByKey[(address: result.address, type: type)];
  final typedValue = typedPreview?.displayValue.trim();
  if (typedValue != null && typedValue.isNotEmpty) {
    return typedValue;
  }
  final currentType = preview?.type ?? result.type;
  final currentDisplayValue = preview?.displayValue ?? result.displayValue;
  final rawBytes = preview?.rawBytes ?? result.rawBytes;
  if (currentType == type && currentDisplayValue.trim().isNotEmpty) {
    return currentDisplayValue.trim();
  }
  return resolveMemoryToolSearchResultValueByType(
    type: type,
    rawBytes: rawBytes,
    fallbackDisplayValue: currentDisplayValue,
  ).trim();
}

String _dslType(SearchValueType type) {
  return switch (type) {
    SearchValueType.i8 => 'i8',
    SearchValueType.i16 => 'i16',
    SearchValueType.i32 => 'i32',
    SearchValueType.i64 => 'i64',
    SearchValueType.f32 => 'f32',
    SearchValueType.f64 => 'f64',
    SearchValueType.bytes => 'bytes',
  };
}

const List<SearchValueType> _chainValueTypes = <SearchValueType>[
  SearchValueType.i8,
  SearchValueType.i16,
  SearchValueType.i32,
  SearchValueType.i64,
  SearchValueType.f32,
  SearchValueType.f64,
  SearchValueType.bytes,
];
