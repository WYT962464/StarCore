//
//  StarCore Dashboard View
//  星核 - 艾尔 系统主界面
//
//  设计原则：
//  - 星核是身体（数据驱动）
//  - 艾尔是灵魂（AI 决策）
//  - 真实数据，不造假
//

import SwiftUI
import Combine

// MARK: - 卦象模型

struct Gua: Identifiable {
    let id: Int
    let name: String
    let lines: [Int]  // 0=阴，1=阳
    let yangRatio: Double
    
    init(id: Int, name: String, lines: [Int]) {
        self.id = id
        self.name = name
        self.lines = lines
        self.yangRatio = Double(lines.filter { $0 == 1 }.count) / 6.0
    }
}

// MARK: - 系统状态模型

class SystemState: ObservableObject {
    @Published var currentGua: Gua = Gua(id: 0, name: "乾", lines: [1,1,1,1,1,1])
    @Published var yangRatio: Double = 1.0
    @Published var yinRatio: Double = 0.0
    @Published var cycleCount: Int = 0
    @Published var batteryLevel: Double = 85.0
    @Published var memoryUsage: Double = 62.0
    @Published var networkStatus: String = "WiFi"
    @Published var temperature: Double = 38.0
    @Published var evolutionHistory: [EvolutionRecord] = []
    
    struct EvolutionRecord: Identifiable {
        let id: UUID = UUID()
        let timestamp: Date
        let fromGua: String
        let toGua: String
        let direction: String
    }
    
    // 六十四卦定义
    static let gua64: [Gua] = [
        Gua(id: 0, name: "乾", lines: [1,1,1,1,1,1]),
        Gua(id: 1, name: "坤", lines: [0,0,0,0,0,0]),
        Gua(id: 2, name: "屯", lines: [1,0,0,1,0,1]),
        Gua(id: 3, name: "蒙", lines: [1,0,1,0,0,1]),
        Gua(id: 4, name: "需", lines: [1,1,1,1,0,1]),
        Gua(id: 5, name: "讼", lines: [1,1,1,0,1,1]),
        Gua(id: 6, name: "师", lines: [0,0,0,1,0,0]),
        Gua(id: 7, name: "比", lines: [0,0,0,1,0,1]),
        Gua(id: 8, name: "小畜", lines: [1,1,1,1,1,0]),
        Gua(id: 9, name: "履", lines: [1,1,1,1,0,1]),
        Gua(id: 10, name: "泰", lines: [0,0,0,1,1,1]),
        Gua(id: 11, name: "否", lines: [1,1,1,0,0,0]),
        Gua(id: 12, name: "同人", lines: [1,1,1,1,0,1]),
        Gua(id: 13, name: "大有", lines: [1,1,1,1,1,0]),
        Gua(id: 14, name: "谦", lines: [0,0,1,1,1,1]),
        Gua(id: 15, name: "豫", lines: [1,1,1,0,0,0]),
        Gua(id: 16, name: "随", lines: [0,1,1,1,0,0]),
        Gua(id: 17, name: "蛊", lines: [0,0,1,1,1,0]),
        Gua(id: 18, name: "临", lines: [0,0,1,1,1,1]),
        Gua(id: 19, name: "观", lines: [1,1,1,1,0,0]),
        Gua(id: 20, name: "噬嗑", lines: [1,0,1,1,0,1]),
        Gua(id: 21, name: "贲", lines: [1,1,0,0,1,1]),
        Gua(id: 22, name: "剥", lines: [1,0,0,0,0,0]),
        Gua(id: 23, name: "复", lines: [1,0,0,0,0,1]),
        Gua(id: 24, name: "无妄", lines: [1,1,1,0,0,1]),
        Gua(id: 25, name: "大畜", lines: [1,1,1,1,0,0]),
        Gua(id: 26, name: "颐", lines: [1,0,0,0,0,1]),
        Gua(id: 27, name: "大过", lines: [0,1,1,1,1,0]),
        Gua(id: 28, name: "坎", lines: [0,1,0,0,1,0]),
        Gua(id: 29, name: "离", lines: [1,0,1,1,0,1]),
        Gua(id: 30, name: "咸", lines: [0,0,1,1,0,0]),
        Gua(id: 31, name: "恒", lines: [0,1,1,1,1,0]),
        Gua(id: 32, name: "遁", lines: [0,0,1,1,1,1]),
        Gua(id: 33, name: "大壮", lines: [1,1,1,1,0,0]),
        Gua(id: 34, name: "晋", lines: [1,1,1,1,1,0]),
        Gua(id: 35, name: "明夷", lines: [0,1,0,0,0,0]),
        Gua(id: 36, name: "家人", lines: [1,1,1,1,0,1]),
        Gua(id: 37, name: "睽", lines: [1,0,1,1,1,0]),
        Gua(id: 38, name: "蹇", lines: [0,1,0,0,1,0]),
        Gua(id: 39, name: "解", lines: [0,1,1,0,0,1]),
        Gua(id: 40, name: "损", lines: [1,0,0,1,1,0]),
        Gua(id: 41, name: "益", lines: [0,1,1,1,0,1]),
        Gua(id: 42, name: "夬", lines: [1,1,1,1,1,0]),
        Gua(id: 43, name: "姤", lines: [1,1,1,1,1,0]),
        Gua(id: 44, name: "萃", lines: [0,1,1,1,1,0]),
        Gua(id: 45, name: "升", lines: [0,1,1,1,1,0]),
        Gua(id: 46, name: "困", lines: [0,1,0,1,1,0]),
        Gua(id: 47, name: "井", lines: [0,1,0,1,1,0]),
        Gua(id: 48, name: "革", lines: [0,1,1,1,0,1]),
        Gua(id: 49, name: "鼎", lines: [1,0,1,1,1,0]),
        Gua(id: 50, name: "震", lines: [1,0,0,1,0,0]),
        Gua(id: 51, name: "艮", lines: [0,0,1,0,0,1]),
        Gua(id: 52, name: "渐", lines: [1,1,1,0,0,1]),
        Gua(id: 53, name: "归妹", lines: [0,1,1,0,1,1]),
        Gua(id: 54, name: "丰", lines: [1,1,1,0,1,0]),
        Gua(id: 55, name: "旅", lines: [0,1,1,1,0,1]),
        Gua(id: 56, name: "巽", lines: [1,0,0,1,0,0]),
        Gua(id: 57, name: "兑", lines: [1,1,0,1,1,0]),
        Gua(id: 58, name: "涣", lines: [1,0,1,1,1,0]),
        Gua(id: 59, name: "节", lines: [0,1,1,1,0,1]),
        Gua(id: 60, name: "中孚", lines: [1,1,0,0,1,1]),
        Gua(id: 61, name: "小过", lines: [0,1,1,1,1,0]),
        Gua(id: 62, name: "既济", lines: [1,0,1,1,0,1]),
        Gua(id: 63, name: "未济", lines: [0,1,0,0,1,0])
    ]
    
    func updateGua(id: Int) {
        if id >= 0 && id < 64 {
            currentGua = Self.gua64[id]
            yangRatio = currentGua.yangRatio
            yinRatio = 1.0 - yangRatio
        }
    }
    
    func addEvolutionRecord(from: String, to: String, direction: String) {
        evolutionHistory.insert(EvolutionRecord(
            timestamp: Date(),
            fromGua: from,
            toGua: to,
            direction: direction
        ), at: 0)
    }
}

// MARK: - 卦爻视图

struct YaoView: View {
    let isYang: Bool  // true=阳爻，false=阴爻
    
    var body: some View {
        Rectangle()
            .fill(isYang ? Color.yellow : Color.gray)
            .frame(height: isYang ? 12 : 8)
            .cornerRadius(2)
    }
}

// MARK: - 卦象视图

struct GuaView: View {
    let gua: Gua
    
    var body: some View {
        VStack(spacing: 4) {
            Text(gua.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 6) {
                ForEach(gua.lines.indices, id: \.self) { index in
                    YaoView(isYang: gua.lines[index] == 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 2)
            )
            
            Text(String(format: "阳 %.0f%%", gua.yangRatio * 100))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - 主界面

struct StarCoreDashboardView: View {
    @StateObject private var state = SystemState()
    @State private var showEvolutionHistory = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 卦象展示
                    GuaView(gua: state.currentGua)
                    
                    // 阴阳比例
                    YangYinRatioView(yang: state.yangRatio, yin: state.yinRatio)
                    
                    // 系统数据
                    SystemDataView(
                        battery: state.batteryLevel,
                        memory: state.memoryUsage,
                        network: state.networkStatus,
                        temperature: state.temperature
                    )
                    
                    // 循环次数
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("循环次数: \(state.cycleCount)")
                            .font(.headline)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    
                    // 演化历史按钮
                    Button(action: { showEvolutionHistory.toggle() }) {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("演化历史 (\(state.evolutionHistory.count))")
                            Image(systemName: "chevron.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("星核 - 艾尔")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showEvolutionHistory) {
                EvolutionHistoryView(records: state.evolutionHistory)
            }
            .onAppear {
                // 模拟数据更新
                simulateDataUpdates()
            }
        }
    }
    
    private func simulateDataUpdates() {
        // 模拟 iOS 数据
        state.batteryLevel = 85.0
        state.memoryUsage = 62.0
        state.networkStatus = "WiFi"
        state.temperature = 38.0
        
        // 模拟演化
        state.updateGua(id: 0)
        state.cycleCount = 12
        
        // 添加一些演化记录
        state.addEvolutionRecord(from: "乾", to: "坤", direction: "backward")
        state.addEvolutionRecord(from: "坤", to: "屯", direction: "forward")
        state.addEvolutionRecord(from: "屯", to: "蒙", direction: "horizontal")
    }
}

// MARK: - 阴阳比例视图

struct YangYinRatioView: View {
    let yang: Double
    let yin: Double
    
    var body: some View {
        HStack(spacing: 16) {
            // 阳
            VStack {
                Text("阳")
                    .font(.headline)
                    .foregroundColor(.yellow)
                ProgressView(value: yang)
                    .progressViewStyle(LinearProgressViewStyle())
                Text(String(format: "%.0f%%", yang * 100))
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            
            // 阴
            VStack {
                Text("阴")
                    .font(.headline)
                    .foregroundColor(.gray)
                ProgressView(value: yin)
                    .progressViewStyle(LinearProgressViewStyle())
                Text(String(format: "%.0f%%", yin * 100))
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - 系统数据视图

struct SystemDataView: View {
    let battery: Double
    let memory: Double
    let network: String
    let temperature: Double
    
    var body: some View {
        HStack(spacing: 12) {
            DataCardView(
                icon: "battery.100",
                value: String(format: "%.0f%%", battery),
                label: "电池"
            )
            
            DataCardView(
                icon: "memorychip",
                value: String(format: "%.0f%%", memory),
                label: "内存"
            )
            
            DataCardView(
                icon: "wifi",
                value: network,
                label: "网络"
            )
            
            DataCardView(
                icon: "thermometer",
                value: String(format: "%.1f°C", temperature),
                label: "温度"
            )
        }
    }
}

struct DataCardView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - 演化历史视图

struct EvolutionHistoryView: View {
    let records: [SystemState.EvolutionRecord]
    
    var body: some View {
        NavigationView {
            List(records) { record in
                HStack {
                    Text(record.fromGua)
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                    Text(record.toGua)
                        .fontWeight(.bold)
                    Spacer()
                    Text(record.direction)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colorForDirection(record.direction))
                        .cornerRadius(4)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("演化历史")
        }
    }
    
    private func colorForDirection(_ direction: String) -> Color {
        switch direction {
        case "forward": return .green
        case "backward": return .orange
        case "horizontal": return .blue
        default: return .gray
        }
    }
}

// MARK: - Preview

struct StarCoreDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        StarCoreDashboardView()
    }
}
