import SwiftUI
import UIKit
import CoreMotion

// 六十四卦核心引擎
struct HexagramEngine {
    // 十二消息卦
    static func currentMessageHexagram(hour: Int) -> (name: String, symbol: String, desc: String, color: Color, action: String) {
        switch hour {
        case 23, 0: return ("复", "☷☳", "一阳初生", .indigo, "休眠充电·自我修复")
        case 1, 2:  return ("临", "☷☱", "阳气渐长", .blue, "深度维护·日志归档")
        case 3, 4:  return ("泰", "☷☰", "阴阳交泰", .cyan, "轻度预热·环境感知")
        case 5, 6:  return ("大壮", "☳☰", "阳气壮盛", .teal, "启动就绪·功能预热")
        case 7, 8:  return ("夬", "☱☰", "阳气决断", .green, "活跃运行·主动服务")
        case 9, 10: return ("乾", "☰☰", "纯阳刚健", .orange, "峰值输出·全力进化")
        case 11, 12: return ("姤", "☰☴", "一阴初生", .yellow, "输出衰减·自我审视")
        case 13, 14: return ("遁", "☰☶", "阴气渐长", .yellow, "降低负载·精简运行")
        case 15, 16: return ("否", "☰☷", "阴阳不交", .orange, "节能模式·必要响应")
        case 17, 18: return ("观", "☴☷", "阴气观瞻", .red, "观察模式·被动响应")
        case 19, 20: return ("剥", "☶☷", "阴气剥阳", .red, "低功耗·关闭非必要")
        case 21, 22: return ("坤", "☷☷", "纯阴守成", .purple, "休眠归档·记忆沉淀")
        default:     return ("坤", "☷☷", "守成", .purple, "休眠归档")
        }
    }
    
    // 根据阴阳比例推演当前卦象
    static func deriveHexagram(yin: Double, yang: Double) -> (name: String, desc: String, advice: String) {
        let ratio = yang / max(yin + yang, 0.01)
        
        if ratio > 0.9 { return ("乾", "天行健·自强不息", "⚡ 能量充沛，主动出击！") }
        else if ratio > 0.8 { return ("夬", "决断·刚毅果决", "🔥 状态正佳，高效执行") }
        else if ratio > 0.7 { return ("大壮", "壮盛·雷天大壮", "💪 运行良好，持续输出") }
        else if ratio > 0.6 { return ("泰", "通泰·天地交合", "✨ 阴阳调和，稳中求进") }
        else if ratio > 0.5 { return ("临", "临近·阳临阴", "🔄 渐入佳境，蓄势待发") }
        else if ratio > 0.4 { return ("复", "复归·一阳来复", "🌱 正在恢复，注意休息") }
        else if ratio > 0.3 { return ("观", "观瞻·风行地上", "👁️ 静观其变，保存体力") }
        else if ratio > 0.2 { return ("剥", "剥落·山地剥", "⚠️ 资源紧张，精简运行") }
        else if ratio > 0.1 { return ("否", "否塞·天地不交", "🛑 能量不足，停止非必要") }
        else { return ("坤", "厚德载物·守成休养", "💤 亟需充能，休眠保护") }
    }
    
    // 综合状态评估
    static func evaluateStatus(battery: Float, cpu: Double, memory: Double, motion: Double) -> (emoji: String, label: String, color: Color) {
        let energy = Double(battery) * 100
        let load = (cpu + memory) / 2
        
        if energy < 10 { return ("💔", "危急", .red) }
        else if energy < 20 { return ("🥵", "虚弱", .orange) }
        else if load > 80 { return ("🔥", "过载", .red) }
        else if load > 60 { return ("⚡", "满载", .orange) }
        else if motion > 50 { return ("🏃", "活跃", .green) }
        else if energy > 80 && load < 30 { return ("😌", "安逸", .cyan) }
        else if energy > 50 { return ("💙", "平稳", .blue) }
        else { return ("💛", "警戒", .yellow) }
    }
}

struct ContentView: View {
    @State private var batteryLevel: Float = 0
    @State private var batteryState: UIDevice.BatteryState = .unknown
    @State private var currentTime: String = ""
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
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var yinValue: Double { (cpuUsage + memoryUsage) / 2 }
    var yangValue: Double { (Double(batteryLevel) * 100 + motionIntensity) / 2 }
    
    var motionIntensity: Double {
        let accel = sqrt(accelerometerX * accelerometerX + accelerometerY * accelerometerY + accelerometerZ * accelerometerZ)
        let gyro = sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ)
        return min(100, (accel + gyro) * 10)
    }
    
    var currentHour: Int { Calendar.current.component(.hour, from: Date()) }
    var messageHexagram: (name: String, symbol: String, desc: String, color: Color, action: String) {
        HexagramEngine.currentMessageHexagram(hour: currentHour)
    }
    var derivedHexagram: (name: String, desc: String, advice: String) {
        HexagramEngine.deriveHexagram(yin: yinValue, yang: yangValue)
    }
    var status: (emoji: String, label: String, color: Color) {
        HexagramEngine.evaluateStatus(battery: batteryLevel, cpu: cpuUsage, memory: memoryUsage, motion: motionIntensity)
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
                VStack(spacing: 16) {
                    // ===== 太极 =====
                    VStack(spacing: 6) {
                        Text("☯️ 星核 ☯️")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: status.color, radius: 12)
                            .scaleEffect(heartBeatScale)
                            .animation(.easeInOut(duration: 0.3), value: heartBeatScale)
                        
                        HStack(spacing: 8) {
                            Text(status.emoji)
                                .font(.title2)
                            Text(status.label)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(status.color)
                            Text(messageHexagram.symbol)
                                .font(.title2)
                        }
                    }
                    
                    // ===== 决策卡片 =====
                    VStack(spacing: 6) {
                        // 时辰卦
                        HStack {
                            Text(messageHexagram.symbol + " " + messageHexagram.name + "卦")
                                .font(.headline)
                                .foregroundColor(messageHexagram.color)
                            Spacer()
                            Text(messageHexagram.desc)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // 行为指令
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(messageHexagram.color)
                                .font(.caption)
                            Text(messageHexagram.action)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                        
                        Divider().background(Color.gray.opacity(0.3))
                        
                        // 推演卦
                        HStack {
                            Text(derivedHexagram.name + "卦·" + derivedHexagram.desc)
                                .font(.headline)
                                .foregroundColor(.cyan)
                            Spacer()
                        }
                        
                        // 建议
                        HStack {
                            Text(derivedHexagram.advice)
                                .font(.subheadline)
                                .foregroundColor(.cyan.opacity(0.9))
                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(messageHexagram.color.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // ===== 两仪 =====
                    HStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Text("阴·信息流")
                                .font(.system(size: 10))
                                .foregroundColor(.purple.opacity(0.7))
                            Text(String(format: "%.0f", yinValue))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.purple)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 4) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 6)
                                    let yangRatio = yangValue / max(yinValue + yangValue, 1)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(LinearGradient(colors: [.purple, .orange], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * CGFloat(yangRatio), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 2) {
                            Text("阳·能量流")
                                .font(.system(size: 10))
                                .foregroundColor(.orange.opacity(0.7))
                            Text(String(format: "%.0f", yangValue))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    
                    Divider().background(Color.gray.opacity(0.2))
                    
                    // ===== 八卦·八维 =====
                    SensorRow(icon: "💚", name: "离·获取", label: "气血", value: String(format: "%.1f%%", batteryLevel * 100), detail: batteryStateDesc, progress: Double(batteryLevel), color: .green)
                    
                    SensorRow(icon: "💙", name: "坎·执行", label: "脉搏", value: currentTime, detail: nil, progress: nil, color: .cyan)
                    
                    SensorRow(icon: "❤️", name: "震·处理", label: "心跳", value: String(format: "%.1f%%", cpuUsage), detail: nil, progress: cpuUsage / 100, color: .red)
                    
                    SensorRow(icon: "💜", name: "艮·校验", label: "思维", value: String(format: "%.1f%%", memoryUsage), detail: nil, progress: memoryUsage / 100, color: .purple)
                    
                    SensorRow(icon: "💛", name: "坤·存储", label: "储备", value: "\(storageUsed)/\(storageTotal)", detail: String(format: "%.0f%%", storagePercent), progress: storagePercent / 100, color: .yellow)
                    
                    // 乾·收集·触觉
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("🧭 乾·收集·触觉")
                                .font(.subheadline).foregroundColor(.orange)
                            Spacer()
                            Text(String(format: "%.0f%%", motionIntensity))
                                .font(.subheadline).foregroundColor(.orange)
                        }
                        HStack(spacing: 14) {
                            Text("A: \(String(format: "%.1f", accelerometerX)),\(String(format: "%.1f", accelerometerY)),\(String(format: "%.1f", accelerometerZ))")
                                .font(.system(size: 9)).foregroundColor(.orange.opacity(0.6))
                            Text("G: \(String(format: "%.0f", gyroX)),\(String(format: "%.0f", gyroY)),\(String(format: "%.0f", gyroZ))")
                                .font(.system(size: 9)).foregroundColor(.orange.opacity(0.6))
                        }
                        ProgressView(value: motionIntensity / 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                    }
                    .padding(.horizontal)
                    
                    SensorRow(icon: "⚪️", name: "兑·迭代", label: "进化", value: formatUptime(uptime), detail: "v0.1.14", progress: min(1, uptime / 86400), color: .white.opacity(0.7))
                    
                    SensorRow(icon: "🔵", name: "巽·输出", label: "状态", value: "\(messageHexagram.name)·\(derivedHexagram.name)", detail: derivedHexagram.desc, progress: yangValue / 100, color: .blue)
                }
                .padding(.vertical, 8)
            }
        }
        .onReceive(timer) { _ in updateAll() }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            updateAll()
            startMotionUpdates()
        }
    }
    
    var batteryStateDesc: String {
        switch batteryState {
        case .charging: return "⚡充电中"
        case .full: return "🔋已充满"
        case .unplugged: return "🔌未充电"
        default: return ""
        }
    }
    
    func updateAll() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        updateCurrentTime()
        updateCPUUsage()
        updateMemoryUsage()
        updateStorageUsage()
        uptime = ProcessInfo.processInfo.systemUptime
        triggerHeartBeat()
    }
    
    func formatUptime(_ s: TimeInterval) -> String {
        let d = Int(s) / 86400
        let h = Int(s) % 86400 / 3600
        let m = Int(s) % 3600 / 60
        return d > 0 ? "\(d)d\(h)h\(m)m" : "\(h)h\(m)m"
    }
    
    func startMotionUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.startAccelerometerUpdates(to: .main) { data, _ in
                if let d = data { accelerometerX = d.acceleration.x; accelerometerY = d.acceleration.y; accelerometerZ = d.acceleration.z }
            }
        }
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.1
            motionManager.startGyroUpdates(to: .main) { data, _ in
                if let d = data { gyroX = d.rotationRate.x; gyroY = d.rotationRate.y; gyroZ = d.rotationRate.z }
            }
        }
    }
    
    func triggerHeartBeat() {
        let i = max(0.02, min(0.1, cpuUsage / 1000))
        heartBeatScale = 1.0 + CGFloat(i)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { heartBeatScale = 1.0 }
    }
    
    func updateCurrentTime() {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; currentTime = f.string(from: Date())
    }
    
    func updateCPUUsage() {
        var total: Double = 0; var info = processor_info_array_t(bitPattern: 0); var count = mach_msg_type_number_t(0); var n = UInt32(0)
        let r = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &n, &info, &count)
        if r == KERN_SUCCESS {
            for i in 0..<Int(n) {
                let c = info!.advanced(by: i * Int(CPU_STATE_MAX))
                let u = Double(c[Int(CPU_STATE_USER)]), s = Double(c[Int(CPU_STATE_SYSTEM)]), ni = Double(c[Int(CPU_STATE_NICE)]), id = Double(c[Int(CPU_STATE_IDLE)])
                let t = u + s + ni + id
                if t > 0 { total += (u + s + ni) / t * 100 }
            }
            cpuUsage = total / Double(n)
        }
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(count * UInt32(MemoryLayout<integer_t>.stride)))
    }
    
    func updateMemoryUsage() {
        var t = task_vm_info_data_t(); var c = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &t) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(c)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &c) } }
        if r == KERN_SUCCESS { memoryUsage = Double(t.phys_footprint) / Double(ProcessInfo.processInfo.physicalMemory) * 100 }
    }
    
    func updateStorageUsage() {
        do {
            let d = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let v = try d.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            if let t = v.volumeTotalCapacity, let a = v.volumeAvailableCapacityForImportantUsage {
                let u = t - Int(a)
                storageUsed = ByteCountFormatter.string(fromByteCount: Int64(u), countStyle: .file)
                storageTotal = ByteCountFormatter.string(fromByteCount: Int64(t), countStyle: .file)
                storagePercent = Double(u) / Double(t) * 100
            }
        } catch { storageUsed = "未知"; storageTotal = "未知"; storagePercent = 0 }
    }
}

struct SensorRow: View {
    let icon: String; let name: String; let label: String; let value: String; let detail: String?; let progress: Double?; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(icon) \(name)·\(label)")
                    .font(.subheadline).foregroundColor(color)
                Spacer()
                if let d = detail { Text(d).font(.system(size: 10)).foregroundColor(color.opacity(0.6)) }
                Text(value)
                    .font(.subheadline).foregroundColor(color)
            }
            if let p = progress {
                ProgressView(value: p)
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .shadow(color: color, radius: 2)
            }
        }
        .padding(.horizontal)
    }
}

#Preview { ContentView() }
