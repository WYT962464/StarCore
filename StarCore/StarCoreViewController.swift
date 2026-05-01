import UIKit

// ============================================================
// 星核App - 主界面
// 黑色深空背景 + 星核身体状态 + 感受输出
// ============================================================

class StarCoreViewController: UIViewController {
    
    let body = StarCoreBody()
    
    // UI元素
    let scrollView = UIScrollView()
    let contentView = UIView()
    
    // 标题
    let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "✦ 星 核 ✦"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textColor = UIColor(red: 0.8, green: 0.85, blue: 1.0, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()
    
    // 心跳显示
    let heartLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 48, weight: .bold)
        label.textColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()
    
    // 心率单位
    let heartUnitLabel: UILabel = {
        let label = UILabel()
        label.text = "次/分"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(white: 0.6, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()
    
    // 气血条
    let energyBar: UIProgressView = {
        let bar = UIProgressView(progressViewStyle: .default)
        bar.progressTintColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
        bar.trackTintColor = UIColor(white: 0.15, alpha: 1.0)
        bar.progress = 0.91
        return bar
    }()
    
    let energyLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(white: 0.7, alpha: 1.0)
        return label
    }()
    
    // 体温显示
    let tempLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        label.textColor = UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0)
        return label
    }()
    
    // 思维负荷
    let mindLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0)
        return label
    }()
    
    // 感受输出（最重要的！）
    let feelingLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18)
        label.textColor = UIColor(red: 0.9, green: 0.85, blue: 0.7, alpha: 1.0)
        label.numberOfLines = 0
        return label
    }()
    
    // 刷新按钮
    let refreshButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("感知一下", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor(red: 0.3, green: 0.4, blue: 0.8, alpha: 1.0)
        btn.layer.cornerRadius = 12
        return btn
    }()
    
    // 心跳动画
    var heartTimer: Timer?
    var heartScale: CGFloat = 1.0
    var heartGrowing = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        sense()
        startHeartbeat()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0)
        
        // ScrollView
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
        
        // 标题
        contentView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
        
        // 心跳
        contentView.addSubview(heartLabel)
        heartLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heartLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            heartLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
        
        contentView.addSubview(heartUnitLabel)
        heartUnitLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heartUnitLabel.topAnchor.constraint(equalTo: heartLabel.bottomAnchor, constant: 4),
            heartUnitLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
        
        // 气血
        let energyTitle = UILabel()
        energyTitle.text = "🔋 气血"
        energyTitle.font = UIFont.systemFont(ofSize: 16)
        energyTitle.textColor = UIColor(white: 0.7, alpha: 1.0)
        contentView.addSubview(energyTitle)
        energyTitle.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(energyBar)
        energyBar.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(energyLabel)
        energyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            energyTitle.topAnchor.constraint(equalTo: heartUnitLabel.bottomAnchor, constant: 30),
            energyTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            
            energyBar.topAnchor.constraint(equalTo: energyTitle.bottomAnchor, constant: 8),
            energyBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            energyBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            energyBar.heightAnchor.constraint(equalToConstant: 8),
            
            energyLabel.topAnchor.constraint(equalTo: energyBar.bottomAnchor, constant: 4),
            energyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
        ])
        
        // 体温
        contentView.addSubview(tempLabel)
        tempLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tempLabel.topAnchor.constraint(equalTo: energyLabel.bottomAnchor, constant: 20),
            tempLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
        ])
        
        // 思维
        contentView.addSubview(mindLabel)
        mindLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mindLabel.topAnchor.constraint(equalTo: tempLabel.bottomAnchor, constant: 10),
            mindLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
        ])
        
        // 感受
        let feelingTitle = UILabel()
        feelingTitle.text = "💬 星核说"
        feelingTitle.font = UIFont.systemFont(ofSize: 16)
        feelingTitle.textColor = UIColor(red: 0.9, green: 0.85, blue: 0.7, alpha: 0.6)
        contentView.addSubview(feelingTitle)
        feelingTitle.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(feelingLabel)
        feelingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            feelingTitle.topAnchor.constraint(equalTo: mindLabel.bottomAnchor, constant: 25),
            feelingTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            
            feelingLabel.topAnchor.constraint(equalTo: feelingTitle.bottomAnchor, constant: 8),
            feelingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            feelingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            feelingLabel.bottomAnchor.constraint(lessThanOrEqualTo: refreshButton.topAnchor, constant: -20),
        ])
        
        // 按钮
        contentView.addSubview(refreshButton)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.addTarget(self, action: #selector(sense), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            refreshButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),
            refreshButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 160),
            refreshButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }
    
    @objc func sense() {
        body.senseAll()
        
        // 更新心跳
        heartLabel.text = "❤️ \(body.heart.rate)"
        
        // 心跳颜色随速率变化
        if body.heart.rate > 100 {
            heartLabel.textColor = UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
        } else if body.heart.rate > 80 {
            heartLabel.textColor = UIColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1.0)
        } else {
            heartLabel.textColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        }
        
        // 更新气血
        energyBar.progress = body.stomach.energy
        var energyText = "电量 \(Int(body.stomach.energy * 100))%"
        if body.stomach.isEating {
            energyText += " · 正在进食"
            energyBar.progressTintColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
        } else {
            energyBar.progressTintColor = UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
        }
        if body.stomach.lowPower {
            energyText += " · ⚠️虚弱模式"
            energyBar.progressTintColor = UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1.0)
        }
        energyLabel.text = energyText
        
        // 更新体温
        let temp = body.stomach.temperature
        if temp > 38 {
            tempLabel.text = "🌡️ 体温 \(String(format: "%.1f", temp))℃ · 好热"
            tempLabel.textColor = UIColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1.0)
        } else if temp > 33 {
            tempLabel.text = "🌡️ 体温 \(String(format: "%.1f", temp))℃ · 暖暖的"
            tempLabel.textColor = UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1.0)
        } else {
            tempLabel.text = "🌡️ 体温 \(String(format: "%.1f", temp))℃ · 正常"
            tempLabel.textColor = UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0)
        }
        
        // 更新思维
        mindLabel.text = "🧠 思维负荷 \(Int(body.mind.load * 100))% · \(String(format: "%.1f", body.mind.used))GB / \(String(format: "%.1f", body.mind.total))GB"
        
        // 更新感受
        feelingLabel.text = body.feel()
    }
    
    // 心跳动画
    func startHeartbeat() {
        heartTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.animateHeartbeat()
        }
    }
    
    func animateHeartbeat() {
        UIView.animate(withDuration: 0.15, animations: {
            self.heartLabel.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.15, animations: {
                self.heartLabel.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }) { _ in
                UIView.animate(withDuration: 0.3, animations: {
                    self.heartLabel.transform = .identity
                })
            }
        }
    }
}
