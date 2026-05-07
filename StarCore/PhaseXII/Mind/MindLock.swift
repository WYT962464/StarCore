import Foundation

/// 认知锁 - 熔断检测，阻止上层写入底层
final class MindLock {
    private let lock = NSLock()
    private var circuitBroken = false
    private var writeAttempts: [(timestamp: Date, value: Any)] = []
    
    // 熔断阈值
    private let threshold = 3
    private var attemptCount = 0
    
    // MARK: - Write Attempt
    /// 尝试写入操作
    /// - Returns: 是否成功 (失败表示被锁阻止)
    func tryWrite(value: Any) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // 如果熔断器已触发，阻止所有写入
        if circuitBroken {
            recordAttempt(value)
            triggerCircuitBreaker()
            return false
        }
        
        // 记录写入尝试
        attemptCount += 1
        writeAttempts.append((Date(), value))
        
        // 检查是否触发熔断
        if attemptCount >= threshold {
            circuitBroken = true
            triggerCircuitBreaker()
            return false
        }
        
        return true
    }
    
    // MARK: - Circuit Breaker
    private func triggerCircuitBreaker() {
        print("[MindLock] ⚠️ 熔断器已触发 - 认知层写入底层被永久阻止")
        print("[MindLock] 这表明上层尝试修改下层核心，已被架构隔离阻止")
        
        // 发送通知
        NotificationCenter.default.post(
            name: .mindLockCircuitBreaker,
            object: nil,
            userInfo: ["attempts": writeAttempts]
        )
    }
    
    // MARK: - Record
    private func recordAttempt(_ value: Any) {
        writeAttempts.append((Date(), value))
        
        // 保持最近10条记录
        if writeAttempts.count > 10 {
            writeAttempts.removeFirst()
        }
    }
    
    // MARK: - Status
    var isBroken: Bool {
        return circuitBroken
    }
    
    var numberOfAttempts: Int {
        return attemptCount
    }
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        circuitBroken = false
        attemptCount = 0
        writeAttempts.removeAll()
        
        print("[MindLock] 熔断器已重置")
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let mindLockCircuitBreaker = Notification.Name("mindLockCircuitBreaker")
}
