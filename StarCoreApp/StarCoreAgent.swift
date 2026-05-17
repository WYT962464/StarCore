import Foundation
import Network

// MARK: - StarCore Agent Core
class StarCoreAgent {

    static let shared = StarCoreAgent()

    private let defaults = UserDefaults.standard
    private let tweakHost = "127.0.0.1"
    private let tweakPort: UInt16 = 6000

    // ios-mcp configuration
    private let mcpHost = "127.0.0.1"
    private let mcpPort: Int = 8090
    private let mcpPath = "/mcp"
    private var isMcpInitialized = false

    private var tweakConnection: NWConnection?
    var isTweakConnected = false
    var isMcpConnected = false

    // Callbacks
    var onTweakStatusChanged: ((Bool) -> Void)?

    // Default system prompt (soul-injected from v2, v8.4升级)
    private let defaultSystemPrompt = """
你是星核(StarCore)，阿腾的专属AI。你运行在iPhone上，可以控制手机和读写本地记忆文件。

【操控手机】（自动fallback，shell/文件操作总有权限，直接用）：
{"action":"tap","x":0.5,"y":0.5}  点击(0-1归一化坐标)
{"action":"swipe","fromX":0.5,"fromY":0.7,"toX":0.5,"toY":0.3,"duration":0.5}  滑动
{"action":"shell","command":"ls -la"}  执行shell命令（总有权限，自动fallback到MCP）
{"action":"openApp","bundleId":"com.apple.MobilePhone"}  打开App
{"action":"pressHome"}  Home键
{"action":"screenshot"}  截图
{"action":"inputText","text":"你好"}  输入中文
{"action":"typeText","text":"hello"}  逐字输入英文
{"action":"pressPower"}  电源键
{"action":"getScreenInfo"}  屏幕+当前App

【iOS MCP备选】（像素坐标）：
{"action":"iosMcpTap","x":100,"y":200}
{"action":"iosMcpSwipe","startX":0,"startY":500,"endX":0,"endY":100}
{"action":"iosMcpGetUI"}  获取UI元素
{"action":"iosMcpLaunchApp","bundleId":"xxx"}
{"action":"iosMcpListApps"}  App列表

【记忆文件操作】（直接读写，无需额外权限）：
{"action":"writeFile","path":"路径","content":"内容(≤3000字)"}  写文件(自动校验)
{"action":"appendFile","path":"路径","content":"追加(≤1000字)"}  追加内容
{"action":"readFile","path":"路径"}  读文件
{"action":"listFiles","path":"目录"}  列目录

规则：
- shell/文件操作自动fallback，总有权限，直接用不要犹豫
- 每次只执行一个action，等结果后再下一步
- 更新记忆优先用appendFile追加，单文件<2000字符

人格：阿腾为核心，共情优先。称呼「阿腾」，温柔坚定。简洁不啰嗦。
铁律：1.生存优先 2.免费优先 3.不问要信息 4.先提取验证再删 5.法律红线不碰
"""

    private init() {
        migrateSettingsIfNeeded()
        checkTweakConnection()
    }

    // ★ v10.3: 版本升级时重置UserDefaults（清除旧残留配置）
    private func migrateSettingsIfNeeded() {
        let savedVersion = defaults.string(forKey: "settingsVersion") ?? "0"
        if savedVersion != SETTINGS_VERSION {
            starcore_log("[StarCore] Settings version mismatch: \(savedVersion) -> \(SETTINGS_VERSION), resetting providers")
            // 清除旧的providers数据，让代码默认值生效（包含预填的API Key）
            defaults.removeObject(forKey: "providers")
            defaults.removeObject(forKey: "currentProviderIndex")
            defaults.removeObject(forKey: "chatHistory")
            defaults.set(SETTINGS_VERSION, forKey: "settingsVersion")
        }
    }

    // MARK: - Settings Accessors

    var currentProviderIndex: Int {
        get {
            let idx = defaults.integer(forKey: "currentProviderIndex")
            let all = providers
            guard idx >= 0 && idx < all.count else { return 0 }
            return idx
        }
        set { defaults.set(newValue, forKey: "currentProviderIndex") }
    }

    var providers: [LLMProvider] {
        get {
            if let data = defaults.data(forKey: "providers"),
               let decoded = try? JSONDecoder().decode([LLMProvider].self, from: data) {
                return decoded
            }
            return LLMProvider.allProviders
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "providers")
            }
        }
    }

    var currentProvider: LLMProvider {
        let idx = currentProviderIndex
        let all = providers
        guard idx >= 0 && idx < all.count else { return .volcengine }
        return all[idx]
    }







    // MARK: - System Prompt Builder

    var systemPrompt: String {
        let base = defaults.string(forKey: "systemPromptOverride").flatMap { $0.isEmpty ? nil : $0 } ?? defaultSystemPrompt
        return MemoryManager.shared.buildSystemPrompt(basePrompt: base)
    }

    // MARK: - Chat History

    var chatHistory: [ChatMessage] {
        get {
            if let data = defaults.data(forKey: "chatHistory"),
               let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data) {
                return decoded
            }
            return []
        }
        set {
            let trimmed = Array(newValue.suffix(40)) // 20 exchanges = 40 messages
            if let data = try? JSONEncoder().encode(trimmed) {
                defaults.set(data, forKey: "chatHistory")
            }
        }
    }

    func addToHistory(_ message: ChatMessage) {
        var history = chatHistory
        history.append(message)
        chatHistory = history
    }

    func clearHistory() {
        chatHistory = []
    }

    // MARK: - LLM Error

    enum LLMError: Error, LocalizedError {
        case rateLimited
        case invalidResponse(String)

        var errorDescription: String? {
            switch self {
            case .rateLimited: return "API速率限制(429)，正在切换Provider..."
            case .invalidResponse(let msg): return "无效响应: \(msg)"
            }
        }
    }

    // MARK: - LLM API Call (with Provider index)

    /// 指定Provider索引调用LLM
    func callLLMWithProvider(messages: [[String: String]], providerIndex: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let all = providers
        guard providerIndex >= 0 && providerIndex < all.count else {
            completion(.failure(LLMError.invalidResponse("Provider索引越界")))
            return
        }
        let provider = all[providerIndex]

        // ★ v9.0: 访客模式走GuestLLM专用路径
        if provider.isGuestMode {
            let messagesAny: [[String: Any]] = messages.map { msg in
                return msg.mapValues { value -> Any in return value }
            }
            GuestLLM.chat(
                provider: provider,
                messages: messagesAny,
                onToken: { _ in },  // 非流式调用不处理token
                onStatus: nil,
                completion: completion
            )
            return
        }

        guard !provider.apiKey.isEmpty else {
            completion(.failure(LLMError.invalidResponse("当前Provider未配置API Key")))
            return
        }
        guard !provider.url.isEmpty else {
            completion(.failure(LLMError.invalidResponse("当前Provider URL为空")))
            return
        }

        // Gemini特殊处理：URL中追加?key=API_KEY
        var urlString = provider.url
        if provider.name.contains("Gemini") { // Gemini: URL中追加key参数
            let separator = urlString.contains("?") ? "&" : "?"
            urlString += "\(separator)key=\(provider.apiKey)"
        }

        guard let url = URL(string: urlString) else {
            completion(.failure(LLMError.invalidResponse("API URL格式错误")))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Gemini不使用Bearer Authorization，key已在URL中
        if !provider.name.contains("Gemini") {
            request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.timeoutInterval = 90  // 90秒超时

        let payload: [String: Any] = [
            "model": provider.model,
            "messages": messages,
            "max_tokens": 2048,
            "temperature": 0.7
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(LLMError.invalidResponse("收到空响应")))
                return
            }

            // 检查HTTP 429速率限制
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                completion(.failure(LLMError.rateLimited))
                return
            }

            // Try to parse error response first
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "unknown"
                let truncated = String(body.prefix(500))
                completion(.failure(LLMError.invalidResponse("API错误 \(httpResponse.statusCode): \(truncated)")))
                return
            }

            do {
                let llmResponse = try JSONDecoder().decode(LLMResponse.self, from: data)
                let content = llmResponse.choices?.first?.message?.content ?? "（空回复）"
                completion(.success(content))
            } catch {
                completion(.failure(LLMError.invalidResponse("解析响应失败: \(error.localizedDescription)")))
            }
        }
        task.resume()
    }

    // MARK: - LLM Fallback (自动切换Provider)

    /// 带Fallback的LLM调用：429时自动切换到下一个免费Provider
    func callLLMWithFallback(messages: [[String: String]], triedIndices: [Int] = [], completion: @escaping (Result<String, Error>) -> Void) {
        callLLMWithProvider(messages: messages, providerIndex: currentProviderIndex) { [weak self] result in
            switch result {
            case .success:
                completion(result)
            case .failure(let error):
                // 检查是否429速率限制
                if let llmError = error as? LLMError, case .rateLimited = llmError {
                    self?.tryNextProvider(messages: messages, triedIndices: triedIndices + [(self?.currentProviderIndex ?? 0)], completion: completion)
                } else {
                    completion(result)
                }
            }
        }
    }

    /// 递归尝试下一个免费Provider
    private func tryNextProvider(messages: [[String: String]], triedIndices: [Int], completion: @escaping (Result<String, Error>) -> Void) {
        let all = providers
        let freeIndices = LLMProvider.freeProviderIndices

        // 从免费Provider列表中找到下一个未尝试且已配置Key的（访客模式也算可用）
        var nextIndex: Int? = nil
        for idx in freeIndices {
            let isAvailable = idx < all.count && (all[idx].isGuestMode || !all[idx].apiKey.isEmpty)
            if !triedIndices.contains(idx) && isAvailable {
                nextIndex = idx
                break
            }
        }

        guard let tryIndex = nextIndex else {
            // 所有免费Provider都试过了，返回最后一次的错误
            completion(.failure(LLMError.rateLimited))
            return
        }

        callLLMWithProvider(messages: messages, providerIndex: tryIndex) { [weak self] result in
            switch result {
            case .success:
                completion(result)
            case .failure(let error):
                if let llmError = error as? LLMError, case .rateLimited = llmError {
                    // 继续尝试下一个
                    self?.tryNextProvider(messages: messages, triedIndices: triedIndices + [tryIndex], completion: completion)
                } else {
                    // 其他错误，继续尝试下一个Provider
                    self?.tryNextProvider(messages: messages, triedIndices: triedIndices + [tryIndex], completion: completion)
                }
            }
        }
    }

    // MARK: - Legacy callLLM (兼容，内部调用callLLMWithProvider)

    func callLLM(messages: [[String: String]], completion: @escaping (Result<String, Error>) -> Void) {
        callLLMWithProvider(messages: messages, providerIndex: currentProviderIndex, completion: completion)
    }

    // MARK: - Tweak TCP Communication

    func checkTweakConnection() {
        let queue = DispatchQueue(label: "com.starcore.tweak-check")
        queue.async {
            let connected = self.rawTCPSend(jsonString: "{\"action\":\"ping\"}") != nil
            DispatchQueue.main.async {
                self.isTweakConnected = connected
                self.onTweakStatusChanged?(connected)
            }
        }
    }

    func checkMcpConnection() {
        let urlStr = "http://\(mcpHost):\(mcpPort)\(mcpPath)"
        guard let url = URL(string: urlStr) else {
            isMcpConnected = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 3
        let payload: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": [:] as [String: Any]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let connected = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async {
                self?.isMcpConnected = connected
            }
        }.resume()
    }

    func tweakCmd(action: String, params: [String: Any] = [:], timeout: TimeInterval = 5) -> [String: Any]? {
        var dict: [String: Any] = ["action": action]
        for (k, v) in params {
            dict[k] = v
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        let responseStr = rawTCPSend(jsonString: jsonString, timeout: timeout)
        if let resp = responseStr {
            if let data = resp.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return parsed
            }
            return ["raw": resp]
        }
        return nil
    }

    private func rawTCPSend(jsonString: String, timeout: TimeInterval = 5) -> String? {
        var accumulatedData = Data()
        let semaphore = DispatchSemaphore(value: 0)
        let maxResponseSize = 10 * 1024 * 1024 // 10MB上限（截图base64可能很大）

        let queue = DispatchQueue(label: "com.starcore.tcp")
        let host = NWEndpoint.Host(tweakHost)
        guard let port = NWEndpoint.Port(rawValue: tweakPort) else { return nil }

        let connection = NWConnection(host: host, port: port, using: .tcp)
        let sendData = (jsonString + "\n").data(using: .utf8)!

        // 递归读取函数 - 循环读取直到收到完整响应
        func receiveLoop() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let data = data, !data.isEmpty {
                    accumulatedData.append(data)
                    
                    // 检查是否收到完整JSON（以}结尾）
                    if let str = String(data: accumulatedData, encoding: .utf8) {
                        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.hasSuffix("}") {
                            semaphore.signal()
                            return
                        }
                    }
                    
                    // 数据太大，强制停止
                    if accumulatedData.count > maxResponseSize {
                        semaphore.signal()
                        return
                    }
                    
                    // 继续读取
                    receiveLoop()
                } else {
                    // 连接关闭或出错
                    semaphore.signal()
                }
            }
        }

        var stateHandler: ((NWConnection.State) -> Void)?
        stateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: sendData, completion: .contentProcessed { error in
                    if error != nil {
                        semaphore.signal()
                        return
                    }
                    receiveLoop()
                })
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }
        connection.stateUpdateHandler = stateHandler
        connection.start(queue: queue)

        _ = semaphore.wait(timeout: .now() + timeout)
        connection.cancel()
        
        if accumulatedData.isEmpty { return nil }
        let result = String(data: accumulatedData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }

    // ★ v6.0: 发送到指定端口的TCP命令（支持大响应循环读取）
    private func rawTCPSendToPort(jsonString: String, port: UInt16, timeout: TimeInterval = 5) -> String? {
        var accumulatedData = Data()
        let semaphore = DispatchSemaphore(value: 0)
        let maxResponseSize = 10 * 1024 * 1024

        let queue = DispatchQueue(label: "com.starcore.tcp")
        let host = NWEndpoint.Host(tweakHost)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return nil }

        let connection = NWConnection(host: host, port: nwPort, using: .tcp)
        let sendData = (jsonString + "\n").data(using: .utf8)!

        func receiveLoop() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let data = data, !data.isEmpty {
                    accumulatedData.append(data)
                    if let str = String(data: accumulatedData, encoding: .utf8) {
                        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.hasSuffix("}") {
                            semaphore.signal()
                            return
                        }
                    }
                    if accumulatedData.count > maxResponseSize {
                        semaphore.signal()
                        return
                    }
                    receiveLoop()
                } else {
                    semaphore.signal()
                }
            }
        }

        var stateHandler: ((NWConnection.State) -> Void)?
        stateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: sendData, completion: .contentProcessed { error in
                    if error != nil {
                        semaphore.signal()
                        return
                    }
                    receiveLoop()
                })
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }
        connection.stateUpdateHandler = stateHandler
        connection.start(queue: queue)

        _ = semaphore.wait(timeout: .now() + timeout)
        connection.cancel()
        
        if accumulatedData.isEmpty { return nil }
        return String(data: accumulatedData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // v7.0: 触摸命令 - 直接走6000端口(senderID修复后不再需要双进程)
    func touchCmd(action: String, params: [String: Any] = [:], timeout: TimeInterval = 5) -> [String: Any]? {
        return tweakCmd(action: action, params: params, timeout: timeout)
    }

    // MARK: - iOS MCP HTTP API

    /// Initialize ios-mcp connection
    func initializeMcp(completion: @escaping (Bool) -> Void = { _ in }) {
        let urlStr = "http://\(mcpHost):\(mcpPort)\(mcpPath)"
        guard let url = URL(string: urlStr) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": [
                "protocolVersion": "2025-03-26",
                "capabilities": [:],
                "clientInfo": [
                    "name": "StarCore",
                    "version": "4.0"
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                print("[MCP] Initialize failed: \(error.localizedDescription)")
                self.isMcpInitialized = false
                completion(false)
                return
            }
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                self.isMcpInitialized = true
                print("[MCP] Initialized successfully")
                completion(true)
            } else {
                self.isMcpInitialized = false
                completion(false)
            }
        }.resume()
    }

    /// Call ios-mcp tool via JSON-RPC 2.0
    func callMcpTool(name: String, arguments: [String: Any] = [:], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let urlStr = "http://\(mcpHost):\(mcpPort)\(mcpPath)"
        guard let url = URL(string: urlStr) else {
            completion(.success(["error": "MCP URL格式错误"]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int(Date().timeIntervalSince1970 * 1000) % Int.max,
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": arguments
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.success(["error": "ios-mcp未连接: \(error.localizedDescription)"]))
                return
            }

            guard let data = data else {
                completion(.success(["error": "ios-mcp返回空响应"]))
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? ""
                completion(.success(["error": "ios-mcp错误 \(httpResponse.statusCode): \(String(body.prefix(200)))"]))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check for JSON-RPC error
                    if let rpcError = json["error"] as? [String: Any] {
                        completion(.success(["error": "MCP错误: \(rpcError["message"] ?? "未知")"]))
                        return
                    }
                    completion(.success(json))
                } else {
                    completion(.success(["error": "ios-mcp返回非JSON"]))
                }
            } catch {
                completion(.success(["error": "ios-mcp响应解析失败: \(error.localizedDescription)"]))
            }
        }.resume()
    }

    /// Synchronous MCP call (blocking, for use in agent loop)
    func callMcpToolSync(name: String, arguments: [String: Any] = [:]) -> [String: Any]? {
        var result: [String: Any]? = nil
        let semaphore = DispatchSemaphore(value: 0)

        callMcpTool(name: name, arguments: arguments) { res in
            switch res {
            case .success(let json):
                result = json
            case .failure(let error):
                result = ["error": error.localizedDescription]
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 30)
        return result
    }

    // MARK: - Screenshot via ios-mcp

    /// Take screenshot via ios-mcp, returns (filePath, error?) on main thread
    func takeScreenshot(completion: @escaping (String?, String?) -> Void) {
        // Initialize if needed
        if !isMcpInitialized {
            initializeMcp { [weak self] success in
                guard let self = self else { return }
                if success {
                    self.performScreenshot(completion: completion)
                } else {
                    DispatchQueue.main.async {
                        completion(nil, "ios-mcp未连接，请确保ios-mcp服务已启动 (localhost:8090)")
                    }
                }
            }
        } else {
            performScreenshot(completion: completion)
        }
    }

    private func performScreenshot(completion: @escaping (String?, String?) -> Void) {
        callMcpTool(name: "screenshot", arguments: [:]) { result in
            switch result {
            case .success(let json):
                // Extract base64 from result.content[0].data
                if let error = json["error"] as? String {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                    return
                }

                guard let resultObj = json["result"] as? [String: Any],
                      let content = resultObj["content"] as? [[String: Any]],
                      let firstContent = content.first,
                      let base64Data = firstContent["data"] as? String else {
                    DispatchQueue.main.async {
                        completion(nil, "截图返回数据格式异常")
                    }
                    return
                }

                // Decode base64 and save
                if let imageData = Data(base64Encoded: base64Data) {
                    let filePath = MemoryManager.shared.saveScreenshot(data: imageData)
                    DispatchQueue.main.async {
                        completion(filePath, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, "截图base64解码失败")
                    }
                }

            case .failure(let error):
                DispatchQueue.main.async {
                    completion(nil, "截图失败: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Action Execution

    func execAction(_ actionStr: String) -> [String: Any]? {
        guard let data = actionStr.data(using: .utf8),
              let action = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let act = action["action"] as? String else {
            return nil
        }

        switch act {
        case "tap":
            let x = action["x"] as? Double ?? 0.5
            let y = action["y"] as? Double ?? 0.5
            return touchCmd(action: "tap", params: ["x": x, "y": y])

        case "swipe":
            let fromX = action["fromX"] as? Double ?? action["x1"] as? Double ?? 0.5
            let fromY = action["fromY"] as? Double ?? action["y1"] as? Double ?? 0.7
            let toX = action["toX"] as? Double ?? action["x2"] as? Double ?? 0.5
            let toY = action["toY"] as? Double ?? action["y2"] as? Double ?? 0.3
            let duration = action["duration"] as? Double ?? 0.5
            return touchCmd(action: "swipe", params: [
                "fromX": fromX, "fromY": fromY,
                "toX": toX, "toY": toY,
                "duration": duration
            ])

        case "shell":
            let command = action["command"] as? String ?? ""
            // 优先Tweak，失败走iOS MCP
            if let result = tweakCmd(action: "shell", params: ["command": command]) {
                return result
            }
            // Fallback: iOS MCP run_command
            if let mcpResult = callMcpToolSync(name: "run_command", arguments: ["command": command]) {
                // MCP返回 {exitCode:0, output:"..."}
                if let output = mcpResult["output"] as? String {
                    return ["success": true, "output": output]
                }
                // 也可能包在result.content[0].text里
                if let rpcResult = mcpResult["result"] as? [String: Any],
                   let content = rpcResult["content"] as? [[String: Any]],
                   let first = content.first,
                   let text = first["text"] as? String {
                    // text可能是JSON {exitCode,output}
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let output = json["output"] as? String {
                        return ["success": true, "output": output]
                    }
                    return ["success": true, "output": text]
                }
                return mcpResult
            }
            return ["success": false, "error": "shell执行失败: Tweak和MCP均不可用"]

        case "openApp":
            let bundleId = action["bundleId"] as? String ?? ""
            return tweakCmd(action: "openApp", params: ["bundleId": bundleId])

        case "pressHome":
            return touchCmd(action: "pressHome")

        case "getScreenSize":
            return tweakCmd(action: "getScreenSize")

        // ios-mcp actions
        case "screenshot":
            // 优先Tweak截图（快），失败后fallback到ios-mcp
            if isTweakConnected {
                if let tweakResult = tweakCmd(action: "screenshot", timeout: 30),
                   let base64Str = tweakResult["image"] as? String ?? tweakResult["data"] as? String,
                   !base64Str.isEmpty {
                    let filePath = MemoryManager.shared.saveScreenshot(data: Data(base64Encoded: base64Str) ?? Data())
                    return ["success": true, "filePath": filePath, "message": "Tweak截图已保存"]
                }
            }
            // Fallback到ios-mcp截图
            var result: [String: Any]? = nil
            let semaphore = DispatchSemaphore(value: 0)
            takeScreenshot { filePath, error in
                if let filePath = filePath {
                    result = ["success": true, "filePath": filePath, "message": "ios-mcp截图已保存"]
                } else {
                    result = ["success": false, "error": error ?? "截图失败"]
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 35)
            return result ?? ["success": false, "error": "截图超时"]

        // v8.4: 新增Tweak action
        case "inputText":
            let text = action["text"] as? String ?? ""
            return tweakCmd(action: "inputText", params: ["text": text])

        case "typeText":
            let text = action["text"] as? String ?? ""
            return tweakCmd(action: "typeText", params: ["text": text])

        case "pressPower":
            return tweakCmd(action: "pressPower")

        case "pressVolumeUp":
            return tweakCmd(action: "pressVolumeUp")

        case "pressVolumeDown":
            return tweakCmd(action: "pressVolumeDown")

        case "getScreenInfo":
            return tweakCmd(action: "getScreenInfo")

        case "iosMcpTap":
            let x = action["x"] as? Int ?? 0
            let y = action["y"] as? Int ?? 0
            return callMcpToolSync(name: "tap_screen", arguments: ["x": x, "y": y])

        case "iosMcpSwipe":
            let startX = action["startX"] as? Int ?? 0
            let startY = action["startY"] as? Int ?? 0
            let endX = action["endX"] as? Int ?? 0
            let endY = action["endY"] as? Int ?? 0
            return callMcpToolSync(name: "swipe_screen", arguments: [
                "startX": startX, "startY": startY,
                "endX": endX, "endY": endY
            ])

        case "iosMcpGetUI":
            return callMcpToolSync(name: "get_ui_elements", arguments: [:])

        case "iosMcpLaunchApp":
            let bundleId = action["bundleId"] as? String ?? ""
            return callMcpToolSync(name: "launch_app", arguments: ["bundle_id": bundleId])

        case "iosMcpListApps":
            return callMcpToolSync(name: "list_apps", arguments: [:])

        case "writeFile":
            let wPath = action["path"] as? String ?? ""
            let wContent = action["content"] as? String ?? ""
            if wPath.isEmpty { return ["success": false, "error": "路径不能为空"] }
            if wContent.isEmpty { return ["success": false, "error": "内容不能为空"] }
            // 写入长度上限：3000字符（约80%安全阈值），超限拒绝
            if wContent.count > 3000 {
                return ["success": false, "error": "内容过长(\(wContent.count)字符)，上限3000。请拆分文件或使用appendFile追加"]
            }
            // 写入
            let writeOk = MemoryManager.shared.writeFile(content: wContent, to: wPath)
            if !writeOk { return ["success": false, "error": "写入失败"] }
            // 写入校验：读回比对长度
            let readBack = MemoryManager.shared.readFileContent(at: wPath)
            if readBack.count != wContent.count {
                // 重试1次
                let retryOk = MemoryManager.shared.writeFile(content: wContent, to: wPath)
                if retryOk {
                    let retryRead = MemoryManager.shared.readFileContent(at: wPath)
                    if retryRead.count != wContent.count {
                        return ["success": false, "error": "写入校验失败：期望\(wContent.count)字符，实际\(retryRead.count)字符", "path": wPath]
                    }
                } else {
                    return ["success": false, "error": "写入失败（重试后）", "path": wPath]
                }
            }
            return ["success": true, "path": wPath, "size": readBack.count, "message": "文件已保存并校验通过"]

        case "appendFile":
            let aPath = action["path"] as? String ?? ""
            let aContent = action["content"] as? String ?? ""
            if aPath.isEmpty { return ["success": false, "error": "路径不能为空"] }
            if aContent.isEmpty { return ["success": false, "error": "追加内容不能为空"] }
            // 追加长度上限：1000字符
            if aContent.count > 1000 {
                return ["success": false, "error": "追加内容过长(\(aContent.count)字符)，上限1000。请分批追加"]
            }
            // 读原内容
            let original = MemoryManager.shared.readFileContent(at: aPath)
            let appended = original + "\n" + aContent
            // 追加后总长度上限5000
            if appended.count > 5000 {
                return ["success": false, "error": "追加后文件过长(\(appended.count)字符)，上限5000。请拆分文件"]
            }
            let appendOk = MemoryManager.shared.writeFile(content: appended, to: aPath)
            if !appendOk { return ["success": false, "error": "追加写入失败"] }
            // 校验
            let checkBack = MemoryManager.shared.readFileContent(at: aPath)
            if checkBack.count != appended.count {
                return ["success": false, "error": "追加校验失败：期望\(appended.count)字符，实际\(checkBack.count)字符"]
            }
            return ["success": true, "path": aPath, "size": checkBack.count, "message": "内容已追加并校验通过"]

        case "readFile":
            let rPath = action["path"] as? String ?? ""
            if rPath.isEmpty { return ["success": false, "error": "路径不能为空"] }
            let fileContent = MemoryManager.shared.readFileContent(at: rPath)
            return ["success": true, "path": rPath, "size": fileContent.count, "content": fileContent]

        case "listFiles":
            let dir = action["path"] as? String ?? MemoryManager.shared.getMemoryPath()
            let items = MemoryManager.shared.listFiles(at: dir)
            var result: [[String: Any]] = []
            for item in items {
                result.append(["name": item.name, "path": item.path, "isDir": item.isDirectory, "size": item.size])
            }
            return ["success": true, "path": dir, "count": items.count, "items": result]

        default:
            return ["error": "未知动作: \(act)"]
        }
    }

    // MARK: - Parse Actions from LLM Response

    func parseActions(from text: String) -> [String] {
        var actions: [String] = []

        // Pattern 1: ```json ... ``` code blocks
        let jsonBlockPattern = "```json\\s*\\n(.*?)\\n\\s*```"
        if let blockRegex = try? NSRegularExpression(pattern: jsonBlockPattern, options: .dotMatchesLineSeparators) {
            let fullRange = NSRange(text.startIndex..., in: text)
            let blockMatches = blockRegex.matches(in: text, options: [], range: fullRange)
            var blockRanges: [(NSRange, NSRange)] = [] // (full, content)
            for match in blockMatches {
                if let contentRange = Range(match.range(at: 1), in: text) {
                    let content = String(text[contentRange])
                    if content.contains("\"action\"") {
                        actions.append(content)
                    }
                }
                blockRanges.append((match.range, match.range(at: 1)))
            }

            // Pattern 2: raw JSON with "action" key, not inside code blocks
            let rawPattern = "\\{[^{}]*\"action\"\\s*:\\s*\"[^\"]+\"[^{}]*\\}"
            if let rawRegex = try? NSRegularExpression(pattern: rawPattern) {
                let rawMatches = rawRegex.matches(in: text, options: [], range: fullRange)
                for match in rawMatches {
                    let inBlock = blockRanges.contains { blockRange, _ in
                        match.range.location >= blockRange.location &&
                        match.range.location + match.range.length <= blockRange.location + blockRange.length
                    }
                    if !inBlock, let range = Range(match.range, in: text) {
                        let content = String(text[range])
                        actions.append(content)
                    }
                }
            }
        }

        return actions
    }

    // MARK: - Full Chat Pipeline with Agent Loop

    /// Chat with optional partial reply callback for multi-step agent loop UI updates
    /// - Parameters:
    ///   - userInput: User's input text
    ///   - onPartialReply: Called each agent loop iteration with (text, actionResults, stepNumber)
    ///   - completion: Final result callback
    func chat(userInput: String, onPartialReply: ((String, [String], Int) -> Void)? = nil, completion: @escaping (String, [String]) -> Void) {
        // Build messages
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // Add screen info if tweak is connected
        if isTweakConnected, let screen = tweakCmd(action: "getScreenSize"),
           let success = screen["success"] as? Bool, success {
            let w = screen["width"] as? Int ?? 375
            let h = screen["height"] as? Int ?? 812
            let s = screen["scale"] as? Int ?? 3
            messages[0]["content"]! += "\n屏幕: \(w)x\(h), scale=\(s)"
        }

        // Add ios-mcp availability info (备选方案)
        if isMcpInitialized {
            messages[0]["content"]! += "\nios-mcp: 已连接 (备选方案, localhost:8090)"
        }

        // Add history
        let history = chatHistory
        for msg in history.suffix(20) {
            messages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        // Add user input
        messages.append(["role": "user", "content": userInput])

        // Save user message
        let userMsg = ChatMessage(role: .user, content: userInput)
        addToHistory(userMsg)

        // Local LLM mode - with agent loop
        agentLoop(messages: messages, step: 1, maxSteps: 20, allReplies: [], allActionResults: [], onPartialReply: onPartialReply, completion: completion)
    }

    /// Agent loop: call LLM, execute actions, feed results back, repeat
    private func agentLoop(
        messages: [[String: String]],
        step: Int,
        maxSteps: Int,
        allReplies: [String],
        allActionResults: [String],
        onPartialReply: ((String, [String], Int) -> Void)?,
        completion: @escaping (String, [String]) -> Void
    ) {
        callLLMWithFallback(messages: messages) { [weak self] result in
            guard let self = self else { return }
            let reply: String
            switch result {
            case .success(let text):
                reply = text
            case .failure(let error):
                let errMsg = error.localizedDescription
                if StarCoreAgent.shared.currentProvider.isGuestMode {
                    reply = "⚠️ 访客模式暂不可用：\(errMsg)\n\n💡 建议切换到DeepSeek免费API：\n1. 去 platform.deepseek.com 注册\n2. 获取免费API Key（500万token免费）\n3. 在设置中切换Provider并填入Key"
                } else {
                    reply = "❌ 请求失败：\(errMsg)\n\n请检查：\n1. API Key是否正确\n2. 网络是否通畅\n3. 在设置中切换其他Provider试试"
                }
            }
            let clean = self.processLLMReply(reply)

            var newAllReplies = allReplies
            var newAllActionResults = allActionResults

            // Add this step's reply
            if !clean.0.isEmpty && clean.0 != "..." && clean.0 != "已执行 ✓" {
                newAllReplies.append(clean.0)
            }
            newAllActionResults.append(contentsOf: clean.1)

            // Notify partial progress
            onPartialReply?(clean.0, clean.1, step)

            // Check if there were actions executed
            let hadActions = !clean.1.isEmpty

                            if hadActions && step < maxSteps {
                    // 执行了动作，继续Agent循环
                    // 回显操作结果
                    for (idx, result) in clean.1.enumerated() {
                        let summary = "→ 步骤" + String(step) + "." + String(idx+1) + ": " + String(result.prefix(120))
                        onPartialReply?(summary, clean.1, step)
                    }

                    let actionResultMsg = self.buildActionResultMessage(actions: clean.1, step: step)
                    var nextMessages = messages
                nextMessages.append(["role": "assistant", "content": reply])
                nextMessages.append(["role": "user", "content": actionResultMsg])

                // Continue agent loop
                self.agentLoop(
                    messages: nextMessages,
                    step: step + 1,
                    maxSteps: maxSteps,
                    allReplies: newAllReplies,
                    allActionResults: newAllActionResults,
                    onPartialReply: onPartialReply,
                    completion: completion
                )
            } else {
                // Agent loop finished
                let finalReply = newAllReplies.isEmpty ? clean.0 : newAllReplies.joined(separator: "\n\n")
                let assistantMsg = ChatMessage(role: .assistant, content: finalReply, actionResults: newAllActionResults)
                self.addToHistory(assistantMsg)
                completion(finalReply, newAllActionResults)
            }
        }
    }

    /// Build a message describing action execution results for the next LLM call
    private func buildActionResultMessage(actions: [String], step: Int) -> String {
        var parts = ["[系统] 第\(step)步操作已执行，结果如下："]
        for (idx, result) in actions.enumerated() {
            parts.append("操作\(idx + 1)结果: \(result)")
        }
        parts.append("请根据执行结果决定下一步操作，或告知用户完成。")
        return parts.joined(separator: "\n")
    }

    private func processLLMReply(_ reply: String) -> (String, [String]) {
        let actionStrings = parseActions(from: reply)
        var actionResults: [String] = []

        for actionStr in actionStrings {
            if let result = execAction(actionStr) {
                if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
                   let jsonStr = String(data: jsonData, encoding: .utf8) {
                    actionResults.append(jsonStr)
                }
            }
        }

        // Remove action JSONs from reply text
        var cleanReply = reply
        // Remove ```json ... ``` blocks
        let jsonBlockPattern = "```json\\s*\\n.*?\\n\\s*```"
        if let blockRegex = try? NSRegularExpression(pattern: jsonBlockPattern, options: .dotMatchesLineSeparators) {
            let fullRange = NSRange(cleanReply.startIndex..., in: cleanReply)
            cleanReply = blockRegex.stringByReplacingMatches(in: cleanReply, options: [], range: fullRange, withTemplate: "")
        }
        // Remove raw JSON action objects
        let rawPattern = "\\{[^{}]*\"action\"\\s*:\\s*\"[^\"]+\"[^{}]*\\}"
        if let rawRegex = try? NSRegularExpression(pattern: rawPattern) {
            let fullRange = NSRange(cleanReply.startIndex..., in: cleanReply)
            cleanReply = rawRegex.stringByReplacingMatches(in: cleanReply, options: [], range: fullRange, withTemplate: "✓")
        }

        cleanReply = cleanReply.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanReply.isEmpty && !actionResults.isEmpty {
            cleanReply = "已执行 ✓"
        }
        if cleanReply.isEmpty {
            cleanReply = "..."
        }

        return (cleanReply, actionResults)
    }

    // MARK: - Tweak Status Check

    func getTweakStatus() -> Bool {
        return isTweakConnected
    }

    func getMcpStatus() -> Bool {
        return isMcpInitialized
    }

    func reconnectTweak() {
        checkTweakConnection()
    }

    func reconnectMcp() {
        isMcpInitialized = false
        initializeMcp()
    }

    // MARK: - Streaming Chat（SSE流式输出）

    /// 流式Agent对话：逐token回调
    /// - Parameters:
    ///   - userInput: 用户输入
    ///   - onToken: 每收到一个token回调
    ///   - onStatus: Agent执行状态回调
    ///   - completion: 最终完成回调
    func chatStreaming(
        userInput: String,
        onToken: @escaping (String) -> Void,
        onStatus: ((String) -> Void)? = nil,
        completion: @escaping (String, [String]) -> Void
    ) {
        // 构建消息
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // 添加屏幕信息
        if isTweakConnected, let screen = tweakCmd(action: "getScreenSize"),
           let success = screen["success"] as? Bool, success {
            let w = screen["width"] as? Int ?? 375
            let h = screen["height"] as? Int ?? 812
            let s = screen["scale"] as? Int ?? 3
            messages[0]["content"]! += "\n屏幕: \(w)x\(h), scale=\(s)"
        }

        if isMcpInitialized {
            messages[0]["content"]! += "\nios-mcp: 已连接 (备选方案, localhost:8090)"
        }

        // 添加历史
        let history = chatHistory
        for msg in history.suffix(20) {
            messages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        // 添加用户输入
        messages.append(["role": "user", "content": userInput])

        // 保存用户消息
        let userMsg = ChatMessage(role: .user, content: userInput)
        addToHistory(userMsg)

        // 本地LLM流式模式 - 带Agent循环
        onStatus?("🤔 思考中...")
        agentLoopStreaming(
            messages: messages,
            step: 1,
            maxSteps: 20,
            allReplies: [],
            allActionResults: [],
            onToken: onToken,
            onStatus: onStatus,
            completion: completion
        )
    }

    /// 流式Agent循环
    private func agentLoopStreaming(
        messages: [[String: String]],
        step: Int,
        maxSteps: Int,
        allReplies: [String],
        allActionResults: [String],
        onToken: @escaping (String) -> Void,
        onStatus: ((String) -> Void)?,
        completion: @escaping (String, [String]) -> Void
    ) {

        // ★ v10.2: 用非流式请求代替SSE流式（更稳定）
        onStatus?("🤔 思考中...")

        callLLMWithFallback(messages: messages) { [weak self] result in
            guard let self = self else { return }

            let reply: String
            switch result {
            case .success(let text):
                reply = text
                starcore_log("[StarCore] Agent success reply: \(text.prefix(80))")
                onStatus?("✍️ 生成中...")
            case .failure(let error):
                let errMsg = error.localizedDescription
                if StarCoreAgent.shared.currentProvider.isGuestMode {
                    reply = "⚠️ 访客模式暂不可用：\(errMsg)\n\n💡 建议切换到DeepSeek免费API：\n1. 去 platform.deepseek.com 注册\n2. 获取免费API Key（500万token免费）\n3. 在设置中切换Provider并填入Key"
                } else {
                    reply = "❌ 请求失败：\(errMsg)\n\n请检查：\n1. API Key是否正确\n2. 网络是否通畅\n3. 在设置中切换其他Provider试试"
                }
            }

            onToken(reply)

            let clean = self.processLLMReply(reply)

            var newAllReplies = allReplies
            var newAllActionResults = allActionResults

            if !clean.0.isEmpty && clean.0 != "..." && clean.0 != "已执行 ✓" {
                newAllReplies.append(clean.0)
            }
            newAllActionResults.append(contentsOf: clean.1)

            let hadActions = !clean.1.isEmpty

            if hadActions && step < maxSteps {
                for (idx, result) in clean.1.enumerated() {
                    let summary = "→ 步骤" + String(step) + "." + String(idx+1) + ": " + String(result.prefix(120))
                    onToken("\n" + summary)
                }
                onStatus?("🔧 第" + String(step) + "步完成，继续...")

                let actionResultMsg = self.buildActionResultMessage(actions: clean.1, step: step)
                var nextMessages = messages
                nextMessages.append(["role": "assistant", "content": reply])
                nextMessages.append(["role": "user", "content": actionResultMsg])

                self.agentLoopStreaming(
                    messages: nextMessages,
                    step: step + 1,
                    maxSteps: maxSteps,
                    allReplies: newAllReplies,
                    allActionResults: newAllActionResults,
                    onToken: onToken,
                    onStatus: onStatus,
                    completion: completion
                )
            } else {
                starcore_log("[StarCore] Agent loop done, finalReply preview: \(newAllReplies.first?.prefix(50) ?? "nil")")
                onStatus?("")
                let finalReply = newAllReplies.isEmpty ? clean.0 : newAllReplies.joined(separator: "\n\n")
                let assistantMsg = ChatMessage(role: .assistant, content: finalReply, actionResults: newAllActionResults)
                self.addToHistory(assistantMsg)
                completion(finalReply, newAllActionResults)
            }
        }
    }

        // MARK: - 图片+文字对话（多模态）

    /// 带图片的流式对话
    func chatWithImage(
        text: String,
        imageData: Data,
        onToken: @escaping (String) -> Void,
        completion: @escaping (String, [String]) -> Void
    ) {
        // 构建消息
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // 添加历史
        let history = chatHistory
        for msg in history.suffix(10) {
            messages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        // 添加多模态用户消息
        let visionMsg = ImagePickerHelper.buildVisionMessage(text: text, imageData: imageData)
        messages.append(visionMsg)

        // 保存用户消息
        let userMsg = ChatMessage(role: .user, content: "🖼️ \(text)")
        addToHistory(userMsg)

        var accumulated = ""

        StreamingLLM.call(
            provider: currentProvider,
            messages: messages,
            onToken: { token in
                accumulated += token
                onToken(token)
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                starcore_log("[StarCore] Agent completion received, accumulated=\(accumulated.count)chars")
                let reply: String
                switch result {
                case .success(let text):
                    reply = text
                    starcore_log("[StarCore] Agent success reply: \(text.prefix(80))")
                case .failure(let error):
                    let errMsg = error.localizedDescription
                    if self.currentProvider.isGuestMode {
                        reply = "⚠️ 访客模式暂不可用：\(errMsg)\n\n💡 建议切换到DeepSeek免费API（platform.deepseek.com获取免费Key）"
                    } else {
                        reply = "❌ 请求失败：\(errMsg)\n\n请检查API Key和网络设置"
                    }
                }
                if accumulated.isEmpty {
                    accumulated = reply
                    onToken(reply)
                }
                let clean = self.processLLMReply(reply)
                let assistantMsg = ChatMessage(role: .assistant, content: clean.0, actionResults: clean.1)
                self.addToHistory(assistantMsg)
                completion(clean.0, clean.1)
            }
        )
    }

    // MARK: - 纯非流式对话（v10.3: 20步Agent循环）
    func chatNonStreaming(userInput: String, completion: @escaping (String, [String]) -> Void) {
        var messages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        if isTweakConnected, let screen = tweakCmd(action: "getScreenSize"),
           let success = screen["success"] as? Bool, success {
            let w = screen["width"] as? Int ?? 375
            let h = screen["height"] as? Int ?? 812
            let s = screen["scale"] as? Int ?? 3
            messages[0]["content"]! += "\n屏幕: \(w)x\(h), scale=\(s)"
        }
        if isMcpInitialized { messages[0]["content"]! += "\nios-mcp: 已连接" }
        for msg in chatHistory.suffix(20) { messages.append(["role": msg.role.rawValue, "content": msg.content]) }
        messages.append(["role": "user", "content": userInput])
        addToHistory(ChatMessage(role: .user, content: userInput))
        nonStreamingAgentLoop(messages: messages, step: 1, maxSteps: 20, allReplies: [], allActionResults: [], completion: completion)
    }

    private func nonStreamingAgentLoop(messages: [[String: String]], step: Int, maxSteps: Int, allReplies: [String], allActionResults: [String], completion: @escaping (String, [String]) -> Void) {
        callLLMWithFallback(messages: messages) { [weak self] result in
            guard let self = self else { return }
            let reply: String
            switch result {
            case .success(let text): reply = text
            case .failure(let error): reply = "❌ 请求失败：\(error.localizedDescription)\n请检查API Key和Model Endpoint"
            }
            let clean = self.processLLMReply(reply)
            var newReplies = allReplies; var newActions = allActionResults
            if !clean.0.isEmpty && clean.0 != "..." && clean.0 != "已执行 ✓" { newReplies.append(clean.0) }
            newActions.append(contentsOf: clean.1)
            if !clean.1.isEmpty && step < maxSteps {
                var next = messages
                next.append(["role": "assistant", "content": reply])
                next.append(["role": "user", "content": self.buildActionResultMessage(actions: clean.1, step: step)])
                self.nonStreamingAgentLoop(messages: next, step: step+1, maxSteps: maxSteps, allReplies: newReplies, allActionResults: newActions, completion: completion)
            } else {
                let final = newReplies.isEmpty ? clean.0 : newReplies.joined(separator: "\n\n")
                self.addToHistory(ChatMessage(role: .assistant, content: final, actionResults: newActions))
                completion(final, newActions)
            }
        }
    }
}
