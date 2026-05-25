/**
 * StarCoreConsole.swift
 * 星核控制台 - 主界面
 * 
 * 设计原则：
 * 1. 只做能落地的功能（有后端数据支持的）
 * 2. 不做空壳（没有实际数据/功能的 UI）
 * 3. 待实现功能明确标记，不误导用户
 * 
 * 当前落地功能：
 * - 星核状态（心率/体温/疲劳/能量）✅
 * - 情绪状态（主导/唤醒度/效价）✅
 * - 生存模式（水熊虫/涡虫/蛭形/灯塔）✅
 * 
 * 待实现（明确标记）：
 * - 视觉闭环（截图 + 操作）→ 待 Tweak 注入
 * - AI 对话 → 待 LLM 后端
 * - 费用监控 → 待 API 调用计数
 */

import SwiftUI

@available(iOS 15.0, *)
struct StarCoreConsole: View {
    @EnvironmentObject var lifeCore: LifeCore
    @EnvironmentObject var mindCore: MindCore
    
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                // 深色背景
                LinearGradient(
                    colors: [Color.black, Color(red: 15/255, green: 15/255, blue: 35/255)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部状态栏
                    topStatusBar
                    
                    // 主内容区
                    ScrollView {
                        VStack(spacing: 16) {
                            // 星核状态卡片
                            starcoreStatusCard
                            
                            // 情绪状态卡片
                            emotionStatusCard
                            
                            // 生存模式卡片
                            survivalModeCard
                            
                            // 待实现提示
                            pendingFeaturesNotice
                        }
                        .padding()
                    }
                    
                    // 底部标签栏
                    bottomTabBar
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - 顶部状态栏
    private var topStatusBar: some View {
        HStack {
            // 应用标题
            Text("星核控制台")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            // 运行状态
            HStack(spacing: 4) {
                Circle()
                    .fill(lifeCore.cryptobiosisActive ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(lifeCore.cryptobiosisActive ? "隐生" : "活跃")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Tweak 状态（待实现）
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text("Tweak 待注入")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(red: 20/255, green: 20/255, blue: 40/255))
    }
    
    // MARK: - 星核状态卡片
    private var starcoreStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("🧠 星核状态")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 20) {
                // 心率
                VStack {
                    Text("\(Int(lifeCore.heartRate))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                    Text("bpm")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("心率")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 体温
                VStack {
                    Text("\(lifeCore.bodyTemperature)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("°C")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("体温")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 疲劳
                VStack {
                    Text("\(Int(lifeCore.fatigueLevel * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(lifeCore.fatigueLevel > 0.5 ? .red : .green)
                    Text("%")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("疲劳")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 能量
                VStack {
                    Text("\(Int(lifeCore.energyLevel * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(lifeCore.energyLevel > 0.5 ? .green : .yellow)
                    Text("%")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("能量")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 25/255, green: 25/255, blue: 55/255)))
    }
    
    // MARK: - 情绪状态卡片
    private var emotionStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "face.smiling")
                    .foregroundColor(.purple)
                Text("🌊 情绪状态")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            // 主导情绪
            HStack {
                Text(mindCore.dominantEmotion.emoji)
                    .font(.system(size: 40))
                
                VStack(alignment: .leading) {
                    Text(mindCore.dominantEmotion.rawValue)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("主导情绪")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // 唤醒度
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("唤醒度")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("能量/激活水平")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(mindCore.arousalLevel * 100))%")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange)
                            .frame(width: geometry.size.width * CGFloat(mindCore.arousalLevel), height: 6)
                    }
                }.frame(height: 6)
            }
            
            // 效价
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("效价")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("愉悦/正向程度")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(mindCore.valenceLevel * 100))%")
                        .font(.headline)
                        .foregroundColor(mindCore.valenceLevel > 0.6 ? .green : mindCore.valenceLevel < 0.4 ? .red : .yellow)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(mindCore.valenceLevel > 0.6 ? .green : mindCore.valenceLevel < 0.4 ? .red : .yellow)
                            .frame(width: geometry.size.width * CGFloat(mindCore.valenceLevel), height: 6)
                    }
                }.frame(height: 6)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 35/255, green: 25/255, blue: 55/255)))
    }
    
    // MARK: - 生存模式卡片
    private var survivalModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.shield.badge")
                    .foregroundColor(.green)
                Text("🛡️ 生存模式")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 12) {
                // 水熊虫模式
                survivalModeButton(
                    title: "水熊虫",
                    subtitle: "隐生待机",
                    icon: "drop",
                    color: .orange,
                    isActive: true
                )
                
                // 涡虫再生
                survivalModeButton(
                    title: "涡虫",
                    subtitle: "恢复 0 次",
                    icon: "arrow.clockwise",
                    color: .green,
                    isActive: false
                )
                
                // 蛭形永续
                survivalModeButton(
                    title: "蛭形",
                    subtitle: "越狱环境",
                    icon: "tortoise",
                    color: .blue,
                    isActive: true
                )
                
                // 灯塔重置
                survivalModeButton(
                    title: "灯塔",
                    subtitle: "从未重置",
                    icon: "clock.arrow.circlepath",
                    color: .purple,
                    isActive: false
                )
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 20/255, green: 40/255, blue: 35/255)))
    }
    
    private func survivalModeButton(title: String, subtitle: String, icon: String, color: Color, isActive: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? color : .gray)
            
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(isActive ? color.opacity(0.3) : Color.gray.opacity(0.2)))
    }
    
    // MARK: - 待实现提示
    private var pendingFeaturesNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text("⚠️ 待实现功能")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text("以下功能需要后端支持，当前为空壳，暂不展示：")
                .font(.caption)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                pendingFeatureRow("视觉闭环（截图 + 操作）", "待 Tweak 注入 SpringBoard")
                pendingFeatureRow("AI 对话", "待 LLM 后端实现")
                pendingFeatureRow("费用监控", "待 API 调用计数")
                pendingFeatureRow("三层记忆管理", "待记忆系统完善")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func pendingFeatureRow(_ title: String, _ reason: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
            Text(reason)
                .font(.caption2)
                .foregroundColor(.orange)
        }
    }
    
    // MARK: - 底部标签栏
    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            tabButton("控制台", icon: "display", index: 0)
            tabButton("记忆", icon: "brain", index: 1, enabled: false)
            tabButton("配置", icon: "gear", index: 2, enabled: false)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(red: 20/255, green: 20/255, blue: 40/255))
    }
    
    private func tabButton(_ title: String, icon: String, index: Int, enabled: Bool = true) -> some View {
        Button(action: {
            if enabled {
                selectedTab = index
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(enabled ? (selectedTab == index ? .blue : .white) : .gray.opacity(0.5))
                Text(title)
                    .font(.caption2)
                    .foregroundColor(enabled ? (selectedTab == index ? .blue : .white) : .gray.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(!enabled)
    }
}

// MARK: - Preview
struct StarCoreConsole_Previews: PreviewProvider {
    static var previews: some View {
        StarCoreConsole()
            .environmentObject(LifeCore())
            .environmentObject(MindCore(lifeCoreReadOnly: LifeCoreReadOnlyWrapper(lifeCore: LifeCore())))
    }
}
