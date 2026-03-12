import 'package:JsxposedX/core/extensions/context_extensions.dart';
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

  const AiChatInput({
    super.key,
    required this.packageName,
    this.systemPrompt,
    this.showQuickActions = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textController = useTextEditingController();
    final chatState = ref.watch(aiChatActionProvider(packageName: packageName));
    
    final textValue = useValueListenable(textController);
    final hasContent = textValue.text.trim().isNotEmpty;
    final isStreaming = chatState.isStreaming;
    final canSend = hasContent && chatState.canSend;
    final hintText = switch (chatState.sessionInitState) {
      AiSessionInitState.initializing => '逆向会话初始化中…',
      AiSessionInitState.failed => '逆向会话初始化失败，当前不可发送',
      AiSessionInitState.ready => context.l10n.aiChatInputHint,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showQuickActions) AiQuickActions(packageName: packageName, systemPrompt: systemPrompt),
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
                  GestureDetector(
                    onTap: canSend
                        ? () {
                            final text = textController.text.trim();
                            ref.read(aiChatActionProvider(packageName: packageName).notifier).send(text);
                            textController.clear();
                          }
                        : null,
                    child: Container(
                      width: 44.w,
                      height: 44.w,
                      margin: EdgeInsets.only(left: 8.w),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: canSend
                            ? context.colorScheme.primary
                            : context.theme.disabledColor,
                      ),
                      child: Icon(
                        isStreaming
                            ? Icons.hourglass_empty
                            : Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 22.sp,
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
