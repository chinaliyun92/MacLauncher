import SwiftUI
import AppKit

@MainActor
class LaunchpadViewModel: ObservableObject {
    @Published var items: [LauncherItem] = [] {
        didSet {
            // 每次数据变更自动保存
            saveConfig()
        }
    }
    @Published var searchText: String = "" {
        didSet {
            // 实时搜索：当文本变化时触发防抖
            debounceSearch()
        }
    }
    @Published var debouncedSearchText: String = "" // 防抖后的搜索文本
    @Published var isLoading: Bool = false
    
    private var searchTask: Task<Void, Never>?
    
    // 扫描路径
    private let searchPaths = [
        "/Applications",
        "/System/Applications",
        "/Users/\(NSUserName())/Applications"
    ]
    
    init() {
        // 1. 优先加载本地配置 (同步，保证启动速度)
        if loadConfig() {
            print("Loaded config from disk.")
        }
        
        // 2. 无论是否有缓存，都触发后台静默扫描更新 (异步)
        // 这样既保证了秒开，又能自动发现新应用
        refreshApps(silent: true)
    }
    
    // MARK: - Persistence
    
    private var configURL: URL? {
        guard let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let appDir = supportDir.appendingPathComponent("MacLauncher")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("layout.json")
    }
    
    func saveConfig() {
        guard let url = configURL else { return }
        // 简单实现：直接保存（数据量小）
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: url)
        } catch {
            print("Failed to save config: \(error)")
        }
    }
    
    func loadConfig() -> Bool {
        guard let url = configURL, FileManager.default.fileExists(atPath: url.path) else { return false }
        
        do {
            let data = try Data(contentsOf: url)
            let loadedItems = try JSONDecoder().decode([LauncherItem].self, from: data)
            self.items = loadedItems
            return true
        } catch {
            print("Failed to load config: \(error)")
            return false
        }
    }
    
    func refreshApps(silent: Bool = false) {
        scanApps(silent: silent)
    }
    
    // MARK: - Folder Management
    
    func updateFolderName(id: UUID, newName: String) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            if case .folder(var folder) = items[index] {
                folder.name = newName
                items[index] = .folder(folder)
            }
        }
    }
    
    func dissolveFolder(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard case .folder(let folder) = items[index] else { return }
        
        withAnimation {
            // 移除文件夹
            items.remove(at: index)
            
            // 将文件夹内的应用转换回 LauncherItem.app 并插入到原位置
            let unpackedItems = folder.items.map { LauncherItem.app($0) }
            items.insert(contentsOf: unpackedItems, at: index)
        }
    }
    
    // MARK: - Scanning
    
    func scanApps(silent: Bool = false) {
        if !silent {
            isLoading = true
        }
        
        Task {
            let foundItems: [LauncherItem] = await Task.detached(priority: .userInitiated) {
                let fileManager = FileManager.default
                var newItems: [LauncherItem] = []
                var scannedURLs = Set<URL>() // 防止重复
                
                // 只扫描 /Applications 目录
                let applicationsPath = "/Applications"
                
                // 使用 enumerator 遍历目录树，它会自动处理所有子目录（包括二级、三级等）
                guard let enumerator = fileManager.enumerator(
                    at: URL(fileURLWithPath: applicationsPath),
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else {
                    return []
                }
                
                // 遍历所有文件/目录
                for case let fileURL as URL in enumerator {
                    // 检查是否是 .app 后缀
                    if fileURL.pathExtension == "app" {
                        // 验证确实是一个目录（.app 是一个包，本质上是目录）
                        var isDirectory: ObjCBool = false
                        if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                           isDirectory.boolValue {
                            // 防止重复添加
                            if !scannedURLs.contains(fileURL) {
                                scannedURLs.insert(fileURL)
                                
                                // 验证应用是否有效（检查 Info.plist 是否存在）
                                let infoPlistPath = fileURL.appendingPathComponent("Contents/Info.plist")
                                if fileManager.fileExists(atPath: infoPlistPath.path) {
                                    // 有效的应用包，添加到列表
                                    let name = fileURL.deletingPathExtension().lastPathComponent
                                    let appItem = AppItem(name: name, url: fileURL)
                                    newItems.append(.app(appItem))
                                }
                            }
                        }
                        // 跳过 .app 包内部的扫描，因为我们已经找到了这个应用
                        enumerator.skipDescendants()
                    }
                }
                
                return newItems.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }.value
            
            // 合并逻辑
            if self.items.isEmpty {
                self.items = foundItems
            } else {
                self.mergeApps(foundItems)
            }
            
            if !silent {
                self.isLoading = false
            }
        }
    }
    
    private func mergeApps(_ newScannedItems: [LauncherItem]) {
        // 1. 扁平化现有所有 App URL
        var existingAppURLs = Set<URL>()
        
        func extractURLs(from items: [LauncherItem]) {
            for item in items {
                switch item {
                case .app(let app):
                    existingAppURLs.insert(app.url)
                case .folder(let folder):
                    for app in folder.items {
                        existingAppURLs.insert(app.url)
                    }
                }
            }
        }
        extractURLs(from: self.items)
        
        // 2. 找出新安装的 App
        var appsToAdd: [LauncherItem] = []
        for item in newScannedItems {
            if case .app(let app) = item {
                if !existingAppURLs.contains(app.url) {
                    appsToAdd.append(item)
                }
            }
        }
        
        // 3. 将新 App 加到末尾
        if !appsToAdd.isEmpty {
            print("Found \(appsToAdd.count) new apps.")
            withAnimation {
                self.items.append(contentsOf: appsToAdd)
            }
        }
    }
    
    // 防抖搜索函数
    private func debounceSearch() {
        // 取消之前的任务
        searchTask?.cancel()
        
        let currentSearchText = searchText
        
        // 如果搜索内容为空，立即显示全部（不需要等待）
        if currentSearchText.isEmpty {
            debouncedSearchText = ""
            return
        }
        
        // 否则，等待 500 毫秒后更新
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            // 检查任务是否被取消，以及 searchText 是否还是原来的值
            if !Task.isCancelled && self.searchText == currentSearchText {
                await MainActor.run {
                    self.debouncedSearchText = currentSearchText
                }
            }
        }
    }
    
    var filteredItems: [LauncherItem] {
        if debouncedSearchText.isEmpty {
            return items
        } else {
            // 简单搜索：只搜顶层项目和文件夹名
            // 如果要搜文件夹里的内容，逻辑会复杂一点，目前保持简单
            return items.filter { item in
                item.name.localizedCaseInsensitiveContains(debouncedSearchText)
            }
        }
    }
    
    func launchApp(_ app: AppItem) {
        // 1. 立即隐藏 Launchpad，提供即时反馈，无需等待应用启动完成
        DispatchQueue.main.async {
            NSApp.hide(nil)
        }
        
        // 2. 异步启动应用
        let workspace = NSWorkspace.shared
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        workspace.openApplication(at: app.url, configuration: configuration) { app, error in
            if let error = error {
                print("Failed to launch app: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Drag & Drop Logic
    
    func moveItem(from source: LauncherItem, to destination: LauncherItem) {
        guard let fromIndex = items.firstIndex(of: source),
              let toIndex = items.firstIndex(of: destination) else { return }
        
        if fromIndex != toIndex {
            withAnimation {
                let movedItem = items.remove(at: fromIndex)
                items.insert(movedItem, at: toIndex)
            }
        }
    }
    
    func groupItem(_ source: LauncherItem, into destination: LauncherItem) {
        guard let sourceIndex = items.firstIndex(of: source),
              let destIndex = items.firstIndex(of: destination) else { return }
        
        if sourceIndex == destIndex { return }
        
        withAnimation {
            // 1. 移除 source
            let itemToGroup = items.remove(at: sourceIndex)
            
            // 重新计算 destIndex
            guard let newDestIndex = items.firstIndex(of: destination) else {
                items.insert(itemToGroup, at: sourceIndex)
                return
            }
            
            var targetFolder: FolderItem
            
            switch items[newDestIndex] {
            case .folder(let folder):
                targetFolder = folder
                if case .app(let app) = itemToGroup {
                    targetFolder.items.append(app)
                } else if case .folder(let sourceFolder) = itemToGroup {
                    targetFolder.items.append(contentsOf: sourceFolder.items)
                }
                items[newDestIndex] = .folder(targetFolder)
                
            case .app(let destApp):
                var newItems: [AppItem] = []
                newItems.append(destApp)
                
                if case .app(let sourceApp) = itemToGroup {
                    newItems.append(sourceApp)
                } else if case .folder(let sourceFolder) = itemToGroup {
                    newItems.append(contentsOf: sourceFolder.items)
                }
                
                targetFolder = FolderItem(name: "未定义", items: newItems)
                items[newDestIndex] = .folder(targetFolder)
            }
        }
    }
}
