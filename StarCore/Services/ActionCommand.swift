/**
 * ActionCommand.swift
 * 动作命令模型 - 定义所有可执行动作的枚举与序列化
 *
 * 设计原则：
 * - 使用枚举定义所有操控动作，保证类型安全
 * - 支持坐标、文字、时长等参数
 * - 可序列化为ZXTouch协议格式
 * - 可扩展为其他协议格式（XPC、Shortcuts等）
 */

import Foundation

// MARK: - 动作命令枚举

/// 所有可执行的操控动作
enum ActionCommand: Equatable, CustomStringConvertible {
    /// 点击坐标 (x, y为逻辑像素)
    case tap(x: Int, y: Int)

    /// 滑动 (duration为毫秒)
    case swipe(fromX: Int, fromY: Int, toX: Int, toY: Int, duration: Int)

    /// 长按 (duration为毫秒)
    case touchHold(x: Int, y: Int, duration: Int)

    /// 输入文字
    case typeText(text: String)

    /// 截图
    case screenshot

    /// 打开App
    case openApp(bundleId: String)

    /// 回到主屏幕
    case goHome

    /// 执行Shell命令
    case runShell(command: String)

    /// 显示弹窗
    case showAlert(title: String, content: String, duration: Int)

    /// 自定义指令（用于扩展）
    case custom(command: String, params: [String])

    // MARK: - CustomStringConvertible

    var description: String {
        switch self {
        case .tap(let x, let y):
            return "点击(\(x), \(y))"
        case .swipe(let fromX, let fromY, let toX, let toY, let duration):
            return "滑动(\(fromX),\(fromY))→(\(toX),\(toY)) \(duration)ms"
        case .touchHold(let x, let y, let duration):
            return "长按(\(x),\(y)) \(duration)ms"
        case .typeText(let text):
            return "输入\"\(text.prefix(20))\(text.count > 20 ? "..." : "")\""
        case .screenshot:
            return "截图"
        case .openApp(let bundleId):
            return "打开\(bundleId)"
        case .goHome:
            return "回主屏幕"
        case .runShell(let cmd):
            return "Shell: \(cmd.prefix(30))"
        case .showAlert(let title, _, _):
            return "弹窗\"\(title)\""
        case .custom(let cmd, _):
            return "自定义: \(cmd)"
        }
    }
}

// MARK: - 命令分类

extension ActionCommand {

    /// 动作分类
    enum Category: String, CaseIterable {
        case touch = "触摸"
        case input = "输入"
        case system = "系统"
        case advanced = "高级"
    }

    /// 所属分类
    var category: Category {
        switch self {
        case .tap, .swipe, .touchHold:
            return .touch
        case .typeText:
            return .input
        case .screenshot, .goHome, .openApp:
            return .system
        case .runShell, .showAlert, .custom:
            return .advanced
        }
    }
}

// MARK: - 坐标验证

extension ActionCommand {

    /// iPhone X逻辑分辨率
    static let iPhoneXScreenWidth = 375
    static let iPhoneXScreenHeight = 812

    /// 验证坐标是否在iPhone X屏幕范围内
    /// - Note: 使用逻辑像素坐标，ZXTouchClient内部会×10转换为物理坐标
    static func isValidCoordinate(x: Int, y: Int) -> Bool {
        return x >= 0 && x <= iPhoneXScreenWidth && y >= 0 && y <= iPhoneXScreenHeight
    }

    /// 修正坐标到屏幕范围内
    static func clampCoordinate(x: Int, y: Int) -> (x: Int, y: Int) {
        return (
            max(0, min(x, iPhoneXScreenWidth)),
            max(0, min(y, iPhoneXScreenHeight))
        )
    }
}

// MARK: - 命令构建器

/// 动作命令构建器 - 便捷创建常用命令
struct ActionCommandBuilder {

    /// 创建点击命令（自动验证坐标）
    static func tap(x: Int, y: Int) -> ActionCommand {
        let clamped = ActionCommand.clampCoordinate(x: x, y: y)
        return .tap(x: clamped.x, y: clamped.y)
    }

    /// 创建向上滑动命令
    static func swipeUp(distance: Int = 200, fromX: Int = 187, fromY: Int = 600) -> ActionCommand {
        return .swipe(fromX: fromX, fromY: fromY, toX: fromX, toY: fromY - distance, duration: 300)
    }

    /// 创建向下滑动命令
    static func swipeDown(distance: Int = 200, fromX: Int = 187, fromY: Int = 300) -> ActionCommand {
        return .swipe(fromX: fromX, fromY: fromY, toX: fromX, toY: fromY + distance, duration: 300)
    }

    /// 创建向左滑动命令
    static func swipeLeft(distance: Int = 200, fromY: Int = 400) -> ActionCommand {
        return .swipe(fromX: 300, fromY: fromY, toX: 300 - distance, toY: fromY, duration: 300)
    }

    /// 创建向右滑动命令
    static func swipeRight(distance: Int = 200, fromY: Int = 400) -> ActionCommand {
        return .swipe(fromX: 75, fromY: fromY, toX: 75 + distance, toY: fromY, duration: 300)
    }

    /// 创建回到主屏幕命令
    static func goHome() -> ActionCommand {
        return .goHome
    }

    /// 创建长按命令（默认1秒）
    static func longPress(x: Int, y: Int, durationMs: Int = 1000) -> ActionCommand {
        let clamped = ActionCommand.clampCoordinate(x: x, y: y)
        return .touchHold(x: clamped.x, y: clamped.y, duration: durationMs)
    }
}

// MARK: - 命令执行记录

/// 动作执行记录（用于日志和回放）
struct ActionLogEntry: Identifiable {
    let id = UUID()
    let command: ActionCommand
    let result: ActionResult
    let timestamp: Date

    var isSuccess: Bool { result.success }
    var method: ActionMethod { result.method }

    var summary: String {
        let status = isSuccess ? "✅" : "❌"
        return "\(status) \(command.description) [\(method.rawValue)]"
    }
}

// MARK: - 坐标预设

/// 常用坐标预设（iPhone X逻辑分辨率）
enum ScreenPreset {
    case center          // 屏幕中心
    case homeIndicator   // 底部横条
    case topCenter       // 顶部中央
    case notification    // 通知中心下拉起始
    case controlCenter   // 控制中心

    var coordinate: (x: Int, y: Int) {
        switch self {
        case .center:           return (187, 406)
        case .homeIndicator:    return (187, 790)
        case .topCenter:        return (187, 50)
        case .notification:     return (187, 0)
        case .controlCenter:    return (187, 0)
        }
    }
}
