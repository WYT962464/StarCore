import Foundation

struct DailyStats: Codable {
    let date: String
    var batteryMin: Float = 1.0
    var batteryMax: Float = 0.0
    var batteryAvg: Float = 0.0
    var batterySamples: Int = 0
    var batterySum: Float = 0
    
    var cpuMin: Double = 100
    var cpuMax: Double = 0
    var cpuAvg: Double = 0
    var cpuSamples: Int = 0
    var cpuSum: Double = 0
    
    var memoryMin: Double = 100
    var memoryMax: Double = 0
    var memoryAvg: Double = 0
    var memorySamples: Int = 0
    var memorySum: Double = 0
    
    var hexagramChanges: Int = 0
    var dominantHexagram: String = ""
    var hexagramCounts: [String: Int] = [:]
    
    var chargingEvents: Int = 0
    var fullChargeEvents: Int = 0
    
    var peakHour: Int = -1  // CPU最高的时段
    var peakHourCpu: Double = 0
    var idleHour: Int = -1  // CPU最低的时段
    var idleHourCpu: Double = 100
    
    mutating func record(battery: Float, cpu: Double, memory: Double, hexagram: String, hour: Int) {
        // 气血
        batterySamples += 1; batterySum += battery
        if battery < batteryMin { batteryMin = battery }
        if battery > batteryMax { batteryMax = battery }
        batteryAvg = batterySum / Float(batterySamples)
        
        // 心跳
        cpuSamples += 1; cpuSum += cpu
        if cpu < cpuMin { cpuMin = cpu }
        if cpu > cpuMax { cpuMax = cpu }
        cpuAvg = cpuSum / Double(cpuSamples)
        if cpu > peakHourCpu { peakHour = hour; peakHourCpu = cpu }
        if cpu < idleHourCpu { idleHour = hour; idleHourCpu = cpu }
        
        // 思维
        memorySamples += 1; memorySum += memory
        if memory < memoryMin { memoryMin = memory }
        if memory > memoryMax { memoryMax = memory }
        memoryAvg = memorySum / Double(memorySamples)
        
        // 卦象
        hexagramCounts[hexagram, default: 0] += 1
        if let maxEntry = hexagramCounts.max(by: { $0.value < $1.value }) {
            dominantHexagram = maxEntry.key
        }
    }
    
    mutating func recordHexagramChange() { hexagramChanges += 1 }
    mutating func recordCharging() { chargingEvents += 1 }
    mutating func recordFullCharge() { fullChargeEvents += 1 }
    
    static func todayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
}

class DailyStatsManager: ObservableObject {
    @Published var today: DailyStats
    private let statsURL: URL
    private let historyURL: URL
    
    init() {
        let dirs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        self.statsURL = dirs[0].appendingPathComponent("starcore_daily.json")
        self.historyURL = dirs[0].appendingPathComponent("starcore_history.json")
        
        let key = DailyStats.todayKey()
        if let data = try? Data(contentsOf: statsURL),
           let stats = try? JSONDecoder().decode(DailyStats.self, from: data),
           stats.date == key {
            self.today = stats
        } else {
            self.today = DailyStats(date: key)
        }
    }
    
    func record(battery: Float, cpu: Double, memory: Double, hexagram: String, hour: Int) {
        today.record(battery: battery, cpu: cpu, memory: memory, hexagram: hexagram, hour: hour)
        save()
    }
    
    func recordHexagramChange() { today.recordHexagramChange(); save() }
    func recordCharging() { today.recordCharging(); save() }
    func recordFullCharge() { today.recordFullCharge(); save() }
    
    func save() {
        if let data = try? JSONEncoder().encode(today) {
            try? data.write(to: statsURL)
        }
    }
    
    // 保存到历史（每日结束时调用）
    func archiveToHistory() {
        var history: [DailyStats] = []
        if let data = try? Data(contentsOf: historyURL),
           let h = try? JSONDecoder().decode([DailyStats].self, from: data) {
            history = h
        }
        // 避免重复
        if !history.contains(where: { $0.date == today.date }) {
            history.append(today)
            if history.count > 30 { history.removeFirst() } // 保留30天
            if let data = try? JSONEncoder().encode(history) {
                try? data.write(to: historyURL)
            }
        }
    }
    
    func loadHistory() -> [DailyStats] {
        if let data = try? Data(contentsOf: historyURL),
           let h = try? JSONDecoder().decode([DailyStats].self, from: data) {
            return h
        }
        return []
    }
}
