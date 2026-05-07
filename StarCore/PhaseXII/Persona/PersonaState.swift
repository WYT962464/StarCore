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
        // 出厂设置：所有参数为空
        resetToFactoryDefaults()
    }
    
    /// 重置为出厂默认
    func resetToFactoryDefaults() {
        parameters.removeAll()
        // 默认所有维度为0.5 (中立)
        for key in dimensionKeys {
            parameters[key] = 0.5
        }
    }
    
    // MARK: - Parameter Access
    /// 获取人格参数
    func getParameter(_ key: String) -> Float {
        return parameters[key] ?? 0.5
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
    
    var summary: String {
        return """
        人格参数:
        - 开放性: \(String(format: "%.1f", getParameter("openness") * 100))%
        - 尽责性: \(String(format: "%.1f", getParameter("conscientiousness") * 100))%
        - 外向性: \(String(format: "%.1f", getParameter("extraversion") * 100))%
        - 宜人性: \(String(format: "%.1f", getParameter("agreeableness") * 100))%
        - 神经质: \(String(format: "%.1f", getParameter("neuroticism") * 100))%
        """
    }
}
