import 'package:flutter/material.dart';

import 'bubble_container.dart';
import 'bubble_content/bubble_content.dart';
import 'bubble_states/bubble_state.dart';
import 'bubble_toolbar/bubble_toolbar.dart';

abstract class BaseAiChatBubble extends StatelessWidget {
  final String content;
  final String role;
  final bool isError;
  final VoidCallback? onRetry;
  final bool isToolCalling;
  final String? packageName;
  final String? retryLabel;

  const BaseAiChatBubble({
    super.key,
    required this.content,
    required this.role,
    this.isError = false,
    this.onRetry,
    this.isToolCalling = false,
    this.packageName,
    this.retryLabel,
  });

  @protected
  BubbleState createBubbleState() {
    return BubbleState(
      content: content,
      role: role,
      isError: isError,
      onRetry: onRetry,
      isToolCalling: isToolCalling,
      packageName: packageName,
      retryLabel: retryLabel,
    );
  }

  @protected
  BaseBubbleContainerPart createContainerPart() {
    return const DefaultBubbleContainerPart();
  }

  @protected
  BaseBubbleContentPart createContentPart() {
    return const DefaultBubbleContentPart();
  }

  @protected
  BaseBubbleToolbarPart createToolbarPart() {
    return const DefaultBubbleToolbarPart();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleState = createBubbleState();
    final containerPart = createContainerPart();
    final contentPart = createContentPart();
    final toolbarPart = createToolbarPart();
    return containerPart.build(
      context,
      bubbleState,
      contentPart: contentPart,
      toolbarPart: toolbarPart,
    );
  }
}

class AiChatBubble extends BaseAiChatBubble {
  const AiChatBubble({
    super.key,
    required super.content,
    required super.role,
    super.isError,
    super.onRetry,
    super.isToolCalling,
    super.packageName,
    super.retryLabel,
  });
}
