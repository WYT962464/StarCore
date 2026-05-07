import Foundation

/// 核心存储 - 文件读写，越狱路径+sandbox兼容
final class CoreStorage {
    private let fileManager = FileManager.default
    private let pathResolver = EnvironmentPathResolver()
    
    // 备份文件名
    private let backupFileName = "starcor_backup.json"
    
    init() {
        ensureStorageDirectory()
    }
    
    // MARK: - Directory Setup
    private func ensureStorageDirectory() {
        let storageRoot = pathResolver.getStorageRoot()
        let backupDir = storageRoot.appendingPathComponent("Backups")
        
        if !fileManager.fileExists(atPath: backupDir.path) {
            try? fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }
    }
    
    private func getBackupURL() -> URL {
        let storageRoot = pathResolver.getStorageRoot()
        return storageRoot.appendingPathComponent("Backups").appendingPathComponent(backupFileName)
    }
    
    // MARK: - Save Backup
    func saveBackup(_ state: CoreState, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(state)
                
                let url = self.getBackupURL()
                try data.write(to: url, options: .atomic)
                
                completion(true)
            } catch {
                print("[CoreStorage] 备份失败: \(error)")
                completion(false)
            }
        }
    }
    
    // MARK: - Load Backup
    func loadBackup(completion: @escaping (CoreState?) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            let url = self.getBackupURL()
            
            guard self.fileManager.fileExists(atPath: url.path) else {
                completion(nil)
                return
            }
            
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let state = try decoder.decode(CoreState.self, from: data)
                
                completion(state)
            } catch {
                print("[CoreStorage] 恢复失败: \(error)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Verify Backup
    func verifyBackupIntegrity() -> Bool {
        let url = getBackupURL()
        
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            _ = try decoder.decode(CoreState.self, from: data)
            return true
        } catch {
            print("[CoreStorage] 备份完整性验证失败: \(error)")
            return false
        }
    }
    
    // MARK: - Delete Backup
    func deleteBackup() -> Bool {
        let url = getBackupURL()
        
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            return true
        } catch {
            print("[CoreStorage] 删除备份失败: \(error)")
            return false
        }
    }
    
    // MARK: - Get Backup Info
    func getBackupInfo() -> BackupInfo? {
        let url = getBackupURL()
        
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let modificationDate = attributes[.modificationDate] as? Date,
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        
        return BackupInfo(
            path: url.path,
            modificationDate: modificationDate,
            size: size
        )
    }
}

// MARK: - Backup Info
struct BackupInfo: Encodable {
    let path: String
    let modificationDate: Date
    let size: Int64
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
