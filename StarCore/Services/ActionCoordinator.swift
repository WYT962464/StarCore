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
 */

import Foundation
import UIKit

// MARK: - 行动类型

/// 行动类型枚举
enum ActionType: String, Codable {
    case tap = "点击"
    case swipe = "滑动"
    case longPress = "长按"
    case homeButton = "按Home键"
    case openApp = "打开应用"
    case screenshot = "截图"
}

/// 行动执行结果
struct ActionResult: Codable {
    let success: Bool
    let method: ActionMethod
    let message: String
    let timestamp: Date
    
    init(success: Bool, method: ActionMethod, message: String = "") {
        self.success = success
        self.method = method
        self.message = message
        self.timestamp = Date()
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

class ActionCoordinator {
    
    // MARK: - 单例
    
    static let shared = ActionCoordinator()
    
    // MARK: - 依赖服务
    
    private let tweakClient = TweakTCPClient.shared
    
    // MARK: - 配置
    
    /// 行动执行超时时间（秒）
    var actionTimeout: TimeInterval = 10.0
    
    /// 是否启用降级策略
    var enableFallback = true
    
    /// ZXTouch连接配置
    var zxtouchHost: String = "127.0.0.1"
    var zxtouchPort: UInt16 = 6000
    
    // MARK: - 状态
    
    /// Tweak连接是否可用
    var isTweakAvailable: Bool {
        return tweakClient.getConnectionState() == .connected
    }
    
    /// ZXTouch连接是否可用
    var isZXTouchAvailable: Bool {
        // TODO: 实现ZXTouch连接检测
        return false
    }
    
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
    }
    
    @objc private func handleTweakStateChange(_ notification: Notification) {
        if let state = notification.object as? ConnectionState {
            print("[ActionCoordinator] Tweak连接状态变更: \(state.rawValue)")
        }
    }
    
    // MARK: - 公开API
    
    /// 尝试连接所有服务
    func connectAll() {
        tweakClient.checkConnection()
        // TODO: 连接ZXTouch
    }
    
    /// 断开所有服务
    func disconnectAll() {
        // disconnect not needed with per-request TCP
        // TODO: 断开ZXTouch
    }
    
    // MARK: - 行动执行
    
    /// 执行点击行动
    /// - Parameters:
    ///   - x: X坐标
    ///   - y: Y坐标
    /// - Returns: 行动结果
    func performTap(x: Int, y: Int) async -> ActionResult {
        // 参数验证
        guard x >= 0 && y >= 0 else {
            return ActionResult(success: false, method: .unavailable, message: "坐标无效")
        }
        
        print("[ActionCoordinator] 执行点击: (\(x), \(y))")
        
        // 层级1: 尝试XPC/Tweak
        if isTweakAvailable {
            do {
                let success = try await tweakClient.tap(x: x, y: y)
                if success {
                    return ActionResult(success: true, method: .xpc, message: "XPC执行成功")
                }
            } catch {
                print("[ActionCoordinator] XPC失败: \(error)")
            }
        }
        
        // 层级2: 降级到ZXTouch
        if enableFallback && isZXTouchAvailable {
            do {
                let success = try await performZXTouchTap(x: x, y: y)
                if success {
                    return ActionResult(success: true, method: .zxtouch, message: "ZXTouch执行成功")
                }
            } catch {
                print("[ActionCoordinator] ZXTouch失败: \(error)")
            }
        }
        
        // 层级3: 降级到Shortcuts（仅用于特定场景）
        if enableFallback {
            // Shortcuts无法执行精确坐标点击，只能执行预设动作
            print("[ActionCoordinator] Shortcuts不支持精确点击")
        }
        
        return ActionResult(success: false, method: .unavailable, message: "所有方法均失败")
    }
    
    /// 执行滑动行动
    func performSwipe(fromX: Int, fromY: Int, toX: Int, toY: Int, duration: Double = 0.5) async -> ActionResult {
        guard fromX >= 0 && fromY >= 0 && toX >= 0 && toY >= 0 else {
            return ActionResult(success: false, method: .unavailable, message: "坐标无效")
        }
        
        print("[ActionCoordinator] 执行滑动: (\(fromX),\(fromY)) -> (\(toX),\(toY))")
        
        // 层级1: XPC/Tweak
        if isTweakAvailable {
            do {
                let success = try await tweakClient.swipe(fromX: fromX, fromY: fromY, toX: toX, toY: toY, duration: duration)
                if success {
                    return ActionResult(success: true, method: .xpc)
                }
            } catch {
                print("[ActionCoordinator] XPC滑动失败: \(error)")
            }
        }
        
        // 层级2: ZXTouch
        if enableFallback && isZXTouchAvailable {
            do {
                let success = try await performZXTouchSwipe(fromX: fromX, fromY: fromY, toX: toX, toY: toY, duration: duration)
                if success {
                    return ActionResult(success: true, method: .zxtouch)
                }
            } catch {
                print("[ActionCoordinator] ZXTouch滑动失败: \(error)")
            }
        }
        
        return ActionResult(success: false, method: .unavailable)
    }
    
    /// 执行长按行动
    func performLongPress(x: Int, y: Int, duration: Double = 1.0) async -> ActionResult {
        guard x >= 0 && y >= 0 && duration > 0 else {
            return ActionResult(success: false, method: .unavailable, message: "参数无效")
        }
        
        print("[ActionCoordinator] 执行长按: (\(x),\(y)), 持续\(duration)秒")
        
        // 层级1: XPC/Tweak
        if isTweakAvailable {
            do {
                let success = try await tweakClient.longPress(x: x, y: y, duration: duration)
                if success {
                    return ActionResult(success: true, method: .xpc)
                }
            } catch {
                print("[ActionCoordinator] XPC长按失败: \(error)")
            }
        }
        
        // 层级2: ZXTouch
        if enableFallback && isZXTouchAvailable {
            do {
                let success = try await performZXTouchLongPress(x: x, y: y, duration: duration)
                if success {
                    return ActionResult(success: true, method: .zxtouch)
                }
            } catch {
                print("[ActionCoordinator] ZXTouch长按失败: \(error)")
            }
        }
        
        return ActionResult(success: false, method: .unavailable)
    }
    
    /// 按下Home键
    func performHomeButton() async -> ActionResult {
        print("[ActionCoordinator] 执行Home键")
        
        // 层级1: XPC/Tweak
        if isTweakAvailable {
            do {
                let success = try await tweakClient.pressHome()
                if success {
                    return ActionResult(success: true, method: .xpc)
                }
            } catch {
                print("[ActionCoordinator] XPC Home键失败: \(error)")
            }
        }
        
        // 层级2: URL Schemes调用Siri打开主屏幕
        if enableFallback {
            return await performHomeViaShortcuts()
        }
        
        return ActionResult(success: false, method: .unavailable)
    }
    
    /// 打开指定应用
    func openApp(bundleId: String) async -> ActionResult {
        print("[ActionCoordinator] 打开应用: \(bundleId)")
        
        // 层级1: XPC/Tweak
        if isTweakAvailable {
            do {
                let success = try await tweakClient.openApp(bundleId: bundleId)
                if success {
                    return ActionResult(success: true, method: .xpc)
                }
            } catch {
                print("[ActionCoordinator] XPC打开应用失败: \(error)")
            }
        }
        
        // 层级2: URL Schemes
        if enableFallback {
            return await performOpenAppViaURLScheme(bundleId: bundleId)
        }
        
        return ActionResult(success: false, method: .unavailable)
    }
    
    /// 截图
    func takeScreenshot() async -> ActionResult {
        print("[ActionCoordinator] 执行截图")
        
        // 层级1: XPC/Tweak
        if isTweakAvailable {
            do {
                let data = try await tweakClient.takeScreenshot()
                if data != nil {
                    return ActionResult(success: true, method: .xpc, message: "截图成功")
                }
            } catch {
                print("[ActionCoordinator] XPC截图失败: \(error)")
            }
        }
        
        // 层级2: 系统截图API
        if enableFallback {
            return await performScreenshotViaSystemAPI()
        }
        
        return ActionResult(success: false, method: .unavailable)
    }
    
    // MARK: - 降级实现
    
    /// 通过ZXTouch执行点击
    private func performZXTouchTap(x: Int, y: Int) async throws -> Bool {
        // TODO: 实现ZXTouch TCP通信
        // 协议: send("touch \(x) \(y)\n")
        throw ActionCoordinatorError.allMethodsFailed
    }
    
    /// 通过ZXTouch执行滑动
    private func performZXTouchSwipe(fromX: Int, fromY: Int, toX: Int, toY: Int, duration: Double) async throws -> Bool {
        // TODO: 实现ZXTouch TCP滑动
        throw ActionCoordinatorError.allMethodsFailed
    }
    
    /// 通过ZXTouch执行长按
    private func performZXTouchLongPress(x: Int, y: Int, duration: Double) async throws -> Bool {
        // TODO: 实现ZXTouch TCP长按
        throw ActionCoordinatorError.allMethodsFailed
    }
    
    /// 通过Shortcuts按Home键
    private func performHomeViaShortcuts() async -> ActionResult {
        // 使用prefs:root= 来打开设置界面作为兜底
        // 但实际上iOS不提供直接返回主屏幕的URL Scheme
        // 这个方法只能作为提示：建议用户手动回到主屏幕
        
        return ActionResult(
            success: false,
            method: .shortcuts,
            message: "Shortcuts不支持返回主屏幕"
        )
    }
    
    /// 通过URL Scheme打开应用
    private func performOpenAppViaURLScheme(bundleId: String) async -> ActionResult {
        // 常见的URL Scheme格式: twitter://, fb:// 等
        // 但大多数应用不提供此接口
        
        // 对于SpringBoard，可以尝试打开相册等系统应用
        if bundleId == "com.apple.mobileslideshow" {
            if let url = URL(string: "photos-redirect://") {
                if await UIApplication.shared.open(url) {
                    return ActionResult(success: true, method: .shortcuts, message: "已打开相册")
                }
            }
        }
        
        return ActionResult(success: false, method: .shortcuts, message: "URL Scheme不可用")
    }
    
    /// 通过系统API截图
    private func performScreenshotViaSystemAPI() async -> ActionResult {
        // iOS的系统截图需要UIApplication接口，但只能截取App自身的画面
        
        return ActionResult(
            success: false,
            method: .shortcuts,
            message: "系统API无法截取其他应用画面"
        )
    }
    
    // MARK: - 诊断
    
    /// 获取诊断信息
    func getDiagnostics() -> [String: Any] {
        return [
            "tweakAvailable": isTweakAvailable,
            "tweakState": tweakClient.getConnectionState().rawValue,
            "zxtouchAvailable": isZXTouchAvailable,
            "actionTimeout": actionTimeout,
            "fallbackEnabled": enableFallback
        ]
    }
}
