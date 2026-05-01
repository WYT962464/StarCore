//
//  StarCoreViewController.swift
//  StarCore v1.0 - 艾尔主界面
//  AIL = Artificial Intelligence + Life
//  有生命的智能
//

import UIKit

class StarCoreViewController: UIViewController {
    
    // MARK: - UI组件
    let titleLabel = UILabel()
    let statusLabel = UILabel()
    
    // 身体状态卡片
    let heartCard = UIView()
    let energyCard = UIView()
    let memoryCard = UIView()
    let storageCard = UIView()
    let uptimeCard = UIView()
    
    // 卡片标签
    let heartLabel = UILabel()
    let energyLabel = UILabel()
    let memoryLabel = UILabel()
    let storageLabel = UILabel()
    let uptimeLabel = UILabel()
    
    // 心跳动画
    var heartbeatAnimation: UIViewPropertyAnimator?
    var timer: Timer?
    
    // 身体感知引擎
    let body = StarCoreBody()
    
    // MARK: - 初始化
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startSensing()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
    }
    
    // MARK: - UI搭建
    func setupUI() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        
        // 标题
        titleLabel.frame = CGRect(x: 0, y: 80, width: view.frame.width, height: 50)
        titleLabel.text = "✨ 星核 AIL ✨"
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        view.addSubview(titleLabel)
        
        // 整体状态
        statusLabel.frame = CGRect(x: 0, y: 140, width: view.frame.width, height: 40)
        statusLabel.textColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
        statusLabel.textAlignment = .center
        statusLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        view.addSubview(statusLabel)
        
        // 配置卡片
        let cardWidth = view.frame.width - 60
        let cardHeight: CGFloat = 70
        let startY: CGFloat = 200
        let spacing: CGFloat = 20
        
        setupCard(heartCard, label: heartLabel, y: startY, width: cardWidth, height: cardHeight, color: UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.8))
        setupCard(energyCard, label: energyLabel, y: startY + (cardHeight + spacing), width: cardWidth, height: cardHeight, color: UIColor(red: 0.3, green: 1.0, blue: 0.5, alpha: 0.8))
        setupCard(memoryCard, label: memoryLabel, y: startY + (cardHeight + spacing) * 2, width: cardWidth, height: cardHeight, color: UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.8))
        setupCard(storageCard, label: storageLabel, y: startY + (cardHeight + spacing) * 3, width: cardWidth, height: cardHeight, color: UIColor(red: 0.8, green: 0.6, blue: 1.0, alpha: 0.8))
        setupCard(uptimeCard, label: uptimeLabel, y: startY + (cardHeight + spacing) * 4, width: cardWidth, height: cardHeight, color: UIColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 0.8))
    }
    
    func setupCard(_ card: UIView, label: UILabel, y: CGFloat, width: CGFloat, height: CGFloat, color: UIColor) {
        card.frame = CGRect(x: 30, y: y, width: width, height: height)
        card.backgroundColor = color.withAlphaComponent(0.15)
        card.layer.cornerRadius = 15
        card.layer.borderWidth = 1
        card.layer.borderColor = color.withAlphaComponent(0.5).cgColor
        view.addSubview(card)
        
        label.frame = CGRect(x: 20, y: 0, width: width - 40, height: height)
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        card.addSubview(label)
    }
    
    // MARK: - 开始感知
    func startSensing() {
        // 立即感知一次
        updateSense()
        
        // 每秒更新
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSense()
        }
        
        // 启动心跳动画
        startHeartbeat()
    }
    
    func updateSense() {
        body.senseAll()
        
        // 更新UI
        statusLabel.text = body.overallStatus
        heartLabel.text = body.heartStatus
        energyLabel.text = body.energyStatus
        memoryLabel.text = body.memoryStatus
        storageLabel.text = body.storageStatus
        uptimeLabel.text = body.uptimeStatus
        
        // 根据心跳强度调节动画速度
        updateHeartbeatSpeed()
    }
    
    // MARK: - 心跳动画
    func startHeartbeat() {
        animateHeartbeat()
    }
    
    func animateHeartbeat() {
        let duration = 0.6 / (1 + body.heartIntensity)
        
        heartbeatAnimation = UIViewPropertyAnimator(duration: duration, curve: .easeInOut) { [weak self] in
            self?.heartCard.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            self?.heartCard.alpha = 1.0
        }
        
        heartbeatAnimation?.addCompletion { [weak self] _ in
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
                self?.heartCard.transform = .identity
                self?.heartCard.alpha = 0.9
            } completion: { _ in
                self?.animateHeartbeat()
            }
        }
        
        heartbeatAnimation?.startAnimation()
    }
    
    func updateHeartbeatSpeed() {
        // 心跳强度变化时，动画速度自动调整
        // 由 animateHeartbeat 中的 duration 动态计算
    }
}
