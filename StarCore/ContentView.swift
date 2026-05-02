import SwiftUI
import UIKit

struct ContentView: View {
    @State private var batteryLevel: Float = 0
    @State private var currentTime: String = ""
    @State private var cpuUsage: Double = 0
    @State private var memoryUsage: Double = 0
    @State private var storageUsed: String = ""
    @State private var storageTotal: String = ""
    @State private var heartBeatScale: CGFloat = 1.0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // 计算整体状态
    var overallStatus: (String, Color) {
        let avgLoad = (cpuUsage + memoryUsage) / 2
        
        if batteryLevel < 0.2 {
            return ("💔 疲惫", .red)
        } else if avgLoad > 80 {
            return ("🔥 兴奋", .orange)
        } else if avgLoad > 50 {
            return ("⚡ 活跃", .yellow)
        } else {
            return ("💙 平静", .blue)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题带心跳动画
            Text("✨ 星核启动！✨")
                .font(.largeTitle)
                .fontWeight(.bold)
                .scaleEffect(heartBeatScale)
                .animation(.easeInOut(duration: 0.3), value: heartBeatScale)
            
            // 整体状态
            HStack {
                Text("状态：")
                    .font(.title2)
                Text(overallStatus.0)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(overallStatus.1)
            }
            
            // 气血 - 电池电量
            HStack {
                Text("💚 气血：")
                    .font(.title2)
                    .foregroundColor(.green)
                Text(String(format: "%.1f%%", batteryLevel * 100))
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            // 脉搏 - 系统时间
            HStack {
                Text("💙 脉搏：")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text(currentTime)
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            // 心跳 - CPU负载
            HStack {
                Text("❤️ 心跳：")
                    .font(.title2)
                    .foregroundColor(.red)
                Text(String(format: "%.1f%%", cpuUsage))
                    .font(.title2)
                    .foregroundColor(.red)
            }
            
            // 思维 - 内存使用
            HStack {
                Text("💜 思维：")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text(String(format: "%.1f%%", memoryUsage))
                    .font(.title2)
                    .foregroundColor(.purple)
            }
            
            // 储备 - 存储使用
            HStack {
                Text("💛 储备：")
                    .font(.title2)
                    .foregroundColor(.yellow)
                Text("\(storageUsed) / \(storageTotal)")
                    .font(.title2)
                    .foregroundColor(.yellow)
            }
        }
        .padding()
        .onReceive(timer) { _ in
            updateBatteryLevel()
            updateCurrentTime()
            updateCPUUsage()
            updateMemoryUsage()
            updateStorageUsage()
            triggerHeartBeat()
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            updateBatteryLevel()
            updateCurrentTime()
            updateCPUUsage()
            updateMemoryUsage()
            updateStorageUsage()
        }
    }
    
    func triggerHeartBeat() {
        // 根据CPU负载调整心跳动画强度
        let intensity = max(0.02, min(0.1, cpuUsage / 1000))
        heartBeatScale = 1.0 + CGFloat(intensity)
        
        // 0.3秒后恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            heartBeatScale = 1.0
        }
    }
    
    func updateBatteryLevel() {
        batteryLevel = UIDevice.current.batteryLevel
    }
    
    func updateCurrentTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        currentTime = formatter.string(from: Date())
    }
    
    func updateCPUUsage() {
        var totalUsageOfCPU: Double = 0
        var processorsInfo = processor_info_array_t(bitPattern: 0)
        var processorsInfoCount = mach_msg_type_number_t(0)
        var numCPUs = UInt32(0)
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &processorsInfo, &processorsInfoCount)
        
        if result == KERN_SUCCESS {
            for i in 0..<Int(numCPUs) {
                let cpuInfo = processorsInfo!.advanced(by: i * Int(CPU_STATE_MAX))
                let user = Double(cpuInfo[Int(CPU_STATE_USER)])
                let system = Double(cpuInfo[Int(CPU_STATE_SYSTEM)])
                let nice = Double(cpuInfo[Int(CPU_STATE_NICE)])
                let idle = Double(cpuInfo[Int(CPU_STATE_IDLE)])
                let total = user + system + nice + idle
                
                if total > 0 {
                    totalUsageOfCPU += (user + system + nice) / total * 100
                }
            }
            cpuUsage = totalUsageOfCPU / Double(numCPUs)
        }
        
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: processorsInfo), vm_size_t(processorsInfoCount * UInt32(MemoryLayout<integer_t>.stride)))
    }
    
    func updateMemoryUsage() {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let used = Double(taskInfo.phys_footprint)
            let total = Double(ProcessInfo.processInfo.physicalMemory)
            memoryUsage = used / total * 100
        }
    }
    
    func updateStorageUsage() {
        let fileManager = FileManager.default
        do {
            let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let values = try documentDirectory.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacityForImportantUsage {
                let used = total - Int(available)
                storageUsed = ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file)
                storageTotal = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
            }
        } catch {
            storageUsed = "未知"
            storageTotal = "未知"
        }
    }
}

#Preview {
    ContentView()
}
