# 稀饭课表 编译指南

本文档说明如何在本地环境中构建 Android 和 iOS 版本的应用程序。

---

## 环境要求

### Flutter

- Flutter SDK 3.x 或更高版本
- 安装后执行 `flutter doctor` 验证环境

### Rust（编译原生库必需）

```bash
# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 安装 Android 目标
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android

# 安装 cargo-ndk
cargo install cargo-ndk
```

### Android

- Android Studio（含 Android SDK）
- JDK 17
- 配置 `ANDROID_SDK_ROOT` 环境变量

### iOS（仅 macOS）

- Xcode 14+
- CocoaPods：`sudo gem install cocoapods`

---

## 拉取依赖

```bash
flutter pub get
```

---

## Android 编译

### 方式一：使用构建脚本（推荐）

Windows PowerShell：

```bash
# 完整构建（含图标重生成）
PowerShell -ExecutionPolicy Bypass -File .\build_android_split_abi.ps1

# 跳过图标重生成
PowerShell -ExecutionPolicy Bypass -File .\build_android_split_abi.ps1 -SkipIcon
```

脚本会自动执行：
1. 安装依赖
2. 生成应用图标
3. 编译 Rust 原生库（armeabi-v7a / arm64-v8a / x86_64）
4. 打包 APK

### 方式二：手动编译

#### 1. 编译 Rust 原生库

```bash
cd native

# 确保已安装 Android NDK
cargo ndk \
  -t armeabi-v7a \
  -t arm64-v8a \
  -t x86_64 \
  -o ../android/app/src/main/jniLibs \
  build --release

cd ..
```

#### 2. 打包 APK

```bash
# 通用 APK（所有架构）
flutter build apk --release

# 按架构拆分 APK（推荐）
flutter build apk --release --split-per-abi

# App Bundle（用于 Google Play）
flutter build appbundle --release
```

### 产物位置

| 类型 | 路径 |
|------|------|
| 通用 APK | `build/app/outputs/flutter-apk/app-release.apk` |
| arm64 APK | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| armv7 APK | `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` |
| x86_64 APK | `build/app/outputs/flutter-apk/app-x86_64-release.apk` |
| App Bundle | `build/app/outputs/bundle/release/app-release.aab` |

### 安装到设备

```bash
# 查看设备列表
flutter devices

# 安装到指定设备
flutter install -d <device-id>

# 或直接运行调试版
flutter run -d <device-id>
```

---

## iOS 编译

> **注意：iOS 编译必须在 macOS 环境下进行。**

### 1. 编译 Rust 原生库

```bash
cd native

# 为真机编译
cargo build --release --target aarch64-apple-ios

# 为模拟器编译（可选）
cargo build --release --target aarch64-apple-ios-sim

cd ..
```

### 2. 安装 iOS 依赖

```bash
cd ios
pod install
cd ..
```

### 3. 打包

```bash
# 无签名构建
flutter build ios --release --no-codesign

# 有签名构建（需在 Xcode 中配置证书）
flutter build ios --release
```

### 4. 使用 Xcode 构建

1. 打开 `ios/Runner.xcworkspace`
2. 选择 Runner 项目
3. 配置签名证书和描述文件
4. 选择目标设备
5. Product → Archive

### 产物位置

- 无签名：`build/ios/iphoneos/Runner.app`
- Archive：Xcode Organizer 中

---

## 图标重生成

项目使用 `flutter_launcher_icons`，配置在 `pubspec.yaml`。

替换图标源文件后执行：

```bash
dart run flutter_launcher_icons
```

然后重新构建应用。

---

## GitHub Actions 自动构建

项目包含 GitHub Actions 工作流，支持自动构建：

- 推送 `v*` 标签时触发
- 手动触发：GitHub Actions 页面点击 "Run workflow"

产物：
- Android APK 和 AAB
- iOS 无签名构建

---

## 常见问题

### Rust 编译失败

确保已安装正确的 NDK 版本和 Rust 目标：

```bash
# 检查 NDK 路径
echo $ANDROID_NDK_HOME

# 重新安装 Rust 目标
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
```

### iOS CocoaPods 错误

```bash
cd ios
pod deintegrate
pod install
cd ..
```

### 图标修改后未生效

1. 重新构建：`flutter build apk --release`
2. 卸载旧版本后安装：`flutter install`
