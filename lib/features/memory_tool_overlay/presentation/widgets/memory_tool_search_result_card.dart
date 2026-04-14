import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/common/widgets/ref_error.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_search_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_badge.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_dialog.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolSearchResultCard extends HookConsumerWidget {
  const MemoryToolSearchResultCard({
    super.key,
    required this.hasMatchingSession,
    required this.sessionStateAsync,
    required this.onRetry,
  });

  final bool hasMatchingSession;
  final AsyncValue<SearchSessionState> sessionStateAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionState = ref.watch(memoryToolResultSelectionProvider);
    final selectionNotifier = ref.read(
      memoryToolResultSelectionProvider.notifier,
    );
    final livePreviewsAsync = ref.watch(currentSearchResultLivePreviewsProvider);
    final selectedPid = ref.watch(memoryToolSelectedProcessProvider)?.pid;
    final isSettingsVisible = useState(false);

    final resultsAsync = hasMatchingSession
        ? ref.watch(currentSearchResultsProvider)
        : const AsyncValue.data(<SearchResult>[]);
    final displayedResults = resultsAsync.maybeWhen(
      data: (results) => results,
      orElse: () => const <SearchResult>[],
    );
    final resultCount = sessionStateAsync.maybeWhen(
      data: (state) => state.resultCount,
      orElse: () => displayedResults.length,
    );
    final visibleResults = displayedResults
        .take(selectionState.selectionLimit)
        .toList(growable: false);
    final listStorageKey = PageStorageKey<String>(
      'memory_tool_search_results_${selectedPid ?? 0}',
    );

    return Stack(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.r),
          child: !hasMatchingSession
              ? Center(
                  child: Text(
                    context.l10n.noData,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurface.withValues(
                        alpha: 0.66,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : resultsAsync.when(
                  data: (_) {
                    if (visibleResults.isEmpty) {
                      return Center(
                        child: Text(
                          context.l10n.noData,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurface.withValues(
                              alpha: 0.66,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: <Widget>[
                        _MemoryToolResultSelectionBar(
                          onSelectAll: () {
                            selectionNotifier.selectVisible(visibleResults);
                          },
                          onInvert: () {
                            selectionNotifier.invertVisible(visibleResults);
                          },
                          onClear: selectionNotifier.clear,
                          onOpenSettings: () {
                            isSettingsVisible.value = true;
                          },
                        ),
                        SizedBox(height: 1.r),
                        Expanded(
                          child: ListView.separated(
                            key: listStorageKey,
                            padding: EdgeInsets.zero,
                            itemCount: visibleResults.length,
                            separatorBuilder: (_, index) => SizedBox(
                              height: index == visibleResults.length - 1
                                  ? 6.r
                                  : 4.r,
                            ),
                            itemBuilder: (BuildContext context, int index) {
                              final result = visibleResults[index];
                              return _MemoryToolSearchResultTile(
                                result: result,
                                displayValue: _resolveDisplayValue(
                                  result: result,
                                  livePreviewsAsync: livePreviewsAsync,
                                ),
                                isSelected: selectionState.contains(
                                  result.address,
                                ),
                                onToggleSelection: () {
                                  selectionNotifier.toggle(result);
                                },
                                onLongPress: () {
                                  selectionNotifier.toggle(result);
                                },
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 6.r),
                        _MemoryToolResultCountText(count: resultCount),
                      ],
                    );
                  },
                  error: (error, _) => RefError(onRetry: onRetry, error: error),
                  loading: () {
                    if (visibleResults.isNotEmpty) {
                      return Column(
                        children: <Widget>[
                          _MemoryToolResultSelectionBar(
                            onSelectAll: () {
                              selectionNotifier.selectVisible(visibleResults);
                            },
                            onInvert: () {
                              selectionNotifier.invertVisible(visibleResults);
                            },
                            onClear: selectionNotifier.clear,
                            onOpenSettings: () {
                              isSettingsVisible.value = true;
                            },
                          ),
                          SizedBox(height: 1.r),
                          Expanded(
                            child: ListView.separated(
                              key: listStorageKey,
                              padding: EdgeInsets.zero,
                              itemCount: visibleResults.length,
                              separatorBuilder: (_, index) => SizedBox(
                                height: index == visibleResults.length - 1
                                    ? 6.r
                                    : 4.r,
                              ),
                              itemBuilder: (BuildContext context, int index) {
                                final result = visibleResults[index];
                                return _MemoryToolSearchResultTile(
                                  result: result,
                                  displayValue: _resolveDisplayValue(
                                    result: result,
                                    livePreviewsAsync: livePreviewsAsync,
                                  ),
                                  isSelected: selectionState.contains(
                                    result.address,
                                  ),
                                  onToggleSelection: () {
                                    selectionNotifier.toggle(result);
                                  },
                                  onLongPress: () {
                                    selectionNotifier.toggle(result);
                                  },
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 6.r),
                          _MemoryToolResultCountText(count: resultCount),
                        ],
                      );
                    }

                    return const Loading();
                  },
                ),
        ),
        if (isSettingsVisible.value)
          Positioned.fill(
            child: MemoryToolResultSelectionDialog(
              initialLimit: selectionState.selectionLimit,
              onClose: () {
                isSettingsVisible.value = false;
              },
              onConfirm: (value) {
                selectionNotifier.updateSelectionLimit(value);
                isSettingsVisible.value = false;
              },
            ),
          ),
      ],
    );
  }
}

class _MemoryToolResultCountText extends StatelessWidget {
  const _MemoryToolResultCountText({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '${context.l10n.memoryToolSessionResultCount}: $count',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurface.withValues(alpha: 0.64),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _resolveDisplayValue({
  required SearchResult result,
  required AsyncValue<Map<int, MemoryValuePreview>> livePreviewsAsync,
}) {
  return livePreviewsAsync.when(
    data: (previews) => previews[result.address]?.displayValue ?? '--',
    error: (_, _) => '--',
    loading: () => '...',
  );
}

class _MemoryToolResultSelectionBar extends StatelessWidget {
  const _MemoryToolResultSelectionBar({
    required this.onSelectAll,
    required this.onInvert,
    required this.onClear,
    required this.onOpenSettings,
  });

  final VoidCallback onSelectAll;
  final VoidCallback onInvert;
  final VoidCallback onClear;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 6.r),
        child: Row(
          children: <Widget>[
            _MemoryToolToolbarGroup(
              children: <Widget>[
                _MemoryToolToolbarAction(
                  icon: Icons.done_all_rounded,
                  onTap: onSelectAll,
                ),
                _MemoryToolToolbarDivider(),
                _MemoryToolToolbarAction(
                  icon: Icons.flip_rounded,
                  onTap: onInvert,
                ),
                _MemoryToolToolbarDivider(),
                _MemoryToolToolbarAction(
                  icon: Icons.layers_clear_rounded,
                  onTap: onClear,
                ),
                _MemoryToolToolbarDivider(),
                _MemoryToolToolbarAction(
                  icon: Icons.tune_rounded,
                  onTap: onOpenSettings,
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _MemoryToolToolbarGroup extends StatelessWidget {
  const _MemoryToolToolbarGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.r, vertical: 2.r),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _MemoryToolToolbarDivider extends StatelessWidget {
  const _MemoryToolToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18.r,
      margin: EdgeInsets.symmetric(horizontal: 2.r),
      color: context.colorScheme.outlineVariant.withValues(alpha: 0.52),
    );
  }
}

class _MemoryToolToolbarAction extends StatelessWidget {
  const _MemoryToolToolbarAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8.r),
      onTap: onTap,
      child: SizedBox(
        width: 28.r,
        height: 28.r,
        child: Center(
          child: Icon(
            icon,
            size: 18.r,
            color: context.colorScheme.onSurface.withValues(alpha: 0.76),
          ),
        ),
      ),
    );
  }
}

class _MemoryToolSearchResultTile extends StatelessWidget {
  const _MemoryToolSearchResultTile({
    required this.result,
    required this.displayValue,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onLongPress,
  });

  final SearchResult result;
  final String displayValue;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colorScheme.primaryContainer.withValues(alpha: 0.72)
                : context.colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: isSelected
                  ? context.colorScheme.primary
                  : context.colorScheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          padding: EdgeInsets.all(12.r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Transform.scale(
                scale: 0.9,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10.r),
                  onTap: onToggleSelection,
                  onLongPress: onToggleSelection,
                  child: Padding(
                    padding: EdgeInsets.all(2.r),
                    child: Icon(
                      isSelected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 22.r,
                      color: isSelected
                          ? context.colorScheme.primary
                          : context.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.72,
                            ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 4.r),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final valueMaxWidth = constraints.maxWidth * 0.58;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: valueMaxWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                displayValue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: context.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: context.colorScheme.primary,
                                ),
                              ),
                              SizedBox(height: 2.r),
                              MemoryToolResultBadge(
                                label: _typeLabel(
                                  type: result.type,
                                  displayValue: displayValue,
                                ),
                                backgroundColor: _typeBadgeBackground(
                                  context,
                                  result.type,
                                ),
                                foregroundColor: _typeBadgeForeground(
                                  context,
                                  result.type,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10.r),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                _formatHex(result.address),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2.r),
                              Align(
                                alignment: Alignment.centerRight,
                                child: MemoryToolResultBadge(
                                  label: _regionTypeLabel(
                                    context,
                                    result.regionTypeKey,
                                  ),
                                  backgroundColor: _regionBadgeBackground(
                                    context,
                                    result.regionTypeKey,
                                  ),
                                  foregroundColor: _regionBadgeForeground(
                                    context,
                                    result.regionTypeKey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatHex(int value) {
    return '0x${value.toRadixString(16).toUpperCase()}';
  }

  String _typeLabel({
    required SearchValueType type,
    required String displayValue,
  }) {
    return switch (type) {
      SearchValueType.i8 => 'I8',
      SearchValueType.i16 => 'I16',
      SearchValueType.i32 => 'I32',
      SearchValueType.i64 => 'I64',
      SearchValueType.f32 => 'F32',
      SearchValueType.f64 => 'F64',
      SearchValueType.bytes => _looksLikeHexByteSequence(displayValue)
          ? 'AOB'
          : 'TEXT',
    };
  }

  bool _looksLikeHexByteSequence(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return RegExp(r'^[0-9A-F]{2}( [0-9A-F]{2})*$').hasMatch(normalized);
  }

  String _regionTypeLabel(BuildContext context, String regionTypeKey) {
    return switch (regionTypeKey) {
      'anonymous' => context.l10n.memoryToolRangeSectionAnonymous,
      'java' => context.l10n.memoryToolRangeSectionJava,
      'javaHeap' => context.l10n.memoryToolRangeSectionJavaHeap,
      'cAlloc' => context.l10n.memoryToolRangeSectionCAlloc,
      'cHeap' => context.l10n.memoryToolRangeSectionCHeap,
      'cData' => context.l10n.memoryToolRangeSectionCData,
      'cBss' => context.l10n.memoryToolRangeSectionCBss,
      'codeApp' => context.l10n.memoryToolRangeSectionCodeApp,
      'codeSys' => context.l10n.memoryToolRangeSectionCodeSys,
      'stack' => context.l10n.memoryToolRangeSectionStack,
      'ashmem' => context.l10n.memoryToolRangeSectionAshmem,
      'bad' => context.l10n.memoryToolRangeSectionBad,
      'other' => context.l10n.memoryToolRangeSectionOther,
      _ => context.l10n.memoryToolRangeSectionOther,
    };
  }

  Color _typeBadgeBackground(BuildContext context, SearchValueType type) {
    return switch (type) {
      SearchValueType.i8 || SearchValueType.i16 || SearchValueType.i32 =>
        const Color(0xFFE8F4FF),
      SearchValueType.i64 => const Color(0xFFEAF2FF),
      SearchValueType.f32 || SearchValueType.f64 => const Color(0xFFEAFBF1),
      SearchValueType.bytes => const Color(0xFFFFF1E4),
    };
  }

  Color _typeBadgeForeground(BuildContext context, SearchValueType type) {
    return switch (type) {
      SearchValueType.i8 || SearchValueType.i16 || SearchValueType.i32 =>
        const Color(0xFF1E6FD9),
      SearchValueType.i64 => const Color(0xFF3157C8),
      SearchValueType.f32 || SearchValueType.f64 => const Color(0xFF1F8A4D),
      SearchValueType.bytes => const Color(0xFFB56816),
    };
  }

  Color _regionBadgeBackground(BuildContext context, String regionTypeKey) {
    return switch (regionTypeKey) {
      'anonymous' => const Color(0xFFF2F3F7),
      'java' || 'javaHeap' => const Color(0xFFFFF3D9),
      'cAlloc' || 'cHeap' || 'cData' || 'cBss' => const Color(0xFFE9F7EC),
      'codeApp' || 'codeSys' => const Color(0xFFECEBFF),
      'stack' => const Color(0xFFFFE9EE),
      'ashmem' => const Color(0xFFE9F8F7),
      'bad' => const Color(0xFFFFE5E5),
      'other' => const Color(0xFFF4F1FF),
      _ => const Color(0xFFF4F1FF),
    };
  }

  Color _regionBadgeForeground(BuildContext context, String regionTypeKey) {
    return switch (regionTypeKey) {
      'anonymous' => const Color(0xFF5F6675),
      'java' || 'javaHeap' => const Color(0xFF9A6A00),
      'cAlloc' || 'cHeap' || 'cData' || 'cBss' => const Color(0xFF2C8A52),
      'codeApp' || 'codeSys' => const Color(0xFF5A46CC),
      'stack' => const Color(0xFFC14568),
      'ashmem' => const Color(0xFF1E8C84),
      'bad' => const Color(0xFFC13F3F),
      'other' => const Color(0xFF6E56CF),
      _ => const Color(0xFF6E56CF),
    };
  }
}
