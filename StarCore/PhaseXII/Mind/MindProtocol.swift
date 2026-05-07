import Foundation

/// 认知协议 - 定义认知层的只读接口
/// 供未来扩展使用
protocol MindReadOnly {
    var dominantEmotion: EmotionType { get }
    var arousalLevel: Float { get }
    var valenceLevel: Float { get }
    var cognitiveLoad: Float { get }
    var mindStatus: MindStatus { get }
}

// MARK: - Default Implementation
@available(iOS 15.0, *)
extension MindCore: MindReadOnly {
    // MindCore自动符合MindReadOnly协议
}
