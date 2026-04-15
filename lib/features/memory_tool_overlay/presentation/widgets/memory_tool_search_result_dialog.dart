import 'package:JsxposedX/common/widgets/horizontal_action_toolbar.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_panel_dialog.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolSearchResultDialog extends StatelessWidget {
  const MemoryToolSearchResultDialog({
    super.key,
    required this.result,
    required this.displayValue,
    required this.onClose,
  });

  final SearchResult result;
  final String displayValue;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return OverlayPanelDialog.card(
      onClose: onClose,
      maxWidthPortrait: 360.r,
      maxWidthLandscape: 420.r,
      maxHeightPortrait: 320.r,
      maxHeightLandscape: 300.r,
      cardBorderRadius: 18.r,
      childBuilder: (context, viewport, layout) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(14.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              HorizontalActionToolbar(
                items: <HorizontalActionToolbarItem>[
                  HorizontalActionToolbarItem(
                    icon: Icons.edit,
                    label: '编辑',
                    onPressed: () {},
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: onClose,
                  child: Text(context.l10n.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
