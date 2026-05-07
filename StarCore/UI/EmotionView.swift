import SwiftUI

/// 情绪显示视图
@available(iOS 15.0, *)
struct EmotionView: View {
    @EnvironmentObject var mindCore: MindCore
    @EnvironmentObject var lifeCore: LifeCore
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 主导情绪卡片
                dominantEmotionCard
                
                // 情绪维度
                emotionDimensionsCard
                
                // 人格状态
                personaCard
                
                // 认知状态
                cognitiveCard
            }
            .padding()
        }
    }
    
    // MARK: - Dominant Emotion Card
    private var dominantEmotionCard: some View {
        VStack(spacing: 16) {
            Text("主导情绪")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(mindCore.dominantEmotion.emoji)
                .font(.system(size: 80))
            
            Text(mindCore.dominantEmotion.rawValue)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("唤醒度 \(Int(mindCore.arousalLevel * 100))% | 效价 \(Int(mindCore.valenceLevel * 100))%")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(emotionBackgroundColor)
        )
    }
    
    private var emotionBackgroundColor: Color {
        if mindCore.valenceLevel > 0.6 {
            return Color(hex: "1e3a2f")
        } else if mindCore.valenceLevel < 0.4 {
            return Color(hex: "3a1e1e")
        }
        return Color(hex: "1e1e3f")
    }
    
    // MARK: - Emotion Dimensions Card
    private var emotionDimensionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("情绪维度")
                .font(.headline)
                .foregroundColor(.white)
            
            // 唤醒度
            dimensionRow(
                title: "唤醒度",
                subtitle: "能量/激活水平",
                value: mindCore.arousalLevel,
                color: .orange
            )
            
            // 效价
            dimensionRow(
                title: "效价",
                subtitle: "愉悦/正向程度",
                value: mindCore.valenceLevel,
                color: valenceColor
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "2d2d4a"))
        )
    }
    
    private func dimensionRow(title: String, subtitle: String, value: Float, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var valenceColor: Color {
        if mindCore.valenceLevel > 0.6 {
            return .green
        } else if mindCore.valenceLevel < 0.4 {
            return .red
        }
        return .yellow
    }
    
    // MARK: - Persona Card
    private var personaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("人格状态")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("出厂设置")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(4)
            }
            
            Text("所有人格参数均为默认值，人格系统尚未激活。")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "252540"))
        )
    }
    
    // MARK: - Cognitive Card
    private var cognitiveCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("认知状态")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("认知负荷")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(mindCore.cognitiveLoad * 100))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("状态")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(mindStatusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(mindStatusColor)
                }
            }
            
            // 与底层连接指示器
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("已通过 LifeCoreProtocol 连接到生命核心")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "252540"))
        )
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
