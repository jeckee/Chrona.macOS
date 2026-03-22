# Chrona macOS（SwiftUI）MVP 开发文档（纯前端）

## 0. 目标
做一个你自己先能用的 macOS 应用：
- 配置个人工作时间（可多段）
- 客户端配置 Qwen API Key（qwen3-max）
- 输入任务（轻输入，多行）
- 自动安排当天时间
- 每个任务给简要行动提示
- 一天总结
- 应用常驻菜单栏（右上角图标）
- 提醒（系统通知）

> 纯客户端：无后端、无账号、无同步。

---

## 1. 技术栈与组件
- 平台：macOS
- UI：SwiftUI
- 网络：URLSession（async/await）
- Key 存储：Keychain
- 设置存储：UserDefaults（AppStorage）
- 数据存储：本地 JSON 文件（Application Support）
- 菜单栏常驻：MenuBarExtra（或 NSStatusItem）
- 提醒：UserNotifications（UNUserNotificationCenter）

---

## 2. 页面与交互（最小可用）
### 2.1 主窗口（MainWindow）
布局：左右两栏
- 左：任务输入（多行 TextEditor）+ “添加任务”
- 右：今日计划列表（PlanItem 卡片）
顶部 Toolbar：
- 生成今日计划
- 生成今日总结
- 打开设置

UI 风格要求（“更像 AI 软件”）：
- 背景/卡片使用 Material（ultraThin/regular）
- 生成中状态：loading 动效 + “AI thinking…”
- 计划展示：逐条插入的 stagger 动效（假流式）

### 2.2 设置（Settings）
- 工作时间段：可增删多段（例如 11:00-11:30, 13:00-18:00）
- 提醒：提前 N 分钟（默认 5）
- Qwen API Key：输入/保存（Keychain），显示“已配置/未配置”

### 2.3 菜单栏（Menu Bar）
关闭主窗口后，应用仍运行并显示右上角图标。
点击图标弹出 Popover：
- 今日进度：done/total
- 按钮：生成今日计划 / 生成今日总结 / 打开主窗口
- 快速输入：单行输入，回车添加任务
- 菜单：Settings / Quit

---

## 3. 数据与存储
### 3.1 UserDefaults（设置）
- workingBlocks: ["HH:mm-HH:mm", ...]
- notifyLeadMinutes: Int

### 3.2 Keychain
- qwen_api_key（service: com.chrona.app, account: qwen_api_key）

### 3.3 本地 JSON（Application Support/Chrona）
- tasks.json
- plan-YYYY-MM-DD.json
- summary-YYYY-MM-DD.json

数据结构（概念）：
- Task: id, raw, title, estimateMin?, fixedStart?, fixedEnd?, status(todo/done)
- PlanItem: id, taskId, title, start, end, locked, tips[]
- DaySummary: date, text

---

## 4. 核心流程
### 4.1 输入任务
用户在多行输入框输入（每行一条）→ 保存为 Task（raw 为原文，title 初始等于 raw）

### 4.2 生成今日计划（AI 排程 + 行动提示）
输入：
- 今日日期
- 工作时间段（多段）
- Task 列表（含 fixedStart/fixedEnd 若有）

输出（要求 AI 返回 JSON）：
- plan_items: [{taskId/title,start,end,locked,tips[]}]
- overflow_tasks: [{taskId,reason,suggestion}]

客户端校验：
- 不得超出工作时间段
- 不得重叠
- locked 项不可被移动
校验失败：提示错误并允许重试（把错误原因回传给 AI 让其修复后重排）

落地：
- 保存 plan-YYYY-MM-DD.json
- 重建通知（见 5）

UI：
- 进入 generating 状态
- 拿到结果后逐条插入 plan_items

### 4.3 勾选完成
PlanItem / Task 支持 Done
- 更新本地数据
- 可选：取消该任务后续提醒

### 4.4 生成一天总结
输入：
- 今日 plan_items
- 完成情况（done/undone）
- overflow_tasks（若有）

输出：
- summary 文本（短、可复制）

落地：
- 保存 summary-YYYY-MM-DD.json

---

## 5. 提醒（系统通知）
授权：首次使用提醒功能时请求通知权限。

触发规则（MVP）：
- 生成计划后，为每个 PlanItem 创建通知：
  1) 开始前 notifyLeadMinutes（默认 5 分钟）
  2) 可选：结束前 5 分钟（由设置开关控制）

通知内容：
- 标题：开始任务 / 即将结束
- 正文：任务 title
- 动作按钮（可选，MVP 可先不做动作回调）：打开 Chrona / 延后 15 分钟 / 标记完成

变更规则：
- 当计划重新生成或时间被手动修改：取消旧通知 → 重建新通知

---

## 6. LLM 调用（Qwen3-Max）
- 模型：qwen3-max
- 客户端直连（URLSession）
- Settings 中必须先配置 API Key，否则禁用“生成”按钮并提示

需要 2 个 API 调用：
1) generatePlan：返回 plan_items + tips + overflow_tasks（JSON）
2) generateSummary：返回 summary 文本（可 JSON 也可纯文本）

输出必须“可解析”：
- 优先 JSON
- 解析失败：提示并记录原始响应（本地日志可选）

---

## 7. 完成标准（MVP）
- 可配置工作时间 + Qwen Key
- 可输入任务
- 可生成今日计划（含行动提示）
- 可勾选完成
- 可生成一天总结
- 关闭窗口后菜单栏常驻
- 生成计划后能按时弹系统通知
