import Foundation

// ★ v11.0: 直连Tweak架构，砍掉iOS MCP，注册34+iOS MCP工具给小智
let SETTINGS_VERSION = "11.2.0"

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

    static let volcengine = LLMProvider(
        name: "火山方舟",
        url: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
        model: "ep-20260510055844-7bsvl",
        apiKey: ""
    )

    static let sensenova = LLMProvider(
        name: "商汤SenseNova",
        url: "https://token.sensenova.cn/v1/chat/completions",
        model: "sensenova-6.7-flash-lite",
        apiKey: "sk-vg4jMAU8fl6n9YXwY5LEgTop5e9xeiZb"
    )

    static let deepseekV4 = LLMProvider(
        name: "DeepSeek V4(商汤)",
        url: "https://token.sensenova.cn/v1/chat/completions",
        model: "deepseek-v4-flash",
        apiKey: "sk-vg4jMAU8fl6n9YXwY5LEgTop5e9xeiZb"
    )

    static let custom = LLMProvider(
        name: "自定义",
        url: "",
        model: "",
        apiKey: ""
    )

    static var allProviders: [LLMProvider] {
        return [.volcengine, .sensenova, .deepseekV4, .custom]
    }

    var isGuestMode: Bool { return false }

    static let guestDeepseek = LLMProvider(
        name: "DeepSeek访客",
        url: "https://api.deepseek.com/v1/chat/completions",
        model: "deepseek-chat",
        apiKey: ""
    )

    static var freeProviderIndices: [Int] { return [] }

    static func keyHint(forProviderIndex idx: Int) -> String {
        switch idx {
        case 1: return "去 platform.sensenova.cn 注册，API Key免费(1500次/5h)"
        case 2: return "同商汤Key，deepseek-v4-flash模型(150次/5h)"
        default: return "去 volcengine.com 注册获取免费API Key"
        }
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

// MARK: - LLM Function Calling Tool Definitions (OpenAI格式，用于原生function calling)
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
                "name": "longPress",
                "description": "长按屏幕坐标",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "x": ["type": "number", "description": "X坐标 0-1"],
                        "y": ["type": "number", "description": "Y坐标 0-1"],
                        "duration": ["type": "number", "description": "长按时长秒"]
                    ],
                    "required": ["x", "y"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "shell",
                "description": "执行shell命令（root权限，自动fallback）",
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
                "name": "pressVolumeUp",
                "description": "按音量+键",
                "parameters": ["type": "object", "properties": [:]]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "pressVolumeDown",
                "description": "按音量-键",
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
                "name": "getScreenSize",
                "description": "获取屏幕像素尺寸和缩放因子",
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
                "name": "getClipboard",
                "description": "获取剪贴板内容",
                "parameters": ["type": "object", "properties": [:]]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "setClipboard",
                "description": "设置剪贴板内容",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "text": ["type": "string", "description": "要复制到剪贴板的文本"]
                    ],
                    "required": ["text"]
                ]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "getUIElements",
                "description": "获取当前屏幕UI元素树",
                "parameters": ["type": "object", "properties": [:]]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "listApps",
                "description": "列出已安装App",
                "parameters": ["type": "object", "properties": [:]]
            ]
        ],
        [
            "type": "function",
            "function": [
                "name": "killApp",
                "description": "强制关闭App",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "bundleId": ["type": "string", "description": "App的Bundle ID"]
                    ],
                    "required": ["bundleId"]
                ]
            ]
        ]
    ]
}

// MARK: - MCP Tool Definitions (小智MCP格式，注册给小智)
// 格式: {name, description, inputSchema} — 不是OpenAI的function calling格式
// 工具名和iOS MCP保持一致，小智已经习惯这些名字
// 34个iOS MCP工具 + 4个Tweak独有文件操作 = 38个工具
struct MCPToolDefinitions {

    static let tweakTools: [[String: Any]] = [
        // ═══════════════════════════════════════
        // 1. 触控操作 (6个)
        // ═══════════════════════════════════════
        [
            "name": "tap_screen",
            "description": "点击屏幕指定坐标。坐标为归一化值0-1，如(0.5,0.5)为屏幕中心",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "x": ["type": "number", "description": "X坐标，归一化0-1"],
                    "y": ["type": "number", "description": "Y坐标，归一化0-1"]
                ],
                "required": ["x", "y"]
            ]
        ],
        [
            "name": "swipe_screen",
            "description": "在屏幕上从起点滑动到终点",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "startX": ["type": "number", "description": "起点X，归一化0-1"],
                    "startY": ["type": "number", "description": "起点Y，归一化0-1"],
                    "endX": ["type": "number", "description": "终点X，归一化0-1"],
                    "endY": ["type": "number", "description": "终点Y，归一化0-1"],
                    "duration": ["type": "number", "description": "滑动时长(秒)，默认0.5"]
                ],
                "required": ["startX", "startY", "endX", "endY"]
            ]
        ],
        [
            "name": "long_press",
            "description": "长按屏幕指定坐标位置",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "x": ["type": "number", "description": "X坐标，归一化0-1"],
                    "y": ["type": "number", "description": "Y坐标，归一化0-1"],
                    "duration": ["type": "number", "description": "长按时长(秒)，默认0.5"]
                ],
                "required": ["x", "y"]
            ]
        ],
        [
            "name": "double_tap",
            "description": "双击屏幕指定坐标位置",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "x": ["type": "number", "description": "X坐标，归一化0-1"],
                    "y": ["type": "number", "description": "Y坐标，归一化0-1"]
                ],
                "required": ["x", "y"]
            ]
        ],
        [
            "name": "drag_and_drop",
            "description": "从起点拖拽到终点（长按+移动+松开）",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "startX": ["type": "number", "description": "起点X，归一化0-1"],
                    "startY": ["type": "number", "description": "起点Y，归一化0-1"],
                    "endX": ["type": "number", "description": "终点X，归一化0-1"],
                    "endY": ["type": "number", "description": "终点Y，归一化0-1"],
                    "duration": ["type": "number", "description": "拖拽时长(秒)，默认1.0"]
                ],
                "required": ["startX", "startY", "endX", "endY"]
            ]
        ],
        [
            "name": "get_element_at_point",
            "description": "获取屏幕指定坐标位置的UI元素信息",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "x": ["type": "number", "description": "X坐标，归一化0-1"],
                    "y": ["type": "number", "description": "Y坐标，归一化0-1"]
                ],
                "required": ["x", "y"]
            ]
        ],

        // ═══════════════════════════════════════
        // 2. 物理按键 (7个)
        // ═══════════════════════════════════════
        [
            "name": "press_home",
            "description": "按下Home键（返回主屏幕）",
            "inputSchema": ["type": "object", "properties": [:]]
        ],
        [
            "name": "press_power",
            "description": "按下电源键（锁屏/唤醒）",
            "inputSchema": ["type": "object", "properties": [:]]
        ],
        [
            "name": "press_volume_up",
            "description": "按下音量+键",
            "inputSchema": ["type": "object", "properties": [:]]
        ],
        [
            "name": "press_volume_down",
            "description": "按下音量-键",
            "inputSchema": ["type": "object", "properties": [:]]
        ],
        [
            "name": "press_key",
            "description": "按下指定按键（支持特殊键名）",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "key": ["type": "string", "description": "按键名称，如home/power/volumeUp/volumeDown"]
                ],
                "required": ["key"]
            ]
        ],
        [
            "name": "toggle_mute",
            "description": "切换静音开关",
            "inputSchema": ["type": "object", "properties": [:]]
        ],
        [
            "name": "wake_and_home",
            "description": "唤醒屏幕并回到主屏幕（先按电源键唤醒，再按Home键）",
            "inputSchema": ["type": "object", "properties": [:]]
        ],

        // ═══════════════════════════════════════
        // 3. 截图与屏幕信息 (3个)
        // ═══════════════════════════════════════
        [
            "name": "screenshot",
            "description": "截取当前屏幕截图并返回压缩后的JPEG图片",
            "inputSchema": ["type": "object", "properties": [:]]
        ],
        [
            "name": "get_screen_info",
            "description": "获取当前屏幕尺寸、缩放因子和前台App信息",
            "inputSchema": ["type": "object", "properties": [:]]
        ],
        [
            "name": "get_ui_elements",
            "description": "获取当前屏幕UI元素树（辅助功能树），用于定位和操作界面元素",
            "inputSchema": ["type": "object", "properties": [:]]
        ],

        // ═══════════════════════════════════════
        // 4. 文本输入 (2个)
        // ═══════════════════════════════════════
        [
            "name": "input_text",
            "description": "输入中文或Unicode文字（粘贴板方式，适合长文本和中文）",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "text": ["type": "string", "description": "要输入的文本"]
                ],
                "required": ["text"]
            ]
        ],
        [
            "name": "type_text",
            "description": "逐字输入英文/ASCII字符（键盘模拟方式）",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "text": ["type": "string", "description": "要逐字输入的文本"]
                ],
                "required": ["text"]
            ]
        ],

        // ═══════════════════════════════════════
        // 5. 剪贴板 (2个)
        // ═══════════════════════════════════════
        [
            "name": "get_clipboard",
            "description": "获取剪贴板当前内容",
            "inputSchema": ["type": "object", "properties": [:]]
        ],
        [
            "name": "set_clipboard",
            "description": "设置剪贴板内容",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "content": ["type": "string", "description": "要复制到剪贴板的文本"]
                ],
                "required": ["content"]
            ]
        ],

        // ═══════════════════════════════════════
        // 6. App管理 (5个)
        // ═══════════════════════════════════════
        [
            "name": "launch_app",
            "description": "通过Bundle ID启动App",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "bundle_id": ["type": "string", "description": "App的Bundle ID，如com.apple.MobilePhone"]
                ],
                "required": ["bundle_id"]
            ]
        ],
        [
            "name": "kill_app",
            "description": "强制关闭指定App",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "bundle_id": ["type": "string", "description": "要关闭的App的Bundle ID"]
                ],
                "required": ["bundle_id"]
            ]
        ],
        [
            "name": "list_apps",
            "description": "列出iPhone上已安装的所有App",
            "inputSchema": ["type": "object", "properties": [:]]
        ],
        [
            "name": "list_running_apps",
            "description": "列出当前正在运行的App",
            "inputSchema": ["type": "object", "properties": [:]]
        ],
        [
            "name": "get_frontmost_app",
            "description": "获取当前前台运行的App信息",
            "inputSchema": ["type": "object", "properties": [:]]
        ],

        // ═══════════════════════════════════════
        // 7. App安装/卸载 (2个)
        // ═══════════════════════════════════════
        [
            "name": "install_app",
            "description": "安装App（需要ipa路径）",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "ipa文件路径"]
                ],
                "required": ["path"]
            ]
        ],
        [
            "name": "uninstall_app",
            "description": "卸载指定App",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "bundle_id": ["type": "string", "description": "要卸载的App的Bundle ID"]
                ],
                "required": ["bundle_id"]
            ]
        ],

        // ═══════════════════════════════════════
        // 8. URL与设备信息 (4个)
        // ═══════════════════════════════════════
        [
            "name": "open_url",
            "description": "打开URL链接（支持http/https/tel/mailto等scheme）",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "url": ["type": "string", "description": "要打开的URL"]
                ],
                "required": ["url"]
            ]
        ],
        [
            "name": "get_device_info",
            "description": "获取设备信息（型号、系统版本、存储等）",
            "inputSchema": ["type": "object", "properties": [:]]
        ],
        [
            "name": "get_brightness",
            "description": "获取当前屏幕亮度（0.0-1.0）",
            "inputSchema": ["type": "object", "properties": [:]]
        ],
        [
            "name": "set_brightness",
            "description": "设置屏幕亮度",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "level": ["type": "number", "description": "亮度级别0.0-1.0"]
                ],
                "required": ["level"]
            ]
        ],

        // ═══════════════════════════════════════
        // 9. 音量控制 (2个)
        // ═══════════════════════════════════════
        [
            "name": "get_volume",
            "description": "获取当前音量（0.0-1.0）",
            "inputSchema": ["type": "object", "properties": [:]]
        ],
        [
            "name": "set_volume",
            "description": "设置音量",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "level": ["type": "number", "description": "音量级别0.0-1.0"]
                ],
                "required": ["level"]
            ]
        ],

        // ═══════════════════════════════════════
        // 10. Shell命令 (1个)
        // ═══════════════════════════════════════
        [
            "name": "run_command",
            "description": "在iPhone上执行shell命令（root权限，可执行任意命令）",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "command": ["type": "string", "description": "要执行的shell命令"]
                ],
                "required": ["command"]
            ]
        ],

        // ═══════════════════════════════════════
        // 11. Tweak独有：文件操作 (4个)
        // ═══════════════════════════════════════
        [
            "name": "readFile",
            "description": "读取文件内容（支持沙盒内和沙盒外任意路径）",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "文件完整路径"]
                ],
                "required": ["path"]
            ]
        ],
        [
            "name": "writeFile",
            "description": "写入文件（覆盖写入，上限3000字。支持沙盒外路径）",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "文件完整路径"],
                    "content": ["type": "string", "description": "文件内容"]
                ],
                "required": ["path", "content"]
            ]
        ],
        [
            "name": "appendFile",
            "description": "追加内容到文件末尾（上限1000字。支持沙盒外路径）",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "文件完整路径"],
                    "content": ["type": "string", "description": "追加内容"]
                ],
                "required": ["path", "content"]
            ]
        ],
        [
            "name": "listFiles",
            "description": "列出目录下的文件和子目录（支持沙盒外路径）",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "目录路径，默认为记忆根目录"]
                ]
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
        currentProviderIndex: 0,
        providers: LLMProvider.allProviders,
        memoryPath: "/var/mobile/StarCoreAgent",
        systemPromptOverride: ""
    )
}
