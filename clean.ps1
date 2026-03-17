Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Remove-IfExists {
    param([string]$Path, [string]$Label)
    if (Test-Path $Path) {
        Write-Host "  删除 $Label" -ForegroundColor DarkGray
        Remove-Item $Path -Recurse -Force
    }
}

Push-Location $ProjectRoot
try {
    Write-Host "`n==> Flutter clean" -ForegroundColor Cyan
    flutter clean

    Write-Host "`n==> 清理 Rust 编译产物" -ForegroundColor Cyan
    Push-Location (Join-Path $ProjectRoot "native")
    try {
        cargo clean
    } finally {
        Pop-Location
    }

    Write-Host "`n==> 清理其他生成目录" -ForegroundColor Cyan
    Remove-IfExists (Join-Path $ProjectRoot "android/app/src/main/jniLibs") "jniLibs"
    Remove-IfExists (Join-Path $ProjectRoot ".dart_tool") ".dart_tool"
    Remove-IfExists (Join-Path $ProjectRoot "pubspec.lock") "pubspec.lock"

    Write-Host "`n清理完成。" -ForegroundColor Green
} finally {
    Pop-Location
}
