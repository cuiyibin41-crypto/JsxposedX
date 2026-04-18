import 'dart:async';

import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_card.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_task_feedback.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_search_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_task_panel.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolSearchTab extends HookConsumerWidget {
  const MemoryToolSearchTab({
    super.key,
    required this.onOpenBrowseTab,
  });

  final VoidCallback onOpenBrowseTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final isSearchDialogVisible = useState(false);
    final selectedPid = ref.watch(memoryToolSelectedProcessProvider)?.pid;
    final sessionStateAsync = ref.watch(getSearchSessionStateProvider);
    final taskStateAsync = ref.watch(getSearchTaskStateProvider);
    final hasMatchingSession = ref.watch(hasMatchingSearchSessionProvider);
    final hasRunningTask = ref.watch(hasRunningSearchTaskProvider);
    final previousTaskStatus = useRef<SearchTaskStatus?>(null);
    final previousSelectedPid = useRef<int?>(selectedPid);
    final previousSessionPid = useRef<int?>(null);

    void scheduleSelectionClear() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        ref.read(memoryToolResultSelectionProvider.notifier).clear();
      });
    }

    void scheduleSearchRefresh() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        ref.invalidate(getSearchSessionStateProvider);
        ref.invalidate(getSearchTaskStateProvider);
        ref.invalidate(getSearchResultsProvider);
        ref.invalidate(hasMatchingSearchSessionProvider);
        ref.invalidate(currentSearchResultsProvider);
      });
    }

    useEffect(() {
      if (!hasRunningTask) {
        return null;
      }

      final timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        ref.invalidate(getSearchTaskStateProvider);
      });
      return timer.cancel;
    }, [hasRunningTask]);

    useEffect(() {
      taskStateAsync.whenData((state) {
        final previousStatus = previousTaskStatus.value;
        final currentStatus = state.status;
        if (previousStatus == SearchTaskStatus.running &&
            currentStatus != SearchTaskStatus.running) {
          scheduleSearchRefresh();
          scheduleSelectionClear();
        }
        previousTaskStatus.value = currentStatus;
      });
      return null;
    }, [taskStateAsync]);

    useEffect(() {
      final previousPid = previousSelectedPid.value;
      if (previousPid != null && previousPid != selectedPid) {
        scheduleSelectionClear();
      }
      previousSelectedPid.value = selectedPid;
      return null;
    }, [selectedPid]);

    useEffect(() {
      sessionStateAsync.whenData((state) {
        final previousPid = previousSessionPid.value;
        final currentSessionPid = state.hasActiveSession ? state.pid : null;
        final hadMatchingSession =
            selectedPid != null && previousPid != null && previousPid == selectedPid;
        final hasExactMatchingSession =
            state.hasActiveSession && selectedPid != null && state.pid == selectedPid;

        if (hadMatchingSession && !hasExactMatchingSession) {
          scheduleSelectionClear();
        }

        previousSessionPid.value = currentSessionPid;
      });
      return null;
    }, [sessionStateAsync, selectedPid]);

    final resultCard = MemoryToolSearchResultCard(
      hasMatchingSession: hasMatchingSession,
      sessionStateAsync: sessionStateAsync,
      onRetry: () {
        ref.invalidate(getSearchSessionStateProvider);
        ref.invalidate(getSearchResultsProvider);
        ref.invalidate(hasMatchingSearchSessionProvider);
        ref.invalidate(currentSearchResultsProvider);
      },
      onOpenSearch: () {
        isSearchDialogVisible.value = true;
      },
      onOpenBrowseTab: onOpenBrowseTab,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.r;
        final padding = EdgeInsets.all(
          constraints.maxHeight < 320 ? 8.r : 12.r,
        );
        final hasTaskFeedback = taskStateAsync.maybeWhen(
          data: (state) =>
              state.status == SearchTaskStatus.cancelled ||
              state.status == SearchTaskStatus.failed,
          orElse: () => false,
        );
        final content = Padding(
          padding: padding,
          child: Column(
            children: <Widget>[
              if (hasTaskFeedback) ...<Widget>[
                MemoryToolSearchTaskFeedback(taskStateAsync: taskStateAsync),
                SizedBox(height: spacing),
              ],
              Expanded(child: resultCard),
            ],
          ),
        );

        return Stack(
          children: <Widget>[
            Positioned.fill(child: content),
            if (isSearchDialogVisible.value)
              Positioned.fill(
                child: MemoryToolSearchDialog(
                  onClose: () {
                    isSearchDialogVisible.value = false;
                  },
                ),
              ),
            taskStateAsync.when(
              skipLoadingOnRefresh: true,
              data: (state) {
                if (state.status != SearchTaskStatus.running) {
                  return const SizedBox.shrink();
                }

                return Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.34),
                    child: MemoryToolSearchTaskPanel(
                      state: state,
                      onCancel: () {
                        ref
                            .read(memorySearchActionProvider.notifier)
                            .cancelSearch();
                      },
                    ),
                  ),
                );
              },
              error: (_, _) => const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}
