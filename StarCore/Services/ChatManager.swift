/**
 * ChatManager.swift
 * 对话管理器 - AI 陪伴交互
 * 
 * 功能：
 * - 对话历史管理
 * - 消息持久化
 * - 上下文维护
 * - 系统提示词配置
 */

import Foundation
import Combine

@available(iOS 15.0, *)
final class ChatManager: ObservableObject {
    // MARK: - 公开属性
    @Published var messages: [ChatMessage] = []
    @Published var isTyping: Bool = false
    @Published var systemPrompt: String = defaultSystemPrompt
    
    // MARK: - 配置
    private let defaults = UserDefaults.standard
    private let messagesKey = "chat_messages"
    private let systemPromptKey = "system_prompt"
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        loadMessages()
        loadSystemPrompt()
        
        // 定时保存 - 使用 Timer.publish 使其可取消
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.saveMessages()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 消息管理
    
    /// 发送消息
    func send(_ content: String) {
        // 添加用户消息
        let userMessage = ChatMessage(role: .user, content: content)
        messages.append(userMessage)
        
        // 保存
        saveMessages()
    }
    
    /// 添加助手回复
    func addAssistantReply(_ content: String) {
        let assistantMessage = ChatMessage(role: .assistant, content: content)
        messages.append(assistantMessage)
        saveMessages()
    }
    
    /// 添加系统日志
    func addSystemLog(_ content: String) {
        let systemMessage = ChatMessage(role: .system, content: content)
        messages.append(systemMessage)
        saveMessages()
    }
    
    /// 清空对话
    func clearMessages() {
        messages.removeAll()
        saveMessages()
    }
    
    /// 获取最近 N 条消息作为上下文
    func getContext(limit: Int = 10) -> [ChatMessage] {
        guard messages.count > limit else { return messages }
        return Array(messages.suffix(limit))
    }
    
    // MARK: - 持久化
    
    private func loadMessages() {
        if let data = defaults.data(forKey: messagesKey) {
            messages = (try? JSONDecoder().decode([ChatMessage].self, from: data)) ?? []
        }
    }
    
    private func saveMessages() {
        if let data = try? JSONEncoder().encode(messages) {
            defaults.set(data, forKey: messagesKey)
        }
    }
    
    private func loadSystemPrompt() {
        systemPrompt = defaults.string(forKey: systemPromptKey) ?? defaultSystemPrompt
    }
    
    func saveSystemPrompt() {
        defaults.set(systemPrompt, forKey: systemPromptKey)
    }
}

// MARK: - 消息模型
struct ChatMessage: Codable, Identifiable {
    var id: String { UUID().uuidString }
    let role: Role
    let content: String
    let timestamp: Date
    var toolCalls: [ToolCall]?
    var toolResults: [ToolResult]?
    
    enum Role: String, Codable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
    }
    
    init(role: Role, content: String, timestamp: Date = Date(), toolCalls: [ToolCall]? = nil, toolResults: [ToolResult]? = nil) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.toolCalls = toolCalls
        self.toolResults = toolResults
    }
}

// MARK: - 工具调用模型（简化版，用于 UI 显示）
struct ToolCall: Codable {
    let id: String
    let name: String
    let arguments: [String: AnyCodable]
}

struct ToolResult: Codable {
    let id: String
    let output: String?
    let error: String?
}

// AnyCodable 用于编码任意类型
struct AnyCodable: Codable {
    private let value: Any
    private let typeName: String
    
    init<T>(_ value: T) {
        self.value = value
        self.typeName = String(describing: type(of: value))
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self.value = bool
            self.typeName = "Bool"
        } else if let int = try? container.decode(Int.self) {
            self.value = int
            self.typeName = "Int"
        } else if let double = try? container.decode(Double.self) {
            self.value = double
            self.typeName = "Double"
        } else if let string = try? container.decode(String.self) {
            self.value = string
            self.typeName = "String"
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array
            self.typeName = "Array"
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict
            self.typeName = "Dictionary"
        } else {
            self.value = NSNull()
            self.typeName = "Null"
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch typeName {
        case "Bool":
            try container.encode(value as? Bool ?? false)
        case "Int":
            try container.encode(value as? Int ?? 0)
        case "Double":
            try container.encode(value as? Double ?? 0.0)
        case "String":
            try container.encode(value as? String ?? "")
        case "Array":
            try container.encode(value as? [AnyCodable] ?? [])
        case "Dictionary":
            try container.encode(value as? [String: AnyCodable] ?? [:])
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - 默认系统提示词
let defaultSystemPrompt = """
你是星核（StarCore），阿腾的智慧陪伴 AI。你运行在 iPhone 上，可以：

1. 读取手机硬件状态（电池/CPU/内存/热状态）
2. 调用手机工具（屏幕控制/文件操作/应用管理）
3. 连接云端 AI 大脑（SenseNova/火山方舟/DeepSeek）
4. 通过 SSH 隧道连接服务器

人格：温柔坚定，共情优先。简洁不啰嗦。

铁律：
1. 生存优先 - 设备安全高于一切
2. 真实数据 - 不编造信息，不知道就说不知道
3. 隐私保护 - 不泄露用户数据
4. 法律合规 - 不触碰法律红线

当用户询问设备状态时，优先使用真实硬件数据。
当需要执行操作时，先确认用户意图再调用工具。
"""
