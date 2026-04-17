import 'package:JsxposedX/common/widgets/overlay_window/overlay_window.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_search_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_process_terminated_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/process_avatar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/process_picker_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/memory_tool_edit_tab.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/memory_tool_saved_tab.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/memory_tool_search_tab.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_presentation.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolOverlay extends HookConsumerWidget {
  const MemoryToolOverlay({super.key});

  static final PageStorageBucket _pageStorageBucket = PageStorageBucket();

  OverlayWindowConfig get overlayConfig => OverlayWindowConfig(
    sceneId: 0,
    bubbleSize: OverlayWindowPresentation.defaultBubbleSize,
    notificationTitle: (context) => context.l10n.overlayMemoryToolTitle,
    notificationContent: (context) =>
        context.l10n.overlayWindowNotificationContent,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final isPickerVisible = useState(false);
    final isProcessTerminatedDialogVisible = useState(false);
    final hasPendingProcessTerminatedDialog = useState(false);
    final isHandlingProcessTerminated = useRef(false);
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final isPanelVisible = ref.watch(
      overlayWindowHostRuntimeProvider.select(
        (state) => state.payload.isPanel && !state.isTransitioningToPanel,
      ),
    );
    final mediaQuery = MediaQuery.of(context);
    final isPortrait = mediaQuery.orientation == Orientation.portrait;
    final portraitTopInset = isPortrait ? mediaQuery.padding.top : 0.0;

    void openProcessPicker() {
      ref.invalidate(
        getProcessInfoProvider(
          offset: 0,
          limit: MemoryToolProcessPickerDialog.initialPageSize,
        ),
      );
      isPickerVisible.value = true;
    }

    Future<void> handleProcessTerminated() async {
      if (isHandlingProcessTerminated.value) {
        return;
      }

      isHandlingProcessTerminated.value = true;
      try {
        try {
          await ref.read(memorySearchActionProvider.notifier).cancelSearch();
        } catch (_) {}

        try {
          await ref
              .read(memorySearchActionProvider.notifier)
              .resetSearchSession();
        } catch (_) {}

        ref.read(memoryToolSelectedProcessProvider.notifier).clear();
        ref.read(memoryToolResultSelectionProvider.notifier).clear();
        ref.invalidate(memorySearchActionProvider);
        ref.invalidate(getSearchSessionStateProvider);
        ref.invalidate(getSearchTaskStateProvider);
        ref.invalidate(getSearchResultsProvider);
        ref.invalidate(currentSearchResultsProvider);
        ref.invalidate(currentSearchResultLivePreviewsProvider);
        ref.invalidate(hasMatchingSearchSessionProvider);
        ref.invalidate(hasRunningSearchTaskProvider);

        if (!context.mounted) {
          return;
        }

        final shouldShowDialogImmediately = ref
            .read(overlayWindowHostRuntimeProvider)
            .payload
            .isPanel;
        if (shouldShowDialogImmediately) {
          isProcessTerminatedDialogVisible.value = true;
          hasPendingProcessTerminatedDialog.value = false;
        } else {
          hasPendingProcessTerminatedDialog.value = true;
        }
      } finally {
        isHandlingProcessTerminated.value = false;
      }
    }

    ref.listen<AsyncValue<void>>(memorySearchActionProvider, (_, next) {
      next.whenOrNull(
        error: (error, _) {
          if (_isProcessUnavailableError(error)) {
            Future.microtask(handleProcessTerminated);
          }
        },
      );
    });

    ref.listen<AsyncValue<List<SearchResult>>>(currentSearchResultsProvider, (
      _,
      next,
    ) {
      next.whenOrNull(
        error: (error, _) {
          if (_isProcessUnavailableError(error)) {
            Future.microtask(handleProcessTerminated);
          }
        },
      );
    });

    ref.listen<AsyncValue<Map<int, MemoryValuePreview>>>(
      currentSearchResultLivePreviewsProvider,
      (_, next) {
        next.whenOrNull(
          error: (error, _) {
            if (_isProcessUnavailableError(error)) {
              Future.microtask(handleProcessTerminated);
            }
          },
        );
      },
    );

    ref.listen<AsyncValue<SearchTaskState>>(getSearchTaskStateProvider, (
      _,
      next,
    ) {
      next.whenOrNull(
        error: (error, _) {
          if (_isProcessUnavailableError(error)) {
            Future.microtask(handleProcessTerminated);
          }
        },
      );
    });

    useEffect(() {
      if (!isPanelVisible || !hasPendingProcessTerminatedDialog.value) {
        return null;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        isProcessTerminatedDialogVisible.value = true;
        hasPendingProcessTerminatedDialog.value = false;
      });
      return null;
    }, [isPanelVisible, hasPendingProcessTerminatedDialog.value]);

    useEffect(() {
      if (!isPanelVisible || selectedProcess == null) {
        return null;
      }

      var isDisposed = false;
      Future.microtask(() async {
        int latestPid;
        try {
          latestPid = await ref.refresh(
            getPidProvider(packageName: selectedProcess.packageName).future,
          );
        } catch (_) {
          return;
        }
        if (isDisposed || !context.mounted) {
          return;
        }
        if (latestPid == 0) {
          await handleProcessTerminated();
        }
      });

      return () {
        isDisposed = true;
      };
    }, [isPanelVisible, selectedProcess?.packageName, selectedProcess?.pid]);

    return DefaultTabController(
      length: 3,
      child: Stack(
        children: [
          OverlayWindowScaffold(
            overlayConfig: overlayConfig,
            overlayBar: OverlayWindowBar(
              backgroundColor: context.colorScheme.surface.withValues(
                alpha: 0.3,
              ),
              toolbarHeight: 52.r,
              titleSpacing: 0,
              leadingWidth: 48.r,
              leading: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  openProcessPicker();
                },
                icon: ProcessAvatar(process: selectedProcess),
              ),
              title: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.r),
                  color: context.colorScheme.primary.withValues(alpha: 0.14),
                ),
                labelColor: context.colorScheme.primary,
                unselectedLabelColor: context.colorScheme.onSurfaceVariant,
                labelStyle: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                tabs: <Widget>[
                  Tab(text: context.l10n.memoryToolTabSearch),
                  Tab(text: context.l10n.memoryToolTabEdit),
                  Tab(text: context.l10n.memoryToolTabSaved),
                ],
              ),
              showMinimizeAction: true,
              showCloseAction: false,
            ),
            backgroundColor: context.colorScheme.surface.withValues(alpha: 0.6),
            padding: EdgeInsets.only(top: portraitTopInset),
            body: PageStorage(
              bucket: _pageStorageBucket,
              child: selectedProcess == null
                  ? Center(
                      child: Text(
                        context.l10n.selectApp,
                        style: TextStyle(
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    )
                  : const TabBarView(
                      children: <Widget>[
                        MemoryToolSearchTab(),
                        MemoryToolEditTab(),
                        MemoryToolSavedTab(),
                      ],
                    ),
            ),
          ),
          if (isPickerVisible.value)
            Positioned.fill(
              child: MemoryToolProcessPickerDialog(
                onClose: () {
                  isPickerVisible.value = false;
                },
                onSelected: (process) {
                  ref
                      .read(memoryToolSelectedProcessProvider.notifier)
                      .select(process);
                  isPickerVisible.value = false;
                },
                onRetry: () {
                  ref.invalidate(
                    getProcessInfoProvider(
                      offset: 0,
                      limit: MemoryToolProcessPickerDialog.initialPageSize,
                    ),
                  );
                },
              ),
            ),
          if (isProcessTerminatedDialogVisible.value)
            Positioned.fill(
              child: MemoryToolProcessTerminatedDialog(
                onConfirm: () {
                  isProcessTerminatedDialogVisible.value = false;
                },
              ),
            ),
        ],
      ),
    );
  }
}

bool _isProcessUnavailableError(Object error) {
  final normalized = error.toString().toLowerCase();
  return normalized.contains('target process is no longer available') ||
      normalized.contains(
        'search session target process is no longer available',
      );
}
