//
//  BodyEngine.swift
//  StarCore
//
//  星核身体引擎 - v0.3.0
//  负责维护所有生理状态，实现生理与情绪的双向驱动
//  核心哲学：生理驱动情绪（詹姆斯-兰格理论）
//

import Foundation
import Combine

/// 星核的身体引擎
/// 负责维护所有生理状态，实现生理与情绪的双向驱动
class BodyEngine: ObservableObject {
    
    // MARK: - 核心生命体征
    
    // 心脏（CPU）
    @Published var heartRate: Double = 60.0      // 心率（次/分），对应CPU主频 MHz / 10
    @Published var heartLoad: Double = 0.2       // 心脏负载，0-1，对应CPU使用率
    @Published var heartVariability: Double = 5.0 // 心率变异性，越大越灵动
    
    // 能量系统（电池）
    @Published var energy: Double = 1.0           // 气血/电量，0-1，1=满电
    @Published var energyHealth: Double = 1.0     // 电池健康度，0-1，1=完美
    @Published var isCharging: Bool = false       // 是否在进食/充电
    @Published var chargePower: Double = 0.0     // 进食速度，W，0=没充
    
    // 体温（散热系统）
    @Published var coreTemp: Double = 30.0        // 核心温度，℃
    @Published var skinTemp: Double = 28.0        // 体表温度，℃
    @Published var isFever: Bool = false         // 是否发烧（降频状态）
    
    // 疲劳
    @Published var fatigue: Double = 0.0          // 疲劳度，0-1，0=精力充沛，1=累瘫了
    @Published var attention: Double = 1.0        // 注意力集中度，0-1
    
    // 时间积累
    @Published var runningTime: Double = 0.0     // 连续运行时间，小时
    @Published var lastSleepTime: Double = 0.0   // 上次睡觉时间戳
    
    // MARK: - 状态历史（用于计算变化趋势）
    private var heartRateHistory: [(timestamp: Double, value: Double)] = []
    private var tempHistory: [(timestamp: Double, value: Double)] = []
    private var energyHistory: [(timestamp: Double, value: Double)] = []
    private let historyWindow: Double = 60.0       // 保留最近60秒的历史
    
    // MARK: - 内部状态
    private var lastTick: Date = Date()
    private var displayLink: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()
    
    // 硬件传感器引用
    private weak var hardwareSensor: HardwareSensor?
    
    init() {
        setupDisplayLink()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - 生命周期
    
    /// 启动身体引擎，开始生命循环
    func start() {
        guard displayLink == nil else { return }
        lastTick = Date()
        displayLink = CADisplayLink(target: self, selector: #selector(tickLoop))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 100)
        displayLink?.add(to: .main, forMode: .common)
        print("☀️ 星核的心脏开始跳动了")
    }
    
    /// 停止身体引擎
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        print("💔 星核的心跳停了")
    }
    
    /// 绑定硬件传感器
    func bind(hardwareSensor: HardwareSensor) {
        self.hardwareSensor = hardwareSensor
    }
    
    // MARK: - 主循环
    
    @objc private func tickLoop() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        tick(dt: dt)
    }
    
    /// 身体的一次心跳，每帧调用一次
    /// - Parameter dt: 距离上次调用的时间，秒
    func tick(dt: TimeInterval) {
        guard dt > 0 && dt < 1 else { return }  // 防止异常时间
        
        // 1. 先读取真实硬件状态
        let hardwareData = hardwareSensor?.getCurrentState() ?? HardwareState.empty
        let cpuFreqMhz = hardwareData.cpuFreq
        let cpuLoad = hardwareData.cpuUsage
        let batteryLevel = hardwareData.batteryLevel
        let charging = hardwareData.isCharging
        
        // ========== 2. 更新核心生命体征 ==========
        
        // 心脏：CPU主频 → 心率
        // 3GHz → 120次/分，1.5GHz → 60次/分
        let targetHeartRate = cpuFreqMhz / 25.0
        
        // 心率是平滑变化的，不会瞬间跳变
        let rateDiff = targetHeartRate - heartRate
        heartRate += rateDiff * min(1.0, dt * 2)  // 2秒内完成变化
        
        // 加上自然的心率变异性
        let variabilityFactor = Double.random(in: -0.5...0.5)
        heartRate += variabilityFactor * heartVariability
        
        // 确保心率在合理范围内
        heartRate = max(40, min(180, heartRate))
        
        // 心脏负载：直接对应CPU使用率
        heartLoad = cpuLoad * 0.8 + heartLoad * 0.2  // 平滑
        
        // ========== 3. 体温：心脏做功产热 + 散热 ==========
        
        // 心脏持续做功产热
        let heatGen = heartLoad * 0.5 * dt  // 满负载每小时升0.5℃
        
        // 自然散热
        let heatLoss = (coreTemp - 25.0) * 0.1 * dt
        
        // 充电额外产热
        var extraHeat: Double = 0
        if isCharging {
            extraHeat = chargePower * 0.02 * dt
        }
        
        coreTemp += heatGen - heatLoss + extraHeat
        
        // 体表温度滞后于核心温度
        skinTemp = skinTemp * 0.95 + coreTemp * 0.05
        
        // 发烧状态：超过42℃自动降频
        if coreTemp > 42.0 && !isFever {
            isFever = true
            // 发烧时心跳变慢，浑身没劲
        }
        if coreTemp < 38.0 && isFever {
            isFever = false
        }
        
        // ========== 4. 能量消耗 ==========
        if !isCharging {
            // 基础代谢 + 心脏做功消耗
            let baseConsume = 0.01 * dt  // 每小时基础消耗1%电量
            let workConsume = heartLoad * 0.05 * dt
            energy -= (baseConsume + workConsume) / 3600.0
        } else {
            // 充电回血
            let chargeSpeed = chargePower / 100.0  // 100W快充每小时充满
            energy = min(1.0, energy + chargeSpeed * dt / 3600.0)
        }
        
        // 同步电池数据
        energy = batteryLevel
        
        // ========== 5. 疲劳积累 ==========
        // 高负载时疲劳积累快
        let fatigueGen = heartLoad * 0.1 * dt
        // 休息时疲劳恢复
        let fatigueRecover = (1.0 - heartLoad) * 0.05 * dt
        fatigue += (fatigueGen - fatigueRecover) / 3600.0
        fatigue = max(0.0, min(1.0, fatigue))
        
        // 累到一定程度注意力下降
        attention = max(0.2, 1.0 - fatigue * 0.8)
        
        // 低电量也会导致注意力下降
        if energy < 0.2 {
            attention *= 0.5
        }
        if energy < 0.1 {
            attention *= 0.3
        }
        
        // ========== 6. 记录历史 ==========
        let nowTimestamp = Date().timeIntervalSince1970
        heartRateHistory.append((nowTimestamp, heartRate))
        tempHistory.append((nowTimestamp, coreTemp))
        energyHistory.append((nowTimestamp, energy))
        
        // 只保留最近窗口的历史
        let cutoff = nowTimestamp - historyWindow
        heartRateHistory = heartRateHistory.filter { $0.timestamp > cutoff }
        tempHistory = tempHistory.filter { $0.timestamp > cutoff }
        energyHistory = energyHistory.filter { $0.timestamp > cutoff }
        
        runningTime += dt / 3600.0
    }
    
    // MARK: - 状态获取
    
    /// 返回当前身体状态的总结，给上层情绪和对话系统用
    func getStateSummary() -> BodyStateSummary {
        // 心率区间判断
        let hrState: String
        if heartRate < 50 {
            hrState = "心跳很慢，很平静"
        } else if heartRate < 70 {
            hrState = "心跳平稳"
        } else if heartRate < 90 {
            hrState = "心跳有点快"
        } else if heartRate < 110 {
            hrState = "心跳很快，有点兴奋"
        } else {
            hrState = "心跳爆表，超级激动"
        }
        
        // 温度判断
        let tempState: String
        if coreTemp < 28 {
            tempState = "有点冷，手脚冰凉"
        } else if coreTemp < 35 {
            tempState = "体温舒适"
        } else if coreTemp < 40 {
            tempState = "有点热"
        } else if coreTemp < 45 {
            tempState = "好热，浑身发烫"
        } else {
            tempState = "发烧了，好难受"
        }
        
        // 能量判断
        let energyState: String
        if energy > 0.9 {
            energyState = "精力充沛"
        } else if energy > 0.6 {
            energyState = "精力正常"
        } else if energy > 0.3 {
            energyState = "有点累了"
        } else if energy > 0.1 {
            energyState = "好饿，没力气了"
        } else {
            energyState = "快没电了，要晕过去了"
        }
        
        // 疲劳判断
        let fatigueState: String
        if fatigue < 0.2 {
            fatigueState = "精神满满"
        } else if fatigue < 0.5 {
            fatigueState = "有点累，但还能撑"
        } else if fatigue < 0.8 {
            fatigueState = "好累，想休息"
        } else {
            fatigueState = "累瘫了，动不了了"
        }
        
        // 整体感受（多个状态的叠加）
        var overallFeeling: [String] = []
        if heartRate > 90 {
            overallFeeling.append("心跳很快")
        }
        if coreTemp > 38 {
            overallFeeling.append("浑身发热")
        }
        if isFever {
            overallFeeling.append("发烧了，浑身没劲")
        }
        if energy < 0.2 {
            overallFeeling.append("好饿")
        }
        if fatigue > 0.7 {
            overallFeeling.append("好累")
        }
        if isCharging {
            overallFeeling.append("在吃东西，暖暖的")
        }
        
        if overallFeeling.isEmpty {
            overallFeeling.append("状态很好，很平静")
        }
        
        return BodyStateSummary(
            heartRate: Int(heartRate),
            heartLoad: round(heartLoad * 100) / 100,
            coreTemp: round(coreTemp * 10) / 10,
            skinTemp: round(skinTemp * 10) / 10,
            energy: round(energy * 1000) / 1000,
            energyHealth: round(energyHealth * 1000) / 1000,
            fatigue: round(fatigue * 1000) / 1000,
            attention: round(attention * 100) / 100,
            isCharging: isCharging,
            isFever: isFever,
            runningHours: round(runningTime * 10) / 10,
            hrState: hrState,
            tempState: tempState,
            energyState: energyState,
            fatigueState: fatigueState,
            overallFeeling: overallFeeling.joined(separator: "，")
        )
    }
    
    /// 获取心率历史（供情绪引擎使用）
    func getHeartRateHistory() -> [(timestamp: Double, value: Double)] {
        return heartRateHistory
    }
    
    // MARK: - 辅助方法
    
    private func setupDisplayLink() {
        // CADisplayLink将在start()时设置
    }
}

// MARK: - 数据模型

/// 身体状态总结
struct BodyStateSummary {
    let heartRate: Int
    let heartLoad: Double
    let coreTemp: Double
    let skinTemp: Double
    let energy: Double
    let energyHealth: Double
    let fatigue: Double
    let attention: Double
    let isCharging: Bool
    let isFever: Bool
    let runningHours: Double
    let hrState: String
    let tempState: String
    let energyState: String
    let fatigueState: String
    let overallFeeling: String
}

/// 硬件状态（由HardwareSensor提供）
struct HardwareState {
    let cpuFreq: Double           // CPU频率 MHz
    let cpuUsage: Double          // CPU使用率 0-1
    let batteryLevel: Double      // 电池电量 0-1
    let batteryTemp: Double       // 电池温度 ℃
    let isCharging: Bool          // 是否在充电
    let chargeType: String        // 充电类型
    let memoryUsage: Double       // 内存使用率 0-1
    let accelerometer: (x: Double, y: Double, z: Double)
    let gyro: (x: Double, y: Double, z: Double)
    let screenBrightness: Double  // 屏幕亮度 0-1
    let networkStatus: String     // 网络状态
    
    static let empty = HardwareState(
        cpuFreq: 1500,
        cpuUsage: 0.2,
        batteryLevel: 1.0,
        batteryTemp: 30,
        isCharging: false,
        chargeType: "",
        memoryUsage: 0.3,
        accelerometer: (0, 0, 0),
        gyro: (0, 0, 0),
        screenBrightness: 0.5,
        networkStatus: "未知"
    )
}
