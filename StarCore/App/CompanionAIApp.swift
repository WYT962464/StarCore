/**
 * CompanionAIApp.swift
 * 智慧陪伴型 AI App - 主入口
 * 
 * 架构：
 * 手机端：硬件感知 + 工具执行 + 陪伴交互
 * 云端端：AI 决策（多云端可选）
 * 连接：SSH 隧道
 */

import SwiftUI

@main
struct CompanionAIApp: App {
    // MARK: - 核心服务
    @StateObject private var hardwareSensor = HardwareSensor()
    @StateObject private var mcpClient = iOSMCPClient()
    @StateObject private var llmManager = LLMManager()
    @StateObject private var serverConnection = ServerConnectionManager()
    @StateObject private var chatManager = ChatManager()
    
    var body: some Scene {
        WindowGroup {
            StarCoreConsole()
                .environmentObject(hardwareSensor)
                .environmentObject(mcpClient)
                .environmentObject(llmManager)
                .environmentObject(serverConnection)
                .environmentObject(chatManager)
                .onAppear {
                    // 启动时初始化
                    hardwareSensor.refresh()
                    mcpClient.checkConnection()
                }
        }
    }
}
