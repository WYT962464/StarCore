/**
 * ActionCoordinator.swift
 * 行动协调器 - 管理多级降级的执行策略
 *
 * 架构说明：
 * StarCore的行动执行采用三层降级策略：
 * 1. XPC/Tweak层 - 最优先（原生iOS触摸注入，权限最高）
 * 2. ZXTouch层 - 第二优先级（TCP Socket控制第三方Tweak）
 * 3. Shortcuts/URL Schemes - 最后兜底（系统级API）
 *
 * 原则：能高级别完成的绝不用低级别
 *
 * 集成说明：
 * - ZXTouchClient作为可选依赖，未安装时不影响App运行
 * - ActionCommand统一动作模型，支持序列化到各协议
 * - 错误自动降级：某一层失败自动尝试下一层
 */

import Foundation
import UIKit

// MARK: - 行动类型

/// 行动类型枚举
enum ActionType: String, Codable {
    case tap = "点击"
    case swipe = "滑动"
    case longPress = "长按"
    case typeText = "输入文字"
    case homeButton = "按Home键"
    case openApp = "打开应用"
    case screenshot = "截图"
    case shellCommand = "Shell命令"
}

/// 行动执行结果
struct ActionResult: Codable {
    let success: Bool
    let method: ActionMethod
    let message: String
    let timestamp: Date
    /// 截图数据（仅screenshot命令有值）
    var screenshotData: Data?

    init(success: Bool, method: ActionMethod, message: String = "", screenshotData: Data? = nil) {
        self.success = success
        self.method = method
        self.message = message
        self.timestamp = Date()
        self.screenshotData = screenshotData
    }
}

/// 行动执行方法
enum ActionMethod: String, Codable {
    case xpc = "XPC/Tweak"
    case zxtouch = "ZXTouch"
    case shortcuts = "Shortcuts"
    case unavailable = "不可用"
}

// MARK: - 行动协调器错误

enum ActionCoordinatorError: Error, LocalizedError {
    case allMethodsFailed
    case actionCancelled
    case invalidParameters
    case timeout

    var errorDescription: String? {
        switch self {
        case .allMethodsFailed:
            return "所有执行方法均失败"
        case .actionCancelled:
            return "行动被取消"
        case .invalidParameters:
            return "无效的行动参数"
        case .timeout:
            return "行动执行超时"
        }
    }
}

// MARK: - 行动协调器

class ActionCoordinator: ObservableObject {

    // MARK: - 单例

    static let shared = ActionCoordinator()

    // MARK: - 依赖服务

    private let tweakClient = TweakTCPClient.shared
    private let zxtouchClient = ZXTouchClient.shared

    // MARK: - 配置

    /// 行动执行超时时间（秒）
    var actionTimeout: TimeInterval = 10.0

    /// 是否启用降级策略
    var enableFallback = true

    // MARK: - 状态

    /// Tweak连接是否可用
    var isTweakAvailable: Bool {
        return tweakClient.getConnectionState() == .connected
    }

    /// ZXTouch连接是否可用
    var isZXTouchAvailable: Bool {
        return zxtouchClient.isAvailable
    }

    /// 任一操控服务是否可用
    var isAnyControlAvailable: Bool {
        return isTweakAvailable || isZXTouchAvailable
    }

    // MARK: - 执行日志

    @Published private(set) var actionLog: [ActionLogEntry] = []

    private let logQueue = DispatchQueue(label: "com.starcore.action.log")

    // MARK: - 初始化

    private init() {
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTweakStateChange),
            name: .tweakConnectionStateChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleZXTouchStateChange),
            name: .zxtouchConnectionStateChanged,
            object: nil
        )
    }

    @objc private func handleTweakStateChange(_ notification: Notification) {
        if let state = notification.object as? ConnectionState {
            print("[ActionCoordinator] Tweak连接状态变更: \(state.rawValue)")
        }
    }

    @objc private func handleZXTouchStateChange(_ notification: Notification) {
        if let state = notification.object as? ZXTouchConnectionState {
            print("[ActionCoordinator] ZXTouch连接状态变更: \(state.rawValue)")
        }
    }

    // MARK: - 连接管理

    /// 尝试连接所有服务
    func connectAll() {
        tweakClient.checkConnection()
        zxtouchClient.checkConnection()
    }

    /// 断开所有服务
    func disconnectAll() {
        // TweakTCPClient和ZXTouchClient使用per-request连接模式，无需显式断开
    }

    // MARK: - 日志记录

    private func logAction(command: ActionCommand, result: ActionResult) {
        let entry = ActionLogEntry(command: command, result: result, timestamp: Date())
        logQueue.async {
            self.actionLog.append(entry)
            // 保持最近200条
            if self.actionLog.count > 200 {
                self.actionLog.removeFirst()
            }
        }
        print("[ActionCoordinator] \(entry.summary)")
    }

    // MARK: - 统一执行入口

    /// 通过ActionCommand执行动作
    /// - Parameter command: 动作命令
    /// - Returns: 执行结果
    func execute(_ command: ActionCommand) async -> ActionResult {
        switch command {
        case .tap(let x, let y):
            return await performTap(x: x, y: y)
        case .swipe(let fromX, let fromY, let toX, let toY, let duration):
            return await performSwipe(fromX: fromX, fromY: fromY, toX: toX, toY: toY, duration: Double(duration) / 1000.0)
        case .touchHold(let x, let y, let duration):
            return await performLongPress(x: x, y: y, duration: Double(duration) / 1000.0)
        case .typeText(let text):
            return await performTypeText(text: text)
        case .screenshot:
            return await takeScreenshot()
        case .openApp(let bundleId):
            return await openApp(bundleId: bundleId)
        case .goHome:
            return await performHomeButton()
        case .runShell(let cmd):
            return await performShellCommand(cmd)
        case .showAlert(let title, let content, let duration):
            return await performShowAlert(title: title, content: content, duration: duration)
        case .custom(let cmd, let params):
            return ActionResult(success: false, method: .unavailable, message: "自定义指令暂未实现: \(cmd) \(params)")
        }
    }

    // MARK: - 行动执行

    /// 执行点击行动
    func performTap(x: Int, y: Int) async -> ActionResult {
        guard x >= 0 && y >= 0 else {
            let result = ActionResult(success: false, method: .unavailable, message: "坐标无效")
            logAction(command: .tap(x: x, y: y), result: result)
            return result
        }

        print("[ActionCoordinator] 执行点击: (\(x), \(y))")

        // 层级1: 尝试XPC/Tweak
        if isTweakAvailable {
            do {
                let success = try await tweakClient.tap(x: x, y: y)
                if success {
                    let result = ActionResult(success: true, method: .xpc, message: "XPC执行成功")
                    logAction(command: .tap(x: x, y: y), result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] XPC失败: \(error)")
            }
        }

        // 层级2: 降级到ZXTouch
        if enableFallback && isZXTouchAvailable {
            do {
                let success = try await zxtouchClient.tap(x: x, y: y)
                if success {
                    let result = ActionResult(success: true, method: .zxtouch, message: "ZXTouch执行成功")
                    logAction(command: .tap(x: x, y: y), result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] ZXTouch失败: \(error)")
            }
        }

        let result = ActionResult(success: false, method: .unavailable, message: "所有方法均失败")
        logAction(command: .tap(x: x, y: y), result: result)
        return result
    }

    /// 执行滑动行动
    func performSwipe(fromX: Int, fromY: Int, toX: Int, toY: Int, duration: Double = 0.5) async -> ActionResult {
        guard fromX >= 0 && fromY >= 0 && toX >= 0 && toY >= 0 else {
            let result = ActionResult(success: false, method: .unavailable, message: "坐标无效")
            logAction(command: .swipe(fromX: fromX, fromY: fromY, toX: toX, toY: toY, duration: Int(duration * 1000)), result: result)
            return result
        }

        print("[ActionCoordinator] 执行滑动: (\(fromX),\(fromY)) -> (\(toX),\(toY))")

        // 层级1: XPC/Tweak
        if isTweakAvailable {
            do {
                let success = try await tweakClient.swipe(fromX: fromX, fromY: fromY, toX: toX, toY: toY, duration: duration)
                if success {
                    let result = ActionResult(success: true, method: .xpc)
                    logAction(command: .swipe(fromX: fromX, fromY: fromY, toX: toX, toY: toY, duration: Int(duration * 1000)), result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] XPC滑动失败: \(error)")
            }
        }

        // 层级2: ZXTouch
        if enableFallback && isZXTouchAvailable {
            do {
                let durationMs = Int(duration * 1000)
                let success = try await zxtouchClient.swipe(fromX: fromX, fromY: fromY, toX: toX, toY: toY, duration: durationMs)
                if success {
                    let result = ActionResult(success: true, method: .zxtouch)
                    logAction(command: .swipe(fromX: fromX, fromY: fromY, toX: toX, toY: toY, duration: durationMs), result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] ZXTouch滑动失败: \(error)")
            }
        }

        let result = ActionResult(success: false, method: .unavailable)
        logAction(command: .swipe(fromX: fromX, fromY: fromY, toX: toX, toY: toY, duration: Int(duration * 1000)), result: result)
        return result
    }

    /// 执行长按行动
    func performLongPress(x: Int, y: Int, duration: Double = 1.0) async -> ActionResult {
        guard x >= 0 && y >= 0 && duration > 0 else {
            let result = ActionResult(success: false, method: .unavailable, message: "参数无效")
            logAction(command: .touchHold(x: x, y: y, duration: Int(duration * 1000)), result: result)
            return result
        }

        print("[ActionCoordinator] 执行长按: (\(x),\(y)), 持续\(duration)秒")

        // 层级1: XPC/Tweak
        if isTweakAvailable {
            do {
                let success = try await tweakClient.longPress(x: x, y: y, duration: duration)
                if success {
                    let result = ActionResult(success: true, method: .xpc)
                    logAction(command: .touchHold(x: x, y: y, duration: Int(duration * 1000)), result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] XPC长按失败: \(error)")
            }
        }

        // 层级2: ZXTouch
        if enableFallback && isZXTouchAvailable {
            do {
                let durationMs = Int(duration * 1000)
                let success = try await zxtouchClient.touchHold(x: x, y: y, duration: durationMs)
                if success {
                    let result = ActionResult(success: true, method: .zxtouch)
                    logAction(command: .touchHold(x: x, y: y, duration: durationMs), result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] ZXTouch长按失败: \(error)")
            }
        }

        let result = ActionResult(success: false, method: .unavailable)
        logAction(command: .touchHold(x: x, y: y, duration: Int(duration * 1000)), result: result)
        return result
    }

    /// 输入文字
    func performTypeText(text: String) async -> ActionResult {
        guard !text.isEmpty else {
            let result = ActionResult(success: false, method: .unavailable, message: "文字为空")
            logAction(command: .typeText(text: text), result: result)
            return result
        }

        print("[ActionCoordinator] 输入文字: \"\(text.prefix(30))\"")

        // 层级1: XPC/Tweak (如果支持)
        // TweakTCPClient暂无typeText方法，跳过

        // 层级2: ZXTouch
        if isZXTouchAvailable {
            do {
                let success = try await zxtouchClient.typeText(text)
                if success {
                    let result = ActionResult(success: true, method: .zxtouch, message: "ZXTouch输入成功")
                    logAction(command: .typeText(text: text), result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] ZXTouch输入失败: \(error)")
            }
        }

        let result = ActionResult(success: false, method: .unavailable, message: "文字输入不可用")
        logAction(command: .typeText(text: text), result: result)
        return result
    }

    /// 按下Home键
    func performHomeButton() async -> ActionResult {
        print("[ActionCoordinator] 执行Home键")

        // 层级1: XPC/Tweak
        if isTweakAvailable {
            do {
                let success = try await tweakClient.pressHome()
                if success {
                    let result = ActionResult(success: true, method: .xpc)
                    logAction(command: .goHome, result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] XPC Home键失败: \(error)")
            }
        }

        // 层级2: ZXTouch (点击底部横条区域)
        if enableFallback && isZXTouchAvailable {
            do {
                let success = try await zxtouchClient.goHome()
                if success {
                    let result = ActionResult(success: true, method: .zxtouch)
                    logAction(command: .goHome, result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] ZXTouch Home键失败: \(error)")
            }
        }

        let result = ActionResult(success: false, method: .unavailable)
        logAction(command: .goHome, result: result)
        return result
    }

    /// 打开指定应用
    func openApp(bundleId: String) async -> ActionResult {
        print("[ActionCoordinator] 打开应用: \(bundleId)")

        // 层级1: XPC/Tweak
        if isTweakAvailable {
            do {
                let success = try await tweakClient.openApp(bundleId: bundleId)
                if success {
                    let result = ActionResult(success: true, method: .xpc)
                    logAction(command: .openApp(bundleId: bundleId), result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] XPC打开应用失败: \(error)")
            }
        }

        // 层级2: ZXTouch
        if enableFallback && isZXTouchAvailable {
            do {
                let success = try await zxtouchClient.openApp(bundleId: bundleId)
                if success {
                    let result = ActionResult(success: true, method: .zxtouch)
                    logAction(command: .openApp(bundleId: bundleId), result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] ZXTouch打开应用失败: \(error)")
            }
        }

        // 层级3: URL Schemes
        if enableFallback {
            return await performOpenAppViaURLScheme(bundleId: bundleId)
        }

        let result = ActionResult(success: false, method: .unavailable)
        logAction(command: .openApp(bundleId: bundleId), result: result)
        return result
    }

    /// 截图
    func takeScreenshot() async -> ActionResult {
        print("[ActionCoordinator] 执行截图")

        // 层级1: XPC/Tweak
        if isTweakAvailable {
            do {
                let data = try await tweakClient.takeScreenshot()
                if let data = data {
                    var result = ActionResult(success: true, method: .xpc, message: "截图成功")
                    result.screenshotData = data
                    logAction(command: .screenshot, result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] XPC截图失败: \(error)")
            }
        }

        // 层级2: ZXTouch
        if enableFallback && isZXTouchAvailable {
            do {
                let data = try await zxtouchClient.screenshot()
                if let data = data {
                    var result = ActionResult(success: true, method: .zxtouch, message: "ZXTouch截图成功")
                    result.screenshotData = data
                    logAction(command: .screenshot, result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] ZXTouch截图失败: \(error)")
            }
        }

        // 层级3: 系统截图API
        if enableFallback {
            return await performScreenshotViaSystemAPI()
        }

        let result = ActionResult(success: false, method: .unavailable)
        logAction(command: .screenshot, result: result)
        return result
    }

    // MARK: - 降级实现

    /// 通过URL Scheme打开应用
    private func performOpenAppViaURLScheme(bundleId: String) async -> ActionResult {
        // 常见的URL Scheme
        if bundleId == "com.apple.mobileslideshow" {
            if let url = URL(string: "photos-redirect://") {
                if await UIApplication.shared.open(url) {
                    let result = ActionResult(success: true, method: .shortcuts, message: "已打开相册")
                    logAction(command: .openApp(bundleId: bundleId), result: result)
                    return result
                }
            }
        }

        let result = ActionResult(success: false, method: .shortcuts, message: "URL Scheme不可用")
        logAction(command: .openApp(bundleId: bundleId), result: result)
        return result
    }

    /// 通过系统API截图
    private func performScreenshotViaSystemAPI() async -> ActionResult {
        let result = ActionResult(
            success: false,
            method: .shortcuts,
            message: "系统API无法截取其他应用画面"
        )
        logAction(command: .screenshot, result: result)
        return result
    }

    /// 执行Shell命令
    private func performShellCommand(_ command: String) async -> ActionResult {
        if isZXTouchAvailable {
            do {
                let output = try await zxtouchClient.runShell(command)
                let result = ActionResult(success: true, method: .zxtouch, message: output)
                logAction(command: .runShell(command: command), result: result)
                return result
            } catch {
                print("[ActionCoordinator] ZXTouch Shell失败: \(error)")
            }
        }

        let result = ActionResult(success: false, method: .unavailable, message: "Shell命令不可用")
        logAction(command: .runShell(command: command), result: result)
        return result
    }

    /// 显示弹窗
    private func performShowAlert(title: String, content: String, duration: Int) async -> ActionResult {
        if isZXTouchAvailable {
            do {
                let success = try await zxtouchClient.showAlert(title: title, content: content, duration: duration)
                if success {
                    let result = ActionResult(success: true, method: .zxtouch)
                    logAction(command: .showAlert(title: title, content: content, duration: duration), result: result)
                    return result
                }
            } catch {
                print("[ActionCoordinator] ZXTouch弹窗失败: \(error)")
            }
        }

        let result = ActionResult(success: false, method: .unavailable, message: "弹窗不可用")
        logAction(command: .showAlert(title: title, content: content, duration: duration), result: result)
        return result
    }

    // MARK: - 诊断

    /// 获取诊断信息
    func getDiagnostics() -> [String: Any] {
        return [
            "tweakAvailable": isTweakAvailable,
            "tweakState": tweakClient.getConnectionState().rawValue,
            "zxtouchAvailable": isZXTouchAvailable,
            "zxtouchState": zxtouchClient.getConnectionState().rawValue,
            "anyControlAvailable": isAnyControlAvailable,
            "actionTimeout": actionTimeout,
            "fallbackEnabled": enableFallback,
            "actionLogCount": actionLog.count
        ]
    }

    /// 获取最近的动作日志
    func getRecentLogs(count: Int = 20) -> [ActionLogEntry] {
        return Array(actionLog.suffix(count))
    }
}
