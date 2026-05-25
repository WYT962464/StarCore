/**
 * iOSMCPClient.swift
 * iOS MCP 客户端 - 手机端工具执行层
 * 
 * 协议：JSON-RPC 2.0 over HTTP POST
 * 端点：http://localhost:8090/mcp
 * 
 * 可用工具（34 个）：
 * - 屏幕控制：screenshot, tap, press, swipe, input_text
 * - 系统信息：get_frontmost_app, get_screen_info, wake_and_home
 * - 通知：show_notification
 * - 文件：list_files, read_file, write_file, delete_file
 * - 剪贴板：get_clipboard, set_clipboard
 * - 应用：open_app, close_app, launch_app
 * - 其他：vibrate, get_battery_info, get_network_info
 */

import Foundation
import Combine

@available(iOS 15.0, *)
final class iOSMCPClient: ObservableObject {
    // MARK: - 连接状态
    @Published var isConnected: Bool = false
    @Published var connectionError: String?
    @Published var lastActivity: Date?
    
    // MARK: - 配置
    private let host = "127.0.0.1"
    private let port = 8090
    private let path = "/mcp"
    private let timeout: TimeInterval = 5.0
    
    private var urlSession: URLSession!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        urlSession = URLSession(configuration: config)
    }
    
    // MARK: - 连接检查
    func checkConnection() {
        Task {
            do {
                let result = try await callTool(name: "get_screen_info", arguments: [:])
                await MainActor.run {
                    self.isConnected = true
                    self.connectionError = nil
                    self.lastActivity = Date()
                }
            } catch {
                await MainActor.run {
                    self.isConnected = false
                    self.connectionError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - JSON-RPC 调用
    private func callTool(name: String, arguments: [String: Any]) async throws -> [String: Any] {
        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int.random(in: 1..<10000),
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": arguments
            ]
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw MCPError.encodingFailed
        }
        
        var request = URLRequest(url: URL(string: "http://\(host):\(port)\(path)")!)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        let (responseData, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MCPError.connectionFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            throw MCPError.serverError(statusCode: httpResponse.statusCode)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let result = json["result"] as? [String: Any] else {
            throw MCPError.invalidResponse
        }
        
        return result
    }
    
    // MARK: - 屏幕控制工具
    
    /// 截图
    func screenshot() async throws -> String {
        let result = try await callTool(name: "screenshot", arguments: [:])
        guard let base64 = result["image"] as? String else {
            throw MCPError.invalidResponse
        }
        lastActivity = Date()
        return base64
    }
    
    /// 点击屏幕
    func tap(x: Int, y: Int) async throws {
        _ = try await callTool(name: "tap", arguments: ["x": x, "y": y])
        lastActivity = Date()
    }
    
    /// 长按屏幕
    func press(x: Int, y: Int, duration: Int = 500) async throws {
        _ = try await callTool(name: "press", arguments: ["x": x, "y": y, "duration": duration])
        lastActivity = Date()
    }
    
    /// 滑动屏幕
    func swipe(fromX: Int, fromY: Int, toX: Int, toY: Int) async throws {
        _ = try await callTool(name: "swipe", arguments: [
            "from_x": fromX, "from_y": fromY,
            "to_x": toX, "to_y": toY
        ])
        lastActivity = Date()
    }
    
    /// 输入文字
    func inputText(text: String) async throws {
        _ = try await callTool(name: "input_text", arguments: ["text": text])
        lastActivity = Date()
    }
    
    /// 唤醒设备并返回主页
    func wakeAndHome() async throws {
        _ = try await callTool(name: "wake_and_home", arguments: [:])
        lastActivity = Date()
    }
    
    // MARK: - 系统信息工具
    
    /// 获取当前前台应用
    func getFrontmostApp() async throws -> String {
        let result = try await callTool(name: "get_frontmost_app", arguments: [:])
        guard let appName = result["app_name"] as? String else {
            throw MCPError.invalidResponse
        }
        lastActivity = Date()
        return appName
    }
    
    /// 获取屏幕信息
    func getScreenInfo() async throws -> [String: Any] {
        let result = try await callTool(name: "get_screen_info", arguments: [:])
        lastActivity = Date()
        return result
    }
    
    /// 获取电池信息
    func getBatteryInfo() async throws -> [String: Any] {
        let result = try await callTool(name: "get_battery_info", arguments: [:])
        lastActivity = Date()
        return result
    }
    
    /// 获取网络信息
    func getNetworkInfo() async throws -> [String: Any] {
        let result = try await callTool(name: "get_network_info", arguments: [:])
        lastActivity = Date()
        return result
    }
    
    // MARK: - 应用控制
    
    /// 打开应用
    func openApp(bundleId: String) async throws {
        _ = try await callTool(name: "open_app", arguments: ["bundle_id": bundleId])
        lastActivity = Date()
    }
    
    /// 关闭应用
    func closeApp(bundleId: String) async throws {
        _ = try await callTool(name: "close_app", arguments: ["bundle_id": bundleId])
        lastActivity = Date()
    }
    
    /// 启动应用
    func launchApp(bundleId: String) async throws {
        _ = try await callTool(name: "launch_app", arguments: ["bundle_id": bundleId])
        lastActivity = Date()
    }
    
    // MARK: - 文件操作
    
    /// 列出文件
    func listFiles(path: String) async throws -> [[String: Any]] {
        let result = try await callTool(name: "list_files", arguments: ["path": path])
        guard let files = result["files"] as? [[String: Any]] else {
            throw MCPError.invalidResponse
        }
        lastActivity = Date()
        return files
    }
    
    /// 读取文件
    func readFile(path: String) async throws -> String {
        let result = try await callTool(name: "read_file", arguments: ["path": path])
        guard let content = result["content"] as? String else {
            throw MCPError.invalidResponse
        }
        lastActivity = Date()
        return content
    }
    
    /// 写入文件
    func writeFile(path: String, content: String) async throws {
        _ = try await callTool(name: "write_file", arguments: ["path": path, "content": content])
        lastActivity = Date()
    }
    
    /// 删除文件
    func deleteFile(path: String) async throws {
        _ = try await callTool(name: "delete_file", arguments: ["path": path])
        lastActivity = Date()
    }
    
    // MARK: - 剪贴板
    
    /// 获取剪贴板
    func getClipboard() async throws -> String {
        let result = try await callTool(name: "get_clipboard", arguments: [:])
        guard let text = result["text"] as? String else {
            throw MCPError.invalidResponse
        }
        lastActivity = Date()
        return text
    }
    
    /// 设置剪贴板
    func setClipboard(text: String) async throws {
        _ = try await callTool(name: "set_clipboard", arguments: ["text": text])
        lastActivity = Date()
    }
    
    // MARK: - 通知
    
    /// 显示通知
    func showNotification(title: String, body: String, sound: String? = nil) async throws {
        var args: [String: Any] = ["title": title, "body": body]
        if let sound = sound {
            args["sound"] = sound
        }
        _ = try await callTool(name: "show_notification", arguments: args)
        lastActivity = Date()
    }
    
    // MARK: - 其他
    
    /// 震动
    func vibrate(pattern: [Int]? = nil) async throws {
        var args: [String: Any] = [:]
        if let pattern = pattern {
            args["pattern"] = pattern
        }
        _ = try await callTool(name: "vibrate", arguments: args)
        lastActivity = Date()
    }
}

// MARK: - 错误类型
enum MCPError: LocalizedError {
    case connectionFailed
    case encodingFailed
    case invalidResponse
    case serverError(statusCode: Int)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed: return "无法连接到 iOS MCP 服务"
        case .encodingFailed: return "请求编码失败"
        case .invalidResponse: return "无效的响应格式"
        case .serverError(let code): return "服务器错误：\(code)"
        case .timeout: return "请求超时"
        }
    }
}
