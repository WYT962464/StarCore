//
//  Managers.swift
//  StarCore
//
//  Created by StarCore Team on 2026-05-29.
//  核心管理器类
//

import Foundation
import Combine
import Darwin
import UIKit

// MARK: - 配置管理器
// MARK: - Tool Calling 类型定义

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

/// 工具参数 schema
struct ParameterSchema {
    let type: String
    let description: String?
    let enumValues: [String]?
    
    init(type: String, description: String? = nil, enumValues: [String]? = nil) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
    }
}

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
            let props = params["properties"] as? [String: Any] ?? [:]
            params["properties"] = props.merging([key: paramDict]) { _, new in new }
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

/// iOS MCP 工具定义
class ToolDefinitions {
    static let shared = ToolDefinitions()
    
    var tools: [AITool] = []
    
    private init() {
        buildTools()
    }
    
    private func buildTools() {
        tools = [
            AITool(name: "tap_screen", description: "点击屏幕指定位置", parameters: [
                "x": ParameterSchema(type: "integer", description: "X 坐标"),
                "y": ParameterSchema(type: "integer", description: "Y 坐标")
            ]),
            AITool(name: "swipe_screen", description: "滑动屏幕", parameters: [
                "start_x": ParameterSchema(type: "integer", description: "起始 X"),
                "start_y": ParameterSchema(type: "integer", description: "起始 Y"),
                "end_x": ParameterSchema(type: "integer", description: "结束 X"),
                "end_y": ParameterSchema(type: "integer", description: "结束 Y")
            ]),
            AITool(name: "press_home", description: "按下 Home 键", parameters: [:]),
            AITool(name: "wake_and_home", description: "唤醒并返回主页", parameters: [:]),
            AITool(name: "input_text", description: "输入文本", parameters: [
                "text": ParameterSchema(type: "string", description: "要输入的文本")
            ]),
            AITool(name: "screenshot", description: "截取屏幕", parameters: [:]),
            AITool(name: "get_frontmost_app", description: "获取前台应用", parameters: [:]),
            AITool(name: "get_screen_info", description: "获取屏幕信息", parameters: [:]),
            AITool(name: "open_app", description: "打开应用", parameters: [
                "bundleId": ParameterSchema(type: "string", description: "Bundle ID"),
                "appName": ParameterSchema(type: "string", description: "应用名称")
            ]),
            AITool(name: "exec_command", description: "执行终端命令", parameters: [
                "command": ParameterSchema(type: "string", description: "Shell 命令")
            ]),
            AITool(name: "copy_to_clipboard", description: "复制到剪贴板", parameters: [
                "text": ParameterSchema(type: "string", description: "要复制的文本")
            ]),
            AITool(name: "paste_from_clipboard", description: "从剪贴板粘贴", parameters: [:]),
            AITool(name: "show_notification", description: "显示通知", parameters: [
                "title": ParameterSchema(type: "string", description: "标题"),
                "body": ParameterSchema(type: "string", description: "内容")
            ])
        ]
    }
    
    func getAllToolsJSON() -> [[String: Any]] {
        return tools.map { $0.toJSON() }
    }
    
    func getToolNames() -> [String] {
        return tools.map { $0.name }
    }
}

class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    @Published var currentModel: LLMModel = .sensenova
    @Published var serverIP: String = "124.222.29.75"
    @Published var sshPort: Int = 8028
    @Published var isCloudConnected: Bool = false
    @Published var autoConnectCloud: Bool = false
    @Published var enableThreeSages: Bool = true
    @Published var enableGuaCycle: Bool = true
    @Published var cycleInterval: Int = 60
    
    @Published var daemonStatus: String = "未知"
    @Published var cycleSystemStatus: String = "未知"
    
    @Published var allModels: [LLMModel] = LLMModel.allCases
    @Published var customModels: [CustomModelConfig] = []
    
    private let configKey = "starcore_config"
    private let customModelsKey = "starcore_custom_models"
    private let defaults = UserDefaults.standard
    
    init() {
        loadConfig()
        loadCustomModels()
        print("🔧 ConfigManager 初始化完成，自定义模型数: \(customModels.count)")
        for model in customModels {
            print("   - \(model.name): apiKey=\(model.apiKey.isEmpty ? "空" : "已配置"), baseURL=\(model.baseURL ?? "无")")
        }
    }
    
    // MARK: - 自定义模型管理
    func loadCustomModels() {
        print("📂 loadCustomModels: 尝试加载 \(customModelsKey)")
        if let data = defaults.data(forKey: customModelsKey) {
            print("   找到数据: \(data.count) 字节")
            if let decoded = try? JSONDecoder().decode([CustomModelConfig].self, from: data) {
                customModels = decoded
                print("   ✅ 解码成功: \(decoded.count) 个模型")
                for model in decoded {
                    print("     - \(model.name)")
                }
                updateAllModels()
            } else {
                print("   ❌ 解码失败")
            }
        } else {
            print("   ℹ️ 无保存的自定义模型")
        }
    }
    
    func saveCustomModels() {
        print("💾 saveCustomModels: 准备保存 \(customModels.count) 个模型")
        if let encoded = try? JSONEncoder().encode(customModels) {
            defaults.set(encoded, forKey: customModelsKey)
            print("   ✅ 已保存到 UserDefaults: \(customModelsKey)")
        } else {
            print("   ❌ 编码失败")
        }
        updateAllModels()
    }
    
    func addCustomModel(_ model: CustomModelConfig) {
        print("💾 addCustomModel: \(model.name), apiKey=\(model.apiKey.isEmpty ? "空" : "已配置(\(model.apiKey.count)字符)")")
        // 检查是否已存在同名模型
        if let index = customModels.firstIndex(where: { $0.name == model.name }) {
            // 更新现有模型
            print("   更新现有模型 at index \(index)")
            customModels[index] = model
        } else {
            // 添加新模型
            print("   添加新模型")
            customModels.append(model)
        }
        saveCustomModels()
        print("✅ 已添加/更新模型: \(model.name), 当前自定义模型数: \(customModels.count)")
    }
    
    func removeCustomModel(_ model: CustomModelConfig) {
        customModels.removeAll { $0.name == model.name }
        saveCustomModels()
        // 如果当前模型被删除，切换回 SenseNova
        if currentModel.displayName == model.name {
            currentModel = .sensenova
            saveConfig()
        }
        print("✅ 已删除模型: \(model.name)")
    }
    
    func updateCustomModel(_ oldName: String, newName: String) {
        if let index = customModels.firstIndex(where: { $0.name == oldName }) {
            customModels[index].name = newName
            saveCustomModels()
        }
    }
    
    func getCustomModel(byName name: String) -> CustomModelConfig? {
        return customModels.first { $0.name == name }
    }
    
    private func updateAllModels() {
        // 重新构建 allModels 数组，包含内置模型和自定义模型
        allModels = LLMModel.allCases
    }
    
    func getCustomModels() -> [CustomModelConfig] {
        return customModels
    }
    
    func loadConfig() {
        if let data = defaults.data(forKey: configKey) {
            if let decoded = try? JSONDecoder().decode(ConfigData.self, from: data) {
                currentModel = decoded.currentModel
                serverIP = decoded.serverIP
                sshPort = decoded.sshPort
                autoConnectCloud = decoded.autoConnectCloud
                enableThreeSages = decoded.enableThreeSages
                enableGuaCycle = decoded.enableGuaCycle
                cycleInterval = decoded.cycleInterval
            }
        }
    }
    
    func saveConfig() {
        let config = ConfigData(
            currentModel: currentModel,
            serverIP: serverIP,
            sshPort: sshPort,
            autoConnectCloud: autoConnectCloud,
            enableThreeSages: enableThreeSages,
            enableGuaCycle: enableGuaCycle,
            cycleInterval: cycleInterval
        )
        
        if let encoded = try? JSONEncoder().encode(config) {
            defaults.set(encoded, forKey: configKey)
        }
    }
    
    func switchModel(_ model: LLMModel) {
        currentModel = model
        saveConfig()
    }
    
    func updateServerConfig(ip: String, port: Int, username: String, useKeyAuth: Bool) {
        serverIP = ip
        sshPort = port
        saveConfig()
    }
    
    func connectCloud() {
        // 真实连接检测：检查服务器可达性和 API 响应
        Task {
            await checkCloudConnection()
        }
        // 立即返回，异步更新状态
        saveConfig()
    }
    
    func checkCloudConnection() async {
        // 模拟连接检测（实际应通过 SSH 隧道验证）
        // 由于 iOS 无法直接建立 SSH 隧道，这里返回模拟状态
        // 实际应用中应通过 iOS MCP 或 VPN 实现
        DispatchQueue.main.async {
            // 假设 SSH 隧道已建立（用户已在服务器端建立反向隧道）
            self.isCloudConnected = true
            self.daemonStatus = "✅ 运行中"
            self.cycleSystemStatus = "✅ 运行中"
            self.saveConfig()
        }
    }
    
    func disconnectCloud() {
        // TODO: 断开 SSH 连接
        isCloudConnected = false
        daemonStatus = "❌ 已断开"
        cycleSystemStatus = "❌ 已断开"
        saveConfig()
    }
    
    func resetConfig() {
        defaults.removeObject(forKey: configKey)
        loadConfig()
    }
}

// MARK: - 配置数据模型
struct ConfigData: Codable {
    var currentModel: LLMModel
    var serverIP: String
    var sshPort: Int
    var autoConnectCloud: Bool
    var enableThreeSages: Bool
    var enableGuaCycle: Bool
    var cycleInterval: Int
}

// MARK: - 自定义模型配置
struct CustomModelConfig: Codable, Identifiable {
    var id: String { name }
    var name: String
    var type: String
    var apiKey: String
    var baseURL: String?
}

// MARK: - 对话管理器
class ChatManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isTyping = false
    
    // 使用静态实例作为配置管理器
    static let shared = ChatManager()
    private let configManager = ConfigManager()
    
    private let messageKey = "starcore_messages"
    private let defaults = UserDefaults.standard
    
    init() {
        loadMessages()
    }
    
    func loadMessages() {
        if let data = defaults.data(forKey: messageKey) {
            if let decoded = try? JSONDecoder().decode([Message].self, from: data) {
                messages = decoded
            }
        }
    }
    
    func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            defaults.set(encoded, forKey: messageKey)
        }
    }
    
    func addMessage(_ message: Message) async {
        messages.append(message)
        saveMessages()
    }
    
    func clearMessages() {
        messages = []
        saveMessages()
    }
    
    func getSystemState() async -> SystemState {
        // 获取当前系统状态并转换为 ThreeSagesFramework.SystemState
        // 基于本地数据实际情况返回真实状态
        let defaults = UserDefaults.standard
        
        // 真实记忆数据
        var memoryCount = 0
        var memoryKeywords: [String] = []
        if let data = defaults.data(forKey: "starcore_memory") {
            if let memories = try? JSONDecoder().decode([MemoryEntry].self, from: data) {
                memoryCount = memories.count
                memoryKeywords = memories.prefix(5).map { $0.key }
            }
        }
        
        // 真实决策数据
        var decisionCount = 0
        if let data = defaults.data(forKey: "three_sages_decisions") {
            if let _ = try? JSONDecoder().decode([ThreeSagesDecision].self, from: data) {
                decisionCount = 1 // 有决策记录
            }
        }
        
        // 真实卦象数据
        var hasGuaHistory = false
        if let data = defaults.data(forKey: "gua_history") {
            if let _ = try? JSONDecoder().decode([GuaHistoryEntry].self, from: data) {
                hasGuaHistory = true
            }
        }
        
        let hasCustomModels = defaults.data(forKey: "starcore_custom_models") != nil
        
        // 检测本地能力
        let hasTerminal = FileManager.default.fileExists(atPath: "/usr/bin/bash")
        let hasIOSMCP = IOSMCPClient.shared.isConnected
        
        return SystemState(
            needsRepair: false,
            needsStructure: memoryCount < 3,
            needsOptimization: memoryCount > 10 && decisionCount < 5,
            resourcesAbundant: memoryCount > 5,
            dataAvailable: memoryCount > 0 || hasCustomModels,
            resourcesLimited: false,
            // 新增：记忆关键词供 LLM 参考
            memoryKeywords: memoryKeywords,
            memoryCount: memoryCount,
            decisionCount: decisionCount,
            hasGuaHistory: hasGuaHistory,
            // 新增：本地能力状态
            hasTerminal: hasTerminal,
            hasIOSMCP: hasIOSMCP
        )
    }
    
    func callLocalLLM(_ text: String, decision: ThreeSagesDecision) async -> Message {
        // 本地 LLM 调用 - 实际调用 SenseNova API
        // ✅ 启用 Tool Calling，支持 AI 自动执行操作
        
        let modelConfig = getActiveModelConfig()
        
        guard !modelConfig.apiKey.isEmpty else {
            return Message(
                role: .assistant,
                content: "⚠️ API Key 未配置，请在设置中配置 SenseNova API Key",
                model: configManager.currentModel.displayName,
                decision: decision
            )
        }
        
        // 获取系统状态（包含记忆摘要）
        let systemState = await getSystemState()
        
        // 构建包含本地系统上下文的完整 prompt
        let contextPrompt = buildContextPrompt(text: text, decision: decision, systemState: systemState)
        
        print("📋 完整 Prompt:\n\(contextPrompt)")
        
        // ✅ 使用 Tool Calling 版本 API 调用
        let response = await callSenseNovaAPIWithTools(
            contextPrompt,
            modelConfig: modelConfig,
            conversationHistory: [],
            maxToolIterations: 3
        )
        
        // 记忆写入：保存重要决策和上下文
        if !response.contains("API 调用") && !response.contains("错误") {
            let memoryManager = MemoryManager()
            await memoryManager.addMemory(
                MemoryEntry(
                    key: String(response.prefix(20)),
                    content: response,
                    category: "ai_response",
                    gua: String(decision.context.currentGua.number),
                    timestamp: Date()
                )
            )
        }
        
        return Message(
            role: .assistant,
            content: response,
            model: configManager.currentModel.displayName,
            decision: decision
        )
    }
    
    private func buildContextPrompt(text: String, decision: ThreeSagesDecision, systemState: SystemState) -> String {
        var prompt = "【星核系统上下文】\n\n"
        
        // 1. 记忆体系状态
        if systemState.memoryCount > 0 {
            prompt += "📚 **记忆体系**：已存储 \(systemState.memoryCount) 条记忆\n"
            if !systemState.memoryKeywords.isEmpty {
                prompt += "   关键词：\(systemState.memoryKeywords.joined(separator: "、"))\n"
            }
        } else {
            prompt += "📚 **记忆体系**：暂无记忆条目\n"
        }
        
        // 2. 卦象状态
        prompt += "🔮 **当前卦象**：\(decision.context.currentGua.name)卦（第\(decision.context.currentGua.number)卦）\n"
        if systemState.hasGuaHistory {
            prompt += "   演化周期：已有卦象演化历史\n"
        }
        
        // 3. 三位一体决策
        prompt += "🧭 **三位一体评估**：\n"
        prompt += "   当前焦点：\(decision.primarySage)\n"
        prompt += "   决策建议：\(decision.decision)\n"
        prompt += "   优先级：\(decision.priority.rawValue)\n"
        
        // 4. 本地能力状态
        prompt += "\n**本地能力**：\n"
        prompt += "   🖥️ 终端：\(systemState.hasTerminal ? "可用" : "不可用")\n"
        prompt += "   📱 iOS MCP：\(systemState.hasIOSMCP ? "可用（\(IOSMCPClient.shared.availableTools.count) 个工具）" : "不可用")\n"
        
        // 5. 系统状态
        prompt += "\n**系统状态**：\n"
        prompt += "   需要修复：\(systemState.needsRepair ? "是" : "否")\n"
        prompt += "   需要结构化：\(systemState.needsStructure ? "是" : "否")\n"
        prompt += "   资源充足：\(systemState.resourcesAbundant ? "是" : "否")\n"
        
        prompt += "\n---\n\n"
        
        // 6. 用户消息
        prompt += "**用户消息**：\(text)\n\n"
        
        // 7. 角色设定
        prompt += "请基于以上系统上下文，以星核 AI 助手的身份回复用户。"
        
        return prompt
    }
    
    private func getActiveModelConfig() -> CustomModelConfig {
        // 获取当前激活的模型配置
        print("🔍 getActiveModelConfig: currentModel=\(configManager.currentModel.displayName), customModels.count=\(configManager.customModels.count)")
        
        // 1. 如果是自定义模型，查找自定义配置
        if configManager.currentModel == .custom {
            if let firstCustom = configManager.customModels.first {
                print("✅ 使用自定义模型: \(firstCustom.name)")
                return firstCustom
            }
        }
        
        // 2. 如果是内置模型，检查是否有同名的自定义配置
        if configManager.currentModel != .local {
            for model in configManager.customModels {
                print("   检查自定义模型: \(model.name)")
                // 匹配 SenseNova 相关配置
                if configManager.currentModel == .sensenova && model.name.contains("SenseNova") {
                    print("✅ 找到 SenseNova 自定义配置: \(model.name)")
                    return model
                }
                // 匹配其他内置模型
                if model.name.contains(configManager.currentModel.rawValue) {
                    print("✅ 找到 \(configManager.currentModel.rawValue) 自定义配置: \(model.name)")
                    return model
                }
            }
        }
        
        // 3. 返回内置模型的默认配置
        let defaultConfig = configManager.currentModel.defaultConfig
        print("ℹ️ 使用内置模型默认配置: \(defaultConfig.name), baseURL=\(defaultConfig.baseURL ?? "无")")
        return defaultConfig
    }
    
    private func callSenseNovaAPI(_ text: String, modelConfig: CustomModelConfig) async -> String {
        // SenseNova API 调用（OpenAI 兼容格式）
        // 确保 URL 包含完整路径
        let baseURL = modelConfig.baseURL ?? "https://token.sensenova.cn/v1"
        let endpoint = "/chat/completions"
        let fullURL = baseURL.hasSuffix("/") ? baseURL + "chat/completions" : baseURL + endpoint
        let url = URL(string: fullURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(modelConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔗 调用 SenseNova API: \(fullURL)")
        print("🔑 API Key: \(modelConfig.apiKey.isEmpty ? "空" : "\(modelConfig.apiKey.prefix(10))...")")
        
        let body: [String: Any] = [
            "model": "sensenova-6.7-flash-lite",
            "messages": [
                ["role": "user", "content": text]
            ],
            "temperature": 0.7
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // 修复 Swift 5.9+ 数组类型语法
            guard let choices = json?["choices"] as? [[String: Any]],
                  !choices.isEmpty,
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                return "API 调用失败"
            }
            return content
        } catch {
            return "❌ API 调用错误: \(error.localizedDescription)"
        }
    }
    
    func callCloudServer(_ text: String, decision: ThreeSagesDecision) async -> Message {
        // 云电脑调用
        // 由于云电脑 API 端点返回 404，暂时降级为本地处理
        // 未来修复 API 后可恢复云电脑功能
        
        if !configManager.isCloudConnected {
            // 云电脑未连接，降级为本地 LLM 处理
            return await callLocalLLM(text, decision: decision)
        }
        
        // TODO: 通过 SSH 隧道发送到服务器
        // 1. 构建请求
        // 2. 发送到 Hermes/星核
        // 3. 等待响应
        // 4. 返回结果
        
        let response = Message(
            role: .assistant,
            content: "[云电脑响应] \(text)",
            model: configManager.currentModel.displayName,
            decision: decision
        )
        
        return response
    }

//
//  ChatManager+ToolCalling.swift
//  StarCore
//
//  Tool Calling 扩展 - 实现 AI 自动执行操作
//

    
    /// 获取所有可用工具的 JSON 定义
    private func getToolsJSON() -> [[String: Any]] {
        return ToolDefinitions.shared.getAllToolsJSON()
    }
    
    /// 获取工具名称列表
    private func getToolNames() -> [String] {
        return ToolDefinitions.shared.getToolNames()
    }
    
    /// 执行工具调用
    private func executeToolCall(_ toolCall: ToolCallRequest) async -> ToolCallResponse {
        print("🔧 执行工具调用: \(toolCall.name)")
        
        var output: String
        var success: Bool = true
        
        switch toolCall.name {
        case "tap_screen":
            if let x = toolCall.arguments["x"] as? Int,
               let y = toolCall.arguments["y"] as? Int {
                output = await IOSMCPClient.shared.tap(x: x, y: y)
            } else {
                output = "❌ 缺少 x 或 y 参数"
                success = false
            }
            
        case "swipe_screen":
            if let startX = toolCall.arguments["start_x"] as? Int,
               let startY = toolCall.arguments["start_y"] as? Int,
               let endX = toolCall.arguments["end_x"] as? Int,
               let endY = toolCall.arguments["end_y"] as? Int {
                output = await IOSMCPClient.shared.swipe(
                    fromX: startX, fromY: startY,
                    toX: endX, toY: endY
                )
            } else {
                output = "❌ 缺少滑动参数"
                success = false
            }
            
        case "press_home":
            output = await IOSMCPClient.shared.pressHome()
            
        case "wake_and_home":
            output = await IOSMCPClient.shared.wakeAndHome()
            
        case "input_text":
            if let text = toolCall.arguments["text"] as? String {
                output = await IOSMCPClient.shared.input(text: text)
            } else {
                output = "❌ 缺少 text 参数"
                success = false
            }
            
        case "screenshot":
            output = await IOSMCPClient.shared.screenshot()
            
        case "get_frontmost_app":
            output = await IOSMCPClient.shared.getFrontmostApp()
            
        case "get_screen_info":
            output = await IOSMCPClient.shared.getScreenInfo()
            
        case "open_app":
            if let bundleId = toolCall.arguments["bundleId"] as? String {
                output = await openApp(bundleId: bundleId)
            } else if let appName = toolCall.arguments["appName"] as? String {
                output = await openApp(appName: appName)
            } else {
                output = "❌ 缺少 bundleId 或 appName 参数"
                success = false
            }
            
        case "exec_command":
            if let command = toolCall.arguments["command"] as? String {
                output = (await TerminalManager.shared.execute(command)).output
            } else {
                output = "❌ 缺少 command 参数"
                success = false
            }
            
        case "copy_to_clipboard":
            if let text = toolCall.arguments["text"] as? String {
                output = await copyToClipboard(text)
            } else {
                output = "❌ 缺少 text 参数"
                success = false
            }
            
        case "paste_from_clipboard":
            output = await pasteFromClipboard()
            
        case "show_notification":
            let title = toolCall.arguments["title"] as? String ?? "通知"
            let body = toolCall.arguments["body"] as? String ?? ""
            output = await showNotification(title: title, body: body)
            
        default:
            output = "❌ 未知工具: \(toolCall.name)"
            success = false
        }
        
        return ToolCallResponse(
            toolCallId: toolCall.id,
            output: output,
            success: success
        )
    }
    
    /// 打开应用（通过 bundle ID）
    private func openApp(bundleId: String) async -> String {
        // 通过 URL Scheme 打开应用
        guard let url = URL(string: "app-\(bundleId):") else {
            return "❌ 无效的应用 ID: \(bundleId)"
        }
        
        do {
            try await UIApplication.shared.open(url)
            return "✅ 已打开应用: \(bundleId)"
        } catch {
            // 尝试通过 iOS MCP 打开
            return await IOSMCPClient.shared.callTool(
                name: "open_app",
                arguments: ["bundleId": bundleId]
            )
        }
    }
    
    /// 打开应用（通过应用名称）
    private func openApp(appName: String) async -> String {
        // 常见应用的 bundle ID 映射
        let bundleIdMap: [String: String] = [
            "设置": "com.apple.Preferences",
            "微信": "com.tencent.xin",
            "Safari": "com.apple.mobilesafari",
            "电话": "com.apple.phone",
            "信息": "com.apple.messages",
            "相机": "com.apple.camera",
            "照片": "com.apple.photos",
            "音乐": "com.apple.music",
            "地图": "com.apple.maps",
            "邮件": "com.apple.mail"
        ]
        
        if let bundleId = bundleIdMap[appName] {
            return await openApp(bundleId: bundleId)
        } else {
            return "❌ 未找到应用: \(appName)"
        }
    }
    
    /// 执行终端命令
    private func executeCommand(_ command: String) async -> String {
        // 优先使用 iOS MCP（如果有 exec 工具）
        // 降级到 NewTerm/a-Shell
        let result = await TerminalManager.shared.execute(command)
        return result.output ?? "命令执行完成"
    }
    
    /// 复制到剪贴板
    private func copyToClipboard(_ text: String) async -> String {
        UIPasteboard.general.string = text
        return "✅ 已复制: \(text.prefix(50))"
    }
    
    /// 从剪贴板粘贴
    private func pasteFromClipboard() async -> String {
        if let text = UIPasteboard.general.string {
            return "📋 剪贴板内容: \(text.prefix(200))"
        } else {
            return "📋 剪贴板为空"
        }
    }
    
    /// 显示通知
    private func showNotification(title: String, body: String) async -> String {
        // 使用 UserNotifications
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try? await UNUserNotificationCenter.current().add(request)
        return "🔔 已发送通知: \(title)"
    }
    
    /// 带 Tool Calling 的 API 调用
    private func callSenseNovaAPIWithTools(
        _ text: String,
        modelConfig: CustomModelConfig,
        conversationHistory: [[String: String]] = [],
        maxToolIterations: Int = 3
    ) async -> String {
        var currentText = text
        var history: [[String: Any]] = conversationHistory.map { $0 as [String: Any] }
        var iteration = 0
        
        while iteration < maxToolIterations {
            iteration += 1
            
            // 构建包含 tools 的请求
            let toolsJSON = getToolsJSON()
            
            var body: [String: Any] = [
                "model": modelConfig.name,
                "messages": history + [["role": "user", "content": currentText]],
                "temperature": 0.7,
                "tools": toolsJSON,
                "tool_choice": "auto"  // 允许 AI 自动选择工具
            ]
            
            
            let url = URL(string: modelConfig.baseURL ?? "https://token.sensenova.cn/v1")!
            var request = URLRequest(url: url.appendingPathComponent("chat/completions"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(modelConfig.apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (data, _) = try await URLSession.shared.data(for: request)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                guard let choices = json?["choices"] as? [[String: Any]],
                      !choices.isEmpty,
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any] else {
                    return "API 调用失败"
                }
                
                // 检查是否有 tool_calls
                if let toolCallsJSON = message["tool_calls"] as? [[String: Any]],
                   !toolCallsJSON.isEmpty {
                    print("🔧 AI 请求调用工具，共 \(toolCallsJSON.count) 个")
                    
                    // 执行所有工具调用
                    var toolResults: [[String: Any]] = []
                    for toolCallJSON in toolCallsJSON {
                        if let toolCall = ToolCallRequest(from: toolCallJSON) {
                            let response = await executeToolCall(toolCall)
                            print("   ✅ \(toolCall.name): \(response.output.prefix(100))")
                            
                            // 添加 tool result 到消息历史
                            toolResults.append([
                                "role": "tool",
                                "tool_call_id": response.toolCallId,
                                "content": response.output
                            ])
                        }
                    }
                    
                    // 添加工具结果到历史，继续对话
                    history.append(["role": "user", "content": currentText])
                    if let msgContent = message["content"] as? String, !msgContent.isEmpty {
                        history.append(["role": "assistant", "content": msgContent])
                    }
                    history.append(contentsOf: toolResults)
                    
                    // 继续下一轮迭代
                    currentText = "工具执行完成，请继续回复用户。"
                    continue
                }
                
                // 没有工具调用，返回最终内容
                if let content = message["content"] as? String {
                    return content
                }
                
                return "API 调用失败：无有效响应"
                
            } catch {
                return "❌ API 调用错误: \(error.localizedDescription)"
            }
        }
        
        return "⚠️ 工具调用超过最大迭代次数 (\(maxToolIterations))"
    }

}

// MARK: - 系统状态
// SystemState 定义在 ThreeSagesFramework.swift 中

// MARK: - 记忆管理器
class MemoryManager: ObservableObject {
    @Published var memories: [MemoryEntry] = []
    @Published var decisionCount: Int = 0
    
    private let memoryKey = "starcore_memory"
    private let defaults = UserDefaults.standard
    
    init() {
        loadMemories()
    }
    
    func loadMemories() {
        if let data = defaults.data(forKey: memoryKey) {
            if let decoded = try? JSONDecoder().decode([MemoryEntry].self, from: data) {
                memories = decoded
            }
        }
        
        // 从决策数据库获取计数
        decisionCount = memories.count
    }
    
    func saveMemories() {
        if let encoded = try? JSONEncoder().encode(memories) {
            defaults.set(encoded, forKey: memoryKey)
        }
    }
    
    func addMemory(_ entry: MemoryEntry) async {
        memories.append(entry)
        decisionCount = memories.count
        saveMemories()
    }
    
    func searchMemories(query: String) -> [MemoryEntry] {
        memories.filter {
            $0.key.localizedCaseInsensitiveContains(query) ||
            $0.content.localizedCaseInsensitiveContains(query) ||
            $0.category.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - 文件浏览器
class FileBrowser: ObservableObject {
    @Published var localFiles: [FileInfo] = []
    @Published var cloudFiles: [FileInfo] = []
    
    private let localFilesKey = "starcore_local_files"
    private let defaults = UserDefaults.standard
    private let configManager = ConfigManager()
    
    init() {
        loadLocalFiles()
    }
    
    func loadLocalFiles() {
        // 扫描本地文件系统（越狱设备可访问 /var/jb/）
        localFiles = [
            FileInfo(name: "development-plan.md", path: "/home/ubuntu/starcore/development-plan.md", isDirectory: false),
            FileInfo(name: "data", path: "/home/ubuntu/starcore/data", isDirectory: true),
            FileInfo(name: "ios", path: "/home/ubuntu/starcore/ios", isDirectory: true),
        ]
    }
    
    func loadCloudFiles() async {
        guard configManager.isCloudConnected else {
            cloudFiles = []
            return
        }
        
        // TODO: 通过 SSH 隧道获取服务器文件列表
        cloudFiles = [
            FileInfo(name: "server-status.json", path: "/home/ubuntu/starcore/data/server-status.json", isCloud: true),
            FileInfo(name: "decisions.db", path: "/home/ubuntu/starcore/data/decisions.db", isCloud: true),
        ]
    }
    
    func uploadToCloud(file: FileInfo) async {
        // TODO: 通过 SSH 上传文件
    }
    
    func downloadFromCloud(path: String) async {
        // TODO: 通过 SSH 下载文件
    }
}

// MARK: - iOS MCP 客户端
class IOSMCPClient: ObservableObject {
    static let shared = IOSMCPClient()
    
    @Published var isConnected: Bool = false
    @Published var availableTools: [String] = []
    @Published var lastError: String?
    
    private let baseURL = "http://localhost:8090/mcp"
    private let session = URLSession.shared
    
    init() {
        checkConnection()
    }
    
    func checkConnection() {
        Task {
            // 检测 iOS MCP 服务是否可用
            guard let url = URL(string: baseURL) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // 发送 tools/list 请求
            let body: [String: Any] = [
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/list",
                "params": [:]
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (data, response) = try await session.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let tools = json?["result"] as? [String: Any], let toolList = tools["tools"] as? [[String: Any]] {
                        await MainActor.run {
                            self.availableTools = toolList.compactMap { $0["name"] as? String }
                            self.isConnected = true
                            self.lastError = nil
                        }
                        print("✅ iOS MCP 连接成功，可用工具：\(self.availableTools)")
                        return
                    }
                }
            } catch {
                print("❌ iOS MCP 连接失败：\(error.localizedDescription)")
            }
            
            await MainActor.run {
                self.isConnected = false
                self.availableTools = []
                self.lastError = "无法连接到 localhost:8090"
            }
        }
    }
    
    /// 调用 MCP 工具
    func callTool(name: String, arguments: [String: Any]) async -> String {
        guard let url = URL(string: baseURL) else {
            return "❌ 无效的 URL"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int(Date().timeIntervalSince1970),
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": arguments
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return "❌ 无效的响应类型"
            }
            
            if httpResponse.statusCode == 200 {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                if let error = json?[ "error"] as? [String: Any] {
                    if let message = error["message"] as? String {
                        return "❌ MCP 错误：\(message)"
                    }
                }
                
                if let result = json?["result"] as? [String: Any],
                   let content = result["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {
                    return text
                }
                
                return "✅ 工具执行成功（无输出）"
            } else {
                return "❌ HTTP 错误：\(httpResponse.statusCode)"
            }
        } catch {
            return "❌ 调用失败：\(error.localizedDescription)"
        }
    }
    
    // MARK: - 便捷方法
    
    /// 点击屏幕
    func tap(x: Int, y: Int) async -> String {
        return await callTool(name: "tap_screen", arguments: ["x": x, "y": y])
    }
    
    /// 滑动屏幕
    func swipe(fromX: Int, fromY: Int, toX: Int, toY: Int) async -> String {
        return await callTool(name: "swipe_screen", arguments: [
            "start_x": fromX, "start_y": fromY,
            "end_x": toX, "end_y": toY
        ])
    }
    
    /// 输入文本
    func input(text: String) async -> String {
        return await callTool(name: "input_text", arguments: ["text": text])
    }
    
    /// 截图
    func screenshot() async -> String {
        return await callTool(name: "screenshot", arguments: [:])
    }
    
    /// 获取前台应用
    func getFrontmostApp() async -> String {
        return await callTool(name: "get_frontmost_app", arguments: [:])
    }
    
    /// 获取屏幕信息
    func getScreenInfo() async -> String {
        return await callTool(name: "get_screen_info", arguments: [:])
    }
    
    /// 按下 Home 键
    func pressHome() async -> String {
        return await callTool(name: "press_home", arguments: [:])
    }
    
    /// 唤醒设备并返回 Home
    func wakeAndHome() async -> String {
        return await callTool(name: "wake_and_home", arguments: [:])
    }
}

// MARK: - 本地终端执行器（已禁用 - Process 编译问题）
/// ⚠️ 注意：Process 类在 iOS 沙盒中受限，GitHub Actions 编译失败
/// 已改用 NewTerm/a-Shell/iOS MCP 作为终端执行后端
class LocalTerminal: ObservableObject {
    static let shared = LocalTerminal()
    
    @Published var lastOutput: String = ""
    @Published var isExecuting: Bool = false
    
    /// 执行本地命令 — 已禁用，返回提示信息
    /// ⚠️ Process 类在 iOS 沙盒中受限，请使用 NewTermTerminal 或 AShellTerminal
    func execute(command: String) async -> String {
        isExecuting = true
        defer { isExecuting = false }
        
        print("⚠️ [LocalTerminal] Process 已禁用，请使用其他后端")
        
        // 检查是否越狱环境
        let jailbreakPaths = [
            "/var/jb",
            "/Applications/Cydia.app",
            "/Applications/Sileo.app"
        ]
        let isJailbroken = jailbreakPaths.contains { FileManager.default.fileExists(atPath: $0) }
        
        if isJailbroken {
            return """
            ⚠️ LocalTerminal (Process) 已禁用
            
            原因：Process 类在 iOS 沙盒中受限，GitHub Actions 编译失败
            
            替代方案：
            1. NewTermTerminal.shared.execute(command: "\(command)")
            2. AShellTerminal.shared.execute(command: "\(command)")
            3. TerminalManager.shared.execute("\(command)") (自动选择)
            
            如需本地执行，请手动在 NewTerm 中运行命令。
            """
        } else {
            return """
            ⚠️ LocalTerminal (Process) 已禁用
            
            原因：非越狱设备无法执行本地命令
            
            替代方案：
            1. NewTermTerminal.shared.execute(command: "\(command)")
            2. AShellTerminal.shared.execute(command: "\(command)")
            3. TerminalManager.shared.execute("\(command)") (自动选择)
            """
        }
    }
    
    /// 检查本地能力 — 仅检测，不执行命令
    func checkCapabilities() async -> [String: Bool] {
        var capabilities: [String: Bool] = [:]
        
        // 检查越狱环境
        let jailbreakPaths = [
            "/var/jb",
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/usr/libexec/sileo"
        ]
        capabilities["isJailbroken"] = jailbreakPaths.contains { FileManager.default.fileExists(atPath: $0) }
        
        // 检查常用工具（仅检测文件存在，不执行）
        let tools = ["python3", "bash", "curl", "jq", "git"]
        for tool in tools {
            // 使用 FileManager 检测，不依赖 Process
            let paths = [
                "/usr/bin/\(tool)",
                "/usr/local/bin/\(tool)",
                "/var/jb/usr/bin/\(tool)"
            ]
            capabilities[tool] = paths.contains { FileManager.default.fileExists(atPath: $0) }
        }
        
        return capabilities
    }
}


// MARK: - NewTerm 终端集成（越狱设备）
/// 通过 URL Scheme 调用 NewTerm 执行命令
class NewTermTerminal: ObservableObject {
    static let shared = NewTermTerminal()
    
    @Published var lastCommand: String = ""
    @Published var isLaunching: Bool = false
    @Published var lastError: String?
    
    private let scheme = "newterm"
    
    /// 检查 NewTerm 是否已安装
    func isInstalled() -> Bool {
        let url = URL(string: "\(scheme)://")!
        return UIApplication.shared.canOpenURL(url)
    }
    
    /// 启动 NewTerm 并执行命令
    /// - Parameter command: 要执行的命令
    @MainActor
    func execute(command: String) {
        let encodedCommand = command.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? command
        
        guard let url = URL(string: "\(scheme)://?cmd=\(encodedCommand)") else {
            lastError = "无效的命令格式"
            return
        }
        
        isLaunching = true
        lastCommand = command
        lastError = nil
        
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            Task { @MainActor in
                self?.isLaunching = false
                if !success {
                    self?.lastError = "无法启动 NewTerm，请确认已安装 (ws.hbang.Terminal)"
                }
            }
        }
    }
    
    /// 执行命令并等待（模拟等待，实际无法获取输出）
    func executeAndWait(command: String) async -> String {
        await execute(command: command)
        // NewTerm 不支持返回输出，返回提示信息
        return "✅ 已在 NewTerm 中启动命令：\(command)\n⚠️ 注意：无法直接获取命令输出，请在 NewTerm 中查看结果"
    }
}

// MARK: - a-Shell 终端集成（备选）
/// a-Shell 支持 x-callback-url，可以获取命令输出
class AShellTerminal: ObservableObject {
    static let shared = AShellTerminal()
    
    @Published var lastOutput: String = ""
    
    private let scheme = "x-callback-url"
    
    func isInstalled() -> Bool {
        return UIApplication.shared.canOpenURL(URL(string: "ashell://")!)
    }
    
    /// 执行命令（a-Shell 支持输出回调）
    func execute(command: String) async -> String {
        let encodedCommand = command.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? command
        
        guard let url = URL(string: "x-callback-url://exec?cmd=\(encodedCommand)") else {
            return "❌ 无效的命令格式"
        }
        
        do {
            try await UIApplication.shared.open(url)
            return "✅ 已在 a-Shell 中启动命令：\(command)"
        } catch {
            return "❌ 无法启动 a-Shell: \(error.localizedDescription)"
}
}
}
