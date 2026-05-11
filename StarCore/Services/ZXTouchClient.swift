/**
 * ZXTouchClient.swift
 * ZXTouch TCP客户端 - 通过ZXTouch越狱插件操控iPhone
 *
 * 协议说明：
 * ZXTouch监听TCP 6000端口，使用二进制文本混合协议：
 * - 消息格式: {message_type}{params}\r\n
 * - 触摸指令坐标需×10，零填充至5位
 * - 手指编号: 1-19，默认使用5号
 * - 响应格式: 以;;分隔的字段串
 *
 * 连接策略: 每次指令新建TCP连接（与ZXTouch Python客户端一致）
 * ZXTouch为可选依赖——未安装时功能不可用但不会崩溃
 */

import Foundation
import UIKit

// MARK: - ZXTouch协议常量

/// ZXTouch消息类型
internal enum ZXTouchMessageType: UInt8 {
    case performTouch = 1           // 触摸事件
    case processBringForeground = 2 // 切换前台App
    case runShell = 3               // 执行Shell命令
    case usleep = 4                 // 微秒级睡眠
    case keyboard = 5               // 键盘操作（输入/显示/隐藏）
    case getDeviceInfo = 6          // 获取设备信息
    case showAlertBox = 7           // 显示弹窗
    case templateMatch = 8          // 图像匹配
    case textRecognizer = 9         // OCR文字识别
}

/// 触摸事件类型
internal enum ZXTouchTouchType: UInt8 {
    case down = 1   // 按下
    case move = 2   // 移动
    case up = 3     // 抬起
}

/// 默认手指编号
internal let kDefaultFinger: UInt8 = 5

// MARK: - 错误类型

enum ZXTouchError: Error, LocalizedError {
    case connectionFailed
    case serviceNotAvailable
    case timeout
    case invalidResponse
    case commandFailed(String)
    case screenshotNotSupported
    case notConnected

    var errorDescription: String? {
        switch self {
        case .connectionFailed: return "ZXTouch连接失败"
        case .serviceNotAvailable: return "ZXTouch服务不可用（未安装？）"
        case .timeout: return "ZXTouch操作超时"
        case .invalidResponse: return "ZXTouch响应无效"
        case .commandFailed(let msg): return "ZXTouch指令失败: \(msg)"
        case .screenshotNotSupported: return "ZXTouch不支持截图（请通过Shell命令实现）"
        case .notConnected: return "ZXTouch未连接"
        }
    }
}

// MARK: - 连接状态

enum ZXTouchConnectionState: String {
    case disconnected = "未连接"
    case connecting = "连接中"
    case connected = "已连接"
    case failed = "连接失败"
}

// MARK: - ZXTouch响应

struct ZXTouchResponse {
    let success: Bool
    let data: String

    /// 解析ZXTouch响应字符串
    /// 格式: "0;;..." 表示成功，非0表示失败
    static func parse(_ raw: String) -> ZXTouchResponse {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: ";;")
        let code = parts.first ?? ""
        let success = (code == "0")
        let data = parts.count > 1 ? parts.dropFirst().joined(separator: ";;") : trimmed
        return ZXTouchResponse(success: success, data: data)
    }
}

// MARK: - ZXTouch TCP客户端

class ZXTouchClient {

    // MARK: - 单例

    static let shared = ZXTouchClient()

    // MARK: - 配置

    /// ZXTouch服务地址（默认本机）
    var host: String = "127.0.0.1"

    /// ZXTouch服务端口（默认6000）
    var port: UInt16 = 6000

    /// 连接超时（秒）
    var connectionTimeout: TimeInterval = 5.0

    /// 读写超时（秒）
    var ioTimeout: TimeInterval = 10.0

    // MARK: - 状态

    private var connectionState: ZXTouchConnectionState = .disconnected {
        didSet {
            NotificationCenter.default.post(
                name: .zxtouchConnectionStateChanged,
                object: connectionState
            )
        }
    }

    private let queue = DispatchQueue(label: "com.starcore.zxtouch.tcp", qos: .userInitiated)

    // MARK: - 初始化

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        if connectionState == .disconnected || connectionState == .failed {
            checkConnection()
        }
    }

    // MARK: - 连接检测

    /// 检查ZXTouch服务是否可用
    func checkConnection() {
        queue.async { [weak self] in
            self?.performConnectionCheck()
        }
    }

    /// 获取当前连接状态
    func getConnectionState() -> ZXTouchConnectionState {
        return connectionState
    }

    /// ZXTouch是否可用
    var isAvailable: Bool {
        return connectionState == .connected
    }

    private func performConnectionCheck() {
        let sock = createTCPSocket()
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

    // MARK: - TCP底层

    /// 创建TCP Socket并连接
    private func createTCPSocket() -> Int32 {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        if sock < 0 { return -1 }

        // 设置超时
        var tv = timeval(tv_sec: Int(connectionTimeout), tv_usec: 0)
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

        if connect(sock, UnsafePointer(UnsafeRawPointer(&addr).assumingMemoryBound(to: sockaddr.self)),
                   socklen_t(MemoryLayout<sockaddr_in>.size)) < 0 {
            close(sock)
            return -1
        }

        return sock
    }

    /// 发送原始指令并接收响应
    private func sendRawCommand(_ command: String) throws -> String {
        guard let commandData = (command + "\r\n").data(using: .utf8) else {
            throw ZXTouchError.invalidResponse
        }

        let sock = createTCPSocket()
        guard sock >= 0 else {
            throw ZXTouchError.connectionFailed
        }
        defer { close(sock) }

        // 发送
        var sent = 0
        while sent < commandData.count {
            let n = commandData.withUnsafeBytes { ptr in
                send(sock, ptr.baseAddress!.advanced(by: sent), commandData.count - sent, 0)
            }
            if n <= 0 { throw ZXTouchError.connectionFailed }
            sent += Int(n)
        }

        // 接收响应
        var recvBuffer = Data()
        var buf = [UInt8](repeating: 0, count: 4096)

        // 设置读超时
        var readTv = timeval(tv_sec: Int(ioTimeout), tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &readTv, socklen_t(MemoryLayout<timeval>.size))

        let deadline = Date().addingTimeInterval(ioTimeout)
        while Date() < deadline {
            let n = recv(sock, &buf, buf.count, 0)
            if n > 0 {
                recvBuffer.append(buf, count: Int(n))
                // ZXTouch响应以\r\n结尾
                if recvBuffer.contains(0x0A) { break }
            } else if n == 0 {
                // 连接关闭
                break
            } else {
                // 错误或超时
                if recvBuffer.isEmpty {
                    throw ZXTouchError.timeout
                }
                break
            }
        }

        guard !recvBuffer.isEmpty,
              let response = String(data: recvBuffer, encoding: .utf8) else {
            throw ZXTouchError.invalidResponse
        }

        DispatchQueue.main.async {
            self.connectionState = .connected
        }

        return response
    }

    /// 发送无需响应的指令（如触摸事件）
    private func sendFireAndForget(_ command: String) throws {
        guard let commandData = (command + "\r\n").data(using: .utf8) else {
            throw ZXTouchError.invalidResponse
        }

        let sock = createTCPSocket()
        guard sock >= 0 else {
            throw ZXTouchError.connectionFailed
        }
        defer { close(sock) }

        var sent = 0
        while sent < commandData.count {
            let n = commandData.withUnsafeBytes { ptr in
                send(sock, ptr.baseAddress!.advanced(by: sent), commandData.count - sent, 0)
            }
            if n <= 0 { throw ZXTouchError.connectionFailed }
            sent += Int(n)
        }

        // 触摸指令需要等待一小段时间让ZXTouch处理
        // 读取可能的响应（非关键，忽略错误）
        var buf = [UInt8](repeating: 0, count: 256)
        _ = recv(sock, &buf, buf.count, 0)

        DispatchQueue.main.async {
            self.connectionState = .connected
        }
    }

    /// 发送指令并等待指定时间（用于组合操作中的sleep）
    private func sendWithWait(_ command: String, waitMs: Int = 50) throws {
        try sendFireAndForget(command)
        if waitMs > 0 {
            usleep(useconds_t(waitMs * 1000))
        }
    }

    // MARK: - 协议格式化

    /// 格式化触摸指令
    /// 格式: {1}{count}{touch_type}{finger:02d}{x*10:05d}{y*10:05d}
    private func formatTouchCommand(type: ZXTouchTouchType, x: Int, y: Int,
                                     finger: UInt8 = kDefaultFinger) -> String {
        let msgType = ZXTouchMessageType.performTouch.rawValue
        let touchType = type.rawValue
        let xScaled = x * 10
        let yScaled = y * 10
        return String(format: "%d1%d%02d%05d%05d", msgType, touchType, finger, xScaled, yScaled)
    }

    /// 格式化睡眠指令（毫秒转微秒）
    /// 格式: {4}{microseconds}
    private func formatSleepCommand(ms: Int) -> String {
        let msgType = ZXTouchMessageType.usleep.rawValue
        let us = ms * 1000
        return "\(msgType)\(us)"
    }

    /// 格式化键盘输入指令
    /// 格式: {5}1;;{text}
    private func formatTypeCommand(text: String) -> String {
        let msgType = ZXTouchMessageType.keyboard.rawValue
        return "\(msgType)1;;\(text)"
    }

    /// 格式化打开App指令
    /// 格式: {2}{bundleId}
    private func formatOpenAppCommand(bundleId: String) -> String {
        let msgType = ZXTouchMessageType.processBringForeground.rawValue
        return "\(msgType)\(bundleId)"
    }

    /// 格式化Shell命令
    /// 格式: {3}{command}
    private func formatShellCommand(_ command: String) -> String {
        let msgType = ZXTouchMessageType.runShell.rawValue
        return "\(msgType)\(command)"
    }

    /// 格式化获取设备信息指令
    /// 格式: {6}{infoType}
    private func formatDeviceInfoCommand(infoType: Int) -> String {
        let msgType = ZXTouchMessageType.getDeviceInfo.rawValue
        return "\(msgType)\(infoType)"
    }

    // MARK: - 公开API

    /// 点击坐标
    /// - Parameters:
    ///   - x: X坐标（逻辑像素）
    ///   - y: Y坐标（逻辑像素）
    /// - Returns: 是否成功
    func tap(x: Int, y: Int) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    // ZXTouch点击 = touch_down + touch_up
                    let downCmd = self.formatTouchCommand(type: .down, x: x, y: y)
                    try self.sendWithWait(downCmd, waitMs: 50)

                    let upCmd = self.formatTouchCommand(type: .up, x: x, y: y)
                    try self.sendFireAndForget(upCmd)

                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 滑动
    /// - Parameters:
    ///   - fromX: 起始X
    ///   - fromY: 起始Y
    ///   - toX: 结束X
    ///   - toY: 结束Y
    ///   - duration: 持续时间（毫秒）
    /// - Returns: 是否成功
    func swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, duration: Int = 300) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    // touch_down
                    let downCmd = self.formatTouchCommand(type: .down, x: fromX, y: fromY)
                    try self.sendWithWait(downCmd, waitMs: 0)

                    let absDx = abs(toX - fromX)
                    let absDy = abs(toY - fromY)

                    if absDx > 50 || absDy > 50 {
                        // 长距离滑动：先移到中点
                        let midX = fromX + (toX - fromX) / 2
                        let midY = fromY + (toY - fromY) / 2
                        let halfDuration = duration / 2

                        // sleep half
                        let sleep1 = self.formatSleepCommand(ms: halfDuration)
                        try self.sendWithWait(sleep1, waitMs: 0)

                        // touch_move to midpoint
                        let moveCmd = self.formatTouchCommand(type: .move, x: midX, y: midY)
                        try self.sendWithWait(moveCmd, waitMs: 0)

                        // sleep half
                        let sleep2 = self.formatSleepCommand(ms: halfDuration)
                        try self.sendWithWait(sleep2, waitMs: 0)
                    } else {
                        // 短距离滑动
                        let sleepCmd = self.formatSleepCommand(ms: duration)
                        try self.sendWithWait(sleepCmd, waitMs: 0)

                        let moveCmd = self.formatTouchCommand(type: .move, x: toX, y: toY)
                        try self.sendWithWait(moveCmd, waitMs: 0)
                    }

                    // touch_up
                    let upCmd = self.formatTouchCommand(type: .up, x: toX, y: toY)
                    try self.sendFireAndForget(upCmd)

                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 长按
    /// - Parameters:
    ///   - x: X坐标
    ///   - y: Y坐标
    ///   - duration: 持续时间（毫秒）
    /// - Returns: 是否成功
    func touchHold(x: Int, y: Int, duration: Int = 1000) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    // touch_down
                    let downCmd = self.formatTouchCommand(type: .down, x: x, y: y)
                    try self.sendWithWait(downCmd, waitMs: 0)

                    // sleep
                    let sleepCmd = self.formatSleepCommand(ms: duration)
                    try self.sendWithWait(sleepCmd, waitMs: 0)

                    // touch_up
                    let upCmd = self.formatTouchCommand(type: .up, x: x, y: y)
                    try self.sendFireAndForget(upCmd)

                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 输入文字
    /// - Parameter text: 要输入的文本
    /// - Returns: ZXTouch响应
    func typeText(_ text: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let cmd = self.formatTypeCommand(text: text)
                    let response = try self.sendRawCommand(cmd)
                    let parsed = ZXTouchResponse.parse(response)
                    continuation.resume(returning: parsed.success)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 打开App
    /// - Parameter bundleId: App的Bundle Identifier
    /// - Returns: 是否成功
    func openApp(bundleId: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let cmd = self.formatOpenAppCommand(bundleId: bundleId)
                    let response = try self.sendRawCommand(cmd)
                    let parsed = ZXTouchResponse.parse(response)
                    continuation.resume(returning: parsed.success)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 回到主屏幕
    func goHome() async throws -> Bool {
        // iPhone X: 底部横条区域点击
        // 逻辑分辨率812×375，底部横条约在y=790, x=187
        return try await tap(x: 187, y: 790)
    }

    /// 执行Shell命令
    /// - Parameter command: Shell命令
    /// - Returns: 命令输出
    func runShell(_ command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let cmd = self.formatShellCommand(command)
                    let response = try self.sendRawCommand(cmd)
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 获取屏幕尺寸
    /// - Returns: (width, height) 逻辑像素
    func getScreenSize() async throws -> (width: Int, height: Int) {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    // infoType=1: 屏幕尺寸
                    let cmd = self.formatDeviceInfoCommand(infoType: 1)
                    let response = try self.sendRawCommand(cmd)
                    let parts = response.trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: ";;")
                    if parts.count >= 3 {
                        let width = Int(parts[1].components(separatedBy: ".").first ?? "0") ?? 0
                        let height = Int(parts[2].components(separatedBy: ".").first ?? "0") ?? 0
                        continuation.resume(returning: (width, height))
                    } else {
                        continuation.resume(throwing: ZXTouchError.invalidResponse)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 截图（通过Shell命令实现）
    /// ZXTouch本身不直接支持截图，使用Shell命令+screencapture
    /// - Returns: PNG图片数据（如果成功）
    func screenshot() async throws -> Data? {
        // ZXTouch没有原生截图指令
        // 尝试通过Shell命令截图到临时文件，然后读取
        let tmpPath = "/tmp/starcore_screenshot.png"
        let _ = try await runShell("screencapture \(tmpPath)")

        // 短暂等待文件写入
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // 通过Shell读取文件并base64编码返回
        let base64Str = try await runShell("cat \(tmpPath) | base64")
        let cleaned = base64Str.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
        return Data(base64Encoded: cleaned)
    }

    /// 显示弹窗
    func showAlert(title: String, content: String, duration: Int = 3) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let msgType = ZXTouchMessageType.showAlertBox.rawValue
                    let cmd = "\(msgType)\(title);;\(content);;\(duration)"
                    let response = try self.sendRawCommand(cmd)
                    let parsed = ZXTouchResponse.parse(response)
                    continuation.resume(returning: parsed.success)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - 批量触摸

    /// 执行批量触摸事件
    /// - Parameter events: 触摸事件列表 [(type, x, y)]
    func performTouchEvents(_ events: [(ZXTouchTouchType, Int, Int)]) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let msgType = ZXTouchMessageType.performTouch.rawValue
                    var argsStr = "\(msgType)\(events.count)"
                    for (touchType, x, y) in events {
                        let xScaled = x * 10
                        let yScaled = y * 10
                        argsStr += String(format: "%d%02d%05d%05d",
                                          touchType.rawValue, kDefaultFinger, xScaled, yScaled)
                    }
                    try self.sendFireAndForget(argsStr)
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let zxtouchConnectionStateChanged = Notification.Name("zxtouchConnectionStateChanged")
}
