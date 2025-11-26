import SwiftUI
import ServiceManagement
import AppKit

struct SettingsView: View {
    @Binding var isPresented: Bool
    @Binding var launchAtLogin: Bool // 从父视图接收状态，而不是本地 State
    
    @AppStorage("customBackgroundColor") private var customBackgroundColor: String = "1,1,1" // RGB string (Default White)
    @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 0.3
    
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
                        
                        Toggle("开机自启动", isOn: $launchAtLogin)
                            .toggleStyle(SwitchToggleStyle())
                            .onChange(of: launchAtLogin) {
                                updateLaunchAtLogin(enabled: launchAtLogin)
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
}
