import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'bubble_content/bubble_content.dart';
import 'bubble_states/bubble_state.dart';
import 'bubble_toolbar/bubble_toolbar.dart';

abstract class BaseBubbleContainerPart {
  const BaseBubbleContainerPart();

  Widget build(
    BuildContext context,
    BubbleState state, {
    required BaseBubbleContentPart contentPart,
    required BaseBubbleToolbarPart toolbarPart,
  }) {
    final bubbleChild = contentPart.build(
      context,
      state,
      toolbarPart: toolbarPart,
    );

    return Row(
      mainAxisAlignment: resolveMainAxisAlignment(state),
      crossAxisAlignment: resolveCrossAxisAlignment(state),
      children: [
        ...buildLeadingWidgets(context, state),
        Flexible(
          child: Align(
            alignment: resolveBubbleAlignment(state),
            child: Container(
              margin: resolveBubbleMargin(state),
              padding: resolveBubblePadding(state),
              constraints: resolveBubbleConstraints(state),
              decoration: buildBubbleDecoration(context, state),
              child: bubbleChild,
            ),
          ),
        ),
        ...buildTrailingWidgets(context, state),
      ],
    );
  }

  @protected
  MainAxisAlignment resolveMainAxisAlignment(BubbleState state) {
    return state.isUser ? MainAxisAlignment.end : MainAxisAlignment.start;
  }

  @protected
  CrossAxisAlignment resolveCrossAxisAlignment(BubbleState state) {
    return CrossAxisAlignment.end;
  }

  @protected
  Alignment resolveBubbleAlignment(BubbleState state) {
    return state.isUser ? Alignment.centerRight : Alignment.centerLeft;
  }

  @protected
  EdgeInsetsGeometry resolveBubbleMargin(BubbleState state) {
    return EdgeInsets.only(bottom: 20.h);
  }

  @protected
  EdgeInsetsGeometry resolveBubblePadding(BubbleState state) {
    return EdgeInsets.symmetric(
      horizontal: state.isToolResult ? 0 : 16.w,
      vertical: state.isLoading ? 14.h : (state.isToolResult ? 0 : 12.h),
    );
  }

  @protected
  BoxConstraints resolveBubbleConstraints(BubbleState state) {
    return BoxConstraints(maxWidth: 0.85.sw);
  }

  @protected
  Decoration? buildBubbleDecoration(BuildContext context, BubbleState state) {
    if (state.isToolResult) {
      return null;
    }

    return BoxDecoration(
      color: state.isUser
          ? context.colorScheme.primary
          : (context.isDark
                ? context.colorScheme.surfaceContainer
                : Colors.white),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20.r),
        topRight: Radius.circular(20.r),
        bottomLeft: Radius.circular(state.isUser ? 20.r : 6.r),
        bottomRight: Radius.circular(state.isUser ? 6.r : 20.r),
      ),
      border: state.isError
          ? Border.all(
              color: Colors.redAccent.withValues(alpha: 0.3),
              width: 1,
            )
          : null,
      boxShadow: [
        BoxShadow(
          color:
              (state.isUser
                      ? context.colorScheme.primary
                      : (state.isError ? Colors.red : Colors.black))
                  .withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @protected
  List<Widget> buildLeadingWidgets(BuildContext context, BubbleState state) {
    if (!state.isUser && state.isError) {
      return [buildRetryAction(context, state, isLeading: true)];
    }
    return const [];
  }

  @protected
  List<Widget> buildTrailingWidgets(BuildContext context, BubbleState state) {
    if (state.isUser && state.isError) {
      return [buildRetryAction(context, state, isLeading: false)];
    }
    return const [];
  }

  @protected
  Widget buildRetryAction(
    BuildContext context,
    BubbleState state, {
    required bool isLeading,
  }) {
    return GestureDetector(
      onTap: state.onRetry,
      child: Padding(
        padding: EdgeInsets.only(
          right: isLeading ? 8.w : 0,
          left: isLeading ? 0 : 8.w,
          bottom: 20.h,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh_rounded,
                color: Colors.redAccent,
                size: 14.sp,
              ),
              SizedBox(width: 4.w),
              Text(
                state.retryLabel ?? context.l10n.retry,
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DefaultBubbleContainerPart extends BaseBubbleContainerPart {
  const DefaultBubbleContainerPart();
}
