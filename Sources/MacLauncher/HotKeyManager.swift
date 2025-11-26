import Cocoa
import Carbon

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    // 修改为: Control + Space
    // 虚拟键码 49 是 Space
    // 修饰符 4096 (controlKey)
    
    func registerHotKey() {
        // 1. 定义快捷键 ID
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x53574654) // 'SWFT'
        hotKeyID.id = 1
        
        // 2. 注册快捷键 (Control + Space)
        // cmdKey: 256, shiftKey: 512, alphaLock: 1024, optionKey: 2048, controlKey: 4096
        let modifierFlags: UInt32 = 4096 // Control
        let keyCode: UInt32 = 49 // Space
        
        let status = RegisterEventHotKey(
            keyCode,
            modifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status != noErr {
            print("Failed to register hotkey: \(status)")
            return
        }
        
        // 3. 安装事件处理器
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, _) -> OSStatus in
                Task { @MainActor in
                    HotKeyManager.shared.toggleAppVisibility()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        print("Global Hotkey Registered: Control + Space")
    }
    
    func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
    
    @MainActor
    func toggleAppVisibility() {
        if NSApp.isHidden {
            // 激活并置顶
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            // 确保窗口获得焦点
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless() // 强制显示
            }
        } else {
            // 如果已经在最前，则隐藏；如果不是在最前，则置顶
            if NSApp.isActive {
                NSApp.hide(nil)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
            }
        }
    }
}
