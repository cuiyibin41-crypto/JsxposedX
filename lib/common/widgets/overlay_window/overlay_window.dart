import 'dart:math' as math;

import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/overlay_window/presentation/models/overlay_scene_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OverlayWindowPanelControls {
  const OverlayWindowPanelControls({
    required this.minimize,
    required this.close,
  });

  final VoidCallback minimize;
  final VoidCallback close;
}

class OverlayWindowPanelScope extends InheritedWidget {
  const OverlayWindowPanelScope({
    super.key,
    required this.controls,
    required super.child,
  });

  final OverlayWindowPanelControls controls;

  static OverlayWindowPanelControls? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<OverlayWindowPanelScope>()
        ?.controls;
  }

  @override
  bool updateShouldNotify(OverlayWindowPanelScope oldWidget) {
    return controls != oldWidget.controls;
  }
}

class OverlayWindow extends StatelessWidget {
  const OverlayWindow({
    super.key,
    required this.child,
    this.header,
    this.onBackdropTap,
    this.footer,
    this.margin,
    this.maxWidth,
    this.maxHeight,
    this.backdrop,
    this.decoration,
    this.contentDecoration,
    this.padding,
    this.contentPadding,
  });

  final Widget child;
  final Widget? header;
  final VoidCallback? onBackdropTap;
  final Widget? footer;
  final EdgeInsetsGeometry? margin;
  final double? maxWidth;
  final double? maxHeight;
  final Widget? backdrop;
  final Decoration? decoration;
  final Decoration? contentDecoration;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final hasHeader = header != null;
    final resolvedMargin = margin ?? EdgeInsets.zero;
    final resolvedPadding = padding ?? EdgeInsets.zero;
    final resolvedContentPadding = contentPadding ?? EdgeInsets.zero;

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shouldFillWidth = maxWidth == null;
          final shouldFillHeight = maxHeight == null;
          final resolvedMaxWidth = maxWidth == null
              ? constraints.maxWidth
              : math.min(maxWidth!, constraints.maxWidth);
          final resolvedMaxHeight = maxHeight == null
              ? constraints.maxHeight
              : math.min(maxHeight!, constraints.maxHeight);

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBackdropTap,
                child: backdrop ?? const SizedBox.expand(),
              ),
              SafeArea(
                child: Padding(
                  padding: resolvedMargin,
                  child: Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: shouldFillWidth ? resolvedMaxWidth : 0,
                        maxWidth: resolvedMaxWidth,
                        minHeight: shouldFillHeight ? resolvedMaxHeight : 0,
                        maxHeight: resolvedMaxHeight,
                      ),
                      child: DecoratedBox(
                        decoration: decoration ?? const BoxDecoration(),
                        child: Padding(
                          padding: resolvedPadding,
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (hasHeader) header!,
                              Expanded(
                                child: DecoratedBox(
                                  decoration:
                                      contentDecoration ??
                                      const BoxDecoration(),
                                  child: Padding(
                                    padding: resolvedContentPadding,
                                    child: child,
                                  ),
                                ),
                              ),
                              if (footer != null) footer!,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class OverlayWindowScaffold extends StatelessWidget {
  const OverlayWindowScaffold({
    super.key,
    this.body,
    this.overlayConfig,
    this.overlayBar,
    this.bottomBar,
    this.backgroundColor,
    this.onBackdropTap,
    this.margin,
    this.maxWidth,
    this.maxHeight,
    this.backdrop,
    this.decoration,
    this.contentDecoration,
    this.padding,
    this.contentPadding,
    @Deprecated('Use body instead.') this.child,
    @Deprecated('Use overlayBar instead.') this.header,
    @Deprecated('Use bottomBar instead.') this.footer,
  }) : assert(body != null || child != null, 'body is required.');

  final Widget? body;
  final OverlayWindowConfig? overlayConfig;
  final Widget? overlayBar;
  final Widget? bottomBar;
  @Deprecated('Use overlayBar instead.')
  final Widget? header;
  @Deprecated('Use bottomBar instead.')
  final Widget? footer;
  @Deprecated('Use body instead.')
  final Widget? child;
  final Color? backgroundColor;
  final VoidCallback? onBackdropTap;
  final EdgeInsetsGeometry? margin;
  final double? maxWidth;
  final double? maxHeight;
  final Widget? backdrop;
  final Decoration? decoration;
  final Decoration? contentDecoration;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? contentPadding;

  OverlaySceneDefinition toSceneDefinition() {
    assert(
      overlayConfig != null,
      'overlayConfig is required for overlay scene registration.',
    );
    return OverlaySceneDefinition(
      sceneId: overlayConfig!.sceneId,
      bubbleSize: overlayConfig!.bubbleSize,
      notificationTitle: overlayConfig!.notificationTitle,
      notificationContent: overlayConfig!.notificationContent,
      panelBuilder: (_) => this,
    );
  }

  int get registeredSceneId {
    assert(
      overlayConfig != null,
      'overlayConfig is required for overlay scene registration.',
    );
    return overlayConfig!.sceneId;
  }

  @override
  Widget build(BuildContext context) {
    final controls = OverlayWindowPanelScope.maybeOf(context);
    final resolvedBody = body ?? child!;
    final resolvedOverlayBar = overlayBar ?? header;
    final resolvedBottomBar = bottomBar ?? footer;
    final resolvedBackdrop = backdrop ?? const SizedBox.expand();
    final resolvedBackgroundColor =
        backgroundColor ?? Theme.of(context).colorScheme.surface;
    final resolvedDecoration = decoration;
    final resolvedContentDecoration = contentDecoration;

    return OverlayWindow(
      header: resolvedOverlayBar,
      onBackdropTap: onBackdropTap ?? controls?.minimize,
      footer: _adaptBottomBar(resolvedBottomBar),
      margin: margin,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      backdrop: resolvedBackdrop,
      decoration: resolvedDecoration,
      contentDecoration:
          resolvedContentDecoration ??
          BoxDecoration(color: resolvedBackgroundColor),
      padding: padding ?? EdgeInsets.zero,
      contentPadding: contentPadding ?? EdgeInsets.zero,
      child: resolvedBody,
    );
  }

  Widget? _adaptBottomBar(Widget? bottomBar) {
    if (bottomBar is! BottomAppBar) {
      return bottomBar;
    }

    return Material(
      color: bottomBar.color,
      elevation: bottomBar.elevation ?? 0,
      shadowColor: bottomBar.shadowColor,
      surfaceTintColor: bottomBar.surfaceTintColor,
      clipBehavior: bottomBar.clipBehavior,
      child: SizedBox(
        height: bottomBar.height,
        child: Padding(
          padding: bottomBar.padding ?? EdgeInsets.zero,
          child: bottomBar.child,
        ),
      ),
    );
  }
}

class OverlayWindowConfig {
  const OverlayWindowConfig({
    required this.sceneId,
    required this.bubbleSize,
    required this.notificationTitle,
    required this.notificationContent,
  });

  final int sceneId;
  final double bubbleSize;
  final OverlaySceneTextBuilder notificationTitle;
  final OverlaySceneTextBuilder notificationContent;
}

class OverlayWindowBar extends StatelessWidget implements PreferredSizeWidget {
  const OverlayWindowBar({
    super.key,
    this.leading,
    this.leadingWidth,
    this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.centerTitle,
    this.toolbarHeight,
    this.foregroundColor,
    this.backgroundColor,
    this.decoration,
    this.titleSpacing,
    this.actionSpacing,
    this.showMinimizeAction = false,
    this.showCloseAction = false,
    this.onMinimize,
    this.onClose,
  });

  final Widget? leading;
  final double? leadingWidth;
  final Widget? title;
  final Widget? subtitle;
  final List<Widget> actions;
  final bool? centerTitle;
  final double? toolbarHeight;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Decoration? decoration;
  final double? titleSpacing;
  final double? actionSpacing;
  final bool showMinimizeAction;
  final bool showCloseAction;
  final VoidCallback? onMinimize;
  final VoidCallback? onClose;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight ?? kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appBarTheme = theme.appBarTheme;
    final controls = OverlayWindowPanelScope.maybeOf(context);
    final resolvedLeadingWidth =
        leadingWidth ?? appBarTheme.leadingWidth ?? kToolbarHeight;
    final resolvedTitleSpacing =
        titleSpacing ??
        appBarTheme.titleSpacing ??
        NavigationToolbar.kMiddleSpacing;
    final resolvedActionSpacing = actionSpacing ?? 8.w;
    final resolvedToolbarHeight = toolbarHeight ?? kToolbarHeight;
    final resolvedForegroundColor =
        foregroundColor ?? appBarTheme.foregroundColor ?? colorScheme.onSurface;
    final resolvedDecoration =
        decoration ??
        BoxDecoration(
          color:
              backgroundColor ??
              appBarTheme.backgroundColor ??
              colorScheme.surface,
        );
    final content = (title == null && subtitle == null)
        ? const SizedBox.shrink()
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (title != null)
                DefaultTextStyle(
                  style:
                      appBarTheme.titleTextStyle ??
                      theme.textTheme.titleLarge?.copyWith(
                        color: resolvedForegroundColor,
                        fontWeight: FontWeight.w600,
                      ) ??
                      TextStyle(
                        color: resolvedForegroundColor,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: title!,
                ),
              if (subtitle != null) ...<Widget>[
                if (title != null) SizedBox(height: 4.h),
                DefaultTextStyle(
                  style:
                      appBarTheme.toolbarTextStyle ??
                      theme.textTheme.bodySmall?.copyWith(
                        color: resolvedForegroundColor.withValues(alpha: 0.78),
                      ) ??
                      TextStyle(
                        color: resolvedForegroundColor.withValues(alpha: 0.78),
                        fontSize: 12.sp,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  child: subtitle!,
                ),
              ],
            ],
          );
    final builtInActions = <Widget>[
      if (showMinimizeAction)
        IconButton(
          onPressed: onMinimize ?? controls?.minimize ?? () {},
          icon: const Icon(Icons.remove_rounded),
          tooltip: 'Minimize',
        ),
      if (showCloseAction)
        IconButton(
          onPressed: onClose ?? controls?.close ?? () {},
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        ),
    ];
    final resolvedActions = <Widget>[...actions, ...builtInActions];
    final resolvedLeading = switch (leading) {
      null => null,
      final widget? => ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: resolvedLeadingWidth),
        child: Align(
          alignment: Alignment.center,
          child: widget is IconButton ? Center(child: widget) : widget,
        ),
      ),
    };

    if (leading == null &&
        title == null &&
        subtitle == null &&
        resolvedActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: resolvedDecoration,
      child: IconTheme.merge(
        data: IconThemeData(color: resolvedForegroundColor),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: resolvedForegroundColor),
          child: SizedBox(
            height: resolvedToolbarHeight,
            child: NavigationToolbar(
              leading: resolvedLeading,
              middle: content,
              trailing: resolvedActions.isEmpty
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (var i = 0; i < resolvedActions.length; i++) ...<Widget>[
                          if (i > 0) SizedBox(width: resolvedActionSpacing),
                          resolvedActions[i],
                        ],
                      ],
                    ),
              centerMiddle: centerTitle ?? appBarTheme.centerTitle ?? false,
              middleSpacing: resolvedTitleSpacing,
            ),
          ),
        ),
      ),
    );
  }
}

@Deprecated('Use OverlayWindowBar instead.')
class OverlayWindowHeader extends OverlayWindowBar {
  const OverlayWindowHeader({
    super.key,
    super.leading,
    super.leadingWidth,
    super.title,
    super.subtitle,
    super.actions = const <Widget>[],
    super.centerTitle,
    super.toolbarHeight,
    super.foregroundColor,
    super.backgroundColor,
    super.decoration,
    super.titleSpacing,
    super.actionSpacing,
    super.showMinimizeAction = false,
    super.showCloseAction = false,
    super.onMinimize,
    super.onClose,
  });
}

class OverlayWindowHeaderButton extends StatelessWidget {
  const OverlayWindowHeaderButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onPressed,
        child: SizedBox(
          width: 40.w,
          height: 40.w,
          child: Icon(icon, size: 20.sp, color: colorScheme.onSurface),
        ),
      ),
    );
  }
}
