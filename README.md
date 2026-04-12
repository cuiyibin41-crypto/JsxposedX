# JsxposedX

- Frida module: [`jsxposedx-frida`](https://github.com/dugongzi/jsxposedx-frida)
- English: [`README_EN.md`](README_EN.md)
- 中文：[`README_CN.md`](README_CN.md)
- Release：[`Download`](https://jsxposed.org)
- 沐雪AI中转站[`前往`](https://api.muxueai.pro)
JsxposedX is a Flutter Android application for Xposed/LSPosed and Frida workflows.

## Summary

- Flutter UI with Android-side Xposed hooks, LSPosed service integration, and native bridge modules
- Project entries for `Quick Functions`, `AI Reverse`, `Xposed Project`, and `Frida Project`
- Additional pages for crypto audit and SO analysis
- Pigeon code generation via `.buildScript/pigen_watch.ps1`
- Debug install flow via `.buildScript/run_install_debug.ps1`
- Shared run configurations in `.idea/runConfigurations/`: `watch_pigeons` and `build_for_xposed_type`
## Build Note

This repository is not a normal Flutter-only app. Device-side verification also involves the Android/Xposed side, so the repository includes shared PowerShell scripts and shared IDE run configurations.

The Android module now uses two thin Xposed shells:

- `android/app/src/api100/` for the legacy `api100` shell
- `android/app/src/api101/` for the modern `api101` shell
- `android/app/src/main/` for shared Flutter/UI and hook core code

Default debug tasks still point to `api100`:

```powershell
.\.buildScript\run_install_debug.ps1
```

Install the `api101` shell explicitly with:

```powershell
.\.buildScript\run_install_debug.ps1 -GradleTask :app:installApi101Debug
```

Build/release note:

- `flutter build appbundle --flavor api100 --release` goes through the Flutter CLI first, then calls the matching Android variant
- `flutter build apk --flavor api101 --release` builds the corresponding release APK, for example `build/app/outputs/flutter-apk/app-api101-release.apk`
- `.\gradlew.bat :app:bundleApi100Release` goes directly through Android Gradle
- `.\gradlew.bat :app:assembleApi101Release` goes directly through Android Gradle for the matching release APK
- for the same flavor, both commands target the same Android release variant output
