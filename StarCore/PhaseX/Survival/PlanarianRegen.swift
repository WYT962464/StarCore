import Foundation

/// 涡虫模式 - 全片段再生
final class PlanarianRegen {
    private weak var lifeCore: LifeCore?
    private var recoveryCount: Int = 0
    private var totalBackupsCreated: Int = 0
    private var backupVersions: [Date: BackupVersion] = [:]
    
    init() {}
    
    func bind(lifeCore: LifeCore) {
        self.lifeCore = lifeCore
    }
    
    func incrementRecoveryCount() {
        recoveryCount += 1
        lifeCore?.addLog(.info, "Planarian: 恢复次数 +1，当前: \(recoveryCount)")
    }
    
    func recordBackup(version: BackupVersion) {
        backupVersions[version.timestamp] = version
        totalBackupsCreated += 1
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
    
    var totalRecoveries: Int { return recoveryCount }
    var totalBackups: Int { return totalBackupsCreated }
    
    /// 从备份恢复时设置恢复计数
    func setRecoveryCount(_ count: Int) {
        recoveryCount = count
    }
    var latestBackup: BackupVersion? {
        return backupVersions.values.sorted { $0.versionNumber > $1.versionNumber }.first
    }
}

struct BackupVersion: Codable {
    let versionNumber: Int
    let timestamp: Date
    let checksum: String
    
    init(versionNumber: Int, timestamp: Date = Date()) {
        self.versionNumber = versionNumber
        self.timestamp = timestamp
        self.checksum = "v\(versionNumber)-\(Int(timestamp.timeIntervalSince1970))"
    }
}
