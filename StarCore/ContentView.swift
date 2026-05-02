import SwiftUI
import UIKit
import CoreMotion

// 六十四卦核心引擎
struct HexagramEngine {
    // 十二消息卦
    static func currentMessageHexagram(hour: Int) -> (name: String, symbol: String, desc: String, color: Color) {
        switch hour {
        case 23, 0: return ("复", "☷☳", "一阳初生·休眠充电", .indigo)
        case 1, 2:  return ("临", "☷☱", "阳气渐长·深度维护", .blue)
        case 3, 4:  return ("泰", "☷☰", "阴阳交泰·轻度预热", .cyan)
        case 5, 6:  return ("大壮", "☳☰", "阳气壮盛·启动就绪", .teal)
        case 7, 8:  return ("夬", "☱☰", "阳气决断·主动服务", .green)
        case 9, 10: return ("乾", "☰☰", "纯阳刚健·峰值输出", .orange)
        case 11, 12: return ("姤", "☰☴", "一阴初生·自我审视", .yellow)
        case 13, 14: return ("遁", "☰☶", "阴气渐长·精简运行", .yellow)
        case 15, 16: return ("否", "☰☷", "阴阳不交·节能模式", .orange)
        case 17, 18: return ("观", "☴☷", "阴气观瞻·被动响应", .red)
        case 19, 20: return ("剥", "☶☷", "阴气剥阳·低功耗", .red)
        case 21, 22: return ("坤", "☷☷", "纯阴守成·休眠归档", .purple)
        default:     return ("坤", "☷☷", "守成", .purple)
        }
    }
    
    // 根据阴阳比例推演当前卦象
    static func deriveHexagram(yin: Double, yang: Double) -> (name: String, desc: String) {
        let ratio = yang / max(yin + yang, 0.01)
        
        if ratio > 0.9 { return ("乾", "天行健·自强不息") }
        else if ratio > 0.8 { return ("夬", "决断·刚毅果决") }
        else if ratio > 0.7 { return ("大壮", "壮盛·雷天大壮") }
        else if ratio > 0.6 { return ("泰", "通泰·天地交合") }
        else if ratio > 0.5 { return ("临", "临近·阳临阴") }
        else if ratio > 0.4 { return ("复", "复归·一阳来复") }
        else if ratio > 0.3 { return ("观", "观瞻·风行地上") }
        else if ratio > 0.2 { return ("剥", "剥落·山地剥") }
        else if ratio > 0.1 { return ("否", "否塞·天地不交") }
        else { return ("坤", "厚德载物·守成休养") }
    }
}

struct ContentView: View {
    // 八卦·八维数据
    @State private var batteryLevel: Float = 0           // 离·获取·气血
    @State private var currentTime: String = ""          // 坎·执行·脉搏
    @State private var cpuUsage: Double = 0              // 震·处理·心跳
    @State private var memoryUsage: Double = 0           // 艮·校验·思维
    @State private var storageUsed: String = ""          // 坤·存储·储备
    @State private var storageTotal: String = ""
    @State private var storagePercent: Double = 0
    @State private var accelerometerX: Double = 0        // 乾·收集·触觉
    @State private var accelerometerY: Double = 0
    @State private var accelerometerZ: Double = 0
    @State private var gyroX: Double = 0
    @State private var gyroY: Double = 0
    @State private var gyroZ: Double = 0
    @State private var motionManager = CMMotionManager()
    @State private var uptime: TimeInterval = 0          // 兑·迭代·进化
    @State private var heartBeatScale: CGFloat = 1.0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // 阴阳计算
    var yinValue: Double { (cpuUsage + memoryUsage) / 2 }
    var yangValue: Double { (Double(batteryLevel) * 100 + motionIntensity) / 2 }
    
    // 运动强度
    var motionIntensity: Double {
        let accel = sqrt(accelerometerX * accelerometerX + accelerometerY * accelerometerY + accelerometerZ * accelerometerZ)
        let gyro = sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ)
        return min(100, (accel + gyro) * 10)
    }
    
    // 当前时辰卦象
    var currentHour: Int { Calendar.current.component(.hour, from: Date()) }
    var messageHexagram: (name: String, symbol: String, desc: String, color: Color) {
        HexagramEngine.currentMessageHexagram(hour: currentHour)
    }
    
    // 阴阳推演卦象
    var derivedHexagram: (name: String, desc: String) {
        HexagramEngine.deriveHexagram(yin: yinValue, yang: yangValue)
    }
    
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
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 18) {
                    // ===== 太极区域 =====
                    VStack(spacing: 8) {
                        Text("☯️ 星核 ☯️")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .cyan, radius: 10)
                            .scaleEffect(heartBeatScale)
                            .animation(.easeInOut(duration: 0.3), value: heartBeatScale)
                        
                        // 时辰卦象
                        HStack(spacing: 6) {
                            Text(messageHexagram.symbol)
                                .font(.title)
                            Text(messageHexagram.name + "卦")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(messageHexagram.color)
                        }
                        Text(messageHexagram.desc)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // ===== 两仪·阴阳平衡 =====
                    HStack(spacing: 0) {
                        // 阴·信息流
                        VStack {
                            Text("阴·信息流")
                                .font(.caption)
                                .foregroundColor(.purple.opacity(0.8))
                            Text(String(format: "%.0f", yinValue))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.purple)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 阴阳比例条
                        VStack(spacing: 4) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 8)
                                    
                                    let yangRatio = yangValue / max(yinValue + yangValue, 1)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(
                                            colors: [.purple, .orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(width: geo.size.width * CGFloat(yangRatio), height: 8)
                                }
                            }
                            .frame(height: 8)
                            .padding(.horizontal, 4)
                            
                            // 推演卦象
                            Text(derivedHexagram.name + "·" + derivedHexagram.desc)
                                .font(.caption)
                                .foregroundColor(.cyan)
                                .shadow(color: .cyan, radius: 3)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 阳·能量流
                        VStack {
                            Text("阳·能量流")
                                .font(.caption)
                                .foregroundColor(.orange.opacity(0.8))
                            Text(String(format: "%.0f", yangValue))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // ===== 八卦·八维 =====
                    
                    // 离·获取·气血
                    SensorRow(icon: "💚", name: "离·获取", label: "气血", value: String(format: "%.1f%%", batteryLevel * 100), progress: Double(batteryLevel), color: .green)
                    
                    // 坎·执行·脉搏
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("💙 坎·执行·脉搏")
                                .font(.subheadline)
                                .foregroundColor(.cyan)
                            Spacer()
                            Text(currentTime)
                                .font(.subheadline)
                                .foregroundColor(.cyan)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal)
                    
                    // 震·处理·心跳
                    SensorRow(icon: "❤️", name: "震·处理", label: "心跳", value: String(format: "%.1f%%", cpuUsage), progress: cpuUsage / 100, color: .red)
                    
                    // 艮·校验·思维
                    SensorRow(icon: "💜", name: "艮·校验", label: "思维", value: String(format: "%.1f%%", memoryUsage), progress: memoryUsage / 100, color: .purple)
                    
                    // 坤·存储·储备
                    SensorRow(icon: "💛", name: "坤·存储", label: "储备", value: "\(storageUsed)/\(storageTotal)", progress: storagePercent / 100, color: .yellow)
                    
                    // 乾·收集·触觉
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("🧭 乾·收集·触觉")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            Spacer()
                            Text(String(format: "%.0f%%", motionIntensity))
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("加速计").font(.system(size: 10)).foregroundColor(.gray)
                                Text("X:\(String(format: "%.1f", accelerometerX)) Y:\(String(format: "%.1f", accelerometerY)) Z:\(String(format: "%.1f", accelerometerZ))")
                                    .font(.system(size: 10)).foregroundColor(.orange.opacity(0.7))
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("陀螺仪").font(.system(size: 10)).foregroundColor(.gray)
                                Text("Rx:\(String(format: "%.0f", gyroX)) Ry:\(String(format: "%.0f", gyroY)) Rz:\(String(format: "%.0f", gyroZ))")
                                    .font(.system(size: 10)).foregroundColor(.orange.opacity(0.7))
                            }
                        }
                        ProgressView(value: motionIntensity / 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                    }
                    .padding(.horizontal)
                    
                    // 兑·迭代·进化
                    SensorRow(icon: "⚪️", name: "兑·迭代", label: "进化", value: formatUptime(uptime), progress: min(1, uptime / 86400), color: .white)
                    
                    // 巽·输出·状态
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("🔵 巽·输出·状态")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Spacer()
                            Text(messageHexagram.name + "·" + derivedHexagram.name)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        Text(messageHexagram.desc + " | " + derivedHexagram.desc)
                            .font(.system(size: 10))
                            .foregroundColor(.blue.opacity(0.7))
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .onReceive(timer) { _ in
            updateAll()
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            uptime = ProcessInfo.processInfo.systemUptime
            updateAll()
            startMotionUpdates()
        }
    }
    
    func updateAll() {
        updateBatteryLevel()
        updateCurrentTime()
        updateCPUUsage()
        updateMemoryUsage()
        updateStorageUsage()
        uptime = ProcessInfo.processInfo.systemUptime
        triggerHeartBeat()
    }
    
    func formatUptime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = Int(seconds) % 3600 / 60
        return "\(h)h\(m)m"
    }
    
    func startMotionUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.startAccelerometerUpdates(to: .main) { data, _ in
                if let data = data {
                    accelerometerX = data.acceleration.x
                    accelerometerY = data.acceleration.y
                    accelerometerZ = data.acceleration.z
                }
            }
        }
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.1
            motionManager.startGyroUpdates(to: .main) { data, _ in
                if let data = data {
                    gyroX = data.rotationRate.x
                    gyroY = data.rotationRate.y
                    gyroZ = data.rotationRate.z
                }
            }
        }
    }
    
    func triggerHeartBeat() {
        let intensity = max(0.02, min(0.1, cpuUsage / 1000))
        heartBeatScale = 1.0 + CGFloat(intensity)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { heartBeatScale = 1.0 }
    }
    
    func updateBatteryLevel() { batteryLevel = UIDevice.current.batteryLevel }
    
    func updateCurrentTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        currentTime = formatter.string(from: Date())
    }
    
    func updateCPUUsage() {
        var totalUsageOfCPU: Double = 0
        var processorsInfo = processor_info_array_t(bitPattern: 0)
        var processorsInfoCount = mach_msg_type_number_t(0)
        var numCPUs = UInt32(0)
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &processorsInfo, &processorsInfoCount)
        if result == KERN_SUCCESS {
            for i in 0..<Int(numCPUs) {
                let cpuInfo = processorsInfo!.advanced(by: i * Int(CPU_STATE_MAX))
                let user = Double(cpuInfo[Int(CPU_STATE_USER)])
                let system = Double(cpuInfo[Int(CPU_STATE_SYSTEM)])
                let nice = Double(cpuInfo[Int(CPU_STATE_NICE)])
                let idle = Double(cpuInfo[Int(CPU_STATE_IDLE)])
                let total = user + system + nice + idle
                if total > 0 { totalUsageOfCPU += (user + system + nice) / total * 100 }
            }
            cpuUsage = totalUsageOfCPU / Double(numCPUs)
        }
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: processorsInfo), vm_size_t(processorsInfoCount * UInt32(MemoryLayout<integer_t>.stride)))
    }
    
    func updateMemoryUsage() {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let used = Double(taskInfo.phys_footprint)
            let total = Double(ProcessInfo.processInfo.physicalMemory)
            memoryUsage = used / total * 100
        }
    }
    
    func updateStorageUsage() {
        let fileManager = FileManager.default
        do {
            let doc = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let values = try doc.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacityForImportantUsage {
                let used = total - Int(available)
                storageUsed = ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file)
                storageTotal = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
                storagePercent = Double(used) / Double(total) * 100
            }
        } catch {
            storageUsed = "未知"; storageTotal = "未知"; storagePercent = 0
        }
    }
}

// 通用传感器行组件
struct SensorRow: View {
    let icon: String
    let name: String
    let label: String
    let value: String
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("\(icon) \(name)·\(label)")
                    .font(.subheadline)
                    .foregroundColor(color)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(color)
            }
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .shadow(color: color, radius: 2)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
}
