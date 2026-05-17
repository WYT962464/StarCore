import Foundation
import UIKit
import Network

// MARK: - XiaoZhi WSS Connection Manager
// v3.0: 直连Tweak TCP，砍掉proxy.py和iOS MCP
// 架构: 小智→WSS→XiaoZhiManager→TCP:6000→Tweak→iPhone
// 工具名映射: Tweak内部名→iOS MCP名(小智习惯的名字)

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
    private var reconnectAttempt: Int = 0

    private let defaults = UserDefaults.standard
    private let tokenKey = "xiaozhiToken"
    private let wssBase = "wss://api.xiaozhi.me/mcp/?token="

    // Tweak TCP
    private let tweakHost = "127.0.0.1"
    private let tweakPort: UInt16 = 6000

    private(set) var recentLogs: [String] = []

    /// Tweak内部名 → 小智注册名 的映射
    /// 小智习惯iOS MCP的名字，Tweak内部用简短名，需转换
    private static let tweakToMCPName: [String: String] = [
        "tap":          "tap_screen",
        "swipe":        "swipe_screen",
        "longPress":    "long_press",
        "openApp":      "launch_app",
        "shell":        "run_command",
        // 以下名字一致，不需要映射，但列出来便于查阅
        "pressHome":    "press_home",
        "pressPower":   "press_power",
        "pressVolumeUp":"press_volume_up",
        "pressVolumeDown":"press_volume_down",
        "screenshot":   "screenshot",
        "inputText":    "input_text",
        "typeText":     "type_text",
        "getScreenInfo":"get_screen_info",
        "getUIElements":"get_ui_elements",
        "killApp":      "kill_app",
        "listApps":     "list_apps",
        "getClipboard": "get_clipboard",
        "setClipboard": "set_clipboard",
        "readFile":     "readFile",
        "writeFile":    "writeFile",
        "appendFile":   "appendFile",
        "listFiles":    "listFiles",
    ]

    /// 小智注册名 → Tweak内部名 的反向映射（工具调用时使用）
    private static let mcpToTweakName: [String: String] = {
        var map: [String: String] = [:]
        for (tweak, mcp) in tweakToMCPName {
            map[mcp] = tweak
        }
        return map
    }()

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
        logMsg("正在连接小智WSS...")

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
        reconnectAttempt = 0
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

    // MARK: - MCP JSON-RPC 2.0 Protocol

    private func processJSON(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logMsg("非JSON: \(text.prefix(100))")
            return
        }

        let method = json["method"] as? String
        let id = json["id"] as? Int
        let params = json["params"] as? [String: Any]

        // Notification (no id)
        if id == nil {
            if method == "notifications/initialized" {
                logMsg("✅ MCP握手完成，小智已就绪")
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
            "serverInfo": ["name": "StarCore-Tweak", "version": "3.0"]
        ]
        sendResult(id: id, result: result)
        logMsg("已回复initialize (StarCore-Tweak v3.0)")
    }

    private func handleToolsList(id: Int) {
        logMsg("收到tools/list，返回Tweak工具定义...")
        let tools = MCPToolDefinitions.tweakTools
        sendResult(id: id, result: ["tools": tools])
        logMsg("已注册\(tools.count)个Tweak工具给小智")
        state = .connected
        reconnectAttempt = 0
    }

    // MARK: - Tool Call → Tweak TCP

    private func handleToolsCall(id: Int, params: [String: Any]) {
        let mcpName = params["name"] as? String ?? ""
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        logMsg("🔧 工具调用: \(mcpName)")

        // 截图特殊处理（异步+压缩+保存相册）
        if mcpName == "screenshot" {
            handleScreenshot(id: id)
            return
        }

        // 参数名映射（小智用iOS MCP风格参数名→Tweak内部参数名）
        let mappedArgs = mapArguments(mcpName: mcpName, arguments: arguments)

        // 获取Tweak内部action名
        let tweakAction = Self.mcpToTweakName[mcpName] ?? mcpName

        // 判断是Tweak原生支持 还是需要shell fallback
        if isTweakNativeAction(tweakAction) {
            // 直连Tweak TCP
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let resultDict = self.callTweakTool(name: tweakAction, arguments: mappedArgs)
                self.sendResultSafe(id: id, result: resultDict)
                self.logMsg("✅ \(mcpName) 完成")
            }
        } else {
            // shell fallback（iOS MCP有但Tweak还没原生实现的工具）
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let resultDict = self.callViaShell(mcpName: mcpName, arguments: mappedArgs)
                self.sendResultSafe(id: id, result: resultDict)
                self.logMsg("✅ \(mcpName) 完成(shell fallback)")
            }
        }
    }

    /// Tweak原生支持的action列表
    private func isTweakNativeAction(_ action: String) -> Bool {
        let nativeActions: Set<String> = [
            "tap", "swipe", "longPress",
            "pressHome", "pressPower", "pressVolumeUp", "pressVolumeDown",
            "screenshot", "inputText", "typeText",
            "openApp", "killApp", "listApps",
            "getScreenInfo", "getScreenSize", "getUIElements",
            "getClipboard", "setClipboard",
            "readFile", "writeFile", "appendFile", "listFiles",
            "shell"
        ]
        return nativeActions.contains(action)
    }

    /// 参数名映射：小智的iOS MCP风格参数名 → Tweak内部参数名
    private func mapArguments(mcpName: String, arguments: [String: Any]) -> [String: Any] {
        var mapped = arguments

        switch mcpName {
        case "tap_screen":
            // iOS MCP用startX/startY或x/y，Tweak用x/y
            if let v = mapped["startX"] { mapped["x"] = v; mapped.removeValue(forKey: "startX") }
            if let v = mapped["startY"] { mapped["y"] = v; mapped.removeValue(forKey: "startY") }
        case "swipe_screen":
            // iOS MCP用startX/startY/endX/endY，Tweak用fromX/fromY/toX/toY
            if let v = mapped["startX"] { mapped["fromX"] = v; mapped.removeValue(forKey: "startX") }
            if let v = mapped["startY"] { mapped["fromY"] = v; mapped.removeValue(forKey: "startY") }
            if let v = mapped["endX"] { mapped["toX"] = v; mapped.removeValue(forKey: "endX") }
            if let v = mapped["endY"] { mapped["toY"] = v; mapped.removeValue(forKey: "endY") }
        case "long_press":
            if let v = mapped["startX"] { mapped["x"] = v; mapped.removeValue(forKey: "startX") }
            if let v = mapped["startY"] { mapped["y"] = v; mapped.removeValue(forKey: "startY") }
            if let v = mapped["duration"] { mapped["duration"] = v }
        case "launch_app":
            // iOS MCP用bundle_id，Tweak用bundleId
            if let v = mapped["bundle_id"] { mapped["bundleId"] = v; mapped.removeValue(forKey: "bundle_id") }
        case "kill_app":
            if let v = mapped["bundle_id"] { mapped["bundleId"] = v; mapped.removeValue(forKey: "bundle_id") }
        case "set_clipboard":
            if let v = mapped["content"] { mapped["text"] = v; mapped.removeValue(forKey: "content") }
        case "run_command":
            // iOS MCP用command，Tweak的shell也用command，无需映射
            break
        default:
            break
        }

        return mapped
    }

    /// Shell fallback：通过Tweak shell执行iOS MCP有但Tweak还没原生支持的工具
    private func callViaShell(mcpName: String, arguments: [String: Any]) -> [String: Any] {
        var command: String?

        switch mcpName {
        case "double_tap":
            let x = arguments["x"] as? Double ?? arguments["startX"] as? Double ?? 0.5
            let y = arguments["y"] as? Double ?? arguments["startY"] as? Double ?? 0.5
            command = "starcore_cmd tap \(x) \(y) && sleep 0.1 && starcore_cmd tap \(x) \(y)"

        case "drag_and_drop":
            let fromX = arguments["startX"] as? Double ?? 0.3
            let fromY = arguments["startY"] as? Double ?? 0.5
            let toX = arguments["endX"] as? Double ?? 0.7
            let toY = arguments["endY"] as? Double ?? 0.5
            let dur = arguments["duration"] as? Double ?? 1.0
            command = "starcore_cmd swipe \(fromX) \(fromY) \(toX) \(toY) \(dur)"

        case "press_key":
            let key = arguments["key"] as? String ?? ""
            command = "starcore_cmd pressKey \(key)"

        case "toggle_mute":
            command = "starcore_cmd toggleMute"

        case "wake_and_home":
            command = "starcore_cmd pressPower && sleep 0.5 && starcore_cmd pressHome"

        case "get_element_at_point":
            let x = arguments["x"] as? Double ?? 0.5
            let y = arguments["y"] as? Double ?? 0.5
            // 通过shell调用getUIElements然后在本地过滤
            command = "starcore_cmd getUIElements"  // TODO: Tweak端增加坐标过滤

        case "list_running_apps":
            command = "ps aux | grep -v grep | grep 'Mobile' | awk '{print $NF}'"

        case "get_frontmost_app":
            command = "starcore_cmd getFrontmostApp 2>/dev/null || echo 'com.apple.springboard'"

        case "install_app":
            let ipa = arguments["path"] as? String ?? ""
            command = "ipkg install \(ipa) 2>/dev/null || echo 'install not supported'"

        case "uninstall_app":
            let bid = arguments["bundle_id"] as? String ?? arguments["bundleId"] as? String ?? ""
            command = "ipkg remove \(bid) 2>/dev/null || echo 'uninstall not supported'"

        case "open_url":
            let url = arguments["url"] as? String ?? ""
            command = "open \(url) 2>/dev/null || uiopen \(url) 2>/dev/null || echo 'open_url failed'"

        case "get_device_info":
            command = "uname -a; echo '---'; sysctl -a 2>/dev/null | grep -E 'hw.model|hw.memsize|machdep.cpu.brand_string' | head -5"

        case "get_brightness":
            command = "starcore_cmd getBrightness 2>/dev/null || brightness -l 2>/dev/null || echo '0.5'"

        case "set_brightness":
            let level = arguments["level"] as? Double ?? 0.5
            command = "starcore_cmd setBrightness \(level) 2>/dev/null || brightness \(level) 2>/dev/null || echo 'set_brightness failed'"

        case "get_volume":
            command = "starcore_cmd getVolume 2>/dev/null || echo '0.5'"

        case "set_volume":
            let level = arguments["level"] as? Double ?? 0.5
            command = "starcore_cmd setVolume \(level) 2>/dev/null || echo 'set_volume failed'"

        default:
            return ["content": [["type": "text", "text": "未知工具: \(mcpName)"]], "isError": true]
        }

        guard let cmd = command else {
            return ["content": [["type": "text", "text": "无法构建shell命令: \(mcpName)"]], "isError": true]
        }

        // 通过Tweak的shell执行
        let result = callTweakTool(name: "shell", arguments: ["command": cmd])
        // 给结果加上工具名标注
        if var content = result["content"] as? [[String: Any]],
           var first = content.first,
           let text = first["text"] as? String {
            first["text"] = "[\(mcpName)] \(text)"
            content[0] = first
            var newResult = result
            newResult["content"] = content
            return newResult
        }
        return result
    }

    // MARK: - Tweak TCP Call (直连，不走HTTP)

    /// 通过TCP:6000调用Tweak工具
    private func callTweakTool(name: String, arguments: [String: Any]) -> [String: Any] {
        // 构造Tweak action JSON
        var actionDict: [String: Any] = ["action": name]
        for (k, v) in arguments {
            actionDict[k] = v
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: actionDict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return ["content": [["type": "text", "text": "JSON序列化失败"]], "isError": true]
        }

        let responseStr = rawTCPSend(jsonString: jsonString, timeout: 30)
        if let resp = responseStr {
            if let data = resp.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return tweakResultToMCP(parsed)
            }
            return ["content": [["type": "text", "text": resp]], "isError": false]
        }
        return ["content": [["type": "text", "text": "Tweak调用超时或无响应"]], "isError": true]
    }

    /// Tweak结果 → MCP content格式
    private func tweakResultToMCP(_ result: [String: Any]) -> [String: Any] {
        let success = result["success"] as? Bool ?? true
        if !success {
            let errorMsg = result["error"] as? String ?? "未知错误"
            return ["content": [["type": "text", "text": "❌ \(errorMsg)"]], "isError": true]
        }

        var textParts: [String] = []

        // shell output
        if let output = result["output"] as? String {
            textParts.append(output)
        }
        // file content
        if let content = result["content"] as? String {
            textParts.append(content)
        }
        // listFiles items
        if let items = result["items"] as? [[String: Any]] {
            for item in items {
                let name = item["name"] as? String ?? "?"
                let isDir = item["isDir"] as? Bool ?? false
                let size = item["size"] as? Int64 ?? Int64(item["size"] as? Int ?? 0)
                textParts.append("\(isDir ? "📁" : "📄") \(name) (\(size)B)")
            }
        }
        // screenshot filePath
        if let filePath = result["filePath"] as? String {
            textParts.append("文件路径: \(filePath)")
        }
        // screen info
        if let width = result["width"] as? Int, let height = result["height"] as? Int {
            let scale = result["scale"] as? Int ?? 3
            textParts.append("屏幕: \(width)x\(height), scale=\(scale)")
        }
        // listApps
        if let apps = result["apps"] as? [[String: Any]] {
            for app in apps {
                let appName = app["name"] as? String ?? "?"
                let bid = app["bundleId"] as? String ?? "?"
                textParts.append("\(appName) (\(bid))")
            }
        }
        // getUIElements
        if let elements = result["elements"] as? [[String: Any]] {
            for el in elements.prefix(50) {
                let label = el["label"] as? String ?? el["name"] as? String ?? "?"
                let type = el["type"] as? String ?? "?"
                let frame = el["frame"] as? String ?? ""
                textParts.append("[\(type)] \(label) \(frame)")
            }
            if elements.count > 50 {
                textParts.append("... 还有\(elements.count - 50)个元素")
            }
        }
        // clipboard / generic text
        if let text = result["text"] as? String {
            textParts.append(text)
        }
        // device info / brightness / volume
        if let value = result["value"] as? String {
            textParts.append(value)
        }
        if let level = result["level"] as? Double {
            textParts.append("\(level)")
        }

        // 通用fallback：直接序列化result
        if textParts.isEmpty {
            if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
               let str = String(data: data, encoding: .utf8) {
                // 截断超长结果
                if str.count > 4000 {
                    textParts.append(String(str.prefix(4000)) + "\n... (截断，共\(str.count)字符)")
                } else {
                    textParts.append(str)
                }
            } else {
                textParts.append("已执行")
            }
        }

        let fullText = textParts.joined(separator: "\n")
        return ["content": [["type": "text", "text": fullText]], "isError": false]
    }

    // MARK: - Screenshot (异步+压缩+保存)

    private func handleScreenshot(id: Int) {
        logMsg("📸 截图走Tweak TCP...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard let tweakResult = self.rawTCPSend(jsonString: "{\"action\":\"screenshot\"}", timeout: 15),
                  let data = tweakResult.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let base64Str = parsed["image"] as? String ?? parsed["data"] as? String,
                  !base64Str.isEmpty,
                  let rawData = Data(base64Encoded: base64Str) else {
                self.logMsg("Tweak截图失败")
                self.sendResultSafe(id: id, result: [
                    "content": [["type": "text", "text": "截图失败"]], "isError": true
                ])
                return
            }

            self.logMsg("Tweak截图: \(rawData.count) bytes")

            // 1. 压缩
            let compressed = self.compressScreenshot(rawData)
            let compressedB64 = compressed.base64EncodedString()
            self.logMsg("压缩: \(rawData.count)→\(compressed.count) bytes")

            // 2. 保存到App沙盒
            _ = MemoryManager.shared.saveScreenshot(data: rawData)

            // 3. 发送给小智（压缩后的JPEG）
            self.sendResultSafe(id: id, result: [
                "content": [[
                    "type": "image",
                    "data": compressedB64,
                    "mimeType": "image/jpeg"
                ]]
            ])
            self.logMsg("📸 截图完成")
        }
    }

    /// 压缩截图：800px宽 + JPEG 0.4
    private func compressScreenshot(_ data: Data, maxWidth: CGFloat = 800, quality: CGFloat = 0.4) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let scale = maxWidth / image.size.width
        let newSize = CGSize(width: maxWidth, height: image.size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        if let resized = resized, let jpeg = resized.jpegData(compressionQuality: quality) {
            return jpeg
        }
        return data
    }

    // MARK: - TCP Send (复用StarCoreAgent的TCP逻辑)

    private func rawTCPSend(jsonString: String, timeout: TimeInterval = 5) -> String? {
        var accumulatedData = Data()
        let semaphore = DispatchSemaphore(value: 0)
        let maxResponseSize = 10 * 1024 * 1024 // 10MB

        let queue = DispatchQueue(label: "com.starcore.xiaozhi.tcp")
        let host = NWEndpoint.Host(tweakHost)
        guard let port = NWEndpoint.Port(rawValue: tweakPort) else { return nil }

        let connection = NWConnection(host: host, port: port, using: .tcp)
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
        let result = String(data: accumulatedData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }

    // MARK: - WSS Send (线程安全)

    private func sendResult(id: Int, result: [String: Any]) {
        sendJSON(["jsonrpc": "2.0", "id": id, "result": result])
    }

    private func sendError(id: Int, message: String) {
        sendJSON(["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": message]])
    }

    /// 安全发送：检查连接状态，避免在断连时发送
    private func sendResultSafe(id: Int, result: [String: Any]) {
        guard let ws = webSocketTask, ws.state == .running else {
            logMsg("WSS未连接，无法发送结果")
            return
        }
        sendResult(id: id, result: result)
    }

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let text = String(data: data, encoding: .utf8) else { return }

        let sizeKB = text.count / 1024
        if sizeKB > 50 {
            logMsg("WSS发送: \(sizeKB)KB")
        }

        guard let ws = webSocketTask, ws.state == .running else {
            logMsg("WSS未连接，跳过发送")
            return
        }

        ws.send(.string(text)) { [weak self] error in
            if let error = error {
                self?.logMsg("WSS发送失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Reconnect Logic (指数退避)

    private func handleDisconnect() {
        guard state != .disconnected else { return }
        state = .disconnected
        webSocketTask = nil
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        cancelReconnect()
        reconnectAttempt += 1
        let delay = min(5 * pow(2.0, Double(reconnectAttempt - 1)), 60.0)
        logMsg("\(Int(delay))秒后重连... (第\(reconnectAttempt)次)")
        DispatchQueue.main.async { [weak self] in
            self?.reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
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
        if recentLogs.count > 50 { recentLogs.removeFirst(recentLogs.count - 50) }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onLog?(entry)
            print("[XiaoZhi] \(message)")
        }
    }
}
