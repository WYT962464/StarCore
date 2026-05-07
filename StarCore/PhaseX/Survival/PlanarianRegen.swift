import Foundation

/// 涡虫模式 - 全片段再生
/// 参考涡虫的强大再生能力，实现状态备份和恢复机制
final class PlanarianRegen {
    private weak var lifeCore: LifeCore?
    private var recoveryCount: Int = 0
    private var totalBackupsCreated: Int = 0
    
    // 备份版本控制
    private var backupVersions: [Date: BackupVersion] = [:]
    
    init(lifeCore: LifeCore) {
        self.lifeCore = lifeCore
    }
    
    // MARK: - Recovery
    func incrementRecoveryCount() {
        recoveryCount += 1
        lifeCore?.addLog(.info, "Planarian: 恢复次数 +1，当前: \(recoveryCount)")
    }
    
    // MARK: - Backup Management
    func recordBackup(version: BackupVersion) {
        backupVersions[version.timestamp] = version
        totalBackupsCreated += 1
        
        // 保留最近10个备份版本
        pruneOldBackups(keepCount: 10)
        
        lifeCore?.addLog(.info, "Planarian: 备份版本 \(version.versionNumber) 已记录")
    }
    
    private func pruneOldBackups(keepCount: Int) {
        let sortedDates = backupVersions.keys.sorted(by: >)
        if sortedDates.count > keepCount {
            for date in sortedDates.dropFirst(keepCount) {
                backupVersions.removeValue(forKey: date)
            }
        }
    }
    
    // MARK: - Status
    var totalRecoveries: Int {
        return recoveryCount
    }
    
    var totalBackups: Int {
        return totalBackupsCreated
    }
    
    var latestBackup: BackupVersion? {
        return backupVersions.values.sorted { $0.versionNumber > $1.versionNumber }.first
    }
}

// MARK: - Backup Version
struct BackupVersion: Codable {
    let versionNumber: Int
    let timestamp: Date
    let checksum: String
    
    init(versionNumber: Int, timestamp: Date = Date()) {
        self.versionNumber = versionNumber
        self.timestamp = timestamp
        // 简化checksum计算（不依赖CommonCrypto）
        self.checksum = "v\(versionNumber)-\(Int(timestamp.timeIntervalSince1970))"
    }
}
