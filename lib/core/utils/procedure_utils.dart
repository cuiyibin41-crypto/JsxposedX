import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 应用信息工具类
class ProcedureUtils {
  const ProcedureUtils._();

  static PackageInfo? _packageInfo;

  /// 获取应用信息（缓存）
  static Future<PackageInfo> getPackageInfo() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!;
  }

  /// 获取版本号（buildNumber）
  static Future<int> getBuildNumber() async {
    final info = await getPackageInfo();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  /// 获取版本名称
  static Future<String> getVersionName() async {
    final info = await getPackageInfo();
    return info.version;
  }

  static Future<void> openApp(String package) async {
    final packageName = package.trim();
    if (packageName.isEmpty) {
      return;
    }

    await LaunchApp.openApp(
      androidPackageName: packageName,
      openStore: true,
    );
  }
}
