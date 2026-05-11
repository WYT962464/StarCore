import SwiftUI

@available(iOS 15.0, *)
struct DashboardView: View {
    @EnvironmentObject var lifeCore: LifeCore
    @EnvironmentObject var mindCore: MindCore
    
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(red: 26/255, green: 26/255, blue: 46/255)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    topStatusBar
                    tabSelector
                    
                    TabView(selection: $selectedTab) {
                        LifeSignsView()
                            .tag(0)
                        EmotionView()
                            .tag(1)
                        ControlView()
                            .tag(2)
                        SystemLogsView()
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                startUpdateTimer()
                // 启动时自动检测操控服务连接
                ActionCoordinator.shared.connectAll()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var topStatusBar: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(lifeCore.cryptobiosisActive ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(lifeCore.cryptobiosisActive ? "隐生" : "活跃")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            // 操控状态指示
            HStack(spacing: 6) {
                Circle()
                    .fill(ActionCoordinator.shared.isAnyControlAvailable ? Color.cyan : Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                Text(ActionCoordinator.shared.isAnyControlAvailable ? "操控可用" : "操控离线")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(currentTime)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton("生命体征", index: 0)
            tabButton("情绪", index: 1)
            tabButton("操控", index: 2)
            tabButton("日志", index: 3)
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
    
    private func startUpdateTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            mindCore.updateCognitiveState()
        }
    }
    
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
