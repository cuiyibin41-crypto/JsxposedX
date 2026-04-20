import 'dart:math' as math;
import 'dart:ui';

import 'package:JsxposedX/common/widgets/custom_text_field.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_panel_dialog.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_text_input_context_menu.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/core/models/ai_session.dart';
import 'package:JsxposedX/core/themes/ai_activation_theme.dart';
import 'package:JsxposedX/features/ai/domain/models/ai_session_init_state.dart';
import 'package:JsxposedX/features/ai/presentation/providers/runtime/ai_chat_runtime_provider.dart';
import 'package:JsxposedX/features/ai/presentation/runtime/ai_chat_environment_initializer.dart';
import 'package:JsxposedX/features/ai/presentation/states/ai_chat_runtime_state.dart';
import 'package:JsxposedX/features/ai/presentation/widgets/ai_chat_compact_scope.dart';
import 'package:JsxposedX/features/ai/presentation/widgets/ai_chat_input.dart';
import 'package:JsxposedX/features/ai/presentation/widgets/ai_chat_list.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/ai_overlay_ui_state_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_ai_overlay_environment_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_ai_overlay_selection_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_saved_items_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_search_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/ai_overlay_assistant_glyph.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/ai_overlay_collapsed_ball.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_ai_message_bubble.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_ai_selection_tag_bar.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

class AiOverlay extends HookConsumerWidget {
  const AiOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final isPanelVisible = ref.watch(
      overlayWindowHostRuntimeProvider.select(
        (state) => state.payload.isPanel && !state.isTransitioningToPanel,
      ),
    );

    if (selectedProcess == null) {
      return const SizedBox.shrink();
    }

    final mediaQuery = MediaQuery.of(context);
    final portraitTopInset = mediaQuery.orientation == Orientation.portrait
        ? mediaQuery.padding.top
        : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(
          constraints.hasBoundedWidth
              ? constraints.maxWidth
              : mediaQuery.size.width,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : mediaQuery.size.height,
        );
        return _AiOverlayViewport(
          selectedProcess: selectedProcess,
          viewportSize: viewportSize,
          portraitTopInset: portraitTopInset,
          isPanelVisible: isPanelVisible,
        );
      },
    );
  }
}

class _AiOverlayViewport extends HookConsumerWidget {
  const _AiOverlayViewport({
    required this.selectedProcess,
    required this.viewportSize,
    required this.portraitTopInset,
    required this.isPanelVisible,
  });

  final ProcessInfo selectedProcess;
  final Size viewportSize;
  final double portraitTopInset;
  final bool isPanelVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlayState = ref.watch(aiOverlayUiStateControllerProvider);
    final overlayStateNotifier = ref.read(
      aiOverlayUiStateControllerProvider.notifier,
    );
    final isExpanded = overlayState.isExpanded;
    final hasSelectedValue = ref.watch(memoryAiOverlayHasSelectedValueProvider);
    final selectionTags = ref.watch(memoryAiOverlaySelectionTagsProvider);
    final offset = overlayState.offset;
    final persistedPanelSize = overlayState.panelSize;
    final dragStartGlobal = useRef<Offset?>(null);
    final dragStartOffset = useRef<Offset?>(null);
    final resizeStartGlobal = useRef<Offset?>(null);
    final resizeStartSize = useRef<Size?>(null);
    final isResizing = useRef(false);
    final isCreateSessionDialogOpen = useState(false);
    final pendingBoundPid = useRef<int?>(null);
    final pendingLayoutKey = useRef<String?>(null);
    final environment = ref.watch(
      memoryAiOverlayEnvironmentProvider(
        MemoryAiOverlayEnvironmentArgs(
          processInfo: selectedProcess,
          isZh: context.isZh,
        ),
      ),
    );
    final chatScopeId = environment.scopeId;
    final chatNotifier = ref.read(
      aiChatRuntimeProvider(packageName: chatScopeId).notifier,
    );
    final chatState = ref.watch(
      aiChatRuntimeProvider(packageName: chatScopeId),
    );
    final sessions = chatState.sessions;
    final AiSession? currentSession = () {
      for (final session in sessions) {
        if (session.id == chatState.currentSessionId) {
          return session;
        }
      }
      return sessions.isNotEmpty ? sessions.first : null;
    }();
    final scrollController = useScrollController();
    final collapsedDiameter = 44.0;
    final defaultExpandedSize = const Size(320.0, 420.0);
    final minExpandedSize = const Size(260.0, 280.0);
    final safePadding = 12.0;
    final expandedBorderRadius = 20.0;
    final collapsedBorderRadius = 14.0;
    final resizeHandleHighlightExtent = 40.0;
    final resizeHandleHitExtent = 52.0;
    final displayTitle = selectedProcess.name.trim().isEmpty
        ? selectedProcess.packageName
        : selectedProcess.name;
    final displaySubtitle =
        '${selectedProcess.packageName} · PID ${selectedProcess.pid}';

    Future<void> initializeOverlayChat() async {
      await initializeAiChatEnvironment(
        notifier: chatNotifier,
        environment: environment,
        initErrorPrefix: context.isZh
            ? '内存会话初始化失败'
            : 'Memory session init failed',
      );
    }

    final hasEnvironmentSnapshot =
        (chatState.systemPrompt?.trim().isNotEmpty ?? false) &&
        chatState.toolsSpec != null &&
        chatState.toolExecutor != null;
    final hasMatchingEnvironmentSnapshot =
        hasEnvironmentSnapshot &&
        chatState.environmentVersion == environment.environmentVersion;
    final shouldAutoInitializeChat =
        !hasMatchingEnvironmentSnapshot &&
        chatState.sessionInitState == AiSessionInitState.ready;

    final availableExpandedWidth = math.max(
      viewportSize.width - (safePadding * 2),
      collapsedDiameter,
    );
    final availableExpandedHeight = math.max(
      viewportSize.height - portraitTopInset - (safePadding * 2),
      collapsedDiameter,
    );
    final effectiveMinExpandedWidth = math.min(
      minExpandedSize.width,
      availableExpandedWidth,
    );
    final effectiveMinExpandedHeight = math.min(
      minExpandedSize.height,
      availableExpandedHeight,
    );

    Size clampExpandedSize(Size size) {
      return Size(
        size.width
            .clamp(effectiveMinExpandedWidth, availableExpandedWidth)
            .toDouble(),
        size.height
            .clamp(effectiveMinExpandedHeight, availableExpandedHeight)
            .toDouble(),
      );
    }

    final expandedSize = clampExpandedSize(
      persistedPanelSize ?? defaultExpandedSize,
    );

    Size currentSize() =>
        isExpanded ? expandedSize : Size(collapsedDiameter, collapsedDiameter);

    Offset defaultOffset(Size size) =>
        Offset(viewportSize.width - size.width - 20.0, portraitTopInset + 88.0);

    Offset clampOffset(Offset value, Size size) {
      final minX = safePadding;
      final maxX = math.max(
        minX,
        viewportSize.width - size.width - safePadding,
      );
      final minY = portraitTopInset + safePadding;
      final maxY = math.max(
        minY,
        viewportSize.height - size.height - safePadding,
      );
      return Offset(
        value.dx.clamp(minX, maxX).toDouble(),
        value.dy.clamp(minY, maxY).toDouble(),
      );
    }

    useEffect(() {
      final size = Size(collapsedDiameter, collapsedDiameter);
      final nextOffset = clampOffset(defaultOffset(size), size);
      if (pendingBoundPid.value == selectedProcess.pid) {
        return null;
      }
      pendingBoundPid.value = selectedProcess.pid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        pendingBoundPid.value = null;
        if (!context.mounted) {
          return;
        }
        overlayStateNotifier.bindProcess(
          pid: selectedProcess.pid,
          initialOffset: nextOffset,
          initialPanelSize: clampExpandedSize(defaultExpandedSize),
        );
      });
      return null;
    }, [selectedProcess.pid]);

    useEffect(() {
      if (!shouldAutoInitializeChat) {
        return null;
      }
      Future.microtask(() async {
        await initializeOverlayChat();
      });
      return null;
    }, [chatScopeId, shouldAutoInitializeChat]);

    useEffect(
      () {
        final nextPanelSize = clampExpandedSize(
          persistedPanelSize ?? defaultExpandedSize,
        );
        final panelSizeChanged = persistedPanelSize != nextPanelSize;
        final size = isExpanded
            ? nextPanelSize
            : Size(collapsedDiameter, collapsedDiameter);
        final nextOffset = clampOffset(offset ?? defaultOffset(size), size);
        final layoutKey =
            '${viewportSize.width}:${viewportSize.height}:$portraitTopInset:$isExpanded:${nextPanelSize.width}:${nextPanelSize.height}:${nextOffset.dx}:${nextOffset.dy}:${panelSizeChanged ? 1 : 0}';
        if (pendingLayoutKey.value == layoutKey) {
          return null;
        }
        pendingLayoutKey.value = layoutKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          pendingLayoutKey.value = null;
          if (!context.mounted) {
            return;
          }
          if (panelSizeChanged) {
            overlayStateNotifier.setPanelSize(nextPanelSize);
          }
          overlayStateNotifier.setOffset(nextOffset);
        });
        return null;
      },
      [
        viewportSize.width,
        viewportSize.height,
        portraitTopInset,
        isExpanded,
        persistedPanelSize?.width,
        persistedPanelSize?.height,
      ],
    );

    final lastMessageId = useRef<String?>(null);
    useEffect(() {
      final visibleMessages = chatState.visibleMessages;
      if (visibleMessages.isEmpty) {
        return null;
      }

      final currentLastId = visibleMessages.last.id;
      final isNewMessage = lastMessageId.value != currentLastId;
      lastMessageId.value = currentLastId;
      if (!scrollController.hasClients || !isNewMessage) {
        return null;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!scrollController.hasClients) {
          return;
        }
        scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
      return null;
    }, [chatState.visibleMessages.length]);

    useEffect(() {
      const followThreshold = 80.0;
      final subscription = chatNotifier.streamingContentStream.listen((
        content,
      ) {
        if (content.isEmpty || !scrollController.hasClients) {
          return;
        }
        if (scrollController.offset > followThreshold) {
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!scrollController.hasClients) {
            return;
          }
          if (scrollController.offset > followThreshold) {
            return;
          }
          scrollController.jumpTo(0);
        });
      });
      return subscription.cancel;
    }, [chatNotifier, scrollController]);

    final resolvedSize = currentSize();
    final resolvedOffset = clampOffset(
      offset ?? defaultOffset(resolvedSize),
      resolvedSize,
    );
    final showExpandedPanel =
        isExpanded &&
        resolvedSize.width > (collapsedDiameter + 4) &&
        resolvedSize.height > (collapsedDiameter + 4);
    final isLandscapePanel = resolvedSize.width > resolvedSize.height * 1.08;
    final panelBaseSize = isLandscapePanel
        ? const Size(420.0, 300.0)
        : const Size(320.0, 420.0);
    final contentScale = math
        .min(
          resolvedSize.width / panelBaseSize.width,
          resolvedSize.height / panelBaseSize.height,
        )
        .clamp(isLandscapePanel ? 0.58 : 0.54, 1.0)
        .toDouble();
    final isCompactPanel =
        isLandscapePanel ||
        contentScale < 0.96 ||
        resolvedSize.width < 340.0 ||
        resolvedSize.height < 420.0;
    final headerLeftPadding = (isCompactPanel ? 10.0 : 14.0) * contentScale;
    final headerTopPadding = (isCompactPanel ? 8.0 : 12.0) * contentScale;
    final headerRightPadding = (isCompactPanel ? 8.0 : 12.0) * contentScale;
    final headerClosePadding = (isCompactPanel ? 3.0 : 4.0) * contentScale;
    final headerCloseIconSize = (isCompactPanel ? 14.0 : 16.0) * contentScale;
    final headerGap = (isCompactPanel ? 8.0 : 10.0) * contentScale;
    final headerTitleFontSize = (isCompactPanel ? 11.5 : 13.0) * contentScale;
    final headerSubtitleFontSize = (isCompactPanel ? 9.5 : 11.0) * contentScale;
    final headerSubtitleGap = (isCompactPanel ? 1.0 : 2.0) * contentScale;
    final contentLeftPadding = (isCompactPanel ? 8.0 : 10.0) * contentScale;
    final contentTopPadding = (isCompactPanel ? 42.0 : 56.0) * contentScale;
    final contentRightPadding = (isCompactPanel ? 8.0 : 12.0) * contentScale;
    final contentBottomPadding = (isCompactPanel ? 8.0 : 12.0) * contentScale;

    void clearSelectionTags() {
      ref.read(memoryToolResultSelectionProvider.notifier).clear();
      ref.read(memoryToolBrowseControllerProvider.notifier).clearSelection();
      ref.read(memoryToolSavedItemSelectionProvider.notifier).clearSelection();
    }

    void removeSelectionTag(MemoryAiOverlaySelectionTag tag) {
      switch (tag.source) {
        case MemoryAiOverlaySelectionSource.search:
          ref
              .read(memoryToolResultSelectionProvider.notifier)
              .removeAddress(tag.address);
          break;
        case MemoryAiOverlaySelectionSource.browse:
          ref
              .read(memoryToolBrowseControllerProvider.notifier)
              .hideAddress(tag.address);
          break;
        case MemoryAiOverlaySelectionSource.saved:
          ref
              .read(memoryToolSavedItemSelectionProvider.notifier)
              .removeAddress(tag.address);
          break;
      }
    }

    String composeSelectionTagMessage(String rawText) {
      if (selectionTags.isEmpty) {
        return rawText.trim();
      }

      final lines = <String>[
        context.isZh
            ? '以下是当前内存工具里我选中的值，请结合它们理解本次提问：'
            : 'These are the values currently selected in the memory tool. Use them as context for this request:',
        for (final tag in selectionTags)
          '- ${switch (tag.source) {
            MemoryAiOverlaySelectionSource.search => context.isZh ? '搜索' : 'Search',
            MemoryAiOverlaySelectionSource.browse => context.isZh ? '浏览' : 'Browse',
            MemoryAiOverlaySelectionSource.saved => context.isZh ? '暂存' : 'Saved',
          }} | ${tag.addressLabel} | ${tag.typeLabel} | ${tag.valueLabel}',
      ];

      final trimmed = rawText.trim();
      if (trimmed.isNotEmpty) {
        lines
          ..add('')
          ..add(trimmed);
      }

      return lines.join('\n').trim();
    }

    void startDragging(Offset globalPosition) {
      if (isResizing.value) {
        return;
      }
      dragStartGlobal.value = globalPosition;
      dragStartOffset.value = resolvedOffset;
    }

    void updateDragging(Offset globalPosition, Size size) {
      if (isResizing.value) {
        return;
      }
      final startGlobal = dragStartGlobal.value;
      final startOffset = dragStartOffset.value;
      if (startGlobal == null || startOffset == null) {
        return;
      }
      final delta = globalPosition - startGlobal;
      overlayStateNotifier.setOffset(clampOffset(startOffset + delta, size));
    }

    void stopDragging() {
      dragStartGlobal.value = null;
      dragStartOffset.value = null;
    }

    return Offstage(
      offstage: !isPanelVisible,
      child: TickerMode(
        enabled: isPanelVisible,
        child: IgnorePointer(
          ignoring: !isPanelVisible,
          child: Stack(
            children: [
              Positioned(
                left: resolvedOffset.dx,
                top: resolvedOffset.dy,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: showExpandedPanel
                      ? null
                      : (details) => startDragging(details.globalPosition),
                  onPanUpdate: showExpandedPanel
                      ? null
                      : (details) => updateDragging(
                          details.globalPosition,
                          resolvedSize,
                        ),
                  onPanEnd: showExpandedPanel ? null : (_) => stopDragging(),
                  onPanCancel: showExpandedPanel ? null : stopDragging,
                  child: CustomPaint(
                    foregroundPainter: showExpandedPanel
                        ? _AiOverlayResizeBorderHighlightPainter(
                            color: context.colorScheme.primary.withValues(
                              alpha: 0.94,
                            ),
                            borderRadius: expandedBorderRadius,
                            clipExtent: resizeHandleHighlightExtent,
                          )
                        : null,
                    child: Container(
                      width: resolvedSize.width,
                      height: resolvedSize.height,
                      decoration: BoxDecoration(
                        color: showExpandedPanel
                            ? context.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.76)
                            : null,
                        gradient: null,
                        borderRadius: BorderRadius.circular(
                          showExpandedPanel
                              ? expandedBorderRadius
                              : collapsedBorderRadius,
                        ),
                        boxShadow: showExpandedPanel
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                        border: showExpandedPanel
                            ? Border.all(
                                color: context.colorScheme.outlineVariant
                                    .withValues(alpha: 0.34),
                                width: 1,
                              )
                            : null,
                      ),
                      clipBehavior: showExpandedPanel
                          ? Clip.antiAlias
                          : Clip.none,
                      child: showExpandedPanel
                          ? Stack(
                              children: <Widget>[
                                Positioned.fill(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 8,
                                      sigmaY: 8,
                                    ),
                                    child: ColoredBox(
                                      color: context.colorScheme.surface
                                          .withValues(alpha: 0.08),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onPanStart: (details) {
                                      startDragging(details.globalPosition);
                                    },
                                    onPanUpdate: (details) {
                                      updateDragging(
                                        details.globalPosition,
                                        resolvedSize,
                                      );
                                    },
                                    onPanEnd: (_) {
                                      stopDragging();
                                    },
                                    onPanCancel: stopDragging,
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        headerLeftPadding,
                                        headerTopPadding,
                                        headerRightPadding,
                                        0,
                                      ),
                                      child: Row(
                                        children: [
                                          Material(
                                            color: context.colorScheme.surface
                                                .withValues(alpha: 0.28),
                                            borderRadius: BorderRadius.circular(
                                              12.0 * contentScale,
                                            ),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    12.0 * contentScale,
                                                  ),
                                              onTap: () {
                                                overlayStateNotifier
                                                    .setExpanded(false);
                                              },
                                              child: Padding(
                                                padding: EdgeInsets.all(
                                                  headerClosePadding,
                                                ),
                                                child: Icon(
                                                  Icons.remove_rounded,
                                                  size: headerCloseIconSize,
                                                  color: context
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.82),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: headerGap),
                                          Expanded(
                                            child: _AiOverlayHeaderIdentity(
                                              displayTitle: displayTitle,
                                              displaySubtitle: displaySubtitle,
                                              contentScale: contentScale,
                                              isCompact: isCompactPanel,
                                              titleFontSize:
                                                  headerTitleFontSize,
                                              subtitleFontSize:
                                                  headerSubtitleFontSize,
                                              subtitleGap: headerSubtitleGap,
                                            ),
                                          ),
                                          SizedBox(width: headerGap),
                                          _AiOverlaySessionActions(
                                            chatScopeId: chatScopeId,
                                            sessions: sessions,
                                            currentSession: currentSession,
                                            isCompact: isCompactPanel,
                                            contentScale: contentScale,
                                            onCreateSession: () {
                                              isCreateSessionDialogOpen.value =
                                                  true;
                                            },
                                            onDeleteCurrentSession:
                                                currentSession == null
                                                ? null
                                                : () async {
                                                    final shouldDelete =
                                                        await showDialog<bool>(
                                                          context: context,
                                                          builder: (dialogContext) => AlertDialog(
                                                            title: Text(
                                                              context
                                                                  .l10n
                                                                  .aiDeleteConfirmTitle,
                                                            ),
                                                            content: Text(
                                                              currentSession
                                                                  .name,
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      dialogContext,
                                                                      false,
                                                                    ),
                                                                child: Text(
                                                                  context
                                                                      .l10n
                                                                      .cancel,
                                                                ),
                                                              ),
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      dialogContext,
                                                                      true,
                                                                    ),
                                                                child: Text(
                                                                  context
                                                                      .l10n
                                                                      .delete,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ) ??
                                                        false;
                                                    if (!shouldDelete) {
                                                      return;
                                                    }
                                                    await ref
                                                        .read(
                                                          aiChatRuntimeProvider(
                                                            packageName:
                                                                chatScopeId,
                                                          ).notifier,
                                                        )
                                                        .deleteSession(
                                                          currentSession.id,
                                                        );
                                                  },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    contentLeftPadding,
                                    contentTopPadding,
                                    contentRightPadding,
                                    contentBottomPadding,
                                  ),
                                  child: AiChatCompactScope(
                                    enabled: isCompactPanel,
                                    scale: contentScale,
                                    child: Column(
                                      children: [
                                        _AiOverlayInitBanner(
                                          chatState: chatState,
                                          onRetry: initializeOverlayChat,
                                          isCompact: isCompactPanel,
                                        ),
                                        Expanded(
                                          child: AiChatList(
                                            messages: chatState.visibleMessages,
                                            scrollController: scrollController,
                                            packageName: chatScopeId,
                                            isCompact: isCompactPanel,
                                            customTitle: context.isZh
                                                ? '内存调试助手'
                                                : 'Memory Assistant',
                                            customSubtitle: displaySubtitle,
                                            bubbleBuilder:
                                                ({
                                                  required message,
                                                  required retryLabel,
                                                  required onRetry,
                                                  required packageName,
                                                }) => MemoryAiChatBubble(
                                                  key: ValueKey(message.id),
                                                  content: message.content,
                                                  role: message.role,
                                                  isError: message.isError,
                                                  isToolCalling:
                                                      message
                                                          .isToolResultBubble &&
                                                      !message.content
                                                          .startsWith('✅') &&
                                                      !message.content
                                                          .startsWith('❌'),
                                                  isToolResultBubble: message
                                                      .isToolResultBubble,
                                                  retryLabel: retryLabel,
                                                  onRetry: onRetry,
                                                  packageName: packageName,
                                                ),
                                            streamingBubbleBuilder:
                                                ({
                                                  required message,
                                                  required retryLabel,
                                                  required onRetry,
                                                  required packageName,
                                                  required streamingContentStream,
                                                  required streamingThinkingStream,
                                                }) => MemoryAiStreamingChatBubble(
                                                  key: ValueKey(message.id),
                                                  role: message.role,
                                                  isError: message.isError,
                                                  isToolCalling: message
                                                      .isToolResultBubble,
                                                  isToolResultBubble: message
                                                      .isToolResultBubble,
                                                  retryLabel: retryLabel,
                                                  onRetry: onRetry,
                                                  packageName: packageName,
                                                  streamingContentStream:
                                                      streamingContentStream,
                                                  streamingThinkingStream:
                                                      streamingThinkingStream,
                                                ),
                                          ),
                                        ),
                                        if (selectionTags.isNotEmpty) ...[
                                          SizedBox(
                                            height:
                                                (isCompactPanel ? 4.0 : 6.0) *
                                                contentScale,
                                          ),
                                          MemoryAiSelectionTagBar(
                                            tags: selectionTags,
                                            onRemoveTag: removeSelectionTag,
                                          ),
                                          SizedBox(
                                            height:
                                                (isCompactPanel ? 4.0 : 6.0) *
                                                contentScale,
                                          ),
                                        ],
                                        AiChatInput(
                                          packageName: chatScopeId,
                                          useOverlayFilePicker: true,
                                          showQuickActions: false,
                                          isEmbedded: true,
                                          isCompact: isCompactPanel,
                                          showBuiltinOptions: true,
                                          builtinOptionsCompact: true,
                                          onRetryInitialization:
                                              initializeOverlayChat,
                                          hasComposedContent:
                                              selectionTags.isNotEmpty,
                                          composeOutgoingText:
                                              composeSelectionTagMessage,
                                          onSendCommitted: clearSelectionTags,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onPanStart: (details) {
                                      isResizing.value = true;
                                      resizeStartGlobal.value =
                                          details.globalPosition;
                                      resizeStartSize.value = expandedSize;
                                    },
                                    onPanUpdate: (details) {
                                      final startGlobal =
                                          resizeStartGlobal.value;
                                      final startSize = resizeStartSize.value;
                                      if (startGlobal == null ||
                                          startSize == null) {
                                        return;
                                      }
                                      final delta =
                                          details.globalPosition - startGlobal;
                                      final nextSize = clampExpandedSize(
                                        Size(
                                          startSize.width + delta.dx,
                                          startSize.height + delta.dy,
                                        ),
                                      );
                                      overlayStateNotifier.setPanelSize(
                                        nextSize,
                                      );
                                      overlayStateNotifier.setOffset(
                                        clampOffset(resolvedOffset, nextSize),
                                      );
                                    },
                                    onPanEnd: (_) {
                                      resizeStartGlobal.value = null;
                                      resizeStartSize.value = null;
                                      isResizing.value = false;
                                    },
                                    onPanCancel: () {
                                      resizeStartGlobal.value = null;
                                      resizeStartSize.value = null;
                                      isResizing.value = false;
                                    },
                                    child: SizedBox(
                                      width: resizeHandleHitExtent,
                                      height: resizeHandleHitExtent,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : AiOverlayCollapsedBall(
                              isHighlighted: hasSelectedValue,
                              onTap: () {
                                overlayStateNotifier.setExpanded(true);
                              },
                            ),
                    ),
                  ),
                ),
              ),
              if (isCreateSessionDialogOpen.value)
                Positioned.fill(
                  child: _AiOverlayCreateSessionDialog(
                    chatScopeId: chatScopeId,
                    initialName:
                        '${context.l10n.aiNewSession} ${DateFormat('MM-dd HH:mm').format(DateTime.now())}',
                    onClose: () {
                      isCreateSessionDialogOpen.value = false;
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiOverlayHeaderIdentity extends StatelessWidget {
  const _AiOverlayHeaderIdentity({
    required this.displayTitle,
    required this.displaySubtitle,
    required this.contentScale,
    required this.isCompact,
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.subtitleGap,
  });

  final String displayTitle;
  final String displaySubtitle;
  final double contentScale;
  final bool isCompact;
  final double titleFontSize;
  final double subtitleFontSize;
  final double subtitleGap;

  @override
  Widget build(BuildContext context) {
    final iconExtent = (isCompact ? 28.0 : 32.0) * contentScale;

    return Row(
      children: [
        SizedBox(
          width: iconExtent,
          height: iconExtent,
          child: AiOverlayAssistantGlyph(size: iconExtent),
        ),
        SizedBox(width: (isCompact ? 8.0 : 10.0) * contentScale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurface,
                  height: 1.05,
                ),
              ),
              SizedBox(height: subtitleGap),
              Text(
                displaySubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: subtitleFontSize,
                  color: context.colorScheme.onSurfaceVariant,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _AiOverlayHeaderAction { createSession, deleteCurrentSession }

class _AiOverlaySessionActions extends HookConsumerWidget {
  const _AiOverlaySessionActions({
    required this.chatScopeId,
    required this.sessions,
    required this.currentSession,
    required this.isCompact,
    required this.contentScale,
    required this.onCreateSession,
    required this.onDeleteCurrentSession,
  });

  final String chatScopeId;
  final List<AiSession> sessions;
  final AiSession? currentSession;
  final bool isCompact;
  final double contentScale;
  final VoidCallback onCreateSession;
  final Future<void> Function()? onDeleteCurrentSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderRadius = BorderRadius.circular(12.0 * contentScale);
    final surfaceColor = context.colorScheme.surface.withValues(alpha: 0.3);
    final borderColor = context.colorScheme.outlineVariant.withValues(
      alpha: 0.34,
    );
    final foregroundColor = context.colorScheme.onSurface;
    final labelFontSize = (isCompact ? 10.0 : 11.5) * contentScale;
    final iconSize = (isCompact ? 14.0 : 16.0) * contentScale;
    final currentName = currentSession?.name ?? context.l10n.aiNewSession;
    final menuButtonExtent = (isCompact ? 30.0 : 34.0) * contentScale;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<AiSession>(
          enabled: sessions.isNotEmpty,
          tooltip: context.l10n.aiSwitchSession,
          onSelected: (session) async {
            await ref
                .read(aiChatRuntimeProvider(packageName: chatScopeId).notifier)
                .switchSession(session.id);
          },
          itemBuilder: (menuContext) => sessions
              .map(
                (session) => PopupMenuItem<AiSession>(
                  value: session,
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: iconSize,
                        color: session.id == currentSession?.id
                            ? context.colorScheme.primary
                            : menuContext.colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: (isCompact ? 6.0 : 8.0) * contentScale),
                      Expanded(
                        child: Text(
                          session.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          child: Container(
            constraints: BoxConstraints(
              minWidth: (isCompact ? 96.0 : 112.0) * contentScale,
              maxWidth: (isCompact ? 132.0 : 160.0) * contentScale,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: (isCompact ? 8.0 : 10.0) * contentScale,
              vertical: (isCompact ? 6.0 : 7.0) * contentScale,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: borderRadius,
              border: Border.all(
                color: sessions.isEmpty
                    ? borderColor
                    : aiActivationGradientColors[1].withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    currentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w600,
                      color: foregroundColor.withValues(
                        alpha: sessions.isEmpty ? 0.55 : 0.88,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: (isCompact ? 4.0 : 6.0) * contentScale),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: (isCompact ? 18.0 : 20.0) * contentScale,
                  color: foregroundColor.withValues(alpha: 0.72),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: (isCompact ? 6.0 : 8.0) * contentScale),
        PopupMenuButton<_AiOverlayHeaderAction>(
          tooltip: context.isZh ? '更多操作' : 'More actions',
          onSelected: (action) async {
            switch (action) {
              case _AiOverlayHeaderAction.createSession:
                onCreateSession();
                break;
              case _AiOverlayHeaderAction.deleteCurrentSession:
                await onDeleteCurrentSession?.call();
                break;
            }
          },
          itemBuilder: (menuContext) => [
            PopupMenuItem<_AiOverlayHeaderAction>(
              value: _AiOverlayHeaderAction.createSession,
              child: Row(
                children: [
                  Icon(
                    Icons.add_comment_rounded,
                    size: iconSize,
                    color: menuContext.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: (isCompact ? 6.0 : 8.0) * contentScale),
                  Text(context.l10n.aiNewSession),
                ],
              ),
            ),
            PopupMenuItem<_AiOverlayHeaderAction>(
              value: _AiOverlayHeaderAction.deleteCurrentSession,
              enabled: onDeleteCurrentSession != null,
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: iconSize,
                    color: onDeleteCurrentSession == null
                        ? menuContext.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          )
                        : menuContext.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: (isCompact ? 6.0 : 8.0) * contentScale),
                  Text(context.l10n.delete),
                ],
              ),
            ),
          ],
          child: Container(
            width: menuButtonExtent,
            height: menuButtonExtent,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: borderRadius,
              border: Border.all(color: borderColor),
            ),
            child: Icon(
              Icons.more_horiz_rounded,
              size: iconSize,
              color: foregroundColor.withValues(alpha: 0.82),
            ),
          ),
        ),
      ],
    );
  }
}

class _AiOverlayCreateSessionDialog extends HookConsumerWidget {
  const _AiOverlayCreateSessionDialog({
    required this.chatScopeId,
    required this.initialName,
    required this.onClose,
  });

  final String chatScopeId;
  final String initialName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController(text: initialName);
    final isSubmitting = useState(false);
    useListenable(controller);

    final canConfirm = !isSubmitting.value && controller.text.trim().isNotEmpty;

    return OverlayPanelDialog.card(
      onClose: isSubmitting.value ? null : onClose,
      maxWidthPortrait: 360.0,
      maxWidthLandscape: 400.0,
      maxHeightPortrait: 250.0,
      maxHeightLandscape: 250.0,
      cardBorderRadius: 18.0,
      childBuilder: (context, viewport, layout) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.aiNewSession,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12.0),
              CustomTextField(
                controller: controller,
                labelText: context.l10n.aiSessionName,
                hintText: context.l10n.aiSessionNameHint,
                contextMenuBuilder: buildOverlayTextInputContextMenu,
                fillColor: context.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.22),
                focusedBorderColor: context.colorScheme.primary,
                enabledBorderColor: context.colorScheme.outlineVariant
                    .withValues(alpha: 0.34),
              ),
              const SizedBox(height: 14.0),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting.value ? null : onClose,
                      child: Text(context.l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: FilledButton(
                      onPressed: canConfirm
                          ? () async {
                              isSubmitting.value = true;
                              try {
                                await ref
                                    .read(
                                      aiChatRuntimeProvider(
                                        packageName: chatScopeId,
                                      ).notifier,
                                    )
                                    .createSession(controller.text.trim());
                                if (context.mounted) {
                                  onClose();
                                }
                              } finally {
                                if (context.mounted) {
                                  isSubmitting.value = false;
                                }
                              }
                            }
                          : null,
                      child: Text(context.l10n.confirm),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AiOverlayInitBanner extends StatelessWidget {
  const _AiOverlayInitBanner({
    required this.chatState,
    required this.onRetry,
    this.isCompact = false,
  });

  final AiChatRuntimeState chatState;
  final Future<void> Function() onRetry;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (chatState.sessionInitState == AiSessionInitState.ready) {
      return const SizedBox.shrink();
    }

    final contentScale = AiChatCompactScope.scaleOf(context);
    final isInitializing =
        chatState.sessionInitState == AiSessionInitState.initializing;
    final backgroundColor = isInitializing
        ? context.colorScheme.primaryContainer.withValues(alpha: 0.78)
        : context.colorScheme.errorContainer.withValues(alpha: 0.84);
    final foregroundColor = isInitializing
        ? context.colorScheme.onPrimaryContainer
        : context.colorScheme.onErrorContainer;
    final message = isInitializing
        ? (context.isZh ? '正在准备当前进程的 AI 会话…' : 'Preparing AI session…')
        : (chatState.error ??
              (context.isZh ? '当前进程的 AI 会话初始化失败' : 'AI session init failed'));

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        (isCompact ? 4.0 : 6.0) * contentScale,
        0,
        (isCompact ? 4.0 : 6.0) * contentScale,
        (isCompact ? 6.0 : 8.0) * contentScale,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: (isCompact ? 10.0 : 12.0) * contentScale,
        vertical: (isCompact ? 8.0 : 10.0) * contentScale,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14.0 * contentScale),
      ),
      child: Row(
        children: [
          Icon(
            isInitializing
                ? Icons.hourglass_top_rounded
                : Icons.error_outline_rounded,
            size: (isCompact ? 14.0 : 16.0) * contentScale,
            color: foregroundColor,
          ),
          SizedBox(width: (isCompact ? 6.0 : 8.0) * contentScale),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: (isCompact ? 10.0 : 11.5) * contentScale,
                color: foregroundColor,
              ),
            ),
          ),
          if (!isInitializing)
            TextButton(
              onPressed: () async {
                await onRetry();
              },
              child: Text(
                context.l10n.retry,
                style: TextStyle(color: foregroundColor),
              ),
            ),
        ],
      ),
    );
  }
}

class _AiOverlayResizeBorderHighlightPainter extends CustomPainter {
  const _AiOverlayResizeBorderHighlightPainter({
    required this.color,
    required this.borderRadius,
    required this.clipExtent,
  });

  final Color color;
  final double borderRadius;
  final double clipExtent;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.2;
    const glowStrokeWidth = 4.2;
    final clipPadding = 6.0;
    final glowStroke = Paint()
      ..color = color.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowStrokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final outerRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    final glowRRect = outerRRect.deflate(glowStrokeWidth / 2);
    final rRect = outerRRect.deflate(strokeWidth / 2);

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        size.width - clipExtent - clipPadding,
        size.height - clipExtent - clipPadding,
        clipExtent + clipPadding,
        clipExtent + clipPadding,
      ),
    );
    canvas.drawRRect(glowRRect, glowStroke);
    canvas.drawRRect(rRect, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(
    covariant _AiOverlayResizeBorderHighlightPainter oldDelegate,
  ) {
    return oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.clipExtent != clipExtent;
  }
}
