/**
 * TweakTCPClient.swift
 * TCP Socket客户端 - 连接SpringBoard中的Tweak
 * 
 * 通过127.0.0.1:6000与Tweak通信
 * 协议：JSON over TCP，每条消息以\n结尾
 * 使用POSIX socket直接通信，零框架依赖
 */

import UIKit

// MARK: - 错误类型

enum TweakTCPError: Error, LocalizedError {
    case connectionFailed
    case serviceNotAvailable
    case operationTimeout
    case invalidResponse
    case encodingError
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed: return "TCP连接失败"
        case .serviceNotAvailable: return "Tweak服务不可用"
        case .operationTimeout: return "操作超时"
        case .invalidResponse: return "无效的响应"
        case .encodingError: return "数据编码错误"
        }
    }
}

// MARK: - 连接状态

enum ConnectionState: String {
    case disconnected = "未连接"
    case connecting = "连接中"
    case connected = "已连接"
    case failed = "连接失败"
}

// MARK: - TCP客户端

class TweakTCPClient: NSObject {
    
    static let shared = TweakTCPClient()
    
    private var connectionState: ConnectionState = .disconnected {
        didSet {
            NotificationCenter.default.post(name: .tweakConnectionStateChanged, object: connectionState)
        }
    }
    
    private let host = "127.0.0.1"
    private let port: UInt16 = 6000
    private let timeout: TimeInterval = 5.0
    private let queue = DispatchQueue(label: "com.starcore.tweak.tcp", qos: .userInitiated)
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        if connectionState == .disconnected {
            checkConnection()
        }
    }
    
    // MARK: - 连接
    
    func checkConnection() {
        queue.async { [weak self] in
            self?.performCheck()
        }
    }
    
    private func performCheck() {
        let sock = self.createSocket()
        if sock >= 0 {
            close(sock)
            DispatchQueue.main.async {
                self.connectionState = .connected
            }
        } else {
            DispatchQueue.main.async {
                self.connectionState = .failed
            }
        }
    }
    
    private func createSocket() -> Int32 {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        if sock < 0 { return -1 }
        
        // 设置超时
        var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        
        if inet_pton(AF_INET, host, &addr.sin_addr) <= 0 {
            close(sock)
            return -1
        }
        
        if connect(sock, UnsafePointer(UnsafeRawPointer(&addr).assumingMemoryBound(to: sockaddr.self)), socklen_t(MemoryLayout<sockaddr_in>.size)) < 0 {
            close(sock)
            return -1
        }
        
        return sock
    }
    
    // MARK: - 发送请求
    
    private func sendRequest(_ request: [String: Any]) throws -> [String: Any] {
        var mutableRequest = request
        let id = Int(Date().timeIntervalSince1970 * 1000)
        mutableRequest["id"] = id
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: mutableRequest),
              var jsonStr = String(data: jsonData, encoding: .utf8) else {
            throw TweakTCPError.encodingError
        }
        jsonStr += "\n"
        
        let sock = createSocket()
        guard sock >= 0 else {
            throw TweakTCPError.connectionFailed
        }
        defer { close(sock) }
        
        // 发送
        let data = jsonStr.data(using: .utf8)!
        var sent = 0
        while sent < data.count {
            let n = data.withUnsafeBytes { ptr in
                send(sock, ptr.baseAddress!.advanced(by: sent), data.count - sent, 0)
            }
            if n <= 0 { throw TweakTCPError.connectionFailed }
            sent += Int(n)
        }
        
        // 接收（直到收到\n）
        var recvBuffer = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        var foundNewline = false
        
        while !foundNewline {
            let n = recv(sock, &buf, buf.count, 0)
            if n <= 0 { throw TweakTCPError.operationTimeout }
            recvBuffer.append(buf, count: Int(n))
            
            // 检查是否有\n
            if let idx = recvBuffer.firstIndex(of: 0x0A) {
                recvBuffer = recvBuffer[0..<idx]
                foundNewline = true
            }
        }
        
        // 解析JSON
        guard let responseStr = String(data: recvBuffer, encoding: .utf8),
              let responseData = responseStr.data(using: .utf8),
              let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw TweakTCPError.invalidResponse
        }
        
        DispatchQueue.main.async {
            self.connectionState = .connected
        }
        
        return response
    }
    
    // MARK: - 异步API
    
    func ping() async throws -> Bool {
        let response = try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try self.sendRequest(["action": "ping"])
                    continuation.resume(returning: result["success"] as? Bool ?? false)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        return response
    }
    
    func tap(x: Int, y: Int) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try self.sendRequest(["action": "tap", "x": x, "y": y])
                    continuation.resume(returning: result["success"] as? Bool ?? false)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, duration: Double = 0.5) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try self.sendRequest([
                        "action": "swipe",
                        "fromX": fromX, "fromY": fromY,
                        "toX": toX, "toY": toY,
                        "duration": duration
                    ])
                    continuation.resume(returning: result["success"] as? Bool ?? false)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func longPress(x: Int, y: Int, duration: Double = 1.0) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try self.sendRequest(["action": "longPress", "x": x, "y": y, "duration": duration])
                    continuation.resume(returning: result["success"] as? Bool ?? false)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func pressHome() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try self.sendRequest(["action": "pressHome"])
                    continuation.resume(returning: result["success"] as? Bool ?? false)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func openApp(bundleId: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try self.sendRequest(["action": "openApp", "bundleId": bundleId])
                    continuation.resume(returning: result["success"] as? Bool ?? false)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getScreenSize() async throws -> (width: Int, height: Int, scale: CGFloat) {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try self.sendRequest(["action": "getScreenSize"])
                    guard let width = result["width"] as? Int,
                          let height = result["height"] as? Int else {
                        continuation.resume(throwing: TweakTCPError.invalidResponse)
                        return
                    }
                    let scale = result["scale"] as? CGFloat ?? 3.0
                    continuation.resume(returning: (width, height, scale))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getCurrentApp() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try self.sendRequest(["action": "getCurrentApp"])
                    continuation.resume(returning: result["bundleId"] as? String ?? "unknown")
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func takeScreenshot() async throws -> Data? {
        // TODO: 实现截图
        return nil
    }
    
    func getConnectionState() -> ConnectionState {
        return connectionState
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let tweakConnectionStateChanged = Notification.Name("tweakConnectionStateChanged")
}
