import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/memory_tool_edit_tab.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/memory_tool_search_tab.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/tabs/memory_tool_watch_tab.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';

class SelectedProcessPanel extends StatelessWidget {
  const SelectedProcessPanel({super.key, required this.selectedProcess});

  final ProcessInfo? selectedProcess;

  @override
  Widget build(BuildContext context) {
    if (selectedProcess == null) {
      return Center(
        child: Text(
          context.l10n.selectApp,
          style: TextStyle(
            color: context.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      );
    }

    return const TabBarView(
      children: <Widget>[
        MemoryToolSearchTab(),
        MemoryToolEditTab(),
        MemoryToolWatchTab(),
      ],
    );
  }
}
