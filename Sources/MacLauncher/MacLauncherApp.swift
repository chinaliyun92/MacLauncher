import SwiftUI

// 1. 创建 AppDelegate 来管理菜单栏图标
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // 尝试加载自定义图标 (AppIcon.icns 会被打包到 Resources 目录)
            // 注意：AppIcon.icns 是一个 iconset，NSImage 可以直接加载
            // 但更好的方式是加载一个特定尺寸的 png，或者直接从 Bundle 里的 AppIcon 加载
            
            // 尝试 1: 从 Bundle 加载 AppIcon
            if let appIcon = NSImage(named: "AppIcon") {
                 appIcon.size = NSSize(width: 18, height: 18) // 状态栏图标标准尺寸
                 appIcon.isTemplate = false // 保持原色，不作为模板渲染
                 button.image = appIcon
            } else {
                // 尝试 2: 尝试手动加载打包进去的资源
                // 由于 package.sh 里我们把 AppIcon.icns 拷贝到了 Resources
                if let resourceURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                   let image = NSImage(contentsOf: resourceURL) {
                    image.size = NSSize(width: 18, height: 18)
                    button.image = image
                } else {
                    // 降级方案：使用系统符号
                    button.image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "Launchpad")
                }
            }
        }
        
        setupMenu()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(title: "显示/隐藏", action: #selector(toggleApp), keyEquivalent: " ")
        toggleItem.keyEquivalentModifierMask = .control
        
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(terminateApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func toggleApp() {
        Task { @MainActor in
            HotKeyManager.shared.toggleAppVisibility()
        }
    }
    
    @objc func terminateApp() {
        NSApp.terminate(nil)
    }
}

@main
struct MacLauncherApp: App {
    // 2. 注入 AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 保持对 HotKeyManager 的引用
    private let hotKeyManager = HotKeyManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 自适应全屏
                .background(Color.clear)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willUpdateNotification), perform: { _ in
                    for window in NSApplication.shared.windows {
                        // 防止重复配置
                        if window.styleMask.contains(.fullSizeContentView) && window.isOpaque == false {
                           // 已经配置过的窗口，检查是否需要移除重置逻辑
                           // 这里我们要非常小心，不要在每次 update 时都重置 frame
                           continue
                        }

                        window.standardWindowButton(.zoomButton)?.isHidden = true
                        window.standardWindowButton(.closeButton)?.isHidden = true
                        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                        
                        window.backgroundColor = .clear
                        window.isOpaque = false
                        window.titleVisibility = .hidden
                        window.titlebarAppearsTransparent = true
                        
                        // 关键：允许窗口成为 Key Window，即使它是无边框的
                        if !window.canBecomeKey {
                            // 这一点很难通过 SwiftUI 直接修改，通常需要 NSWindow 子类
                            // 但我们可以尝试通过 collectionBehavior 来辅助
                            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                        }
                        
                        window.styleMask.insert(.fullSizeContentView)
                        // 增加可调整大小的掩码
                        window.styleMask.insert(.resizable)
                        // 允许拖动 (移动窗口)
                        // window.isMovableByWindowBackground = true 
                        // 禁用全局背景拖拽，改为手动实现特定区域拖拽
                        window.isMovableByWindowBackground = false
                        
                        if let screen = window.screen {
                            // 计算屏幕宽高的 80%
                            let screenWidth = screen.frame.width
                            let screenHeight = screen.frame.height
                            let width = screenWidth * 0.8
                            let height = screenHeight * 0.8
                            
                            // 计算居中位置
                            let x = (screenWidth - width) / 2
                            let y = (screenHeight - height) / 2
                            
                            let frame = NSRect(x: x, y: y, width: width, height: height)
                            window.setFrame(frame, display: true)
                        }
                        
                        // 确保窗口层级足够高，覆盖 Dock
                        window.level = .mainMenu + 1
                    }
                })
                .onAppear {
                    // 应用启动时注册全局快捷键
                    hotKeyManager.registerHotKey()
                    
                    // 强制激活应用到前台
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    }
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}
