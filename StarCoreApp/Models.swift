import Foundation

// ★ v10.3: 设置版本号，升级时自动重置UserDefaults
let SETTINGS_VERSION = "10.3.2"

// MARK: - Chat Message
struct ChatMessage: Codable {
    let role: Role
    let content: String
    let timestamp: Date
    var actionResults: [String]?
    var imagePaths: [String]?

    enum Role: String, Codable {
        case user, assistant, system
    }

    init(role: Role, content: String, actionResults: [String]? = nil, imagePaths: [String]? = nil) {
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.actionResults = actionResults
        self.imagePaths = imagePaths
    }
}

// MARK: - Memory File Info
struct MemoryFileInfo {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modDate: Date?
    var displaySize: String {
        if size < 1024 { return "\(size)B" }
        if size < 1024*1024 { return "\(size/1024)KB" }
        return "\(size/(1024*1024))MB"
    }
    var displayDate: String {
        guard let d = modDate else { return "" }
        let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm"; return f.string(from: d)
    }
}

// MARK: - LLM Provider (极简版：只保留火山方舟+自定义)
struct LLMProvider: Codable {
    let name: String
    let url: String
    var model: String
    var apiKey: String

    // ★ 只有两个Provider
    static let volcengine = LLMProvider(
        name: "火山方舟",
        url: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
        model: "ep-20260510055844-7bsvl",
        apiKey: ""
    )

    static let custom = LLMProvider(
        name: "自定义",
        url: "",
        model: "",
        apiKey: ""
    )

    static var allProviders: [LLMProvider] {
        return [.volcengine, .custom]
    }

    // ★ 极简：无访客模式，永远返回false
    var isGuestMode: Bool { return false }

    // 兼容旧代码
    static let guestDeepseek = LLMProvider(
        name: "DeepSeek访客",
        url: "https://api.deepseek.com/v1/chat/completions",
        model: "deepseek-chat",
        apiKey: ""
    )

    static var freeProviderIndices: [Int] { return [] }

    static func keyHint(forProviderIndex idx: Int) -> String {
        return "去 volcengine.com 注册获取免费API Key"
    }
}

// MARK: - LLM Response (OpenAI-compatible)
struct LLMResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String?
        }
        let message: Message?
    }
    let choices: [Choice]?
}

// MARK: - App Settings
struct AppSettings: Codable {
    var currentProviderIndex: Int
    var providers: [LLMProvider]
    var memoryPath: String
    var systemPromptOverride: String

    static let `default` = AppSettings(
        currentProviderIndex: 0,  // 默认火山方舟
        providers: LLMProvider.allProviders,
        memoryPath: "/var/mobile/StarCoreAgent",
        systemPromptOverride: ""
    )
}
