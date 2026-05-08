import SwiftUI

@available(iOS 15.0, *)
struct EmotionView: View {
    @EnvironmentObject var mindCore: MindCore
    @EnvironmentObject var lifeCore: LifeCore
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                dominantEmotionCard
                emotionDimensionsCard
                personaCard
                cognitiveCard
                interactionCard
                jellyfishResetCard
            }
            .padding()
        }
    }
    
    private var dominantEmotionCard: some View {
        VStack(spacing: 16) {
            Text("主导情绪").font(.caption).foregroundColor(.gray)
            Text(mindCore.dominantEmotion.emoji).font(.system(size: 80))
            Text(mindCore.dominantEmotion.rawValue).font(.title2).fontWeight(.semibold).foregroundColor(.white)
            Text("唤醒度 \(Int(mindCore.arousalLevel * 100))% | 效价 \(Int(mindCore.valenceLevel * 100))%")
                .font(.caption).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(RoundedRectangle(cornerRadius: 20).fill(emotionBackgroundColor))
    }
    
    private var emotionBackgroundColor: Color {
        if mindCore.valenceLevel > 0.6 { return Color(red: 30/255, green: 58/255, blue: 47/255) }
        else if mindCore.valenceLevel < 0.4 { return Color(red: 58/255, green: 30/255, blue: 30/255) }
        return Color(red: 30/255, green: 30/255, blue: 63/255)
    }
    
    private var emotionDimensionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("情绪维度").font(.headline).foregroundColor(.white)
            dimensionRow(title: "唤醒度", subtitle: "能量/激活水平", value: mindCore.arousalLevel, color: .orange)
            dimensionRow(title: "效价", subtitle: "愉悦/正向程度", value: mindCore.valenceLevel, color: valenceColor)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 45/255, green: 45/255, blue: 74/255)))
    }
    
    private func dimensionRow(title: String, subtitle: String, value: Float, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title).font(.subheadline).foregroundColor(.white)
                    Text(subtitle).font(.caption2).foregroundColor(.gray)
                }
                Spacer()
                Text("\(Int(value * 100))%").font(.headline).foregroundColor(color)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: geometry.size.width * CGFloat(value), height: 8)
                }
            }.frame(height: 8)
        }
    }
    
    private var valenceColor: Color {
        if mindCore.valenceLevel > 0.6 { return .green }
        else if mindCore.valenceLevel < 0.4 { return .red }
        return .yellow
    }
    
    private var personaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("人格状态").font(.headline).foregroundColor(.white)
                Spacer()
                Text(mindCore.getPersonaSummary().isEmpty ? "出厂设置" : "成长中").font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(mindCore.getPersonaSummary().isEmpty ? Color.blue.opacity(0.3) : Color.green.opacity(0.3)).cornerRadius(4)
            }
            if mindCore.getPersonaSummary().isEmpty {
                Text("出厂空白，通过交互自然成型。").font(.caption).foregroundColor(.gray)
            } else {
                Text(mindCore.getPersonaSummary()).font(.caption).foregroundColor(.gray)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 37/255, green: 37/255, blue: 64/255)))
    }
    
    // MARK: - 交互入口
    @State private var inputText: String = ""
    @State private var interactionLog: [String] = []
    
    private var interactionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("交互").font(.headline).foregroundColor(.white)
            
            // 输入框
            HStack(spacing: 8) {
                TextField("说点什么...", text: $inputText)
                    .font(.subheadline)
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                
                Button(action: submitInteraction) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            // 交互记录
            if !interactionLog.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(interactionLog.reversed(), id: \.self) { log in
                            Text(log)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 37/255, green: 37/255, blue: 64/255)))
    }
    
    private func submitInteraction() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        
        // 记录交互
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        interactionLog.append("[\(timestamp)] \(text)")
        
        // 驱动人格参数变化（阶段十二：交互自然成型）
        let feedback = analyzeSentiment(text)
        mindCore.processInteraction(text: text, feedback: feedback)
        
        inputText = ""
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// 极简情感分析：正/负/中性
    private func analyzeSentiment(_ text: String) -> Float {
        let positive = ["好", "棒", "厉害", "开心", "喜欢", "爱", "赞", "不错", "优秀", "谢谢", "感谢", "辛苦", "加油"]
        let negative = ["差", "烂", "坏", "讨厌", "烦", "恨", "错", "笨", "傻", "不行", "失望", "生气"]
        
        var score: Float = 0
        for word in positive {
            if text.contains(word) { score += 0.3 }
        }
        for word in negative {
            if text.contains(word) { score -= 0.3 }
        }
        return max(-1, min(score, 1))
    }
    
    // MARK: - 灯塔重置按钮
    private var jellyfishResetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("灯塔重置").font(.headline).foregroundColor(.white)
                Spacer()
                Text("清理冗余 · 理论永久稳定").font(.caption2).foregroundColor(.purple)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已重置 \(lifeCore.jellyfishReset.numberOfResets) 次").font(.caption).foregroundColor(.gray)
                    if let lastDate = lifeCore.jellyfishReset.lastReset {
                        Text("上次: \(DateFormatter.localizedString(from: lastDate, dateStyle: .short, timeStyle: .short))").font(.caption2).foregroundColor(.gray)
                    }
                }
                Spacer()
                Button(action: {
                    lifeCore.jellyfishReset.performReset()
                    lifeCore.addLog(.success, "灯塔重置：清理冗余完成")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重置")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.3))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 37/255, green: 37/255, blue: 64/255)))
    }
    
    private var cognitiveCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("认知状态").font(.headline).foregroundColor(.white)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("认知负荷").font(.caption).foregroundColor(.gray)
                    Text("\(Int(mindCore.cognitiveLoad * 100))%").font(.title3).fontWeight(.semibold).foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("状态").font(.caption).foregroundColor(.gray)
                    Text(mindStatusText).font(.subheadline).fontWeight(.medium).foregroundColor(mindStatusColor)
                }
            }
            HStack(spacing: 8) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text("已通过 LifeCoreProtocol 连接到生命核心").font(.caption).foregroundColor(.gray)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 37/255, green: 37/255, blue: 64/255)))
    }
    
    private var mindStatusText: String {
        switch mindCore.mindStatus {
        case .active: return "活跃"
        case .dormant: return "休眠"
        case .overloaded: return "过载"
        }
    }
    
    private var mindStatusColor: Color {
        switch mindCore.mindStatus {
        case .active: return .green
        case .dormant: return .orange
        case .overloaded: return .red
        }
    }
}
