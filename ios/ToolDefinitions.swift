//
//  ToolDefinitions.swift
//  StarCore
//
//  AI Tool Calling 定义 - OpenAI 兼容格式
//  将 iOS MCP 工具转换为 LLM 可理解的 schema
//

import Foundation

/// AI 工具定义
struct AITool {
    let name: String
    let description: String
    let parameters: [String: ParameterSchema]
    
    /// 转换为 OpenAI tools 格式
    func toJSON() -> [String: Any] {
        var params: [String: Any] = ["type": "object", "properties": [:]]
        
        for (key, param) in parameters {
            var paramDict: [String: Any] = ["type": param.type]
            if let desc = param.description {
                paramDict["description"] = desc
            }
            if let enumValues = param.enumValues {
                paramDict["enum"] = enumValues
            }
            params["properties"] = (params["properties"] as? [String: Any] ?? [:]).merging([key: paramDict]) { _, new in new }
        }
        
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": params
            ]
        ]
    }
}

/// 参数 schema
struct ParameterSchema {
    let type: String
    let description: String?
    let enumValues: [String]?
}

// MARK: - iOS MCP 工具定义

class ToolDefinitions {
    static let shared = ToolDefinitions()
    
    /// iOS MCP 工具列表（OpenAI 兼容格式）
    var tools: [AITool] = []
    
    private init() {
        buildTools()
    }
    
    /// 构建所有工具定义
    private func buildTools() {
        tools = [
            // === 屏幕控制工具 ===
            AITool(
                name: "tap_screen",
                description: "点击屏幕指定位置（坐标系统：左上角为 0,0）",
                parameters: [
                    "x": ParameterSchema(type: "integer", description: "X 坐标（像素）"),
                    "y": ParameterSchema(type: "integer", description: "Y 坐标（像素）")
                ]
            ),
            AITool(
                name: "swipe_screen",
                description: "滑动屏幕（用于滚动、拖拽等操作）",
                parameters: [
                    "start_x": ParameterSchema(type: "integer", description: "起始 X 坐标"),
                    "start_y": ParameterSchema(type: "integer", description: "起始 Y 坐标"),
                    "end_x": ParameterSchema(type: "integer", description: "结束 X 坐标"),
                    "end_y": ParameterSchema(type: "integer", description: "结束 Y 坐标")
                ]
            ),
            AITool(
                name: "press_home",
                description: "按下 Home 键（返回主屏幕）",
                parameters: [:]
            ),
            AITool(
                name: "wake_and_home",
                description: "唤醒设备并返回主屏幕（组合操作）",
                parameters: [:]
            ),
            
            // === 输入工具 ===
            AITool(
                name: "input_text",
                description: "输入文本（用于搜索、聊天、表单填写等）",
                parameters: [
                    "text": ParameterSchema(type: "string", description: "要输入的文本内容")
                ]
            ),
            
            // === 信息获取工具 ===
            AITool(
                name: "screenshot",
                description: "截取当前屏幕（返回图片 base64）",
                parameters: [:]
            ),
            AITool(
                name: "get_frontmost_app",
                description: "获取当前前台应用名称",
                parameters: [:]
            ),
            AITool(
                name: "get_screen_info",
                description: "获取屏幕信息（分辨率、锁屏状态等）",
                parameters: [:]
            ),
            
            // === 应用控制工具 ===
            AITool(
                name: "open_app",
                description: "打开指定应用（通过 bundle ID 或应用名称）",
                parameters: [
                    "bundleId": ParameterSchema(type: "string", description: "应用的 Bundle ID（如 com.apple.Preferences）"),
                    "appName": ParameterSchema(type: "string", description: "应用名称（备选）")
                ]
            ),
            AITool(
                name: "close_app",
                description: "关闭当前前台应用",
                parameters: [:]
            ),
            AITool(
                name: "switch_to_recent_app",
                description: "切换到最近使用的应用",
                parameters: [:]
            ),
            
            // === 系统工具 ===
            AITool(
                name: "get_battery_info",
                description: "获取电池信息（电量、充电状态）",
                parameters: [:]
            ),
            AITool(
                name: "get_network_info",
                description: "获取网络状态（WiFi/蜂窝、信号强度）",
                parameters: [:]
            ),
            AITool(
                name: "get_storage_info",
                description: "获取存储使用情况",
                parameters: [:]
            ),
            AITool(
                name: "get_memory_info",
                description: "获取内存使用情况",
                parameters: [:]
            ),
            
            // === 通知工具 ===
            AITool(
                name: "show_notification",
                description: "显示系统通知（用于提醒用户）",
                parameters: [
                    "title": ParameterSchema(type: "string", description: "通知标题"),
                    "body": ParameterSchema(type: "string", description: "通知内容"),
                    "sound": ParameterSchema(type: "string", description: "通知声音（可选）", enumValues: ["default", "none"]),
                    "badge": ParameterSchema(type: "integer", description: "角标数字（可选）")
                ]
            ),
            
            // === 终端工具（通过 iOS MCP 代理）===
            AITool(
                name: "exec_command",
                description: "在越狱终端执行命令（需要 SSH 隧道或本地终端后端）",
                parameters: [
                    "command": ParameterSchema(type: "string", description: "要执行的 Shell 命令")
                ]
            ),
            AITool(
                name: "get_terminal_output",
                description: "获取上次终端命令的输出",
                parameters: [:]
            ),
            
            // === 剪贴板工具 ===
            AITool(
                name: "copy_to_clipboard",
                description: "复制文本到剪贴板",
                parameters: [
                    "text": ParameterSchema(type: "string", description: "要复制的文本")
                ]
            ),
            AITool(
                name: "paste_from_clipboard",
                description: "从剪贴板获取文本",
                parameters: [:]
            ),
            
            // === 文件工具 ===
            AITool(
                name: "read_file",
                description: "读取文件内容（需要文件路径）",
                parameters: [
                    "path": ParameterSchema(type: "string", description: "文件绝对路径")
                ]
            ),
            AITool(
                name: "write_file",
                description: "写入文件内容",
                parameters: [
                    "path": ParameterSchema(type: "string", description: "文件绝对路径"),
                    "content": ParameterSchema(type: "string", description: "要写入的内容")
                ]
            ),
            
            // === 设置工具 ===
            AITool(
                name: "get_settings",
                description: "获取系统设置（WiFi、蓝牙、亮度等）",
                parameters: [
                    "category": ParameterSchema(type: "string", description: "设置类别", enumValues: ["wifi", "bluetooth", "brightness", "airplane", "all"])
                ]
            ),
            AITool(
                name: "set_setting",
                description: "修改系统设置",
                parameters: [
                    "key": ParameterSchema(type: "string", description: "设置键名"),
                    "value": ParameterSchema(type: "string", description: "设置值")
                ]
            )
        ]
    }
    
    /// 获取所有工具（JSON 格式）
    func getAllToolsJSON() -> [[String: Any]] {
        return tools.map { $0.toJSON() }
    }
    
    /// 获取工具名称列表
    func getToolNames() -> [String] {
        return tools.map { $0.name }
    }
    
    /// 根据名称查找工具
    func getTool(name: String) -> AITool? {
        return tools.first { $0.name == name }
    }
    
    /// 检查工具是否可用
    func isToolAvailable(name: String) -> Bool {
        return tools.first { $0.name == name } != nil
    }
}

// MARK: - Tool Calling 响应处理

/// AI 工具调用请求
struct ToolCallRequest {
    let id: String
    let name: String
    let arguments: [String: Any]
    
    /// 从 JSON 解析
    init?(from json: [String: Any]) {
        guard let id = json["id"] as? String,
              let name = json["name"] as? String,
              let arguments = json["arguments"] as? [String: Any] else {
            return nil
        }
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// AI 工具调用响应
struct ToolCallResponse {
    let toolCallId: String
    let output: String
    let success: Bool
}
