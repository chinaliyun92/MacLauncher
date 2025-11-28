import SwiftUI
import UniformTypeIdentifiers
import ServiceManagement

struct ContentView: View {
    @StateObject private var viewModel = LaunchpadViewModel()
    @State private var expandedFolderId: UUID? = nil
    @State private var editingFolderName: String = ""
    @State private var showSettings = false
    @State private var launchAtLogin: Bool = false
    @State private var wasWindowHidden = true // 追踪窗口之前的隐藏状态
    
    // 从 UserDefaults 读取设置
    @AppStorage("customBackgroundColor") private var customBackgroundColor: String = "1,1,1"
    @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 0.3
    
    // 解析颜色
    var backgroundColor: Color {
        let components = customBackgroundColor.split(separator: ",").compactMap { Double($0) }
        if components.count == 3 {
            return Color(red: components[0], green: components[1], blue: components[2])
        }
        return Color.black
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 40, alignment: .top)
    ]
    
    var body: some View {
        ZStack {
            // 背景层
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                    .edgesIgnoringSafeArea(.all)
                
                // 自定义颜色和透明度
                backgroundColor.opacity(backgroundOpacity)
                    .edgesIgnoringSafeArea(.all)
            }
            .onTapGesture {
                withAnimation {
                    expandedFolderId = nil
                }
            }
            
            // 顶部拖拽区域 (热区)
            VStack {
                DraggableArea()
                    .frame(height: 40) // 顶部 40pt 作为拖拽区
                    .contentShape(Rectangle())
                Spacer()
            }
            
            VStack(spacing: 30) {
                // 搜索栏与设置按钮
                HStack(spacing: 16) {
                    // 搜索框
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.title2)
                        SearchTextField(text: $viewModel.searchText, placeholder: "搜索")
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    
                    // 刷新按钮
                    Button(action: {
                        viewModel.refreshApps(silent: false)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(12)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                            .animation(
                                viewModel.isLoading ? 
                                Animation.linear(duration: 1).repeatForever(autoreverses: false) : 
                                .default,
                                value: viewModel.isLoading
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("刷新应用列表")
                    .disabled(viewModel.isLoading)
                    
                    // 设置按钮
                    Button(action: {
                        withAnimation {
                            showSettings = true
                        }
                    }) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(12)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("设置")
                }
                .padding(.horizontal, 100)
                .padding(.top, 50)
                
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .colorScheme(.dark)
                        Text("正在扫描应用...")
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 主应用网格
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 40) {
                            ForEach(viewModel.filteredItems) { item in
                                GeometryReader { geo in
                                    LauncherItemView(item: item)
                                        .onTapGesture {
                                            switch item {
                                            case .app(let app):
                                                viewModel.launchApp(app)
                                            case .folder(let folder):
                                                withAnimation {
                                                    editingFolderName = folder.name
                                                    expandedFolderId = folder.id
                                                }
                                            }
                                        }
                                        .draggable(item.id.uuidString)
                                        .dropDestination(for: String.self) { ids, location in
                                            guard let id = ids.first,
                                                  let sourceItem = viewModel.items.first(where: { $0.id.uuidString == id }) else { return false }
                                            
                                            if sourceItem.id == item.id { return false }
                                            
                                            let frame = geo.frame(in: .local)
                                            let centerRect = frame.insetBy(dx: frame.width * 0.2, dy: frame.height * 0.2)
                                            
                                            if centerRect.contains(location) {
                                                withAnimation {
                                                    viewModel.groupItem(sourceItem, into: item)
                                                }
                                            } else {
                                                withAnimation {
                                                    viewModel.moveItem(from: sourceItem, to: item)
                                                }
                                            }
                                            return true
                                        }
                                }
                                .frame(height: 120)
                                .zIndex(1)
                            }
                        }
                        .padding(.horizontal, 50)
                        .padding(.bottom, 50)
                    }
                    .scrollIndicators(.hidden)
                    .background(ScrollViewHider()) // 添加背景监听器来强制隐藏滚动条
                    .blur(radius: (expandedFolderId != nil || showSettings) ? 10 : 0)
                    .disabled(expandedFolderId != nil || showSettings)
                }
            }
            
            // 文件夹展开视图 Overlay
            if let folderId = expandedFolderId,
               let index = viewModel.items.firstIndex(where: { $0.id == folderId }),
               case .folder(let folder) = viewModel.items[index] {
                
                Color.black.opacity(0.6)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation {
                            expandedFolderId = nil
                        }
                    }
                
                VStack(spacing: 20) {
                    HStack {
                        TextField("文件夹名称", text: $editingFolderName, onCommit: {
                            viewModel.updateFolderName(id: folderId, newName: editingFolderName)
                        })
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .frame(width: 200)
                        
                        Button(action: {
                            withAnimation {
                                expandedFolderId = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    viewModel.dissolveFolder(id: folderId)
                                }
                            }
                        }) {
                            Text("解散分组")
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.6))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 30) {
                            ForEach(folder.items) { app in
                                AppIconView(app: app)
                                    .onTapGesture {
                                        viewModel.launchApp(app)
                                        withAnimation {
                                            expandedFolderId = nil
                                        }
                                    }
                            }
                        }
                        .padding(30)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: 800, maxHeight: 500)
                    .background(
                        ZStack {
                            VisualEffectView(material: .popover, blendingMode: .withinWindow)
                            Color.black.opacity(0.2)
                        }
                    )
                    .cornerRadius(20)
                    .shadow(radius: 20)
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(100)
            }
            
            // 设置弹窗 Overlay (居中显示)
            if showSettings {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation {
                            showSettings = false
                        }
                    }
                    .zIndex(200)
                
                SettingsView(isPresented: $showSettings, launchAtLogin: $launchAtLogin)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(201)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 主界面显示后，异步检测开机自启动状态
        .onAppear {
            Task {
                await checkLaunchAtLoginStatus()
            }
        }
        // 监听窗口显示事件 - 当窗口从隐藏状态变为显示时，清空搜索内容
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if let window = notification.object as? NSWindow,
               window == NSApp.windows.first {
                // 如果窗口之前是隐藏的，现在显示出来了，清空搜索内容
                if wasWindowHidden && !showSettings {
                    viewModel.searchText = ""
                    wasWindowHidden = false
                }
            }
        }
        // 监听窗口失去焦点事件（点击外部区域）
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            if let window = notification.object as? NSWindow,
               window == NSApp.windows.first {
                // 如果窗口失去焦点且不是因为有设置弹窗或展开的文件夹，隐藏窗口并标记状态
                if !showSettings && expandedFolderId == nil {
                    wasWindowHidden = true
                    NSApp.hide(nil)
                }
            }
        }
        // 核心修改：使用 NSViewRepresentable 注入按键监听，通过 Closure 回调处理
        .background(KeyMonitorView(onEsc: {
            if showSettings {
                withAnimation { showSettings = false }
            } else if expandedFolderId != nil {
                withAnimation { expandedFolderId = nil }
            } else {
                // 标记窗口为隐藏状态，然后隐藏窗口
                wasWindowHidden = true
                NSApp.hide(nil)
                // 隐藏后取消第一响应者，防止下次唤起时仍处于编辑状态
                NSApp.windows.first?.makeFirstResponder(nil)
            }
        }))
    }
    
    // 异步检测开机自启动状态
    @MainActor
    private func checkLaunchAtLoginStatus() async {
        // 在后台线程执行检测，避免阻塞 UI
        let status = await Task.detached {
            return SMAppService.mainApp.status
        }.value
        
        // 回到主线程更新状态
        self.launchAtLogin = (status == .enabled)
    }
}

struct KeyMonitorView: NSViewRepresentable {
    var onEsc: () -> Void
    
    func makeNSView(context: Context) -> WindowConfiguratorNSView {
        let view = WindowConfiguratorNSView()
        view.onEsc = onEsc
        return view
    }
    
    func updateNSView(_ nsView: WindowConfiguratorNSView, context: Context) {
        // 更新闭包
        nsView.onEsc = onEsc
        // 每次视图更新时尝试隐藏滚动条
        nsView.hideScrollbars()
    }
}

class WindowConfiguratorNSView: NSView {
    private var monitor: Any?
    var onEsc: (() -> Void)?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 当视图被添加到窗口时，设置监听器并隐藏滚动条
        setupMonitor()
        // 立即隐藏，然后在多个时间点重复隐藏，确保滚动条被彻底隐藏
        hideScrollbars()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hideScrollbars()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.hideScrollbars()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hideScrollbars()
        }
        
        // 监听窗口通知，在窗口更新时也隐藏滚动条
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidUpdate),
            name: NSWindow.didUpdateNotification,
            object: self.window
        )
    }
    
    @objc private func windowDidUpdate() {
        hideScrollbars()
    }
    
    func setupMonitor() {
        // 防止重复添加
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        
        guard self.window != nil else { return }
        
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // 1. 处理 ESC (keyCode 53)
            if event.keyCode == 53 {
                // 拦截事件，防止系统默认行为（例如 beep 或者输入框放弃焦点等）
                // 直接调用我们的逻辑
                
                // 检查当前是否处于输入状态
                // 即使在输入状态，我们也希望直接退出，而不是先放弃焦点再退出
                
                DispatchQueue.main.async {
                    self?.onEsc?()
                }
                return nil // 拦截事件
            }
            
            // 2. 处理 Cmd+Q (keyCode 12)
            if event.modifierFlags.contains(.command) && event.keyCode == 12 {
                NSApp.terminate(nil)
                return nil
            }
            
            // 3. 处理 Cmd+W (keyCode 13)
            if event.modifierFlags.contains(.command) && event.keyCode == 13 {
                NSApp.hide(nil)
                return nil
            }
            
            return event
        }
    }
    
    func hideScrollbars() {
        guard let window = self.window, let contentView = window.contentView else { return }
        recursivelyHideScrollbars(in: contentView)
    }
    
    private func recursivelyHideScrollbars(in view: NSView) {
        if let scrollView = view as? NSScrollView {
            // 强制隐藏滚动条
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.scrollerStyle = .overlay
            scrollView.autohidesScrollers = true
            
            // 确保滚动条视图被移除
            if let verticalScroller = scrollView.verticalScroller {
                verticalScroller.isHidden = true
                verticalScroller.alphaValue = 0
            }
            if let horizontalScroller = scrollView.horizontalScroller {
                horizontalScroller.isHidden = true
                horizontalScroller.alphaValue = 0
            }
            
            // 设置滚动视图的边框样式，进一步隐藏滚动条
            scrollView.borderType = .noBorder
        }
        for subview in view.subviews {
            recursivelyHideScrollbars(in: subview)
        }
    }
    
    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// ... 剩下的辅助 View 代码保持不变
struct AppIconView: View {
    let app: AppItem
    @State private var isHovering = false
    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .shadow(radius: 4)
            
            Text(app.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 100) // 限制文字最大宽度
                .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
        }
        .frame(width: 110, height: 110) // 固定容器尺寸
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovering ? Color.white.opacity(0.15) : Color.clear)
        )
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
        .onHover { hovering in isHovering = hovering }
    }
}

struct LauncherItemView: View {
    let item: LauncherItem
    @State private var isHovering = false
    var body: some View {
        VStack(spacing: 8) {
            Group {
                switch item {
                case .app(let app):
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                case .folder(let folder):
                    FolderIconView(folder: folder)
                        .frame(width: 64, height: 64)
                }
            }
            .shadow(radius: 4)
            
            Text(item.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 100) // 限制文字最大宽度
                .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
        }
        .frame(width: 110, height: 110) // 固定容器尺寸
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovering ? Color.white.opacity(0.15) : Color.clear)
        )
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
        .onHover { hovering in isHovering = hovering }
    }
}

struct FolderIconView: View {
    let folder: FolderItem
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.25)).aspectRatio(1, contentMode: .fit).shadow(radius: 4).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                ForEach(folder.items.prefix(9)) { app in Image(nsImage: app.icon).resizable().aspectRatio(contentMode: .fit) }
            }.padding(8)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// 滚动条隐藏器 - 持续监听并隐藏滚动条
struct ScrollViewHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.setValue(NSColor.clear, forKey: "backgroundColor")
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // 每次更新时都尝试隐藏滚动条
        DispatchQueue.main.async {
            if let window = nsView.window,
               let contentView = window.contentView {
                recursivelyHideScrollbars(in: contentView)
            }
        }
    }
    
    private func recursivelyHideScrollbars(in view: NSView) {
        if let scrollView = view as? NSScrollView {
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.scrollerStyle = .overlay
            scrollView.autohidesScrollers = true
            
            if let verticalScroller = scrollView.verticalScroller {
                verticalScroller.isHidden = true
                verticalScroller.alphaValue = 0
            }
            if let horizontalScroller = scrollView.horizontalScroller {
                horizontalScroller.isHidden = true
                horizontalScroller.alphaValue = 0
            }
        }
        for subview in view.subviews {
            recursivelyHideScrollbars(in: subview)
        }
    }
}

// 自定义搜索框，支持白色 placeholder
struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.focusRingType = .none
        textField.backgroundColor = .clear
        textField.textColor = .white
        textField.font = NSFont.systemFont(ofSize: 20) // 对应 .title2
        
        // 设置对齐方式（左对齐）
        textField.alignment = .left
        if let cell = textField.cell as? NSTextFieldCell {
            cell.lineBreakMode = .byTruncatingTail
            cell.usesSingleLineMode = true
        }
        
        // 设置 placeholder 颜色为白色，并对齐
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        
        let placeholderAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white.withAlphaComponent(0.7),
            .paragraphStyle: paragraphStyle,
            .font: NSFont.systemFont(ofSize: 20) // 确保字体大小一致
        ]
        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: placeholderAttrs
        )
        
        // 设置 delegate 以支持实时文本变化监听
        textField.delegate = context.coordinator
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        // 更新 placeholder，保持对齐和字体
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        
        let placeholderAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white.withAlphaComponent(0.7),
            .paragraphStyle: paragraphStyle,
            .font: NSFont.systemFont(ofSize: 20) // 确保字体大小一致
        ]
        nsView.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: placeholderAttrs
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchTextField
        
        init(_ parent: SearchTextField) {
            self.parent = parent
            super.init()
        }
        
        @objc func textChanged(_ sender: NSTextField) {
            parent.text = sender.stringValue
        }
        
        // 实时监听文本变化（不需要按回车）
        func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }
}

