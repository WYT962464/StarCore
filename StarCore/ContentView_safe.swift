import SwiftUI
import UIKit
import CoreMotion
import CoreLocation
import Network
import UserNotifications
import Combine

// MARK: - 硬件信息获取器 (v0.3.0 安全版)
// 使用安全的公开API替代有风险的Mach API

class HardwareInfo {
    
    /// 获取CPU使用率估算（安全方法）
    /// 由于沙盒限制，无法使用host_processor_info，这里使用估算方法
    static func getCPUUsageEstimate() -> Double {
        // 方法1: 基于活跃核心数的粗略估算
        let activeCores = ProcessInfo.processInfo.activeProcessorCount
        let totalCores = ProcessInfo.processInfo.processorCount
        
        // 基础负载 + 核心利用率估算
        let baseLoad = 15.0 // 基础系统负载
        let coreLoad = Double(activeCores) * 5.0
        
        return min(100.0, baseLoad + coreLoad)
    }
    
    /// 获取内存使用情况（安全方法）
    /// 由于沙盒限制，无法使用task_info，这里返回总量和估算使用率
    static func getMemoryInfo() -> (total: UInt64, usedPercent: Double) {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        // iOS系统通常占用约30-40%内存作为系统缓存
        // App实际可用内存会动态调整，这里使用估算值
        let estimatedUsedPercent = 35.0
        
        return (totalMemory, estimatedUsedPercent)
    }
    
    /// 获取格式化内存字符串
    static func getMemoryString() -> String {
        let (total, _) = getMemoryInfo()
        let totalGB = Double(total) / 1_073_741_824.0
        return String(format: "%.1f GB", totalGB)
    }
    
    /// 获取存储空间信息（安全方法）
    static func getStorageInfo() -> (used: String, total: String, percent: Double) {
        do {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let values = try documentsURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            
            guard let total = values.volumeTotalCapacity,
                  let available = values.volumeAvailableCapacityForImportantUsage else {
                return ("未知", "未知", 0)
            }
            
            let usedBytes = Int64(total) - available
            let usedString = ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
            let totalString = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
            let percent = Double(total - Int(available)) / Double(total) * 100.0
            
            return (usedString, totalString, percent)
        } catch {
            return ("未知", "未知", 0)
        }
    }
    
    /// 获取设备型号标识符（安全方法）
    static func getDeviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let platform = withUnsafePointer(to: &systemInfo.machine) { ptr in
            return String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
        }
        return platform
    }
    
    /// 获取可读的设备型号名称
    static func getDeviceModelName() -> String {
        let identifier = getDeviceIdentifier()
        
        // iPhone型号映射表
        let modelMap: [String: String] = [
            "iPhone10,3": "iPhone X",
            "iPhone10,6": "iPhone X",
            "iPhone11,2": "iPhone XS",
            "iPhone11,4": "iPhone XS Max",
            "iPhone11,6": "iPhone XS Max",
            "iPhone11,8": "iPhone XR",
            "iPhone12,1": "iPhone 11",
            "iPhone12,3": "iPhone 11 Pro",
            "iPhone12,5": "iPhone 11 Pro Max",
            "iPhone12,8": "iPhone SE (2nd)",
            "iPhone13,1": "iPhone 12 mini",
            "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone14,6": "iPhone SE (3rd)",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
        ]
        
        return modelMap[identifier] ?? UIDevice.current.model
    }
}

// MARK: - 智能控制系统 (v0.2.0 建议期核心)
enum SystemAction: String, CaseIterable {
    case performanceMax = "性能最大化"
    case performanceOpt = "性能优化"
    case performanceBal = "性能平衡"
    case prepareActive = "准备活动"
    case reducePerf = "降低性能"
    case lowPower = "低功耗模式"
    case minimalActivity = "最小活动"
    case maintenance = "维护优化"
    case sleepMode = "休眠模式"
    
    var description: String {
        switch self {
        case .performanceMax: return "全核心满载运行，主动进化学习"
        case .performanceOpt: return "高性能模式，响应优先"
        case .performanceBal: return "平衡模式，性能与能耗兼顾"
        case .prepareActive: return "即将活跃，提前预热资源"
        case .reducePerf: return "降低负载，进入轻度节能"
        case .lowPower: return "低功耗模式，关闭非必要功能"
        case .minimalActivity: return "最小活动，仅保留核心感知"
        case .maintenance: return "后台维护，整理内存，归档日志"
        case .sleepMode: return "深度休眠，仅保留时钟和唤醒检测"
        }
    }
    
    var icon: String {
        switch self {
        case .performanceMax: return "flame"
        case .performanceOpt: return "bolt"
        case .performanceBal: return "scalemass"
        case .prepareActive: return "sunrise"
        case .reducePerf: return "tortoise"
        case .lowPower: return "leaf"
        case .minimalActivity: return "moon.stars"
        case .maintenance: return "wrench.and.screwdriver"
        case .sleepMode: return "powersleep"
        }
    }
    
    var color: Color {
        switch self {
        case .performanceMax: return .red
        case .performanceOpt: return .orange
        case .performanceBal: return .yellow
        case .prepareActive: return .green
        case .reducePerf: return .teal
        case .lowPower: return .cyan
        case .minimalActivity: return .blue
        case .maintenance: return .purple
        case .sleepMode: return .indigo
        }
    }
}

class IntelligentController: ObservableObject {
    @Published var currentAction: SystemAction = .performanceBal
    @Published var lastUpdate: Date = .distantPast
    @Published var actionReason: String = "初始化中..."
    
    private var timer: AnyCancellable?
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        timer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.evaluateState()
            }
    }
    
    func evaluateState(batteryLevel: Float = 0.5, cpuUsage: Double = 30, hour: Int = 12, isCharging: Bool = false) {
        let hourPriority = getHourPriorityAction(hour: hour)
        let conditionPriority = getConditionPriorityAction(batteryLevel: batteryLevel, cpuUsage: cpuUsage, isCharging: isCharging)
        
        // 优先级：硬件条件 > 时辰卦象
        let finalAction = getHigherPriorityAction(conditionPriority, hourPriority)
        let reason = finalAction == conditionPriority ? "硬件条件触发" : "时辰卦象驱动"
        
        DispatchQueue.main.async {
            self.currentAction = finalAction
            self.lastUpdate = Date()
            self.actionReason = reason
        }
    }
    
    private func getHourPriorityAction(hour: Int) -> SystemAction {
        switch hour {
        case 9, 10, 11: return .performanceMax  // 乾卦午时
        case 7, 8, 12, 13: return .performanceOpt  // 夬卦/姤卦
        case 5, 6, 14, 15: return .performanceBal  // 大壮/遁卦
        case 3, 4, 16, 17: return .prepareActive   // 泰/否卦
        case 1, 2, 18, 19: return .reducePerf      // 临/观卦
        case 20, 21, 22: return .lowPower          // 剥卦
        case 23, 0: return .maintenance            // 复卦
        default: return .sleepMode                 // 深夜休眠
        }
    }
    
    private func getConditionPriorityAction(batteryLevel: Float, cpuUsage: Double, isCharging: Bool) -> SystemAction {
        if isCharging {
            return batteryLevel > 0.9 ? .maintenance : .performanceOpt
        }
        
        if batteryLevel < 0.1 { return .sleepMode }
        if batteryLevel < 0.2 { return .minimalActivity }
        if batteryLevel < 0.3 { return .lowPower }
        if batteryLevel < 0.5 { return .reducePerf }
        
        if cpuUsage > 90 { return .performanceMax }
        if cpuUsage > 70 { return .performanceOpt }
        
        return .performanceBal
    }
    
    private func getHigherPriorityAction(_ a1: SystemAction, _ a2: SystemAction) -> SystemAction {
        let priority: [SystemAction: Int] = [
            .sleepMode: 10, .minimalActivity: 9, .lowPower: 8,
            .maintenance: 7, .reducePerf: 6, .prepareActive: 5,
            .performanceBal: 4, .performanceOpt: 3, .performanceMax: 2
        ]
        return (priority[a1] ?? 0) < (priority[a2] ?? 0) ? a1 : a2
    }
}

// MARK: - 以下为原ContentView的修改版本

struct ContentView: View {
    @State private var batteryLevel: Float = 0
    @State private var batteryState: UIDevice.BatteryState = .unknown
    @State private var currentTime: String = ""
    
    // v0.3.0 修改：使用安全的估算方法替代Mach API
    @State private var cpuUsage: Double = 0
    @State private var memoryUsage: Double = 0
    
    @State private var storageUsed: String = ""
    @State private var storageTotal: String = ""
    @State private var storagePercent: Double = 0
    
    @State private var accelerometerX: Double = 0
    @State private var accelerometerY: Double = 0
    @State private var accelerometerZ: Double = 0
    @State private var gyroX: Double = 0
    @State private var gyroY: Double = 0
    @State private var gyroZ: Double = 0
    @State private var motionManager = CMMotionManager()
    @State private var uptime: TimeInterval = 0
    @State private var heartBeatScale: CGFloat = 1.0
    @State private var networkStatus: String = "检测中..."
    @State private var monitor = NWPathMonitor()
    @State private var heading: Double = -1
    @State private var magneticX: Double = 0
    @State private var magneticY: Double = 0
    @State private var magneticZ: Double = 0
    @State private var locationManager: CLLocationManager?
    @State private var deviceOrientation: UIDeviceOrientation = .unknown
    @State private var screenBrightness: Double = 0
    @State private var displayMode: Int = 0
    @StateObject private var intelliControl = IntelligentController()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.1),
                    Color(red: 0.08, green: 0.08, blue: 0.2),
                    Color(red: 0.03, green: 0.12, blue: 0.15)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 14) {
                    // 状态显示
                    HStack {
                        VStack(alignment: .leading) {
                            Text("☯️ 星核 v0.3.0")
                                .font(.headline)
                                .foregroundColor(.cyan)
                            Text("安全模式运行中")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("❤️ \(String(format: "%.0f%%", batteryLevel * 100))")
                                .foregroundColor(.red)
                            Text("⚡ \(batteryStateDesc)")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 硬件信息卡片
                    VStack(spacing: 8) {
                        HStack {
                            Text("📊 硬件感知")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Spacer()
                            Text(HardwareInfo.getDeviceModelName())
                                .font(.caption)
                                .foregroundColor(.cyan)
                        }
                        
                        Divider().background(Color.gray.opacity(0.3))
                        
                        // CPU信息（估算值）
                        HStack {
                            Text("处理器")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(ProcessInfo.processInfo.processorCount)核心")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("负载 ~\(String(format: "%.0f%%", cpuUsage))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        // 内存信息
                        HStack {
                            Text("内存")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(HardwareInfo.getMemoryString())
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        // 存储信息
                        HStack {
                            Text("存储")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(storageUsed)/\(storageTotal)")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("(\(String(format: "%.0f%%", storagePercent)))")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // 传感器数据
                    VStack(spacing: 6) {
                        HStack {
                            Text("🎯 传感器")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        HStack {
                            Text("加速度")
                            Spacer()
                            Text("X:\(String(format: "%.2f", accelerometerX)) Y:\(String(format: "%.2f", accelerometerY)) Z:\(String(format: "%.2f", accelerometerZ))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        
                        HStack {
                            Text("陀螺仪")
                            Spacer()
                            Text("X:\(String(format: "%.2f", gyroX)) Y:\(String(format: "%.2f", gyroY)) Z:\(String(format: "%.2f", gyroZ))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                        
                        if heading >= 0 {
                            HStack {
                                Text("方向")
                                Spacer()
                                Text("\(Int(heading))° \(headingDirection)")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        HStack {
                            Text("网络")
                            Spacer()
                            Text(networkStatus)
                                .foregroundColor(networkStatus == "离线" ? .red : .green)
                        }
                    }
                    .font(.caption)
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    // 运行时间
                    HStack {
                        Text("⏱️ 运行时间")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(formatUptime(uptime))
                            .foregroundColor(.white)
                    }
                    .font(.caption)
                    .padding(.horizontal)
                }
                .padding(.vertical, 6)
            }
        }
        .onReceive(timer) { _ in
            updateAll()
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            startNetworkMonitor()
            startMotionUpdates()
            updateAll()
        }
    }
    
    var batteryStateDesc: String {
        switch batteryState {
        case .charging: return "充电中"
        case .full: return "已充满"
        case .unplugged: return "未充电"
        default: return "未知"
        }
    }
    
    var headingDirection: String {
        guard heading >= 0 else { return "无" }
        let h = heading.truncatingRemainder(dividingBy: 360)
        if h >= 337.5 || h < 22.5 { return "北" }
        else if h < 67.5 { return "东北" }
        else if h < 112.5 { return "东" }
        else if h < 157.5 { return "东南" }
        else if h < 202.5 { return "南" }
        else if h < 247.5 { return "西南" }
        else if h < 292.5 { return "西" }
        else { return "西北" }
    }
    
    func updateAll() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        screenBrightness = Double(UIScreen.main.brightness * 100)
        
        updateCurrentTime()
        
        // v0.3.0 修改：使用安全方法获取CPU和内存
        cpuUsage = HardwareInfo.getCPUUsageEstimate()
        memoryUsage = HardwareInfo.getMemoryInfo().usedPercent
        
        let storageInfo = HardwareInfo.getStorageInfo()
        storageUsed = storageInfo.used
        storageTotal = storageInfo.total
        storagePercent = storageInfo.percent
        
        uptime = ProcessInfo.processInfo.systemUptime
        triggerHeartBeat()
    }
    
    func updateCurrentTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        currentTime = formatter.string(from: Date())
    }
    
    func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = Int(seconds) % 86400 / 3600
        let minutes = Int(seconds) % 3600 / 60
        return days > 0 ? "\(days)d \(hours)h \(minutes)m" : "\(hours)h \(minutes)m"
    }
    
    func triggerHeartBeat() {
        let intensity = max(0.02, min(0.1, cpuUsage / 1000))
        heartBeatScale = 1.0 + CGFloat(intensity)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            heartBeatScale = 1.0
        }
    }
    
    func startNetworkMonitor() {
        let queue = DispatchQueue(label: "network")
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        self.networkStatus = "WiFi"
                    } else if path.usesInterfaceType(.cellular) {
                        self.networkStatus = "蜂窝"
                    } else {
                        self.networkStatus = "在线"
                    }
                } else {
                    self.networkStatus = "离线"
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func startMotionUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.startAccelerometerUpdates(to: .main) { data, _ in
                if let data = data {
                    self.accelerometerX = data.acceleration.x
                    self.accelerometerY = data.acceleration.y
                    self.accelerometerZ = data.acceleration.z
                }
            }
        }
        
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.1
            motionManager.startGyroUpdates(to: .main) { data, _ in
                if let data = data {
                    self.gyroX = data.rotationRate.x
                    self.gyroY = data.rotationRate.y
                    self.gyroZ = data.rotationRate.z
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
