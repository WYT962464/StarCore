/**
 * LLMManager.swift
 * LLM 管理器 - 多云端 AI 大脑切换
 * 
 * 支持提供商：
 * - SenseNova（商汤）
 * - 火山方舟
 * - DeepSeek
 * - 自定义 OpenAI 兼容端点
 * 
 * 功能：
 * - 提供商配置管理
 * - 费用监控（API 调用计数）
 * - 自动切换（费用阈值触发）
 * - 对话历史管理
 */

import Foundation
import Combine

@available(iOS 15.0, *)
final class LLMManager: ObservableObject {
    // MARK: - 公开属性
    @Published var currentProviderIndex: Int = 0
    @Published var providers: [LLMProvider] = []
    @Published var isStreaming: Bool = false
    @Published var lastResponse: String?
    @Published var totalTokensUsed: Int = 0
    @Published var totalCostEstimate: Double = 0.0
    
    // MARK: - 配置
    private let defaults = UserDefaults.standard
    private let providersKey = "llm_providers"
    private let currentProviderKey = "current_llm_provider"
    private let costThresholdKey = "cost_threshold"
    private let autoSwitchKey = "auto_switch_enabled"
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        loadProviders()
        loadCurrentProvider()
        setupAutoSwitch()
    }
    
    // MARK: - 提供商管理
    
    /// 加载提供商配置
    func loadProviders() {
        if let data = defaults.data(forKey: providersKey) {
            providers = (try? JSONDecoder().decode([LLMProvider].self, from: data)) ?? defaultProviders
        } else {
            providers = defaultProviders
            saveProviders()
        }
    }
    
    /// 保存提供商配置
    func saveProviders() {
        if let data = try? JSONEncoder().encode(providers) {
            defaults.set(data, forKey: providersKey)
        }
    }
    
    /// 加载当前提供商
    func loadCurrentProvider() {
        currentProviderIndex = defaults.integer(forKey: currentProviderKey)
        if currentProviderIndex >= providers.count {
            currentProviderIndex = 0
        }
    }
    
    /// 保存当前提供商
    func saveCurrentProvider() {
        defaults.set(currentProviderIndex, forKey: currentProviderKey)
    }
    
    /// 切换提供商
    func switchProvider(to index: Int) {
        guard index >= 0 && index < providers.count else { return }
        currentProviderIndex = index
        saveCurrentProvider()
        lastResponse = nil
    }
    
    /// 更新提供商配置
    func updateProvider(_ provider: LLMProvider, at index: Int) {
        guard index >= 0 && index < providers.count else { return }
        providers[index] = provider
        saveProviders()
    }
    
    /// 添加新提供商
    func addProvider(_ provider: LLMProvider) {
        providers.append(provider)
        saveProviders()
    }
    
    /// 删除提供商
    func removeProvider(at index: Int) {
        guard index >= 0 && index < providers.count else { return }
        providers.remove(at: index)
        if currentProviderIndex >= providers.count {
            currentProviderIndex = max(0, providers.count - 1)
        }
        saveProviders()
        saveCurrentProvider()
    }
    
    /// 获取当前提供商
    var currentProvider: LLMProvider {
        guard currentProviderIndex >= 0 && currentProviderIndex < providers.count else {
            return defaultProviders[0]
        }
        return providers[currentProviderIndex]
    }
    
    // MARK: - 默认提供商
    
    private var defaultProviders: [LLMProvider] {
        [
            LLMProvider(
                name: "SenseNova",
                url: "https://token.sensenova.cn/v1/chat/completions",
                model: "sensenova-6.7-flash-lite",
                apiKey: ""
            ),
            LLMProvider(
                name: "火山方舟",
                url: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
                model: "doubao-lite-4k",
                apiKey: ""
            ),
            LLMProvider(
                name: "DeepSeek",
                url: "https://api.deepseek.com/v1/chat/completions",
                model: "deepseek-chat",
                apiKey: ""
            ),
            LLMProvider(
                name: "自定义",
                url: "",
                model: "",
                apiKey: ""
            )
        ]
    }
    
    // MARK: - API 调用
    
    /// 发送消息到 LLM
    func sendMessage(_ message: String, systemPrompt: String? = nil) async throws -> String {
        let provider = currentProvider
        guard !provider.apiKey.isEmpty else {
            throw LLMError.apiKeyMissing
        }
        guard !provider.url.isEmpty else {
            throw LLMError.invalidEndpoint
        }
        
        isStreaming = true
        
        var messages: [[String: String]] = []
        if let systemPrompt = systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": message])
        
        let requestBody: [String: Any] = [
            "model": provider.model,
            "messages": messages,
            "temperature": 0.7,
            "stream": false
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw LLMError.encodingFailed
        }
        
        var request = URLRequest(url: URL(string: provider.url)!)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.connectionFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LLMError.serverError(statusCode: httpResponse.statusCode)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let messageDict = firstChoice["message"] as? [String: String],
              let content = messageDict["content"] else {
            throw LLMError.invalidResponse
        }
        
        // 更新使用统计
        if let usage = json["usage"] as? [String: Any] {
            if let tokens = usage["total_tokens"] as? Int {
                totalTokensUsed += tokens
            }
        }
        
        isStreaming = false
        lastResponse = content
        return content
    }
    
    /// 流式发送消息
    func sendMessageStream(_ message: String, systemPrompt: String? = nil, onToken: @escaping (String) -> Void) async throws {
        let provider = currentProvider
        guard !provider.apiKey.isEmpty else {
            throw LLMError.apiKeyMissing
        }
        
        isStreaming = true
        
        var messages: [[String: String]] = []
        if let systemPrompt = systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": message])
        
        let requestBody: [String: Any] = [
            "model": provider.model,
            "messages": messages,
            "temperature": 0.7,
            "stream": true
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw LLMError.encodingFailed
        }
        
        var request = URLRequest(url: URL(string: provider.url)!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        
        let (streamData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LLMError.connectionFailed
        }
        
        // 处理流式响应
        // 注意：实际实现需要使用 URLSession.webSocketTask 或自定义流处理
        isStreaming = false
    }
    
    // MARK: - 费用监控
    
    /// 获取费用阈值
    var costThreshold: Double {
        get { defaults.double(forKey: costThresholdKey) }
        set { defaults.set(newValue, forKey: costThresholdKey) }
    }
    
    /// 是否启用自动切换
    var autoSwitchEnabled: Bool {
        get { defaults.bool(forKey: autoSwitchKey) }
        set { defaults.set(newValue, forKey: autoSwitchKey) }
    }
    
    /// 检查是否需要自动切换
    func checkAutoSwitch() {
        guard autoSwitchEnabled else { return }
        guard costThreshold > 0 else { return }
        
        // 简化估算：每 1000 token ≈ 0.002 元（SenseNova 价格）
        let estimatedCost = Double(totalTokensUsed) / 1000.0 * 0.002
        
        if estimatedCost >= costThreshold {
            // 切换到下一个可用提供商
            let nextIndex = (currentProviderIndex + 1) % providers.count
            switchProvider(to: nextIndex)
        }
    }
    
    // MARK: - 自动切换设置
    
    private func setupAutoSwitch() {
        // 定时检查费用 - 使用 Timer.publish 使其可取消
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkAutoSwitch()
            }
            .store(in: &cancellables)
    }
}

// MARK: - LLM 提供商模型
struct LLMProvider: Codable, Identifiable {
    var id: String { name }
    let name: String
    var url: String
    var model: String
    var apiKey: String
    
    var isConfigured: Bool {
        !apiKey.isEmpty && !url.isEmpty
    }
}

// MARK: - 错误类型
enum LLMError: LocalizedError {
    case apiKeyMissing
    case invalidEndpoint
    case connectionFailed
    case encodingFailed
    case invalidResponse
    case serverError(statusCode: Int)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing: return "API Key 未配置"
        case .invalidEndpoint: return "无效的端点 URL"
        case .connectionFailed: return "连接失败"
        case .encodingFailed: return "请求编码失败"
        case .invalidResponse: return "无效的响应格式"
        case .serverError(let code): return "服务器错误：\(code)"
        case .timeout: return "请求超时"
        }
    }
}
