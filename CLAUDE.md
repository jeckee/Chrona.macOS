# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Chrona 是一个 macOS 菜单栏常驻的时间管理应用，使用 Qwen AI 进行智能任务排程和总结。

**核心特性**：
- 纯客户端应用（无后端、无账号、无同步）
- 配置个人工作时间段（支持多段）
- AI 自动安排任务并提供行动提示
- 系统通知提醒
- 生成每日总结

## 技术栈

- **平台**：macOS
- **UI 框架**：SwiftUI
- **网络**：URLSession（async/await）
- **敏感数据存储**：Keychain（存储 Qwen API Key）
- **配置存储**：UserDefaults / AppStorage
- **数据存储**：本地 JSON 文件（Application Support/Chrona 目录）
- **菜单栏**：MenuBarExtra 或 NSStatusItem
- **通知**：UserNotifications（UNUserNotificationCenter）

## 架构要点

### 数据存储策略

1. **UserDefaults**（用户设置）：
   - workingBlocks: 工作时间段数组
   - notifyLeadMinutes: 提前提醒分钟数

2. **Keychain**（敏感信息）：
   - service: com.chrona.app
   - account: qwen_api_key

3. **本地 JSON 文件**（Application Support/Chrona）：
   - tasks.json：任务列表
   - plan-YYYY-MM-DD.json：每日计划
   - summary-YYYY-MM-DD.json：每日总结

### 核心数据结构

```swift
// Task: 任务
{
  id, raw, title, estimateMin?, fixedStart?, fixedEnd?, status(todo/done)
}

// PlanItem: 计划项
{
  id, taskId, title, start, end, locked, tips[]
}

// DaySummary: 每日总结
{
  date, text
}
```

### AI 集成（Qwen3-Max）

需要实现两个 API 调用：

1. **generatePlan**：生成今日计划
   - 输入：日期、工作时间段、任务列表
   - 输出：plan_items（含 tips）+ overflow_tasks
   - 必须返回 JSON 格式

2. **generateSummary**：生成每日总结
   - 输入：plan_items、完成情况、overflow_tasks
   - 输出：summary 文本

**重要**：客户端必须校验 AI 返回的计划：
- 不得超出工作时间段
- 不得重叠
- locked 项不可移动
- 校验失败时将错误原因回传给 AI 重新生成

### UI 设计要求

"更像 AI 软件"的视觉风格：
- 使用 Material 背景（ultraThin/regular）
- 生成中显示 loading 动效 + "AI thinking…"
- 计划展示使用逐条插入的 stagger 动效（假流式）

### 通知系统

生成计划后自动创建通知：
1. 每个任务开始前 N 分钟（notifyLeadMinutes）

当计划重新生成或手动修改时间时，必须：取消旧通知 → 重建新通知

## 开发命令

### 构建和运行

使用 Xcode：
```bash
# 打开项目
open Chrona.xcodeproj

# 或使用命令行构建
xcodebuild -project Chrona.xcodeproj -scheme Chrona -configuration Debug build

# 运行
xcodebuild -project Chrona.xcodeproj -scheme Chrona -configuration Debug run
```

使用 xcodebuild：
```bash
# Debug 构建
xcodebuild -project Chrona.xcodeproj -scheme Chrona -configuration Debug build

# Release 构建
xcodebuild -project Chrona.xcodeproj -scheme Chrona -configuration Release build

# 清理
xcodebuild -project Chrona.xcodeproj -scheme Chrona clean
```

### 项目结构

```
Chrona/
├── ChronaApp.swift          # 应用入口
├── AppState.swift           # 全局状态管理
├── Models/
│   └── Models.swift         # 数据模型
├── Managers/
│   ├── KeychainManager.swift      # Keychain 管理
│   ├── FileStorageManager.swift   # 文件存储管理
│   ├── SettingsManager.swift      # 设置管理
│   └── NotificationManager.swift  # 通知管理
├── Services/
│   └── QwenAPIService.swift       # Qwen API 服务
└── Views/
    ├── MainWindow.swift           # 主窗口
    ├── SettingsView.swift         # 设置页面
    ├── MenuBarView.swift          # 菜单栏视图
    └── Components.swift           # UI 组件
```

## 关键实现注意事项

1. **菜单栏常驻**：关闭主窗口后应用继续运行，通过菜单栏图标访问
2. **API Key 管理**：未配置 API Key 时禁用"生成"按钮并提示用户
3. **JSON 解析容错**：AI 返回解析失败时提示用户并记录原始响应
4. **通知权限**：首次使用提醒功能时请求通知权限
5. **多行任务输入**：支持在 TextEditor 中每行输入一个任务
