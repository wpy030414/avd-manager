# AGENTS.md — AVD Manager 协作约定

原生 macOS AVD 管理器。Swift 6.4 + SwiftUI + SwiftPM，面向 macOS 27 Liquid Glass 2。
包名 `im.xrl.avd_manager`，作者：杏仁鹿。

## 构建命令

> ⚠️ SwiftUI 宏（`@State`、`@StateObject`、`#Preview`）需要 Xcode 的宏插件，**必须用 Xcode-beta**（`/Applications/Xcode-beta.app`）编译，不能用 CommandLineTools。

```bash
# 必须在 AVDManager/ 子目录下构建（SwiftPM 包根目录）
cd AVDManager

# 调试构建
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build

# 打包 .app（release + ad-hoc 签名）
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./scripts/bundle-app.sh

# 启动打包好的 app
open /Users/xrl/Documents/Repos/avd-manager/AVDManager/AVDManager.app
```

## 目录结构

```
AVDManager/
├── Package.swift
├── Sources/
│   ├── AVDManagerKit/                  # 库 target（宏需要）
│   │   ├── Models/                     # AVD、EmulatorState、SystemImage 等数据模型
│   │   ├── Services/                   # AndroidSDK、AVDService、EmulatorService、SystemImageService
│   │   ├── ViewModels/                 # AVDManagerViewModel（@MainActor 串联服务层）
│   │   ├── Views/                      # ContentView、AVDDetailView、LogPanelView、各 Sheet
│   │   ├── Design/                     # DesignTokens、FluidAmbientBackground
│   │   └── Utils/                      # DebugLog、LogStore、Process+Async
│   └── AVDManagerCLI/                  # 可执行 target（薄包装）
│       ├── AVDManagerApp.swift         # @main 入口 + AppDelegate
│       └── Debug/DebugEmulator.swift   # 独立调试工具（不打包进 app）
├── Resources/                          # Info.plist、Assets.xcassets、en.lproj、zh-Hans.lproj
└── scripts/bundle-app.sh               # 打包 .app + ad-hoc 签名
```

## 架构要点

- **target 分离**：SwiftUI 库放进 `AVDManagerKit`（得益于宏插件），可执行入口放在 `AVDManagerCLI`。新增业务代码放 `AVDManagerKit`，一般不用改 `AVDManagerCLI`。
- **条目唯一入口**：`AVDManagerApp.swift` 的 `AppDelegate` 持有 `@MainActor let viewModel: AVDManagerViewModel`，通过 `.environmentObject` 注入。
- **视图层级**：`ContentView` 用 `HSplitView`，左 sidebar（固定 270pt）+ 右 `rightPane`（`AVDDetailView` + `LogPanelView`）。
- **服务层**：`AndroidSDK.shared`（actor）封装检测/安装；`AVDService`、`EmulatorService`、`SystemImageService` 封装命令行；`AVDManagerViewModel` 串联全部服务。
- **状态流转**：`EmulatorState`（stopped / booting / running / stopping / error），5 秒轮询 `refreshStates`。

## 编码规范

- **并发**：target 开启 `StrictConcurrency`。UI 与 `@MainActor` 的 `AVDManagerViewModel` 交互；服务是 `actor`。跨隔离调用用 `Task { @MainActor in ... }` 派回主线。
- **日志**：
  - 调试用 `DebugLog.log()` 写 `/tmp/avdmanager-debug.log`。
  - UI 日志用 `LogStore`（`@MainActor ObservableObject`），按 AVD id 分 store（`logStore(for:)`），退出即丢。
- **本地化**：UI 文案走 `NSLocalizedString`，维护 `Resources/{en,zh-Hans}.lproj/Localizable.strings`。新增按钮/文案必须加 key，中英双写。
- **不可加 warnings**：`AVDManager` 的 debug 配置开了 `-warnings-as-errors`，提交前确保零警告。

## 关键尺寸 / 外观

- sidebar 固定宽度 **270pt**（`min 240 / ideal 270 / max 360`）。
- toolbar 右侧两组：操作按钮（环境/下载/创建/刷新）+ 外观切换 + 日志显示/隐藏。
- 外观/日志切换按钮用圆形 `.glassEffect`，其余 toolbar 按钮仅 hover 才显示 material。
- 详情卡 `maxHeight: 360`，之下 `LogPanelView` 占满剩余空间。

## 调试提示

- 模拟器输出会实时流式写入当前 AVD 的日志面板（`EmulatorService.start` 的 `onLog` 回调经 `Pipe` 读取 stdout/stderr）。
- `DebugEmulator` 是独立 CLI 工具，可直接跑状态检测/启动/停止流程。手动启动的模拟器日志落 `/tmp/avdmanager-emu-err.log`。
