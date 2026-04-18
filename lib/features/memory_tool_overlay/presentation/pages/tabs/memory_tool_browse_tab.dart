import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_batch_edit_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_calculator_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_stats_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_list.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolBrowseTab extends HookConsumerWidget {
  const MemoryToolBrowseTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final browseState = ref.watch(memoryToolBrowseControllerProvider);
    final browseNotifier = ref.read(memoryToolBrowseControllerProvider.notifier);
    final visibleResults = ref.watch(currentBrowseResultsProvider);
    final livePreviewsAsync = ref.watch(currentBrowseResultLivePreviewsProvider);
    final valueHistoryState = ref.watch(memoryValueHistoryProvider);
    final frozenValuesAsync = ref.watch(currentFrozenMemoryValuesProvider);
    final processControlState = ref.watch(memoryProcessControlActionProvider);
    final processPausedAsync = selectedProcess == null
        ? const AsyncValue.data(false)
        : ref.watch(processPausedProvider(pid: selectedProcess.pid));
    final savedItemsNotifier = ref.read(memoryToolSavedItemsProvider.notifier);
    final isSettingsVisible = useState(false);
    final isBatchEditVisible = useState(false);
    final isCalculatorVisible = useState(false);
    final scrollController = useScrollController();
    final previousAnchorAddress = useRef<int?>(null);
    final anchorItemKey = useMemoized(
      () => GlobalKey(debugLabel: 'memory_tool_browse_anchor'),
      [browseState.anchorAddress],
    );

    bool centerAnchorInViewport() {
      if (!scrollController.hasClients || browseState.anchorAddress == null) {
        return false;
      }

      final anchorContext = anchorItemKey.currentContext;
      if (anchorContext != null) {
        final renderObject = anchorContext.findRenderObject();
        if (renderObject != null && scrollController.position.hasContentDimensions) {
          final viewport = RenderAbstractViewport.maybeOf(renderObject);
          if (viewport != null) {
            final revealedOffset = viewport.getOffsetToReveal(
              renderObject,
              0.5,
            );
            final targetOffset = revealedOffset.offset.clamp(
              0.0,
              scrollController.position.maxScrollExtent,
            );
            if ((scrollController.offset - targetOffset).abs() > 0.5) {
              scrollController.jumpTo(targetOffset);
            }
            return true;
          }
        }
      }

      final anchorIndex = visibleResults.indexWhere(
        (result) => result.address == browseState.anchorAddress,
      );
      if (anchorIndex < 0) {
        return false;
      }
      final estimatedItemExtent = 94.r;
      final viewportDimension = scrollController.position.viewportDimension;
      final estimatedOffset =
          (anchorIndex * estimatedItemExtent) -
          ((viewportDimension - estimatedItemExtent) / 2);
      final targetOffset = estimatedOffset.clamp(
        0.0,
        scrollController.position.maxScrollExtent,
      );
      if ((scrollController.offset - targetOffset).abs() > 0.5) {
        scrollController.jumpTo(targetOffset);
      }
      return false;
    }

    void scheduleCenterAnchor({int maxRetries = 8}) {
      final expectedAnchorAddress = browseState.anchorAddress;
      if (expectedAnchorAddress == null) {
        return;
      }

      void attempt(int remainingRetries) {
        if (!context.mounted ||
            browseState.anchorAddress != expectedAnchorAddress) {
          return;
        }
        if (centerAnchorInViewport()) {
          previousAnchorAddress.value = expectedAnchorAddress;
          return;
        }
        if (remainingRetries <= 0) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          attempt(remainingRetries - 1);
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        attempt(maxRetries);
      });
    }

    useEffect(() {
      void handleScroll() {
        if (!scrollController.hasClients) {
          return;
        }
        final position = scrollController.position;
        if (position.pixels <= 180.r) {
          browseNotifier.loadMoreAbove();
        }
        if (position.maxScrollExtent - position.pixels <= 320.r) {
          browseNotifier.loadMoreBelow();
        }
      }

      scrollController.addListener(handleScroll);
      return () {
        scrollController.removeListener(handleScroll);
      };
    }, [scrollController, browseNotifier]);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !scrollController.hasClients) {
          return;
        }
        final position = scrollController.position;
        if (position.pixels <= 180.r &&
            !browseState.isLoadingAbove &&
            !browseState.reachedTopBoundary) {
          browseNotifier.loadMoreAbove();
        }
        if (position.maxScrollExtent - position.pixels <= 320.r &&
            !browseState.isLoadingBelow &&
            !browseState.reachedBottomBoundary) {
          browseNotifier.loadMoreBelow();
        }
      });
      return null;
    }, [
      visibleResults.length,
      browseState.isLoadingAbove,
      browseState.isLoadingBelow,
      browseState.reachedTopBoundary,
      browseState.reachedBottomBoundary,
    ]);

    useEffect(() {
      if (browseState.isInitializing) {
        previousAnchorAddress.value = null;
      }
      return null;
    }, [browseState.isInitializing]);

    useEffect(() {
      final anchorAddress = browseState.anchorAddress;
      if (anchorAddress == null ||
          previousAnchorAddress.value == anchorAddress ||
          visibleResults.isEmpty) {
        return null;
      }

      scheduleCenterAnchor();
      return null;
    }, [browseState.anchorAddress, visibleResults.length]);

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

    final fallbackPreviewMap = <int, MemoryValuePreview>{
      for (final result in visibleResults)
        result.address: MemoryValuePreview(
          address: result.address,
          type: result.type,
          rawBytes: result.rawBytes,
          displayValue: result.displayValue,
        ),
    };
    final resolvedPreviewMap = <int, MemoryValuePreview>{
      ...fallbackPreviewMap,
      ...?livePreviewsAsync.asData?.value,
    };
    final resolvedLivePreviewsAsync =
        AsyncValue<Map<int, MemoryValuePreview>>.data(resolvedPreviewMap);
    final currentFrozenAddresses = frozenValuesAsync.asData?.value
            .where((value) => value.pid == selectedProcess.pid)
            .map((value) => value.address)
            .toSet() ??
        const <int>{};
    final previousValueByAddress = <int, String>{
      for (final entry in valueHistoryState.entries)
        entry.key: entry.value.displayValue,
    };
    final selectedResults = visibleResults
        .where((result) => browseState.selectionState.contains(result.address))
        .toList(growable: false);
    final canRestorePrevious = browseState.selectionState.selectedAddresses.any(
      valueHistoryState.containsKey,
    );
    final visibleResultCount = browseState.results
        .where((result) => !browseState.hiddenAddresses.contains(result.address))
        .length;
    final pageCount = browseState.selectionState.selectionLimit <= 0
        ? 0
        : (visibleResultCount / browseState.selectionState.selectionLimit).ceil();

    Future<void> showSavedToast(int count) async {
      await ToastOverlayMessage.show(
        context.l10n.memoryToolSavedToSavedMessage(count),
        duration: const Duration(milliseconds: 1200),
      );
    }

    Future<void> saveResultsToSaved(Iterable<SearchResult> results) async {
      final resultList = results.toList(growable: false);
      if (resultList.isEmpty) {
        return;
      }

      savedItemsNotifier.saveMany(
        pid: selectedProcess.pid,
        results: resultList,
        previewsByAddress: resolvedPreviewMap,
        frozenAddresses: currentFrozenAddresses,
      );
      await showSavedToast(resultList.length);
    }

    final resultList = browseState.hasAnchor
        ? MemoryToolSearchResultList(
            listStorageKey: PageStorageKey<String>(
              'memory_tool_browse_results_${selectedProcess.pid}_${browseState.anchorAddress ?? 0}',
            ),
            scrollController: scrollController,
            results: visibleResults,
            isSelected: browseState.selectionState.contains,
            onToggleSelection: browseNotifier.toggle,
            onDeleteResult: (result) {
              browseNotifier.hideAddress(result.address);
            },
            livePreviewsAsync: resolvedLivePreviewsAsync,
            previousValueByAddress: previousValueByAddress,
            processPid: selectedProcess.pid,
            initialFrozenStateByAddress: <int, bool>{
              for (final address in currentFrozenAddresses) address: true,
            },
            highlightedAddress: browseState.anchorAddress,
            itemKeyBuilder: (result) {
              if (result.address != browseState.anchorAddress) {
                return null;
              }
              return anchorItemKey;
            },
          )
        : _MemoryToolBrowseEmptyState(
            message: context.l10n.memoryToolBrowseEmpty,
          );

    return Stack(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(12.r),
          child: Column(
            children: <Widget>[
              MemoryToolResultSelectionBar(
                actions: <MemoryToolResultSelectionActionData>[
                  MemoryToolResultSelectionActionData(
                    icon: Icons.my_location_rounded,
                    onTap: browseState.hasAnchor
                        ? () async {
                            await browseNotifier.recenter();
                            if (!context.mounted) {
                              return;
                            }
                            scheduleCenterAnchor();
                          }
                        : null,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: processPausedAsync.asData?.value ?? false
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    onTap:
                        processControlState.isLoading || processPausedAsync.isLoading
                        ? null
                        : () async {
                            try {
                              final isPaused =
                                  processPausedAsync.asData?.value ?? false;
                              await ref
                                  .read(
                                    memoryProcessControlActionProvider.notifier,
                                  )
                                  .setProcessPaused(
                                    pid: selectedProcess.pid,
                                    paused: !isPaused,
                                  );
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.done_all_rounded,
                    onTap: visibleResults.isEmpty
                        ? null
                        : () {
                            browseNotifier.selectVisible(visibleResults);
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.flip_rounded,
                    onTap: visibleResults.isEmpty
                        ? null
                        : () {
                            browseNotifier.invertVisible(visibleResults);
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.layers_clear_rounded,
                    onTap: visibleResults.isEmpty
                        ? null
                        : browseNotifier.clearSelection,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.delete_sweep_rounded,
                    onTap: selectedResults.isEmpty
                        ? null
                        : () {
                            browseNotifier.hideMany(
                              browseState.selectionState.selectedAddresses,
                            );
                            browseNotifier.clearSelection();
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.save_alt_rounded,
                    onTap: selectedResults.isEmpty
                        ? null
                        : () async {
                            await saveResultsToSaved(selectedResults);
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.calculate_outlined,
                    onTap: selectedResults.length >= 2
                        ? () {
                            isCalculatorVisible.value = true;
                          }
                        : null,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.edit_rounded,
                    onTap: selectedResults.isEmpty
                        ? null
                        : () {
                            isBatchEditVisible.value = true;
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.undo_rounded,
                    onTap: canRestorePrevious
                        ? () async {
                            try {
                              final sessionState = await ref.read(
                                getSearchSessionStateProvider.future,
                              );
                              await ref
                                  .read(memoryValueActionProvider.notifier)
                                  .restorePreviousValues(
                                    addresses: browseState
                                        .selectionState
                                        .selectedAddresses,
                                    littleEndian: sessionState.littleEndian,
                                  );
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          }
                        : null,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.tune_rounded,
                    onTap: () {
                      isSettingsVisible.value = true;
                    },
                  ),
                ],
              ),
              SizedBox(height: 8.r),
              Expanded(
                child: browseState.isInitializing && !browseState.hasAnchor
                    ? const Loading()
                    : browseState.errorText != null && !browseState.hasAnchor
                    ? _MemoryToolBrowseEmptyState(message: browseState.errorText!)
                    : visibleResults.isEmpty && browseState.hasAnchor
                    ? _MemoryToolBrowseEmptyState(message: context.l10n.noData)
                    : resultList,
              ),
              SizedBox(height: 6.r),
              MemoryToolResultStatsBar(
                resultCount: visibleResultCount,
                selectedCount: browseState.selectionState.selectedCount,
                renderedCount: visibleResults.length,
                pageCount: pageCount,
              ),
            ],
          ),
        ),
        if (isSettingsVisible.value)
          Positioned.fill(
            child: MemoryToolResultSelectionDialog(
              initialLimit: browseState.selectionState.selectionLimit,
              onClose: () {
                isSettingsVisible.value = false;
              },
              onConfirm: (value) {
                browseNotifier.updateSelectionLimit(value);
                isSettingsVisible.value = false;
              },
            ),
          ),
        if (isBatchEditVisible.value)
          Positioned.fill(
            child: MemoryToolBatchEditDialog(
              results: selectedResults,
              livePreviewsAsync: resolvedLivePreviewsAsync,
              savedSyncMode: MemoryToolBatchEditSavedSyncMode.frozenOnly,
              onClose: () {
                isBatchEditVisible.value = false;
              },
            ),
          ),
        if (isCalculatorVisible.value)
          Positioned.fill(
            child: MemoryToolResultCalculatorDialog(
              results: selectedResults,
              livePreviewsAsync: resolvedLivePreviewsAsync,
              onClose: () {
                isCalculatorVisible.value = false;
              },
            ),
          ),
      ],
    );
  }
}

class _MemoryToolBrowseEmptyState extends StatelessWidget {
  const _MemoryToolBrowseEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.r),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.66),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
