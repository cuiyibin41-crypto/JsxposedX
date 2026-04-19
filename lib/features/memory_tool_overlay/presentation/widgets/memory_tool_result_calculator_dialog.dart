import 'package:JsxposedX/common/widgets/overlay_window/overlay_panel_dialog.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolResultCalculatorDialog extends ConsumerWidget {
  const MemoryToolResultCalculatorDialog({
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
    final previewMap =
        livePreviewsAsync.asData?.value ?? <int, MemoryValuePreview>{};
    final items = results
        .asMap()
        .entries
        .map((entry) {
          return _ResolvedCalculatorItem.fromResult(
            index: entry.key,
            result: entry.value,
            preview: previewMap[entry.value.address],
          );
        })
        .whereType<_ResolvedCalculatorItem>()
        .toList(growable: false);
    final pairs = _buildPairs(items);

    return OverlayPanelDialog.card(
      onClose: onClose,
      maxWidthPortrait: 420.r,
      maxWidthLandscape: 560.r,
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
                context.l10n.memoryToolResultCalculatorTitle,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4.r),
              Text(
                context.l10n.memoryToolResultCalculatorSummary(
                  results.length,
                  pairs.length,
                ),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.66),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12.r),
              if (items.length < 2)
                Text(
                  context.l10n.memoryToolResultCalculatorNeedAtLeastTwo,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else ...<Widget>[
                _SectionTitle(
                  label: context.l10n.memoryToolResultCalculatorValues,
                ),
                SizedBox(height: 8.r),
                for (final item in items) ...<Widget>[
                  _ValueLine(item: item),
                  SizedBox(height: 6.r),
                ],
                SizedBox(height: 8.r),
                _SectionTitle(
                  label: context.l10n.memoryToolResultCalculatorCombinations,
                ),
                SizedBox(height: 8.r),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final spacing = 8.r;
                    final gridColumnCount = constraints.maxWidth >= 420.r
                        ? 2
                        : 1;
                    final itemWidth =
                        (constraints.maxWidth -
                            (spacing * (gridColumnCount - 1))) /
                        gridColumnCount;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: pairs
                          .map(
                            (pair) => SizedBox(
                              width: itemWidth,
                              child: _PairCard(
                                pair: pair,
                                onCopy: (value) async {
                                  final copiedMessage = context.l10n.codeCopied;
                                  final failedMessage = context.l10n.error;
                                  final copied =
                                      await FlutterOverlayWindow.setClipboardData(
                                        value,
                                      );
                                  ref
                                      .read(
                                        overlayWindowHostRuntimeProvider
                                            .notifier,
                                      )
                                      .showToast(
                                        copied ? copiedMessage : failedMessage,
                                      );
                                },
                              ),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
              ],
              SizedBox(height: 12.r),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
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

  List<_CalculatorPair> _buildPairs(List<_ResolvedCalculatorItem> items) {
    final pairs = <_CalculatorPair>[];
    for (int left = 0; left < items.length; left++) {
      for (int right = left + 1; right < items.length; right++) {
        pairs.add(_CalculatorPair(left: items[left], right: items[right]));
      }
    }
    return pairs;
  }
}

class _ResolvedCalculatorItem {
  const _ResolvedCalculatorItem({
    required this.index,
    required this.address,
    required this.displayValue,
  });

  final int index;
  final int address;
  final String displayValue;

  static _ResolvedCalculatorItem fromResult({
    required int index,
    required SearchResult result,
    required MemoryValuePreview? preview,
  }) {
    final currentDisplayValue = _resolveCurrentDisplayValue(
      result: result,
      preview: preview,
    );

    return _ResolvedCalculatorItem(
      index: index,
      address: result.address,
      displayValue: currentDisplayValue,
    );
  }

  static String _resolveCurrentDisplayValue({
    required SearchResult result,
    required MemoryValuePreview? preview,
  }) {
    if (result.type == SearchValueType.bytes &&
        isMemoryToolInstructionDisplayValue(result.displayValue)) {
      return result.displayValue.trim();
    }
    final previewDisplayValue = preview?.displayValue.trim();
    if (previewDisplayValue != null && previewDisplayValue.isNotEmpty) {
      return previewDisplayValue;
    }
    return result.displayValue.trim();
  }
}

class _CalculatorPair {
  const _CalculatorPair({required this.left, required this.right});

  final _ResolvedCalculatorItem left;
  final _ResolvedCalculatorItem right;

  int get offset => right.address - left.address;

  int get xorValue => left.address ^ right.address;

  String get title => '#${left.index + 1} / #${right.index + 1}';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: context.colorScheme.onSurface.withValues(alpha: 0.84),
      ),
    );
  }
}

class _ValueLine extends StatelessWidget {
  const _ValueLine({required this.item});

  final _ResolvedCalculatorItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 8.r),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28.r,
              child: Text(
                '#${item.index + 1}',
                style: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 8.r),
            Expanded(
              child: Text(
                '${formatMemoryToolSearchResultAddress(item.address)}  ${item.displayValue}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairCard extends StatelessWidget {
  const _PairCard({required this.pair, required this.onCopy});

  final _CalculatorPair pair;
  final Future<void> Function(String value) onCopy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.34,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(10.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              pair.title,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8.r),
            _CopyValueTile(
              label: context.l10n.memoryToolResultCalculatorOffset,
              value: _formatSignedHex(pair.offset),
              secondaryValue: null,
              copyValue: _formatSignedHex(pair.offset),
              onCopy: onCopy,
            ),
            SizedBox(height: 6.r),
            _CopyValueTile(
              label: context.l10n.memoryToolResultCalculatorXor,
              value: _formatHex(pair.xorValue),
              secondaryValue: null,
              copyValue: _formatHex(pair.xorValue),
              onCopy: onCopy,
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyValueTile extends StatelessWidget {
  const _CopyValueTile({
    required this.label,
    required this.value,
    required this.secondaryValue,
    required this.copyValue,
    required this.onCopy,
  });

  final String label;
  final String value;
  final String? secondaryValue;
  final String copyValue;
  final Future<void> Function(String value) onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10.r),
        onTap: () async {
          await onCopy(copyValue);
        },
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 8.r),
          decoration: BoxDecoration(
            color: context.colorScheme.surface.withValues(alpha: 0.54),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.24),
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
                          alpha: 0.66,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.r),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (secondaryValue != null) ...<Widget>[
                      SizedBox(height: 1.r),
                      Text(
                        secondaryValue!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.62,
                          ),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

String _formatHex(int value) {
  return '0x${value.toUnsigned(64).toRadixString(16).toUpperCase()}';
}

String _formatSignedHex(int value) {
  if (value == 0) {
    return '0x0';
  }
  final prefix = value > 0 ? '+0x' : '-0x';
  return '$prefix${value.abs().toRadixString(16).toUpperCase()}';
}
