import UIKit
import MachO

// ============================================================
// 星核API体检中心
// 逐层测试iOS各种硬件API，记录哪些能用哪些不能用
// ============================================================

class StarCoreViewController: UIViewController {
    
    let textView = UITextView()
    var report = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        // 体检报告显示区
        textView.frame = CGRect(x: 20, y: 80, width: view.frame.width - 40, height: view.frame.height - 100)
        textView.backgroundColor = .clear
        textView.textColor = .green
        textView.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        textView.isEditable = false
        view.addSubview(textView)
        
        log("🌟 星核API体检中心 🌟")
        log("=========================")
        log("开始逐层测试系统API...\n")
        
        // 第一层：基础API测试
        testLevel1_Basic()
        
        // 第二层：ProcessInfo测试
        testLevel2_ProcessInfo()
        
        // 第三层：BSD系统调用测试
        testLevel3_BSD()
        
        log("\n✅ 体检完成！以上是能用的API")
        log("❌ 没出现的就是闪退或崩溃的")
    }
    
    func log(_ message: String) {
        report += message + "\n"
        textView.text = report
        print(message)
    }
    
    // MARK: - Level 1: 基础API (100%安全)
    func testLevel1_Basic() {
        log("📱 Level 1: 基础API测试")
        log("------------------------")
        
        let device = UIDevice.current
        log("设备名称: \(device.name)")
        log("系统版本: \(device.systemVersion) \(device.systemName)")
        log("设备型号: \(device.model)")
        
        // 电池
        device.isBatteryMonitoringEnabled = true
        log("电量: \(Int(device.batteryLevel * 100))%")
        
        let state = device.batteryState
        var stateText = ""
        switch state {
        case .charging: stateText = "充电中"
        case .full: stateText = "满电"
        case .unplugged: stateText = "使用中"
        case .unknown: stateText = "未知"
        @unknown default: stateText = "未知"
        }
        log("充电状态: \(stateText)")
        log("✅ Level 1 全部通过！\n")
    }
    
    // MARK: - Level 2: ProcessInfo
    func testLevel2_ProcessInfo() {
        log("🧠 Level 2: ProcessInfo 测试")
        log("------------------------")
        
        let process = ProcessInfo.processInfo
        log("进程名: \(process.processName)")
        log("进程ID: \(process.processIdentifier)")
        log("系统运行时间: \(Int(process.systemUptime))秒")
        log("处理器数量: \(process.processorCount)")
        log("活跃处理器: \(process.activeProcessorCount)")
        log("物理内存: \(Float(process.physicalMemory) / 1024 / 1024 / 1024)GB")
        
        // 内存占用
        let memory = process.physicalMemory
        log("可获取物理内存大小: \(memory)")
        
        log("✅ Level 2 全部通过！\n")
    }
    
    // MARK: - Level 3: BSD 系统调用
    func testLevel3_BSD() {
        log("⚙️ Level 3: BSD 系统调用测试")
        log("------------------------")
        
        // getloadavg - 系统负载
        var loadAvg: [Double] = [0, 0, 0]
        if getloadavg(&loadAvg, 3) >= 0 {
            log("系统负载 (1分钟): \(loadAvg[0])")
            log("系统负载 (5分钟): \(loadAvg[1])")
            log("系统负载 (15分钟): \(loadAvg[2])")
            log("✅ getloadavg() 通过！")
        } else {
            log("❌ getloadavg() 失败")
        }
        
        // sysconf - CPU核心数
        let cpus = sysconf(_SC_NPROCESSORS_ONLN)
        log("在线CPU核心数: \(cpus)")
        log("✅ sysconf() 通过！")
        
        // host_page_size - 内存页大小
        var pageSize: Int32 = 0
        var size = MemoryLayout<Int32>.size
        
        // 先注释掉mach相关的，避免闪退
        // let host = mach_host_self()
        // if host_page_size(host, &pageSize, &size) == KERN_SUCCESS {
        //     log("内存页大小: \(pageSize)字节")
        //     log("✅ host_page_size() 通过！")
        // } else {
        //     log("❌ host_page_size() 失败")
        // }
        
        log("✅ Level 3 安全测试通过！\n")
    }
}
