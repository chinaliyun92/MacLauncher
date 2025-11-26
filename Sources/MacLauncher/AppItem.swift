import SwiftUI
import AppKit

enum LauncherItem: Identifiable, Equatable, Codable {
    case app(AppItem)
    case folder(FolderItem)
    
    var id: UUID {
        switch self {
        case .app(let item): return item.id
        case .folder(let item): return item.id
        }
    }
    
    var name: String {
        switch self {
        case .app(let item): return item.name
        case .folder(let item): return item.name
        }
    }
}

struct AppItem: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let url: URL
    // icon 不参与归档，运行时通过 url 获取
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, url
    }
    
    init(id: UUID = UUID(), name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(URL.self, forKey: .url)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
    }
    
    static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct FolderItem: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var items: [AppItem]
    
    init(id: UUID = UUID(), name: String = "未定义", items: [AppItem] = []) {
        self.id = id
        self.name = name
        self.items = items
    }
}
