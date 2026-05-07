import Foundation

/// 生命核心引擎 - 阶段十：生命中枢
/// 负责生命体征监控、隐生模式、定期备份和恢复机制
@available(iOS 15.0, *)
final class LifeCore: ObservableObject {
    // MARK: - Published Properties (生命体征)
    @Published var heartRate: Int = 72              // 心率 (CPU使用率映射)
    @Published var energyLevel: Float = 1.0        // 能量 (电池电量)
    @Published var bodyTemperature: Float = 36.6   // 体温 (设备温度)
    @Published var fatigueLevel: Float = 0.0       // 疲劳度 (CPU持续负载)
    @Published var cryptobiosisActive: Bool = false // 隐生状态
    @Published var backupStatus: BackupStatus = .idle
    @Published var lastBackupDate: Date?
    @Published var systemLogs: [SystemLog] = []
    
    // MARK: - Private Properties
    private var heartbeatTimer: Timer?
    private var backupTimer: Timer?
    private let storage = CoreStorage()
    
    // MARK: - Survival Modules (生存模块)
    let tardigradeMode: TardigradeMode
    let planarianRegen: PlanarianRegen
    let bdelloidPersist: BdelloidPersist
    let jellyfishReset: JellyfishReset
    
    // MARK: - Body Engine
    let bodyEngine: BodyEngine
    
    // MARK: - Initialization
    init() {
        // 初始化生存模块
        self.tardigradeMode = TardigradeMode(lifeCore: self)
        self.planarianRegen = PlanarianRegen(lifeCore: self)
        self.bdelloidPersist = BdelloidPersist()
        self.jellyfishReset = JellyfishReset()
        self.bodyEngine = BodyEngine()
        
        // 启动自检
        performStartupCheck()
        
        // 启动心跳循环
        startHeartbeat()
        
        // 启动定期备份 (每30分钟)
        startPeriodicBackup()
        
        // 尝试从备份恢复
        attemptRecovery()
        
        addLog(.info, "LifeCore 初始化完成")
    }
    
    deinit {
        heartbeatTimer?.invalidate()
        backupTimer?.invalidate()
    }
    
    // MARK: - Startup Check
    private func performStartupCheck() {
        addLog(.info, "启动自检开始...")
        
        // 检查备份完整性
        let backupIntact = storage.verifyBackupIntegrity()
        if backupIntact {
            addLog(.success, "备份完整性检查通过")
        } else {
            addLog(.warning, "备份完整性检查失败，将创建新备份")
        }
        
        addLog(.info, "启动自检完成")
    }
    
    // MARK: - Heartbeat Loop
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateVitalSigns()
        }
    }
    
    private func updateVitalSigns() {
        // 更新生理数据
        let hardwareData = bodyEngine.getCurrentData()
        
        heartRate = hardwareData.heartRate
        energyLevel = hardwareData.energyLevel
        bodyTemperature = hardwareData.bodyTemperature
        fatigueLevel = hardwareData.fatigueLevel
        
        // 检查隐生条件
        checkCryptobiosisTrigger()
    }
    
    // MARK: - Cryptobiosis (隐生模式)
    private func checkCryptobiosisTrigger() {
        let shouldEnterCryptobiosis = energyLevel < 0.20 && !cryptobiosisActive
        
        if shouldEnterCryptobiosis {
            enterCryptobiosis()
        } else if energyLevel >= 0.20 && cryptobiosisActive {
            exitCryptobiosis()
        }
    }
    
    private func enterCryptobiosis() {
        cryptobiosisActive = true
        addLog(.warning, "进入隐生模式 - 能量过低")
        tardigradeMode.enterCryptobiosis()
        
        // 通知上层停止非必要功能
        NotificationCenter.default.post(name: .cryptobiosisEntered, object: nil)
    }
    
    private func exitCryptobiosis() {
        cryptobiosisActive = false
        addLog(.success, "退出隐生模式 - 能量已恢复")
        tardigradeMode.exitCryptobiosis()
        
        NotificationCenter.default.post(name: .cryptobiosisExited, object: nil)
    }
    
    // MARK: - Backup System
    private func startPeriodicBackup() {
        backupTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.performBackup()
        }
    }
    
    func performBackup() {
        backupStatus = .inProgress
        addLog(.info, "开始备份核心状态...")
        
        let state = CoreState(
            heartRate: heartRate,
            energyLevel: energyLevel,
            bodyTemperature: bodyTemperature,
            fatigueLevel: fatigueLevel,
            cryptobiosisActive: cryptobiosisActive,
            timestamp: Date()
        )
        
        storage.saveBackup(state) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.lastBackupDate = Date()
                    self?.backupStatus = .completed
                    self?.addLog(.success, "备份完成")
                } else {
                    self?.backupStatus = .failed
                    self?.addLog(.error, "备份失败")
                }
            }
        }
    }
    
    // MARK: - Recovery
    private func attemptRecovery() {
        storage.loadBackup { [weak self] state in
            DispatchQueue.main.async {
                guard let self = self, let state = state else { return }
                
                // 检测是否需要恢复 (异常状态检测)
                if self.detectAnomaly(state: state) {
                    self.performRecovery(from: state)
                }
            }
        }
    }
    
    private func detectAnomaly(state: CoreState) -> Bool {
        // 检测异常：体温过高/过低，心率为0等
        return state.bodyTemperature < 35.0 || state.bodyTemperature > 40.0 || state.heartRate == 0
    }
    
    private func performRecovery(from state: CoreState) {
        addLog(.warning, "检测到异常，正在从备份恢复...")
        
        heartRate = state.heartRate
        energyLevel = state.energyLevel
        bodyTemperature = state.bodyTemperature
        fatigueLevel = state.fatigueLevel
        cryptobiosisActive = state.cryptobiosisActive
        
        addLog(.success, "从备份恢复完成")
        planarianRegen.incrementRecoveryCount()
    }
    
    // MARK: - Logging
    func addLog(_ level: LogLevel, _ message: String) {
        let log = SystemLog(level: level, message: message, timestamp: Date())
        DispatchQueue.main.async {
            self.systemLogs.append(log)
            // 保持最近100条日志
            if self.systemLogs.count > 100 {
                self.systemLogs.removeFirst()
            }
        }
    }
}

// MARK: - Supporting Types
enum BackupStatus {
    case idle, inProgress, completed, failed
}

enum LogLevel: String {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    case success = "OK"
}

struct SystemLog: Identifiable {
    let id = UUID()
    let level: LogLevel
    let message: String
    let timestamp: Date
}

struct CoreState: Codable {
    let heartRate: Int
    let energyLevel: Float
    let bodyTemperature: Float
    let fatigueLevel: Float
    let cryptobiosisActive: Bool
    let timestamp: Date
}

// MARK: - Notifications
extension Notification.Name {
    static let cryptobiosisEntered = Notification.Name("cryptobiosisEntered")
    static let cryptobiosisExited = Notification.Name("cryptobiosisExited")
}
