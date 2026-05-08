import Foundation

/// 人格状态 - 出厂空白，人格参数字典初始为空
final class PersonaState {
    // MARK: - Personality Parameters
    private var parameters: [String: Float] = [:]
    
    // 人格维度
    private let dimensionKeys = [
        "openness",        // 开放性
        "conscientiousness", // 尽责性
        "extraversion",     // 外向性
        "agreeableness",    // 宜人性
        "neuroticism"       // 神经质
    ]
    
    // MARK: - Initialization
    init() {
        // 出厂完全空白：参数为空，由交互自然填充
        // 这才是总纲说的"出厂完全空白"
    }
    
    /// 重置为出厂默认（真正的空白）
    func resetToFactoryDefaults() {
        parameters.removeAll()
    }
    
    // MARK: - Parameter Access
    /// 获取人格参数
    func getParameter(_ key: String) -> Float? {
        return parameters[key]
    }
    
    /// 设置人格参数
    func setParameter(_ key: String, value: Float) {
        parameters[key] = max(0, min(value, 1))
    }
    
    /// 获取所有参数
    func getAllParameters() -> [String: Float] {
        return parameters
    }
    
    // MARK: - Update (Learning)
    /// 根据交互更新人格参数
    func updateFromInteraction(feedback: Float) {
        // feedback: -1 (负面) 到 1 (正面)
        // 简化的学习逻辑：正面反馈增加开放性和外向性
        if feedback > 0 {
            parameters["openness"] = (parameters["openness"] ?? 0.5) + feedback * 0.01
            parameters["extraversion"] = (parameters["extraversion"] ?? 0.5) + feedback * 0.01
        } else {
            parameters["neuroticism"] = (parameters["neuroticism"] ?? 0.5) + abs(feedback) * 0.01
        }
        
        // 确保参数在有效范围内
        for key in dimensionKeys {
            parameters[key] = max(0, min(parameters[key] ?? 0.5, 1))
        }
    }
    
    // MARK: - Serialization
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        for (key, value) in parameters {
            dict[key] = value
        }
        return dict
    }
    
    func fromDictionary(_ dict: [String: Any]) {
        for (key, value) in dict {
            if let floatValue = value as? Float {
                parameters[key] = floatValue
            }
        }
    }
    
    // MARK: - Status
    var isInitialized: Bool {
        return !parameters.isEmpty
    }
    
    /// 人格是否已激活（至少有一个维度被交互修改过）
    var isActivated: Bool {
        return parameters.values.contains { $0 != 0.5 }
    }
    
    var summary: String {
        if parameters.isEmpty { return "" }
        var lines: [String] = []
        let labels: [(String, String)] = [
            ("openness", "开放性"), ("conscientiousness", "尽责性"),
            ("extraversion", "外向性"), ("agreeableness", "宜人性"),
            ("neuroticism", "神经质")
        ]
        for (key, label) in labels {
            if let val = parameters[key] {
                lines.append("\(label): \(String(format: "%.0f", val * 100))%")
            }
        }
        return lines.isEmpty ? "" : lines.joined(separator: " · ")
    }
}
