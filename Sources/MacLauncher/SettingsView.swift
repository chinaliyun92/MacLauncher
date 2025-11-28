import SwiftUI
import ServiceManagement
import AppKit

struct SettingsView: View {
    @Binding var isPresented: Bool
    @Binding var launchAtLogin: Bool // 从父视图接收状态，而不是本地 State
    
    @AppStorage("customBackgroundColor") private var customBackgroundColor: String = "1,1,1" // RGB string (Default White)
    @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 0.3
    
    // 内部状态，用于立即显示 Toggle
    @State private var isCheckingStatus = false
    
    // 预设颜色选项
    private let presetColors: [Color] = [
        .white,
        .black,
        Color(white: 0.3), // 深灰
        .red,
        .orange,
        .yellow,
        .green,
        .mint,
        .blue,
        .indigo,
        .purple
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("偏好设置")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color.black.opacity(0.05))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // General Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("通用")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        LaunchAtLoginToggleView(
                            isOn: $launchAtLogin,
                            isCheckingStatus: $isCheckingStatus,
                            onToggle: { enabled in
                                updateLaunchAtLogin(enabled: enabled)
                            }
                        )
                        .id("launchAtLoginToggle") // 强制视图在设置弹窗显示时重新创建
                        .frame(height: 22) // 明确设置高度
                        .onAppear {
                            // 设置弹窗显示时，立即同步检查状态
                            checkLaunchAtLoginStatusImmediately()
                        }
                        
                        HStack {
                            Text("全局快捷键")
                            Spacer()
                            Text("Control + Space")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                    
                    // Appearance Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("外观")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("背景颜色 (预设)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 12)], spacing: 12) {
                            ForEach(presetColors, id: \.self) { color in
                                Button(action: { selectColor(color) }) {
                                    ZStack {
                                        // 外圈选中状态
                                        if isSelected(color) {
                                            Circle()
                                                .stroke(Color.blue.opacity(0.8), lineWidth: 3)
                                                .frame(width: 36, height: 36)
                                        }
                                        
                                        // 颜色主体
                                        Circle()
                                            .fill(color)
                                            .frame(width: 28, height: 28)
                                            // 给浅色增加内描边，防止看不清
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                            )
                                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                    }
                                    .frame(width: 36, height: 36)
                                    .contentShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 8)
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text("背景透明度")
                                Spacer()
                                Text("\(Int(backgroundOpacity * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $backgroundOpacity, in: 0...1)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
                .padding()
            }
        }
        // 恢复为较小的固定尺寸
        .frame(width: 450, height: 400)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                Color(NSColor.windowBackgroundColor).opacity(0.8)
            }
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(40) // 增加外边距，防止阴影或按钮被裁切
    }
    
    private func updateLaunchAtLogin(enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status == .enabled { return }
                try service.register()
            } else {
                if service.status == .notRegistered { return }
                try service.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
            // 失败时回滚 UI 状态
            DispatchQueue.main.async {
                self.launchAtLogin = !enabled
            }
        }
    }
    
    // 辅助函数：更新颜色
    private func selectColor(_ color: Color) {
        let nsColor = NSColor(color)
        if let srgbColor = nsColor.usingColorSpace(.sRGB) {
            customBackgroundColor = "\(srgbColor.redComponent),\(srgbColor.greenComponent),\(srgbColor.blueComponent)"
        }
    }
    
    // 辅助函数：判断是否选中 (近似判断)
    private func isSelected(_ color: Color) -> Bool {
        // 解析当前颜色
        let components = customBackgroundColor.split(separator: ",").compactMap { Double($0) }
        guard components.count == 3 else { return false }
        
        let currentColor = NSColor(red: components[0], green: components[1], blue: components[2], alpha: 1.0)
        
        // 解析目标颜色
        let nsColor = NSColor(color)
        guard let targetColor = nsColor.usingColorSpace(.sRGB) else { return false }
        
        // 比较 RGB 分量 (允许微小误差)
        let epsilon = 0.01
        return abs(currentColor.redComponent - targetColor.redComponent) < epsilon &&
               abs(currentColor.greenComponent - targetColor.greenComponent) < epsilon &&
               abs(currentColor.blueComponent - targetColor.blueComponent) < epsilon
    }
    
    // 立即同步检查开机自启动状态（在主线程上执行）
    private func checkLaunchAtLoginStatusImmediately() {
        isCheckingStatus = true
        // 在主线程上同步检查状态
        let status = SMAppService.mainApp.status
        launchAtLogin = (status == .enabled)
        // 延迟一下再解除禁用状态，确保UI更新完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isCheckingStatus = false
        }
    }
}

// MARK: - 自定义 Switch 控件
struct LaunchAtLoginToggleView: NSViewRepresentable {
    @Binding var isOn: Bool
    @Binding var isCheckingStatus: Bool
    var onToggle: (Bool) -> Void
    
    func makeNSView(context: Context) -> LaunchAtLoginContainerView {
        let containerView = LaunchAtLoginContainerView()
        containerView.setup(parent: context.coordinator, isOn: isOn, isEnabled: !isCheckingStatus)
        context.coordinator.containerView = containerView
        return containerView
    }
    
    func updateNSView(_ nsView: LaunchAtLoginContainerView, context: Context) {
        // 更新 Switch 状态
        nsView.update(isOn: isOn, isEnabled: !isCheckingStatus)
        context.coordinator.containerView = nsView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: LaunchAtLoginToggleView
        var containerView: LaunchAtLoginContainerView?
        var switchControl: NSSwitch? {
            return containerView?.switchControl
        }
        
        init(_ parent: LaunchAtLoginToggleView) {
            self.parent = parent
        }
        
        @objc func switchChanged(_ sender: NSSwitch) {
            let newValue = sender.state == .on
            parent.isOn = newValue
            parent.onToggle(newValue)
        }
    }
}

// MARK: - 自定义容器视图
class LaunchAtLoginContainerView: NSView {
    private var stackView: NSStackView!
    private var label: NSTextField!
    var switchControl: NSSwitch!
    private weak var coordinator: LaunchAtLoginToggleView.Coordinator?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        
        // 创建 HStack 布局
        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建标签
        label = NSTextField(labelWithString: "开机自启动")
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        label.textColor = .labelColor
        
        // 创建 Switch
        switchControl = NSSwitch()
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.frame = NSRect(x: 0, y: 0, width: 51, height: 31) // NSSwitch 的标准尺寸
        switchControl.isHidden = false
        switchControl.alphaValue = 1.0
        
        // 添加到 StackView
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(NSView()) // Spacer
        stackView.addArrangedSubview(switchControl)
        
        // 设置 Spacer 的优先级
        if stackView.arrangedSubviews.count > 1 {
            let spacer = stackView.arrangedSubviews[1]
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        
        addSubview(stackView)
        
        // 设置约束
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 31), // Switch 的标准高度
            switchControl.widthAnchor.constraint(equalToConstant: 51), // Switch 的标准宽度
            switchControl.heightAnchor.constraint(equalToConstant: 31) // Switch 的标准高度
        ])
    }
    
    func setup(parent: LaunchAtLoginToggleView.Coordinator, isOn: Bool, isEnabled: Bool) {
        self.coordinator = parent
        switchControl.target = parent
        switchControl.action = #selector(LaunchAtLoginToggleView.Coordinator.switchChanged(_:))
        switchControl.state = isOn ? .on : .off
        switchControl.isEnabled = isEnabled
        
        // 确保 Switch 控件可见
        switchControl.isHidden = false
        switchControl.alphaValue = 1.0
        
        // 确保视图在添加到窗口后能正确显示
        needsLayout = true
        needsDisplay = true
    }
    
    func update(isOn: Bool, isEnabled: Bool) {
        let newState: NSControl.StateValue = isOn ? .on : .off
        if switchControl.state != newState {
            switchControl.state = newState
        }
        switchControl.isEnabled = isEnabled
        
        // 强制刷新显示
        needsDisplay = true
        if let window = window {
            window.displayIfNeeded()
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 当视图被添加到窗口时，确保 Switch 正确显示
        if window != nil {
            // 强制布局更新
            needsLayout = true
            layoutSubtreeIfNeeded()
            
            // 立即标记需要显示，并强制更新
            needsDisplay = true
            stackView?.needsDisplay = true
            switchControl?.needsDisplay = true
            switchControl?.needsLayout = true
            
            // 强制窗口更新显示
            window?.displayIfNeeded()
            
            // 延迟一点确保窗口已经完全设置好，再次强制更新
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.needsLayout = true
                self.layoutSubtreeIfNeeded()
                self.needsDisplay = true
                self.stackView?.needsDisplay = true
                self.switchControl?.needsDisplay = true
                self.switchControl?.needsLayout = true
                self.window?.displayIfNeeded()
            }
        }
    }
    
    override func layout() {
        super.layout()
        // 确保布局完成后，所有视图都可见
        switchControl?.isHidden = false
        stackView?.isHidden = false
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        // 在绘制前确保所有子视图都准备好了
        stackView?.needsLayout = true
        switchControl?.needsLayout = true
        // 确保视图不被隐藏
        switchControl?.isHidden = false
        stackView?.isHidden = false
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // 确保子视图正确显示
        stackView?.needsDisplay = true
        switchControl?.needsDisplay = true
    }
}
