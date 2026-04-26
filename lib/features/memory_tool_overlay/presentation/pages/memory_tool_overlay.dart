import 'dart:async';

import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_window.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/ai_overlay/ai_overlay.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_breakpoint_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/memory_tool_browse_tab.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/memory_tool_pointer_tab.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_browse_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_pointer_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_settings_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_auto_chase_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_auto_chase_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_pointer_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_search_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_process_terminated_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/process_avatar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/process_picker_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/memory_tool_debug_tab.dart';
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
    final tabController = useTabController(initialLength: 5);
    final isPickerVisible = useState(false);
    final isProcessTerminatedDialogVisible = useState(false);
    final hasPendingProcessTerminatedDialog = useState(false);
    final isHandlingProcessTerminated = useRef(false);
    final previousPanelVisible = useRef(false);
    final pendingAutoPausePanelOpen = useRef(false);
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final memoryToolSettingsAsync = ref.watch(memoryToolSettingsProvider);
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

        try {
          await ref
              .read(memoryPointerActionProvider.notifier)
              .resetPointerScanSession();
        } catch (_) {}

        try {
          await ref
              .read(memoryPointerAutoChaseActionProvider.notifier)
              .resetPointerAutoChase();
        } catch (_) {}

        ref.read(memoryToolSelectedProcessProvider.notifier).clear();
        ref.read(memoryToolResultSelectionProvider.notifier).clear();
        ref.invalidate(memorySearchActionProvider);
        ref.invalidate(getSearchSessionStateProvider);
        ref.invalidate(getSearchTaskStateProvider);
        ref.invalidate(getSearchResultsProvider);
        ref.invalidate(currentSearchResultsProvider);
        ref.invalidate(currentSearchResultLivePreviewsProvider);
        ref.read(memoryToolBrowseControllerProvider.notifier).clear();
        await ref.read(memoryToolPointerControllerProvider.notifier).clear();
        ref.invalidate(currentBrowseResultsProvider);
        ref.invalidate(currentBrowseResultLivePreviewsProvider);
        ref.invalidate(getPointerScanSessionStateProvider);
        ref.invalidate(getPointerScanTaskStateProvider);
        ref.invalidate(getPointerScanResultsProvider);
        ref.invalidate(getPointerAutoChaseStateProvider);
        ref.invalidate(getPointerAutoChaseLayerResultsProvider);
        if (selectedProcess != null) {
          ref.invalidate(
            getMemoryBreakpointsProvider(pid: selectedProcess.pid),
          );
          ref.invalidate(
            getMemoryBreakpointStateProvider(pid: selectedProcess.pid),
          );
          ref.invalidate(
            getMemoryBreakpointHitsProvider(pid: selectedProcess.pid),
          );
        }
        ref.read(memoryBreakpointSelectedIdProvider.notifier).clear();
        ref.invalidate(hasMatchingSearchSessionProvider);
        ref.invalidate(hasRunningSearchTaskProvider);
        ref.invalidate(hasRunningPointerTaskProvider);

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
            return;
          }
          unawaited(
            ToastOverlayMessage.show(
              error.toString().replaceFirst('Exception: ', ''),
            ),
          );
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
      final wasPanelVisible = previousPanelVisible.value;
      previousPanelVisible.value = isPanelVisible;
      final didOpenPanel = isPanelVisible && !wasPanelVisible;
      if (!isPanelVisible) {
        pendingAutoPausePanelOpen.value = false;
        return null;
      }
      if (didOpenPanel) {
        pendingAutoPausePanelOpen.value = true;
      }
      if (selectedProcess == null) {
        pendingAutoPausePanelOpen.value = false;
        return null;
      }
      if (!pendingAutoPausePanelOpen.value) {
        return null;
      }
      final settings = memoryToolSettingsAsync.asData?.value;
      if (settings == null) {
        return null;
      }
      pendingAutoPausePanelOpen.value = false;
      if (!settings.autoPauseOnOverlayOpen) {
        return null;
      }

      var isDisposed = false;
      Future.microtask(() async {
        try {
          await ref
              .read(memoryProcessControlActionProvider.notifier)
              .setProcessPaused(pid: selectedProcess.pid, paused: true);
        } catch (error) {
          if (isDisposed || !context.mounted) {
            return;
          }
          await ToastOverlayMessage.show(
            error.toString().replaceFirst('Exception: ', ''),
            duration: const Duration(milliseconds: 1400),
          );
        }
      });

      return () {
        isDisposed = true;
      };
    }, [isPanelVisible, memoryToolSettingsAsync, selectedProcess?.pid]);

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

    return Stack(
      children: [
        OverlayWindowScaffold(
          overlayConfig: overlayConfig,
          overlayBar: OverlayWindowBar(
            backgroundColor: context.colorScheme.surface.withValues(alpha: 0.3),
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
              controller: tabController,
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
                const Tab(icon: Icon(Icons.search_rounded)),
                const Tab(icon: Icon(Icons.visibility_rounded)),
                const Tab(icon: Icon(Icons.timeline_rounded)),
                const Tab(icon: Icon(Icons.bug_report_rounded)),
                const Tab(icon: Icon(Icons.bookmark_rounded)),
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
                : TabBarView(
                    controller: tabController,
                    children: <Widget>[
                      MemoryToolSearchTab(
                        onOpenBrowseTab: () {
                          tabController.animateTo(1);
                        },
                        onOpenPointerTab: () {
                          tabController.animateTo(2);
                        },
                        onOpenDebugTab: () {
                          tabController.animateTo(3);
                        },
                        onOpenSavedTab: () {
                          tabController.animateTo(4);
                        },
                      ),
                      MemoryToolBrowseTab(
                        onOpenPointerTab: () {
                          tabController.animateTo(2);
                        },
                        onOpenDebugTab: () {
                          tabController.animateTo(3);
                        },
                      ),
                      MemoryToolPointerTab(
                        onOpenBrowseTab: () {
                          tabController.animateTo(1);
                        },
                      ),
                      MemoryToolDebugTab(
                        onOpenBrowseTab: () {
                          tabController.animateTo(1);
                        },
                        onOpenPointerTab: () {
                          tabController.animateTo(2);
                        },
                      ),
                      MemoryToolSavedTab(
                        onOpenBrowseTab: () {
                          tabController.animateTo(1);
                        },
                        onOpenPointerTab: () {
                          tabController.animateTo(2);
                        },
                        onOpenDebugTab: () {
                          tabController.animateTo(3);
                        },
                      ),
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
                final browseNotifier = ref.read(
                  memoryToolBrowseControllerProvider.notifier,
                );
                browseNotifier.clear();
                ref.read(memoryToolPointerControllerProvider.notifier).clear();
                ref
                    .read(memoryPointerActionProvider.notifier)
                    .resetPointerScanSession();
                ref
                    .read(memoryPointerAutoChaseActionProvider.notifier)
                    .resetPointerAutoChase();
                ref.read(memoryBreakpointSelectedIdProvider.notifier).clear();
                ref
                    .read(memoryToolSelectedProcessProvider.notifier)
                    .select(process);
                Future<void>.microtask(() async {
                  try {
                    await browseNotifier.ensureReadableRegions(
                      pid: process.pid.toInt(),
                    );
                  } catch (_) {}
                });
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
        const Positioned.fill(child: AiOverlay()),
      ],
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
