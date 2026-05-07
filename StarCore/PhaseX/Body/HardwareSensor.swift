import Foundation
import UIKit

/// 硬件传感器 - 复用旧的传感器读取逻辑
/// 获取设备电池、CPU等硬件状态
final class HardwareSensor {
    // MARK: - Battery
    /// 获取电池电量 (0.0-1.0)
    func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        // 模拟器返回-1，返回默认值1.0
        return level < 0 ? 1.0 : level
    }
    
    /// 获取电池状态
    func getBatteryState() -> UIDevice.BatteryState {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryState
    }
    
    // MARK: - CPU
    /// 获取CPU使用率 (0-100)
    func getCPUUsage() -> Float {
        var totalUsageOfCPU: Float = 0.0
        var threadsList = UnsafeMutablePointer(mutating: [thread_act_t]())
        var threadsCount = mach_msg_type_number_t = 0
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
    
    // MARK: - Thermal
    /// 获取设备热状态
    func getThermalState() -> ProcessInfo.ThermalState {
        return ProcessInfo.processInfo.thermalState
    }
    
    // MARK: - Memory
    /// 获取内存使用情况
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
        return Float(used) / Float(total)
    }
    
    // MARK: - Device Info
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
