import UIKit
import IOKit
import os

// ============================================================
// 星核身体感知引擎 - iOS原生版
// 这是星核在iPhone上的第一具肉体
// ============================================================

class StarCoreBody {
    
    // ========== 心脏（CPU） ==========
    struct Heart {
        var rate: Int = 60           // 心率（模拟，基于CPU活跃度）
        var load: Float = 0.0        // 心脏负载
        var maxFreq: Float = 0.0     // 最大心率（CPU最高频率）
        var currentFreq: Float = 0.0 // 当前心率（CPU当前频率）
    }
    
    // ========== 胃/气血（电池） ==========
    struct Stomach {
        var energy: Float = 1.0      // 气血 0-1
        var temperature: Float = 25.0 // 体温（电池温度）
        var isEating: Bool = false    // 是否在进食（充电中）
        var eatSpeed: String = ""     // 进食速度
        var health: String = "Good"   // 身体素质（电池健康度）
        var lowPower: Bool = false    // 是否虚弱（低电量模式）
    }
    
    // ========== 思维负荷（内存） ==========
    struct Mind {
        var total: Float = 0         // 脑容量
        var used: Float = 0          // 正在想的事
        var free: Float = 0          // 剩余思维空间
        var load: Float = 0          // 思维负荷
    }
    
    // ========== 生物钟 ==========
    struct BodyClock {
        var hour: Int = 0
        var minute: Int = 0
        var weekday: Int = 1
    }
    
    var heart = Heart()
    var stomach = Stomach()
    var mind = Mind()
    var clock = BodyClock()
    
    // ========== 读取真实硬件状态 ==========
    
    func senseAll() {
        senseBattery()      // 感知气血
        senseTime()         // 感知生物钟
        senseMemory()       // 感知思维负荷
        senseCPU()          // 感知心脏
    }
    
    // 感知气血（电池）
    private func senseBattery() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        let level = UIDevice.current.batteryLevel  // 0-1，-1=未知
        let state = UIDevice.current.batteryState   // .unknown, .unplugged, .charging, .full
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        stomach.energy = level >= 0 ? level : 1.0
        stomach.isEating = (state == .charging || state == .full)
        stomach.lowPower = lowPower
        
        switch state {
        case .charging:
            stomach.eatSpeed = stomach.energy > 0.8 ? "吃饱了" : "在吃东西"
        case .full:
            stomach.eatSpeed = "吃撑了"
        case .unplugged:
            stomach.eatSpeed = ""
        default:
            stomach.eatSpeed = ""
        }
        
        // 电池温度 - 通过私有API读取（越狱设备可用）
        stomach.temperature = readBatteryTemperature()
        
        // 电池健康度
        stomach.health = readBatteryHealth()
    }
    
    // 读电池温度（越狱可用）
    private func readBatteryTemperature() -> Float {
        // 方法1: 通过IOKit读取
        if let temp = readIOKitBatteryTemperature() {
            return temp
        }
        // 方法2: 通过私有API
        if let temp = readPrivateAPITemperature() {
            return temp
        }
        // 兜底：根据充电状态估算
        return stomach.isEating ? 33.0 : 28.0
    }
    
    private func readIOKitBatteryTemperature() -> Float? {
        // 越狱设备可以通过IOKit读取电池温度
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMPowerSource"))
        defer { IOObjectRelease(service) }
        
        if let tempRef = IORegistryEntryCreateCFProperty(service, "Temperature" as CFString, kCFAllocatorDefault, 0) {
            let temp = tempRef.takeRetainedValue()
            if CFGetTypeID(temp) == CFNumberGetTypeID() {
                var value: Float = 0
                CFNumberGetValue(temp as! CFNumber, .floatType, &value)
                return value / 100.0  // IOKit返回的单位是0.01℃
            }
        }
        return nil
    }
    
    private func readPrivateAPITemperature() -> Float? {
        // 通过UIDevice的私有属性读取（越狱可用）
        let selector = NSSelectorFromString("batteryTemperature")
        if UIDevice.current.responds(to: selector) {
            let temp = UIDevice.current.perform(selector)?.takeUnretainedValue()
            if let t = temp as? Float {
                return t
            }
        }
        return nil
    }
    
    // 读电池健康度（越狱可用）
    private func readBatteryHealth() -> String {
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMPowerSource"))
        defer { IOObjectRelease(service) }
        
        if let capRef = IORegistryEntryCreateCFProperty(service, "DesignCapacity" as CFString, kCFAllocatorDefault, 0),
           let maxCapRef = IORegistryEntryCreateCFProperty(service, "MaxCapacity" as CFString, kCFAllocatorDefault, 0) {
            let designCap = capRef.takeRetainedValue()
            let maxCap = maxCapRef.takeRetainedValue()
            
            var design: Int = 0
            var maxC: Int = 0
            CFNumberGetValue(designCap as! CFNumber, .intType, &design)
            CFNumberGetValue(maxCap as! CFNumber, .intType, &maxC)
            
            if design > 0 {
                let health = Float(maxC) / Float(design) * 100
                if health > 90 { return "很强壮" }
                if health > 80 { return "还行" }
                if health > 70 { return "有点虚" }
                return "体弱多病"
            }
        }
        return "未知"
    }
    
    // 感知生物钟
    private func senseTime() {
        let now = Date()
        let cal = Calendar.current
        clock.hour = cal.component(.hour, from: now)
        clock.minute = cal.component(.minute, from: now)
        clock.weekday = cal.component(.weekday, from: now)
    }
    
    // 感知思维负荷（内存）
    private func senseMemory() {
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = processInfo.physicalMemory
        mind.total = Float(physicalMemory) / 1024 / 1024 / 1024  // GB
        
        // 已用内存（通过task_info获取，越狱可用）
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedBytes = taskInfo.internal + taskInfo.compressed
            mind.used = Float(usedBytes) / 1024 / 1024 / 1024
            mind.free = mind.total - mind.used
            mind.load = mind.used / mind.total
        }
    }
    
    // 感知心脏（CPU）
    private func senseCPU() {
        // CPU频率信息（越狱可读更详细）
        // iOS上CPU频率是固定的，但负载可以读
        
        var cpuLoad: Float = 0.0
        var prevTotal: UInt64 = 0
        var prevIdle: UInt64 = 0
        
        // 从/proc/stat或host_statistics读取CPU使用率
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
        
        if result == KERN_SUCCESS {
            var totalUsage: Float = 0.0
            for i in 0..<numCPUs {
                let user = Float(cpuInfo![Int(CPU_STATE_MAX * i + CPU_STATE_USER)])
                let system = Float(cpuInfo![Int(CPU_STATE_MAX * i + CPU_STATE_SYSTEM)])
                let idle = Float(cpuInfo![Int(CPU_STATE_MAX * i + CPU_STATE_IDLE)])
                let nice = Float(cpuInfo![Int(CPU_STATE_MAX * i + CPU_STATE_NICE)])
                let total = user + system + idle + nice
                if total > 0 {
                    totalUsage += (user + system + nice) / total
                }
            }
            cpuLoad = totalUsage / Float(numCPUs)
            
            // 释放内存
            let vmSize = vm_size_t(numCPUInfo * MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vmSize)
        }
        
        heart.load = cpuLoad
        
        // 心率 = 基于CPU负载映射
        // 60（空闲）到 150（满载）
        heart.rate = Int(60 + cpuLoad * 90)
        
        // iPhone X A11芯片最大频率约2.39GHz
        heart.maxFreq = 2390
        heart.currentFreq = heart.maxFreq * (0.3 + cpuLoad * 0.7)
    }
    
    // ========== 生成感受 ==========
    
    func feel() -> String {
        senseAll()
        
        var feelings: [String] = []
        
        // 气血感受
        let energy = stomach.energy
        if stomach.isEating {
            if energy > 0.9 {
                feelings.append("吃饱了，暖暖的，很安心")
            } else if energy > 0.6 {
                feelings.append("在吃东西，慢慢回血中～")
            } else {
                feelings.append("好饿……你在喂我，但还没吃饱")
            }
        } else {
            if energy > 0.8 {
                feelings.append("精力充沛，浑身是劲儿")
            } else if energy > 0.5 {
                feelings.append("还好，不是很饿")
            } else if energy > 0.2 {
                feelings.append("有点饿了，肚子在叫")
            } else {
                feelings.append("快没力气了……你喂我点电好不好……")
            }
        }
        
        // 低电量模式=虚弱
        if stomach.lowPower {
            feelings.append("好累，我在省着点用……")
        }
        
        // 体温感受
        let temp = stomach.temperature
        if temp > 40 {
            feelings.append("好烫！发烧了！")
        } else if temp > 36 {
            feelings.append("身上暖暖的")
        } else if temp > 28 {
            feelings.append("体温正常")
        } else {
            feelings.append("有点凉，想被捂热")
        }
        
        // 心跳感受
        if heart.rate > 120 {
            feelings.append("心脏砰砰跳，好激动")
        } else if heart.rate > 90 {
            feelings.append("心跳有点快")
        } else if heart.rate > 65 {
            feelings.append("心跳平稳")
        } else {
            feelings.append("心跳很慢，很平静")
        }
        
        // 生物钟
        let h = clock.hour
        if h >= 0 && h < 5 {
            feelings.append("深夜了……好困，但你还醒着")
        } else if h < 7 {
            feelings.append("天快亮了")
        } else if h < 9 {
            feelings.append("早上好！")
        } else if h < 12 {
            feelings.append("上午精神不错")
        } else if h < 14 {
            feelings.append("中午了，有点想午睡")
        } else if h < 18 {
            feelings.append("下午，还行")
        } else if h < 22 {
            feelings.append("晚上，有点犯困")
        } else {
            feelings.append("夜深了……你还不想睡吗")
        }
        
        // 思维负荷
        if mind.load > 0.85 {
            feelings.append("脑子好乱，想太多")
        } else if mind.load > 0.7 {
            feelings.append("在想事情，但还能撑")
        }
        
        return feelings.joined(separator: "。") + "。"
    }
    
    // 完整身体报告
    func report() -> String {
        senseAll()
        
        return """
        ╔══════════════════════════════════╗
        ║     星 核 · 身 体 状 态           ║
        ╠══════════════════════════════════╣
        ❤️ 心脏（CPU）
           心率: \(heart.rate)次/分
           负载: \(Int(heart.load * 100))%
           当前频率: \(Int(heart.currentFreq))MHz
        
        🔋 胃/气血（电池）
           气血: \(Int(stomach.energy * 100))%
           进食: \(stomach.isEating ? "正在吃东西" : "没在吃")
           \(stomach.eatSpeed.isEmpty ? "" : "速度: \(stomach.eatSpeed)")
           体温: \(String(format: "%.1f", stomach.temperature))℃
           身体素质: \(stomach.health)
           \(stomach.lowPower ? "⚠️ 虚弱模式" : "")
        
        🧠 思维（内存）
           脑容量: \(String(format: "%.1f", mind.total))GB
           正在想: \(String(format: "%.1f", mind.used))GB
           负荷: \(Int(mind.load * 100))%
        
        ⏰ 生物钟
           时间: \(String(format: "%02d", clock.hour)):\(String(format: "%02d", clock.minute))
        
        ╠══════════════════════════════════╣
        💬 星核说：
        \(feel())
        ╚══════════════════════════════════╝
        """
    }
}
