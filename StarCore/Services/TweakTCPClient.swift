/**
 * TweakTCPClient.swift
 * TCP Socket客户端 - 连接SpringBoard中的Tweak
 * 
 * 通过127.0.0.1:6000与Tweak通信
 * 协议：JSON over TCP，每条消息以\n结尾
 */

import UIKit

// MARK: - 错误类型

enum TweakTCPError: Error, LocalizedError {
    case connectionFailed
    case connectionInterrupted
    case serviceNotAvailable
    case operationTimeout
    case invalidResponse
    case encodingError
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed: return "TCP连接失败"
        case .connectionInterrupted: return "TCP连接被中断"
        case .serviceNotAvailable: return "Tweak服务不可用，请确保Tweak已安装并激活"
        case .operationTimeout: return "操作超时"
        case .invalidResponse: return "无效的响应"
        case .encodingError: return "数据编码错误"
        }
    }
}

// MARK: - TCP客户端

class TweakTCPClient {
    
    // MARK: - 单例
    
    static let shared = TweakTCPClient()
    
    // MARK: - 属性
    
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private let queue = DispatchQueue(label: "com.starcore.tweak.tcp", qos: .userInitiated)
    private var pendingRequests: [Int: (Result<[String: Any], Error>) -> Void] = [:]
    private var nextId: Int = 0
    private var readBuffer = Data()
    private let host = "127.0.0.1"
    private let port: UInt32 = 6000
    
    /// 连接状态
    enum ConnectionState: String {
        case disconnected = "未连接"
        case connecting = "连接中"
        case connected = "已连接"
        case failed = "连接失败"
    }
    
    var connectionState: ConnectionState = .disconnected {
        didSet {
            NotificationCenter.default.post(name: .tweakConnectionStateChanged, object: connectionState)
        }
    }
    
    // MARK: - 初始化
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        disconnect()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAppDidBecomeActive() {
        if connectionState == .disconnected {
            connect()
        }
    }
    
    // MARK: - 连接管理
    
    func connect() {
        queue.async { [weak self] in
            self?.performConnect()
        }
    }
    
    private func performConnect() {
        guard connectionState != .connected && connectionState != .connecting else { return }
        
        DispatchQueue.main.async {
            self.connectionState = .connecting
        }
        
        disconnectInternal()
        
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(nil, self.host as CFString, self.port, &readStream, &writeStream)
        
        guard let input = readStream?.takeRetainedValue(),
              let output = writeStream?.takeRetainedValue() else {
            DispatchQueue.main.async {
                self.connectionState = .failed
            }
            return
        }
        
        self.inputStream = input
        self.outputStream = output
        
        input.delegate = self
        output.delegate = self
        
        input.schedule(in: .current, forMode: .default)
        output.schedule(in: .current, forMode: .default)
        
        input.open()
        output.open()
        
        // 启动RunLoop在后台线程
        CFRunLoopRun()
    }
    
    func disconnect() {
        queue.async { [weak self] in
            self?.disconnectInternal()
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
            }
        }
    }
    
    private func disconnectInternal() {
        inputStream?.close()
        outputStream?.close()
        inputStream = nil
        outputStream = nil
        readBuffer = Data()
        
        // 清理所有pending请求
        for (_, callback) in pendingRequests {
            callback(.failure(TweakTCPError.connectionInterrupted))
        }
        pendingRequests.removeAll()
    }
    
    // MARK: - 发送请求
    
    private func sendRequest(_ request: [String: Any]) async throws -> [String: Any] {
        guard connectionState == .connected else {
            throw TweakTCPError.serviceNotAvailable
        }
        
        let id = nextId
        nextId += 1
        
        var mutableRequest = request
        mutableRequest["id"] = id
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: mutableRequest),
              var jsonStr = String(data: jsonData, encoding: .utf8) else {
            throw TweakTCPError.encodingError
        }
        jsonStr += "\n"
        
        guard let output = outputStream, output.hasSpaceAvailable else {
            throw TweakTCPError.serviceNotAvailable
        }
        
        jsonStr.withCString { ptr in
            output.write(ptr, maxLength: strlen(ptr))
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[id] = { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - 公开API
    
    func ping() async throws -> Bool {
        let response = try await sendRequest(["action": "ping"])
        return response["success"] as? Bool ?? false
    }
    
    func tap(x: Int, y: Int) async throws -> Bool {
        let response = try await sendRequest(["action": "tap", "x": x, "y": y])
        return response["success"] as? Bool ?? false
    }
    
    func swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, duration: Double = 0.5) async throws -> Bool {
        let response = try await sendRequest([
            "action": "swipe",
            "fromX": fromX, "fromY": fromY,
            "toX": toX, "toY": toY,
            "duration": duration
        ])
        return response["success"] as? Bool ?? false
    }
    
    func longPress(x: Int, y: Int, duration: Double = 1.0) async throws -> Bool {
        let response = try await sendRequest(["action": "longPress", "x": x, "y": y, "duration": duration])
        return response["success"] as? Bool ?? false
    }
    
    func pressHome() async throws -> Bool {
        let response = try await sendRequest(["action": "pressHome"])
        return response["success"] as? Bool ?? false
    }
    
    func openApp(bundleId: String) async throws -> Bool {
        let response = try await sendRequest(["action": "openApp", "bundleId": bundleId])
        return response["success"] as? Bool ?? false
    }
    
    func getScreenSize() async throws -> (width: Int, height: Int, scale: CGFloat) {
        let response = try await sendRequest(["action": "getScreenSize"])
        guard let width = response["width"] as? Int,
              let height = response["height"] as? Int else {
            throw TweakTCPError.invalidResponse
        }
        let scale = response["scale"] as? CGFloat ?? 3.0
        return (width, height, scale)
    }
    
    func getCurrentApp() async throws -> String {
        let response = try await sendRequest(["action": "getCurrentApp"])
        return response["bundleId"] as? String ?? "unknown"
    }
}

// MARK: - NSStreamDelegate

extension TweakTCPClient: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            if aStream == outputStream {
                DispatchQueue.main.async {
                    self.connectionState = .connected
                }
                print("[TweakTCPClient] 连接成功")
            }
            
        case .hasBytesAvailable:
            guard let input = aStream as? InputStream else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            let len = input.read(&buffer, maxLength: buffer.count)
            if len > 0 {
                readBuffer.append(buffer, count: len)
                processBuffer()
            }
            
        case .errorOccurred:
            print("[TweakTCPClient] 流错误: \(aStream.streamError?.localizedDescription ?? "unknown")")
            DispatchQueue.main.async {
                self.connectionState = .failed
            }
            disconnectInternal()
            
        case .endEncountered:
            print("[TweakTCPClient] 连接断开")
            DispatchQueue.main.async {
                self.connectionState = .disconnected
            }
            disconnectInternal()
            
        default:
            break
        }
    }
    
    private func processBuffer() {
        while let nlRange = readBuffer.range(of: Data([0x0A])) { // 0x0A = \n
            let lineData = readBuffer.subdata(in: 0..<nlRange.lowerBound)
            readBuffer = readBuffer.subdata(in: nlRange.upperBound..<readBuffer.count)
            
            guard let jsonStr = String(data: lineData, encoding: .utf8),
                  let jsonData = jsonStr.data(using: .utf8),
                  let response = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let id = response["id"] as? Int else {
                continue
            }
            
            if let callback = pendingRequests.removeValue(forKey: id) {
                callback(.success(response))
            }
        }
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let tweakConnectionStateChanged = Notification.Name("tweakConnectionStateChanged")
}
