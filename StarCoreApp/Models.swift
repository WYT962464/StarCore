import Foundation

// ★ v10.3: 设置版本号，升级时自动重置UserDefaults
let SETTINGS_VERSION = "10.3.3"

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
    struct ToolCall: Codable {
        struct FunctionCall: Codable {
            let name: String?
            let arguments: String?
        }
        let id: String?
        let type: String?
        let function: FunctionCall?
    }
    struct Choice: Codable {
        struct Message: Codable {
            let content: String?
            let role: String?
            let toolCalls: [ToolCall]?
            enum CodingKeys: String, CodingKey {
                case content, role
                case toolCalls = "tool_calls"
            }
        }
        let message: Message?
        let finishReason: String?
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
    let choices: [Choice]?
}

// 工具定义（原生function calling）
struct ToolDefinitions {
    static let allTools: [[String: Any]] = [
        [
            "type": "function",
            "function": [
                "name": "tap",
                "description": "点击屏幕（归一化坐标0-1）",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "x": ["type": "number", "description": "X坐标 0-1"],
                        "y": ["type": "number", "description": "Y坐标 0-1"]
                    ],
                    "required": ["x", "y"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "swipe",
                "description": "滑动屏幕",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "fromX": ["type": "number"],
                        "fromY": ["type": "number"],
                        "toX": ["type": "number"],
                        "toY": ["type": "number"],
                        "duration": ["type": "number", "description": "滑动时长秒"]
                    ],
                    "required": ["fromX", "fromY", "toX", "toY"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "shell",
                "description": "执行shell命令（自动fallback，总有权限）",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "command": ["type": "string", "description": "shell命令"]
                    ],
                    "required": ["command"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "openApp",
                "description": "打开App",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "bundleId": ["type": "string", "description": "App的Bundle ID"]
                    ],
                    "required": ["bundleId"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "pressHome",
                "description": "按Home键",
                "parameters": ["type": "object", "properties": [:]]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "screenshot",
                "description": "截图",
                "parameters": ["type": "object", "properties": [:]]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "inputText",
                "description": "输入中文/Unicode文字",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "text": ["type": "string", "description": "要输入的文本"]
                    ],
                    "required": ["text"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "typeText",
                "description": "逐字输入英文",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "text": ["type": "string", "description": "要输入的英文"]
                    ],
                    "required": ["text"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "pressPower",
                "description": "按电源键",
                "parameters": ["type": "object", "properties": [:]]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "getScreenInfo",
                "description": "获取屏幕尺寸和当前App信息",
                "parameters": ["type": "object", "properties": [:]]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "writeFile",
                "description": "写文件到App沙盒（自动校验，上限3000字）",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "文件完整路径"],
                        "content": ["type": "string", "description": "文件内容"]
                    ],
                    "required": ["path", "content"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "appendFile",
                "description": "追加内容到文件（上限1000字）",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "文件完整路径"],
                        "content": ["type": "string", "description": "追加内容"]
                    ],
                    "required": ["path", "content"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "readFile",
                "description": "读取文件内容",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "文件完整路径"]
                    ],
                    "required": ["path"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "listFiles",
                "description": "列出目录内容",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "目录路径"]
                    ]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "iosMcpGetUI",
                "description": "获取当前屏幕UI元素",
                "parameters": ["type": "object", "properties": [:]]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "iosMcpLaunchApp",
                "description": "通过iOS MCP启动App",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "bundleId": ["type": "string"]
                    ],
                    "required": ["bundleId"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "iosMcpListApps",
                "description": "列出已安装App",
                "parameters": ["type": "object", "properties": [:]]
            ]
        ]
    ]
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
