import Foundation

/// 灯塔水母模式 - 逆分化重置
/// 参考灯塔水母的生物学逆分化过程，实现系统状态重置
final class JellyfishReset {
    private(set) var lastResetDate: Date?
    private var resetCount: Int = 0
    private var scheduledResetTimer: Timer?
    
    // 重置间隔 (默认7天)
    private let resetInterval: TimeInterval = 7 * 24 * 60 * 60
    
    // 可选的重置回调
    var onBeforeReset: (() -> Void)?
    var onAfterReset: (() -> Void)?
    
    init() {}
    
    // MARK: - Reset Control
    /// 执行重置操作
    func performReset() {
        onBeforeReset?()
        
        resetCount += 1
        lastResetDate = Date()
        
        // 清理缓存
        clearCaches()
        
        // 重置非核心状态
        resetTransientState()
        
        onAfterReset?()
        
        print("[JellyfishReset] 重置完成，已执行\(resetCount)次")
    }
    
    /// 清理缓存
    private func clearCaches() {
        // 清理URL缓存
        URLCache.shared.removeAllCachedResponses()
        
        // 清理临时文件
        let tempDir = FileManager.default.temporaryDirectory
        try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .forEach { try? FileManager.default.removeItem(at: $0) }
    }
    
    /// 重置临时状态
    private func resetTransientState() {
        // 重置UserDefaults中的临时数据
        let defaults = UserDefaults.standard
        let transientKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("transient_") }
        transientKeys.forEach { defaults.removeObject(forKey: $0) }
    }
    
    // MARK: - Scheduled Reset
    /// 启动定期重置调度
    func startScheduledReset() {
        scheduledResetTimer = Timer.scheduledTimer(withTimeInterval: resetInterval, repeats: true) { [weak self] _ in
            self?.performReset()
        }
    }
    
    /// 停止定期重置
    func stopScheduledReset() {
        scheduledResetTimer?.invalidate()
        scheduledResetTimer = nil
    }
    
    // MARK: - Manual Reset
    /// 手动触发重置
    func manualReset() {
        performReset()
    }
    
    // MARK: - Status
    var numberOfResets: Int {
        return resetCount
    }
    
    var lastReset: Date? {
        return lastResetDate
    }
    
    var nextScheduledReset: Date? {
        guard let last = lastResetDate else { return Date() }
        return last.addingTimeInterval(resetInterval)
    }
}
