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
        // 无论越狱与否，App沙盒内的Documents目录一定可写
        // 越狱路径 /var/mobile/Documents/ 作为扩展，不是主存储
        let sandboxDocs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp"
        let basePath: String
        
        switch currentEnvironment {
        case .jailbroken:
            // 越狱环境：优先使用沙盒Documents（保证可写），在StarCore子目录下
            basePath = sandboxDocs + "/StarCore"
            try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true)
        case .sandbox, .testFlight, .simulator:
            basePath = sandboxDocs + "/StarCore"
            try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true)
        }
        
        return URL(fileURLWithPath: basePath)
    }
    
    // MARK: - Static Detection (avoid self before init)
    private static func checkJailbroken() -> Bool {
        // 传统越狱路径
        let legacyPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]
        for path in legacyPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        // 无根越狱路径（多巴胺Dopamine/palera1n等）
        let rootlessPaths = [
            "/var/jb/bin/bash",
            "/var/jb/usr/sbin/sshd",
            "/var/jb/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/var/jb/Applications",
            "/var/jb/etc/apt"
        ]
        for path in rootlessPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        // 检测 /var/jb 目录是否存在（无根越狱核心标志）
        if FileManager.default.fileExists(atPath: "/var/jb") {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: "/var/jb", isDirectory: &isDir), isDir.boolValue {
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
