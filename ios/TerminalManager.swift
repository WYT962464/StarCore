//
//  TerminalManager.swift
//  StarCore
//
//  Created by StarCore Team on 2026-05-29.
//  统一终端执行路由层 - AI 如臂指使的"神经系统"
//

import Foundation
import Combine
import UIKit

// MARK: - 终端执行后端协议
/// 所有终端后端必须实现此协议
protocol TerminalBackend: ObservableObject {
    /// 后端名称
    var name: String { get }
    
    /// 是否可用
    var isAvailable: Bool { get }
    
    /// 检查后端是否就绪
    func checkReady() async -> Bool
    
    /// 执行命令
    /// - Parameter command: 要执行的命令
    /// - Returns: 命令输出
    func execute(_ command: String) async -> String
}

// MARK: - 终端执行策略
enum TerminalStrategy: String, CaseIterable {
    case local = "local"           // 本地 Process（越狱设备）
    case newterm = "newterm"       // NewTerm URL Scheme
    case ashell = "ashell"         // a-Shell x-callback-url
    case remote = "remote"         // iOS MCP + SSH 隧道（远程执行）
    
    var description: String {
        switch self {
        case .local: return "本地执行（越狱设备，可获取输出）"
        case .newterm: return "NewTerm URL Scheme（简单命令，无法获取输出）"
        case .ashell: return "a-Shell x-callback-url（支持输出回调）"
        case .remote: return "iOS MCP + SSH 隧道（远程执行，可获取输出）"
        }
    }
}

// MARK: - 终端执行结果
struct TerminalResult {
    let command: String
    let output: String
    let strategy: TerminalStrategy
    let backend: String
    let success: Bool
    let timestamp: Date
    
    var summary: String {
        return "✅ \(command)\n📤 \(output.prefix(200))\n🔧 \(backend)"
    }
}

// MARK: - 统一终端管理器
/// AI 如臂指使的"神经系统" — 统一终端执行路由层
/// 
/// 根据设备环境自动选择最佳后端：
/// - 越狱 + SSH 隧道 → LocalTerminal（本地 Process）
/// - 越狱 + 无隧道 → NewTerm URL Scheme
/// - 非越狱 → iOS MCP + SSH 隧道（远程执行）
class TerminalManager: ObservableObject {
    static let shared = TerminalManager()
    
    @Published var currentStrategy: TerminalStrategy = .local
    @Published var availableBackends: [String] = []
    @Published var lastResult: TerminalResult?
    @Published var isExecuting: Bool = false
    
    // 后端实例
    private let localTerminal = LocalTerminal.shared
    private let newtermTerminal = NewTermTerminal.shared
    private let ashellTerminal = AShellTerminal.shared
    
    // 环境检测
    private var isJailbroken: Bool = false
    private var hasSSHTunnel: Bool = false
    
    init() {
        Task {
            await detectEnvironment()
        }
    }
    
    // MARK: - 环境检测
    /// 自动检测设备环境，选择最佳后端
    @MainActor
    private func detectEnvironment() {
        // 检测越狱环境
        let jailbreakPaths = [
            "/var/jb",
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/usr/libexec/sileo"
        ]
        isJailbroken = jailbreakPaths.contains { FileManager.default.fileExists(atPath: $0) }
        
        // 检测 SSH 隧道（iOS MCP 服务）
        hasSSHTunnel = checkSSHTunnel()
        
        // 检测各后端可用性
        var backends: [String] = []
        
        if isJailbroken {
            backends.append("local")
        }
        
        if newtermTerminal.isInstalled() {
            backends.append("newterm")
        }
        
        if ashellTerminal.isInstalled() {
            backends.append("ashell")
        }
        
        if hasSSHTunnel {
            backends.append("remote")
        }
        
        availableBackends = backends
        
        // 自动选择最佳策略
        currentStrategy = selectBestStrategy()
        
        print("🔍 环境检测完成:")
        print("  越狱: \(isJailbroken)")
        print("  SSH 隧道: \(hasSSHTunnel)")
        print("  可用后端: \(backends)")
        print("  当前策略: \(currentStrategy.rawValue)")
    }
    
    /// 检测 SSH 隧道是否可用
    private func checkSSHTunnel() -> Bool {
        // 检查 iOS MCP 服务端口
        let port = 8090
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = UInt32(0x7F000001) // 127.0.0.1
        
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        
        var timeout = 2.0
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        return result == 0
    }
    
    // MARK: - 策略选择
    /// 根据环境自动选择最佳策略
    private func selectBestStrategy() -> TerminalStrategy {
        // 优先级：local > remote > ashell > newterm
        if isJailbroken && FileManager.default.fileExists(atPath: "/usr/bin/env") {
            return .local
        }
        
        if hasSSHTunnel {
            return .remote
        }
        
        if ashellTerminal.isInstalled() {
            return .ashell
        }
        
        if newtermTerminal.isInstalled() {
            return .newterm
        }
        
        return .newterm // 默认
    }
    
    // MARK: - 统一执行接口
    /// 执行命令 — AI 如臂指使的核心接口
    /// - Parameter command: 要执行的命令
    /// - Returns: 执行结果
    @MainActor
    func execute(_ command: String) async -> TerminalResult {
        isExecuting = true
        defer { isExecuting = false }
        
        print("🖥️ [TerminalManager] 执行命令: \(command)")
        print("📍 当前策略: \(currentStrategy.rawValue)")
        
        var output: String = ""
        var success: Bool = false
        var backendName: String = ""
        
        do {
            switch currentStrategy {
            case .local:
                // 本地 Process 执行（越狱设备）
                backendName = "LocalTerminal"
                output = await localTerminal.execute(command: command)
                success = !output.contains("❌")
                
            case .newterm:
                // NewTerm URL Scheme
                backendName = "NewTerm"
                newtermTerminal.execute(command: command)
                output = "✅ 已在 NewTerm 中启动命令: \(command)\n⚠️ 注意：无法直接获取命令输出，请在 NewTerm 中查看结果"
                success = true
                
            case .ashell:
                // a-Shell x-callback-url
                backendName = "a-Shell"
                output = await ashellTerminal.execute(command: command)
                success = !output.contains("❌")
                
            case .remote:
                // iOS MCP + SSH 隧道（远程执行）
                backendName = "iOS MCP (Remote)"
                output = await executeRemote(command: command)
                success = !output.contains("❌")
            }
            
        } catch {
            output = "❌ 执行异常: \(error.localizedDescription)"
            success = false
        }
        
        let result = TerminalResult(
            command: command,
            output: output,
            strategy: currentStrategy,
            backend: backendName,
            success: success,
            timestamp: Date()
        )
        
        lastResult = result
        
        if success {
            print("✅ 命令执行成功")
        } else {
            print("❌ 命令执行失败")
        }
        
        return result
    }
    
    // MARK: - 远程执行（iOS MCP + SSH 隧道）
    private func executeRemote(command: String) async -> String {
        // 通过 iOS MCP 调用服务器执行命令
        // 注意：当前 iOS MCP 没有 exec 工具，需要扩展
        // 临时方案：通过 URL Scheme 调用服务器端脚本
        
        let serverURL = "http://localhost:8080" // 服务器端 API
        
        // 检查服务器端是否有 exec 接口
        guard let url = URL(string: "\(serverURL)/api/exec") else {
            return "❌ 服务器端 exec 接口不可用"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["command": command]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return "❌ 服务器响应异常: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
            }
            
            let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return result?["output"] as? String ?? "✅ 命令已提交"
            
        } catch {
            return "❌ 远程执行失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 快捷方法
    /// 执行命令并返回纯输出字符串
    func run(_ command: String) async -> String {
        let result = await execute(command)
        return result.output
    }
    
    /// 执行命令并返回成功状态
    func runSuccess(_ command: String) async -> Bool {
        let result = await execute(command)
        return result.success
    }
    
    // MARK: - 策略切换
    /// 手动切换执行策略
    @MainActor
    func switchStrategy(_ strategy: TerminalStrategy) {
        currentStrategy = strategy
        print("🔄 策略已切换: \(strategy.rawValue)")
    }
    
    /// 获取当前可用策略列表
    func getAvailableStrategies() -> [TerminalStrategy] {
        return TerminalStrategy.allCases.filter { strategy in
            switch strategy {
            case .local: return isJailbroken
            case .newterm: return newtermTerminal.isInstalled()
            case .ashell: return ashellTerminal.isInstalled()
            case .remote: return hasSSHTunnel
            }
        }
    }
}

// MARK: - 全局快捷函数
/// 全局终端执行快捷函数 — AI 如臂指使
func terminal(_ command: String) async -> String {
    return await TerminalManager.shared.run(command)
}

func terminalSuccess(_ command: String) async -> Bool {
    return await TerminalManager.shared.runSuccess(command)
}
