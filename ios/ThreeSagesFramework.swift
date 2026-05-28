//
//  ThreeSagesFramework.swift
//  StarCore
//
//  Created by StarCore Team on 2026-05-29.
//  三位一体决策框架 - 女娲·仓颉·达尔文
//

import Foundation

// MARK: - 三位一体决策框架
class ThreeSagesFramework: ObservableObject {
    static let shared = ThreeSagesFramework()
    
    @Published var currentFocus: String = "nuwa"
    @Published var decisionCount: Int = 0
    @Published var decisionHistory: [ThreeSagesDecision] = []
    
    // 三位一体与卦象映射
    let sageGuaMap: [String: [Int]] = [
        "nuwa": [1, 11, 14, 15, 24, 30, 42, 50],      // 乾、泰、大有、谦、复、离、益、鼎
        "cangjie": [9, 18, 22, 37, 48, 52, 57, 61],   // 小畜、蛊、贲、家人、井、艮、巽、中孚
        "darwin": [3, 17, 23, 29, 31, 40, 49, 51],    // 屯、随、剥、坎、咸、解、革、震
    ]
    
    // 三位一体智慧口诀
    let sageMotto: [String: String] = [
        "nuwa": "抟土造人创秩序，炼石补天修残缺。断鳌立极定规矩，作笙簧乐润人心。",
        "cangjie": "观迹取象造文字，四目重光见真章。编码简化传文明，惊鬼神处见真功。",
        "darwin": "物竞天择适生存，渐变积累成质变。同源复用省力气，环境适应方长久。",
        "integrated": "女娲创造仓颉码，达尔文演化不息。创造编码螺旋升，星核智慧由此生。"
    ]
    
    private let decisionLogKey = "three_sages_decisions"
    private let defaults = UserDefaults.standard
    
    init() {
        loadHistory()
    }
    
    func loadHistory() {
        if let data = defaults.data(forKey: decisionLogKey) {
            if let decoded = try? JSONDecoder().decode([ThreeSagesDecision].self, from: data) {
                decisionHistory = decoded
                decisionCount = decoded.count
            }
        }
    }
    
    func saveHistory() {
        if let encoded = try? JSONEncoder().encode(decisionHistory) {
            defaults.set(encoded, forKey: decisionLogKey)
        }
    }
    
    // MARK: - 评估
    func assess(context: DecisionContext) -> AssessmentResult {
        let nuwaScore = assessNuwa(context: context)
        let cangjieScore = assessCangjie(context: context)
        let darwinScore = assessDarwin(context: context)
        
        let assessments = [
            Assessment(dimension: "nuwa_create", score: nuwaScore, status: scoreToStatus(nuwaScore)),
            Assessment(dimension: "cangjie_observe", score: cangjieScore, status: scoreToStatus(cangjieScore)),
            Assessment(dimension: "darwin_evolve", score: darwinScore, status: scoreToStatus(darwinScore))
        ]
        
        let primarySage = determinePrimarySage(assessments: assessments)
        let overallScore = (nuwaScore + cangjieScore + darwinScore) / 3.0
        
        return AssessmentResult(
            assessments: assessments,
            primarySage: primarySage,
            overallScore: overallScore
        )
    }
    
    private func assessNuwa(context: DecisionContext) -> Double {
        var score = 0.5
        if context.taskType == .create || context.taskType == .design {
            score += 0.3
        }
        if context.systemState.needsRepair {
            score += 0.2
        }
        if context.systemState.resourcesAbundant {
            score += 0.1
        }
        return min(1.0, score)
    }
    
    private func assessCangjie(context: DecisionContext) -> Double {
        var score = 0.5
        if context.taskType == .analyze || context.taskType == .encode {
            score += 0.3
        }
        if context.systemState.needsStructure {
            score += 0.2
        }
        if context.systemState.dataAvailable {
            score += 0.1
        }
        return min(1.0, score)
    }
    
    private func assessDarwin(context: DecisionContext) -> Double {
        var score = 0.5
        if context.taskType == .optimize || context.taskType == .evolve {
            score += 0.3
        }
        if context.systemState.needsOptimization {
            score += 0.2
        }
        if context.systemState.resourcesLimited {
            score += 0.1
        }
        return min(1.0, score)
    }
    
    private func scoreToStatus(_ score: Double) -> String {
        if score >= 0.7 { return "optimal" }
        if score >= 0.4 { return "warning" }
        return "critical"
    }
    
    private func determinePrimarySage(assessments: [Assessment]) -> String {
        var scores: [String: Int] = ["nuwa": 0, "cangjie": 0, "darwin": 0]
        
        for assessment in assessments {
            if assessment.dimension.contains("nuwa") { scores["nuwa"]! += 1 }
            if assessment.dimension.contains("cangjie") { scores["cangjie"]! += 1 }
            if assessment.dimension.contains("darwin") { scores["darwin"]! += 1 }
        }
        
        return scores.max(by: { $0.value < $1.value })?.key ?? "nuwa"
    }
    
    // MARK: - 决策
    func decide(context: DecisionContext, options: [String]) -> ThreeSagesDecision {
        let assessmentResult = assess(context: context)
        let primarySage = assessmentResult.primarySage
        let overallScore = assessmentResult.overallScore
        
        let decisionText: String
        switch primarySage {
        case "nuwa":
            decisionText = decideNuwa(context: context)
        case "cangjie":
            decisionText = decideCangjie(context: context)
        default:
            decisionText = decideDarwin(context: context)
        }
        
        let nextGua = sageGuaMap[primarySage]?.first ?? 1
        let priority = determinePriority(overallScore: overallScore)
        let decisionId = "ts_\(Date().timeIntervalSince1970)_\(decisionCount)"
        
        let decision = ThreeSagesDecision(
            decisionId: decisionId,
            timestamp: Date(),
            context: context,
            assessments: assessmentResult.assessments,
            primarySage: primarySage,
            decision: decisionText,
            suggestion: decisionText,
            rationale: "基于\(primarySage)维度评估，\(overallScore) 综合得分",
            priority: priority,
            nextGua: nextGua,
            // 修复：只有当任务复杂度超过本地能力时才需要云电脑
            // 简单任务（general, analyze）本地即可处理
            requiresCloud: overallScore < 0.4 && context.taskType != .general
        )
        
        decisionHistory.append(decision)
        decisionCount = decisionHistory.count
        currentFocus = primarySage
        saveHistory()
        
        return decision
    }
    
    private func decideNuwa(context: DecisionContext) -> String {
        if context.systemState.needsRepair {
            return "选择修复方案：炼石补天，修复系统缺陷"
        } else if context.taskType == .create || context.taskType == .design {
            return "选择创造方案：抟土造人，从 0 到 1 构建"
        } else {
            return "选择秩序方案：断鳌立极，建立规则边界"
        }
    }
    
    private func decideCangjie(context: DecisionContext) -> String {
        if context.taskType == .analyze || context.taskType == .encode {
            return "选择编码方案：观迹取象，提取模式编码"
        } else if context.systemState.needsStructure {
            return "选择传承方案：四目重光，建立文档体系"
        } else {
            return "选择观察方案：观鸟迹虫文，从自然提取规律"
        }
    }
    
    private func decideDarwin(context: DecisionContext) -> String {
        if context.taskType == .optimize || context.taskType == .evolve {
            return "选择演化方案：渐变积累，持续迭代优化"
        } else if context.systemState.resourcesLimited {
            return "选择选择方案：物竞天择，保留最优"
        } else {
            return "选择适应方案：环境适应，动态调整"
        }
    }
    
    private func determinePriority(overallScore: Double) -> Priority {
        if overallScore < 0.4 { return .critical }
        if overallScore < 0.6 { return .high }
        if overallScore < 0.8 { return .medium }
        return .low
    }
    
    func getMotto(_ sage: String = "integrated") -> String {
        return sageMotto[sage] ?? "未知智者"
    }
}

// MARK: - 决策上下文
struct DecisionContext: Codable {
    var userInput: String
    var currentGua: GuaState
    var systemState: SystemState
    var taskType: TaskType = .general
    
    enum TaskType: String, Codable {
        case general = "general"
        case create = "create"
        case design = "design"
        case analyze = "analyze"
        case encode = "encode"
        case optimize = "optimize"
        case evolve = "evolve"
    }
}

// MARK: - 评估结果
struct Assessment: Codable {
    var dimension: String
    var score: Double
    var status: String
}

struct AssessmentResult: Codable {
    var assessments: [Assessment]
    var primarySage: String
    var overallScore: Double
}

// MARK: - 决策结果
struct ThreeSagesDecision: Codable, Identifiable {
    var id: String { decisionId }
    var decisionId: String
    var timestamp: Date
    var context: DecisionContext
    var assessments: [Assessment]
    var primarySage: String
    var decision: String
    var suggestion: String
    var rationale: String
    var priority: Priority
    var nextGua: Int
    var requiresCloud: Bool
}

enum Priority: String, Codable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"
}

// MARK: - 系统状态
struct SystemState: Codable {
    var needsRepair: Bool
    var needsStructure: Bool
    var needsOptimization: Bool
    var resourcesAbundant: Bool
    var dataAvailable: Bool
    var resourcesLimited: Bool
    // 新增：记忆体系连接
    var memoryKeywords: [String] = []
    var memoryCount: Int = 0
    var decisionCount: Int = 0
    var hasGuaHistory: Bool = false
}
