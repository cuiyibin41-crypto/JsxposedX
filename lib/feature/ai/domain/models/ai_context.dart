import 'package:JsxposedX/generated/apk_analysis.g.dart';

/// AI 上下文信息 — 封装当前分析的 APK 基础信息
class AiApkContext {
  final String packageName;
  final String? versionName;
  final int? versionCode;
  final int? minSdk;
  final int? targetSdk;
  final bool? debuggable;
  final bool? allowBackup;
  final List<String> permissions;
  final List<String> exportedActivities;
  final List<String> exportedServices;
  final List<String> exportedReceivers;
  final List<String> exportedProviders;
  final List<String> soFiles;

  const AiApkContext({
    required this.packageName,
    this.versionName,
    this.versionCode,
    this.minSdk,
    this.targetSdk,
    this.debuggable,
    this.allowBackup,
    this.permissions = const [],
    this.exportedActivities = const [],
    this.exportedServices = const [],
    this.exportedReceivers = const [],
    this.exportedProviders = const [],
    this.soFiles = const [],
  });

  /// 从 Pigeon 的 ApkManifest 创建
  factory AiApkContext.fromManifest(ApkManifest m, {List<String> soFiles = const []}) {
    return AiApkContext(
      packageName: m.packageName,
      versionName: m.versionName,
      versionCode: m.versionCode,
      minSdk: m.minSdk,
      targetSdk: m.targetSdk,
      debuggable: m.debuggable,
      allowBackup: m.allowBackup,
      permissions: m.permissions.whereType<String>().toList(),
      exportedActivities: m.activities
          .whereType<ApkComponent>()
          .where((c) => c.exported)
          .map((c) => c.name)
          .toList(),
      exportedServices: m.services
          .whereType<ApkComponent>()
          .where((c) => c.exported)
          .map((c) => c.name)
          .toList(),
      exportedReceivers: m.receivers
          .whereType<ApkComponent>()
          .where((c) => c.exported)
          .map((c) => c.name)
          .toList(),
      exportedProviders: m.providers
          .whereType<ApkComponent>()
          .where((c) => c.exported)
          .map((c) => c.name)
          .toList(),
      soFiles: soFiles,
    );
  }

  /// 仅包名（manifest 还没加载时）
  factory AiApkContext.minimal(String packageName) =>
      AiApkContext(packageName: packageName);

  /// 格式化为 system prompt 文本
  String toPromptText({bool isZh = true}) {
    final b = StringBuffer();

    if (isZh) {
      b.writeln('【目标应用信息】');
      b.writeln('包名: $packageName');
      if (versionName != null) b.writeln('版本: $versionName ($versionCode)');
      if (minSdk != null) b.writeln('SDK: min=$minSdk, target=$targetSdk');
      if (debuggable != null) b.writeln('可调试: ${debuggable! ? "是" : "否"}');
      if (allowBackup != null) b.writeln('允许备份: ${allowBackup! ? "是" : "否"}');

      if (permissions.isNotEmpty) {
        b.writeln('\n权限 (${permissions.length}个):');
        final dangerous = permissions.where(_isDangerousPermission).toList();
        if (dangerous.isNotEmpty) {
          b.writeln('  敏感权限: ${dangerous.map(_shortPermission).join(", ")}');
        }
        final other = permissions.where((p) => !_isDangerousPermission(p)).toList();
        if (other.isNotEmpty) {
          b.writeln('  其他: ${other.length}个');
        }
      }

      _writeExportedComponents(b, '导出的 Activity', exportedActivities);
      _writeExportedComponents(b, '导出的 Service', exportedServices);
      _writeExportedComponents(b, '导出的 Receiver', exportedReceivers);
      _writeExportedComponents(b, '导出的 Provider', exportedProviders);
      
      if (soFiles.isNotEmpty) {
        b.writeln('\nNative 库 (${soFiles.length}个):');
        for (var so in soFiles.take(10)) {
          b.writeln('  - $so');
        }
        if (soFiles.length > 10) {
          b.writeln('  ... +${soFiles.length - 10}');
        }
      }
    } else {
      b.writeln('[Target Application]');
      b.writeln('Package: $packageName');
      if (versionName != null) b.writeln('Version: $versionName ($versionCode)');
      if (minSdk != null) b.writeln('SDK: min=$minSdk, target=$targetSdk');
      if (debuggable != null) b.writeln('Debuggable: ${debuggable! ? "yes" : "no"}');
      if (allowBackup != null) b.writeln('AllowBackup: ${allowBackup! ? "yes" : "no"}');

      if (permissions.isNotEmpty) {
        b.writeln('\nPermissions (${permissions.length}):');
        final dangerous = permissions.where(_isDangerousPermission).toList();
        if (dangerous.isNotEmpty) {
          b.writeln('  Sensitive: ${dangerous.map(_shortPermission).join(", ")}');
        }
      }

      _writeExportedComponents(b, 'Exported Activities', exportedActivities);
      _writeExportedComponents(b, 'Exported Services', exportedServices);
      _writeExportedComponents(b, 'Exported Receivers', exportedReceivers);
      _writeExportedComponents(b, 'Exported Providers', exportedProviders);
      
      if (soFiles.isNotEmpty) {
        b.writeln('\nNative Libraries (${soFiles.length}):');
        for (var so in soFiles.take(10)) {
          b.writeln('  - $so');
        }
        if (soFiles.length > 10) {
          b.writeln('  ... +${soFiles.length - 10}');
        }
      }
    }

    return b.toString();
  }

  void _writeExportedComponents(StringBuffer b, String label, List<String> items) {
    if (items.isEmpty) return;
    b.writeln('\n$label (${items.length}):');
    for (var item in items.take(8)) {
      b.writeln('  - $item');
    }
    if (items.length > 8) {
      b.writeln('  ... +${items.length - 8}');
    }
  }

  static bool _isDangerousPermission(String p) {
    const keywords = [
      'CAMERA', 'LOCATION', 'STORAGE', 'CONTACTS', 'SMS', 'PHONE',
      'MICROPHONE', 'RECORD_AUDIO', 'READ_EXTERNAL', 'WRITE_EXTERNAL',
      'ACCESS_FINE', 'ACCESS_COARSE', 'READ_PHONE', 'SEND_SMS',
    ];
    final upper = p.toUpperCase();
    return keywords.any((k) => upper.contains(k));
  }

  static String _shortPermission(String p) {
    // android.permission.ACCESS_FINE_LOCATION → ACCESS_FINE_LOCATION
    final idx = p.lastIndexOf('.');
    return idx >= 0 ? p.substring(idx + 1) : p;
  }
}
