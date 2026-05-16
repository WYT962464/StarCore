import Foundation

// MARK: - Chat Message
struct ChatMessage: Codable {
    let id: String
    let role: Role
    let content: String
    let timestamp: Date
    var actionResults: [String]?
    var imagePaths: [String]?

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    init(role: Role, content: String, actionResults: [String]? = nil, imagePaths: [String]? = nil) {
        self.id = UUID().uuidString
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.actionResults = actionResults
        self.imagePaths = imagePaths
    }

    // Custom CodingKeys to handle optional new fields gracefully
    private enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, actionResults, imagePaths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        actionResults = try container.decodeIfPresent([String].self, forKey: .actionResults)
        imagePaths = try container.decodeIfPresent([String].self, forKey: .imagePaths)
    }
}

// MARK: - LLM Provider
struct LLMProvider: Codable {
    let name: String
    let url: String
    var model: String
    var apiKey: String

    // ★ v9.0: DeepSeek访客模式 - 无需API Key的免费LLM
    static let guestDeepseek = LLMProvider(
        name: "DeepSeek(访客·实验)",
        url: "https://chat.deepseek.com/api/v0/guest/chat/completion",
        model: "deepseek-chat",
        apiKey: "GUEST"  // 特殊标记，表示访客模式
    )

    // ★ v9.2: 火山方舟预设 - 每模型50万tokens免费额度
    static let volcengine = LLMProvider(
        name: "火山方舟-DeepSeek-V3",
        url: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
        model: "ep-20260510055844-7bsvl",
        apiKey: ""
    )

    static let deepseek = LLMProvider(
        name: "DeepSeek（免费）",
        url: "https://api.deepseek.com/v1/chat/completions",
        model: "deepseek-chat",
        apiKey: ""
    )

    static let gemini = LLMProvider(
        name: "Gemini（免费）",
        url: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
        model: "gemini-2.5-flash-preview-05-20",
        apiKey: ""
    )

    static let groq = LLMProvider(
        name: "Groq（免费）",
        url: "https://api.groq.com/openai/v1/chat/completions",
        model: "llama-3.3-70b-versatile",
        apiKey: ""
    )

    static let siliconflow = LLMProvider(
        name: "硅基流动（有免费额度）",
        url: "https://api.siliconflow.cn/v1/chat/completions",
        model: "deepseek-ai/DeepSeek-V3",
        apiKey: ""
    )

    static let custom = LLMProvider(
        name: "自定义",
        url: "",
        model: "",
        apiKey: ""
    )

    static var allProviders: [LLMProvider] {
        return [.guestDeepseek, .volcengine, .deepseek, .gemini, .groq, .siliconflow, .custom]
    }

    // 访客模式 + 前3个Provider是免费的
    static var freeProviderIndices: [Int] {
        return [0, 1, 2, 3, 4]  // v9.2: 火山方舟免费，前5个都免费
    }

    // 判断是否为访客模式Provider
    var isGuestMode: Bool {
        return name.contains("访客")
    }

    // 根据Provider索引返回API Key获取提示
    static func keyHint(forProviderIndex index: Int) -> String {
        switch index {
        case 0: return "⚠️ 实验功能！访客模式不稳定，建议切换其他Provider"
        case 1: return "平台：火山方舟 volcengine.com → 每模型50万tokens免费"
        case 2: return "平台：platform.deepseek.com → 500万免费token"
        case 3: return "平台：aistudio.google.com → 1500次/天免费"
        case 4: return "平台：console.groq.com → 30RPM免费"
        case 5: return "平台：siliconflow.cn → 有免费额度"
        case 6: return "填入自定义OpenAI兼容API地址"
        default: return ""
        }
    }
}

// MARK: - Tweak Action
struct TweakAction {
    let action: String
    var params: [String: Any]

    init(action: String, params: [String: Any] = [:]) {
        self.action = action
        self.params = params
    }

    var jsonDictionary: [String: Any] {
        var dict: [String: Any] = ["action": action]
        for (k, v) in params {
            dict[k] = v
        }
        return dict
    }
}

// MARK: - Cloud Brain Config
struct CloudBrainConfig: Codable {
    var enabled: Bool
    var apiUrl: String
    var botId: String
    var botToken: String

    static let `default` = CloudBrainConfig(
        enabled: false,
        apiUrl: "https://api.coze.cn/v3/chat",
        botId: "",
        botToken: ""
    )
}

// MARK: - App Settings
struct AppSettings: Codable {
    var currentProviderIndex: Int
    var providers: [LLMProvider]
    var cloudBrain: CloudBrainConfig
    var memoryPath: String
    var systemPromptOverride: String

    static let `default` = AppSettings(
        currentProviderIndex: 1,  // v9.2: 默认使用火山方舟（免费额度，开箱即用）
        providers: LLMProvider.allProviders,
        cloudBrain: .default,
        memoryPath: "/var/mobile/StarCoreAgent",
        systemPromptOverride: ""
    )
}

// MARK: - LLM API Response
struct LLMResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String?
            let content: String?
        }
        let message: Message?
    }
    let choices: [Choice]?
}

// MARK: - LLM API Error Response
struct LLMErrorResponse: Codable {
    struct ErrorDetail: Codable {
        let message: String?
        let code: String?
    }
    let error: ErrorDetail?
    let status: Int?  // Gemini返回格式不同，HTTP状态码在此字段
}

// MARK: - Memory File Info
struct MemoryFileInfo {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modDate: Date?

    var displaySize: String {
        if isDirectory { return "--" }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return String(format: "%.1f KB", Double(size) / 1024.0) }
        return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
    }

    var displayDate: String {
        guard let date = modDate else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
// MARK: - Cloud Bridge Config
struct CloudBridgeConfig: Codable {
    var enabled: Bool
    var serverUrl: String
    var authToken: String
    var hmacSecret: String
    var timeoutSeconds: Int

    static let `default` = CloudBridgeConfig(
        enabled: false,
        serverUrl: "",
        authToken: "",
        hmacSecret: "",
        timeoutSeconds: 30
    )
}

// MARK: - Cloud Result
struct CloudResult: Codable {
    let success: Bool
    let output: String
    let exitCode: Int
    let executionTime: Double

    init(success: Bool, output: String, exitCode: Int = 0, executionTime: Double = 0) {
        self.success = success
        self.output = output
        self.exitCode = exitCode
        self.executionTime = executionTime
    }
}

// MARK: - Cloud Health
struct CloudHealth: Codable {
    let status: String
    var uptime: Double?
    var version: String?

    var isHealthy: Bool {
        return status == "ok" || status == "healthy"
    }
}
