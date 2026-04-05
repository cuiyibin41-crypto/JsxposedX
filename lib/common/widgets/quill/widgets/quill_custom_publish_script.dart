import 'dart:convert';
import 'dart:developer' as developer;

import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/common/widgets/custom_dIalog.dart';
import 'package:JsxposedX/common/widgets/custom_text_field.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/core/routes/routes/home_route.dart';
import 'package:JsxposedX/features/frida/presentation/providers/frida_action_provider.dart';
import 'package:JsxposedX/features/frida/presentation/providers/frida_query_provider.dart';
import 'package:JsxposedX/features/project/presentation/providers/project_query_provider.dart';
import 'package:JsxposedX/features/xposed/presentation/providers/xposed_action_provider.dart';
import 'package:JsxposedX/features/xposed/presentation/providers/xposed_query_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class QuillCustomPublishScript extends quill.EmbedBuilder {
  @override
  String get key => 'publish_script';

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final Map<String, dynamic> data = jsonDecode(embedContext.node.value.data);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _PublishScriptCard(data: data),
    );
  }
}

class _PublishScriptCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;

  const _PublishScriptCard({required this.data});

  @override
  ConsumerState<_PublishScriptCard> createState() => _PublishScriptCardState();
}

class _PublishScriptCardState extends ConsumerState<_PublishScriptCard> {
  bool _copied = false;

  String get _title => widget.data['title']?.toString() ?? '发布脚本';

  String get _targetName => widget.data['targetName']?.toString() ?? '';

  String get _packageName => widget.data['packageName']?.toString() ?? '';

  String get _description => widget.data['description']?.toString() ?? '';

  String get _scriptType =>
      widget.data['scriptType']?.toString() ?? 'xposed_js';

  String get _script => widget.data['script']?.toString() ?? '';

  bool get _isXposedScript => _scriptType == 'xposed_js';

  bool get _isFridaScript => _scriptType == 'frida_js';

  bool get _isSupportedScriptType => _isXposedScript || _isFridaScript;

  Future<void> _copyScript() async {
    await Clipboard.setData(ClipboardData(text: _script));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  String? _validateImportData() {
    if (_script.trim().isEmpty) {
      return '脚本内容为空，无法导入';
    }
    if (_packageName.trim().isEmpty) {
      return '目标包名为空，无法导入';
    }
    if (!_isSupportedScriptType) {
      return '暂不支持该脚本类型导入';
    }
    return null;
  }

  String _sanitizeFileName(String value) {
    return value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'[\r\n\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _defaultFileName() {
    final sanitized = _sanitizeFileName(_title);
    if (sanitized.isNotEmpty) {
      return sanitized;
    }
    return 'script_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _normalizeScriptFileName(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) {
      return '';
    }
    return name.endsWith('.js') ? name : '$name.js';
  }

  String _normalizeXposedFileName(String rawName) {
    final fileName = _normalizeScriptFileName(rawName);
    if (fileName.startsWith('[traditional]')) {
      return fileName;
    }
    return '[traditional]$fileName';
  }

  bool _isReservedXposedName(String rawName) {
    final normalized = _normalizeScriptFileName(rawName).toLowerCase();
    final stripped = normalized.startsWith('[traditional]')
        ? normalized.substring('[traditional]'.length)
        : normalized;
    return stripped == 'hook' || stripped == 'hook.js';
  }

  Future<void> _showImportDialog() async {
    final nameController = TextEditingController(text: _defaultFileName());
    await CustomDialog.show(
      title: Text(context.l10n.importScript),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '文件名',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          CustomTextField(
            controller: nameController,
            hintText: 'script_name.js',
          ),
        ],
      ),
      actionButtons: [
        TextButton(
          onPressed: SmartDialog.dismiss,
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            final rawName = nameController.text.trim();
            if (rawName.isEmpty) {
              ToastMessage.show(context.l10n.projectNameEmpty);
              return;
            }
            if (_isXposedScript && _isReservedXposedName(rawName)) {
              ToastMessage.show(context.l10n.reservedScriptFileName);
              return;
            }

            final fileName = _isXposedScript
                ? _normalizeXposedFileName(rawName)
                : _normalizeScriptFileName(rawName);

            try {
              if (_isFridaScript) {
                await ref.read(
                  createFridaScriptProvider(
                    packageName: _packageName,
                    localPath: fileName,
                    content: _script,
                  ).future,
                );
                ref.invalidate(fridaScriptsProvider(packageName: _packageName));
              } else {
                await ref.read(
                  createJsScriptProvider(
                    packageName: _packageName,
                    localPath: fileName,
                    content: _script,
                  ).future,
                );
                ref.invalidate(jsScriptsProvider(packageName: _packageName));
              }

              if (!mounted) {
                return;
              }
              SmartDialog.dismiss();
              ToastMessage.show(
                context.l10n.aiScriptSavedTo(
                  _isFridaScript
                      ? context.l10n.fridaProject
                      : context.l10n.xposedProject,
                  fileName,
                ),
              );
              context.push(
                _isFridaScript
                    ? HomeRoute.toFridaProject(packageName: _packageName)
                    : HomeRoute.toXposedProject(packageName: _packageName),
              );
            } catch (error) {
              if (!mounted) {
                return;
              }
              ToastMessage.show(
                context.l10n.aiScriptSaveFailed(error.toString()),
              );
            }
          },
          child: Text(context.l10n.importScript),
        ),
      ],
    );
    nameController.dispose();
  }

  Future<void> _handleImportScript() async {
    final validationMessage = _validateImportData();
    if (validationMessage != null) {
      developer.log(validationMessage);
      ToastMessage.show(validationMessage);
      return;
    }

    try {
      final exists = await ref.read(
        projectExistsProvider(packageName: _packageName).future,
      );
      if (!exists) {
        if (!mounted) {
          return;
        }
        ToastMessage.show('本地没有该项目，请先创建对应项目');
        return;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ToastMessage.show(error.toString());
      return;
    }

    if (!mounted) {
      return;
    }
    await _showImportDialog();
  }

  Color _scriptTypeColor(ColorScheme colorScheme) {
    switch (_scriptType) {
      case 'frida_js':
        return Colors.green;
      case 'xposed_js':
      default:
        return colorScheme.primary;
    }
  }

  String _scriptTypeLabel() {
    switch (_scriptType) {
      case 'frida_js':
        return 'Frida JS';
      case 'xposed_js':
      default:
        return 'Xposed JS';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = _scriptTypeColor(colorScheme);
    final isDark = theme.brightness == Brightness.dark;
    final cardBackground = Color.alphaBlend(
      accentColor.withValues(alpha: isDark ? 0.10 : 0.06),
      colorScheme.surface,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
        color: cardBackground,
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.10 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.95),
                        accentColor.withValues(alpha: 0.72),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.code, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'jsxposedx脚本',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            label: _scriptTypeLabel(),
                            color: accentColor,
                          ),
                          _InfoChip(
                            label: _targetName,
                            color: colorScheme.secondary,
                            icon: Icons.apps_rounded,
                          ),
                          _InfoChip(
                            label: _packageName,
                            color: Colors.teal,
                            icon: Icons.inventory_2_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _CodePanel(
              title: 'JS 脚本',
              accentColor: accentColor,
              actions: [
                _PanelAction(
                  label: context.l10n.importScript,
                  icon: Icons.download_rounded,
                  color: accentColor,
                  onTap: _handleImportScript,
                ),
                _PanelAction(
                  label: _copied ? '已复制' : '复制脚本',
                  icon: _copied ? Icons.check : Icons.copy_all_rounded,
                  color: _copied ? Colors.green : accentColor,
                  onTap: _copyScript,
                ),
              ],
              child: SelectableText(
                _script,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFFD7DBE0),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _InfoChip(
              color: Colors.red,
              label: "在JsxposedX中你可以直接导入此脚本,也可以通过收藏该帖子让它更方便被找到",
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _InfoChip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopDots extends StatelessWidget {
  final Color accentColor;

  const _TopDots({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(accentColor.withValues(alpha: 0.95)),
        const SizedBox(width: 6),
        _dot(accentColor.withValues(alpha: 0.55)),
        const SizedBox(width: 6),
        _dot(accentColor.withValues(alpha: 0.3)),
      ],
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CodePanel extends StatelessWidget {
  final String title;
  final Widget child;
  final Color accentColor;
  final List<Widget>? actions;

  const _CodePanel({
    required this.title,
    required this.child,
    required this.accentColor,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final panelColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF11161E)
        : const Color(0xFF18202A);

    return Container(
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              children: [
                _TopDots(accentColor: accentColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x1AFFFFFF)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PanelAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
