# 点一点

Mac 菜单栏里的每日次数记录器。MVP 当前只支持一个次数型事项，默认事项是“喝水”，默认每日目标是 8 次。

## 当前功能

- 菜单栏常驻图标。
- 左键点击图标直接打卡，今日次数加 1。
- 右键点击图标打开菜单。
- 菜单展示事项名称、今日次数和每日目标。
- 菜单支持打卡、撤销、重置、设置和退出。
- 设置窗口支持开机自启、提示开关、事项名称、每日目标、今日初始次数和图标样式。
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
