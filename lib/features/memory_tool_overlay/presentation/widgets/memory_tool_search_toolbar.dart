import 'package:JsxposedX/common/widgets/horizontal_action_toolbar.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolSearchToolbar extends StatelessWidget {
  const MemoryToolSearchToolbar({
    super.key,
    required this.canRunFirstScan,
    required this.canRunNextScan,
    required this.canReset,
    required this.onFirstScan,
    required this.onNextScan,
    required this.onReset,
  });

  final bool canRunFirstScan;
  final bool canRunNextScan;
  final bool canReset;
  final VoidCallback onFirstScan;
  final VoidCallback onNextScan;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return HorizontalActionToolbar(
      borderRadius: 16.r,
      items: <HorizontalActionToolbarItem>[
        HorizontalActionToolbarItem(
          icon: Icons.search_rounded,
          label: context.l10n.memoryToolActionFirstScan,
          onPressed: canRunFirstScan ? onFirstScan : null,
          isPrimary: true,
        ),
        HorizontalActionToolbarItem(
          icon: Icons.filter_alt_rounded,
          label: context.l10n.memoryToolActionNextScan,
          onPressed: canRunNextScan ? onNextScan : null,
        ),
        HorizontalActionToolbarItem(
          icon: Icons.restart_alt_rounded,
          label: context.l10n.memoryToolActionReset,
          onPressed: canReset ? onReset : null,
        ),
      ],
    );
  }
}
