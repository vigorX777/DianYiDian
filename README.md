# 点一点

Mac 菜单栏里的每日次数记录器。当前支持多个次数型场景，默认场景是“喝水”，默认每日目标是 8 次。

## 当前功能

- 菜单栏常驻图标。
- 左键点击图标直接打卡，今日次数加 1。
- 右键点击图标打开菜单。
- 菜单展示事项名称、今日次数和每日目标。
- 右键菜单展示当月水位日期表。
- 菜单支持打卡、撤销、重置、设置和退出。
- 支持单次打卡音效和首次达标音效。
- 支持多个次数型场景，每个场景可设置图标、主题色、启用状态和是否固定到菜单栏。
- 支持当前场景显示和固定场景多图标显示。
- 支持场景轻提醒：不提醒、间隔提醒、固定时间提醒。
- 支持菜单栏打卡动效和首次达标小庆祝。
- 设置窗口和右键浮层采用 Liquid Glass 兼容视觉风格。
- 设置窗口支持开机自启、提示开关、场景名称、每日目标、今日初始次数、图标样式和提醒设置。
- 本地保存当前配置、今日状态和历史记录。
- 跨天时归档前一天历史，并按今日初始次数重置。
- 自绘“进度环 + 小图标”菜单栏图标。

## 开发命令

```bash
swift build
swift run DianYiDianCoreChecks
swift run DianYiDian
```

## 本地打包

当前机器没有完整 Xcode，所以先提供 SwiftPM 本地打包脚本：

```bash
sh Scripts/package-app.sh
```

脚本会生成 `.build/app/点一点.app`。如果要做正式 Archive、签名和分发，需要安装完整 Xcode 后再创建标准 macOS App Archive。

## 正式分发

正式签名、Archive 和导出流程见 `分发流程.md`。当前机器仍是 Command Line Tools 环境，完整 Xcode 工程和 Archive 流程需要安装完整 Xcode 后继续。

## UI 方案

`v0.4.0-Liquid-Glass-UI改造方案.md` 记录了当前玻璃风格改造范围。由于项目仍保持 macOS 14 最低系统版本，当前使用 SwiftUI Material 和 AppKit Popover 做兼容实现，后续再评估迁移到 macOS 26 SDK 的系统级 Liquid Glass API。
