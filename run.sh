#!/bin/bash

# Chrona 快速运行脚本

set -e

echo "🚀 启动 Chrona..."

# 构建并运行
xcodebuild -project Chrona.xcodeproj \
    -scheme Chrona \
    -configuration Debug \
    build

echo "✅ 构建完成！正在启动应用..."

# 打开应用
open ~/Library/Developer/Xcode/DerivedData/Chrona-*/Build/Products/Debug/Chrona.app

echo "🎉 Chrona 已启动！"
