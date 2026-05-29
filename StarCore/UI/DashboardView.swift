/**
 * DashboardView.swift
 * 星核主仪表盘 - 生命体征 + 情绪 + 人格状态
 */

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var hardwareSensor: HardwareSensor
    @EnvironmentObject var mcpClient: iOSMCPClient
    @EnvironmentObject var llmManager: LLMManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 生命体征卡片
                    LifeSignsCard(
                        cpuUsage: hardwareSensor.cpuUsage,
                        batteryLevel: hardwareSensor.batteryLevel,
                        thermalState: hardwareSensor.thermalState
                    )
                    
                    // 情绪状态卡片
                    EmotionStatusCard(
                        arousal: hardwareSensor.arousal,
                        valence: hardwareSensor.valence
                    )
                    
                    // 人格状态卡片
                    PersonaStateCard()
                    
                    // 服务状态
                    ServiceStatusCard(
                        mcpConnected: mcpClient.isConnected,
                        serverConnected: serverConnection.isConnected,
                        llmModel: llmManager.currentModel
                    )
                }
                .padding()
            }
            .navigationTitle("星核状态")
        }
    }
}

// MARK: - 子视图
struct LifeSignsCard: View {
    let cpuUsage: Double
    let batteryLevel: Double
    let thermalState: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🫀 生命体征")
                .font(.headline)
            
            HStack {
                VStack {
                    Text("\(Int(cpuUsage))%")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("心率")
                        .font(.caption)
                }
                
                VStack {
                    Text("\(Int(batteryLevel))%")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("能量")
                        .font(.caption)
                }
                
                VStack {
                    Text("\(thermalState)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("体温")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct EmotionStatusCard: View {
    let arousal: Double
    let valence: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💭 情绪状态")
                .font(.headline)
            
            HStack {
                VStack {
                    Text("\(Int(arousal * 100))")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("唤醒度")
                        .font(.caption)
                }
                
                VStack {
                    Text("\(Int(valence * 100))")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("效价")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
}

struct PersonaStateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎭 人格状态")
                .font(.headline)
            
            Text("出厂空白人格，正在通过交互学习进化...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ServiceStatusCard: View {
    let mcpConnected: Bool
    let serverConnected: Bool
    let llmModel: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔌 服务状态")
                .font(.headline)
            
            HStack {
                Text("iOS MCP")
                Spacer()
                Image(systemName: mcpConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(mcpConnected ? .green : .red)
            }
            
            HStack {
                Text("SSH隧道")
                Spacer()
                Image(systemName: serverConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(serverConnected ? .green : .red)
            }
            
            HStack {
                Text("LLM模型")
                Spacer()
                Text(llmModel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}
