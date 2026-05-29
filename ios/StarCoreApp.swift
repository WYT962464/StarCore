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
    @StateObject private var fileBrowser = FileBrowser()
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
                .environmentObject(fileBrowser)
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
enum LLMModel: String, Codable, CaseIterable, Identifiable {
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
    
    // 内置模型的默认 API 配置
    var defaultConfig: CustomModelConfig {
        switch self {
        case .sensenova:
            return CustomModelConfig(
                name: "SenseNova-6.7 Flash-Lite",
                type: "openai",
                apiKey: "sk-vg4jMAU8fl6n9YXwY5LEgTop5e9xeiZb",  // 默认测试 Key，用户可在设置中修改
                baseURL: "https://token.sensenova.cn/v1",
                modelName: "sensenova-6.7-flash-lite"  // API 实际使用的模型名称
            )
        case .openai:
            return CustomModelConfig(
                name: "OpenAI-GPT-4",
                type: "openai",
                apiKey: "",
                baseURL: "https://api.openai.com/v1"
            )
        case .claude:
            return CustomModelConfig(
                name: "Claude-3.5",
                type: "anthropic",
                apiKey: "",
                baseURL: "https://api.anthropic.com/v1"
            )
        case .deepseek:
            return CustomModelConfig(
                name: "DeepSeek-V3",
                type: "openai",
                apiKey: "",
                baseURL: "https://api.deepseek.com/v1"
            )
        case .local:
            return CustomModelConfig(
                name: "本地模型",
                type: "local",
                apiKey: "",
                baseURL: nil
            )
        case .custom:
            return CustomModelConfig(
                name: "自定义模型",
                type: "openai",
                apiKey: "",
                baseURL: ""
            )
        }
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
