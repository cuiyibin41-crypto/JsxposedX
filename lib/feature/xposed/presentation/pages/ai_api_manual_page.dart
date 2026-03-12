import 'package:JsxposedX/common/widgets/custom_dIalog.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/core/models/ai_session.dart';
import 'package:JsxposedX/feature/ai/presentation/providers/chat/ai_chat_action_provider.dart';
import 'package:JsxposedX/feature/ai/presentation/states/ai_chat_action_state.dart';
import 'package:JsxposedX/feature/ai/presentation/widgets/ai_chat_input.dart';
import 'package:JsxposedX/feature/ai/presentation/widgets/ai_chat_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

class AiApiManualPage extends HookConsumerWidget {
  final String? initialApiType;

  const AiApiManualPage({super.key, this.initialApiType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isZh = context.isZh;
    final apiType = useState<String>(initialApiType ?? 'xposed'); // 'xposed' or 'frida'

    // 加载 MD 文档内容
    final mdFuture = useMemoized(
      () => rootBundle.loadString(
        apiType.value == 'frida'
            ? (isZh ? 'assets/raws/Frida_API.md' : 'assets/raws/Frida_API_en.md')
            : (isZh ? 'assets/raws/JsxposedX_API.md' : 'assets/raws/JsxposedX_API_en.md'),
      ),
      [isZh, apiType.value],
    );
    final mdSnapshot = useFuture(mdFuture);

    if (!mdSnapshot.hasData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final systemPrompt = _buildSystemPrompt(mdSnapshot.data!, isZh, apiType.value);

    final packageName = 'jsxposed_api_manual_${apiType.value}';

    final chatState = ref.watch(
      aiChatActionProvider(packageName: packageName),
    );
    final scrollController = useScrollController();

    // 加载完成后设置 system prompt
    useEffect(() {
      Future.microtask(() {
        ref
            .read(aiChatActionProvider(packageName: packageName).notifier)
            .setSystemPrompt(systemPrompt);
      });
      return null;
    }, [packageName, systemPrompt]);

    // 自动滚动逻辑（同 AiReversePage）
    final lastMessageId = useRef<String?>(null);
    useEffect(() {
      final visibleMessages = chatState.visibleMessages;
      if (visibleMessages.isNotEmpty) {
        final currentLastId = visibleMessages.last.id;
        final isNewMessage = lastMessageId.value != currentLastId;
        lastMessageId.value = currentLastId;

        if (scrollController.hasClients && isNewMessage) {
          Future.microtask(() {
            scrollController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          });
        }
      }
      return null;
    }, [chatState.visibleMessages.length]);

    return Scaffold(
      appBar: _buildAppBar(context, ref, chatState, systemPrompt, apiType),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AiChatList(
                messages: chatState.visibleMessages,
                scrollController: scrollController,
                packageName: packageName,
                systemPrompt: systemPrompt,
                customTitle: apiType.value == 'frida'
                    ? (isZh ? 'Frida API 助手' : 'Frida API Assistant')
                    : (isZh ? 'JsxposedX API 助手' : 'JsxposedX API Assistant'),
                customSubtitle: isZh
                    ? '有任何关于 ${apiType.value == 'frida' ? 'Frida' : 'JsxposedX'} API 的问题都可以问我'
                    : 'Ask me anything about ${apiType.value == 'frida' ? 'Frida' : 'JsxposedX'} API',
              ),
            ),
            AiChatInput(
              packageName: packageName,
              systemPrompt: systemPrompt,
              showQuickActions: false,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    AiChatActionState chatState,
    String systemPrompt,
    ValueNotifier<String> apiType,
  ) {
    final packageName = 'jsxposed_api_manual_${apiType.value}';
    final providerKey = aiChatActionProvider(packageName: packageName);

    return AppBar(
      title: Text(context.l10n.aiApiManualTitle),
      actions: [
        // API 类型切换按钮
        PopupMenuButton<String>(
          icon: Icon(
            apiType.value == 'xposed' ? Icons.code_rounded : Icons.memory_rounded,
            size: 20.sp,
          ),
          tooltip: 'Switch API',
          offset: const Offset(0, 40),
          onSelected: (value) {
            apiType.value = value;
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'xposed',
              child: Row(
                children: [
                  Icon(
                    Icons.code_rounded,
                    size: 16.sp,
                    color: apiType.value == 'xposed' ? context.colorScheme.primary : null,
                  ),
                  SizedBox(width: 8.w),
                  Text('Xposed API'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'frida',
              child: Row(
                children: [
                  Icon(
                    Icons.memory_rounded,
                    size: 16.sp,
                    color: apiType.value == 'frida' ? context.colorScheme.primary : null,
                  ),
                  SizedBox(width: 8.w),
                  Text('Frida API'),
                ],
              ),
            ),
          ],
        ),
        PopupMenuButton<AiSession>(
          icon: Icon(Icons.chat_bubble_outline_rounded, size: 20.sp),
          tooltip: context.l10n.aiSwitchSession,
          offset: const Offset(0, 40),
          onSelected: (session) {
            ref.read(providerKey.notifier).switchSession(session.id);
          },
          itemBuilder: (_) => chatState.sessions
              .map((s) => PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16.sp,
                          color: s.id == chatState.currentSessionId
                              ? context.colorScheme.primary
                              : null,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
        _AppBarAction(
          icon: Icons.add_comment_rounded,
          tooltip: context.l10n.aiNewSession,
          onTap: () => _createSession(context, ref, systemPrompt, packageName),
        ),
        _AppBarAction(
          icon: Icons.delete_forever_rounded,
          tooltip: context.l10n.aiDeleteHistory,
          color: Colors.redAccent,
          onTap: () => _deleteHistory(context, ref, systemPrompt, packageName),
        ),
        SizedBox(width: 8.w),
      ],
    );
  }

  Future<void> _createSession(
    BuildContext context,
    WidgetRef ref,
    String systemPrompt,
    String packageName,
  ) async {
    final nameController = TextEditingController(
      text:
          "${context.l10n.aiNewSession} ${DateFormat('MM-dd HH:mm').format(DateTime.now())}",
    );
    final name = await CustomDialog.show<String>(
      title: Text(context.l10n.aiNewSession),
      child: Container(
        decoration: BoxDecoration(
          color: context.isDark
              ? context.colorScheme.surfaceContainerLow
              : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.aiSessionName,
            hintText: context.l10n.aiSessionNameHint,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: context.theme.dividerColor),
            ),
          ),
        ),
      ),
      actionButtons: [
        TextButton(
          onPressed: () => SmartDialog.dismiss(),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () =>
              SmartDialog.dismiss(result: nameController.text.trim()),
          child: Text(context.l10n.confirm),
        ),
      ],
    );
    if (name != null && name.isNotEmpty) {
      ref
          .read(aiChatActionProvider(packageName: packageName).notifier)
          .createSession(name);
    }
  }

  Future<void> _deleteHistory(
    BuildContext context,
    WidgetRef ref,
    String systemPrompt,
    String packageName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.aiDeleteConfirmTitle),
        content: Text(context.l10n.aiDeleteConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref
          .read(aiChatActionProvider(packageName: packageName).notifier)
          .deleteHistory();
    }
  }

  String _buildSystemPrompt(String mdContent, bool isZh, String apiType) {
    final apiName = apiType == 'frida' ? 'Frida' : 'JsxposedX';
    if (isZh) {
      return '你是 $apiName API 助手。请根据以下 API 文档回答用户的问题，'
          '尽量给出具体的代码示例。始终使用中文回复。\n\n$mdContent';
    }
    return 'You are a $apiName API assistant. '
        'Answer questions based on the following API documentation. '
        'Provide concrete code examples when possible. '
        'Always respond in English.\n\n$mdContent';
  }
}

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20.sp, color: color),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}
