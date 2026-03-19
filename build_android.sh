#!/bin/bash

# 网络电台 App Android 打包脚本
# 使用方法：在有 Flutter 环境的机器上运行此脚本

set -e

echo "🚀 开始构建 Android APK..."

# 进入 Flutter 项目目录
cd "$(dirname "$0")/flutter_app"

# 检查 Flutter 是否安装
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未安装，请先安装 Flutter SDK"
    echo "   https://docs.flutter.dev/get-started/install"
    exit 1
fi

# 获取依赖
echo "📦 获取依赖..."
flutter pub get

# 构建 Release APK
echo "🔨 构建 APK..."
flutter build apk --release

# 输出位置
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

if [ -f "$APK_PATH" ]; then
    echo ""
    echo "✅ 构建成功！"
    echo "📱 APK 位置: $APK_PATH"
    echo "📊 文件大小: $(du -h "$APK_PATH" | cut -f1)"
    echo ""
    echo "💡 安装方法："
    echo "   1. 将 APK 传输到 Android 手机"
    echo "   2. 点击安装（可能需要开启'允许未知来源'）"
else
    echo "❌ 构建失败，请检查错误信息"
    exit 1
fi
