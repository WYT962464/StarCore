import Foundation
import UIKit

// MARK: - XiaoZhi WSS Connection Manager
// 小智MCP桥接：WSS连接 → MCP协议握手 → 工具转发
// 截图特殊处理：走Tweak + 压缩，不走iOS MCP的大包base64

class XiaoZhiManager {

    static let shared = XiaoZhiManager()

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
                logMsg("Token已更新，准备重连")
                disconnect()
                connect()
            }
        }
    }

    func connect() {
        let t = token
        guard !t.isEmpty else {
            logMsg("未配置Token，跳过连接")
            state = .disconnected
            return
        }
        guard state != .connecting && state != .connected else { return }

        lastToken = t
        state = .connecting
        logMsg("正在连接小智...")

        guard let url = URL(string: wssBase + t) else {
            logMsg("URL构造失败")
            state = .disconnected
            scheduleReconnect()
            return
        }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessage()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        state = .disconnected
        cancelReconnect()
        logMsg("已断开小智连接")
    }

    // MARK: - Message Loop

    private func receiveMessage() {
        guard let ws = webSocketTask, ws.state == .running else { return }
        ws.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage()
            case .failure(let error):
                self.logMsg("WSS接收失败: \(error.localizedDescription)")
                self.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            processJSON(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) { processJSON(text) }
        @unknown default:
            break
        }
    }

    // MARK: - MCP Protocol

    private func processJSON(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logMsg("非JSON: \(text.prefix(100))")
            return
        }

        let method = json["method"] as? String
        let id = json["id"] as? Int
        let params = json["params"] as? [String: Any]

        // 通知（没有id）
        if id == nil {
            if method == "notifications/initialized" { logMsg("收到initialized通知") }
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
            logMsg("ping/pong")
        default:
            sendError(id: id!, message: "Method not found: \(method ?? "")")
        }
    }

    private func handleInitialize(id: Int) {
        logMsg("收到initialize请求")
        let result: [String: Any] = [
            "protocolVersion": "2024-11-05",
            "capabilities": ["tools": ["listChanged": false]],
            "serverInfo": ["name": "StarCore-iOS", "version": "2.2"]
        ]
        sendResult(id: id, result: result)
        logMsg("已回复initialize")
    }

    private func handleToolsList(id: Int) {
        logMsg("收到tools/list，获取iOS MCP工具...")
        fetchMcpTools { [weak self] tools in
            guard let self = self else { return }
            if let tools = tools {
                self.sendResult(id: id, result: ["tools": tools])
                self.logMsg("已注册\(tools.count)个工具给小智")
                self.state = .connected
            } else {
                self.sendError(id: id, message: "Failed to fetch iOS MCP tools")
                self.logMsg("获取iOS MCP工具失败")
            }
        }
    }

    // MARK: - Tool Call Dispatcher

    private func handleToolsCall(id: Int, params: [String: Any]) {
        let toolName = params["name"] as? String ?? ""
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        logMsg("工具调用: \(toolName)")

        // ★ 截图特殊处理：走Tweak + 压缩，不走iOS MCP大包
        if toolName == "screenshot" {
            handleScreenshot(id: id)
            return
        }

        // 其他工具照旧走iOS MCP
        callMcpTool(name: toolName, arguments: arguments) { [weak self] resultDict in
            guard let self = self else { return }
            self.sendResult(id: id, result: resultDict)
            self.logMsg("工具\(toolName)完成")
        }
    }

    // MARK: - Screenshot Special Path

    private func handleScreenshot(id: Int) {
        logMsg("截图走Tweak路径+压缩...")

        // 在后台线程执行，避免阻塞WSS接收
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var screenshotData: Data?
            var method = "未知"

            // 方案1：Tweak截图（系统级，快）
            if let tweakResult = StarCoreAgent.shared.tweakCmd(action: "screenshot", timeout: 15),
               let base64Str = tweakResult["image"] as? String ?? tweakResult["data"] as? String,
               !base64Str.isEmpty {
                screenshotData = Data(base64Encoded: base64Str)
                method = "Tweak"
            }

            // 方案2：iOS MCP截图（fallback）
            if screenshotData == nil {
                logMsg("Tweak截图失败，尝试iOS MCP...")
                let semaphore = DispatchSemaphore(value: 0)
                self.callMcpTool(name: "screenshot", arguments: [:]) { resultDict in
                    // 从iOS MCP result中提取base64
                    if let content = resultDict["content"] as? [[String: Any]],
                       let first = content.first,
                       let b64 = first["data"] as? String {
                        screenshotData = Data(base64Encoded: b64)
                        method = "iOS-MCP"
                    }
                    semaphore.signal()
                }
                _ = semaphore.wait(timeout: .now() + 30)
            }

            // 截图全部失败
            guard let rawData = screenshotData else {
                self.logMsg("截图失败：Tweak和iOS MCP均未返回数据")
                self.sendResult(id: id, result: [
                    "content": [["type": "text", "text": "截图失败：无法获取屏幕图像"]],
                    "isError": true
                ])
                return
            }

            self.logMsg("截图原始大小: \(rawData.count) bytes (\(method))")

            // ★ 压缩：缩放+JPEG，确保WSS消息不超限
            let compressed = self.compressScreenshot(rawData)
            let compressedB64 = compressed.base64EncodedString()

            self.logMsg("压缩后: \(compressed.count) bytes, base64: \(compressedB64.count) chars")

            // 保存到本地
            let filePath = MemoryManager.shared.saveScreenshot(data: rawData)

            // 返回压缩后的图片给小智
            self.sendResult(id: id, result: [
                "content": [[
                    "type": "image",
                    "data": compressedB64,
                    "mimeType": "image/jpeg"
                ]]
            ])
            self.logMsg("截图完成(\(method))，已发送压缩版")
        }
    }

    /// 压缩截图：缩放到800px宽 + JPEG quality 0.4
    /// iPhone X全屏PNG约5-8MB → 压缩后约80-150KB
    private func compressScreenshot(_ data: Data, maxWidth: CGFloat = 800, quality: CGFloat = 0.4) -> Data {
        guard let image = UIImage(data: data) else {
            logMsg("图片解码失败，返回原始数据")
            return data
        }

        let scale = maxWidth / image.size.width
        let newWidth = maxWidth
        let newHeight = image.size.height * scale
        let newSize = CGSize(width: newWidth, height: newHeight)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        if let resized = resized, let jpeg = resized.jpegData(compressionQuality: quality) {
            return jpeg
        }

        logMsg("压缩失败，返回原始数据")
        return data
    }

    // MARK: - iOS MCP HTTP Calls

    private func fetchMcpTools(completion: @escaping ([[String: Any]]?) -> Void) {
        let body: [String: Any] = [
            "jsonrpc": "2.0", "id": nextId(),
            "method": "tools/list", "params": [:] as [String: Any]
        ]
        postMcp(body: body) { json in
            guard let result = json?["result"] as? [String: Any],
                  let tools = result["tools"] as? [[String: Any]] else {
                completion(nil)
                return
            }
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

    private func callMcpTool(name: String, arguments: [String: Any], completion: @escaping ([String: Any]) -> Void) {
        let body: [String: Any] = [
            "jsonrpc": "2.0", "id": nextId(),
            "method": "tools/call",
            "params": ["name": name, "arguments": arguments]
        ]
        postMcp(body: body) { json in
            if let result = json?["result"] as? [String: Any] {
                completion(result)
            } else {
                completion(["content": [["type": "text", "text": "MCP调用失败"]], "isError": true])
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
        // ★ 截图等工具可能返回大数据，给足超时
        request.timeoutInterval = 60

        session.dataTask(with: request) { data, _, error in
            if let error = error {
                self.logMsg("MCP请求失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.logMsg("MCP响应解析失败，数据大小: \(data?.count ?? 0)")
                completion(nil)
                return
            }
            completion(json)
        }.resume()
    }

    // MARK: - WSS Send

    private func sendResult(id: Int, result: [String: Any]) {
        sendJSON(["jsonrpc": "2.0", "id": id, "result": result])
    }

    private func sendError(id: Int, message: String) {
        sendJSON(["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": message]])
    }

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let text = String(data: data, encoding: .utf8) else { return }
        let sizeKB = text.count / 1024
        if sizeKB > 500 {
            logMsg("⚠️ WSS发送大消息: \(sizeKB)KB")
        }
        webSocketTask?.send(.string(text)) { [weak self] error in
            if let error = error {
                self?.logMsg("WSS发送失败: \(error.localizedDescription)")
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
        logMsg("10秒后重连...")
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
                    self.logMsg("检测到Token变化，重连中...")
                    self.disconnect()
                    self.connect()
                }
            }
        }
    }

    // MARK: - Logging

    private func logMsg(_ message: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(ts)] \(message)"
        recentLogs.append(entry)
        if recentLogs.count > 30 { recentLogs.removeFirst(recentLogs.count - 30) }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onLog?(entry)
            print("[XiaoZhi] \(message)")
        }
    }
}
