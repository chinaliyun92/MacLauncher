import SwiftUI
import AppKit

struct WindowDragGesture: Gesture {
    var body: some Gesture {
        DragGesture()
            .onChanged { value in
                if let window = NSApp.windows.first {
                    let currentFrame = window.frame
                    // 计算新的原点
                    // 注意：macOS 的坐标系 Y 轴是向上的，但 NSEvent 的 delta 是常规的
                    // SwiftUI 的 DragGesture translation 是相对于手势开始时的偏移量
                    
                    // 我们不能直接使用 translation，因为窗口移动后，手势的参考系也会变（如果是相对 view 的）
                    // 但实际上，最简单的做法是直接调用 window.performDrag
                    // 可是 performDrag 只能在 mouseDown 事件中调用。
                    
                    // 更好的方法是：
                    // 在 View 中捕获 mouseDown 事件，并调用 window.performDrag(with: event)
                }
            }
    }
}

// 重新实现：使用 NSViewRepresentable 包装一个可拖拽的 NSView
struct DraggableArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView {
        return DragView()
    }
    
    func updateNSView(_ nsView: DragView, context: Context) {}
    
    class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool {
            return true
        }
    }
}

