import Foundation

// MARK: - Chat Message
struct ChatMessage: Codable {
    let id: String
    let role: Role
    let content: String
    let timestamp: Date
    var actionResults: [String]?

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    init(role: Role, content: String, actionResults: [String]? = nil) {
        self.id = UUID().uuidString
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.actionResults = actionResults
    }
}

// MARK: - LLM Provider
struct LLMProvider: Codable {
    let name: String
    let url: String
    var model: String
    var apiKey: String

    static let siliconflow = LLMProvider(
        name: "硅基流动",
        url: "https://api.siliconflow.cn/v1/chat/completions",
        model: "deepseek-ai/DeepSeek-V3",
        apiKey: ""
    )

    static let deepseek = LLMProvider(
        name: "DeepSeek",
        url: "https://api.deepseek.com/v1/chat/completions",
        model: "deepseek-chat",
        apiKey: ""
    )

    static let volcengine = LLMProvider(
        name: "火山方舟",
        url: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
        model: "ep-20260510050234-p99sv",
        apiKey: ""
    )

    static let custom = LLMProvider(
        name: "自定义",
        url: "",
        model: "",
        apiKey: ""
    )

    static var allProviders: [LLMProvider] {
        return [.siliconflow, .deepseek, .volcengine, .custom]
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
        currentProviderIndex: 0,
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
}
