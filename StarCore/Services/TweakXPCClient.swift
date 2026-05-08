/**
 * TweakXPCClient.swift
 * XPC客户端 - 连接Tweak服务
 * 
 * StarCore App通过此客户端与SpringBoard中的Tweak通信
 * 实现触摸注入和系统操作
 */

import UIKit

// MARK: - XPC协议定义（Swift版本）

/// StarCore Tweak XPC协议
@objc protocol StarCoreTweakXPCProtocol {
    /// 点击指定坐标
    /// - Parameters:
    ///   - x: X坐标（逻辑像素）
    ///   - y: Y坐标（逻辑像素）
    ///   - reply: 回调：操作是否成功
    func tapAtX(_ x: Int, Y y: Int, reply: @escaping (Bool) -> Void)
    
    /// 滑动操作
    func swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, duration: Double, reply: @escaping (Bool) -> Void)
    
    /// 长按操作
    func longPressAtX(_ x: Int, Y y: Int, duration: Double, reply: @escaping (Bool) -> Void)
    
    /// 按下Home键
    func pressHomeButton(reply: @escaping (Bool) -> Void)
    
    /// 打开指定应用
    func openApp(_ bundleId: String, reply: @escaping (Bool) -> Void)
    
    /// 获取屏幕尺寸
    func getScreenSize(reply: @escaping ([String: Any]) -> Void)
    
    /// 获取当前前台应用
    func getCurrentApp(reply: @escaping (String) -> Void)
    
    /// 截取屏幕
    func takeScreenshot(reply: @escaping (Data?) -> Void)
}

// MARK: - XPC服务名称

/// XPC服务名称（与Tweak端保持一致）
let kStarCoreTweakXPCServiceName = "com.starcore.tweak-service"

// MARK: - 错误类型

/// XPC客户端错误
enum TweakXPCError: Error, LocalizedError {
    case connectionFailed
    case connectionInterrupted
    case serviceNotAvailable
    case operationTimeout
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "XPC连接失败"
        case .connectionInterrupted:
            return "XPC连接被中断"
        case .serviceNotAvailable:
            return "Tweak服务不可用，请确保Tweak已安装并激活"
        case .operationTimeout:
            return "操作超时"
        case .invalidResponse:
            return "无效的响应"
        }
    }
}

// MARK: - XPC客户端

/// Tweak XPC客户端
class TweakXPCClient {
    
    // MARK: - 单例
    
    static let shared = TweakXPCClient()
    
    // MARK: - 属性
    
    private var connection: NSXPCConnection?
    private let connectionQueue = DispatchQueue(label: "com.starcore.tweak.xpc", qos: .userInitiated)
    private var isConnected = false
    private var reconnectTimer: Timer?
    
    /// 连接状态
    var connectionState: ConnectionState = .disconnected {
        didSet {
            NotificationCenter.default.post(name: .tweakConnectionStateChanged, object: connectionState)
        }
    }
    
    /// 连接状态枚举
    enum ConnectionState: String {
        case disconnected = "未连接"
        case connecting = "连接中"
        case connected = "已连接"
        case failed = "连接失败"
    }
    
    // MARK: - 初始化
    
    private init() {
        setupNotifications()
    }
    
    deinit {
        disconnect()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 通知
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppDidBecomeActive() {
        // App激活时尝试连接
        if connectionState == .disconnected {
            connect()
        }
    }
    
    // MARK: - 连接管理
    
    /// 连接到Tweak XPC服务
    func connect() {
        connectionQueue.async { [weak self] in
            self?.performConnect()
        }
    }
    
    private func performConnect() {
        guard connectionState != .connected && connectionState != .connecting else {
            return
        }
        
        DispatchQueue.main.async {
            self.connectionState = .connecting
        }
        
        // 断开旧连接
        disconnectInternal()
        
        // 创建新连接
        let newConnection = NSXPCConnection(machServiceName: kStarCoreTweakXPCServiceName, options: [])
        newConnection.remoteObjectInterface = NSXPCInterface(with: StarCoreTweakXPCProtocol.self)
        
        // 设置中断处理器
        newConnection.interruptionHandler = { [weak self] in
            print("[TweakXPCClient] 连接被中断")
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
                self?.scheduleReconnect()
            }
        }
        
        // 设置失效处理器
        newConnection.invalidationHandler = { [weak self] in
            print("[TweakXPCClient] 连接已失效")
            DispatchQueue.main.async {
                self?.connectionState = .failed
                self?.scheduleReconnect()
            }
        }
        
        newConnection.resume()
        
        // 验证连接
        if let proxy = getProxy() {
            // 发送心跳验证连接
            proxy.getScreenSize { [weak self] sizeInfo in
                if sizeInfo["width"] != nil {
                    print("[TweakXPCClient] 连接验证成功: \(sizeInfo)")
                    DispatchQueue.main.async {
                        self?.connectionState = .connected
                        self?.isConnected = true
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.connectionState = .failed
            }
        }
        
        self.connection = newConnection
    }
    
    /// 断开连接
    func disconnect() {
        connectionQueue.async { [weak self] in
            self?.disconnectInternal()
        }
    }
    
    private func disconnectInternal() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        connection?.invalidate()
        connection = nil
        isConnected = false
    }
    
    /// 安排重连
    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }
    
    // MARK: - 获取代理
    
    /// 获取XPC代理对象
    func getProxy() -> StarCoreTweakXPCProtocol? {
        guard let connection = connection else {
            print("[TweakXPCClient] 连接未初始化")
            return nil
        }
        
        return connection.remoteObjectProxyWithErrorHandler { error in
            print("[TweakXPCClient] XPC错误: \(error)")
        } as? StarCoreTweakXPCProtocol
    }
    
    /// 同步获取代理（带超时）
    func getProxy(timeout: TimeInterval = 5.0) async throws -> StarCoreTweakXPCProtocol {
        return try await withCheckedThrowingContinuation { continuation in
            let proxy = getProxy()
            
            if let proxy = proxy {
                // 验证连接
                proxy.getScreenSize { sizeInfo in
                    if sizeInfo["width"] != nil {
                        continuation.resume(returning: proxy)
                    } else {
                        continuation.resume(throwing: TweakXPCError.connectionFailed)
                    }
                }
            } else {
                continuation.resume(throwing: TweakXPCError.connectionFailed)
            }
        }
    }
    
    // MARK: - 触摸操作
    
    /// 点击指定坐标
    /// - Parameters:
    ///   - x: X坐标（逻辑像素）
    ///   - y: Y坐标（逻辑像素）
    /// - Returns: 操作是否成功
    func tap(x: Int, y: Int) async throws -> Bool {
        let proxy = try await getProxy()
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.tapAtX(x, Y: y) { success in
                if success {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(throwing: TweakXPCError.invalidResponse)
                }
            }
        }
    }
    
    /// 滑动操作
    func swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, duration: Double = 0.5) async throws -> Bool {
        let proxy = try await getProxy()
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.swipe(fromX: fromX, fromY: fromY, toX: toX, toY: toY, duration: duration) { success in
                if success {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(throwing: TweakXPCError.invalidResponse)
                }
            }
        }
    }
    
    /// 长按操作
    func longPress(x: Int, y: Int, duration: Double = 1.0) async throws -> Bool {
        let proxy = try await getProxy()
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.longPressAtX(x, Y: y, duration: duration) { success in
                if success {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(throwing: TweakXPCError.invalidResponse)
                }
            }
        }
    }
    
    /// 按下Home键
    func pressHome() async throws -> Bool {
        let proxy = try await getProxy()
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.pressHomeButton { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    // MARK: - 系统操作
    
    /// 打开指定应用
    func openApp(bundleId: String) async throws -> Bool {
        let proxy = try await getProxy()
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.openApp(bundleId) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// 获取屏幕尺寸
    func getScreenSize() async throws -> (width: Int, height: Int, scale: CGFloat) {
        let proxy = try await getProxy()
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.getScreenSize { sizeInfo in
                if let width = sizeInfo["width"] as? Int,
                   let height = sizeInfo["height"] as? Int {
                    let scale = sizeInfo["scale"] as? CGFloat ?? 1.0
                    continuation.resume(returning: (width, height, scale))
                } else {
                    continuation.resume(throwing: TweakXPCError.invalidResponse)
                }
            }
        }
    }
    
    /// 获取当前前台应用
    func getCurrentApp() async throws -> String {
        let proxy = try await getProxy()
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.getCurrentApp { bundleId in
                continuation.resume(returning: bundleId)
            }
        }
    }
    
    /// 截取屏幕
    func takeScreenshot() async throws -> Data? {
        let proxy = try await getProxy()
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.takeScreenshot { data in
                continuation.resume(returning: data)
            }
        }
    }
}

// MARK: - 通知名称

extension Notification.Name {
    /// Tweak连接状态变更通知
    static let tweakConnectionStateChanged = Notification.Name("tweakConnectionStateChanged")
}
