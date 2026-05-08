import Foundation
import UIKit

/// 持久化统计（不放入CoreState，运行时辅助用）
struct PersistedStats {
    var totalBackups: Int = 0
    var launchCount: Int = 0
}

/// 生命核心引擎 - 阶段十：生命中枢
@available(iOS 15.0, *)
final class LifeCore: ObservableObject {
    // MARK: - Published Properties
    @Published var heartRate: Int = 72
    @Published var energyLevel: Float = 1.0
    @Published var bodyTemperature: Float = 36.6
    @Published var fatigueLevel: Float = 0.0
    @Published var cryptobiosisActive: Bool = false
    @Published var backupStatus: BackupStatus = .idle
    @Published var lastBackupDate: Date?
    @Published var systemLogs: [SystemLog] = []
    
    // MARK: - Private Properties
    private var heartbeatTimer: Timer?
    private var backupTimer: Timer?
    private let storage = CoreStorage()
    
    // MARK: - Survival Modules
    let tardigradeMode: TardigradeMode
    let planarianRegen: PlanarianRegen
    let bdelloidPersist: BdelloidPersist
    let jellyfishReset: JellyfishReset
    
    // MARK: - Body Engine
    let bodyEngine: BodyEngine
    
    // MARK: - Initialization
    // 持久化统计（从备份恢复）
    private var persistedStats = PersistedStats()
    
    init() {
        self.bodyEngine = BodyEngine()
        self.bdelloidPersist = BdelloidPersist()
        self.jellyfishReset = JellyfishReset()
        self.tardigradeMode = TardigradeMode()
        self.planarianRegen = PlanarianRegen()
        
        self.tardigradeMode.bind(lifeCore: self)
        self.planarianRegen.bind(lifeCore: self)
        
        performStartupCheck()
        startHeartbeat()
        startPeriodicBackup()
        attemptRecovery()
        scheduleFirstBackup()
        registerLifecycleObservers()
        
        addLog(.info, "LifeCore 初始化完成")
    }
    
    deinit {
        heartbeatTimer?.invalidate()
        backupTimer?.invalidate()
    }
    
    // MARK: - Startup Check
    private func performStartupCheck() {
        addLog(.info, "启动自检开始...")
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
    
    private var heartbeatCount = 0
    
    private func updateVitalSigns() {
        let hardwareData = bodyEngine.getCurrentData()
        heartRate = hardwareData.heartRate
        energyLevel = hardwareData.energyLevel
        bodyTemperature = hardwareData.bodyTemperature
        fatigueLevel = hardwareData.fatigueLevel
        checkCryptobiosisTrigger()
        
        // 每60秒输出一条运行日志
        heartbeatCount += 1
        if heartbeatCount % 60 == 0 {
            addLog(.info, "心跳:\(heartRate)bpm 能量:\(Int(energyLevel*100))% 体温:\(String(format: "%.1f", bodyTemperature))℃ 疲劳:\(Int(fatigueLevel*100))%")
        }
    }
    
    // MARK: - Cryptobiosis
    private func checkCryptobiosisTrigger() {
        if energyLevel < 0.20 && !cryptobiosisActive {
            enterCryptobiosis()
        } else if energyLevel >= 0.20 && cryptobiosisActive {
            exitCryptobiosis()
        }
    }
    
    private func enterCryptobiosis() {
        cryptobiosisActive = true
        addLog(.warning, "进入隐生模式 - 能量过低")
        tardigradeMode.enterCryptobiosis()
        NotificationCenter.default.post(name: .cryptobiosisEntered, object: nil)
    }
    
    private func exitCryptobiosis() {
        cryptobiosisActive = false
        addLog(.success, "退出隐生模式 - 能量已恢复")
        tardigradeMode.exitCryptobiosis()
        NotificationCenter.default.post(name: .cryptobiosisExited, object: nil)
    }
    
    // MARK: - Backup
    private func startPeriodicBackup() {
        // 每5分钟自动备份
        backupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.performBackup()
        }
    }
    
    /// 启动后60秒执行首次备份
    private func scheduleFirstBackup() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.performBackup()
        }
    }
    
    /// 监听app生命周期，进入后台时保存
    private func registerLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.performBackup()
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
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
            timestamp: Date(),
            totalRecoveries: planarianRegen.totalRecoveries,
            totalResets: jellyfishReset.numberOfResets,
            lastResetDate: jellyfishReset.lastReset,
            totalBackups: persistedStats.totalBackups + 1,
            launchCount: persistedStats.launchCount
        )
        storage.saveBackup(state) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.lastBackupDate = Date()
                    self?.backupStatus = .completed
                    self?.persistedStats.totalBackups += 1
                    self?.addLog(.success, "备份完成(累计\(self?.persistedStats.totalBackups ?? 0)次)")
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
                guard let self = self else { return }
                if let state = state {
                    // 恢复持久化统计
                    self.persistedStats = PersistedStats(
                        totalBackups: state.totalBackups,
                        launchCount: state.launchCount + 1
                    )
                    // 恢复涡虫再生计数（从上次备份恢复+1）
                    self.planarianRegen.setRecoveryCount(state.totalRecoveries + 1)
                    // 恢复灯塔重置状态
                    self.jellyfishReset.restoreState(count: state.totalResets, lastDate: state.lastResetDate)
                    
                    self.performRecovery(from: state)
                    self.addLog(.success, "涡虫再生：从备份恢复，累计恢复\(self.planarianRegen.totalRecoveries)次，启动\(self.persistedStats.launchCount)次")
                } else {
                    self.persistedStats.launchCount = 1
                    self.addLog(.info, "首次启动，无历史备份可恢复")
                }
            }
        }
    }
    
    private func performRecovery(from state: CoreState) {
        addLog(.info, "正在从备份恢复上次状态...")
        // 恢复上次保存的状态作为初始参考
        bodyTemperature = state.bodyTemperature
        cryptobiosisActive = state.cryptobiosisActive
        // 心率和能量水平从实时硬件读取（更准确），不使用旧值
        addLog(.info, "状态恢复完成，硬件数据实时采集中")
    }
    
    // MARK: - Logging
    func addLog(_ level: LogLevel, _ message: String) {
        let log = SystemLog(level: level, message: message, timestamp: Date())
        DispatchQueue.main.async {
            self.systemLogs.append(log)
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
    
    // 持久化生存统计
    var totalRecoveries: Int = 0       // 涡虫再生累计次数
    var totalResets: Int = 0           // 灯塔重置累计次数
    var lastResetDate: Date?           // 上次重置时间
    var totalBackups: Int = 0          // 累计备份次数
    var launchCount: Int = 0           // 累计启动次数
}

extension Notification.Name {
    static let cryptobiosisEntered = Notification.Name("cryptobiosisEntered")
    static let cryptobiosisExited = Notification.Name("cryptobiosisExited")
}
