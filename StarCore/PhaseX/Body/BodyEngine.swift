import Foundation
import UIKit

/// 生理引擎 - 复用旧的硬件传感器数据映射逻辑
/// 将硬件指标映射为生命体征
final class BodyEngine {
    private let hardwareSensor = HardwareSensor()
    
    // 历史数据用于计算趋势
    private var heartRateHistory: [Int] = []
    private var energyHistory: [Float] = []
    
    init() {}
    
    // MARK: - Data Mapping
    /// 获取当前生理数据
    func getCurrentData() -> VitalSigns {
        let cpuUsage = hardwareSensor.getCPUUsage()
        let batteryLevel = hardwareSensor.getBatteryLevel()
        let thermalState = hardwareSensor.getThermalState()
        
        // CPU使用率 -> 心率 (60-120范围)
        let heartRate = mapCPUToHeartRate(cpuUsage)
        
        // 电池电量 -> 能量水平
        let energyLevel = batteryLevel
        
        // 热状态 -> 体温 (35.0-40.0范围)
        let bodyTemperature = mapThermalToTemperature(thermalState)
        
        // CPU持续负载 -> 疲劳度
        let fatigueLevel = calculateFatigueLevel()
        
        // 更新历史
        updateHistory(heartRate: heartRate, energy: energyLevel)
        
        return VitalSigns(
            heartRate: heartRate,
            energyLevel: energyLevel,
            bodyTemperature: bodyTemperature,
            fatigueLevel: fatigueLevel
        )
    }
    
    // MARK: - Mapping Functions
    private func mapCPUToHeartRate(_ cpuUsage: Float) -> Int {
        // CPU使用率 0-100% 映射到心率 60-120
        let minHR = 60
        let maxHR = 120
        let rate = minHR + Int(cpuUsage * Float(maxHR - minHR) / 100)
        return min(max(rate, minHR), maxHR)
    }
    
    private func mapThermalToTemperature(_ state: ProcessInfo.ThermalState) -> Float {
        // 基础体温由热状态决定
        let baseTemp: Float
        switch state {
        case .nominal:
            baseTemp = 36.5
        case .fair:
            baseTemp = 37.0
        case .serious:
            baseTemp = 38.0
        case .critical:
            baseTemp = 39.0
        @unknown default:
            baseTemp = 36.5
        }
        // CPU负载微调体温（0-100% CPU -> +0~0.8℃）
        let cpuUsage = hardwareSensor.getCPUUsage()
        let cpuTempBoost = cpuUsage * 0.008
        // 加入微小随机波动（模拟真实体温±0.1℃）
        let noise = Float.random(in: -0.1...0.1)
        return baseTemp + cpuTempBoost + noise
    }
    
    private func calculateFatigueLevel() -> Float {
        // 基于CPU使用率历史计算疲劳度
        guard !heartRateHistory.isEmpty else { return 0.0 }
        
        let recentHRs = Array(heartRateHistory.suffix(10))
        let avgHR = recentHRs.reduce(0, +) / recentHRs.count
        
        // 心率持续高于80表示疲劳
        let fatigue = Float(max(0, avgHR - 80)) / 40.0
        return min(fatigue, 1.0)
    }
    
    private func updateHistory(heartRate: Int, energy: Float) {
        heartRateHistory.append(heartRate)
        energyHistory.append(energy)
        
        // 保持最近60条记录
        if heartRateHistory.count > 60 {
            heartRateHistory.removeFirst()
        }
        if energyHistory.count > 60 {
            energyHistory.removeFirst()
        }
    }
    
    // MARK: - Trend Analysis
    func getEnergyTrend() -> Trend {
        guard energyHistory.count >= 5 else { return .stable }
        
        let recent = Array(energyHistory.suffix(5))
        let first = recent.first ?? 0
        let last = recent.last ?? 0
        
        if last < first - 0.1 {
            return .declining
        } else if last > first + 0.1 {
            return .rising
        }
        return .stable
    }
    
    func getHeartRateTrend() -> Trend {
        guard heartRateHistory.count >= 5 else { return .stable }
        
        let recent = Array(heartRateHistory.suffix(5))
        let avgRecent = recent.reduce(0, +) / recent.count
        let avgAll = heartRateHistory.reduce(0, +) / heartRateHistory.count
        
        if avgRecent > avgAll + 5 {
            return .rising
        } else if avgRecent < avgAll - 5 {
            return .declining
        }
        return .stable
    }
}

// MARK: - Supporting Types
struct VitalSigns {
    let heartRate: Int
    let energyLevel: Float
    let bodyTemperature: Float
    let fatigueLevel: Float
}

enum Trend {
    case rising, stable, declining
}
