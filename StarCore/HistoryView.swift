import SwiftUI

struct HistoryView: View {
    let history: [DailyStats]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.15).ignoresSafeArea()
            
            if history.isEmpty {
                VStack(spacing: 16) {
                    Text("📜").font(.system(size: 60))
                    Text("暂无历史记录").font(.title2).foregroundColor(.gray)
                    Text("运行越久，记忆越深").font(.caption).foregroundColor(.gray.opacity(0.6))
                    Button("返回") { dismiss() }.foregroundColor(.cyan).padding()
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        HStack {
                            Text("📜 成长轨迹").font(.title2).fontWeight(.bold).foregroundColor(.cyan)
                            Spacer()
                            Text("\(history.count)天").font(.caption).foregroundColor(.gray)
                        }.padding(.horizontal)
                        
                        // 趋势概览
                        if history.count >= 2 {
                            let latest = history.last!
                            let prev = history[history.count - 2]
                            VStack(spacing: 8) {
                                Text("最近变化").font(.headline).foregroundColor(.white.opacity(0.8))
                                HStack(spacing: 20) {
                                    TrendItem(label: "气血", current: latest.batteryAvg, previous: prev.batteryAvg, isPercent: true, color: .green)
                                    TrendItem(label: "心跳", current: latest.cpuAvg, previous: prev.cpuAvg, isPercent: false, color: .red)
                                    TrendItem(label: "思维", current: latest.memoryAvg, previous: prev.memoryAvg, isPercent: false, color: .purple)
                                }
                            }.padding(12).background(Color.white.opacity(0.06)).cornerRadius(10).padding(.horizontal)
                        }
                        
                        // 每日卡片
                        ForEach(history.reversed(), id: \.date) { day in
                            DayCard(stats: day)
                        }
                        
                        Button("返回") { dismiss() }.foregroundColor(.cyan).padding()
                    }.padding(.vertical)
                }
            }
        }
    }
}

struct TrendItem: View {
    let label: String; let current: Double; let previous: Double; let isPercent: Bool; let color: Color
    var diff: Double { current - previous }
    var diffStr: String {
        if abs(diff) < 0.1 { return "→" }
        return diff > 0 ? "↑\(String(format: "%.1f", abs(diff)))" : "↓\(String(format: "%.1f", abs(diff)))"
    }
    var diffColor: Color { abs(diff) < 0.1 ? .gray : diff > 0 ? .green : .red }
    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundColor(color)
            Text(isPercent ? String(format: "%.0f%%", current * 100) : String(format: "%.1f%%", current))
                .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            Text(diffStr).font(.system(size: 10)).foregroundColor(diffColor)
        }
    }
}

struct DayCard: View {
    let stats: DailyStats
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(stats.date).font(.headline).foregroundColor(.cyan)
                Spacer()
                if !stats.dominantHexagram.isEmpty {
                    Text(stats.dominantHexagram + "卦").font(.caption).padding(.horizontal, 6).padding(.vertical, 2).background(Color.cyan.opacity(0.2)).cornerRadius(4).foregroundColor(.cyan)
                }
            }
            
            HStack(spacing: 16) {
                MiniStat(icon: "💚", value: String(format: "%.0f%%", stats.batteryAvg * 100), color: .green)
                MiniStat(icon: "❤️", value: String(format: "%.1f%%", stats.cpuAvg), color: .red)
                MiniStat(icon: "💜", value: String(format: "%.1f%%", stats.memoryAvg), color: .purple)
                MiniStat(icon: "☯️", value: "\(stats.hexagramChanges)变", color: .cyan)
            }
            
            // 气血条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.2)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(Color.green.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(stats.batteryAvg), height: 4)
                }
            }.frame(height: 4)
        }
        .padding(10).background(Color.white.opacity(0.04)).cornerRadius(8).padding(.horizontal)
    }
}

struct MiniStat: View {
    let icon: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 1) {
            Text(icon).font(.system(size: 12))
            Text(value).font(.system(size: 10)).foregroundColor(color)
        }
    }
}

#Preview { HistoryView(history: []) }
