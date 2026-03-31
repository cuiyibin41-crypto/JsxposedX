import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/core/models/ai_message.dart';
import 'package:JsxposedX/feature/ai/domain/models/ai_session_init_state.dart';
import 'package:JsxposedX/feature/ai/presentation/providers/chat/ai_chat_action_provider.dart';
import 'package:JsxposedX/feature/ai/presentation/widgets/ai_quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AiChatInput extends HookConsumerWidget {
  final String packageName;
  final String? systemPrompt;
  final bool showQuickActions;
  final Future<void> Function()? onRetryInitialization;
  final VoidCallback? onOpenAnalysis;

  const AiChatInput({
    super.key,
    required this.packageName,
    this.systemPrompt,
    this.showQuickActions = true,
    this.onRetryInitialization,
    this.onOpenAnalysis,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textController = useTextEditingController();
    final chatState = ref.watch(aiChatActionProvider(packageName: packageName));
    
    final textValue = useValueListenable(textController);
    final hasContent = textValue.text.trim().isNotEmpty;
    final isStreaming = chatState.isStreaming;
    final canSend = hasContent && chatState.canSend;
    AiMessage? latestSessionSummary;
    for (final message in chatState.protocolMessages.reversed) {
      if (message.role == 'system' &&
          message.content.startsWith('[session_summary]')) {
        latestSessionSummary = message;
        break;
      }
    }
    final hasSessionSummary = latestSessionSummary != null;
    final canCompactContext =
        !hasContent && chatState.hasUserMessages && !isStreaming;
    final canRetryLastTurn = !hasContent && chatState.canRetryLastTurn;
    final canRetryInitialization =
        !hasContent &&
        chatState.sessionInitState == AiSessionInitState.failed &&
        onRetryInitialization != null;
    final actionIcon = isStreaming
        ? Icons.stop_rounded
        : canSend
        ? Icons.arrow_upward_rounded
        : canRetryLastTurn
        ? Icons.refresh_rounded
        : canRetryInitialization
        ? Icons.replay_rounded
        : Icons.arrow_upward_rounded;
    final actionColor = isStreaming || canSend || canRetryLastTurn || canRetryInitialization
        ? context.colorScheme.primary
        : context.theme.disabledColor;
    final hintText = switch (chatState.sessionInitState) {
      AiSessionInitState.initializing => context.l10n.aiReverseSessionInitializingHint,
      AiSessionInitState.failed => context.l10n.aiReverseSessionInitFailedHint,
      AiSessionInitState.ready => context.l10n.aiChatInputHint,
    };
    final actionLabel = isStreaming
        ? context.l10n.aiStopGeneration
        : canSend
        ? context.l10n.sendToAi
        : canRetryLastTurn
        ? context.l10n.aiRetryLastTurn
        : canRetryInitialization
        ? context.l10n.aiRetryInitialization
        : context.l10n.aiUnavailableToSend;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showQuickActions)
          AiQuickActions(
            packageName: packageName,
            systemPrompt: systemPrompt,
            onOpenAnalysis: onOpenAnalysis,
          ),
        Container(
          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 20.h),
          decoration: BoxDecoration(
            color: context.isDark ? context.theme.scaffoldBackgroundColor : Colors.transparent,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: context.isDark ? context.colorScheme.surfaceContainerLow : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      child: TextField(
                        controller: textController,
                        enabled: chatState.sessionInitState == AiSessionInitState.ready,
                        onSubmitted: (_) {
                          if (!canSend) {
                            return;
                          }
                          final text = textController.text.trim();
                          ref
                              .read(
                                aiChatActionProvider(packageName: packageName)
                                    .notifier,
                              )
                              .send(text);
                          textController.clear();
                        },
                        style: TextStyle(
                          fontSize: 15.sp,
                          height: 1.4,
                          color: context.textTheme.bodyLarge?.color,
                        ),
                        decoration: InputDecoration(
                          hintText: hintText,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isDense: true,
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                          hintStyle: TextStyle(
                            color: context.theme.hintColor,
                            fontSize: 15.sp,
                          ),
                        ),
                        maxLines: 5,
                        minLines: 1,
                      ),
                    ),
                  ),
                  if (hasSessionSummary)
                    GestureDetector(
                      onTap: () {
                        final summary = latestSessionSummary?.content;
                        if (summary == null || summary.isEmpty) {
                          return;
                        }
                        showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          isScrollControlled: true,
                          builder: (sheetContext) {
                            return _SessionSummarySheet(summary: summary);
                          },
                        );
                      },
                      child: Container(
                        width: 36.w,
                        height: 36.w,
                        margin: EdgeInsets.only(left: 6.w),
                        decoration: BoxDecoration(
                          color: context.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Tooltip(
                          message: context.l10n.aiViewSummary,
                          child: Icon(
                            Icons.summarize_outlined,
                            size: 18.sp,
                            color: context.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  if (canCompactContext)
                    GestureDetector(
                      onTap: () async {
                        final changed = await ref
                            .read(
                              aiChatActionProvider(packageName: packageName)
                                  .notifier,
                            )
                            .compactContext();
                        if (!context.mounted) {
                          return;
                        }
                        ToastMessage.show(
                          changed
                              ? context.l10n.aiContextCompressed
                              : context.l10n.aiContextAlreadyCompact,
                        );
                      },
                      child: Container(
                        width: 36.w,
                        height: 36.w,
                        margin: EdgeInsets.only(left: 6.w),
                        decoration: BoxDecoration(
                          color: context.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Tooltip(
                          message: context.l10n.aiCompressContext,
                          child: Icon(
                            Icons.compress_rounded,
                            size: 18.sp,
                            color: context.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () async {
                      final notifier = ref.read(
                        aiChatActionProvider(packageName: packageName).notifier,
                      );
                      if (isStreaming) {
                        await notifier.stopStreaming();
                        return;
                      }
                      if (canSend) {
                        final text = textController.text.trim();
                        await notifier.send(text);
                        textController.clear();
                        return;
                      }
                      if (canRetryLastTurn) {
                        await notifier.retryLastTurn();
                        return;
                      }
                      if (canRetryInitialization) {
                        await onRetryInitialization?.call();
                      }
                    },
                    child: Container(
                      width: 44.w,
                      height: 44.w,
                      margin: EdgeInsets.only(left: 8.w),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: actionColor,
                      ),
                      child: Tooltip(
                        message: actionLabel,
                        child: Icon(
                          actionIcon,
                          color: Colors.white,
                          size: 22.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionSummarySheet extends StatelessWidget {
  const _SessionSummarySheet({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    final sections = _parseSummarySections(summary);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.aiSummaryTitle,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12.h),
              for (final entry in sections.entries)
                if (entry.value.isNotEmpty) ...[
                  _SummarySectionCard(
                    title: entry.key,
                    items: entry.value,
                  ),
                  SizedBox(height: 10.h),
                ],
              if (sections.values.every((items) => items.isEmpty))
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Text(
                    context.l10n.aiSummaryEmpty,
                    style: TextStyle(
                      color: context.theme.hintColor,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List<String>> _parseSummarySections(String rawSummary) {
    final sections = <String, List<String>>{
      '历史诉求': [],
      '已知结论': [],
      '工具发现': [],
      '待继续': [],
    };

    String? currentTitle;
    final normalized = rawSummary
        .replaceFirst('[session_summary]', '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    for (final line in normalized) {
      if (line.endsWith('：')) {
        currentTitle = line.substring(0, line.length - 1);
        sections.putIfAbsent(currentTitle, () => <String>[]);
        continue;
      }
      if (!line.startsWith('- ')) {
        continue;
      }
      final content = line.substring(2).trim();
      if (content.isEmpty) {
        continue;
      }
      sections.putIfAbsent(currentTitle ?? '其他', () => <String>[]).add(content);
    }

    return sections;
  }
}

class _SummarySectionCard extends StatelessWidget {
  const _SummarySectionCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: context.colorScheme.primary,
            ),
          ),
          SizedBox(height: 8.h),
          for (final item in items)
            Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Container(
                      width: 4.w,
                      height: 4.w,
                      decoration: BoxDecoration(
                        color: context.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13.sp,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
