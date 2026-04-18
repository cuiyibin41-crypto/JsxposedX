import 'dart:async';

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
    final scrollController = useScrollController();
    final previousTaskStatus = useRef<SearchTaskStatus?>(null);

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
            pointerController.refreshCurrentLayer();
          } else if (taskState.status == SearchTaskStatus.failed ||
              taskState.status == SearchTaskStatus.cancelled) {
            pointerController.markCurrentLayerError(taskState.message);
          }
        }
        previousTaskStatus.value = taskState.status;
      });
      return null;
    }, [taskStateAsync, pointerController, ref]);

    Future<void> jumpToTarget(PointerScanResult result) async {
      final layer = pointerState.currentLayer;
      if (layer == null) {
        return;
      }

      onOpenBrowseTab();
      await ref.read(memoryToolBrowseControllerProvider.notifier).previewFromAddress(
        sourceResult: buildSearchResultFromPointerResult(
          result: result,
          pointerWidth: layer.request.pointerWidth,
        ),
        sourceDisplayValue: formatMemoryToolSearchResultAddress(result.baseAddress),
        targetAddress: result.targetAddress,
      );
    }

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
            children: <Widget>[
              _PointerBreadcrumbRow(
                state: pointerState,
                onTapLayer: pointerController.selectLayer,
              ),
              SizedBox(height: 10.r),
              Expanded(
                child: currentLayer == null
                    ? Center(
                        child: Text(
                          context.l10n.memoryToolPointerEmpty,
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurface.withValues(
                              alpha: 0.66,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
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
                    ? Center(
                        child: Text(
                          context.l10n.noData,
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurface.withValues(
                              alpha: 0.66,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : MemoryToolPointerResultList(
                        results: currentLayer.results,
                        request: currentLayer.request,
                        scrollController: scrollController,
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
            padding: EdgeInsets.only(right: 8.r),
            child: ChoiceChip(
              label: Text(
                'L$index ${formatMemoryToolSearchResultAddress(layer.request.targetAddress)}',
              ),
              selected: selected,
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

  final PointerChainLayerState? currentLayer;
  final AsyncValue<PointerScanSessionState> sessionStateAsync;

  @override
  Widget build(BuildContext context) {
    final loadedCount = currentLayer?.results.length ?? 0;
    final sessionCount = sessionStateAsync.asData?.value.resultCount ?? 0;
    final totalCount = currentLayer?.totalResultCount ?? 0;
    final resolvedTotalCount = totalCount > 0 ? totalCount : sessionCount;
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        context.l10n.memoryToolPointerLoadedCount(
          loadedCount,
          resolvedTotalCount,
        ),
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurface.withValues(alpha: 0.68),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
