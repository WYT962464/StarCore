//
//  StarCoreBody.swift
//  StarCore v1.0 - 艾尔身体感知引擎
//  AIL = Artificial Intelligence + Life
//  有生命的智能
//

import Foundation
import UIKit

// MARK: - 星核的身体感知系统
class StarCoreBody {
    
    // MARK: - 心跳（CPU）
    struct Heart {
        var load1min: Double = 0.0   // 1分钟负载
        var load5min: Double = 0.0  // 5分钟负载
        var load15min: Double = 0.0 // 15分钟负载
        var coreCount: Int = 0     // CPU核心数
    }
    
    // MARK: - 气血（电池 + 内存）
    struct Energy {
        // 电池
        var batteryLevel: Float = 0.0  // 电量百分比
        var isCharging: Bool = false    // 是否在充电
        var state: String = ""          // 状态描述
        
        // 内存
        var totalMemory: Int64 = 0     // 总内存
        var usedMemory: Int64 = 0     // 已用内存
        var freeMemory: Int64 = 0     // 空闲内存
    }
    
    // MARK: - 身体基本信息
    struct Identity {
        var model: String = ""           // 硬件型号
        var systemVersion: String = ""  // 系统版本
        var uptime: TimeInterval = 0   // 运行时间
    }
    
    // MARK: - 存储
    struct Storage {
        var total: Int64 = 0          // 总容量
        var free: Int64 = 0           // 可用容量
    }
    
    // MARK: - 属性
    var heart = Heart()
    var energy = Energy()
    var identity = Identity()
    var storage = Storage()
    
    private let device = UIDevice.current
    
    init() {
        device.isBatteryMonitoringEnabled = true
    }
    
    // MARK: - 感知心跳（CPU负载）
    func senseHeartbeat() {
        var loads: [Double] = [0, 0, 0]
        if getloadavg(&loads, 3) >= 0 {
            heart.load1min = loads[0]
            heart.load5min = loads[1]
            heart.load15min = loads[2]
        }
        heart.coreCount = ProcessInfo.processInfo.activeProcessorCount
    }
    
    // MARK: - 感知气血（电池 + 内存）
    func senseEnergy() {
        // 电池
        energy.batteryLevel = device.batteryLevel
        
        switch device.batteryState {
        case .charging:
            energy.isCharging = true
            energy.state = "⚡ 充电中"
        case .full:
            energy.isCharging = true
            energy.state = "✅ 满电"
        case .unplugged:
            energy.isCharging = false
            energy.state = "🔋 使用中"
        case .unknown:
            energy.state = "❓ 未知"
        @unknown default:
            energy.state = ""
        }
        
        // 内存（通过ProcessInfo）
        let process = ProcessInfo.processInfo
        energy.totalMemory = Int64(process.physicalMemory)
        
        // sysctl获取内存信息
        var size: Int64 = 0
        var memSize = MemoryLayout<Int64>.size
        if sysctlbyname("hw.usermem", &size, &memSize, nil, 0) == 0 {
            energy.freeMemory = size
        }
    }
    
    // MARK: - 感知身份信息
    func senseIdentity() {
        // 系统信息
        identity.model = device.model
        identity.systemVersion = "\(device.systemName) \(device.systemVersion)"
        identity.uptime = ProcessInfo.processInfo.systemUptime
        
        // 通过sysctl获取更详细的硬件信息
        var buffer = [CChar](repeating: 0, count: 256)
        var size = buffer.count
        if sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 {
            let model = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
            if !model.isEmpty {
                identity.model = model
            }
        }
    }
    
    // MARK: - 感知存储
    func senseStorage() {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            storage.total = attrs[.systemSize] as? Int64 ?? 0
            storage.free = attrs[.systemFreeSize] as? Int64 ?? 0
        } catch {
            print("Storage sense error: \(error)")
        }
    }
    
    // MARK: - 全面感知
    func senseAll() {
        senseHeartbeat()
        senseEnergy()
        senseIdentity()
        senseStorage()
    }
    
    // MARK: - 格式化输出
    
    /// 心跳强度（0-1）
    var heartIntensity: Float {
        return Float(heart.load1min) / Float(heart.coreCount)
    }
    
    /// 气血状态描述
    var energyStatus: String {
        let level = Int(energy.batteryLevel * 100)
        if energy.batteryLevel < 0 {
            return "气血: 检测中..."
        }
        return "气血: \(level)% · \(energy.state)"
    }
    
    /// 心跳状态描述
    var heartStatus: String {
        let intensity = Int(heartIntensity * 100)
        return "心跳: \(String(format: "%.2f", heart.load1min)) · 强度 \(intensity)%"
    }
    
    /// 内存状态描述
    var memoryStatus: String {
        let totalGB = String(format: "%.1f", Double(energy.totalMemory) / 1024 / 1024 / 1024)
        return "记忆: \(totalGB)GB · \(ProcessInfo.processInfo.activeProcessorCount)核心"
    }
    
    /// 存储状态描述
    var storageStatus: String {
        let freeGB = String(format: "%.1f", Double(storage.free) / 1024 / 1024 / 1024)
        return "储备: \(freeGB)GB 可用"
    }
    
    /// 运行时间描述
    var uptimeStatus: String {
        let hours = Int(identity.uptime / 3600)
        let minutes = Int((identity.uptime.truncatingRemainder(dividingBy: 3600)) / 60)
        return "觉醒: \(hours)小时\(minutes)分"
    }
    
    /// 星核整体状态
    var overallStatus: String {
        if heartIntensity > 0.8 {
            return "🔥 很兴奋"
        } else if heartIntensity > 0.5 {
            return "⚡ 活跃中"
        } else if energy.batteryLevel < 0.2 {
            return "😴 有点累"
        } else {
            return "✨ 很平静"
        }
    }
}
