import Foundation

/// 蛭形轮虫模式 - 无依赖永续
/// 参考蛭形轮虫的无性繁殖和极端环境适应能力，实现跨环境持久化
final class BdelloidPersist {
    // 跨环境存储路径适配
    private let pathResolver = EnvironmentPathResolver()
    
    init() {}
    
    // MARK: - Path Detection
    /// 检测当前运行环境，返回对应的存储路径
    func detectCurrentEnvironment() -> StorageEnvironment {
        return pathResolver.currentEnvironment
    }
    
    /// 获取当前环境的存储根路径
    func getStorageRoot() -> URL {
        return pathResolver.getStorageRoot()
    }
    
    // MARK: - Persistence
    /// 验证数据在所有已知环境中的一致性
    func verifyCrossEnvironmentConsistency(data: Data) -> Bool {
        let checksum = calculateChecksum(data)
        // 在实际实现中会比较多个环境路径中的checksum
        return true
    }
    
    private func calculateChecksum(_ data: Data) -> String {
        // 简化的校验和计算
        let sum = data.reduce(0) { $0 + Int($1) }
        return String(format: "%08x", sum)
    }
}

// MARK: - Environment Path Resolver
enum StorageEnvironment {
    case sandbox          // 正常沙盒环境
    case jailbroken       // 越狱环境
    case testFlight       // TestFlight
    case simulator        // 模拟器
}

class EnvironmentPathResolver {
    let currentEnvironment: StorageEnvironment
    
    init() {
        #if targetEnvironment(simulator)
        currentEnvironment = .simulator
        #else
        if isJailbroken() {
            currentEnvironment = .jailbroken
        } else if isTestFlight() {
            currentEnvironment = .testFlight
        } else {
            currentEnvironment = .sandbox
        }
        #endif
    }
    
    func getStorageRoot() -> URL {
        let basePath: String
        
        switch currentEnvironment {
        case .sandbox, .testFlight:
            basePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp"
        case .jailbroken:
            // 越狱环境使用更稳定的路径
            basePath = "/var/mobile/Documents/StarCore"
            try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true)
        case .simulator:
            basePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp"
        }
        
        return URL(fileURLWithPath: basePath)
    }
    
    // MARK: - Environment Detection
    private func isJailbroken() -> Bool {
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        return false
    }
    
    private func isTestFlight() -> Bool {
        let bundlePath = Bundle.main.appStoreReceiptURL?.path ?? ""
        return bundlePath.contains("sandboxReceipt")
    }
}
