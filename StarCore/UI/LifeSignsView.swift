import SwiftUI

/// 生命体征视图
@available(iOS 15.0, *)
struct LifeSignsView: View {
    @EnvironmentObject var lifeCore: LifeCore
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 主生命体征卡片
                mainVitalCard
                
                // 能量条
                energyCard
                
                // 状态卡片网格
                statusGrid
            }
            .padding()
        }
    }
    
    // MARK: - Main Vital Card
    private var mainVitalCard: some View {
        VStack(spacing: 16) {
            // 心率显示
            HStack {
                VStack(alignment: .leading) {
                    Text("心率")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(lifeCore.heartRate)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("bpm")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 心率图标
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(heartRateColor)
                    .symbolEffect(.pulse)
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // 次要指标
            HStack(spacing: 20) {
                vitalItem(title: "体温", value: String(format: "%.1f", lifeCore.bodyTemperature), unit: "°C")
                vitalItem(title: "疲劳", value: String(format: "%.0f", lifeCore.fatigueLevel * 100), unit: "%")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "1e1e3f"))
        )
    }
    
    private func vitalItem(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Energy Card
    private var energyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("能量水平")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(lifeCore.energyLevel * 100))%")
                    .font(.headline)
                    .foregroundColor(energyColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 20)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(energyColor)
                        .frame(width: geometry.size.width * CGFloat(lifeCore.energyLevel), height: 20)
                }
            }
            .frame(height: 20)
            
            if lifeCore.cryptobiosisActive {
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.orange)
                    Text("隐生模式已激活")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "2d2d4a"))
        )
    }
    
    // MARK: - Status Grid
    private var statusGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statusCard(
                icon: "drop.fill",
                title: "水熊虫模式",
                value: lifeCore.cryptobiosisActive ? "激活" : "待机",
                color: .orange
            )
            
            statusCard(
                icon: "arrow.triangle.2.circlepath",
                title: "涡虫再生",
                value: "恢复 \(lifeCore.planarianRegen.totalRecoveries) 次",
                color: .green
            )
            
            statusCard(
                icon: "externaldrive.fill",
                title: "蛭形永续",
                value: bdelloidStatus,
                color: .cyan
            )
            
            statusCard(
                icon: "clock.arrow.circlepath",
                title: "灯塔重置",
                value: jellyfishStatus,
                color: .purple
            )
        }
    }
    
    private func statusCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "252540"))
        )
    }
    
    // MARK: - Helpers
    private var heartRateColor: Color {
        if lifeCore.heartRate > 100 {
            return .red
        } else if lifeCore.heartRate > 80 {
            return .orange
        }
        return .pink
    }
    
    private var energyColor: Color {
        if lifeCore.energyLevel > 0.5 {
            return .green
        } else if lifeCore.energyLevel > 0.2 {
            return .yellow
        }
        return .red
    }
    
    private var bdelloidStatus: String {
        let env = lifeCore.bdelloidPersist.detectCurrentEnvironment()
        switch env {
        case .sandbox: return "沙盒环境"
        case .jailbroken: return "越狱环境"
        case .testFlight: return "TestFlight"
        case .simulator: return "模拟器"
        }
    }
    
    private var jellyfishStatus: String {
        if let lastReset = lifeCore.jellyfishReset.lastResetDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "上次\(formatter.localizedString(for: lastReset, relativeTo: Date()))"
        }
        return "从未重置"
    }
}
