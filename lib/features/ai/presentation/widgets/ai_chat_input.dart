import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/common/widgets/app_bottom_sheet.dart';
import 'dart:developer' as developer;
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/core/utils/file_picker_util.dart';
import 'package:JsxposedX/features/ai/domain/constants/builtin_ai_config.dart';
import 'package:JsxposedX/features/ai/domain/models/ai_chat_session_context.dart';
import 'package:JsxposedX/features/ai/domain/models/ai_session_init_state.dart';
import 'package:JsxposedX/features/ai/domain/services/ai_multimodal_message_codec.dart';
import 'package:JsxposedX/features/ai/presentation/providers/config/ai_config_query_provider.dart';
import 'package:JsxposedX/features/ai/presentation/providers/runtime/ai_chat_runtime_provider.dart';
import 'package:JsxposedX/features/ai/presentation/states/ai_chat_runtime_state.dart';
import 'package:JsxposedX/features/ai/presentation/widgets/ai_chat_compact_scope.dart';
import 'package:JsxposedX/features/ai/presentation/widgets/ai_quick_actions.dart';
import 'package:JsxposedX/features/ai/presentation/widgets/padi_chat_options_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

final aiChatPendingAttachmentsProvider =
    StateProvider.family<List<PickedFileData>, String>(
      (ref, packageName) => const [],
    );

class AiChatInput extends HookConsumerWidget {
  final String packageName;
  final String? systemPrompt;
  final bool useOverlayFilePicker;
  final bool showQuickActions;
  final bool isEmbedded;
  final bool isCompact;
  final bool showBuiltinOptions;
  final bool builtinOptionsCompact;
  final Future<void> Function()? onRetryInitialization;
  final VoidCallback? onOpenAnalysis;
  final String Function(String rawText)? composeOutgoingText;
  final bool hasComposedContent;
  final VoidCallback? onSendCommitted;

  const AiChatInput({
    super.key,
    required this.packageName,
    this.systemPrompt,
    this.useOverlayFilePicker = false,
    this.showQuickActions = true,
    this.isEmbedded = false,
    this.isCompact = false,
    this.showBuiltinOptions = true,
    this.builtinOptionsCompact = false,
    this.onRetryInitialization,
    this.onOpenAnalysis,
    this.composeOutgoingText,
    this.hasComposedContent = false,
    this.onSendCommitted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopeCompact = AiChatCompactScope.of(context);
    final scopeScale = AiChatCompactScope.scaleOf(context);
    final effectiveCompact = isCompact || scopeCompact;
    final textController = useTextEditingController();
    final pendingAttachments = ref.watch(
      aiChatPendingAttachmentsProvider(packageName),
    );
    final pendingAttachmentsNotifier = ref.read(
      aiChatPendingAttachmentsProvider(packageName).notifier,
    );
    final chatState = ref.watch(
      aiChatRuntimeProvider(packageName: packageName),
    );
    final aiConfigAsync = ref.watch(aiConfigProvider);

    final textValue = useValueListenable(textController);
    final hasContent = textValue.text.trim().isNotEmpty;
    final hasAttachments = pendingAttachments.isNotEmpty;
    final isStreaming = chatState.isStreaming;
    final canSend =
        (hasContent || hasAttachments || hasComposedContent) &&
        chatState.canSend;
    final hasContextDetails =
        chatState.hasUserMessages ||
        chatState.sessionContext.hasStructuredMemory;
    final canRetryLastTurn =
        !hasContent && !hasAttachments && chatState.canRetryLastTurn;
    final canRetryInitialization =
        !hasContent &&
        !hasAttachments &&
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
    final actionColor =
        isStreaming || canSend || canRetryLastTurn || canRetryInitialization
        ? context.colorScheme.primary
        : context.theme.disabledColor;
    final hintText = switch (chatState.sessionInitState) {
      AiSessionInitState.initializing =>
        context.l10n.aiReverseSessionInitializingHint,
      AiSessionInitState.failed => context.l10n.aiReverseSessionInitFailedHint,
      AiSessionInitState.ready => context.l10n.aiChatInputHint,
    };
    final actionLabel = isStreaming
        ? context.l10n.aiStopGeneration
        : canSend
        ? context.l10n.sendToAi
        : canRetryLastTurn
        ? (chatState.canResumeToolPhase
              ? context.l10n.aiResumeToolPhase
              : chatState.canContinueGeneration
              ? context.l10n.aiContinue
              : context.l10n.aiRetryLastTurn)
        : canRetryInitialization
        ? context.l10n.aiRetryInitialization
        : context.l10n.aiUnavailableToSend;
    final menuButtonSize = (effectiveCompact ? 30 : 36) * scopeScale;
    final menuIconSize = (effectiveCompact ? 17 : 20) * scopeScale;
    final horizontalGap = isEmbedded
        ? ((effectiveCompact ? 6 : 10) * scopeScale)
        : ((effectiveCompact ? 10 : 14) * scopeScale);
    final inputVerticalPadding = (effectiveCompact ? 6 : 10) * scopeScale;
    final inputFontSize = (effectiveCompact ? 13 : 15) * scopeScale;
    final actionButtonSize = (effectiveCompact ? 36 : 44) * scopeScale;
    final actionIconSize = (effectiveCompact ? 18 : 22) * scopeScale;
    final sendButtonMargin = (effectiveCompact ? 6 : 8) * scopeScale;
    final maxInputLines = effectiveCompact ? 3 : 5;
    final popupMenuColor = (useOverlayFilePicker || isEmbedded)
        ? context.colorScheme.surface
        : context.theme.cardColor;

    Future<void> handleSend() async {
      final notifier = ref.read(
        aiChatRuntimeProvider(packageName: packageName).notifier,
      );
      if (isStreaming) {
        await notifier.stopStreaming();
        return;
      }
      if (canSend) {
        try {
          final outgoingText =
              composeOutgoingText?.call(textController.text.trim()) ??
              textController.text.trim();
          final message = AiMultimodalMessageCodec.encodeFromPickedFiles(
            text: outgoingText,
            attachments: pendingAttachments,
          );

          textController.clear();
          pendingAttachmentsNotifier.state = const [];
          onSendCommitted?.call();

          notifier.send(message); // Fire and forget
        } catch (error, stackTrace) {
          developer.log(
            'Failed to encode pending attachments before send.',
            name: 'AiChatInput',
            error: error,
            stackTrace: stackTrace,
          );
          if (!context.mounted) {
            return;
          }
          ToastMessage.show(_formatAttachmentError(error));
        }
        return;
      }
      if (canRetryLastTurn) {
        await notifier.retryLastTurn();
        return;
      }
      if (canRetryInitialization) {
        await onRetryInitialization?.call();
      }
    }

    Future<void> handleMenuAction(_AiInputMenuAction action) async {
      switch (action) {
        case _AiInputMenuAction.previewContext:
          if (!hasContextDetails) {
            return;
          }
          AppBottomSheet.show<void>(
            context: context,
            title: context.l10n.aiContextTitle,
            child: _ContextSheet(chatState: chatState),
          );
          break;
        case _AiInputMenuAction.uploadImage:
          try {
            final picked = await FilePickerUtil.pickImage(
              useOverlayProxy: useOverlayFilePicker,
            );
            if (picked == null) {
              developer.log('Image picker returned null.', name: 'AiChatInput');
              return;
            }
            AiMultimodalMessageCodec.encodeFromPickedFiles(
              text: '',
              attachments: [picked],
            );
            pendingAttachmentsNotifier.state = [...pendingAttachments, picked];
            developer.log(
              'Image attachment queued: ${picked.fileName}',
              name: 'AiChatInput',
            );
          } catch (error, stackTrace) {
            developer.log(
              'Failed to pick image attachment.',
              name: 'AiChatInput',
              error: error,
              stackTrace: stackTrace,
            );
            if (!context.mounted) {
              return;
            }
            ToastMessage.show(_formatAttachmentError(error));
          }
          break;
        case _AiInputMenuAction.uploadFile:
          try {
            final picked = await FilePickerUtil.pickFile(
              useOverlayProxy: useOverlayFilePicker,
            );
            if (picked == null) {
              developer.log('File picker returned null.', name: 'AiChatInput');
              return;
            }
            AiMultimodalMessageCodec.encodeFromPickedFiles(
              text: '',
              attachments: [picked],
            );
            pendingAttachmentsNotifier.state = [...pendingAttachments, picked];
            developer.log(
              'File attachment queued: ${picked.fileName}',
              name: 'AiChatInput',
            );
          } catch (error, stackTrace) {
            developer.log(
              'Failed to pick file attachment.',
              name: 'AiChatInput',
              error: error,
              stackTrace: stackTrace,
            );
            if (!context.mounted) {
              return;
            }
            ToastMessage.show(_formatAttachmentError(error));
          }
          break;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showQuickActions)
          AiQuickActions(
            packageName: packageName,
            systemPrompt: systemPrompt,
            onOpenAnalysis: onOpenAnalysis,
          ),
        if (showBuiltinOptions &&
            aiConfigAsync.value != null &&
            shouldUseBuiltinPadiOptions(aiConfigAsync.value!))
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * scopeScale),
            child: PadiChatOptionsBar(
              packageName: packageName,
              isCompact: builtinOptionsCompact,
            ),
          ),
        Container(
          padding: isEmbedded
              ? EdgeInsets.zero
              : EdgeInsets.fromLTRB(
                  16 * scopeScale,
                  4 * scopeScale,
                  16 * scopeScale,
                  20 * scopeScale,
                ),
          decoration: BoxDecoration(
            color: isEmbedded
                ? Colors.transparent
                : (context.isDark
                      ? context.theme.scaffoldBackgroundColor
                      : Colors.transparent),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isEmbedded
                  ? Colors.transparent
                  : (context.isDark
                        ? context.colorScheme.surfaceContainerLow
                        : Colors.white),
              borderRadius: BorderRadius.circular(
                isEmbedded ? 0 : 12 * scopeScale,
              ),
              boxShadow: isEmbedded
                  ? const []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isEmbedded ? 0 : 4 * scopeScale),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pendingAttachments.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isEmbedded ? 0 : 8 * scopeScale,
                        isEmbedded ? 0 : 8 * scopeScale,
                        isEmbedded ? 0 : 8 * scopeScale,
                        isEmbedded ? 8 * scopeScale : 2 * scopeScale,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6 * scopeScale,
                          runSpacing: 6 * scopeScale,
                          children: [
                            for (
                              var index = 0;
                              index < pendingAttachments.length;
                              index++
                            )
                              _PendingAttachmentChip(
                                file: pendingAttachments[index],
                                onRemove: () {
                                  final updated = List<PickedFileData>.from(
                                    pendingAttachments,
                                  )..removeAt(index);
                                  pendingAttachmentsNotifier.state =
                                      List<PickedFileData>.unmodifiable(
                                        updated,
                                      );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  Container(
                    padding: isEmbedded
                        ? EdgeInsets.fromLTRB(0, 0, 0, 2 * scopeScale)
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: isEmbedded ? Colors.transparent : null,
                      borderRadius: BorderRadius.circular(12 * scopeScale),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        PopupMenuButton<_AiInputMenuAction>(
                          tooltip: context.isZh ? '更多操作' : 'More actions',
                          offset: const Offset(0, -180),
                          color: popupMenuColor,
                          surfaceTintColor: Colors.transparent,
                          shadowColor: Colors.black.withValues(alpha: 0.18),
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              14 * scopeScale,
                            ),
                          ),
                          onSelected: handleMenuAction,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _AiInputMenuAction.previewContext,
                              enabled: hasContextDetails,
                              child: _AiInputMenuItem(
                                icon: Icons.data_object_rounded,
                                title: context.isZh
                                    ? '查看上下文'
                                    : 'Preview context',
                                subtitle: context.isZh
                                    ? '预览自动压缩后的对话上下文'
                                    : 'Preview the current compressed context',
                              ),
                            ),
                            PopupMenuItem(
                              value: _AiInputMenuAction.uploadImage,
                              child: _AiInputMenuItem(
                                icon: Icons.image_outlined,
                                title: context.isZh ? '上传图片' : 'Upload image',
                                subtitle: context.isZh
                                    ? '添加图片到待发送附件'
                                    : 'Add an image as a pending attachment',
                              ),
                            ),
                            PopupMenuItem(
                              value: _AiInputMenuAction.uploadFile,
                              child: _AiInputMenuItem(
                                icon: Icons.attach_file_rounded,
                                title: context.isZh ? '上传文件' : 'Upload file',
                                subtitle: context.isZh
                                    ? '添加文件到待发送附件'
                                    : 'Add a file as a pending attachment',
                              ),
                            ),
                          ],
                          child: Container(
                            width: menuButtonSize,
                            height: menuButtonSize,
                            margin: EdgeInsets.only(
                              left: isEmbedded ? 0 : 6 * scopeScale,
                            ),
                            decoration: BoxDecoration(
                              color: context.isDark
                                  ? context.colorScheme.surfaceContainerLow
                                  : context.colorScheme.surface,
                              borderRadius: BorderRadius.circular(
                                10 * scopeScale,
                              ),
                              border: Border.all(
                                color: context.colorScheme.outlineVariant
                                    .withValues(
                                      alpha: context.isDark ? 0.55 : 0.8,
                                    ),
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: menuIconSize,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(width: horizontalGap),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: inputVerticalPadding,
                            ),
                            child: TextField(
                              controller: textController,
                              enabled:
                                  chatState.sessionInitState ==
                                  AiSessionInitState.ready,
                              onSubmitted: (_) async {
                                if (!canSend) {
                                  return;
                                }
                                await handleSend();
                              },
                              style: TextStyle(
                                fontSize: inputFontSize,
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
                                  fontSize: inputFontSize,
                                ),
                              ),
                              maxLines: maxInputLines,
                              minLines: 1,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: handleSend,
                          child: Container(
                            width: actionButtonSize,
                            height: actionButtonSize,
                            margin: EdgeInsets.only(left: sendButtonMargin),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: actionColor,
                            ),
                            child: Tooltip(
                              message: actionLabel,
                              child: Icon(
                                actionIcon,
                                color: Colors.white,
                                size: actionIconSize,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  String _formatAttachmentError(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    return raw;
  }
}

enum _AiInputMenuAction { previewContext, uploadImage, uploadFile }

class _AiInputMenuItem extends StatelessWidget {
  const _AiInputMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scopeScale = AiChatCompactScope.scaleOf(context);
    return SizedBox(
      width: 210 * scopeScale,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30 * scopeScale,
            height: 30 * scopeScale,
            decoration: BoxDecoration(
              color: context.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9 * scopeScale),
            ),
            child: Icon(
              icon,
              size: 16 * scopeScale,
              color: context.colorScheme.primary,
            ),
          ),
          SizedBox(width: 10 * scopeScale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13 * scopeScale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2 * scopeScale),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5 * scopeScale,
                    height: 1.35,
                    color: context.colorScheme.onSurfaceVariant,
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

class _PendingAttachmentChip extends StatelessWidget {
  const _PendingAttachmentChip({required this.file, required this.onRemove});

  final PickedFileData file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scopeScale = AiChatCompactScope.scaleOf(context);
    final extension = (file.extension ?? '').toLowerCase();
    final isImage = const {
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'bmp',
      'heic',
    }.contains(extension);

    return Container(
      constraints: BoxConstraints(maxWidth: 220 * scopeScale),
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scopeScale,
        vertical: 7 * scopeScale,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: context.isDark ? 0.55 : 0.75,
        ),
        borderRadius: BorderRadius.circular(999 * scopeScale),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isImage ? Icons.image_outlined : Icons.attach_file_rounded,
            size: 14 * scopeScale,
            color: context.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: 6 * scopeScale),
          Flexible(
            child: Text(
              '${file.fileName} · ${file.formattedSize}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5 * scopeScale,
                color: context.colorScheme.onSurface,
              ),
            ),
          ),
          SizedBox(width: 6 * scopeScale),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 14 * scopeScale,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextSheet extends StatelessWidget {
  const _ContextSheet({required this.chatState});

  final AiChatRuntimeState chatState;

  @override
  Widget build(BuildContext context) {
    final scopeScale = AiChatCompactScope.scaleOf(context);
    final sessionContext = chatState.sessionContext;
    final stats = chatState.contextStats;
    final checkpoint = sessionContext.checkpoint;
    final layers = stats.includedLayers.join(' / ');
    final lastRecoveryMode = sessionContext.taskState.lastRecoveryMode;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16 * scopeScale,
          0,
          16 * scopeScale,
          16 * scopeScale,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ContextInfoCard(
                title: context.l10n.aiContextBudget,
                rows: [
                  '${context.l10n.aiContextBudget}: ${stats.estimatedTokens}/${stats.tokenBudget}',
                  '${context.l10n.aiContextRemaining}: ${stats.remainingTokens}',
                  '${context.l10n.aiContextLayers}: ${layers.isEmpty ? '-' : layers}',
                  '${context.l10n.aiContextRecentRounds}: ${stats.recentRoundsKept}',
                  '${context.l10n.aiContextCompression}: '
                      '${_localizedCompactReason(context, stats.compactReason)}',
                  '${context.l10n.aiContextMigration}: '
                      '${stats.migratedLegacySummary ? context.l10n.aiContextMigrationDone : context.l10n.aiContextMigrationNone}',
                  '${context.l10n.aiContextToolTrace}: '
                      '${sessionContext.hasPendingToolPhase ? context.l10n.aiContextToolTracePending : context.l10n.aiContextToolTraceClear}',
                ],
              ),
              SizedBox(height: 10 * scopeScale),
              _ContextInfoCard(
                title: context.l10n.aiContextMemory,
                rows: [
                  '${context.l10n.aiContextGoals}: ${_joinList(sessionContext.sessionMemory.userGoals)}',
                  '${context.l10n.aiContextFacts}: ${_joinList(sessionContext.sessionMemory.confirmedFacts)}',
                  '${context.l10n.aiContextHypotheses}: ${_joinList(sessionContext.sessionMemory.openHypotheses)}',
                  '${context.l10n.aiContextFindings}: ${_joinList(sessionContext.sessionMemory.toolFindings)}',
                  '${context.l10n.aiContextTaskBlockers}: ${_joinList(sessionContext.sessionMemory.blockers)}',
                  '${context.l10n.aiContextTaskCurrent}: ${sessionContext.taskState.currentStep ?? context.l10n.aiSummaryEmpty}',
                  '${context.l10n.aiContextTaskNext}: ${sessionContext.taskState.nextStep ?? context.l10n.aiSummaryEmpty}',
                ],
              ),
              SizedBox(height: 10 * scopeScale),
              _ContextInfoCard(
                title: context.l10n.aiContextCheckpoint,
                rows: checkpoint == null
                    ? [context.l10n.aiContextNoCheckpoint]
                    : [
                        '${context.l10n.aiContextCheckpointTime}: ${checkpoint.createdAtIso}',
                        '${context.l10n.aiContextCheckpointPrompt}: ${checkpoint.lastUserMessage == null ? context.l10n.aiSummaryEmpty : AiMultimodalMessageCodec.toDisplayText(checkpoint.lastUserMessage!.content, isZh: context.isZh)}',
                        '${context.l10n.aiContextCheckpointMode}: ${_localizedRecoveryMode(context, lastRecoveryMode)}',
                      ],
              ),
              SizedBox(height: 10 * scopeScale),
              _ContextInfoCard(
                title: context.l10n.aiContextLastError,
                rows: [
                  sessionContext.taskState.lastError ??
                      context.l10n.aiContextNoError,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _joinList(List<String> items) {
    if (items.isEmpty) {
      return '';
    }
    return items.join(' | ');
  }

  String _localizedCompactReason(BuildContext context, String? reason) {
    return switch (reason) {
      'budget' => context.l10n.aiContextCompactReasonBudget,
      'manual' => context.l10n.aiContextCompactReasonManual,
      _ => context.l10n.aiContextCompactReasonNone,
    };
  }

  String _localizedRecoveryMode(
    BuildContext context,
    AiChatRecoveryMode recoveryMode,
  ) {
    return switch (recoveryMode) {
      AiChatRecoveryMode.retryLastTurn => context.l10n.aiRecoveryModeRetry,
      AiChatRecoveryMode.continueGeneration =>
        context.l10n.aiRecoveryModeContinue,
      AiChatRecoveryMode.resumeToolPhase => context.l10n.aiRecoveryModeTool,
      AiChatRecoveryMode.retryInitialization =>
        context.l10n.aiRetryInitialization,
      AiChatRecoveryMode.none => '-',
    };
  }
}

class _ContextInfoCard extends StatelessWidget {
  const _ContextInfoCard({required this.title, required this.rows});

  final String title;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    final scopeScale = AiChatCompactScope.scaleOf(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12 * scopeScale),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14 * scopeScale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13 * scopeScale,
              fontWeight: FontWeight.w700,
              color: context.colorScheme.primary,
            ),
          ),
          SizedBox(height: 8 * scopeScale),
          for (final item in rows)
            Padding(
              padding: EdgeInsets.only(bottom: 6 * scopeScale),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 6 * scopeScale),
                    child: Container(
                      width: 4 * scopeScale,
                      height: 4 * scopeScale,
                      decoration: BoxDecoration(
                        color: context.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 8 * scopeScale),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(fontSize: 13 * scopeScale, height: 1.45),
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
