# Mac Launcher (MVP)

macOS 26 居然把启动台去掉了？不用担心，这是一个用 Swift 和 SwiftUI 编写的轻量级替代品。

## ✨ 功能

- 🚀 **极速启动**：基于本地缓存秒开，后台自动静默扫描新应用。
- ⌨️ **全局快捷键**：默认使用 `Control + Space` 快速唤起/隐藏。
- 📂 **文件夹支持**：拖拽合并成组，点击平滑展开，支持重命名和解散分组。
- 👆 **拖拽重排**：自由拖拽应用图标调整顺序。
- 🔍 **快速搜索**：顶部搜索栏支持实时过滤应用。
- 🎨 **高度定制**：可设置背景颜色、透明度，完美适配任何壁纸。
- 🖥️ **沉浸体验**：自动全屏，无边框设计，支持 ESC 键快捷关闭。
- 🤖 **开机自启**：支持随系统自动启动。

## 🛠️ 如何运行

本项目使用 Swift Package Manager 管理，无需复杂的 Xcode 工程文件。

### 方式一：一键打包 (推荐)

在终端中执行以下命令，会自动编译并生成 `MacLauncher.app`：

```bash
chmod +x package.sh && ./package.sh
```

生成的 App 会自动隐藏 Dock 图标，作为后台 Agent 运行。

### 方式二：使用 Xcode 开发

1. 在终端中生成 Xcode 项目文件：
   ```bash
   swift package generate-xcodeproj
   ```
2. 打开生成的 `MacLauncher.xcodeproj`。
3. 点击 Run 运行。

## 📋 项目结构

```
Sources/
  MacLauncher/
    ├── AppItem.swift            # 数据模型 (支持 Codable)
    ├── HotKeyManager.swift      # 全局快捷键管理 (Carbon API)
    ├── LaunchpadViewModel.swift # 业务逻辑 (扫描、排序、分组)
    ├── ContentView.swift        # UI 主视图 (网格、文件夹、手势)
    ├── SettingsView.swift       # 设置面板
    └── MacLauncherApp.swift     # 程序入口
Package.swift                    # 包依赖定义
package.sh                       # 自动打包脚本
```

## 📝 快捷键说明

| 快捷键 | 功能 |
| --- | --- |
| `Control + Space` | 全局唤起/隐藏启动台 |
| `ESC` | 关闭当前文件夹 / 隐藏启动台 |
| `Cmd + Q` | 强制退出应用 |
| `Cmd + W` | 隐藏应用窗口 |

## ⚠️ 注意事项

- 首次运行时，macOS 可能会提示“权限验证”或询问是否允许访问应用程序文件夹，请点击“允许”或“打开”。
- 由于使用了 Carbon API 注册全局快捷键，请确保没有其他 App 占用 `Control + Space` (系统默认是输入法切换，可能需要调整)。

## 📝 开发状态

- [x] 自动扫描应用
- [x] 拖拽排序
- [x] 文件夹创建/解散/重命名
- [x] 全局快捷键唤起
- [x] 隐藏 Dock 图标
- [x] 开机自启动
- [x] UI 自定义 (背景/透明度)
- [ ] 键盘方向键导航 (待排期)
