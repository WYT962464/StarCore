import Foundation

/// 生存锁 - 阶段十：生命中枢
/// 实现代码层面的隔离机制，确保底层核心不被上层意外修改
/// 注：物理隔离依赖于架构设计，本文件提供代码层面的断言和日志
final class SurvivalLock {
    private let lockQueue = DispatchQueue(label: "com.starcor.lock.survival", qos: .userInitiated)
    
    // MARK: - Read/Write State
    private var isLocked: Bool = false
    private var writeAttemptCount: Int = 0
    private var lastWriteAttemptTime: Date?
    
    // MARK: - Lock Mechanism
    /// 尝试获取写锁
    /// - Returns: 是否成功获取写锁
    func tryAcquireWriteLock() -> Bool {
        return lockQueue.sync {
            if isLocked {
                writeAttemptCount += 1
                lastWriteAttemptTime = Date()
                logWriteAttempt()
                return false
            }
            return true
        }
    }
    
    /// 释放写锁
    func releaseWriteLock() {
        lockQueue.sync {
            // 写锁只能由持有者释放，这里简化处理
        }
    }
    
    /// 触发熔断 - 永久锁定写操作
    func triggerCircuitBreaker() {
        lockQueue.sync {
            isLocked = true
            logCircuitBreaker()
        }
    }
    
    // MARK: - Assertions
    /// 断言只读访问 - 用于MindCore尝试写入时检测
    func assertReadOnlyAccess(file: String = #file, line: Int = #line) {
        // 在debug模式下记录只读访问
        #if DEBUG
        print("[SurvivalLock] 只读访问 from \(file):\(line)")
        #endif
    }
    
    /// 断言写入尝试 - 检测违规写入
    func assertWriteAttempt(file: String = #file, line: Int = #line) {
        #if DEBUG
        let success = tryAcquireWriteLock()
        if !success {
            print("[SurvivalLock] 警告：非法写入尝试被阻止 from \(file):\(line)")
        }
        #endif
    }
    
    // MARK: - Logging
    private func logWriteAttempt() {
        print("[SurvivalLock] 写锁已被占用，尝试次数: \(writeAttemptCount)")
    }
    
    private func logCircuitBreaker() {
        print("[SurvivalLock] 熔断器已触发 - 所有写入操作已永久禁用")
    }
    
    // MARK: - Status
    var isWriteProtected: Bool {
        return lockQueue.sync { isLocked }
    }
    
    var totalWriteAttempts: Int {
        return lockQueue.sync { writeAttemptCount }
    }
}
