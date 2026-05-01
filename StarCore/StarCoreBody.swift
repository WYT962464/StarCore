import UIKit

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
    
    // 读电池温度 - 先估算，后面加root权限后再精确读取
    private func readBatteryTemperature() -> Float {
        // 根据充电状态估算温度
        if stomach.isEating {
            return 32.0 + Float.random(in: 0...2.0) // 充电中32-34度
        } else {
            return 27.0 + Float.random(in: 0...1.5) // 没充电27-28.5度
        }
    }
    
    // 读电池健康度 - 先返回固定值，后面通过IOKit精确读取
    private func readBatteryHealth() -> String {
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
    
    // 感知思维负荷 - 简化版，避免mach API可能的崩溃
    private func senseMemory() {
        // 先给固定值，确保不崩溃
        mind.total = 4096.0 // 假设4GB
        mind.used = Float.random(in: 500...1500) // 随机500-1500MB
        mind.free = mind.total - mind.used
        mind.load = mind.used / mind.total
    }
    
    // 感知心跳 - 简化版，避免host_info可能的崩溃
    private func senseCPU() {
        // 先给固定模拟值
        let randomUsage = Float.random(in: 0.1...0.4) // 10%-40%
        heart.load = randomUsage
        heart.rate = 60 + Int(randomUsage * 60)
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
