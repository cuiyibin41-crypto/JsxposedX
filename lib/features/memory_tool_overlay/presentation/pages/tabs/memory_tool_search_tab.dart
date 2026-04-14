import 'dart:async';

import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/widgets/memory_tool_search_form_card.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/widgets/memory_tool_search_result_card.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/widgets/memory_tool_search_session_card.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/widgets/memory_tool_search_task_feedback.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/widgets/memory_tool_search_task_overlay.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_search_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolSearchTab extends HookConsumerWidget {
  const MemoryToolSearchTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final searchFormState = ref.watch(memoryToolSearchFormProvider);
    final searchActionState = ref.watch(memorySearchActionProvider);
    final sessionStateAsync = ref.watch(getSearchSessionStateProvider);
    final taskStateAsync = ref.watch(getSearchTaskStateProvider);
    final hasMatchingSession = ref.watch(hasMatchingSearchSessionProvider);
    final hasRunningTask = ref.watch(hasRunningSearchTaskProvider);
    final valueController = useTextEditingController(
      text: searchFormState.value,
    );
    final previousTaskStatus = useRef<SearchTaskStatus?>(null);

    useEffect(() {
      if (valueController.text == searchFormState.value) {
        return null;
      }

      valueController.value = valueController.value.copyWith(
        text: searchFormState.value,
        selection: TextSelection.collapsed(
          offset: searchFormState.value.length,
        ),
        composing: TextRange.empty,
      );
      return null;
    }, [searchFormState.value, valueController]);

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
          ref.invalidate(getSearchSessionStateProvider);
          ref.invalidate(getSearchTaskStateProvider);
          ref.invalidate(getSearchResultsProvider);
          ref.invalidate(hasMatchingSearchSessionProvider);
          ref.invalidate(currentSearchResultsProvider);
        }
        previousTaskStatus.value = currentStatus;
      });
      return null;
    }, [taskStateAsync]);

    final formCard = MemoryToolSearchFormCard(
      valueController: valueController,
      state: searchFormState,
      actionState: searchActionState,
      hasRunningTask: hasRunningTask,
      canRunNextScan: hasMatchingSession,
      onValueChanged: ref
          .read(memoryToolSearchFormProvider.notifier)
          .updateValue,
      onTypeChanged: ref.read(memoryToolSearchFormProvider.notifier).updateType,
      onEndianChanged: ref
          .read(memoryToolSearchFormProvider.notifier)
          .updateEndian,
      onFirstScan: ref.read(memoryToolSearchFormProvider.notifier).firstScan,
      onNextScan: ref.read(memoryToolSearchFormProvider.notifier).nextScan,
      onReset: ref
          .read(memoryToolSearchFormProvider.notifier)
          .resetSearchSession,
      taskStatus: MemoryToolSearchTaskFeedback(taskStateAsync: taskStateAsync),
    );

    final sessionCard = MemoryToolSearchSessionCard(
      sessionStateAsync: sessionStateAsync,
      selectedPid: selectedProcess?.pid,
    );

    final resultCard = MemoryToolSearchResultCard(
      hasMatchingSession: hasMatchingSession,
      sessionStateAsync: sessionStateAsync,
      onRetry: () {
        ref.invalidate(getSearchSessionStateProvider);
        ref.invalidate(getSearchResultsProvider);
        ref.invalidate(hasMatchingSearchSessionProvider);
        ref.invalidate(currentSearchResultsProvider);
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.r;
        final padding = EdgeInsets.all(
          constraints.maxHeight < 320 ? 8.r : 12.r,
        );
        final isCompactLandscape =
            constraints.maxHeight < 320 && constraints.maxWidth > 560;
        final isCompactHeight = constraints.maxHeight < 420;

        Widget content;
        if (isCompactLandscape) {
          content = Padding(
            padding: padding,
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 11,
                  child: ListView(
                    children: <Widget>[
                      formCard,
                      SizedBox(height: spacing),
                      sessionCard,
                    ],
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(flex: 9, child: resultCard),
              ],
            ),
          );
        } else if (isCompactHeight) {
          final resultHeight =
              (constraints.maxHeight.clamp(220.0, 320.0) as double) * 0.9;
          content = ListView(
            padding: padding,
            children: <Widget>[
              formCard,
              SizedBox(height: spacing),
              sessionCard,
              SizedBox(height: spacing),
              SizedBox(height: resultHeight, child: resultCard),
            ],
          );
        } else {
          content = Padding(
            padding: padding,
            child: Column(
              children: <Widget>[
                formCard,
                SizedBox(height: spacing),
                sessionCard,
                SizedBox(height: spacing),
                Expanded(child: resultCard),
              ],
            ),
          );
        }

        return Stack(
          children: <Widget>[
            Positioned.fill(child: content),
            MemoryToolSearchTaskOverlay(
              taskStateAsync: taskStateAsync,
              onCancel: () {
                ref.read(memorySearchActionProvider.notifier).cancelSearch();
              },
            ),
          ],
        );
      },
    );
  }
}
