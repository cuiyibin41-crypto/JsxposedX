import 'dart:async';

import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_pointer_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/states/memory_tool_pointer_state.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_pointer_utils.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_pointer_result_list.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart'
    show PointerScanResult, PointerScanSessionState, SearchTaskStatus;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolPointerTab extends HookConsumerWidget {
  const MemoryToolPointerTab({
    super.key,
    required this.onOpenBrowseTab,
  });

  final VoidCallback onOpenBrowseTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final pointerState = ref.watch(memoryToolPointerControllerProvider);
    final pointerController = ref.read(memoryToolPointerControllerProvider.notifier);
    final taskStateAsync = ref.watch(getPointerScanTaskStateProvider);
    final sessionStateAsync = ref.watch(getPointerScanSessionStateProvider);
    final currentLayer = pointerState.currentLayer;
    final staticOnlyMode = currentLayer?.staticOnlyMode ?? false;
    final scrollController = useScrollController();
    final previousTaskStatus = useRef<SearchTaskStatus?>(null);
    final selectedRegionTypeKeys = useState<Set<String>>(<String>{});

    useEffect(() {
      void handleScroll() {
        if (!scrollController.hasClients) {
          return;
        }
        if (scrollController.position.extentAfter <= 320.r) {
          pointerController.loadMore();
        }
      }

      scrollController.addListener(handleScroll);
      return () {
        scrollController.removeListener(handleScroll);
      };
    }, [scrollController, pointerController]);

    final isRunningTask = taskStateAsync.maybeWhen(
      data: (state) => state.status == SearchTaskStatus.running,
      orElse: () => false,
    );

    useEffect(() {
      if (!isRunningTask) {
        return null;
      }

      final timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        ref.invalidate(getPointerScanTaskStateProvider);
      });
      return timer.cancel;
    }, [isRunningTask, ref]);

    useEffect(() {
      taskStateAsync.whenData((taskState) {
        final previousStatus = previousTaskStatus.value;
        if (previousStatus == SearchTaskStatus.running &&
            taskState.status != SearchTaskStatus.running) {
          ref.invalidate(getPointerScanSessionStateProvider);
          ref.invalidate(getPointerScanResultsProvider);
          if (taskState.status == SearchTaskStatus.completed) {
            unawaited(pointerController.handleTaskCompleted());
          } else if (taskState.status == SearchTaskStatus.failed ||
              taskState.status == SearchTaskStatus.cancelled) {
            pointerController.handleTaskStopped(
              status: taskState.status,
              message: taskState.message,
            );
          }
        }
        previousTaskStatus.value = taskState.status;
      });
      return null;
    }, [taskStateAsync, pointerController, ref]);

    final availableRegionTypeKeys = <String>[
      if (currentLayer != null)
        ...{
          for (final result in currentLayer.results)
            if (!staticOnlyMode ||
                pointerController.isStaticRegionType(result.regionTypeKey))
              result.regionTypeKey,
        },
    ];
    final availableRegionTypeSignature = availableRegionTypeKeys.join(',');
    final selectedRegionTypeSignature = selectedRegionTypeKeys.value.toList()
      ..sort();
    useEffect(() {
      final nextSelected = selectedRegionTypeKeys.value
          .where(availableRegionTypeKeys.contains)
          .toSet();
      if (nextSelected.length != selectedRegionTypeKeys.value.length) {
        selectedRegionTypeKeys.value = nextSelected;
      }
      return null;
    }, [availableRegionTypeSignature]);

    Future<void> previewAndOpenBrowse(
      Future<void> Function() previewAction,
    ) async {
      try {
        await previewAction();
        onOpenBrowseTab();
      } catch (_) {
        if (!context.mounted) {
          return;
        }
        await ToastOverlayMessage.show(
          context.l10n.memoryToolOffsetPreviewUnreadable,
          duration: const Duration(milliseconds: 1200),
        );
      }
    }

    Future<void> jumpToTarget(PointerScanResult result) async {
      final layer = pointerState.currentLayer;
      if (layer == null) {
        return;
      }

      await previewAndOpenBrowse(
        () => ref
            .read(memoryToolBrowseControllerProvider.notifier)
            .previewFromAddress(
              sourceResult: buildSearchResultFromPointerResult(
                result: result,
                pointerWidth: layer.request.pointerWidth,
              ),
              targetAddress: result.targetAddress,
            ),
      );
    }

    bool matchesPointerResult(PointerScanResult result) {
      if (staticOnlyMode &&
          !pointerController.isStaticRegionType(result.regionTypeKey)) {
        return false;
      }
      if (selectedRegionTypeKeys.value.isNotEmpty &&
          !selectedRegionTypeKeys.value.contains(result.regionTypeKey)) {
        return false;
      }
      return true;
    }

    final filteredResults = currentLayer == null
        ? const <PointerScanResult>[]
        : currentLayer.results
              .where(matchesPointerResult)
              .toList(growable: false);

    useEffect(() {
      if (currentLayer == null ||
          currentLayer.isLoadingInitial ||
          currentLayer.isLoadingMore ||
          !currentLayer.hasMore ||
          filteredResults.length >= 12 ||
          selectedRegionTypeKeys.value.isEmpty) {
        return null;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        pointerController.loadMore();
      });
      return null;
    }, [
      currentLayer?.results.length,
      currentLayer?.hasMore,
      currentLayer?.isLoadingInitial,
      currentLayer?.isLoadingMore,
      filteredResults.length,
      selectedRegionTypeSignature.join(','),
    ]);

    if (selectedProcess == null) {
      return Center(
        child: Text(
          context.l10n.selectApp,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.66),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Stack(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(12.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (currentLayer != null) ...<Widget>[
                _PointerHeaderPanel(
                  state: pointerState,
                  availableRegionTypeKeys: availableRegionTypeKeys,
                  selectedRegionTypeKeys: selectedRegionTypeKeys.value,
                  onTapLayer: pointerController.selectLayer,
                  onToggleRegionTypeKey: (regionTypeKey) {
                    final nextSelected = Set<String>.from(
                      selectedRegionTypeKeys.value,
                    );
                    if (nextSelected.contains(regionTypeKey)) {
                      nextSelected.remove(regionTypeKey);
                    } else {
                      nextSelected.add(regionTypeKey);
                    }
                    selectedRegionTypeKeys.value = nextSelected;
                  },
                  onClearRegionFilters: () {
                    selectedRegionTypeKeys.value = <String>{};
                  },
                ),
              ],
              SizedBox(height: currentLayer == null ? 0 : 6.r),
              Expanded(
                child: currentLayer == null
                    ? const SizedBox.shrink()
                    : currentLayer.results.isEmpty && currentLayer.errorText != null
                    ? Center(
                        child: Text(
                          currentLayer.errorText!,
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : currentLayer.results.isEmpty && !isRunningTask
                    ? const SizedBox.shrink()
                    : filteredResults.isEmpty && !isRunningTask
                    ? const SizedBox.shrink()
                    : MemoryToolPointerResultList(
                        results: filteredResults,
                        request: currentLayer.request,
                        scrollController: scrollController,
                        selectedPointerAddress: currentLayer.selectedPointerAddress,
                        isTerminalLayer: currentLayer.isTerminalLayer,
                        onContinueSearch: (result) async {
                          await pointerController.continueScan(
                            result: result,
                            baseRequest: currentLayer.request,
                          );
                        },
                        onJumpToTarget: jumpToTarget,
                      ),
              ),
              SizedBox(height: 8.r),
              _PointerFooter(
                currentLayer: currentLayer,
                sessionStateAsync: sessionStateAsync,
              ),
            ],
          ),
        ),
        if (taskStateAsync case AsyncData(value: final taskState) when taskState.status == SearchTaskStatus.running)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.22),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colorScheme.surface.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.l10n.memoryToolPointerTaskRunningTitle,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 10.r),
                        SizedBox(
                          width: 28.r,
                          height: 28.r,
                          child: CircularProgressIndicator(strokeWidth: 2.4.r),
                        ),
                        SizedBox(height: 12.r),
                        Text(
                          '${context.l10n.memoryToolTaskRegionsLabel}: ${taskState.processedRegions}/${taskState.totalRegions}',
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4.r),
                        Text(
                          '${context.l10n.memoryToolTaskResultCountLabel}: ${taskState.resultCount}',
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 12.r),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: () {
                              if (pointerState.isAutoChasing) {
                                pointerController.cancelAutoChase();
                                return;
                              }
                              ref
                                  .read(memoryPointerActionProvider.notifier)
                                  .cancelPointerScan();
                            },
                            child: Text(context.l10n.memoryToolTaskCancelAction),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PointerHeaderPanel extends StatelessWidget {
  const _PointerHeaderPanel({
    required this.state,
    required this.availableRegionTypeKeys,
    required this.selectedRegionTypeKeys,
    required this.onTapLayer,
    required this.onToggleRegionTypeKey,
    required this.onClearRegionFilters,
  });

  final MemoryToolPointerState state;
  final List<String> availableRegionTypeKeys;
  final Set<String> selectedRegionTypeKeys;
  final ValueChanged<int> onTapLayer;
  final ValueChanged<String> onToggleRegionTypeKey;
  final VoidCallback onClearRegionFilters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colorScheme.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.38),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10.r, 10.r, 10.r, 10.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PointerBreadcrumbRow(
                state: state,
                onTapLayer: onTapLayer,
              ),
              if (availableRegionTypeKeys.isNotEmpty) ...<Widget>[
                SizedBox(height: 8.r),
                _PointerFilterPanel(
                  selectedRegionTypeKeys: selectedRegionTypeKeys,
                  availableRegionTypeKeys: availableRegionTypeKeys,
                  onToggleRegionTypeKey: onToggleRegionTypeKey,
                  onClearRegionFilters: onClearRegionFilters,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PointerBreadcrumbRow extends StatelessWidget {
  const _PointerBreadcrumbRow({
    required this.state,
    required this.onTapLayer,
  });

  final MemoryToolPointerState state;
  final ValueChanged<int> onTapLayer;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List<Widget>.generate(state.layers.length, (index) {
          final layer = state.layers[index];
          final selected = index == state.currentLayerIndex;
          return Padding(
            padding: EdgeInsets.only(right: 6.r),
            child: ChoiceChip(
              label: Text(
                'L$index ${formatMemoryToolSearchResultAddress(layer.request.targetAddress)}',
              ),
              selected: selected,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              onSelected: (_) {
                onTapLayer(index);
              },
            ),
          );
        }),
      ),
    );
  }
}

class _PointerFooter extends StatelessWidget {
  const _PointerFooter({
    required this.currentLayer,
    required this.sessionStateAsync,
  });

  static const Set<String> _staticRegionTypeKeys = <String>{'cData', 'cBss'};

  final PointerChainLayerState? currentLayer;
  final AsyncValue<PointerScanSessionState> sessionStateAsync;

  @override
  Widget build(BuildContext context) {
    final loadedCount = currentLayer == null
        ? 0
        : currentLayer!.staticOnlyMode
            ? currentLayer!.results
                  .where(
                    (result) => _staticRegionTypeKeys.contains(result.regionTypeKey),
                  )
                  .length
            : currentLayer!.results.length;
    final sessionCount = sessionStateAsync.asData?.value.resultCount ?? 0;
    final totalCount = currentLayer?.totalResultCount ?? 0;
    final resolvedTotalCount = currentLayer?.staticOnlyMode ?? false
        ? loadedCount
        : totalCount > 0
            ? totalCount
            : sessionCount;
    final stopReasonText = switch (currentLayer?.autoStopReasonKey) {
      'staticReached' => context.l10n.memoryToolPointerStopReasonStaticReached,
      'noMorePointers' => context.l10n.memoryToolPointerStopReasonNoMorePointers,
      'maxDepth' => context.l10n.memoryToolPointerStopReasonMaxDepth,
      'cancelled' => context.l10n.memoryToolPointerStopReasonCancelled,
      'failed' => context.l10n.memoryToolPointerStopReasonFailed,
      _ => null,
    };

    if (currentLayer == null ||
        (loadedCount <= 0 &&
            resolvedTotalCount <= 0 &&
            stopReasonText == null)) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (loadedCount > 0 || resolvedTotalCount > 0)
            Text(
              context.l10n.memoryToolPointerLoadedCount(
                loadedCount,
                resolvedTotalCount,
              ),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.68),
                fontWeight: FontWeight.w700,
              ),
            ),
          if (stopReasonText != null) ...<Widget>[
            SizedBox(height: 2.r),
            Text(
              stopReasonText,
              style: context.textTheme.bodySmall?.copyWith(
                color: currentLayer?.autoStopReasonKey == 'failed'
                    ? context.colorScheme.error
                    : context.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PointerFilterPanel extends StatelessWidget {
  const _PointerFilterPanel({
    required this.selectedRegionTypeKeys,
    required this.availableRegionTypeKeys,
    required this.onToggleRegionTypeKey,
    required this.onClearRegionFilters,
  });

  final Set<String> selectedRegionTypeKeys;
  final List<String> availableRegionTypeKeys;
  final ValueChanged<String> onToggleRegionTypeKey;
  final VoidCallback onClearRegionFilters;

  @override
  Widget build(BuildContext context) {
    if (availableRegionTypeKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 6.r),
            child: ChoiceChip(
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              label: Text(context.l10n.memoryToolRangePresetAll),
              selected: selectedRegionTypeKeys.isEmpty,
              onSelected: (_) {
                onClearRegionFilters();
              },
            ),
          ),
          ...availableRegionTypeKeys.map((regionTypeKey) {
            return Padding(
              padding: EdgeInsets.only(right: 6.r),
              child: FilterChip(
                visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                label: Text(
                  mapMemoryToolSearchResultRegionTypeLabel(
                    context,
                    regionTypeKey,
                  ),
                ),
                selected: selectedRegionTypeKeys.contains(regionTypeKey),
                onSelected: (_) {
                  onToggleRegionTypeKey(regionTypeKey);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
