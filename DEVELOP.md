# 开发文档

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

## 🛠️ 开发环境

- Swift 5.9+
- macOS 14.0+
- Swift Package Manager

## 🏃 本地运行

### 方式一：使用 Swift Package Manager

```bash
# 编译
swift build

# 运行
swift run
```

### 方式二：一键打包

```bash
chmod +x package.sh && ./package.sh
```

生成的 `MacLauncher.app` 位于项目根目录。

### 方式三：使用 Xcode

```bash
# 生成 Xcode 项目
swift package generate-xcodeproj

# 打开项目
open MacLauncher.xcodeproj
```

## 🔧 打包流程

`package.sh` 脚本会执行以下步骤：

1. 编译 Release 版本
2. 创建 App Bundle 结构
3. 生成应用图标（如果有 `AppIcon.png`）
4. 创建 `Info.plist`
5. 进行 Ad-hoc 签名
6. 输出 `MacLauncher.app`

## 📦 发布流程

### 自动发布（GitHub Actions）

1. 创建并推送 tag：
   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

2. GitHub Actions 会自动构建并发布到 Release 页面

详细说明请参考 [RELEASE.md](RELEASE.md)

## 🎨 添加应用图标

1. 准备 1024x1024 的 PNG 图片
2. 保存为 `AppIcon.png` 放在项目根目录
3. 运行打包脚本会自动生成 `.icns` 图标文件

## 🔑 技术要点

- **全局快捷键**：使用 Carbon API (`RegisterEventHotKey`)
- **应用扫描**：使用 `FileManager.enumerator` 递归扫描 `/Applications`
- **开机自启**：使用 `SMAppService` API
- **UI 框架**：SwiftUI

## 📝 TODO

- [ ] 键盘方向键导航
- [ ] 文件夹内搜索
- [ ] 自定义快捷键
- [ ] 主题切换

## 📄 许可证

MIT License


