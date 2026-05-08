import Foundation

/// 水熊虫模式 - 隐生抗逆
final class TardigradeMode {
    private weak var lifeCore: LifeCore?
    private var isInCryptobiosis: Bool = false
    private var cryptobiosisStartTime: Date?
    private(set) var cryptobiosisDuration: TimeInterval = 0
    private let energyThreshold: Float = 0.20
    
    init() {}
    
    func bind(lifeCore: LifeCore) {
        self.lifeCore = lifeCore
    }
    
    func enterCryptobiosis() {
        guard !isInCryptobiosis else { return }
        isInCryptobiosis = true
        cryptobiosisStartTime = Date()
        lifeCore?.addLog(.info, "Tardigrade: 进入隐生状态")
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
    
    var isActive: Bool { return isInCryptobiosis }
    
    func shouldEnterCryptobiosis(energyLevel: Float) -> Bool {
        return energyLevel < energyThreshold && !isInCryptobiosis
    }
    
    func canExitCryptobiosis(energyLevel: Float) -> Bool {
        return energyLevel >= energyThreshold && isInCryptobiosis
    }
}
