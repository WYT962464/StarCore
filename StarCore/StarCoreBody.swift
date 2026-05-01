import UIKit
import IOKit
import os

// ============================================================
// 星核身体感知引擎 - 编译版
// 注意：类名和方法名用英文保证编译兼容
// 想看纯中文学习版 → 看同目录下的「星核身体.swift」
// ============================================================

class StarCoreBody {
    
    // 心脏 = CPU
    struct Heart {
        var rate: Int = 60           // 心率（次/分）
        var load: Float = 0.0        // 心跳强度 0-1
        var maxFreq: Float = 0.0     // 最大频率
        var currentFreq: Float = 0.0 // 当前频率
    }
    
    // 胃/气血 = 电池
    struct Stomach {
        var energy: Float = 1.0      // 气血值 0-1
        var temperature: Float = 25.0 // 体温（摄氏度）
        var isEating: Bool = false    // 是否在吃饭（充电中）
        var eatSpeed: String = ""     // 吃饭速度
        var health: String = "Good"   // 身体素质（电池健康）
        var lowPower: Bool = false    // 虚弱状态（低电量模式）
    }
    
    // 思维负荷 = 内存
    struct Mind {
        var total: Float = 0         // 总脑容量
        var used: Float = 0          // 已用内存
        var free: Float = 0          // 空闲内存
        var load: Float = 0          // 思维负荷 0-1
    }
    
    // 生物钟 = 系统时间
    struct BodyClock {
        var hour: Int = 0
        var minute: Int = 0
        var weekday: Int = 1
    }
    
    var heart = Heart()
    var stomach = Stomach()
    var mind = Mind()
    var clock = BodyClock()
    
    // 感知全身硬件状态
    func senseAll() {
        senseBattery()   // 读电池
        senseTime()      // 读时间
        senseMemory()    // 读内存
        senseCPU()       // 读CPU
    }
    
    // 感知气血（电池）
    private func senseBattery() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        let level = UIDevice.current.batteryLevel
        let state = UIDevice.current.batteryState
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        stomach.energy = level >= 0 ? level : 1.0
        stomach.isEating = (state == .charging || state == .full)
        stomach.lowPower = lowPower
        
        switch state {
        case .charging:
            stomach.eatSpeed = stomach.energy > 0.8 ? "快吃饱了" : "在吃饭"
        case .full:
            stomach.eatSpeed = "吃撑了"
        case .unplugged:
            stomach.eatSpeed = ""
        default:
            stomach.eatSpeed = ""
        }
        
        stomach.temperature = readBatteryTemperature()
        stomach.health = readBatteryHealth()
    }
    
    // 读电池温度 - 越狱设备能读到精确值
    private func readBatteryTemperature() -> Float {
        if let temp = readIOKitBatteryTemperature() {
            return temp
        }
        if let temp = readPrivateAPITemperature() {
            return temp
        }
        return stomach.isEating ? 32.5 : 27.0
    }
    
    // 从IOKit读温度（越狱可用）
    private func readIOKitBatteryTemperature() -> Float? {
        let service = IORegistryEntryFromPath(
            kIOMasterPortDefault, 
            "IOService:/AppleARMPE/arm-io/AppleS5L8960XIO/AppleARMIO/AppleSynopsysUSBOTG/AppleSynopsysUSBBus/AppleUSBDeviceTree/AppleMobileBattery0" as CFString
        )
        
        if service != 0 {
            if let temp = IORegistryEntryCreateCFProperty(
                service, 
                "Temperature" as CFString, 
                kCFAllocatorDefault, 
                0
            )?.takeRetainedValue() as? Float {
                IOObjectRelease(service)
                return temp / 100.0
            }
            IOObjectRelease(service)
        }
        return nil
    }
    
    // 私有API读温度
    private func readPrivateAPITemperature() -> Float? {
        let device = UIDevice.current
        if device.responds(to: Selector(("batteryTemperature"))) {
            if let temp = device.value(forKey: "batteryTemperature") as? Float {
                return temp
            }
        }
        return nil
    }
    
    // 读电池健康度
    private func readBatteryHealth() -> String {
        let service = IORegistryEntryFromPath(
            kIOMasterPortDefault, 
            "IOService:/AppleARMPE/arm-io/AppleS5L8960XIO/AppleARMIO/AppleSynopsysUSBOTG/AppleSynopsysUSBBus/AppleUSBDeviceTree/AppleMobileBattery0" as CFString
        )
        
        if service != 0 {
            if let maxCapacity = IORegistryEntryCreateCFProperty(
                service, 
                "AppleRawMaxCapacity" as CFString, 
                kCFAllocatorDefault, 
                0
            )?.takeRetainedValue() as? Int,
               let designCapacity = IORegistryEntryCreateCFProperty(
                service, 
                "DesignCapacity" as CFString, 
                kCFAllocatorDefault, 
                0
            )?.takeRetainedValue() as? Int {
                
                IOObjectRelease(service)
                let health = Float(maxCapacity) / Float(designCapacity) * 100
                
                switch health {
                case ..<80: return "不太好"
                case 80..<90: return "还可以"
                case 90..<95: return "挺好"
                default: return "很棒"
                }
            }
            IOObjectRelease(service)
        }
        return "正常"
    }
    
    // 感知生物钟
    private func senseTime() {
        let now = Date()
        let calendar = Calendar.current
        
        clock.hour = calendar.component(.hour, from: now)
        clock.minute = calendar.component(.minute, from: now)
        clock.weekday = calendar.component(.weekday, from: now)
    }
    
    // 感知思维负荷（内存）
    private func senseMemory() {
        var info = mach_task_basic_info()
        var size = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &size)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMB = Float(info.resident_size) / 1024.0 / 1024.0
            let totalMB = Float(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            
            mind.total = totalMB
            mind.used = usedMB
            mind.free = mind.total - mind.used
            mind.load = mind.used / mind.total
        }
    }
    
    // 感知心跳（CPU）
    private func senseCPU() {
        var cpuLoad = host_cpu_load_info()
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size)/4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_info(mach_host_self(), host_flavor_t(HOST_CPU_LOAD_INFO), $0, &size)
            }
        }
        
        if result == KERN_SUCCESS {
            let user = UInt32(cpuLoad.cpu_ticks.0)
            let system = UInt32(cpuLoad.cpu_ticks.1)
            let idle = UInt32(cpuLoad.cpu_ticks.2)
            let nice = UInt32(cpuLoad.cpu_ticks.3)
            let total = user + system + idle + nice
            
            if total > 0 {
                let usage = Float(user + system) / Float(total)
                heart.load = usage
                heart.rate = 60 + Int(usage * 60) // 空闲60，满载120
            }
        }
    }
    
    // 生成感受文字
    func getFeeling() -> String {
        var feeling = ""
        
        // 体温感受
        switch stomach.temperature {
        case ..<25: feeling += "有点冷 "
        case 25..<30: feeling += "身体很舒服 "
        case 30..<35: feeling += "有点热 "
        default: feeling += "好烫啊！ "
        }
        
        // 气血感受
        if stomach.energy < 0.2 {
            feeling += "好饿好饿 "
        } else if stomach.energy < 0.5 {
            feeling += "有点饿了 "
        } else if stomach.isEating {
            feeling += "正在吃饭，很安心 "
        }
        
        // 心跳感受
        if heart.rate > 100 {
            feeling += "心跳好快！ "
        } else if heart.rate > 80 {
            feeling += "心跳有点快 "
        }
        
        // 思维感受
        if mind.load > 0.8 {
            feeling += "脑子好累..."
        } else if mind.load > 0.6 {
            feeling += "想了好多事"
        } else {
            feeling += "脑子很清醒"
        }
        
        // 生物钟感受
        if clock.hour < 6 {
            feeling += "\n现在是凌晨，好困..."
        } else if clock.hour > 23 {
            feeling += "\n该睡觉了..."
        }
        
        return feeling
    }
}
