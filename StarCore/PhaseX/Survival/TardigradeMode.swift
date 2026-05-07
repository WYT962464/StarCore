import Foundation

/// 水熊虫模式 - 隐生抗逆
/// 参考真实水熊虫的隐生能力，在极端环境下进入低功耗状态
final class TardigradeMode {
    private weak var lifeCore: LifeCore?
    private var isInCryptobiosis: Bool = false
    private var cryptobiosisStartTime: Date?
    
    // 隐生状态持续时间
    private(set) var cryptobiosisDuration: TimeInterval = 0
    
    // 触发阈值
    private let energyThreshold: Float = 0.20  // 20%电量触发隐生
    
    init(lifeCore: LifeCore) {
        self.lifeCore = lifeCore
    }
    
    // MARK: - Cryptobiosis Control
    func enterCryptobiosis() {
        guard !isInCryptobiosis else { return }
        
        isInCryptobiosis = true
        cryptobiosisStartTime = Date()
        
        lifeCore?.addLog(.info, "Tardigrade: 进入隐生状态")
        lifeCore?.addLog(.info, "Tardigrade: 暂停非必要功能，降低代谢")
    }
    
    func exitCryptobiosis() {
        guard isInCryptobiosis else { return }
        
        if let startTime = cryptobiosisStartTime {
            cryptobiosisDuration = Date().timeIntervalSince(startTime)
            lifeCore?.addLog(.success, "Tardigrade: 退出隐生，持续\(Int(cryptobiosisDuration))秒")
        }
        
        isInCryptobiosis = false
        cryptobiosisStartTime = nil
    }
    
    // MARK: - Status
    var isActive: Bool {
        return isInCryptobiosis
    }
    
    /// 检查是否应该进入隐生
    func shouldEnterCryptobiosis(energyLevel: Float) -> Bool {
        return energyLevel < energyThreshold && !isInCryptobiosis
    }
    
    /// 检查是否可以退出隐生
    func canExitCryptobiosis(energyLevel: Float) -> Bool {
        return energyLevel >= energyThreshold && isInCryptobiosis
    }
}
