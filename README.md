# CWNU Timetable Demo

Flutter 课表项目（端侧 Rust FFI 抓取课表，无需独立后端服务）。

编译与打包说明见 [BUILD.md](BUILD.md)。

## 项目结构

- `lib/main.dart`：Flutter 启动入口
- `lib/pages/`：页面层（启动页、登录页、课表页）
- `lib/services/`：接口与本地存储
- `lib/models/`：数据模型

## 运行 App（推荐）

应用在手机端本地完成统一认证登录与课表抓取，无需 Python 服务。

```bash
flutter pub get
flutter run -d emulator-5556
```

## 使用说明

- 首次登录成功后会保存账号、密码。
- 之后每次进入应用会自动登录并自动刷新课表。
- 课表页右上角支持手动刷新和退出登录。
- 课表会本地缓存，启动时优先显示旧数据，再后台刷新。

## 打包 APK

```bash
flutter build apk --release
```

产物位置：

- `build/app/outputs/flutter-apk/app-release.apk`
