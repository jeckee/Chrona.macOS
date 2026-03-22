# Chrona macOS

一个智能时间管理 macOS 应用，使用 Qwen AI 进行任务排程和总结。

## 功能特性

- ✅ 配置个人工作时间段（支持多段）
- ✅ 输入任务（支持多行输入）
- ✅ AI 自动安排当天时间
- ✅ 每个任务提供简要行动提示
- ✅ 生成每日总结
- ✅ 菜单栏常驻
- ✅ 系统通知提醒

## 技术栈

- SwiftUI
- macOS 13.0+
- Qwen API (qwen-max)

## 构建和运行

### 使用 Xcode

1. 打开 `Chrona.xcodeproj`
2. 选择目标设备为 "My Mac"
3. 点击运行按钮（⌘R）

### 使用命令行

```bash
# 快速运行（推荐）
./run.sh

# 或手动构建
xcodebuild -project Chrona.xcodeproj -scheme Chrona -configuration Debug build

# 运行构建好的应用
open ~/Library/Developer/Xcode/DerivedData/Chrona-*/Build/Products/Debug/Chrona.app

# Release 构建
xcodebuild -project Chrona.xcodeproj -scheme Chrona -configuration Release build
```

## 配置

首次运行时，需要在设置中配置：

1. Qwen API Key（必需）
2. 工作时间段（默认：09:00-12:00, 14:00-18:00）
3. 默认任务时长（默认：30 分钟）
4. 提醒设置（默认：提前 5 分钟）

## 使用说明

1. 在左侧输入框中输入任务（每行一个）
2. 点击"添加任务"
3. 点击"生成今日计划"，AI 会自动安排时间并提供行动提示
4. 完成任务后可以勾选标记
5. 一天结束时点击"生成今日总结"

## 数据存储

- 设置：UserDefaults
- API Key：Keychain
- 任务和计划：`~/Library/Application Support/Chrona/`

## 许可证

Copyright © 2024. All rights reserved.
