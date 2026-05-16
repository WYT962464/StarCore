import Foundation

// MARK: - XiaoZhi WSS Connection Manager
// 翻译自 xiaozhi_proxy_v2.py，用 URLSessionWebSocketTask 替代 python-websocket

class XiaoZhiManager {

    static let shared = XiaoZhiManager()

    // MARK: - State

    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }

    private(set) var state: ConnectionState = .disconnected {
        didSet { DispatchQueue.main.async { [weak self] in guard let self = self else { return }; self.onStateChanged?(self.state) } }
    }

    var onStateChanged: ((ConnectionState) -> Void)?
    var onLog: ((String) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var reconnectTimer: Timer?
    private var tokenCheckTimer: Timer?
    private var lastToken: String = ""
    private var msgIdCounter: Int = 0

    private let defaults = UserDefaults.standard
    private let tokenKey = "xiaozhiToken"
    private let mcpBase = "http://127.0.0.1:8090/mcp"
    private let wssBase = "wss://api.xiaozhi.me/mcp/?token="

    // Recent logs (最多保留20条)
    private(set) var recentLogs: [String] = []

    private init() {
        session = URLSession(configuration: .default, delegate: nil, delegateQueue: OperationQueue())
        startTokenCheckTimer()
    }

    // MARK: - Public API

    var token: String {
        get { defaults.string(forKey: tokenKey) ?? "" }
        set {
            defaults.set(newValue, forKey: tokenKey)
            if newValue != lastToken && !newValue.isEmpty {
                log("Token已更新，准备重连")
                disconnect()
                connect()
            }
        }
    }

    func connect() {
        let t = token
        guard !t.isEmpty else {
            log("未配置Token，跳过连接")
            state = .disconnected
            return
        }
        guard state != .connecting && state != .connected else { return }

        lastToken = t
        state = .connecting
        log("正在连接小智...")

        guard let url = URL(string: wssBase + t) else {
            log("❌ URL构造失败")
            state = .disconnected
            scheduleReconnect()
            return
        }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        // 开始接收消息
        receiveMessage()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        state = .disconnected
        cancelReconnect()
        log("已断开小智连接")
    }

    // MARK: - Message Loop

    private func receiveMessage() {
        guard let ws = webSocketTask, ws.state == .running else { return }
        ws.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage()  // continue loop
            case .failure(let error):
                self.log("❌ WSS接收失败: \(error.localizedDescription)")
                self.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            processJSON(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                processJSON(text)
            }
        @unknown default:
            break
        }
    }

    // MARK: - MCP Protocol (matching xiaozhi_proxy_v2.py)

    private func processJSON(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            log("⚠️ 非JSON: \(text.prefix(100))")
            return
        }

        let method = json["method"] as? String
        let id = json["id"] as? Int
        let params = json["params"] as? [String: Any]

        // 如果是通知（没有id），只处理initialized
        if id == nil {
            if method == "notifications/initialized" {
                log("✅ 收到initialized通知")
            }
            return
        }

        switch method {
        case "initialize":
            handleInitialize(id: id!)
        case "tools/list":
            handleToolsList(id: id!)
        case "tools/call":
            handleToolsCall(id: id!, params: params ?? [:])
        case "ping":
            sendResult(id: id!, result: [:])
        default:
            log("⚠️ 未知方法: \(method ?? "nil")")
            sendError(id: id!, message: "Method not found: \(method ?? "")")
        }
    }

    private func handleInitialize(id: Int) {
        log("📥 收到initialize请求")
        let result: [String: Any] = [
            "protocolVersion": "2024-11-05",
            "capabilities": ["tools": ["listChanged": false]],
            "serverInfo": ["name": "StarCore-iOS", "version": "2.1"]
        ]
        sendResult(id: id, result: result)
        log("✅ 已回复initialize")
    }

    private func handleToolsList(id: Int) {
        log("📥 收到tools/list请求，正在获取iOS MCP工具...")

        fetchMcpTools { [weak self] tools in
            guard let self = self else { return }
            if let tools = tools {
                let result: [String: Any] = ["tools": tools]
                self.sendResult(id: id, result: result)
                self.log("✅ 已注册\(tools.count)个工具给小智")
            } else {
                self.sendError(id: id, message: "Failed to fetch iOS MCP tools")
                self.log("❌ 获取iOS MCP工具失败")
            }
        }
    }

    private func handleToolsCall(id: Int, params: [String: Any]) {
        let toolName = params["name"] as? String ?? ""
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        log("📞 工具调用: \(toolName)")

        callMcpTool(name: toolName, arguments: arguments) { [weak self] resultDict in
            guard let self = self else { return }
            // 构造MCP标准的result格式
            // 直接透传MCP返回的result
            self.sendResult(id: id, result: resultDict_ysg ?? [:])
                private func handleToolsCall(id: Int, params: [String: Any]) {
        let toolName = params["name"] as? String ?? ""
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        log("📞 工具调用: \(toolName)")

        callMcpTool(name: toolName, arguments: arguments) { [weak self] resultDict in
            guard let self = self else { return }
            // 直接透传iOS MCP的result，包含content/isError等
            // resultDict是JSON字符串，解析回dict
            if let data = resultDict.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                self.sendResult(id: id, result: dict)
            } else {
                self.sendResult(id: id, result: ["content": [["type": "text", "text": resultDict]]])
            }
            self.log("✅ 工具\(toolName)调用完成")
        }
    }

    // MARK: - iOS MCP HTTP Calls

    private func fetchMcpTools(completion: @escaping ([[String: Any]]?) -> Void) {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": nextId(),
            "method": "tools/list",
            "params": [:] as [String: Any]
        ]
        postMcp(body: body) { json in
            guard let result = json?["result"] as? [String: Any],
                  let tools = result["tools"] as? [[String: Any]] else {
                completion(nil)
                return
            }
            // 简化description（截断200字符）
            let simplified = tools.map { tool -> [String: Any] in
                var t = tool
                if let desc = t["description"] as? String, desc.count > 200 {
                    t["description"] = String(desc.prefix(200)) + "..."
                }
                return t
            }
            completion(simplified)
        }
    }

    private func callMcpTool(name: String, arguments: [String: Any], completion: @escaping (String) -> Void) {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": nextId(),
            "method": "tools/call",
            "params": ["name": name, "arguments": arguments]
        ]
        postMcp(body: body) { json in
            guard let result = json?["result"] as? [String: Any] else {
                completion("Error: no result from MCP")
                return
            }
            // 提取text内容
            if let content = result["content"] as? [[String: Any]],
               let first = content.first,
               let text = first["text"] as? String {
                completion(text)
            } else if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettySorted),
                      let str = String(data: data, encoding: .utf8) {
                completion(str)
            } else {
                completion("Empty result")
            }
        }
    }

    private func postMcp(body: [String: Any], completion: @escaping ([String: Any]?) -> Void) {
        guard let url = URL(string: mcpBase),
              let data = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        request.timeoutInterval = 30

        session.dataTask(with: request) { data, _, error in
            if let error = error {
                self.log("❌ MCP请求失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil)
                return
            }
            completion(json)
        }.resume()
    }

    // MARK: - WSS Send

    private func sendResult(id: Int, result: [String: Any]) {
        let msg: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "result": result
        ]
        sendJSON(msg)
    }

    private func sendError(id: Int, message: String) {
        let msg: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "error": ["code": -32601, "message": message]
        ]
        sendJSON(msg)
    }

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { [weak self] error in
            if let error = error {
                self?.log("❌ WSS发送失败: \(error.localizedDescription)")
            }
        }
    }

    private func nextId() -> Int {
        msgIdCounter += 1
        return msgIdCounter
    }

    // MARK: - Reconnect Logic

    private func handleDisconnect() {
        guard state != .disconnected else { return }
        state = .disconnected
        webSocketTask = nil
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        cancelReconnect()
        log("⏳ 10秒后重连...")
        DispatchQueue.main.async { [weak self] in
            self?.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
                self?.connect()
            }
        }
    }

    private func cancelReconnect() {
        DispatchQueue.main.async { [weak self] in
            self?.reconnectTimer?.invalidate()
            self?.reconnectTimer = nil
        }
    }

    // MARK: - Token Auto-Check (every 60s)

    private func startTokenCheckTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.tokenCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let current = self.token
                if !current.isEmpty && current != self.lastToken {
                    self.log("🔄 检测到Token变化，重连中...")
                    self.disconnect()
                    self.connect()
                }
            }
        }
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        recentLogs.append(entry)
        if recentLogs.count > 20 { recentLogs.removeFirst(recentLogs.count - 20) }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onLog?(entry)
            print("[XiaoZhi] \(message)")
        }
    }
}
