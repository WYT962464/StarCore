import Foundation
import UIKit

/// 硬件传感器 - 获取设备真实硬件状态
/// 只暴露真实数据，不做虚假映射
final class HardwareSensor: ObservableObject {
    // MARK: - Published Properties (真实数据)
    @Published var batteryLevel: Float = 1.0
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var cpuUsage: Float = 0.0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var memoryUsedMB: UInt64 = 0
    @Published var memoryTotalMB: UInt64 = 0
    @Published var memoryUsagePercent: Float = 0.0
    @Published var deviceModel: String = ""
    @Published var systemVersion: String = ""
    
    // MARK: - Initialization
    init() {
        refresh()
    }
    
    // MARK: - Refresh
    /// 刷新所有真实硬件数据
    func refresh() {
        // 电池
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        batteryLevel = level < 0 ? 1.0 : level
        batteryState = UIDevice.current.batteryState
        
        // CPU (Mach API 真实线程分析)
        cpuUsage = getCPUUsage()
        
        // 热状态 (系统级)
        thermalState = ProcessInfo.processInfo.thermalState
        
        // 内存 (Mach API 真实物理内存)
        let mem = getMemoryUsage()
        memoryUsedMB = mem.used / 1024 / 1024
        memoryTotalMB = mem.total / 1024 / 1024
        memoryUsagePercent = getMemoryUsagePercent()
        
        // 设备信息
        deviceModel = getDeviceModel()
        systemVersion = getSystemVersion()
    }
    
    // MARK: - Raw Data Methods (保留原始方法供其他模块使用)
    /// 获取电池电量 (0.0-1.0)
    func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level < 0 ? 1.0 : level
    }
    
    /// 获取电池状态
    func getBatteryState() -> UIDevice.BatteryState {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryState
    }
    
    /// 获取 CPU 使用率 (0-100) - Mach API 真实线程分析
    func getCPUUsage() -> Float {
        var totalUsageOfCPU: Float = 0.0
        var threadsList = UnsafeMutablePointer(mutating: [thread_act_t]())
        var threadsCount: mach_msg_type_number_t = 0
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }
        
        if threadsResult == KERN_SUCCESS {
            for index in 0..<threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }
                
                guard infoResult == KERN_SUCCESS else {
                    break
                }
                
                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU = totalUsageOfCPU + Float(threadBasicInfo.cpu_usage) / Float(TH_USAGE_SCALE) * 100.0
                }
            }
        }
        
        return min(totalUsageOfCPU, 100.0)
    }
    
    /// 获取设备热状态
    func getThermalState() -> ProcessInfo.ThermalState {
        return ProcessInfo.processInfo.thermalState
    }
    
    /// 获取内存使用情况 - Mach API 真实物理内存
    func getMemoryUsage() -> (used: UInt64, total: UInt64) {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        let used = result == KERN_SUCCESS ? UInt64(taskInfo.phys_footprint) : 0
        let total = ProcessInfo.processInfo.physicalMemory
        
        return (used, total)
    }
    
    /// 获取内存使用百分比
    func getMemoryUsagePercent() -> Float {
        let (used, total) = getMemoryUsage()
        return total > 0 ? Float(used) / Float(total) : 0.0
    }
    
    /// 获取设备型号
    func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    /// 获取系统版本
    func getSystemVersion() -> String {
        return UIDevice.current.systemVersion
    }
}
