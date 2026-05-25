/**
 * SettingsView.swift
 * 设置页面
 * 
 * 功能：
 * - LLM 提供商配置（火山方舟/商汤 SenseNova/DeepSeek/自定义）
 * - Tweak 连接管理
 * - 小智 AI 配置
 * - 系统设置
 */

import SwiftUI

@available(iOS 15.0, *)
struct SettingsView: View {
    @EnvironmentObject var lifeCore: LifeCore
    @EnvironmentObject var mindCore: MindCore
    
    @State private var selectedProvider = "volcano"
    @State private var apiKey = "ark-5db3deab-6e44-46f5-ad83-95..."
    @State private var endpoint = "ep-20260510055430-pkn8w"
    @State private var tweakConnected = true
    @State private var tweakEndpoint = "127.0.0.1:6000"
    @State private var xiaozhiConnected = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // LLM Provider
                    llmProviderSection
                    
                    // Tweak 连接
                    tweakConnectionSection
                    
                    // Tweak 状态
                    tweakStatusSection
                    
                    // 小智 AI
                    xiaozhiSection
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - LLM Provider 配置
    private var llmProviderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "robot")
                    .foregroundColor(.blue)
                Text("LLM Provider")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            // 提供商选择
            HStack(spacing: 8) {
                providerButton("火山方舟", isSelected: selectedProvider == "volcano", action: { selectedProvider = "volcano" })
                providerButton("自定义", isSelected: selectedProvider == "custom", action: { selectedProvider = "custom" })
                providerButton("商汤 SenseNova", isSelected: selectedProvider == "sensenova", action: { selectedProvider = "sensenova" })
                providerButton("DeepSeek", isSelected: selectedProvider == "deepseek", action: { selectedProvider = "deepseek" })
            }
            
            // API Key
            configField("API Key", text: $apiKey, isSecure: true)
            
            // Endpoint
            configField("Endpoint", text: $endpoint, isSecure: false)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 30/255, green: 30/255, blue: 63/255)))
    }
    
    private func providerButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.purple.opacity(0.6) : Color.gray.opacity(0.3))
                .cornerRadius(20)
                .foregroundColor(.white)
        }
    }
    
    private func configField(_ label: String, text: Binding<String>, isSecure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            
            if isSecure {
                SecureField("", text: text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                TextField("", text: text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    // MARK: - Tweak 连接
    private var tweakConnectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "wrench")
                    .foregroundColor(.blue)
                Text("Tweak 连接")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("已连接")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Button(action: {
                // 重新连接 Tweak
                tweakConnected.toggle()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("重新连接 Tweak")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(10)
                .foregroundColor(.white)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 30/255, green: 30/255, blue: 63/255)))
    }
    
    // MARK: - Tweak 状态
    private var tweakStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(.blue)
                Text("Tweak 状态")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("已连接 (\(tweakEndpoint))")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Button(action: {
                // 检测 Tweak 连接
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text("检测 Tweak 连接")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(10)
                .foregroundColor(.white)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 30/255, green: 30/255, blue: 63/255)))
    }
    
    // MARK: - 小智 AI
    private var xiaozhiSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "mic")
                    .foregroundColor(.blue)
                Text("小智 AI (WSS→Tweak TCP)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            TextField("输入配置...", text: .constant(""))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.vertical, 8)
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("已连接")
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
                
                Spacer()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 30/255, green: 30/255, blue: 63/255)))
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(LifeCore())
            .environmentObject(MindCore(lifeCoreReadOnly: LifeCoreReadOnlyWrapper(lifeCore: LifeCore())))
    }
}
