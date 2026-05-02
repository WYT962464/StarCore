import UIKit

class StarCoreViewController: UIViewController {
    
    let titleLabel = UILabel()
    let batteryLabel = UILabel()
    let timeLabel = UILabel()
    let cpuLabel = UILabel()
    var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 黑底
        view.backgroundColor = .black
        
        // 标题
        titleLabel.frame = CGRect(x: 0, y: 150, width: view.frame.width, height: 60)
        titleLabel.text = "✨ 星核启动 ✨"
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        view.addSubview(titleLabel)
        
        // 电池电量
        batteryLabel.frame = CGRect(x: 0, y: 250, width: view.frame.width, height: 50)
        batteryLabel.textColor = UIColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
        batteryLabel.textAlignment = .center
        batteryLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        view.addSubview(batteryLabel)
        
        // 系统时间
        timeLabel.frame = CGRect(x: 0, y: 310, width: view.frame.width, height: 50)
        timeLabel.textColor = UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0)
        timeLabel.textAlignment = .center
        timeLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        view.addSubview(timeLabel)
        
        // CPU负载
        cpuLabel.frame = CGRect(x: 0, y: 370, width: view.frame.width, height: 50)
        cpuLabel.textColor = UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
        cpuLabel.textAlignment = .center
        cpuLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        view.addSubview(cpuLabel)
        
        // 开启电池监控
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // 每秒更新一次
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateAll()
        }
        timer?.fire()
    }
    
    func updateAll() {
        updateBattery()
        updateTime()
        updateCPU()
    }
    
    func updateBattery() {
        let level = UIDevice.current.batteryLevel
        let state = UIDevice.current.batteryState
        
        var stateText = ""
        switch state {
        case .charging:
            stateText = "⚡️ 充电中"
        case .full:
            stateText = "✅ 满电"
        case .unplugged:
            stateText = "🔋 使用中"
        case .unknown:
            stateText = "❓ 未知"
        @unknown default:
            stateText = ""
        }
        
        if level >= 0 {
            batteryLabel.text = "气血: \(Int(level * 100))% · \(stateText)"
        } else {
            batteryLabel.text = "气血: 检测中..."
        }
    }
    
    func updateTime() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        let timeString = dateFormatter.string(from: Date())
        timeLabel.text = "🕐 脉搏: \(timeString)"
    }
    
    func updateCPU() {
        var loads: [Double] = [0, 0, 0]
        if getloadavg(&loads, 3) >= 0 {
            let load1min = loads[0]
            let intensity = min(load1min / 6.0, 1.0) // 6核CPU，最大负载6.0
            let percent = Int(intensity * 100)
            cpuLabel.text = "❤️ 心跳: \(String(format: "%.2f", load1min)) · 强度 \(percent)%"
        } else {
            cpuLabel.text = "❤️ 心跳: 检测中..."
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
    }
}
