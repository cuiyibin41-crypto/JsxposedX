import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolResultSelectionBar extends StatefulWidget {
  const MemoryToolResultSelectionBar({
    super.key,
    this.actions = const <MemoryToolResultSelectionActionData>[],
    this.groups = const <MemoryToolResultSelectionActionGroupData>[],
  });

  final List<MemoryToolResultSelectionActionData> actions;
  final List<MemoryToolResultSelectionActionGroupData> groups;

  @override
  State<MemoryToolResultSelectionBar> createState() =>
      _MemoryToolResultSelectionBarState();
}

class _MemoryToolResultSelectionBarState
    extends State<MemoryToolResultSelectionBar> {
  final Set<int> _expandedGroupIndexes = <int>{0};

  @override
  void didUpdateWidget(covariant MemoryToolResultSelectionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _expandedGroupIndexes.removeWhere(
      (index) => index < 0 || index >= widget.groups.length,
    );
    if (_expandedGroupIndexes.isEmpty && widget.groups.isNotEmpty) {
      _expandedGroupIndexes.add(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    final actions = widget.actions;
    final hasGroups = groups.isNotEmpty;
    final primaryActions = hasGroups
        ? groups
        : <MemoryToolResultSelectionActionGroupData>[];
    final secondaryActions = actions;

    if (actions.isEmpty) {
      if (!hasGroups) {
        return const SizedBox.shrink();
      }
    }
    if (hasGroups && groups.every((group) => group.actions.isEmpty)) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 6.r),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.42,
              ),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.r, vertical: 2.r),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (hasGroups) ...<Widget>[
                    for (
                      int index = 0;
                      index < primaryActions.length;
                      index++
                    ) ...<Widget>[
                      if (index > 0) SizedBox(width: 4.r),
                      _MemoryToolResultSelectionGroupSegment(
                        group: primaryActions[index],
                        isExpanded: _expandedGroupIndexes.contains(index),
                        onTap: () {
                          setState(() {
                            if (_expandedGroupIndexes.contains(index)) {
                              _expandedGroupIndexes.remove(index);
                            } else {
                              _expandedGroupIndexes.add(index);
                            }
                          });
                        },
                      ),
                    ],
                  ] else
                    for (
                      int index = 0;
                      index < secondaryActions.length;
                      index++
                    ) ...<Widget>[
                      if (index > 0) const _MemoryToolResultSelectionDivider(),
                      _MemoryToolResultSelectionAction(
                        data: secondaryActions[index],
                      ),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MemoryToolResultSelectionActionData {
  const MemoryToolResultSelectionActionData({
    required this.icon,
    this.label,
    this.onTap,
  });

  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
}

class MemoryToolResultSelectionActionGroupData {
  const MemoryToolResultSelectionActionGroupData({
    required this.icon,
    required this.label,
    required this.actions,
  });

  final IconData icon;
  final String label;
  final List<MemoryToolResultSelectionActionData> actions;
}

class _MemoryToolResultSelectionDivider extends StatelessWidget {
  const _MemoryToolResultSelectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18.r,
      margin: EdgeInsets.symmetric(horizontal: 2.r),
      color: context.colorScheme.outlineVariant.withValues(alpha: 0.52),
    );
  }
}

class _MemoryToolResultSelectionGroupSegment extends StatelessWidget {
  const _MemoryToolResultSelectionGroupSegment({
    required this.group,
    required this.isExpanded,
    required this.onTap,
  });

  final MemoryToolResultSelectionActionGroupData group;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isExpanded
            ? context.colorScheme.surface.withValues(alpha: 0.78)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9.r),
        border: Border.all(
          color: isExpanded
              ? context.colorScheme.outlineVariant.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isExpanded ? 3.r : 0,
          vertical: isExpanded ? 2.r : 0,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _MemoryToolResultSelectionGroupAction(
                icon: group.icon,
                label: group.label,
                isSelected: isExpanded,
                isEnabled: group.actions.isNotEmpty,
                onTap: onTap,
              ),
              if (isExpanded) ...<Widget>[
                SizedBox(width: 2.r),
                for (final action in group.actions)
                  _MemoryToolResultSelectionAction(data: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryToolResultSelectionAction extends StatelessWidget {
  const _MemoryToolResultSelectionAction({required this.data});

  final MemoryToolResultSelectionActionData data;

  @override
  Widget build(BuildContext context) {
    final action = InkWell(
      borderRadius: BorderRadius.circular(7.r),
      onTap: data.onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(7.r),
        ),
        child: SizedBox(
          width: 24.r,
          height: 24.r,
          child: Center(
            child: Icon(
              data.icon,
              size: 15.r,
              color: context.colorScheme.onSurface.withValues(
                alpha: data.onTap == null ? 0.3 : 0.76,
              ),
            ),
          ),
        ),
      ),
    );
    final label = data.label;
    if (label == null || label.trim().isEmpty) {
      return action;
    }
    return Tooltip(message: label, child: action);
  }
}

class _MemoryToolResultSelectionGroupAction extends StatelessWidget {
  const _MemoryToolResultSelectionGroupAction({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final action = InkWell(
      borderRadius: BorderRadius.circular(10.r),
      onTap: isEnabled ? onTap : null,
      child: SizedBox(
        width: 34.r,
        height: 34.r,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected
                ? context.colorScheme.primaryContainer.withValues(alpha: 0.72)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Center(
            child: SizedBox(
              width: 28.r,
              height: 28.r,
              child: Center(
                child: Icon(
                  icon,
                  size: 18.r,
                  color: isSelected
                      ? context.colorScheme.onPrimaryContainer
                      : context.colorScheme.onSurface.withValues(
                          alpha: isEnabled ? 0.76 : 0.3,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Tooltip(message: label, child: action);
  }
}
