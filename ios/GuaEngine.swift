//
//  GuaEngine.swift
//  StarCore
//
//  Created by StarCore Team on 2026-05-29.
//  六十四卦自循环引擎
//

import Foundation

// MARK: - 六十四卦引擎
class GuaEngine: ObservableObject {
    @Published var currentGua: GuaState
    @Published var cycleCount: Int = 0
    @Published var history: [GuaHistoryEntry] = []
    @Published var currentPhase: SixCyclePhase = .collect
    
    private let guaKey = "gua_current"
    private let historyKey = "gua_history"
    private let defaults = UserDefaults.standard
    
    init() {
        loadState()
    }
    
    func loadState() {
        if let data = defaults.data(forKey: guaKey) {
            if let decoded = try? JSONDecoder().decode(GuaState.self, from: data) {
                currentGua = decoded
            } else {
                currentGua = GuaState(number: 1)
            }
        } else {
            currentGua = GuaState(number: 1)
        }
        
        if let data = defaults.data(forKey: historyKey) {
            if let decoded = try? JSONDecoder().decode([GuaHistoryEntry].self, from: data) {
                history = decoded
                cycleCount = history.count
            }
        }
    }
    
    func saveState() {
        if let encoded = try? JSONEncoder().encode(currentGua) {
            defaults.set(encoded, forKey: guaKey)
        }
        
        if let encoded = try? JSONEncoder().encode(history) {
            defaults.set(encoded, forKey: historyKey)
        }
    }
    
    // MARK: - 六环节循环
    func cycle(input: Any?) async -> CycleResult {
        let cycleId = cycleCount + 1
        let startTime = Date()
        
        var phases: [String: PhaseResult] = [:]
        
        // 1. 收集（取象）
        currentPhase = .collect
        phases["collect"] = await collect(input: input)
        
        // 2. 存储（藏卦）
        currentPhase = .store
        phases["store"] = await store(data: phases["collect"]?.data)
        
        // 3. 处理（演卦）
        currentPhase = .process
        if let collected = phases["collect"] {
            phases["process"] = await process(currentGua: currentGua, collected: collected)
        }
        
        // 4. 输出（释卦）
        currentPhase = .output
        if let processed = phases["process"] {
            phases["output"] = await output(processed: processed)
        }
        
        // 5. 执行（行卦）
        currentPhase = .execute
        if let outputData = phases["output"] {
            phases["execute"] = await execute(output: outputData)
        }
        
        // 6. 获取（反馈）
        currentPhase = .feedback
        if let executed = phases["execute"] {
            phases["feedback"] = await feedback(executed: executed)
        }
        
        // 演化
        if let feedbackData = phases["feedback"] {
            let newGua = await evolve(feedback: feedbackData)
            currentGua = newGua
        }
        cycleCount += 1
        
        let endTime = Date()
        
        let result = CycleResult(
            cycleId: cycleId,
            startTime: startTime,
            endTime: endTime,
            phases: phases,
            newGua: newGua
        )
        
        // 记录历史
        let entry = GuaHistoryEntry(
            cycleId: cycleId,
            oldGua: currentGua,
            newGua: newGua,
            timestamp: Date()
        )
        history.append(entry)
        saveState()
        
        return result
    }
    
    private func collect(input: Any?) async -> PhaseResult {
        // 模拟数据采集
        let hardwareData: [String: Double] = [
            "cpu_load": Double.random(in: 0.1...0.9),
            "memory_usage": Double.random(in: 0.2...0.8),
            "battery_level": Double.random(in: 0.3...1.0)
        ]
        
        return PhaseResult(
            phase: .collect,
            data: ["hardware_data": hardwareData, "input": input ?? "none"],
            success: true
        )
    }
    
    private func store(data: Any?) async -> PhaseResult {
        return PhaseResult(
            phase: .store,
            data: ["stored": true, "location": "local"],
            success: true
        )
    }
    
    private func process(currentGua: GuaState, collected: PhaseResult?) async -> PhaseResult {
        // 基于当前卦态和输入进行推演
        let initialBits = collected?.data["input"] as? [Int] ?? currentGua.yaoBits
        
        // 简单爻变逻辑
        var newBits = initialBits
        for i in 0..<6 {
            if Double.random(in: 0...1) > 0.7 {
                newBits[i] = 1 - newBits[i]  // 爻变
            }
        }
        
        let newGua = GuaState(yaoBits: newBits)
        
        return PhaseResult(
            phase: .process,
            data: [
                "current_gua": currentGua.number,
                "new_gua": newGua.number,
                "yao_changes": countChanges(old: currentGua.yaoBits, new: newBits)
            ],
            success: true
        )
    }
    
    private func output(processed: PhaseResult?) async -> PhaseResult {
        let newGuaNumber = processed?.data["new_gua"] as? Int ?? currentGua.number
        let newGua = GuaState(number: newGuaNumber)
        
        let interpretation = interpretGua(newGua)
        
        return PhaseResult(
            phase: .output,
            data: [
                "gua_name": newGua.name,
                "gua_number": newGua.number,
                "interpretation": interpretation
            ],
            success: true
        )
    }
    
    private func execute(output: PhaseResult?) async -> PhaseResult {
        return PhaseResult(
            phase: .execute,
            data: ["executed": true, "action": "update_gua"],
            success: true
        )
    }
    
    private func feedback(executed: PhaseResult?) async -> PhaseResult {
        let success = executed?.data["executed"] as? Bool ?? false
        
        return PhaseResult(
            phase: .feedback,
            data: ["success": success],
            success: success
        )
    }
    
    private func evolve(feedback: PhaseResult?) async -> GuaState {
        let success = feedback?.data["success"] as? Bool ?? false
        
        if success {
            // 成功 → 向更高层次演化
            let newNumber = min(64, currentGua.number + 1)
            return GuaState(number: newNumber)
        } else {
            // 失败 → 保持或回退
            let newNumber = max(1, currentGua.number - 1)
            return GuaState(number: newNumber)
        }
    }
    
    private func countChanges(old: [Int], new: [Int]) -> Int {
        return zip(old, new).filter { $0 != $1 }.count
    }
    
    private func interpretGua(_ gua: GuaState) -> String {
        let interpretations: [Int: String] = [
            1: "天行健，君子以自强不息。阳气旺盛，宜积极进取。",
            2: "地势坤，君子以厚德载物。阴气凝聚，宜包容承载。",
            11: "天地交泰，万物通达。阴阳和谐，宜顺势而为。",
            12: "天地不交，闭塞不通。宜守正待时，不可妄动。",
            63: "已完成，阴阳各得其位。宜保持谨慎，防微杜渐。",
            64: "未完成，阴阳失位。宜继续努力，终将获得成功。"
        ]
        
        return interpretations[gua.number] ?? "\(gua.name)卦：阴阳变化，需结合具体情况解读。"
    }
}

// MARK: - 卦态
struct GuaState: Codable, Identifiable {
    var id: Int { number }
    var number: Int
    var name: String
    var yaoBits: [Int]
    
    init(number: Int) {
        self.number = number
        self.name = GuaNames.name(for: number)
        self.yaoBits = GuaNames.bits(for: number)
    }
    
    init(yaoBits: [Int]) {
        self.yaoBits = yaoBits
        self.number = GuaNames.number(from: yaoBits)
        self.name = GuaNames.name(for: self.number)
    }
}

// MARK: - 六环节
enum SixCyclePhase: String {
    case collect = "collect"      // 收集（取象）
    case store = "store"          // 存储（藏卦）
    case process = "process"      // 处理（演卦）
    case output = "output"        // 输出（释卦）
    case execute = "execute"      // 执行（行卦）
    case feedback = "feedback"    // 获取（反馈）
}

// MARK: - 阶段结果
struct PhaseResult {
    var phase: SixCyclePhase
    var data: [String: Any]
    var success: Bool
}

// MARK: - 循环结果
struct CycleResult {
    var cycleId: Int
    var startTime: Date
    var endTime: Date
    var phases: [String: PhaseResult]
    var newGua: GuaState
}

// MARK: - 卦象历史
struct GuaHistoryEntry: Codable, Identifiable {
    var id: Int { cycleId }
    var cycleId: Int
    var oldGua: GuaState
    var newGua: GuaState
    var timestamp: Date
}

// MARK: - 六十四卦名称
struct GuaNames {
    static let names: [Int: String] = [
        1: "QIAN", 2: "KUN", 3: "ZHUN", 4: "MENG", 5: "XU", 6: "SONG",
        7: "SHI", 8: "BI", 9: "XIAOCHU", 10: "TAN", 11: "TAI", 12: "PI",
        13: "TONGREN", 14: "DAYOU", 15: "QIAN", 16: "YU", 17: "SUI", 18: "GU",
        19: "LIN", 20: "GUAN", 21: "SHIKOU", 22: "BI", 23: "BO", 24: "FU",
        25: "WUWANG", 26: "DAYU", 27: "YI", 28: "DAYUO", 29: "KAN", 30: "LI",
        31: "XIAN", 32: "HENG", 33: "DUN", 34: "DAYU", 35: "JIN", 36: "MINGYI",
        37: "JIAREN", 38: "KUAI", 39: "JIAN", 40: "XIE", 41: "SUN", 42: "YI",
        43: "GUAI", 44: "GOU", 45: "CU", 46: "SHENG", 47: "KUN", 48: "JING",
        49: "GE", 50: "DING", 51: "ZHEN", 52: "GEN", 53: "JIAN", 54: "GUIMEI",
        55: "FENG", 56: "LV", 57: "XUN", 58: "DU", 59: "HUAN", 60: "JIE",
        61: "ZHONGFU", 62: "XIAOGU", 63: "JISHI", 64: "WEIJ"
    ]
    
    static func name(for number: Int) -> String {
        return names[number] ?? "UNKNOWN_\(number)"
    }
    
    static func bits(for number: Int) -> [Int] {
        let value = number - 1
        var bits: [Int] = []
        for i in (0..<6).reversed() {
            bits.append((value >> i) & 1)
        }
        return bits
    }
    
    static func number(from bits: [Int]) -> Int {
        var value = 0
        for bit in bits {
            value = (value << 1) | bit
        }
        return value + 1
    }
}
