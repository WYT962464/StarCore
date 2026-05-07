import Foundation

/// 认知核心 - 阶段十二：人格认知
/// 持有LifeCoreReadOnly引用，通过协议只读访问底层
@available(iOS 15.0, *)
final class MindCore: ObservableObject {
    // MARK: - Dependencies
    private let lifeCoreReadOnly: LifeCoreReadOnly
    private let emotionEngine: EmotionEngine
    private let personaState: PersonaState
    private let mindLock: MindLock
    
    // MARK: - Published Properties
    @Published var dominantEmotion: EmotionType = .neutral
    @Published var arousalLevel: Float = 0.5        // 唤醒度 0-1
    @Published var valenceLevel: Float = 0.5        // 效价 0-1 (愉悦度)
    @Published var cognitiveLoad: Float = 0.0       // 认知负荷
    @Published var mindStatus: MindStatus = .active
    
    // MARK: - Initialization
    init(lifeCoreReadOnly: LifeCoreReadOnly) {
        self.lifeCoreReadOnly = lifeCoreReadOnly
        self.emotionEngine = EmotionEngine(lifeCore: lifeCoreReadOnly)
        self.personaState = PersonaState()
        self.mindLock = MindLock()
        
        // 初始化完成
        print("[MindCore] 认知核心初始化完成")
    }
    
    // MARK: - Update Loop
    /// 更新认知状态
    func updateCognitiveState() {
        // 检查隐生状态
        if lifeCoreReadOnly.cryptobiosisActive {
            mindStatus = .dormant
            return
        }
        
        mindStatus = .active
        
        // 更新情绪状态
        let emotionalState = emotionEngine.calculateEmotion(
            heartRate: lifeCoreReadOnly.heartRate,
            energy: lifeCoreReadOnly.energyLevel,
            fatigue: lifeCoreReadOnly.fatigueLevel
        )
        
        dominantEmotion = emotionalState.type
        arousalLevel = emotionalState.arousal
        valenceLevel = emotionalState.valence
        
        // 更新认知负荷
        cognitiveLoad = calculateCognitiveLoad()
    }
    
    // MARK: - Cognitive Load Calculation
    private func calculateCognitiveLoad() -> Float {
        // 基于心率和疲劳度计算认知负荷
        let hrFactor = Float(lifeCoreReadOnly.heartRate - 60) / 60.0  // 0-1
        let fatigueFactor = lifeCoreReadOnly.fatigueLevel
        
        return min((hrFactor + fatigueFactor) / 2.0, 1.0)
    }
    
    // MARK: - Read-Only Access
    /// 获取生命体征（只读）
    func getVitalSigns() -> VitalSignsSnapshot {
        return VitalSignsSnapshot(
            heartRate: lifeCoreReadOnly.heartRate,
            energyLevel: lifeCoreReadOnly.energyLevel,
            bodyTemperature: lifeCoreReadOnly.bodyTemperature,
            fatigueLevel: lifeCoreReadOnly.fatigueLevel
        )
    }
    
    // MARK: - Write Protection
    /// 尝试写入底层（会被阻止）
    func attemptWrite底层(_ value: Any) -> Bool {
        return mindLock.tryWrite(value: value)
    }
}

// MARK: - Supporting Types
enum MindStatus {
    case active
    case dormant
    case overloaded
}

struct VitalSignsSnapshot {
    let heartRate: Int
    let energyLevel: Float
    let bodyTemperature: Float
    let fatigueLevel: Float
}
