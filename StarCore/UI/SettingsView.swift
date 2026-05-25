/**
 * SettingsView.swift
 * 设置页面 - LLM 提供商配置
 * 
 * 设计参考用户提供的截图：
 * - 提供商选择按钮（火山方舟/自定义/商汤/DeepSeek）
 * - 选中状态紫色高亮
 * - API Key 输入框
 * - Endpoint 输入框
 */

import SwiftUI

@available(iOS 15.0, *)
struct SettingsView: View {
    @EnvironmentObject var llmManager: LLMManager
    @EnvironmentObject var serverConnection: ServerConnectionManager
    @EnvironmentObject var chatManager: ChatManager
    
    @State private var showingProviderList = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                // 深色背景
                LinearGradient(
                    colors: [Color(red: 10/255, green: 20/255, blue: 45/255), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // LLM 提供商配置
                        llmProviderSection
                        
                        // 服务器连接
                        serverConnectionSection
                        
                        // 系统提示词
                        systemPromptSection
                        
                        // 费用监控
                        costMonitoringSection
                        
                        // 关于
                        aboutSection
                    }
                    .padding()
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        // 保存并返回
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - LLM 提供商配置
    private var llmProviderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("LLM Provider")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            // 提供商选择按钮
            HStack(spacing: 8) {
                providerButton("火山方舟", index: 0)
                providerButton("自定义", index: 3)
                providerButton("商汤", index: 2)
                providerButton("DeepSeek", index: 1)
            }
            
            // API Key 输入
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                SecureField("输入 API Key", text: Binding(
                    get: { llmManager.currentProvider.apiKey },
                    set: { llmManager.updateProvider(
                        LLMProvider(
                            name: llmManager.currentProvider.name,
                            url: llmManager.currentProvider.url,
                            model: llmManager.currentProvider.model,
                            apiKey: $0
                        ),
                        at: llmManager.currentProviderIndex
                    )}
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(12)
                .background(Color(red: 30/255, green: 30/255, blue: 50/255))
                .cornerRadius(8)
            }
            
            // Endpoint 输入
            VStack(alignment: .leading, spacing: 8) {
                Text("Endpoint")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                TextField("输入 Endpoint", text: Binding(
                    get: { llmManager.currentProvider.url },
                    set: { llmManager.updateProvider(
                        LLMProvider(
                            name: llmManager.currentProvider.name,
                            url: $0,
                            model: llmManager.currentProvider.model,
                            apiKey: llmManager.currentProvider.apiKey
                        ),
                        at: llmManager.currentProviderIndex
                    )}
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(12)
                .background(Color(red: 30/255, green: 30/255, blue: 50/255))
                .cornerRadius(8)
            }
            
            // 模型选择
            VStack(alignment: .leading, spacing: 8) {
                Text("Model")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                TextField("输入模型名称", text: Binding(
                    get: { llmManager.currentProvider.model },
                    set: { llmManager.updateProvider(
                        LLMProvider(
                            name: llmManager.currentProvider.name,
                            url: llmManager.currentProvider.url,
                            model: $0,
                            apiKey: llmManager.currentProvider.apiKey
                        ),
                        at: llmManager.currentProviderIndex
                    )}
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(12)
                .background(Color(red: 30/255, green: 30/255, blue: 50/255))
                .cornerRadius(8)
            }
            
            // 状态指示
            HStack {
                Circle()
                    .fill(llmManager.currentProvider.isConfigured ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(llmManager.currentProvider.isConfigured ? "已配置" : "未配置")
                    .font(.caption)
                    .foregroundColor(llmManager.currentProvider.isConfigured ? .green : .orange)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 20/255, green: 20/255, blue: 40/255)))
    }
    
    private func providerButton(_ name: String, index: Int) -> some View {
        Button(action: {
            llmManager.switchProvider(to: index)
        }) {
            Text(name)
                .font(.caption)
                .fontWeight(llmManager.currentProviderIndex == index ? .semibold : .regular)
                .foregroundColor(llmManager.currentProviderIndex == index ? .white : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(llmManager.currentProviderIndex == index ? Color.purple : Color(red: 40/255, green: 40/255, blue: 60/255))
                )
        }
    }
    
    // MARK: - 服务器连接
    private var serverConnectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.green)
                Text("Server Connection")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            HStack {
                Circle()
                    .fill(serverConnection.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(serverConnection.isConnected ? "已连接" : "未连接")
                    .font(.caption)
                    .foregroundColor(serverConnection.isConnected ? .green : .red)
                
                Spacer()
                
                Text("\(serverConnection.config.host):\(serverConnection.config.tunnelPort)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Button(action: {
                serverConnection.checkConnection()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("刷新连接")
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 20/255, green: 40/255, blue: 35/255)))
    }
    
    // MARK: - 系统提示词
    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.message")
                    .foregroundColor(.purple)
                Text("System Prompt")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            TextEditor(text: $chatManager.systemPrompt)
                .frame(minHeight: 100)
                .padding(12)
                .background(Color(red: 30/255, green: 30/255, blue: 50/255))
                .cornerRadius(8)
            
            Button(action: {
                chatManager.saveSystemPrompt()
            }) {
                Text("保存提示词")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.purple))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 35/255, green: 25/255, blue: 55/255)))
    }
    
    // MARK: - 费用监控
    private var costMonitoringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "yensign")
                    .foregroundColor(.yellow)
                Text("Cost Monitoring")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("已用 Token")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(llmManager.totalTokensUsed)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("估算费用")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("¥\(String(format: "%.4f", llmManager.totalCostEstimate))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)
            }
            
            HStack {
                Text("费用阈值")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                TextField("设置阈值", value: $llmManager.costThreshold, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.white)
            }
            
            Toggle("自动切换", isOn: $llmManager.autoSwitchEnabled)
                .labelsHidden()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 50/255, green: 45/255, blue: 20/255)))
    }
    
    // MARK: - 关于
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.gray)
                Text("关于")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("版本")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("1.0.0")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("架构")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("手机端感知 + 云端决策")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 25/255, green: 25/255, blue: 25/255)))
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(LLMManager())
            .environmentObject(ServerConnectionManager())
            .environmentObject(ChatManager())
    }
}
