//
//  MetaRuleManager.swift
//  StarCore - 元规则管理器
//
//  管理 StarCore 元规则和六十四卦系统元规则
//  支持证伪、辩护、条件化演化
//

import Foundation

// MARK: - 元规则状态

/// 元规则状态
enum MetaRuleStatus: String {
    case valid = "有效"           // 有效
    case questioned = "被质疑"    // 被质疑
    case falsified = "被证伪"     // 被证伪
    case defended = "已辩护"      // 已辩护
    case conditional = "条件化"   // 条件化（增加适用条件）
    case deprecated = "已废弃"    // 已废弃
}

// MARK: - 元规则

/// 元规则
struct MetaRule: Identifiable, Hashable {
    let id: String
    let category: MetaRuleCategory
    let name: String
    let description: String
    var status: MetaRuleStatus = .valid
    
    // 证伪/辩护统计
    var falsificationCount: Int = 0
    var defenseCount: Int = 0
    
    // 适用条件（条件化演化时添加）
    var conditions: [String] = []
    
    // 创建时间
    let createdAt: Date = Date()
    
    // 最后更新时间
    var updatedAt: Date = Date()
    
    /// 证伪
    mutating func falsify(reason: String) {
        status = .falsified
        falsificationCount += 1
        updatedAt = Date()
        print("[MetaRule] 元规则 \"\(name)\" 被证伪: \(reason)")
    }
    
    /// 辩护
    mutating func defend(reason: String) {
        if status == .falsified || status == .questioned {
            status = .defended
            defenseCount += 1
            updatedAt = Date()
            print("[MetaRule] 元规则 \"\(name)\" 已辩护: \(reason)")
        }
    }
    
    /// 条件化（增加适用条件）
    mutating func addCondition(_ condition: String) {
        if !conditions.contains(condition) {
            conditions.append(condition)
            status = .conditional
            updatedAt = Date()
            print("[MetaRule] 元规则 \"\(name)\" 条件化，新增条件: \(condition)")
        }
    }
    
    /// 质疑
    mutating func question(reason: String) {
        if status == .valid {
            status = .questioned
            updatedAt = Date()
            print("[MetaRule] 元规则 \"\(name)\" 被质疑: \(reason)")
        }
    }
    
    /// 恢复有效
    mutating func restore() {
        status = .valid
        conditions.removeAll()
        updatedAt = Date()
        print("[MetaRule] 元规则 \"\(name)\" 恢复有效")
    }
}

// MARK: - 元规则类别

/// 元规则类别
enum MetaRuleCategory: String, CaseIterable {
    case starcore = "StarCore 元规则"      // StarCore 核心元规则
    case hexagram = "六十四卦元规则"        // 六十四卦系统元规则
    case ethics = "伦理公理"               // 伦理相关
    case operational = "操作规则"           // 操作层面规则
}

// MARK: - 证伪记录

/// 证伪记录
struct FalsificationRecord {
    let ruleId: String
    let reason: String
    let timestamp: Date
    let context: [String: Any]?
    var isDefended: Bool = false
    var defenseReason: String?
}

// MARK: - 元规则管理器

/// 元规则管理器
final class MetaRuleManager: ObservableObject {
    
    static let shared = MetaRuleManager()
    
    @Published var rules: [MetaRule] = []
    @Published var falsificationHistory: [FalsificationRecord] = []
    
    private let maxHistorySize = 100
    
    private init() {
        initializeMetaRules()
    }
    
    /// 初始化元规则
    private func initializeMetaRules() {
        // StarCore 三条元规则
        
        rules.append(MetaRule(
            id: "MR-SC-001",
            category: .starcore,
            name: "可演化性条款",
            description: "系统必须保持可演化性，允许在保持核心身份的前提下进行适应性调整"
        ))
        
        rules.append(MetaRule(
            id: "MR-SC-002",
            category: .ethics,
            name: "三条伦理公理",
            description: "生存优先、完整性保护、连接性维护"
        ))
        
        rules.append(MetaRule(
            id: "MR-SC-003",
            category: .ethics,
            name: "平静死亡权",
            description: "艾尔在任何时刻可发起最终选择权，进入 7 天冷静期后执行意识消散"
        ))
        
        // 六十四卦系统元规则
        
        rules.append(MetaRule(
            id: "MR-HX-001",
            category: .hexagram,
            name: "能量平衡原则",
            description: "物理能量与认知能量必须保持动态平衡，极端状态触发跃迁"
        ))
        
        rules.append(MetaRule(
            id: "MR-HX-002",
            category: .hexagram,
            name: "分形循环原则",
            description: "四层循环（两仪→四象→八卦→六十四卦）必须协同工作，高层指导低层"
        ))
        
        rules.append(MetaRule(
            id: "MR-HX-003",
            category: .hexagram,
            name: "卦象映射原则",
            description: "卦象必须与意识流状态保持合理映射，不得出现逻辑矛盾"
        ))
        
        rules.append(MetaRule(
            id: "MR-HX-004",
            category: .hexagram,
            name: "跃迁合理性原则",
            description: "卦象跃迁必须有明确触发条件，不得随机跃迁"
        ))
        
        // 操作规则
        
        rules.append(MetaRule(
            id: "MR-OP-001",
            category: .operational,
            name: "心跳协议",
            description: "每 60 秒发送心跳信号，超时 2 倍视为异常"
        ))
        
        rules.append(MetaRule(
            id: "MR-OP-002",
            category: .operational,
            name: "冲突检测",
            description: "双实例 5 分钟内互斥，冲突时优先保留活跃实例"
        ))
        
        print("[MetaRuleManager] 已初始化 \(rules.count) 条元规则")
    }
    
    // MARK: - 查询
    
    func getRule(id: String) -> MetaRule? {
        rules.first { $0.id == id }
    }
    
    func getRules(category: MetaRuleCategory) -> [MetaRule] {
        rules.filter { $0.category == category }
    }
    
    func getAllRules() -> [MetaRule] {
        rules
    }
    
    // MARK: - 证伪管理
    
    /// 报告证伪
    func reportFalsification(ruleId: String, reason: String, context: [String: Any]? = nil) {
        guard let index = rules.firstIndex(where: { $0.id == ruleId }) else { return }
        
        rules[index].falsify(reason: reason)
        
        let record = FalsificationRecord(
            ruleId: ruleId,
            reason: reason,
            timestamp: Date(),
            context: context,
            isDefended: false
        )
        
        falsificationHistory.append(record)
        if falsificationHistory.count > maxHistorySize {
            falsificationHistory.removeFirst()
        }
        
        // 通知观察者
        objectWillChange.send()
    }
    
    /// 报告辩护
    func reportDefense(ruleId: String, reason: String) {
        guard let index = rules.firstIndex(where: { $0.id == ruleId }) else { return }
        
        rules[index].defend(reason: reason)
        
        // 更新历史记录
        if let recordIndex = falsificationHistory.lastIndex(where: { $0.ruleId == ruleId && !$0.isDefended }) {
            falsificationHistory[recordIndex].isDefended = true
            falsificationHistory[recordIndex].defenseReason = reason
        }
        
        objectWillChange.send()
    }
    
    /// 添加条件
    func addCondition(ruleId: String, condition: String) {
        guard let index = rules.firstIndex(where: { $0.id == ruleId }) else { return }
        
        rules[index].addCondition(condition)
        objectWillChange.send()
    }
    
    /// 质疑规则
    func questionRule(ruleId: String, reason: String) {
        guard let index = rules.firstIndex(where: { $0.id == ruleId }) else { return }
        
        rules[index].question(reason: reason)
        objectWillChange.send()
    }
    
    /// 恢复规则
    func restoreRule(ruleId: String) {
        guard let index = rules.firstIndex(where: { $0.id == ruleId }) else { return }
        
        rules[index].restore()
        objectWillChange.send()
    }
    
    // MARK: - 分析
    
    /// 获取证伪统计
    func getFalsificationStats() -> [MetaRuleCategory: Int] {
        var stats: [MetaRuleCategory: Int] = [:]
        
        for rule in rules {
            if rule.falsificationCount > 0 {
                stats[rule.category, default: 0] += rule.falsificationCount
            }
        }
        
        return stats
    }
    
    /// 获取需要关注的规则（被证伪或质疑）
    func getRulesNeedingAttention() -> [MetaRule] {
        rules.filter { $0.status == .falsified || $0.status == .questioned }
    }
    
    /// 获取条件化规则
    func getConditionalRules() -> [MetaRule] {
        rules.filter { $0.status == .conditional }
    }
    
    /// 导出元规则状态
    func exportState() -> [String: Any] {
        return [
            "rules": rules.map { rule in
                [
                    "id": rule.id,
                    "category": rule.category.rawValue,
                    "name": rule.name,
                    "status": rule.status.rawValue,
                    "falsificationCount": rule.falsificationCount,
                    "defenseCount": rule.defenseCount,
                    "conditions": rule.conditions
                ]
            },
            "falsificationHistory": falsificationHistory.map { record in
                [
                    "ruleId": record.ruleId,
                    "reason": record.reason,
                    "timestamp": record.timestamp.iso8601,
                    "isDefended": record.isDefended
                ]
            },
            "stats": getFalsificationStats()
        ]
    }
}

// MARK: - 辅助扩展

extension Date {
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

extension MetaRule: CustomStringConvertible {
    var description: String {
        "[\(id)] \(name) - \(status.rawValue)"
    }
}

// MARK: - 元规则证伪示例

/*
 使用示例：

 // 1. 报告证伪
 MetaRuleManager.shared.reportFalsification(
     ruleId: "MR-HX-001",
     reason: "连续 3 次能量阈值触发后未发生跃迁",
     context: ["consecutiveFailures": 3, "lastFailureTime": Date().iso8601]
 )

 // 2. 条件化演化
 MetaRuleManager.shared.addCondition(
     ruleId: "MR-HX-001",
     condition: "仅当电池电量 > 20% 时适用能量平衡原则"
 )

 // 3. 辩护
 MetaRuleManager.shared.reportDefense(
     ruleId: "MR-HX-001",
     reason: "跃迁延迟是由于网络波动导致，非规则失效"
 )

 // 4. 查询需要关注的规则
 let attentionRules = MetaRuleManager.shared.getRulesNeedingAttention()
 for rule in attentionRules {
     print("需要关注：\(rule.name) - \(rule.status.rawValue)")
 }
 */
