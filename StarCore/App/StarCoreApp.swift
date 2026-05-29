/**
 * StarCoreApp.swift
 * 星核 - 双层架构智能体核心系统
 * 
 * 架构：
 * 阶段十：生命中枢 (LifeCore + 生存能力 + 生理引擎)
 * 阶段十二：人格认知 (MindCore + EmotionEngine + PersonaState)
 * 操控服务层：ZXTouch + Tweak TCP + SSH隧道
 */

import SwiftUI

@main
struct StarCoreApp: App {
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
                    hardwareSensor.refresh()
                    mcpClient.checkConnection()
                    serverConnection.connect()
                }
        }
    }
}
