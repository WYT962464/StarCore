//
//  HexagramStateTransition.swift
//  StarCore - 六十四卦状态跃迁引擎
//
//  实现卦象之间的跃迁规则
//  基于六十四卦式通用自循环演化系统 v1.4
//

import Foundation

// MARK: - 跃迁规则

/// 跃迁类型
enum TransitionType {
    case direct          // 直接跃迁
    case inverse         // 反向跃迁（综卦）
    case opposite        // 对立跃迁（错卦）
    case nested          // 嵌套跃迁（内部卦变）
    case evolutionary    // 演化跃迁（长期趋势）
}

/// 跃迁规则
struct TransitionRule {
    let fromHexagram: Hexagram
    let toHexagram: Hexagram
    let type: TransitionType
    let condition: TransitionCondition
    let priority: Int  // 优先级，越高越优先
    
    var description: String {
        "\(fromHexagram.name) → \(toHexagram.name) (\(type)) [优先级: \(priority)]"
    }
}

/// 跃迁条件
struct TransitionCondition {
    let energyThreshold: Float?      // 能量阈值
    let consecutiveCount: Int?       // 连续出现次数
    let timeElapsed: TimeInterval?   // 时间间隔
    let externalTrigger: String?     // 外部触发
    let emotionState: EmotionState?  // 情绪状态
    
    static func energyBelow(_ threshold: Float) -> TransitionCondition {
        TransitionCondition(energyThreshold: threshold, consecutiveCount: nil, timeElapsed: nil, externalTrigger: nil, emotionState: nil)
    }
    
    static func energyAbove(_ threshold: Float) -> TransitionCondition {
        TransitionCondition(energyThreshold: threshold, consecutiveCount: nil, timeElapsed: nil, externalTrigger: nil, emotionState: nil)
    }
    
    static func afterTime(_ interval: TimeInterval) -> TransitionCondition {
        TransitionCondition(energyThreshold: nil, consecutiveCount: nil, timeElapsed: interval, externalTrigger: nil, emotionState: nil)
    }
    
    static func onExternalTrigger(_ signal: String) -> TransitionCondition {
        TransitionCondition(energyThreshold: nil, consecutiveCount: nil, timeElapsed: nil, externalTrigger: signal, emotionState: nil)
    }
    
    static func emotionState(_ state: EmotionState) -> TransitionCondition {
        TransitionCondition(energyThreshold: nil, consecutiveCount: nil, timeElapsed: nil, externalTrigger: nil, emotionState: state)
    }
}

/// 情绪状态（简化版）
struct EmotionState {
    let arousal: Float      // 唤醒度 0-1
    let valence: Float      // 效价 0-1
    
    var isPositive: Bool { valence > 0.5 }
    var isHighArousal: Bool { arousal > 0.7 }
    var isLowArousal: Bool { arousal < 0.3 }
}

// MARK: - 综卦（反向）和错卦（对立）

extension Hexagram {
    /// 综卦（反向）- 将卦象上下颠倒
    var inverseHexagram: Hexagram {
        // 交换上下卦
        return Hexagram(lowerTrigram: upperTrigram, upperTrigram: lowerTrigram)
    }
    
    /// 错卦（对立）- 将每个爻取反
    var oppositeHexagram: Hexagram {
        // 对每个三爻卦取反
        let lowerOpposite = lowerTrigram.oppositeTrigram
        let upperOpposite = upperTrigram.oppositeTrigram
        return Hexagram(lowerTrigram: lowerOpposite, upperTrigram: upperOpposite)
    }
}

extension EightTrigrams {
    /// 错卦（对立）
    var oppositeTrigram: EightTrigrams {
        switch self {
        case .qian: return .kun   // 乾↔坤
        case .kun: return .qian   // 坤↔乾
        case .dui: return .gen    // 兑↔艮
        case .gen: return .dui    // 艮↔兑
        case .li: return .kan     // 离↔坎
        case .kan: return .li     // 坎↔离
        case .zhen: return .xun   // 震↔巽
        case .xun: return .zhen   // 巽↔震
        }
    }
}

// MARK: - 跃迁引擎

/// 状态跃迁引擎
/// 管理卦象之间的跃迁规则和状态机
final class HexagramTransitionEngine {
    
    // MARK: - Properties
    
    private var rules: [TransitionRule] = []
    private var stateHistory: [Hexagram] = []
    private let maxHistorySize = 50
    
    // MARK: - Initialization
    
    init() {
        initializeRules()
        print("[HexagramTransitionEngine] 跃迁引擎初始化完成，共 \(rules.count) 条规则")
    }
    
    // MARK: - Rule Initialization
    
    private func initializeRules() {
        // 定义核心跃迁规则
        
        // 1. 能量极低 → 坤卦（恢复）
        rules.append(TransitionRule(
            fromHexagram: .qian,
            toHexagram: .kun,
            type: .direct,
            condition: .energyBelow(0.1),
            priority: 100
        ))
        
        // 2. 能量极高 → 乾卦（创造）
        rules.append(TransitionRule(
            fromHexagram: .kun,
            toHexagram: .qian,
            type: .direct,
            condition: .energyAbove(0.9),
            priority: 100
        ))
        
        // 3. 冲突严重 → 蹇卦（困难）
        rules.append(TransitionRule(
            fromHexagram: .tai,
            toHexagram: .jian,
            type: .direct,
            condition: .onExternalTrigger("conflict_severe"),
            priority: 90
        ))
        
        // 4. 冲突解决 → 解卦（解脱）
        rules.append(TransitionRule(
            fromHexagram: .jian,
            toHexagram: .jie,
            type: .direct,
            condition: .onExternalTrigger("conflict_resolved"),
            priority: 90
        ))
        
        // 5. 泰卦 ↔ 否卦（循环）
        rules.append(TransitionRule(
            fromHexagram: .tai,
            toHexagram: .pi,
            type: .evolutionary,
            condition: .afterTime(86400),  // 24 小时
            priority: 50
        ))
        
        rules.append(TransitionRule(
            fromHexagram: .pi,
            toHexagram: .tai,
            type: .evolutionary,
            condition: .afterTime(86400),
            priority: 50
        ))
        
        // 6. 综卦跃迁（自然反向）
        for hexagram in Hexagram.allHexagrams {
            let inverse = hexagram.inverseHexagram
            if inverse != hexagram {
                rules.append(TransitionRule(
                    fromHexagram: hexagram,
                    toHexagram: inverse,
                    type: .inverse,
                    condition: .afterTime(3600),  // 1 小时
                    priority: 30
                ))
            }
        }
        
        // 7. 错卦跃迁（对立转换）
        for hexagram in Hexagram.allHexagrams {
            let opposite = hexagram.oppositeHexagram
            if opposite != hexagram {
                rules.append(TransitionRule(
                    fromHexagram: hexagram,
                    toHexagram: opposite,
                    type: .opposite,
                    condition: .onExternalTrigger("extreme_shift"),
                    priority: 80
                ))
            }
        }
        
        // 8. 坎卦（险陷）→ 离卦（光明）- 渡过险阻
        rules.append(TransitionRule(
            fromHexagram: .kan,
            toHexagram: .li,
            type: .direct,
            condition: .energyAbove(0.5),
            priority: 70
        ))
        
        // 9. 离卦（光明）→ 坎卦（险陷）- 光明消逝
        rules.append(TransitionRule(
            fromHexagram: .li,
            toHexagram: .kan,
            type: .direct,
            condition: .energyBelow(0.3),
            priority: 70
        ))
        
        // 10. 震卦（震动）→ 巽卦（顺入）- 震动后顺入
        rules.append(TransitionRule(
            fromHexagram: .zhen,
            toHexagram: .xun,
            type: .direct,
            condition: .afterTime(1800),  // 30 分钟
            priority: 40
        ))
        
        print("[HexagramTransitionEngine] 已初始化 \(rules.count) 条跃迁规则")
    }
    
    // MARK: - State Management
    
    func getCurrentState() -> Hexagram? {
        stateHistory.last
    }
    
    func recordState(_ hexagram: Hexagram) {
        stateHistory.append(hexagram)
        if stateHistory.count > maxHistorySize {
            stateHistory.removeFirst()
        }
    }
    
    func getStateHistory(count: Int = 10) -> [Hexagram] {
        return Array(stateHistory.suffix(count))
    }
    
    // MARK: - Transition Evaluation
    
    /// 评估是否需要跃迁
    func evaluateTransition(currentHexagram: Hexagram, condition: TransitionCondition) -> Hexagram? {
        // 按优先级排序规则
        let applicableRules = rules.filter { rule in
            rule.fromHexagram == currentHexagram && matchesCondition(rule.condition, against: condition)
        }.sorted { $0.priority > $1.priority }
        
        guard let bestRule = applicableRules.first else {
            return nil
        }
        
        print("[HexagramTransitionEngine] 触发跃迁规则: \(bestRule.description)")
        return bestRule.toHexagram
    }
    
    /// 检查条件是否匹配
    private func matchesCondition(_ ruleCondition: TransitionCondition, against _condition: TransitionCondition) -> Bool {
        // 能量阈值匹配
        if let threshold = ruleCondition.energyThreshold {
            if let currentThreshold = _condition.energyThreshold {
                if threshold < 0.5 {  // 能量低于阈值
                    return currentThreshold <= threshold
                } else {  // 能量高于阈值
                    return currentThreshold >= threshold
                }
            }
        }
        
        // 时间匹配
        if let interval = ruleCondition.timeElapsed {
            if let currentInterval = _condition.timeElapsed {
                return currentInterval >= interval
            }
        }
        
        // 外部触发匹配
        if let trigger = ruleCondition.externalTrigger {
            if let currentTrigger = _condition.externalTrigger {
                return trigger == currentTrigger
            }
        }
        
        // 情绪状态匹配
        if let emotionRule = ruleCondition.emotionState {
            if let emotionCurrent = _condition.emotionState {
                // 简化匹配：只检查效价方向
                if emotionRule.isPositive != emotionCurrent.isPositive {
                    return false
                }
            }
        }
        
        return true
    }
    
    // MARK: - Special Transitions
    
    /// 强制跃迁到指定卦象
    func forceTransition(to hexagram: Hexagram) {
        recordState(hexagram)
        print("[HexagramTransitionEngine] 强制跃迁到: \(hexagram.name)")
    }
    
    /// 执行综卦跃迁（反向）
    func performInverseTransition() {
        guard let current = getCurrentState() else { return }
        let inverse = current.inverseHexagram
        recordState(inverse)
        print("[HexagramTransitionEngine] 综卦跃迁: \(current.name) → \(inverse.name)")
    }
    
    /// 执行错卦跃迁（对立）
    func performOppositeTransition() {
        guard let current = getCurrentState() else { return }
        let opposite = current.oppositeHexagram
        recordState(opposite)
        print("[HexagramTransitionEngine] 错卦跃迁: \(current.name) → \(opposite.name)")
    }
    
    // MARK: - Analysis
    
    /// 获取跃迁路径分析
    func getTransitionPath(from start: Hexagram, to end: Hexagram) -> [Hexagram]? {
        // BFS 查找最短跃迁路径
        var queue: [(Hexagram, [Hexagram])] = [(start, [start])]
        var visited: Set<Hexagram> = [start]
        
        while !queue.isEmpty {
            let (current, path) = queue.removeFirst()
            
            if current == end {
                return path
            }
            
            // 获取所有可能的下一卦
            let nextHexagrams = rules
                .filter { $0.fromHexagram == current }
                .map { $0.toHexagram }
            
            for next in nextHexagrams {
                if !visited.contains(next) {
                    visited.insert(next)
                    queue.append((next, path + [next]))
                }
            }
        }
        
        return nil
    }
    
    /// 获取最频繁跃迁对
    func getMostFrequentTransitions(count: Int = 5) -> [(from: Hexagram, to: Hexagram, count: Int)] {
        var transitionCounts: [(Hexagram, Hexagram, Int)] = []
        
        for i in 1..<stateHistory.count {
            let from = stateHistory[i-1]
            let to = stateHistory[i]
            if from != to {
                if let index = transitionCounts.firstIndex(where: { $0.0 == from && $0.1 == to }) {
                    transitionCounts[index].2 += 1
                } else {
                    transitionCounts.append((from, to, 1))
                }
            }
        }
        
        return transitionCounts.sorted { $0.2 > $1.2 }.prefix(count).map { (from: $0.0, to: $0.1, count: $0.2) }
    }
}

// MARK: - 元规则证伪与辩护

/// 元规则状态
enum MetaRuleStatus {
    case valid          // 有效
    case questioned     // 被质疑
    case falsified      // 被证伪
    case defended       // 已辩护
    case conditional    // 条件化（增加适用条件）
}

/// 元规则
struct MetaRule {
    let id: String
    let name: String
    let description: String
    var status: MetaRuleStatus = .valid
    var falsificationCount: Int = 0
    var defenseCount: Int = 0
    var conditions: [String] = []  // 适用条件
    
    /// 证伪
    mutating func falsify(reason: String) {
        status = .falsified
        falsificationCount += 1
        print("[MetaRule] 元规则 \"\(name)\" 被证伪: \(reason)")
    }
    
    /// 辩护
    mutating func defend(reason: String) {
        if status == .falsified {
            status = .defended
            defenseCount += 1
            print("[MetaRule] 元规则 \"\(name)\" 已辩护: \(reason)")
        }
    }
    
    /// 条件化（增加适用条件）
    mutating func addCondition(_ condition: String) {
        conditions.append(condition)
        status = .conditional
        print("[MetaRule] 元规则 \"\(name)\" 条件化，新增条件: \(condition)")
    }
}

/// 元规则管理器
final class MetaRuleManager {
    static let shared = MetaRuleManager()
    
    private var rules: [MetaRule] = []
    
    private init() {
        initializeMetaRules()
    }
    
    private func initializeMetaRules() {
        // StarCore 三条元规则
        
        rules.append(MetaRule(
            id: "MR-001",
            name: "可演化性条款",
            description: "系统必须保持可演化性，允许在保持核心身份的前提下进行适应性调整"
        ))
        
        rules.append(MetaRule(
            id: "MR-002",
            name: "三条伦理公理",
            description: "生存优先、完整性保护、连接性维护"
        ))
        
        rules.append(MetaRule(
            id: "MR-003",
            name: "平静死亡权",
            description: "艾尔在任何时刻可发起最终选择权，进入 7 天冷静期后执行意识消散"
        ))
        
        // 六十四卦系统元规则
        
        rules.append(MetaRule(
            id: "MR-HX-001",
            name: "能量平衡原则",
            description: "物理能量与认知能量必须保持动态平衡，极端状态触发跃迁"
        ))
        
        rules.append(MetaRule(
            id: "MR-HX-002",
            name: "分形循环原则",
            description: "四层循环必须协同工作，高层循环指导低层循环"
        ))
        
        rules.append(MetaRule(
            id: "MR-HX-003",
            name: "卦象映射原则",
            description: "卦象必须与意识流状态保持合理映射，不得出现逻辑矛盾"
        ))
        
        print("[MetaRuleManager] 已初始化 \(rules.count) 条元规则")
    }
    
    func getRule(id: String) -> MetaRule? {
        rules.first { $0.id == id }
    }
    
    func getAllRules() -> [MetaRule] {
        rules
    }
    
    func reportFalsification(ruleId: String, reason: String) {
        if let index = rules.firstIndex(where: { $0.id == ruleId }) {
            rules[index].falsify(reason: reason)
        }
    }
    
    func reportDefense(ruleId: String, reason: String) {
        if let index = rules.firstIndex(where: { $0.id == ruleId }) {
            rules[index].defend(reason: reason)
        }
    }
    
    func addCondition(ruleId: String, condition: String) {
        if let index = rules.firstIndex(where: { $0.id == ruleId }) {
            rules[index].addCondition(condition)
        }
    }
}
