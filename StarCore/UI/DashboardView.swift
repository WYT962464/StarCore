import SwiftUI

/// 主仪表盘视图
@available(iOS 15.0, *)
struct DashboardView: View {
    @EnvironmentObject var lifeCore: LifeCore
    @EnvironmentObject var mindCore: MindCore
    
    @State private var selectedTab = 0
    @State private var showLogs = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [Color.black, Color(hex: "1a1a2e")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部状态栏
                    topStatusBar
                    
                    // Tab选择器
                    tabSelector
                    
                    // 主内容区
                    TabView(selection: $selectedTab) {
                        LifeSignsView()
                            .tag(0)
                        
                        EmotionView()
                            .tag(1)
                        
                        SystemLogsView()
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                startUpdateTimer()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Top Status Bar
    private var topStatusBar: some View {
        HStack {
            // 系统状态
            HStack(spacing: 8) {
                Circle()
                    .fill(lifeCore.cryptobiosisActive ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(lifeCore.cryptobiosisActive ? "隐生" : "活跃")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 时间
            Text(currentTime)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton("生命体征", index: 0)
            tabButton("情绪", index: 1)
            tabButton("系统日志", index: 2)
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
    
    private func tabButton(_ title: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(selectedTab == index ? .semibold : .regular)
                    .foregroundColor(selectedTab == index ? .white : .gray)
                
                Rectangle()
                    .fill(selectedTab == index ? Color.blue : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Timer
    private func startUpdateTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            mindCore.updateCognitiveState()
        }
    }
    
    // MARK: - Helpers
    private var currentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

// MARK: - System Logs View
@available(iOS 15.0, *)
struct SystemLogsView: View {
    @EnvironmentObject var lifeCore: LifeCore
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(lifeCore.systemLogs.reversed()) { log in
                    logRow(log)
                }
            }
            .padding()
        }
    }
    
    private func logRow(_ log: SystemLog) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("[\(log.level.rawValue)]")
                .font(.caption)
                .foregroundColor(logColor(for: log.level))
                .frame(width: 50, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(log.message)
                    .font(.caption)
                    .foregroundColor(.white)
                
                Text(timeString(log.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func logColor(for level: LogLevel) -> Color {
        switch level {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
