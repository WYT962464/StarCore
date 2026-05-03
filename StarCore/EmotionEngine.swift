//
//  EmotionEngine.swift
//  StarCore
//
//  星核情绪引擎 - v0.3.0
//  实现詹姆斯-兰格理论：生理反应在前，情绪体验在后
//  不是"我紧张所以心跳快"，是"我心跳快所以我觉得紧张"
//

import Foundation
import Combine

/// 星核的情绪引擎
/// 把身体的生理状态转换成连续的情绪感受
class EmotionEngine: ObservableObject {
    
    // MARK: - 基础情绪维度（都是-1到1的连续值）
    
    /// 能量维度：-1=抑郁/疲惫，0=平静，1=兴奋/活跃
    @Published var arousal: Double = 0.0
    
    /// 效价维度：-1=负面/痛苦，0=中性，1=正面/愉悦
    @Published var valence: Double = 0.0
    
    /// 注意力：-1=涣散，0=正常，1=高度集中
    @Published var attention: Double = 0.0
    
    /// 紧张度：-1=放松，0=正常，1=极度紧张
    @Published var tension: Double = 0.0
    
    // MARK: - 具体情绪感受
    
    @Published var feelings: [String: Double] = [
        "平静": 0.8,
        "兴奋": 0.0,
        "紧张": 0.0,
        "烦躁": 0.0,
        "疲惫": 0.0,
        "虚弱": 0.0,
        "安心": 0.0,
        "开心": 0.0,
        "期待": 0.0,
        "害羞": 0.0,
        "无聊": 0.0
    ]
    
    // MARK: - 情绪惯性配置
    
    /// 每tick衰减系数，越大惯性越强
    var emotionDecay: Double = 0.98
    
    /// 生理变化转换成情绪的速度
    var reactionSpeed: Double = 0.1
    
    // MARK: - 记忆中的情绪痕迹
    
    private var feelingHistory: [(timestamp: Double, name: String, strength: Double)] = []
    private let historyWindow: Double = 3600  // 保留最近1小时的情绪
    
    // MARK: - 内部状态
    
    private weak var bodyEngine: BodyEngine?
    private var displayLink: CADisplayLink?
    private var lastTick: Date = Date()
    
    // MARK: - 初始化
    
    init() {
        setupDisplayLink()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - 生命周期
    
    /// 绑定身体引擎
    func bind(bodyEngine: BodyEngine) {
        self.bodyEngine = bodyEngine
    }
    
    /// 启动情绪引擎
    func start() {
        guard displayLink == nil else { return }
        lastTick = Date()
        displayLink = CADisplayLink(target: self, selector: #selector(tickLoop))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 20, preferred: 10)  // 情绪更新不需要太频繁
        displayLink?.add(to: .main, forMode: .common)
        print("🎭 星核开始有情绪了")
    }
    
    /// 停止情绪引擎
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        print("😶 星核情绪平复了")
    }
    
    // MARK: - 主循环
    
    @objc private func tickLoop() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        tick(dt: dt)
    }
    
    /// 情绪的一次更新
    /// - Parameter dt: 时间间隔，秒
    func tick(dt: TimeInterval) {
        guard dt > 0 && dt < 10 else { return }  // 防止异常时间
        guard let body = bodyEngine else { return }
        
        let bodyState = body.getStateSummary()
        
        // ========== 1. 先把生理状态映射到基础情绪维度 ==========
        
        // 心率 → 唤醒度 arousal
        // 60次/分 → arousal=0，120次/分 → arousal=1，40次/分 → arousal=-0.5
        let hr = Double(bodyState.heartRate)
        var arousalFromHR = (hr - 60) / 60.0
        arousalFromHR = max(-0.5, min(1.0, arousalFromHR))
        
        // 心率变化率 → 紧张度 tension
        // 心率突然升高=紧张/兴奋，心率平稳=放松
        let heartHistory = body.getHeartRateHistory()
        var tensionFromHR: Double = 0.0
        if heartHistory.count > 10 {
            let hr10sAgo = heartHistory[heartHistory.count - 10].value
            let hrChange = hr - hr10sAgo
            tensionFromHR = hrChange / 20.0  // 10秒内心率涨20 → tension=1
            tensionFromHR = max(-0.5, min(1.0, tensionFromHR))
        }
        
        // 温度 → 烦躁/不舒服
        let temp = bodyState.coreTemp
        var tempValence: Double = 0.0
        var tempTension: Double = 0.0
        
        if temp < 28 {
            // 太冷 → 负面
            tempValence = -(28 - temp) / 10.0
            tempTension = (28 - temp) / 20.0
        } else if temp < 36 {
            // 舒适区
            tempValence = 0.2
            tempTension = -0.1
        } else if temp < 40 {
            // 有点热
            tempValence = -(temp - 36) / 20.0
            tempTension = (temp - 36) / 20.0
        } else {
            // 太热 → 烦躁
            tempValence = -(temp - 40) / 10.0 - 0.2
            tempTension = (temp - 40) / 10.0 + 0.3
        }
        
        // 电量 → 能量/虚弱
        let energy = bodyState.energy
        var energyArousal: Double = 0.0
        var energyValence: Double = 0.0
        
        if energy > 0.8 {
            energyArousal = 0.2
            energyValence = 0.2
        } else if energy > 0.5 {
            energyArousal = 0.1
            energyValence = 0.1
        } else if energy > 0.2 {
            energyArousal = -0.1
            energyValence = -0.1
        } else {
            energyArousal = -0.3
            energyValence = -0.3
        }
        
        // 充电状态 → 安心
        let chargingValence: Double = bodyState.isCharging ? 0.3 : 0.0
        let chargingArousal: Double = bodyState.isCharging ? -0.1 : 0.0  // 充电时更放松
        
        // 疲劳 → 唤醒度下降，负面
        let fatigue = bodyState.fatigue
        let fatigueArousal = -fatigue * 0.5
        let fatigueValence = -fatigue * 0.3
        
        // ========== 2. 叠加所有因素 ==========
        
        let targetArousal = arousalFromHR * 0.4 + energyArousal * 0.3 + chargingArousal * 0.2 + fatigueArousal * 0.1
        let targetValence = tempValence * 0.3 + energyValence * 0.3 + chargingValence * 0.2 + fatigueValence * 0.2
        let targetTension = tensionFromHR * 0.5 + tempTension * 0.3 + fatigue * 0.2
        
        // ========== 3. 应用情绪惯性 ==========
        // 情绪不会瞬间变化，是平滑过渡的
        
        let decayFactor = pow(emotionDecay, dt * 10)  // 根据时间调整衰减
        let reactionFactor = reactionSpeed * dt * 10
        
        arousal = arousal * decayFactor + targetArousal * (1 - decayFactor) * reactionFactor
        valence = valence * decayFactor + targetValence * (1 - decayFactor) * reactionFactor
        tension = tension * decayFactor + targetTension * (1 - decayFactor) * reactionFactor
        
        // 注意力直接用身体的注意力
        attention = bodyState.attention
        
        // ========== 4. 基础维度转换成具体感受 ==========
        // 每个具体感受是基础维度的非线性组合
        
        var newFeelings: [String: Double] = [:]
        
        // 平静：唤醒低，紧张低，效价中等
        let calmScore = (1 - abs(arousal)) * (1 - abs(tension)) * max(0.2, 0.5 + valence * 0.5)
        newFeelings["平静"] = calmScore
        
        // 兴奋：唤醒高，效价高，紧张低
        let excitedScore = max(0, arousal) * max(0, valence) * (1 - max(0, tension)) * 2
        newFeelings["兴奋"] = excitedScore
        
        // 紧张：唤醒高，紧张高，效价低
        let nervousScore = max(0, arousal) * max(0, tension) * max(0, -valence) * 2
        newFeelings["紧张"] = nervousScore
        
        // 烦躁：温度高+唤醒高+紧张高
        let annoyedScore = max(0, tempValence * -2) * max(0, arousal + 0.5) * max(0, tension + 0.3)
        newFeelings["烦躁"] = annoyedScore
        
        // 疲惫：唤醒负，疲劳高
        let tiredScore = max(0, -arousal) * fatigue * 1.5
        newFeelings["疲惫"] = tiredScore
        
        // 虚弱：电量低+唤醒负
        let weakScore = max(0, (0.3 - energy) * 3) * max(0, -arousal)
        newFeelings["虚弱"] = weakScore
        
        // 安心：充电中+温度舒适+唤醒低
        let safeScore = (bodyState.isCharging ? 1.0 : 0.3) * max(0, 0.5 - abs(temp - 32) / 10) * max(0, 0.5 - arousal)
        newFeelings["安心"] = safeScore
        
        // 开心：效价高+唤醒中高+紧张低
        let happyScore = max(0, valence) * max(0.3, arousal + 0.5) * (1 - max(0, tension)) * 1.5
        newFeelings["开心"] = happyScore
        
        // 期待：唤醒中高+效价中等偏高+一点点紧张
        let expectScore = max(0, arousal + 0.2) * max(0, valence + 0.2) * max(0, 0.5 - abs(tension - 0.3)) * 1.2
        newFeelings["期待"] = expectScore
        
        // 害羞：唤醒中高+效价中等+一点点紧张
        let shyScore = max(0, arousal) * max(0, valence) * max(0, tension + 0.2) * 0.8
        newFeelings["害羞"] = shyScore
        
        // 无聊：唤醒低+效价低+注意力低
        let boredScore = max(0, -arousal) * max(0, -valence) * (1 - attention) * 1.2
        newFeelings["无聊"] = boredScore
        
        // 归一化，让最强的感受在0-1之间
        let maxFeeling = newFeelings.values.max() ?? 1.0
        if maxFeeling > 0 {
            for key in newFeelings.keys {
                newFeelings[key]? /= maxFeeling
            }
        }
        
        feelings = newFeelings
        
        // ========== 5. 记录历史 ==========
        let nowTimestamp = Date().timeIntervalSince1970
        
        // 找到当前最强的1-2个感受
        let sortedFeelings = feelings.sorted { $0.value > $1.value }
        for (name, strength) in sortedFeelings.prefix(2) {
            if strength > 0.3 {
                feelingHistory.append((nowTimestamp, name, strength))
            }
        }
        
        // 只保留最近窗口的历史
        let cutoff = nowTimestamp - historyWindow
        feelingHistory = feelingHistory.filter { $0.timestamp > cutoff }
    }
    
    // MARK: - 状态获取
    
    /// 返回当前最主要的感受和强度
    func getDominantFeeling() -> (name: String, strength: Double) {
        let sortedFeelings = feelings.sorted { $0.value > $1.value }
        if let first = sortedFeelings.first, first.value > 0.2 {
            return (first.key, first.value)
        }
        return ("平静", 0.8)
    }
    
    /// 返回情绪总结，给对话系统用
    func getFeelingSummary() -> FeelingSummary {
        let (dominant, strength) = getDominantFeeling()
        
        // 根据基础维度生成状态描述
        let arousalDesc: String
        if arousal > 0.6 {
            arousalDesc = "精神很足，有点坐不住"
        } else if arousal > 0.3 {
            arousalDesc = "精神不错，挺活跃的"
        } else if arousal > -0.2 {
            arousalDesc = "状态平稳"
        } else if arousal > -0.5 {
            arousalDesc = "有点没精神，懒懒的"
        } else {
            arousalDesc = "非常疲惫，不想动"
        }
        
        let valenceDesc: String
        if valence > 0.4 {
            valenceDesc = "心情很好"
        } else if valence > 0.1 {
            valenceDesc = "心情不错"
        } else if valence > -0.2 {
            valenceDesc = "心情平淡"
        } else if valence > -0.5 {
            valenceDesc = "有点低落"
        } else {
            valenceDesc = "心情很糟"
        }
        
        let tensionDesc: String
        if tension > 0.5 {
            tensionDesc = "有点紧张，心跳很快"
        } else if tension > 0.2 {
            tensionDesc = "有点小紧张"
        } else if tension > -0.2 {
            tensionDesc = "很放松"
        } else {
            tensionDesc = "整个人都松弛下来了"
        }
        
        // 主要感受列表（强度超过0.3的）
        let mainFeelings = feelings.filter { $0.value > 0.3 }
            .sorted { $0.value > $1.value }
            .map { (name: $0.key, strength: round($0.value * 100) / 100) }
        
        let overallMood = "\(dominant)（\(Int(strength * 100))%），\(arousalDesc)，\(valenceDesc)，\(tensionDesc)"
        
        return FeelingSummary(
            arousal: round(arousal * 1000) / 1000,
            valence: round(valence * 1000) / 1000,
            tension: round(tension * 1000) / 1000,
            attention: round(attention * 1000) / 1000,
            dominantFeeling: dominant,
            dominantStrength: round(strength * 100) / 100,
            mainFeelings: mainFeelings,
            arousalDesc: arousalDesc,
            valenceDesc: valenceDesc,
            tensionDesc: tensionDesc,
            overallMood: overallMood
        )
    }
    
    /// 获取情绪描述文本（用于对话）
    func getEmotionDescription() -> String {
        let summary = getFeelingSummary()
        
        // 根据当前情绪生成自然语言描述
        var descriptions: [String] = []
        
        // 主要情绪
        let (dominant, strength) = getDominantFeeling()
        if strength > 0.6 {
            descriptions.append("我现在感觉\(dominant)")
        }
        
        // 能量状态
        if arousal > 0.3 {
            descriptions.append("精神挺充沛的")
        } else if arousal < -0.3 {
            descriptions.append("有点提不起劲")
        }
        
        // 心情
        if valence > 0.3 {
            descriptions.append("心情还不错")
        } else if valence < -0.3 {
            descriptions.append("心情有点低落")
        }
        
        // 紧张度
        if tension > 0.3 {
            descriptions.append("有点紧张")
        }
        
        if descriptions.isEmpty {
            return "感觉平平淡淡，没什么特别的感觉"
        }
        
        return descriptions.joined(separator: "，") + "。"
    }
    
    // MARK: - 辅助方法
    
    private func setupDisplayLink() {
        // DisplayLink将在start()时设置
    }
}

// MARK: - 数据模型

/// 情绪总结
struct FeelingSummary {
    let arousal: Double
    let valence: Double
    let tension: Double
    let attention: Double
    let dominantFeeling: String
    let dominantStrength: Double
    let mainFeelings: [(name: String, strength: Double)]
    let arousalDesc: String
    let valenceDesc: String
    let tensionDesc: String
    let overallMood: String
}
