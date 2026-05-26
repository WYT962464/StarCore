//
//  EnergySystem.swift
//  StarCore - 双能量系统
//
//  基于六十四卦式通用自循环演化系统 v1.4
//  物理能量 + 认知能量的双能量模型
//

import Foundation

// MARK: - 能量类型

/// 能量级别
enum EnergyLevel: Float, CaseIterable {
    case critical = 0.0      // 危急（< 10%）
    case low = 0.25          // 低（10-30%）
    case moderate = 0.5      // 中等（30-70%）
    case high = 0.75         // 高（70-90%）
    case optimal = 1.0       // 最优（> 90%）
    
    var description: String {
        switch self {
        case .critical: return "危急"
        case .low: return "低"
        case .moderate: return "中等"
        case .high: return "高"
        case .optimal: return "最优"
        }
    }
    
    var color: String {
        switch self {
        case .critical: return "🔴"
        case .low: return "🟠"
        case .moderate: return "🟡"
        case .high: return "🟢"
        case .optimal: return "✨"
        }
    }
}

// MARK: - 物理能量

/// 物理能量 - 映射设备硬件状态
struct PhysicalEnergy {
    // 电池电量（0-1）
    var batteryLevel: Float = 1.0
    
    // 设备温度状态
    var temperatureStatus: TemperatureStatus = .normal
    
    // CPU 使用率（0-1）
    var cpuUsage: Float = 0.0
    
    // 内存使用率（0-1）
    var memoryUsage: Float = 0.0
    
    // 网络状态
    var networkStatus: NetworkStatus = .connected
    
    /// 综合物理能量评分
    var score: Float {
        var score = batteryLevel
        
        // 温度惩罚
        switch temperatureStatus {
        case .overheating: score *= 0.5
        case .cold: score *= 0.7
        case .normal: break
        }
        
        // CPU 惩罚（过高表示负载重）
        score *= (1.0 - cpuUsage * 0.3)
        
        // 内存惩罚
        score *= (1.0 - memoryUsage * 0.2)
        
        // 网络影响
        switch networkStatus {
        case .disconnected: score *= 0.8
        case .weak: score *= 0.9
        case .connected: break
        }
        
        return max(0, min(1, score))
    }
    
    /// 能量级别
    var level: EnergyLevel {
        let s = score
        if s < 0.1 { return .critical }
        if s < 0.3 { return .low }
        if s < 0.7 { return .moderate }
        if s < 0.9 { return .high }
        return .optimal
    }
}

/// 温度状态
enum TemperatureStatus {
    case cold, normal, overheating
}

/// 网络状态
enum NetworkStatus {
    case disconnected, weak, connected
}

// MARK: - 认知能量

/// 认知能量 - 任务奖励/惩罚系统
struct CognitiveEnergy {
    // 基础认知能量（0-1）
    var baseEnergy: Float = 0.5
    
    // 当前任务累积能量
    var taskEnergy: Float = 0.0
    
    // 能量池（可存储的额外能量）
    var energyPool: Float = 0.0
    
    // 能量衰减率（每 tick）
    var decayRate: Float = 0.001
    
    // 最大能量池容量
    let maxPoolCapacity: Float = 1.0
    
    /// 综合认知能量评分
    var score: Float {
        let total = baseEnergy + taskEnergy + energyPool
        return max(0, min(1, total))
    }
    
    /// 能量级别
    var level: EnergyLevel {
        let s = score
        if s < 0.1 { return .critical }
        if s < 0.3 { return .low }
        if s < 0.7 { return .moderate }
        if s < 0.9 { return .high }
        return .optimal
    }
    
    /// 奖励能量
    mutating func reward(amount: Float, source: EnergySource = .taskCompletion) {
        let effectiveAmount = amount * effectiveness(for: source)
        
        if energyPool < maxPoolCapacity {
            energyPool = min(maxPoolCapacity, energyPool + effectiveAmount)
        } else {
            taskEnergy = min(1.0, taskEnergy + effectiveAmount)
        }
    }
    
    /// 消耗能量
    mutating func consume(amount: Float, source: EnergySource = .taskExecution) {
        // 优先消耗 taskEnergy，然后是 energyPool，最后是 baseEnergy
        if taskEnergy >= amount {
            taskEnergy -= amount
        } else {
            let remaining = amount - taskEnergy
            taskEnergy = 0
            
            if energyPool >= remaining {
                energyPool -= remaining
            } else {
                let remaining2 = remaining - energyPool
                energyPool = 0
                baseEnergy = max(0, baseEnergy - remaining2)
            }
        }
    }
    
    /// 衰减（自然消耗）
    mutating func decay() {
        taskEnergy *= (1.0 - decayRate)
        energyPool *= (1.0 - decayRate * 0.5)  // 池子衰减更慢
    }
    
    /// 能量来源效率
    private func effectiveness(for source: EnergySource) -> Float {
        switch source {
        case .taskCompletion: return 1.0
        case .userFeedback: return 0.8
        case .rest: return 0.5
        case .externalReward: return 1.2
        }
    }
}

/// 能量来源
enum EnergySource {
    case taskCompletion      // 任务完成
    case userFeedback        // 用户反馈
    case rest                // 休息恢复
    case externalReward      // 外部奖励
}

// MARK: - 双能量系统

/// 双能量系统 - 物理能量 + 认知能量
struct DualEnergySystem {
    // 物理能量
    var physical: PhysicalEnergy = PhysicalEnergy()
    
    // 认知能量
    var cognitive: CognitiveEnergy = CognitiveEnergy()
    
    // 权重配置
    var physicalWeight: Float = 0.7
    var cognitiveWeight: Float = 0.3
    
    /// 总能量评分
    var totalScore: Float {
        physical.score * physicalWeight + cognitive.score * cognitiveWeight
    }
    
    /// 总能量级别
    var level: EnergyLevel {
        let s = totalScore
        if s < 0.1 { return .critical }
        if s < 0.3 { return .low }
        if s < 0.7 { return .moderate }
        if s < 0.9 { return .high }
        return .optimal
    }
    
    /// 能量状态描述
    var statusDescription: String {
        "\(physical.level.color) 物理:\(String(format: "%.1f", physical.score * 100))% " +
        "\(cognitive.level.color) 认知:\(String(format: "%.1f", cognitive.score * 100))% " +
        "总计:\(String(format: "%.1f", totalScore * 100))%"
    }
    
    /// 更新物理能量
    mutating func updatePhysical(battery: Float, temperature: TemperatureStatus,
                                  cpu: Float, memory: Float, network: NetworkStatus) {
        physical.batteryLevel = battery
        physical.temperatureStatus = temperature
        physical.cpuUsage = cpu
        physical.memoryUsage = memory
        physical.networkStatus = network
    }
    
    /// 更新认知能量
    mutating func updateCognitive(base: Float, task: Float, pool: Float) {
        cognitive.baseEnergy = base
        cognitive.taskEnergy = task
        cognitive.energyPool = pool
    }
    
    /// 自然衰减
    mutating func tick() {
        cognitive.decay()
    }
    
    /// 奖励
    mutating func reward(amount: Float, source: EnergySource = .taskCompletion) {
        cognitive.reward(amount: amount, source: source)
    }
    
    /// 消耗
    mutating func consume(amount: Float, source: EnergySource = .taskExecution) {
        cognitive.consume(amount: amount, source: source)
    }
    
    /// 能量平衡检查
    func checkBalance() -> EnergyBalanceStatus {
        let physicalScore = physical.score
        let cognitiveScore = cognitive.score
        
        let diff = abs(physicalScore - cognitiveScore)
        
        if diff < 0.1 {
            return .balanced
        } else if diff < 0.3 {
            return .slightlyImbalanced
        } else if diff < 0.5 {
            return .moderatelyImbalanced
        } else {
            return .severelyImbalanced
        }
    }
    
    /// 能量建议
    func energyAdvice() -> String {
        switch checkBalance() {
        case .balanced:
            return "能量平衡良好，保持当前状态"
        case .slightlyImbalanced:
            if physical.score < cognitive.score {
                return "物理能量偏低，建议休息或充电"
            } else {
                return "认知能量偏低，建议完成任务或获取反馈"
            }
        case .moderatelyImbalanced:
            if physical.score < cognitive.score {
                return "⚠️ 物理能量显著偏低，建议立即休息"
            } else {
                return "⚠️ 认知能量显著偏低，建议完成高价值任务"
            }
        case .severelyImbalanced:
            if physical.score < cognitive.score {
                return "🔴 物理能量危急，可能进入休眠模式"
            } else {
                return "🔴 认知能量危急，可能触发反思模式"
            }
        }
    }
}

/// 能量平衡状态
enum EnergyBalanceStatus {
    case balanced                    // 平衡
    case slightlyImbalanced          // 轻微失衡
    case moderatelyImbalanced        // 中度失衡
    case severelyImbalanced          // 严重失衡
}

// MARK: - 能量事件

/// 能量事件
enum EnergyEvent {
    case thresholdReached(EnergyLevel)   // 达到阈值
    case balanceWarning(EnergyBalanceStatus)  // 平衡警告
    case recoveryInitiated              // 开始恢复
    case criticalLow                  // 能量危急
}

// MARK: - 能量管理器

/// 能量管理器
final class EnergyManager: ObservableObject {
    
    @Published var energySystem: DualEnergySystem = DualEnergySystem()
    @Published var recentEvents: [EnergyEvent] = []
    
    private var timer: Timer?
    private let maxEventHistory = 50
    
    init() {
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    /// 开始监控
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.monitoringTick()
        }
    }
    
    /// 监控 tick
    private func monitoringTick() {
        energySystem.tick()
        
        // 检查阈值
        checkThresholds()
        
        // 检查平衡
        let balance = energySystem.checkBalance()
        if balance != .balanced {
            addEvent(.balanceWarning(balance))
        }
    }
    
    /// 检查阈值
    private func checkThresholds() {
        let level = energySystem.level
        
        // 记录临界状态
        if level == .critical {
            addEvent(.criticalLow)
        }
    }
    
    /// 添加事件
    private func addEvent(_ event: EnergyEvent) {
        recentEvents.append(event)
        if recentEvents.count > maxEventHistory {
            recentEvents.removeFirst()
        }
    }
    
    /// 更新物理能量（从硬件）
    func updatePhysical(battery: Float, temperature: TemperatureStatus,
                        cpu: Float, memory: Float, network: NetworkStatus) {
        energySystem.updatePhysical(battery: battery, temperature: temperature,
                                    cpu: cpu, memory: memory, network: network)
    }
    
    /// 更新认知能量
    func updateCognitive(base: Float, task: Float, pool: Float) {
        energySystem.updateCognitive(base: base, task: task, pool: pool)
    }
    
    /// 任务完成奖励
    func onTaskCompleted(effort: Float) {
        energySystem.reward(amount: effort * 0.1, source: .taskCompletion)
    }
    
    /// 用户正面反馈
    func onPositiveFeedback() {
        energySystem.reward(amount: 0.05, source: .userFeedback)
    }
    
    /// 用户负面反馈
    func onNegativeFeedback() {
        energySystem.consume(amount: 0.05, source: .taskExecution)
    }
    
    /// 休息恢复
    func onRest(duration: TimeInterval) {
        let recoveryAmount = Float(duration) / 3600.0 * 0.1  // 每小时恢复 10%
        energySystem.reward(amount: recoveryAmount, source: .rest)
    }
    
    /// 获取能量状态快照
    func getSnapshot() -> [String: Any] {
        return [
            "physical": [
                "score": energySystem.physical.score,
                "level": energySystem.physical.level.rawValue,
                "battery": energySystem.physical.batteryLevel
            ],
            "cognitive": [
                "score": energySystem.cognitive.score,
                "level": energySystem.cognitive.level.rawValue,
                "pool": energySystem.cognitive.energyPool
            ],
            "total": [
                "score": energySystem.totalScore,
                "level": energySystem.level.rawValue
            ],
            "balance": energySystem.checkBalance().rawValue,
            "advice": energySystem.energyAdvice()
        ]
    }
}

// MARK: - 扩展

extension EnergyLevel: CustomStringConvertible {
    var description: String {
        "\(self.color) \(self.description)"
    }
}

extension EnergyBalanceStatus: CustomStringConvertible {
    var description: String {
        switch self {
        case .balanced: return "平衡"
        case .slightlyImbalanced: return "轻微失衡"
        case .moderatelyImbalanced: return "中度失衡"
        case .severelyImbalanced: return "严重失衡"
        }
    }
}
