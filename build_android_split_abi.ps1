Param(
    [switch]$SkipIcon
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$NativeDir = Join-Path $ProjectRoot "native"
$JniLibsOut = Join-Path $ProjectRoot "android/app/src/main/jniLibs"
$LauncherIconSource = Join-Path $ProjectRoot "assets/app_icon_tuned.png"

function Test-RequiredCommand {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "缺少命令: $Name，请先安装并配置到 PATH。"
    }
}

function Invoke-BuildStep {
    param(
        [string]$Title,
        [scriptblock]$Action
    )
    Write-Host "`n==> $Title" -ForegroundColor Cyan
    & $Action
}

Test-RequiredCommand flutter
Test-RequiredCommand dart
Test-RequiredCommand cargo
Test-RequiredCommand rustup

Push-Location $ProjectRoot
try {
    Invoke-BuildStep "拉取 Flutter 依赖" {
        flutter pub get
    }

    if (-not $SkipIcon) {
        if (-not (Test-Path $LauncherIconSource)) {
            throw "未找到图标源文件: assets/app_icon_tuned.png"
        }

        Invoke-BuildStep "生成应用图标资源" {
            dart run flutter_launcher_icons -f pubspec.yaml
        }

        Invoke-BuildStep "校验 Android 图标资源" {
            $iconOutputs = @(
                "android/app/src/main/res/mipmap-mdpi/ic_launcher.png",
                "android/app/src/main/res/mipmap-hdpi/ic_launcher.png",
                "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png",
                "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png",
                "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
            )

            foreach ($rel in $iconOutputs) {
                $path = Join-Path $ProjectRoot $rel
                if (-not (Test-Path $path)) {
                    throw "图标生成失败，缺少文件: $rel"
                }

                $item = Get-Item $path
                if ($item.Length -le 0) {
                    throw "图标文件异常（大小为 0）: $rel"
                }
            }
        }
    } else {
        Write-Host "[WARN] 已跳过图标生成，产物可能沿用旧图标。" -ForegroundColor Yellow
    }

    Invoke-BuildStep "安装 Rust Android targets" {
        rustup target add aarch64-linux-android x86_64-linux-android armv7-linux-androideabi
    }

    Invoke-BuildStep "编译 Rust 动态库到 jniLibs" {
        New-Item -ItemType Directory -Path $JniLibsOut -Force | Out-Null
        Push-Location $NativeDir
        try {
            cargo ndk -t armeabi-v7a -t arm64-v8a -t x86_64 -o $JniLibsOut build --lib --release
        }
        finally {
            Pop-Location
        }
    }

    Invoke-BuildStep "构建 Android split-per-abi release APK" {
        flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64,android-x64
    }

    Invoke-BuildStep "校验产物" {
        $outputs = @(
            "build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk",
            "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk",
            "build/app/outputs/flutter-apk/app-x86_64-release.apk"
        )

        foreach ($rel in $outputs) {
            $path = Join-Path $ProjectRoot $rel
            if (-not (Test-Path $path)) {
                throw "未找到产物: $rel"
            }
            $item = Get-Item $path
            Write-Host ("[OK] {0} ({1} bytes)" -f $rel, $item.Length) -ForegroundColor Green
        }
    }

    Write-Host "`n完成：已生成带最新图标的 split-per-abi APK。" -ForegroundColor Green
}
finally {
    Pop-Location
}
