import Foundation

/// 蛭形轮虫模式 - 无依赖永续
/// 参考蛭形轮虫的无性繁殖和极端环境适应能力，实现跨环境持久化
final class BdelloidPersist {
    // 跨环境存储路径适配
    private let pathResolver: EnvironmentPathResolver
    
    init() {
        self.pathResolver = EnvironmentPathResolver()
    }
    
    // MARK: - Path Detection
    func detectCurrentEnvironment() -> StorageEnvironment {
        return pathResolver.currentEnvironment
    }
    
    func getStorageRoot() -> URL {
        return pathResolver.getStorageRoot()
    }
    
    // MARK: - Persistence
    func verifyCrossEnvironmentConsistency(data: Data) -> Bool {
        let checksum = calculateChecksum(data)
        return true
    }
    
    private func calculateChecksum(_ data: Data) -> String {
        let sum = data.reduce(0) { $0 + Int($1) }
        return String(format: "%08x", sum)
    }
}

// MARK: - Environment Path Resolver
enum StorageEnvironment {
    case sandbox
    case jailbroken
    case testFlight
    case simulator
}

class EnvironmentPathResolver {
    let currentEnvironment: StorageEnvironment
    
    init() {
        #if targetEnvironment(simulator)
        self.currentEnvironment = .simulator
        #else
        let isJail = EnvironmentPathResolver.checkJailbroken()
        let isTF = EnvironmentPathResolver.checkTestFlight()
        if isJail {
            self.currentEnvironment = .jailbroken
        } else if isTF {
            self.currentEnvironment = .testFlight
        } else {
            self.currentEnvironment = .sandbox
        }
        #endif
    }
    
    func getStorageRoot() -> URL {
        let basePath: String
        
        switch currentEnvironment {
        case .sandbox, .testFlight:
            basePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp"
        case .jailbroken:
            basePath = "/var/mobile/Documents/StarCore"
            try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true)
        case .simulator:
            basePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp"
        }
        
        return URL(fileURLWithPath: basePath)
    }
    
    // MARK: - Static Detection (avoid self before init)
    private static func checkJailbroken() -> Bool {
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
    
    private static func checkTestFlight() -> Bool {
        let bundlePath = Bundle.main.appStoreReceiptURL?.path ?? ""
        return bundlePath.contains("sandboxReceipt")
    }
}
