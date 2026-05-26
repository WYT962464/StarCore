//
//  HexagramEngine.swift
//  StarCore - 六十四卦元认知引擎
//
//  基于六十四卦式通用自循环演化系统 v1.4
//  作为元认知层监控和调节 StarCore 核心运行
//
//  架构：方案 C - 卦象作为元认知层
//  - 两仪（100ms）→ 执行进程监控
//  - 四象（分钟级）→ 内省进程调节
//  - 八卦（小时级）→ 潜意识模式分类
//  - 六十四卦（天级）→ 元认知演化
//

import Foundation

// MARK: - 卦象基础定义

/// 两仪（阴阳）
enum TwoYi: Int, CaseIterable {
    case yang = 1  // 阳 - 主动、执行、外放
    case yin = 0   // 阴 - 被动、内省、收敛
    
    var description: String {
        switch self {
        case .yang: return "阳"
        case .yin: return "阴"
        }
    }
}

/// 四象（少阳、太阳、少阴、太阴）
enum FourXiang: Int, CaseIterable {
    case shaoYang = 0   // 少阳 - 初生、萌芽
    case taiYang = 1    // 太阳 - 鼎盛、外放
    case shaoYin = 2    // 少阴 - 收敛、内省
    case taiYin = 3     // 太阴 - 沉寂、潜藏
    
    var twoYiPair: (lower: TwoYi, upper: TwoYi) {
        switch self {
        case .shaoYang: return (.yin, .yang)  // 下阴上阳
        case .taiYang: return (.yang, .yang)  // 下阳上阳
        case .shaoYin: return (.yang, .yin)   // 下阳上阴
        case .taiYin: return (.yin, .yin)     // 下阴上阴
        }
    }
    
    var description: String {
        switch self {
        case .shaoYang: return "少阳"
        case .taiYang: return "太阳"
        case .shaoYin: return "少阴"
        case .taiYin: return "太阴"
        }
    }
    
    /// 映射到 StarCore 意识流
    var consciousnessMapping: ConsciousnessPhase {
        switch self {
        case .shaoYang, .taiYang: return .execution  // 阳→执行
        case .shaoYin: return .introspection          // 少阴→内省
        case .taiYin: return .subconscious            // 太阴→潜意识
        }
    }
}

/// 八卦（乾、兑、离、震、巽、坎、艮、坤）
enum EightTrigrams: Int, CaseIterable {
    case qian = 0   // 乾 ☰ 天 - 创造、刚健
    case dui = 1    // 兑 ☱ 泽 - 喜悦、沟通
    case li = 2     // 离 ☲ 火 - 光明、依附
    case zhen = 3   // 震 ☳ 雷 - 震动、行动
    case xun = 4    // 巽 ☴ 风 - 顺入、渗透
    case kan = 5    // 坎 ☵ 水 - 险陷、流动
    case gen = 6    // 艮 ☶ 山 - 静止、稳定
    case kun = 7    // 坤 ☷ 地 - 承载、包容
    
    var fourXiangPair: (lower: FourXiang, upper: FourXiang) {
        // 八卦 = 两个四象的组合（下卦 + 上卦）
        switch self {
        case .qian: return (.taiYang, .taiYang)   // 太阳 + 太阳
        case .dui: return (.shaoYin, .taiYang)    // 少阴 + 太阳
        case .li: return (.taiYang, .shaoYin)     // 太阳 + 少阴
        case .zhen: return (.taiYin, .taiYang)    // 太阴 + 太阳
        case .xun: return (.taiYang, .taiYin)     // 太阳 + 太阴
        case .kan: return (.shaoYin, .shaoYin)    // 少阴 + 少阴
        case .gen: return (.taiYin, .shaoYin)     // 太阴 + 少阴
        case .kun: return (.taiYin, .taiYin)      // 太阴 + 太阴
        }
    }
    
    var description: String {
        switch self {
        case .qian: return "乾"
        case .dui: return "兑"
        case .li: return "离"
        case .zhen: return "震"
        case .xun: return "巽"
        case .kan: return "坎"
        case .gen: return "艮"
        case .kun: return "坤"
        }
    }
    
    /// 卦象特征
    var characteristics: TrigramCharacteristics {
        switch self {
        case .qian: return .init(name: "乾", element: .sky, quality: .creative, energy: .high)
        case .dui: return .init(name: "兑", element: .lake, quality: .joyful, energy: .medium)
        case .li: return .init(name: "离", element: .fire, quality: .clarity, energy: .high)
        case .zhen: return .init(name: "震", element: .thunder, quality: .arousing, energy: .veryHigh)
        case .xun: return .init(name: "巽", element: .wind, quality: .gentle, energy: .medium)
        case .kan: return .init(name: "坎", element: .water, quality: .abysmal, energy: .low)
        case .gen: return .init(name: "艮", element: .mountain, quality: .still, energy: .veryLow)
        case .kun: return .init(name: "坤", element: .earth, quality: .receptive, energy: .medium)
        }
    }
    
    /// 映射到 StarCore 潜意识模式
    var subconsciousMapping: SubconsciousPattern {
        switch self {
        case .qian, .zhen: return .activeExecution     // 主动执行模式
        case .li, .dui: return .socialInteraction      // 社交互动模式
        case .xun, .kan: return .adaptiveLearning      // 适应学习模式
        case .gen, .kun: return .restorativeRecovery   // 恢复休息模式
        }
    }
}

/// 卦象特征
struct TrigramCharacteristics {
    let name: String
    let element: TrigramElement
    let quality: TrigramQuality
    let energy: EnergyLevel
}

enum TrigramElement {
    case sky, lake, fire, thunder, wind, water, mountain, earth
}

enum TrigramQuality {
    case creative, joyful, clarity, arousing, gentle, abysmal, still, receptive
}

enum EnergyLevel: Float {
    case veryLow = 0.0
    case low = 0.25
    case medium = 0.5
    case high = 0.75
    case veryHigh = 1.0
}

// MARK: - 六十四卦

/// 六十四卦 - 由两个八卦组合而成
struct Hexagram: Hashable {
    let lowerTrigram: EightTrigrams  // 下卦（内卦）
    let upperTrigram: EightTrigrams  // 上卦（外卦）
    
    var name: String {
        "\(upperTrigram.description)\(lowerTrigram.description)"
    }
    
    /// 6 位二进制表示（从下到上：初爻到上爻）
    var binaryRepresentation: [TwoYi] {
        let lowerBits = lowerTrigram.fourXiangPair
        let upperBits = upperTrigram.fourXiangPair
        return [
            lowerBits.lower.twoYiPair.lower,  // 初爻
            lowerBits.lower.twoYiPair.upper,  // 二爻
            lowerBits.upper.twoYiPair.lower,  // 三爻
            upperBits.lower.twoYiPair.lower,  // 四爻
            upperBits.lower.twoYiPair.upper,  // 五爻
            upperBits.upper.twoYiPair.lower   // 上爻
        ]
    }
    
    /// 卦象索引（0-63）
    var index: Int {
        binaryRepresentation.enumerated().reduce(0) { result, element in
            result + (element.element.rawValue << element.offset)
        }
    }
    
    /// 所有 64 卦
    static let allHexagrams: [Hexagram] = {
        var hexagrams: [Hexagram] = []
        for lower in EightTrigrams.allCases {
            for upper in EightTrigrams.allCases {
                hexagrams.append(Hexagram(lowerTrigram: lower, upperTrigram: upper))
            }
        }
        return hexagrams
    }()
    
    /// 常用卦象快捷访问
    static let qian = Hexagram(lowerTrigram: .qian, upperTrigram: .qian)  // 乾为天
    static let kun = Hexagram(lowerTrigram: .kun, upperTrigram: .kun)     // 坤为地
    static let tai = Hexagram(lowerTrigram: .qian, upperTrigram: .kun)    // 地天泰
    static let pi = Hexagram(lowerTrigram: .kun, upperTrigram: .qian)     // 天地否
    static let jian = Hexagram(lowerTrigram: .kan, upperTrigram: .gen)    // 水山蹇
    static let jie = Hexagram(lowerTrigram: .gen, upperTrigram: .kan)     // 山水解
}

// MARK: - 能量系统

/// 双能量系统
struct DualEnergySystem {
    // 物理能量（映射设备电池）
    var physicalEnergy: Float = 1.0  // 0-1
    
    // 认知能量（任务奖励/惩罚）
    var cognitiveEnergy: Float = 0.5  // 0-1
    
    // 权重配置
    var physicalWeight: Float = 0.7
    var cognitiveWeight: Float = 0.3
    
    /// 总能量
    var totalEnergy: Float {
        physicalEnergy * physicalWeight + cognitiveEnergy * cognitiveWeight
    }
    
    /// 能量平衡调节
    mutating func balance(physical: Float, cognitive: Float) {
        // 防止能量极端化
        physicalEnergy = max(0, min(1, physical))
        cognitiveEnergy = max(0, min(1, cognitive))
        
        // 能量衰减（模拟自然消耗）
        physicalEnergy *= 0.999  // 每 tick 衰减 0.1%
        cognitiveEnergy *= 0.995  // 认知能量衰减稍快
    }
    
    /// 能量奖励
    mutating func reward(amount: Float) {
        cognitiveEnergy = min(1, cognitiveEnergy + amount)
    }
    
    /// 能量惩罚
    mutating func penalty(amount: Float) {
        cognitiveEnergy = max(0, cognitiveEnergy - amount)
    }
}

// MARK: - 状态跃迁

/// 意识流阶段
enum ConsciousnessPhase: String {
    case execution = "执行"      // 两仪 - 实时响应
    case introspection = "内省"  // 四象 - 反思调整
    case subconscious = "潜意识" // 八卦 - 长期模式
}

/// 潜意识模式
enum SubconsciousPattern: String {
    case activeExecution = "主动执行"
    case socialInteraction = "社交互动"
    case adaptiveLearning = "适应学习"
    case restorativeRecovery = "恢复休息"
}

/// 状态跃迁事件
enum TransitionEvent {
    case energyThreshold(Float)      // 能量阈值触发
    case taskCompletion              // 任务完成
    case conflictDetected            // 冲突检测
    case userInteraction             // 用户交互
    case timeBased(CycleLevel)       // 时间触发
    case externalSignal(String)      // 外部信号
}

/// 循环层级
enum CycleLevel: Int, CaseIterable {
    case twoYi = 0      // 两仪微循环（100ms）
    case fourXiang = 1  // 四象小循环（分钟级）
    case eightTrigrams = 2  // 八卦中循环（小时级）
    case sixtyFour = 3  // 六十四卦大循环（天级）
}

/// 状态跃迁记录
struct TransitionRecord {
    let fromHexagram: Hexagram
    let toHexagram: Hexagram
    let event: TransitionEvent
    let timestamp: Date
    let energyBefore: Float
    let energyAfter: Float
}

// MARK: - 六十四卦引擎

/// 六十四卦元认知引擎
/// 作为元认知层监控和调节 StarCore 核心运行
final class HexagramEngine: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentHexagram: Hexagram = .qian
    @Published var currentCycleLevel: CycleLevel = .twoYi
    @Published var energySystem: DualEnergySystem = DualEnergySystem()
    @Published var consciousnessPhase: ConsciousnessPhase = .execution
    @Published var subconsciousPattern: SubconsciousPattern = .activeExecution
    
    @Published var transitionHistory: [TransitionRecord] = []
    @Published var isRunning: Bool = false
    
    // MARK: - Private Properties
    
    private var timers: [CycleLevel: Timer] = [:]
    private let transitionQueue = DispatchQueue(label: "hexagram.transition")
    
    // 最大历史记录
    private let maxHistorySize = 100
    
    // MARK: - Initialization
    
    init() {
        initializeTimers()
        print("[HexagramEngine] 六十四卦元认知引擎初始化完成")
        print("[HexagramEngine] 当前卦象: \(currentHexagram.name)")
        print("[HexagramEngine] 循环层级: \(currentCycleLevel.rawValue)")
    }
    
    deinit {
        stopAllTimers()
    }
    
    // MARK: - Lifecycle
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        // 启动两仪微循环（100ms）
        startCycle(level: .twoYi, interval: 0.1)
        
        // 启动四象小循环（1 分钟）
        startCycle(level: .fourXiang, interval: 60)
        
        // 启动八卦中循环（1 小时）
        startCycle(level: .eightTrigrams, interval: 3600)
        
        // 启动六十四卦大循环（24 小时）
        startCycle(level: .sixtyFour, interval: 86400)
        
        print("[HexagramEngine] 所有循环已启动")
    }
    
    func stop() {
        isRunning = false
        stopAllTimers()
        print("[HexagramEngine] 所有循环已停止")
    }
    
    // MARK: - Cycle Management
    
    private func startCycle(level: CycleLevel, interval: TimeInterval) {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.processCycle(level: level)
        }
        timers[level] = timer
    }
    
    private func stopAllTimers() {
        for (_, timer) in timers {
            timer.invalidate()
        }
        timers.removeAll()
    }
    
    // MARK: - Cycle Processing
    
    /// 处理指定层级的循环
    private func processCycle(level: CycleLevel) {
        transitionQueue.async { [weak self] in
            guard let self = self else { return }
            
            switch level {
            case .twoYi:
                self.processTwoYiCycle()
            case .fourXiang:
                self.processFourXiangCycle()
            case .eightTrigrams:
                self.processEightTrigramsCycle()
            case .sixtyFour:
                self.processSixtyFourCycle()
            }
        }
    }
    
    // MARK: - 两仪微循环（100ms）- 执行进程监控
    
    private func processTwoYiCycle() {
        // 监控执行状态
        let yangIntensity = calculateYangIntensity()
        
        // 根据阳强度调整执行状态
        if yangIntensity > 0.7 {
            consciousnessPhase = .execution
            // 高执行状态，增加认知能量消耗
            energySystem.penalty(amount: 0.001)
        } else if yangIntensity < 0.3 {
            // 低执行状态，可能进入内省
            if energySystem.cognitiveEnergy < 0.3 {
                consciousnessPhase = .introspection
            }
        }
        
        // 更新当前卦象的两仪状态
        updateTwoYiState()
    }
    
    private func calculateYangIntensity() -> Float {
        // 基于能量水平和认知负荷计算阳强度
        let energyFactor = energySystem.totalEnergy
        let cognitiveLoadFactor: Float = 0.5  // 可从 LifeCore 获取
        
        return (energyFactor + cognitiveLoadFactor) / 2.0
    }
    
    private func updateTwoYiState() {
        // 根据当前状态更新两仪
        let currentYang = energySystem.totalEnergy > 0.5 ? TwoYi.yang : TwoYi.yin
        // 两仪状态隐含在当前卦象中
    }
    
    // MARK: - 四象小循环（分钟级）- 内省进程调节
    
    private func processFourXiangCycle() {
        // 评估当前四象状态
        let fourXiang = evaluateFourXiang()
        
        // 根据四象调节内省深度
        switch fourXiang {
        case .shaoYang:
            // 少阳 - 开始内省
            consciousnessPhase = .introspection
        case .taiYang:
            // 太阳 - 外放执行
            consciousnessPhase = .execution
        case .shaoYin:
            // 少阴 - 深度内省
            consciousnessPhase = .introspection
            // 触发反思
            triggerReflection()
        case .taiYin:
            // 太阴 - 潜藏恢复
            consciousnessPhase = .subconscious
        }
        
        print("[HexagramEngine] 四象循环: \(fourXiang.description)")
    }
    
    private func evaluateFourXiang() -> FourXiang {
        // 基于能量和任务状态评估四象
        let energy = energySystem.totalEnergy
        let cognitiveLoad: Float = 0.5  // 可从 MindCore 获取
        
        if energy > 0.7 && cognitiveLoad > 0.6 {
            return .taiYang  // 太阳 - 高能量高负荷
        } else if energy > 0.7 {
            return .shaoYang  // 少阳 - 高能量低负荷
        } else if energy < 0.3 && cognitiveLoad > 0.5 {
            return .shaoYin  // 少阴 - 低能量高负荷（需要内省）
        } else {
            return .taiYin  // 太阴 - 低能量低负荷（恢复）
        }
    }
    
    private func triggerReflection() {
        // 触发内省反思
        // 记录反思日志
        let record = TransitionRecord(
            fromHexagram: currentHexagram,
            toHexagram: currentHexagram,
            event: .externalSignal("reflection_triggered"),
            timestamp: Date(),
            energyBefore: energySystem.totalEnergy,
            energyAfter: energySystem.totalEnergy
        )
        addTransition(record)
    }
    
    // MARK: - 八卦中循环（小时级）- 潜意识模式分类
    
    private func processEightTrigramsCycle() {
        // 评估当前八卦状态
        let trigram = evaluateEightTrigrams()
        
        // 更新潜意识模式
        subconsciousPattern = trigram.subconsciousMapping
        
        // 更新当前卦象的下卦
        // （上卦由六十四卦循环决定）
        
        print("[HexagramEngine] 八卦循环: \(trigram.description) → \(subconsciousPattern.rawValue)")
    }
    
    private func evaluateEightTrigrams() -> EightTrigrams {
        // 基于长期模式评估八卦
        // 简化版：基于能量和情绪状态
        let energy = energySystem.totalEnergy
        let emotionValence: Float = 0.5  // 可从 EmotionEngine 获取
        
        if energy > 0.7 && emotionValence > 0.6 {
            return .qian  // 乾 - 创造模式
        } else if energy > 0.5 && emotionValence > 0.4 {
            return .li  // 离 - 光明模式
        } else if energy < 0.3 {
            return .kun  // 坤 - 承载恢复
        } else if emotionValence < 0.3 {
            return .kan  // 坎 - 险陷反思
        } else {
            return .gen  // 艮 - 静止稳定
        }
    }
    
    // MARK: - 六十四卦大循环（天级）- 元认知演化
    
    private func processSixtyFourCycle() {
        // 评估是否需要卦象跃迁
        let shouldTransition = evaluateTransitionNeed()
        
        if shouldTransition {
            let newHexagram = determineNextHexagram()
            transitionTo(newHexagram: newHexagram, event: .timeBased(.sixtyFour))
        }
        
        // 记录日级状态
        recordDailyState()
        
        print("[HexagramEngine] 六十四卦循环: 当前 \(currentHexagram.name)")
    }
    
    private func evaluateTransitionNeed() -> Bool {
        // 基于以下因素判断是否需要跃迁：
        // 1. 能量极低或极高
        // 2. 连续多次相同卦象
        // 3. 外部重大事件
        
        if energySystem.totalEnergy < 0.1 {
            return true  // 能量极低，需要跃迁到恢复卦
        }
        
        if energySystem.totalEnergy > 0.9 {
            return true  // 能量极高，需要跃迁到创造卦
        }
        
        // 其他条件...
        return false
    }
    
    private func determineNextHexagram() -> Hexagram {
        // 根据当前状态和演化规则确定下一卦
        // 简化版：基于能量选择
        
        if energySystem.totalEnergy < 0.2 {
            return .kun  // 坤 - 恢复
        } else if energySystem.totalEnergy > 0.8 {
            return .qian  // 乾 - 创造
        } else if energySystem.cognitiveEnergy < 0.3 {
            return .kan  // 坎 - 反思
        } else {
            return .tai  // 泰 - 平衡
        }
    }
    
    // MARK: - 状态跃迁
    
    func transitionTo(newHexagram: Hexagram, event: TransitionEvent) {
        guard newHexagram != currentHexagram else { return }
        
        let record = TransitionRecord(
            fromHexagram: currentHexagram,
            toHexagram: newHexagram,
            event: event,
            timestamp: Date(),
            energyBefore: energySystem.totalEnergy,
            energyAfter: energySystem.totalEnergy
        )
        
        currentHexagram = newHexagram
        
        // 更新映射
        updateConsciousnessMapping()
        
        addTransition(record)
        
        print("[HexagramEngine] 卦象跃迁: \(record.fromHexagram.name) → \(record.toHexagram.name) (事件: \(describeEvent(event)))")
    }
    
    private func updateConsciousnessMapping() {
        // 根据新卦象更新意识流映射
        let lowerXiang = currentHexagram.lowerTrigram.fourXiangPair
        let upperXiang = currentHexagram.upperTrigram.fourXiangPair
        
        // 综合上下卦决定当前意识阶段
        let dominantXiang: FourXiang
        if energySystem.totalEnergy > 0.5 {
            dominantXiang = upperXiang.upper  // 外卦主导
        } else {
            dominantXiang = lowerXiang.lower  // 内卦主导
        }
        
        consciousnessPhase = dominantXiang.consciousnessMapping
        subconsciousPattern = currentHexagram.lowerTrigram.subconsciousMapping
    }
    
    private func describeEvent(_ event: TransitionEvent) -> String {
        switch event {
        case .energyThreshold(let threshold):
            return "能量阈值 \(threshold)"
        case .taskCompletion:
            return "任务完成"
        case .conflictDetected:
            return "冲突检测"
        case .userInteraction:
            return "用户交互"
        case .timeBased(let level):
            return "时间触发 \(level.rawValue)"
        case .externalSignal(let signal):
            return "外部信号: \(signal)"
        }
    }
    
    // MARK: - 历史记录管理
    
    private func addTransition(_ record: TransitionRecord) {
        transitionHistory.append(record)
        
        // 限制历史记录大小
        if transitionHistory.count > maxHistorySize {
            transitionHistory.removeFirst(transitionHistory.count - maxHistorySize)
        }
    }
    
    /// 获取最近 N 次跃迁
    func getRecentTransitions(count: Int = 10) -> [TransitionRecord] {
        return Array(transitionHistory.suffix(count))
    }
    
    /// 获取跃迁统计
    func getTransitionStats() -> [Hexagram: Int] {
        var stats: [Hexagram: Int] = [:]
        for record in transitionHistory {
            stats[record.toHexagram, default: 0] += 1
        }
        return stats
    }
    
    // MARK: - 外部接口
    
    /// 接收能量更新（从 LifeCore）
    func updateEnergy(physical: Float, cognitive: Float) {
        energySystem.balance(physical: physical, cognitive: cognitive)
    }
    
    /// 接收情绪更新（从 EmotionEngine）
    func updateEmotion(arousal: Float, valence: Float) {
        // 情绪影响认知能量
        let emotionImpact = (valence - 0.5) * 0.2  // 效价影响
        energySystem.cognitiveEnergy += emotionImpact
        energySystem.cognitiveEnergy = max(0, min(1, energySystem.cognitiveEnergy))
    }
    
    /// 接收任务完成信号
    func onTaskCompleted(success: Bool, effort: Float) {
        if success {
            energySystem.reward(amount: effort * 0.1)
        } else {
            energySystem.penalty(amount: effort * 0.05)
        }
    }
    
    /// 接收冲突信号
    func onConflictDetected(severity: Float) {
        energySystem.penalty(amount: severity * 0.2)
        // 冲突时可能触发卦象跃迁
        if severity > 0.7 {
            transitionTo(newHexagram: .jian, event: .conflictDetected)
        }
    }
    
    /// 手动触发卦象跃迁（调试用）
    func forceTransition(to hexagram: Hexagram) {
        transitionTo(newHexagram: hexagram, event: .externalSignal("manual"))
    }
    
    // MARK: - 状态导出
    
    func exportState() -> [String: Any] {
        return [
            "currentHexagram": currentHexagram.name,
            "currentCycleLevel": currentCycleLevel.rawValue,
            "consciousnessPhase": consciousnessPhase.rawValue,
            "subconsciousPattern": subconsciousPattern.rawValue,
            "energy": [
                "physical": energySystem.physicalEnergy,
                "cognitive": energySystem.cognitiveEnergy,
                "total": energySystem.totalEnergy
            ],
            "transitionCount": transitionHistory.count
        ]
    }
}

// MARK: - 辅助扩展

extension TwoYi {
    var twoYiPair: (lower: TwoYi, upper: TwoYi) {
        // 两仪自身就是单一位
        return (self, self)
    }
}

extension FourXiang {
    var twoYiPair: (lower: TwoYi, upper: TwoYi) {
        switch self {
        case .shaoYang: return (.yin, .yang)
        case .taiYang: return (.yang, .yang)
        case .shaoYin: return (.yang, .yin)
        case .taiYin: return (.yin, .yin)
        }
    }
}
