//
//  ContentView.swift
//  StarCore
//
//  Created by StarCore Team on 2026-05-29.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var configManager: ConfigManager
    
    // 底部标签栏选择
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // 标签 0: 对话窗口
                ChatView()
                    .tabItem {
                        Label("💬 对话", systemImage: "message")
                    }
                    .tag(0)
                
                // 标签 1: 记忆管理
                MemoryView()
                    .tabItem {
                        Label("🧠 记忆", systemImage: "brain")
                    }
                    .tag(1)
                
                // 标签 2: 文件管理
                FileView()
                    .tabItem {
                        Label("📁 文件", systemImage: "folder")
                    }
                    .tag(2)
                
                // 标签 3: 终端控制
                TerminalView()
                    .tabItem {
                        Label("🖥️ 终端", systemImage: "terminal")
                    }
                    .tag(3)
                
                // 标签 4: 设置
                SettingsView()
                    .tabItem {
                        Label("⚙️ 设置", systemImage: "gear")
                    }
                    .tag(4)
            }
            .navigationTitle("星核 StarCore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 顶部工具栏：模型切换
                ToolbarItem(placement: .navigationBarLeading) {
                    ModelSelectorButton()
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showCloudStatus()
                    }) {
                        Image(systemName: configManager.isCloudConnected ? "cloud.checkmark" : "cloud")
                            .foregroundColor(configManager.isCloudConnected ? .green : .gray)
                    }
                }
            }
        }
    }
    
    private func showCloudStatus() {
        // 显示云电脑连接状态弹窗
        // TODO: 实现云电脑状态查看
    }
}

// MARK: - 模型选择器按钮
struct ModelSelectorButton: View {
    @EnvironmentObject var configManager: ConfigManager
    
    var body: some View {
        Menu {
            ForEach(LLMModel.allCases, id: \.self) { model in
                Button(action: {
                    configManager.switchModel(model)
                }) {
                    Label(model.displayName, systemImage: "star")
                }
            }
        } label: {
            Label(configManager.currentModel.displayName, systemImage: "star")
                .foregroundColor(.blue)
        }
    }
}

// MARK: - 终端视图
struct TerminalView: View {
    @StateObject private var terminal = LocalTerminal.shared
    @StateObject private var mcpClient = IOSMCPClient.shared
    @State private var commandInput = ""
    @State private var selectedMode = 0  // 0: 终端，1: iOS MCP
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部模式切换
                Picker("模式", selection: $selectedMode) {
                    Text("本地终端").tag(0)
                    Text("iOS MCP").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedMode == 0 {
                    // 终端模式
                    terminalBody
                } else {
                    // iOS MCP 模式
                    mcpBody
                }
            }
            .navigationTitle("🖥️ 终端控制")
        }
    }
    
    var terminalBody: some View {
        VStack {
            // 输出区域
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("📋 本地终端 - 越狱设备可用")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if terminal.lastOutput.isEmpty {
                        Text("等待命令...")
                            .foregroundColor(.gray)
                            .italic()
                    } else {
                        Text(terminal.lastOutput)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding()
            }
            
            // 输入区域
            HStack {
                TextField("输入命令...", text: $commandInput)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                Button(action: {
                    executeCommand()
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(commandInput.isEmpty || terminal.isExecuting)
            }
            .padding()
        }
    }
    
    var mcpBody: some View {
        VStack {
            // 连接状态
            HStack {
                Image(systemName: mcpClient.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(mcpClient.isConnected ? .green : .red)
                Text(mcpClient.isConnected ? "已连接" : "未连接")
                Spacer()
                if !mcpClient.availableTools.isEmpty {
                    Text("\(mcpClient.availableTools.count) 个工具")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            // 工具列表
            if !mcpClient.availableTools.isEmpty {
                List(mcpClient.availableTools, id: \.self) { tool in
                    Button(action: {
                        runMCPTool(tool)
                    }) {
                        HStack {
                            Text(tool)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
            } else if mcpClient.isConnected == false {
                VStack {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("iOS MCP 服务未运行")
                        .foregroundColor(.gray)
                    Text("请确保 ios-mcp 服务在 localhost:8090 运行")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            
            // 快捷操作
            if mcpClient.isConnected {
                VStack(spacing: 12) {
                    Text("快捷操作")
                        .font(.headline)
                    
                    HStack {
                        Button("📸 截图") { runMCPTool("screenshot") }
                        Button("🏠 Home") { runMCPTool("press_home") }
                        Button("📱 前台应用") { runMCPTool("get_frontmost_app") }
                    }
                    
                    HStack {
                        Button("👆 点击") { runMCPTool("tap_screen") }
                        Button("👆 滑动") { runMCPTool("swipe_screen") }
                        Button("⌨️ 输入") { runMCPTool("input_text") }
                    }
                }
                .padding()
            }
        }
    }
    
    func executeCommand() {
        guard !commandInput.isEmpty else { return }
        let cmd = commandInput
        commandInput = ""
        
        Task {
            let output = await terminal.execute(command: cmd)
            print("终端输出：\(output)")
        }
    }
    
    func runMCPTool(_ tool: String) {
        Task {
            var result = ""
            switch tool {
            case "screenshot":
                result = await mcpClient.screenshot()
            case "press_home":
                result = await mcpClient.pressHome()
            case "get_frontmost_app":
                result = await mcpClient.getFrontmostApp()
            case "tap_screen":
                result = await mcpClient.tap(x: 500, y: 1000)  // 示例坐标
            case "swipe_screen":
                result = await mcpClient.swipe(fromX: 500, fromY: 1500, toX: 500, toY: 500)
            case "input_text":
                result = await mcpClient.input(text: "测试输入")
            default:
                result = await mcpClient.callTool(name: tool, arguments: [:])
            }
            print("MCP 结果：\(result)")
            // TODO: 显示结果到 UI
        }
    }
}

// MARK: - 云电脑状态
struct CloudStatusView: View {
    @EnvironmentObject var configManager: ConfigManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("☁️ 云电脑状态")
                .font(.headline)
            
            Divider()
            
            HStack {
                Text("服务器:")
                Spacer()
                Text(configManager.serverIP)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("SSH 隧道:")
                Spacer()
                if configManager.isCloudConnected {
                    Text("✅ 已连接 (端口 8028)")
                        .foregroundColor(.green)
                } else {
                    Text("❌ 未连接")
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Text("星核 daemon:")
                Spacer()
                Text(configManager.daemonStatus)
            }
            
            HStack {
                Text("CycleSystem:")
                Spacer()
                Text(configManager.cycleSystemStatus)
            }
            
            Divider()
            
            Button(configManager.isCloudConnected ? "断开连接" : "连接云电脑") {
                if configManager.isCloudConnected {
                    configManager.disconnectCloud()
                } else {
                    configManager.connectCloud()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(ChatManager())
        .environmentObject(ConfigManager())
}
