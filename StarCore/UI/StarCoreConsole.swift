/**
 * StarCoreConsole.swift
 * 星核控制台 - 主界面
 * 
 * 设计原则：
 * 1. 只展示真实硬件数据（电池/CPU/内存/热状态）
 * 2. 不展示虚假映射数据（心率/体温/疲劳/情绪等）
 * 3. 待实现功能明确标记
 * 
 * 真实数据源：
 * - 电池电量: UIDevice.current.batteryLevel ✅
 * - CPU 使用率: Mach API 线程分析 ✅
 * - 热状态: ProcessInfo.thermalState ✅
 * - 内存使用: Mach API task_vm_info ✅
 * - 设备信息: uname() ✅
 * 
 * 虚假数据（已移除）：
 * - 心率: CPU 映射 60-120 ❌
 * - 体温: 热状态映射 36.5-39.0 ❌
 * - 疲劳度: CPU 历史推算 ❌
 * - 情绪: 基于虚假数据计算 ❌
 */

import SwiftUI

@available(iOS 15.0, *)
struct StarCoreConsole: View {
    @StateObject private var hardwareSensor = HardwareSensor()
    
    // 刷新定时器
    @State private var refreshTimer: Timer?
    
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
                            // 设备信息卡片
                            deviceInfoCard
                            
                            // 真实硬件数据卡片
                            hardwareDataCard
                            
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
            .onAppear {
                // 启动定时器，每 2 秒刷新一次真实数据
                refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                    hardwareSensor.refresh()
                }
            }
            .onDisappear {
                refreshTimer?.invalidate()
            }
        }
    }
    
    // MARK: - 顶部状态栏
    private var topStatusBar: some View {
        HStack {
            Text("星核控制台")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            // 刷新指示器
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("实时")
                    .font(.caption)
                    .foregroundColor(.green)
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
    
    // MARK: - 设备信息卡片
    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(.blue)
                Text("📱 设备信息")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hardwareSensor.deviceModel)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("设备型号")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(hardwareSensor.systemVersion)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("iOS 版本")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 25/255, green: 25/255, blue: 55/255)))
    }
    
    // MARK: - 真实硬件数据卡片
    private var hardwareDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.green)
                Text("⚡ 硬件状态（真实数据）")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            // 电池电量
            hardwareDataRow(
                icon: "battery.50",
                title: "电池电量",
                value: "\(Int(hardwareSensor.batteryLevel * 100))%",
                color: batteryColor,
                detail: batteryStateText
            )
            
            // CPU 使用率
            hardwareDataRow(
                icon: "cpu",
                title: "CPU 使用率",
                value: "\(Int(hardwareSensor.cpuUsage))%",
                color: cpuColor,
                detail: "实时线程分析"
            )
            
            // 热状态
            hardwareDataRow(
                icon: "thermometer",
                title: "热状态",
                value: thermalStateText,
                color: thermalColor,
                detail: "系统级热管理"
            )
            
            // 内存使用
            hardwareDataRow(
                icon: "memorychip",
                title: "内存使用",
                value: "\(hardwareSensor.memoryUsedMB) / \(hardwareSensor.memoryTotalMB) MB",
                color: memoryColor,
                detail: "物理内存"
            )
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 20/255, green: 40/255, blue: 35/255)))
    }
    
    private func hardwareDataRow(icon: String, title: String, value: String, color: Color, detail: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Text(detail)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
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
                pendingFeatureRow("心率/体温/疲劳", "需要真实传感器数据，当前是 CPU 映射的虚假数据")
                pendingFeatureRow("情绪状态", "需要真实生理数据输入，当前基于虚假数据计算")
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
                // TODO: 切换标签页
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(enabled ? .white : .gray.opacity(0.5))
                Text(title)
                    .font(.caption2)
                    .foregroundColor(enabled ? .white : .gray.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(!enabled)
    }
    
    // MARK: - 颜色辅助
    private var batteryColor: Color {
        if hardwareSensor.batteryLevel > 0.5 { return .green }
        if hardwareSensor.batteryLevel > 0.2 { return .yellow }
        return .red
    }
    
    private var batteryStateText: String {
        switch hardwareSensor.batteryState {
        case .charging: return "充电中"
        case .full: return "充满"
        case .unplugged: return "未充电"
        case .unknown: return "未知"
        @unknown default: return "未知"
        }
    }
    
    private var cpuColor: Color {
        if hardwareSensor.cpuUsage < 30 { return .green }
        if hardwareSensor.cpuUsage < 70 { return .yellow }
        return .red
    }
    
    private var thermalColor: Color {
        switch hardwareSensor.thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }
    
    private var thermalStateText: String {
        switch hardwareSensor.thermalState {
        case .nominal: return "正常"
        case .fair: return "轻微发热"
        case .serious: return "发热"
        case .critical: return "过热"
        @unknown default: return "未知"
        }
    }
    
    private var memoryColor: Color {
        if hardwareSensor.memoryUsagePercent < 0.5 { return .green }
        if hardwareSensor.memoryUsagePercent < 0.8 { return .yellow }
        return .red
    }
}

// MARK: - HardwareSensor 扩展（添加刷新方法）
extension HardwareSensor {
    @Published var batteryLevel: Float = 1.0
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var cpuUsage: Float = 0.0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var memoryUsedMB: UInt64 = 0
    @Published var memoryTotalMB: UInt64 = 0
    @Published var memoryUsagePercent: Float = 0.0
    @Published var deviceModel: String = ""
    @Published var systemVersion: String = ""
    
    func refresh() {
        // 电池
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel < 0 ? 1.0 : UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        
        // CPU
        cpuUsage = getCPUUsage()
        
        // 热状态
        thermalState = ProcessInfo.processInfo.thermalState
        
        // 内存
        let mem = getMemoryUsage()
        memoryUsedMB = mem.used / 1024 / 1024
        memoryTotalMB = mem.total / 1024 / 1024
        memoryUsagePercent = getMemoryUsagePercent()
        
        // 设备信息
        deviceModel = getDeviceModel()
        systemVersion = getSystemVersion()
    }
}

// MARK: - Preview
struct StarCoreConsole_Previews: PreviewProvider {
    static var previews: some View {
        StarCoreConsole()
    }
}
