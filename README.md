# AVD Manager

一款原生 macOS 上的 Android 虚拟设备（AVD）管理器，为 macOS 27 Liquid Glass 2 视觉风格打造。

![platform](https://img.shields.io/badge/macOS-27+-black.svg) ![language](https://img.shields.io/badge/Swift-6.4-orange.svg) ![ui](https://img.shields.io/badge/SwiftUI-Liquid%20Glass-blue.svg)

## 功能

- 📱 **AVD 列表**：自动检测 `~/.android/avd` 下的全部 AVD，实时显示 stopped / booting / running / stopping / error 状态。
- ▶️ **启动 / 停止**：一键启停，自动分配控制台端口并等待 `sys.boot_completed`。
- ➕ **创建 / 删除 / 重命名**：内置向导创建 AVD，支持删除与重命名。
- 🖼️ **系统镜像管理**：从 `sdkmanager` 拉取可用镜像列表，支持下载安装与卸载。
- 🔧 **环境管理**：自动检测 Android SDK / Java / adb / emulator，并一键安装缺失依赖。
- 📜 **模拟器日志**：每个 AVD 拥有独立日志区，实时流式捕获模拟器 stdout/stderr，切换 AVD 视图时保留各自的记录。
- 🎨 **外观切换**：跟随系统 / 浅色 / 深色三态切换。
- 🌐 **中英双语**：界面文案完整本地化。

## 系统要求

- macOS 27 或更高
- Xcode-beta（编译 SwiftUI 宏必需）
- Android SDK（App 支持 Homebrew / Android Studio 路径自动发现，无需手动配置）

## 构建与运行

```bash
cd AVDManager

# 调试构建
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build

# 打包 .app（release + ad-hoc 签名）
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/bundle-app.sh

# 启动
open /Users/xrl/Documents/Repos/avd-manager/AVDManager/AVDManager.app
```

> 直接用 `swift build` 而**不**设置 `DEVELOPER_DIR` 会失败——SwiftUI 的 Property Wrapper 宏需要 Xcode-beta 的宏插件，CommandLineTools 不含该组件。

## 项目结构

```
AVDManager/
├── Package.swift
├── Sources/
│   ├── AVDManagerKit/                  # SwiftUI 业务库
│   │   ├── Models/                     # AVD、EmulatorState、SystemImage 等
│   │   ├── Services/                   # AndroidSDK、AVDService、EmulatorService、SystemImageService
│   │   ├── ViewModels/                 # AVDManagerViewModel（@MainActor 中枢）
│   │   ├── Views/                      # ContentView、AVDDetailView、LogPanelView、各 Sheet
│   │   ├── Design/                     # DesignTokens、FluidAmbientBackground
│   │   └── Utils/                      # DebugLog、LogStore、ProcessRunner
│   └── AVDManagerCLI/                  # @main 入口薄包装
│       └── Debug/DebugEmulator.swift   # 独立调试工具
├── Resources/                          # Info.plist、Assets、本地化字符串
└── scripts/bundle-app.sh               # 打包脚本
```

采用 **库 + 可执行薄包装** 的双 target 结构：SwiftUI 源码置于 `AVDManagerKit`，仅 `@main` 入口放在 `AVDManagerCLI`。此结构让 SwiftPM 能在 Xcode-beta 的宏插件下编译 `@State` 等宏。

## 架构简述

- **UI 层**：纯 SwiftUI。`ContentView` 用 `HSplitView` 划分固定宽度的左侧 AVD 列表与右侧详情/日志区。
- **视图模型层**：`AVDManagerViewModel`（`@MainActor`、`ObservableObject`）串联全部服务并驱动 UI 状态；每 5 秒轮询模拟器状态。
- **服务层**：`AndroidSDK`（actor）负责 SDK/Java 检测与依赖安装；`AVDService`、`EmulatorService`、`SystemImageService` 封装 `avdmanager` / `emulator` / `adb` / `sdkmanager` 的真实命令行调用。
- **并发**：target 开启 `StrictConcurrency`；服务为 `actor`，跨隔离交互统一经 `Task { @MainActor in }` 回到主线。

## 调试

- App 运行期调试日志：`/tmp/avdmanager-debug.log`
- 模拟器 stderr（外部启动时）：`/tmp/avdmanager-emu-err.log`
- `DebugEmulator`：独立 CLI 工具，可单独运行以验证模拟器状态检测与启停流程。

## 致谢

© 2021-Present 杏仁鹿. All rights reserved.
