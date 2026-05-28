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
    
    private let configKey = "starcore_config"
    private let defaults = UserDefaults.standard
    
    init() {
        loadConfig()
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
        // TODO: 建立 SSH 反向隧道连接
        // 1. 检查网络可达性
        // 2. 建立 SSH 连接
        // 3. 设置端口转发
        // 4. 验证连接
        isCloudConnected = true
        daemonStatus = "✅ 运行中"
        cycleSystemStatus = "✅ 运行中"
        saveConfig()
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
    
    func addCustomModel(_ model: CustomModelConfig) {
        // TODO: 实现自定义模型添加
        print("Adding custom model: \(model.name)")
    }
    
    func removeCustomModel(_ model: CustomModelConfig) {
        // TODO: 实现自定义模型删除
    }
    
    func getCustomModels() -> [CustomModelConfig] {
        // TODO: 从配置中获取自定义模型列表
        return []
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
        return SystemState(
            needsRepair: !configManager.daemonStatus.contains("✅"),
            needsStructure: false,
            needsOptimization: false,
            resourcesAbundant: configManager.isCloudConnected,
            dataAvailable: true,
            resourcesLimited: false
        )
    }
    
    func callLocalLLM(_ text: String, decision: ThreeSagesDecision) async -> Message {
        // 本地 LLM 调用
        // TODO: 实现本地模型调用（llama.cpp 等）
        
        let response = Message(
            role: .assistant,
            content: "[本地响应] \(text)",
            model: configManager.currentModel.displayName,
            decision: decision
        )
        
        return response
    }
    
    func callCloudServer(_ text: String, decision: ThreeSagesDecision) async -> Message {
        // 云电脑调用
        guard configManager.isCloudConnected else {
            return Message(
                role: .assistant,
                content: "❌ 云电脑未连接，无法执行复杂任务",
                model: configManager.currentModel.displayName,
                decision: decision
            )
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
