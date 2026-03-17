# 稀饭课表 编译文档

本文档用于本项目的构建与打包，适用于当前代码结构（Flutter + Rust FFI）。

## 1. 项目现状

1. 桌面平台目录已移除，仅保留：Android、iOS、Web。
2. Android 构建会在 preBuild 阶段自动编译 Rust 动态库。
3. 版本号来源于 [pubspec.yaml](pubspec.yaml) 当前为 0.1.0+1。

## 2. 环境要求

### 2.1 Flutter

1. 安装 Flutter stable。
2. 命令行可执行 flutter、dart。
3. 执行一次：flutter doctor

### 2.2 Android（Windows 可完整构建）

1. 安装 Android Studio（含 Android SDK、platform-tools、build-tools、命令行工具）。
2. 配置好 ANDROID_SDK_ROOT（或在 Android Studio 中已可正常识别）。
3. 至少准备一个模拟器或真机。

### 2.3 Rust（Android 构建必需）

1. 安装 Rust（rustup + cargo）。
2. 安装 cargo-ndk：
   cargo install cargo-ndk
3. 安装 Android 目标：
   rustup target add aarch64-linux-android x86_64-linux-android armv7-linux-androideabi

说明：本项目在 [android/app/build.gradle.kts](android/app/build.gradle.kts) 中通过 preBuild 调用 cargo ndk 编译 native 库。

## 3. 拉取依赖

在项目根目录执行：

flutter pub get

## 4. 调试运行

### 4.1 查看设备

flutter devices

### 4.2 在模拟器运行

flutter run -d emulator-5554

如果你的模拟器 ID 不同，请替换为 flutter devices 输出中的实际 ID。

## 5. Android 打包

### 5.1 通用 Release 包

flutter build apk --release

产物：
[build/app/outputs/flutter-apk/app-release.apk](build/app/outputs/flutter-apk/app-release.apk)

### 5.2 按 ABI 拆分打包

flutter build apk --release --split-per-abi

### 5.3 一键脚本（推荐）

项目根目录提供了脚本 [build_android_split_abi.ps1](build_android_split_abi.ps1)，会按下面顺序执行：

1. flutter pub get
2. 生成应用图标（dart run flutter_launcher_icons）
3. rustup 安装 Android targets
4. cargo ndk 编译 Rust 动态库（armeabi-v7a / arm64-v8a / x86_64）
5. flutter build apk --release --split-per-abi

执行命令：

PowerShell -ExecutionPolicy Bypass -File .\build_android_split_abi.ps1

如果你想跳过图标重生成：

PowerShell -ExecutionPolicy Bypass -File .\build_android_split_abi.ps1 -SkipIcon

产物：

1. [build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk](build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk)
2. [build/app/outputs/flutter-apk/app-arm64-v8a-release.apk](build/app/outputs/flutter-apk/app-arm64-v8a-release.apk)
3. [build/app/outputs/flutter-apk/app-x86_64-release.apk](build/app/outputs/flutter-apk/app-x86_64-release.apk)

## 6. iOS 说明

1. iOS 工程仍保留在 [ios](ios)。
2. iOS 只能在 macOS + Xcode 环境下构建。
3. 在 macOS 上建议执行：
   flutter pub get
   flutter build ios --release

Bundle Identifier 当前在 [ios/Runner.xcodeproj/project.pbxproj](ios/Runner.xcodeproj/project.pbxproj) 中已设置为 com.xifan.kebiao。

## 7. 图标重生成（可选）

项目使用 flutter_launcher_icons，配置在 [pubspec.yaml](pubspec.yaml)。

当你替换图标源文件后执行：

dart run flutter_launcher_icons

然后重新构建 APK 或重新安装应用。

## 8. 常见问题

### 8.1 图标修改后没生效

原因通常是安装了旧 APK。

处理顺序：

1. 重新构建：flutter build apk --release
2. 重新安装：flutter install -d <device-id>
3. 仍异常时，先卸载应用再安装。

### 8.2 Rust 宏出现 frb_expand 警告

该警告通常不阻塞构建。若要清理，可尝试在 native 目录执行：

cargo update -p flutter_rust_bridge_macros

更新后重新构建验证。
