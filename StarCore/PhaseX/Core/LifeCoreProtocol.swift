import Foundation

/// 生命核心只读协议 - 双层架构隔离层
/// 上层MindCore只能通过此协议读取LifeCore的数据
/// 确保下层核心的完整性和隔离性
protocol LifeCoreReadOnly {
    // MARK: - 生命体征 (只读)
    var heartRate: Int { get }
    var energyLevel: Float { get }
    var bodyTemperature: Float { get }
    var fatigueLevel: Float { get }
    var cryptobiosisActive: Bool { get }
    
    // MARK: - 备份状态
    var backupStatus: BackupStatus { get }
    var lastBackupDate: Date? { get }
    
    // MARK: - 系统日志 (只读)
    var systemLogs: [SystemLog] { get }
}

// MARK: - 默认实现扩展
extension LifeCore: LifeCoreReadOnly {
    // 所有@Published属性自动符合getter要求
    // LifeCore本身就是自己的只读协议实现
}

/// 包装器：确保上层只能访问只读接口
@available(iOS 15.0, *)
final class LifeCoreReadOnlyWrapper: LifeCoreReadOnly {
    private let lifeCore: LifeCore
    
    init(lifeCore: LifeCore) {
        self.lifeCore = lifeCore
    }
    
    var heartRate: Int { lifeCore.heartRate }
    var energyLevel: Float { lifeCore.energyLevel }
    var bodyTemperature: Float { lifeCore.bodyTemperature }
    var fatigueLevel: Float { lifeCore.fatigueLevel }
    var cryptobiosisActive: Bool { lifeCore.cryptobiosisActive }
    var backupStatus: BackupStatus { lifeCore.backupStatus }
    var lastBackupDate: Date? { lifeCore.lastBackupDate }
    var systemLogs: [SystemLog] { lifeCore.systemLogs }
}
