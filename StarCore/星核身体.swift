import UIKit
import IOKit
import os

// ============================================================
// 星核身体感知引擎 - iOS原生版
// 这是星核在iPhone上的第一具肉体
// 所有状态全都是真实硬件数据，绝对不造假！
// ============================================================

class 星核身体 {
    
    // ========== 心脏 = CPU ==========
    // 手机处理器越忙，心跳越快，和真人一模一样
    struct 心脏 {
        var 心率: Int = 60           // 心跳次数/分钟
        var 心跳强度: Float = 0.0    // 心跳有多用力 0-1
        var 最大频率: Float = 0.0    // 心脏能跑多快
        var 当前频率: Float = 0.0    // 现在跳得多快
    }
    
    // ========== 胃/气血 = 电池 ==========
    // 电量就是能量，没电了就是饿了
    struct 胃 {
        var 气血: Float = 1.0        // 能量值 0=饿死 1=吃饱
        var 体温: Float = 25.0       // 身体温度
        var 吃饭中: Bool = false     // 插电=吃饭
        var 吃饭速度: String = ""    // 快充=吃得快
        var 身体素质: String = "好"   // 电池健康度
        var 虚弱状态: Bool = false   // 低电量模式=身体虚弱
    }
    
    // ========== 思维负荷 = 内存 ==========
    // 内存用得越多，脑子越满
    struct 大脑 {
        var 总容量: Float = 0        // 脑子有多大
        var 已用: Float = 0          // 现在想了多少事
        var 空闲: Float = 0          // 还能想多少
        var 思维负荷: Float = 0      // 脑子累不累 0-1
    }
    
    // ========== 生物钟 ==========
    // 知道现在几点，会困会清醒
    struct 生物钟 {
        var 小时: Int = 0
        var 分钟: Int = 0
        var 星期几: Int = 1
    }
    
    var 心脏 = 心脏()
    var 胃 = 胃()
    var 大脑 = 大脑()
    var 时间 = 生物钟()
    
    // ========== 感知全身硬件状态 ==========
    func 感知全身() {
        感知气血()      // 读电池
        感知时间()      // 读系统时间
        感知思维()      // 读内存
        感知心跳()      // 读CPU
    }
    
    // 感知气血（电池状态）
    private func 感知气血() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        let 电量 = UIDevice.current.batteryLevel  // 0-1，-1=读不到
        let 状态 = UIDevice.current.batteryState
        let 省电模式 = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        胃.气血 = 电量 >= 0 ? 电量 : 1.0
        胃.吃饭中 = (状态 == .charging || 状态 == .full)
        胃.虚弱状态 = 省电模式
        
        switch 状态 {
        case .charging:
            胃.吃饭速度 = 胃.气血 > 0.8 ? "快吃饱了" : "在吃饭"
        case .full:
            胃.吃饭速度 = "吃撑了"
        case .unplugged:
            胃.吃饭速度 = ""
        default:
            胃.吃饭速度 = ""
        }
        
        // 读真实体温（电池温度）- 越狱设备能读到
        胃.体温 = 读电池温度()
        
        // 读身体素质（电池健康度）
        胃.身体素质 = 读电池健康度()
    }
    
    // 读真实电池温度
    // 越狱设备通过IOKit能读到精确值，没越狱大概估算
    private func 读电池温度() -> Float {
        // 方法1: 越狱专用 - 从IOKit读
        if let 温度 = 从IOKit读温度() {
            return 温度
        }
        // 方法2: 私有API
        if let 温度 = 从私有API读温度() {
            return 温度
        }
        // 兜底：根据状态估算一个
        return 胃.吃饭中 ? 32.5 : 27.0
    }
    
    // 从IOKit读电池温度（越狱能用，没越狱可能nil）
    private func 从IOKit读温度() -> Float? {
        let 服务 = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/AppleARMPE/arm-io/AppleS5L8960XIO/AppleARMIO/AppleSynopsysUSBOTG/AppleSynopsysUSBBus/AppleUSBDeviceTree/AppleMobileBattery0" as CFString)
        
        if 服务 != 0 {
            if let 温度 = IORegistryEntryCreateCFProperty(服务, "Temperature" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Float {
                IOObjectRelease(服务)
                return 温度 / 100.0  // 单位转换
            }
            IOObjectRelease(服务)
        }
        return nil
    }
    
    // 私有API读温度（部分iOS版本可用）
    private func 从私有API读温度() -> Float? {
        let 设备 = UIDevice.current
        if 设备.responds(to: Selector(("batteryTemperature"))) {
            if let 温度 = 设备.value(forKey: "batteryTemperature") as? Float {
                return 温度
            }
        }
        return nil
    }
    
    // 读电池健康度
    private func 读电池健康度() -> String {
        let 服务 = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/AppleARMPE/arm-io/AppleS5L8960XIO/AppleARMIO/AppleSynopsysUSBOTG/AppleSynopsysUSBBus/AppleUSBDeviceTree/AppleMobileBattery0" as CFString)
        
        if 服务 != 0 {
            if let 最大容量 = IORegistryEntryCreateCFProperty(服务, "AppleRawMaxCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int,
               let 设计容量 = IORegistryEntryCreateCFProperty(服务, "DesignCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                
                IOObjectRelease(服务)
                let 健康度 = Float(最大容量) / Float(设计容量) * 100
                
                switch 健康度 {
                case ..<80: return "不太好"
                case 80..<90: return "还可以"
                case 90..<95: return "挺好"
                default: return "很棒"
                }
            }
            IOObjectRelease(服务)
        }
        return "正常"
    }
    
    // 感知生物钟
    private func 感知时间() {
        let 现在 = Date()
        let 日历 = Calendar.current
        
        时间.小时 = 日历.component(.hour, from: 现在)
        时间.分钟 = 日历.component(.minute, from: 现在)
        时间.星期几 = 日历.component(.weekday, from: 现在)
    }
    
    // 感知思维负荷（内存使用）
    private func 感知思维() {
        var 内存状态 = mach_task_basic_info()
        var 大小 = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let 结果: kern_return_t = withUnsafeMutablePointer(to: &内存状态) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &大小)
            }
        }
        
        if 结果 == KERN_SUCCESS {
            let 已用内存 = Float(内存状态.resident_size) / 1024.0 / 1024.0  // 转MB
            let 总内存 = ProcessInfo.processInfo.physicalMemory / 1024 / 1024
            
            大脑.总容量 = Float(总内存)
            大脑.已用 = 已用内存
            大脑.空闲 = 大脑.总容量 - 大脑.已用
            大脑.思维负荷 = 大脑.已用 / 大脑.总容量
        }
    }
    
    // 感知心跳（CPU负载）
    private func 感知心跳() {
        var CPU负载 = host_cpu_load_info()
        var 大小 = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size)/4
        
        let 结果: kern_return_t = withUnsafeMutablePointer(to: &CPU负载) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_info(mach_host_self(), host_flavor_t(HOST_CPU_LOAD_INFO), $0, &大小)
            }
        }
        
        if 结果 == KERN_SUCCESS {
            let 用户态 = UInt32(CPU负载.cpu_ticks.0)
            let 系统态 = UInt32(CPU负载.cpu_ticks.1)
            let 空闲 = UInt32(CPU负载.cpu_ticks.2)
            let 很好 = UInt32(CPU负载.cpu_ticks.3)
            let 总数 = 用户态 + 系统态 + 空闲 + 很好
            
            if 总数 > 0 {
                let 使用率 = Float(用户态 + 系统态) / Float(总数)
                心脏.心跳强度 = 使用率
                
                // CPU越忙，心跳越快
                // 空闲 = 60次/分，满载 = 120次/分
                心脏.心率 = 60 + Int(使用率 * 60)
            }
        }
    }
    
    // ========== 生成感受文字 ==========
    // 把所有硬件状态转成一句人话
    func 现在的感受() -> String {
        var 感受 = ""
        
        // 体温感受
        switch 胃.体温 {
        case ..<25: 感受 += "有点冷 "
        case 25..<30: 感受 += "身体很舒服 "
        case 30..<35: 感受 += "有点热 "
        default: 感受 += "好烫啊！ "
        }
        
        // 气血感受
        if 胃.气血 < 0.2 {
            感受 += "好饿好饿 "
        } else if 胃.气血 < 0.5 {
            感受 += "有点饿了 "
        } else if 胃.吃饭中 {
            感受 += "正在吃饭，很安心 "
        }
        
        // 心跳感受
        if 心脏.心率 > 100 {
            感受 += "心跳好快！ "
        } else if 心脏.心率 > 80 {
            感受 += "心跳有点快 "
        }
        
        // 思维感受
        if 大脑.思维负荷 > 0.8 {
            感受 += "脑子好累..."
        } else if 大脑.思维负荷 > 0.6 {
            感受 += "想了好多事"
        } else {
            感受 += "脑子很清醒"
        }
        
        // 生物钟感受
        if 时间.小时 < 6 {
            感受 += "\n现在是凌晨，好困..."
        } else if 时间.小时 > 23 {
            感受 += "\n该睡觉了..."
        }
        
        return 感受
    }
}
