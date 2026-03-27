import 'package:JsxposedX/common/pages/toast.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/core/themes/app_colors.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:storage_space/storage_space.dart';

class InfoCard extends HookWidget {
  const InfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final infos = useState<List<Map<String, dynamic>>>([]);
    useEffect(() {
      Future.microtask(() async {
        final deviceInfo = DeviceInfoPlugin();
        final packageInfo = await PackageInfo.fromPlatform();
        final androidInfo = await deviceInfo.androidInfo;
        if (!context.mounted) return;
        String storageInfo =
            "${context.l10n.totalStorage} -- G (-- G ${context.l10n.available})";
        try {
          final space = await getStorageSpace(
            lowOnSpaceThreshold: 100 * 1024 * 1024,
            fractionDigits: 0,
          );
          if (!context.mounted) return;
          storageInfo =
              "${context.l10n.totalStorage} ${space.totalSize} (${space.freeSize} ${context.l10n.available})";
        } catch (e) {
          // Fallback if plugin fails
        }

        infos.value = [
          {
            "title": context.l10n.systemVersion,
            "content": "Android:${androidInfo.version.release}",
          },
          {
            "title": context.l10n.sdkVersion,
            "content":
                "${androidInfo.version.sdkInt} (API ${androidInfo.version.sdkInt})",
          },
          {
            "title": context.l10n.deviceModel,
            "content": "${androidInfo.manufacturer} ${androidInfo.model}",
          },
          {"title": context.l10n.systemStorage, "content": storageInfo},
          {
            "title": context.l10n.cpuArchitecture,
            "content": "CPU: ${androidInfo.supportedAbis.first}",
          },
          {
            "title": context.l10n.frameworkPackageName,
            "content": packageInfo.packageName,
          },
        ];
      });

      return null;
    }, []);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.w,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.14 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ...infos.value.asMap().entries.map((entry) {
            final info = entry.value;
            return Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 2.h,
                  ),
                  minVerticalPadding: 10.h,
                  title: Text(
                    info["title"],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.sp,
                    ),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      info["content"],
                      style: TextStyle(
                        fontSize: 12.sp,
                        height: 1.45,
                        color: context.isDark
                            ? Colors.white70
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

              ],
            );
          }),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 10.h),
                child: TextButton(
                  onPressed: () {
                    final text = infos.value
                        .map((e) => "${e["title"]}: ${e["content"]}")
                        .join("\n");
                    Clipboard.setData(ClipboardData(text: text));
                    ToastMessage.show(context.l10n.success);
                  },
                  child: Text(context.l10n.copy),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
