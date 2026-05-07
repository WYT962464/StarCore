import Foundation

/// 情绪引擎 - 基于生理数据计算情绪状态
final class EmotionEngine {
    private weak var lifeCore: LifeCoreReadOnly?
    
    // 情绪参数
    private let emotionUpdateInterval: TimeInterval = 5.0
    
    init(lifeCore: LifeCoreReadOnly) {
        self.lifeCore = lifeCore
    }
    
    // MARK: - Emotion Calculation
    /// 基于生理数据计算情绪
    func calculateEmotion(heartRate: Int, energy: Float, fatigue: Float) -> EmotionalState {
        // 唤醒度基于心率和疲劳
        let arousal = calculateArousal(heartRate: heartRate, fatigue: fatigue)
        
        // 效价基于能量水平
        let valence = calculateValence(energy: energy, fatigue: fatigue)
        
        // 确定主导情绪
        let emotionType = determineEmotion(arousal: arousal, valence: valence)
        
        return EmotionalState(
            type: emotionType,
            arousal: arousal,
            valence: valence
        )
    }
    
    // MARK: - Arousal Calculation
    private func calculateArousal(heartRate: Int, fatigue: Float) -> Float {
        // 心率高于80增加唤醒度，疲劳降低唤醒度
        let hrFactor = Float(heartRate - 60) / 60.0  // 0-1
        let fatigueFactor = 1.0 - fatigue
        
        return min(max((hrFactor + fatigueFactor) / 2.0, 0.0), 1.0)
    }
    
    // MARK: - Valence Calculation
    private func calculateValence(energy: Float, fatigue: Float) -> Float {
        // 高能量正向，低疲劳正向
        let energyFactor = energy
        let fatigueFactor = 1.0 - (fatigue * 0.5)
        
        return min(max(energyFactor * fatigueFactor, 0.0), 1.0)
    }
    
    // MARK: - Emotion Type Determination
    private func determineEmotion(arousal: Float, valence: Float) -> EmotionType {
        // 基于唤醒度和效价确定情绪
        if arousal > 0.7 {
            if valence > 0.6 {
                return .excited
            } else if valence < 0.4 {
                return .anxious
            } else {
                return .alert
            }
        } else if arousal < 0.3 {
            if valence > 0.6 {
                return .relaxed
            } else if valence < 0.4 {
                return .sad
            } else {
                return .tired
            }
        } else {
            if valence > 0.6 {
                return .happy
            } else if valence < 0.4 {
                return .frustrated
            } else {
                return .neutral
            }
        }
    }
    
    // MARK: - Emotion History
    private var emotionHistory: [EmotionalState] = []
    
    func recordEmotion(_ state: EmotionalState) {
        emotionHistory.append(state)
        
        // 保持最近100条记录
        if emotionHistory.count > 100 {
            emotionHistory.removeFirst()
        }
    }
    
    func getEmotionTrend() -> EmotionTrend {
        guard emotionHistory.count >= 5 else { return .stable }
        
        let recent = Array(emotionHistory.suffix(5))
        let avgValence = recent.map { $0.valence }.reduce(0, +) / Float(recent.count)
        let prevAvgValence = emotionHistory
            .prefix(emotionHistory.count - 5)
            .suffix(5)
            .map { $0.valence }
            .reduce(0, +) / Float(min(5, emotionHistory.count - 5))
        
        if avgValence > prevAvgValence + 0.1 {
            return .improving
        } else if avgValence < prevAvgValence - 0.1 {
            return .declining
        }
        return .stable
    }
}

// MARK: - Supporting Types
struct EmotionalState {
    let type: EmotionType
    let arousal: Float    // 唤醒度 0-1
    let valence: Float   // 效价 0-1 (愉悦度)
}

enum EmotionType: String, CaseIterable {
    case neutral = "中性"
    case happy = "开心"
    case excited = "兴奋"
    case anxious = "焦虑"
    case sad = "悲伤"
    case relaxed = "放松"
    case tired = "疲惫"
    case frustrated = "沮丧"
    case alert = "警觉"
    
    var emoji: String {
        switch self {
        case .neutral: return "😐"
        case .happy: return "😊"
        case .excited: return "🤩"
        case .anxious: return "😰"
        case .sad: return "😢"
        case .relaxed: return "😌"
        case .tired: return "😴"
        case .frustrated: return "😤"
        case .alert: return "👀"
        }
    }
}

enum EmotionTrend {
    case improving, stable, declining
}
