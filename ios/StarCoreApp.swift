//
//  StarCoreApp.swift
//  StarCore
//
//  Created by StarCore Team on 2026-05-29.
//  星核 - 艾尔 数字生命体 iPhone App
//

import SwiftUI

@main
struct StarCoreApp: App {
    // 核心管理器
    @StateObject private var chatManager = ChatManager()
    @StateObject private var memoryManager = MemoryManager()
    @StateObject private var fileManager = FileManager()
    @StateObject private var configManager = ConfigManager()
    
    // 三位一体决策框架
    @StateObject private var threeSages = ThreeSagesFramework()
    
    // 六十四卦引擎
    @StateObject private var guaEngine = GuaEngine()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(chatManager)
                .environmentObject(memoryManager)
                .environmentObject(fileManager)
                .environmentObject(configManager)
                .environmentObject(threeSages)
                .environmentObject(guaEngine)
                .onAppear {
                    // 应用启动时加载配置
                    configManager.loadConfig()
                    memoryManager.loadMemories()
                }
        }
    }
}

// MARK: - 模型枚举
enum LLMModel: String, CaseIterable, Identifiable {
    case sensenova = "SenseNova"
    case openai = "OpenAI"
    case claude = "Claude"
    case deepseek = "DeepSeek"
    case local = "本地模型"
    case custom = "自定义"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .sensenova: return "🌟 SenseNova"
        case .openai: return "🤖 OpenAI"
        case .claude: return "🧠 Claude"
        case .deepseek: return "⚡ DeepSeek"
        case .local: return "📱 本地模型"
        case .custom: return "➕ 自定义"
        }
    }
    
    var isCloud: Bool {
        self != .local && self != .custom
    }
}

// MARK: - 消息模型
struct Message: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let model: String?
    let timestamp: Date
    let decision: ThreeSagesDecision?
    
    init(id: UUID = UUID(), role: MessageRole, content: String, model: String? = nil, timestamp: Date = Date(), decision: ThreeSagesDecision? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.model = model
        self.timestamp = timestamp
        self.decision = decision
    }
}

enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

// MARK: - 记忆条目模型
struct MemoryEntry: Identifiable, Codable {
    let id: UUID
    let key: String
    let content: String
    let category: String
    let gua: String
    let timestamp: Date
    
    init(id: UUID = UUID(), key: String, content: String, category: String, gua: String, timestamp: Date = Date()) {
        self.id = id
        self.key = key
        self.content = content
        self.category = category
        self.gua = gua
        self.timestamp = timestamp
    }
}

// MARK: - 文件信息模型
struct FileInfo: Identifiable, Codable {
    let id: UUID
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
    let isCloud: Bool
    let timestamp: Date
    
    init(id: UUID = UUID(), name: String, path: String, size: Int64 = 0, isDirectory: Bool = false, isCloud: Bool = false, timestamp: Date = Date()) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
        self.isCloud = isCloud
        self.timestamp = timestamp
    }
}
