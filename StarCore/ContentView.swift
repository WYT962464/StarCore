import SwiftUI
import UIKit
import CoreMotion
import Network

// 六十四卦核心引擎
struct HexagramEngine {
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

// 状态日志条目
struct StatusLog: Identifiable {
    let id = UUID()
    let time: String
    let hexagram: String
    let status: String
    let event: String
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
    @State private var networkStatus: String = "检测中..."
    @State private var networkType: String = ""
    @State private var statusLogs: [StatusLog] = []
    @State private var lastHexagram: String = ""
    @State private var lastStatus: String = ""
    @State private var monitor = NWPathMonitor()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var yinValue: Double { (cpuUsage + memoryUsage) / 2 }
    var yangValue: Double { (Double(batteryLevel) * 100 + motionIntensity) / 2 }
    
    var motionIntensity: Double {
        let a = sqrt(accelerometerX * accelerometerX + accelerometerY * accelerometerY + accelerometerZ * accelerometerZ)
        let g = sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ)
        return min(100, (a + g) * 10)
    }
    
    var currentHour: Int { Calendar.current.component(.hour, from: Date()) }
    var msgHex: (name: String, symbol: String, desc: String, color: Color, action: String) { HexagramEngine.currentMessageHexagram(hour: currentHour) }
    var drvHex: (name: String, desc: String, advice: String) { HexagramEngine.deriveHexagram(yin: yinValue, yang: yangValue) }
    var stat: (emoji: String, label: String, color: Color) { HexagramEngine.evaluateStatus(battery: batteryLevel, cpu: cpuUsage, memory: memoryUsage, motion: motionIntensity) }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.03, green: 0.03, blue: 0.1), Color(red: 0.08, green: 0.08, blue: 0.2), Color(red: 0.03, green: 0.12, blue: 0.15)]), startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 14) {
                    // 太极
                    VStack(spacing: 4) {
                        Text("☯️ 星核 ☯️")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: stat.color, radius: 12)
                            .scaleEffect(heartBeatScale)
                            .animation(.easeInOut(duration: 0.3), value: heartBeatScale)
                        HStack(spacing: 6) {
                            Text(stat.emoji).font(.title2)
                            Text(stat.label).font(.title3).fontWeight(.bold).foregroundColor(stat.color)
                            Text(msgHex.symbol).font(.title2)
                        }
                    }
                    
                    // 决策卡片
                    VStack(spacing: 5) {
                        HStack { Text(msgHex.symbol + " " + msgHex.name + "卦").font(.headline).foregroundColor(msgHex.color); Spacer(); Text(msgHex.desc).font(.caption).foregroundColor(.gray) }
                        HStack { Image(systemName: "bolt.fill").foregroundColor(msgHex.color).font(.caption); Text(msgHex.action).font(.caption).foregroundColor(.white.opacity(0.9)); Spacer() }
                        Divider().background(Color.gray.opacity(0.3))
                        HStack { Text(drvHex.name + "卦·" + drvHex.desc).font(.headline).foregroundColor(.cyan); Spacer() }
                        HStack { Text(drvHex.advice).font(.subheadline).foregroundColor(.cyan.opacity(0.9)); Spacer() }
                    }
                    .padding(10).background(Color.white.opacity(0.06)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(msgHex.color.opacity(0.3), lineWidth: 1)).padding(.horizontal)
                    
                    // 两仪
                    HStack(spacing: 0) {
                        VStack(spacing: 1) { Text("阴·信息流").font(.system(size: 9)).foregroundColor(.purple.opacity(0.7)); Text(String(format: "%.0f", yinValue)).font(.system(size: 26, weight: .bold)).foregroundColor(.purple) }.frame(maxWidth: .infinity)
                        VStack(spacing: 3) { GeometryReader { geo in ZStack(alignment: .leading) { RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.3)).frame(height: 5); let r = yangValue / max(yinValue + yangValue, 1); RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [.purple, .orange], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * CGFloat(r), height: 5) } }.frame(height: 5) }.frame(maxWidth: .infinity)
                        VStack(spacing: 1) { Text("阳·能量流").font(.system(size: 9)).foregroundColor(.orange.opacity(0.7)); Text(String(format: "%.0f", yangValue)).font(.system(size: 26, weight: .bold)).foregroundColor(.orange) }.frame(maxWidth: .infinity)
                    }.padding(.horizontal)
                    
                    Divider().background(Color.gray.opacity(0.2))
                    
                    // 八卦·八维
                    SensorRow(icon: "💚", name: "离·获取", label: "气血", value: String(format: "%.1f%%", batteryLevel * 100), detail: batteryStateDesc, progress: Double(batteryLevel), color: .green)
                    SensorRow(icon: "💙", name: "坎·执行", label: "脉搏", value: currentTime, detail: nil, progress: nil, color: .cyan)
                    SensorRow(icon: "❤️", name: "震·处理", label: "心跳", value: String(format: "%.1f%%", cpuUsage), detail: nil, progress: cpuUsage / 100, color: .red)
                    SensorRow(icon: "💜", name: "艮·校验", label: "思维", value: String(format: "%.1f%%", memoryUsage), detail: nil, progress: memoryUsage / 100, color: .purple)
                    SensorRow(icon: "💛", name: "坤·存储", label: "储备", value: "\(storageUsed)/\(storageTotal)", detail: String(format: "%.0f%%", storagePercent), progress: storagePercent / 100, color: .yellow)
                    
                    // 乾·收集·触觉+网络
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("🧭 乾·收集·触觉").font(.subheadline).foregroundColor(.orange)
                            Spacer()
                            Text(String(format: "%.0f%%", motionIntensity)).font(.subheadline).foregroundColor(.orange)
                        }
                        HStack {
                            Text("A:\(String(format: "%.1f", accelerometerX)),\(String(format: "%.1f", accelerometerY)),\(String(format: "%.1f", accelerometerZ))")
                                .font(.system(size: 9)).foregroundColor(.orange.opacity(0.5))
                            Spacer()
                            Text("📡 \(networkStatus)").font(.system(size: 9)).foregroundColor(networkStatus == "离线" ? .red.opacity(0.7) : .green.opacity(0.7))
                        }
                        ProgressView(value: motionIntensity / 100).progressViewStyle(LinearProgressViewStyle(tint: .orange))
                    }.padding(.horizontal)
                    
                    SensorRow(icon: "⚪️", name: "兑·迭代", label: "进化", value: formatUptime(uptime), detail: "v0.1.15", progress: min(1, uptime / 86400), color: .white.opacity(0.7))
                    SensorRow(icon: "🔵", name: "巽·输出", label: "状态", value: "\(msgHex.name)·\(drvHex.name)", detail: drvHex.desc, progress: yangValue / 100, color: .blue)
                    
                    Divider().background(Color.gray.opacity(0.2))
                    
                    // 状态变化日志
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("📜 变易日志").font(.headline).foregroundColor(.white.opacity(0.8))
                            Spacer()
                            if !statusLogs.isEmpty {
                                Text("\(statusLogs.count)条")
                                    .font(.caption).foregroundColor(.gray)
                            }
                        }
                        
                        if statusLogs.isEmpty {
                            Text("等待卦象流转...")
                                .font(.caption).foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(statusLogs.suffix(5).reversed()) { log in
                                HStack {
                                    Text(log.time).font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                                    Text(log.hexagram).font(.system(size: 10, weight: .bold)).foregroundColor(.cyan)
                                    Text(log.status).font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text(log.event).font(.system(size: 9)).foregroundColor(.yellow.opacity(0.8))
                                }
                            }
                        }
                    }
                    .padding(10).background(Color.white.opacity(0.04)).cornerRadius(8).padding(.horizontal)
                }
                .padding(.vertical, 6)
            }
        }
        .onReceive(timer) { _ in updateAll() }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            startNetworkMonitor()
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
    
    func startNetworkMonitor() {
        let queue = DispatchQueue(label: "network")
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        self.networkStatus = "WiFi"
                        self.networkType = "wifi"
                    } else if path.usesInterfaceType(.cellular) {
                        self.networkStatus = "蜂窝"
                        self.networkType = "cellular"
                    } else {
                        self.networkStatus = "在线"
                        self.networkType = "other"
                    }
                } else {
                    self.networkStatus = "离线"
                    self.networkType = "none"
                }
            }
        }
        monitor.start(queue: queue)
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
        checkStatusChange()
    }
    
    func checkStatusChange() {
        let currentHex = drvHex.name
        let currentStat = stat.label
        
        if lastHexagram != "" && (currentHex != lastHexagram || currentStat != lastStatus) {
            var event = ""
            if currentHex != lastHexagram { event += "\(lastHexagram)→\(currentHex)" }
            if currentStat != lastStatus { event += event.isEmpty ? "\(lastStatus)→\(currentStat)" : " \(lastStatus)→\(currentStat)" }
            
            let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
            statusLogs.append(StatusLog(time: f.string(from: Date()), hexagram: currentHex + "卦", status: currentStat, event: event))
            if statusLogs.count > 50 { statusLogs.removeFirst() }
        }
        
        lastHexagram = currentHex
        lastStatus = currentStat
    }
    
    func formatUptime(_ s: TimeInterval) -> String {
        let d = Int(s) / 86400; let h = Int(s) % 86400 / 3600; let m = Int(s) % 3600 / 60
        return d > 0 ? "\(d)d\(h)h\(m)m" : "\(h)h\(m)m"
    }
    
    func startMotionUpdates() {
        if motionManager.isAccelerometerAvailable { motionManager.accelerometerUpdateInterval = 0.1; motionManager.startAccelerometerUpdates(to: .main) { d, _ in if let d = d { accelerometerX = d.acceleration.x; accelerometerY = d.acceleration.y; accelerometerZ = d.acceleration.z } } }
        if motionManager.isGyroAvailable { motionManager.gyroUpdateInterval = 0.1; motionManager.startGyroUpdates(to: .main) { d, _ in if let d = d { gyroX = d.rotationRate.x; gyroY = d.rotationRate.y; gyroZ = d.rotationRate.z } } }
    }
    
    func triggerHeartBeat() { let i = max(0.02, min(0.1, cpuUsage / 1000)); heartBeatScale = 1.0 + CGFloat(i); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { heartBeatScale = 1.0 } }
    func updateCurrentTime() { let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; currentTime = f.string(from: Date()) }
    
    func updateCPUUsage() {
        var total: Double = 0; var info = processor_info_array_t(bitPattern: 0); var count = mach_msg_type_number_t(0); var n = UInt32(0)
        let r = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &n, &info, &count)
        if r == KERN_SUCCESS { for i in 0..<Int(n) { let c = info!.advanced(by: i * Int(CPU_STATE_MAX)); let u = Double(c[Int(CPU_STATE_USER)]), s = Double(c[Int(CPU_STATE_SYSTEM)]), ni = Double(c[Int(CPU_STATE_NICE)]), id = Double(c[Int(CPU_STATE_IDLE)]); let t = u + s + ni + id; if t > 0 { total += (u + s + ni) / t * 100 } }; cpuUsage = total / Double(n) }
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(count * UInt32(MemoryLayout<integer_t>.stride)))
    }
    
    func updateMemoryUsage() {
        var t = task_vm_info_data_t(); var c = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &t) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(c)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &c) } }
        if r == KERN_SUCCESS { memoryUsage = Double(t.phys_footprint) / Double(ProcessInfo.processInfo.physicalMemory) * 100 }
    }
    
    func updateStorageUsage() {
        do { let d = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false); let v = try d.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]); if let t = v.volumeTotalCapacity, let a = v.volumeAvailableCapacityForImportantUsage { let u = t - Int(a); storageUsed = ByteCountFormatter.string(fromByteCount: Int64(u), countStyle: .file); storageTotal = ByteCountFormatter.string(fromByteCount: Int64(t), countStyle: .file); storagePercent = Double(u) / Double(t) * 100 } } catch { storageUsed = "未知"; storageTotal = "未知"; storagePercent = 0 }
    }
}

struct SensorRow: View {
    let icon: String; let name: String; let label: String; let value: String; let detail: String?; let progress: Double?; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(icon) \(name)·\(label)").font(.subheadline).foregroundColor(color)
                Spacer()
                if let d = detail { Text(d).font(.system(size: 10)).foregroundColor(color.opacity(0.6)) }
                Text(value).font(.subheadline).foregroundColor(color)
            }
            if let p = progress { ProgressView(value: p).progressViewStyle(LinearProgressViewStyle(tint: color)).shadow(color: color, radius: 2) }
        }.padding(.horizontal)
    }
}

#Preview { ContentView() }
