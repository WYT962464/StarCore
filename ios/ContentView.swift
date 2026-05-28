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
                
                // 标签 3: 设置
                SettingsView()
                    .tabItem {
                        Label("⚙️ 设置", systemImage: "gear")
                    }
                    .tag(3)
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
                        // 云电脑连接状态
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
            ForEach(LLMModel.allCases) { model in
                Button {
                    configManager.switchModel(model)
                } label: {
                    HStack {
                        Text(model.displayName)
                        if model == configManager.currentModel {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "cpu")
                Text(configManager.currentModel.displayName)
                    .font(.caption)
            }
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
