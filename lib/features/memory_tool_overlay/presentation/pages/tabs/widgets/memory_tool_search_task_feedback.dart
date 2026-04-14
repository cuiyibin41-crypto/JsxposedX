import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolSearchTaskFeedback extends StatelessWidget {
  const MemoryToolSearchTaskFeedback({super.key, required this.taskStateAsync});

  final AsyncValue<SearchTaskState> taskStateAsync;

  @override
  Widget build(BuildContext context) {
    return taskStateAsync.when(
      skipLoadingOnRefresh: true,
      data: (state) {
        if (state.status != SearchTaskStatus.cancelled &&
            state.status != SearchTaskStatus.failed) {
          return const SizedBox.shrink();
        }

        final isError = state.status == SearchTaskStatus.failed;
        final message = state.message.trim().isEmpty
            ? isError
                  ? context.l10n.memoryToolTaskFailedFallback
                  : context.l10n.memoryToolTaskCancelled
            : state.message;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: isError
                ? context.colorScheme.errorContainer.withValues(alpha: 0.72)
                : context.colorScheme.secondaryContainer.withValues(
                    alpha: 0.72,
                  ),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(12.r),
            child: Text(
              message,
              style: context.textTheme.bodySmall?.copyWith(
                color: isError
                    ? context.colorScheme.onErrorContainer
                    : context.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
      error: (error, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: context.colorScheme.errorContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(12.r),
          child: Text(
            error.toString(),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
    );
  }
}
