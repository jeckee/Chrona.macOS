#!/bin/bash

# Chrona 构建脚本

set -e

PROJECT="Chrona.xcodeproj"
SCHEME="Chrona"
CONFIGURATION="Release"

echo "🚀 开始构建 Chrona..."

# 检查 Xcode 是否安装
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未找到 xcodebuild。请安装 Xcode。"
    exit 1
fi

# 清理
echo "🧹 清理旧的构建..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" clean

# 构建
echo "🔨 构建应用..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath build \
    build

echo "✅ 构建完成！"
echo "📦 应用位置: build/Build/Products/$CONFIGURATION/Chrona.app"

# 可选：打开应用
read -p "是否运行应用？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "build/Build/Products/$CONFIGURATION/Chrona.app"
fi
