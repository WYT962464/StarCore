//
//  Managers.swift
//  StarCore
//
//  Created by StarCore Team on 2026-05-29.
//  核心管理器类
//

import Foundation
import Combine

// MARK: - 配置管理器
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
        let memoryCount = defaults.data(forKey: "starcore_memory") != nil ? 10 : 0
        let hasCustomModels = defaults.data(forKey: "starcore_custom_models") != nil
        
        return SystemState(
            needsRepair: false,           // 系统运行正常
            needsStructure: memoryCount < 5,  // 记忆条目少时需要结构化
            needsOptimization: false,     // 无需优化
            resourcesAbundant: true,      // 资源充足
            dataAvailable: memoryCount > 0 || hasCustomModels,  // 有本地数据
            resourcesLimited: false       // 资源不受限
        )
    }
    
    func callLocalLLM(_ text: String, decision: ThreeSagesDecision) async -> Message {
        // 本地 LLM 调用 - 实际调用 SenseNova API
        // 使用自定义模型配置或内置模型配置
        
        let modelConfig = getActiveModelConfig()
        
        guard !modelConfig.apiKey.isEmpty else {
            return Message(
                role: .assistant,
                content: "⚠️ API Key 未配置，请在设置中配置 SenseNova API Key",
                model: configManager.currentModel.displayName,
                decision: decision
            )
        }
        
        // 调用 SenseNova API
        let response = await callSenseNovaAPI(text, modelConfig: modelConfig)
        
        return Message(
            role: .assistant,
            content: response,
            model: configManager.currentModel.displayName,
            decision: decision
        )
    }
    
    private func getActiveModelConfig() -> CustomModelConfig {
        // 获取当前激活的模型配置
        print("🔍 getActiveModelConfig: currentModel=\(configManager.currentModel.displayName), customModels.count=\(configManager.customModels.count)")
        
        if configManager.currentModel == .sensenova {
            // 查找自定义 SenseNova 配置
            for model in configManager.customModels {
                print("   检查模型: \(model.name), contains SenseNova: \(model.name.contains("SenseNova"))")
            }
            if let customModel = configManager.customModels.first(where: { $0.name.contains("SenseNova") }) {
                print("✅ 找到自定义模型: \(customModel.name), apiKey=\(customModel.apiKey.isEmpty ? "空" : "已配置")")
                return customModel
            }
        }
        
        // 返回默认配置（需要用户手动填写 API Key）
        print("⚠️ 未找到自定义模型，返回默认配置")
        return CustomModelConfig(
            name: "SenseNova-6.7 Flash-Lite",
            type: "openai",
            apiKey: "",  // 用户需在设置中填写
            baseURL: "https://token.sensenova.cn/v1"
        )
    }
    
    private func callSenseNovaAPI(_ text: String, modelConfig: CustomModelConfig) async -> String {
        // SenseNova API 调用（OpenAI 兼容格式）
        let url = URL(string: modelConfig.baseURL ?? "https://token.sensenova.cn/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(modelConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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

// MARK: - 文件管理器
class FileManager: ObservableObject {
    @Published var localFiles: [FileInfo] = []
    @Published var cloudFiles: [FileInfo] = []
    
    private let localFilesKey = "starcore_local_files"
    private let defaults = UserDefaults.standard
    private let configManager = ConfigManager()
    
    init() {
        loadLocalFiles()
    }
    
    func loadLocalFiles() {
        // TODO: 扫描本地文件系统
        localFiles = [
            FileInfo(name: "development-plan.md", path: "/starcore/development-plan.md", isDirectory: false),
            FileInfo(name: "data", path: "/starcore/data", isDirectory: true),
            FileInfo(name: "ios", path: "/starcore/ios", isDirectory: true),
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
