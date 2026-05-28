
// MARK: - NewTerm 终端集成
import Foundation

/// NewTerm URL Scheme 客户端
/// 支持通过 URL Scheme 启动 NewTerm 并执行命令
class NewTermClient: ObservableObject {
    static let shared = NewTermClient()
    
    @Published var lastCommand: String = ""
    @Published var isLaunching: Bool = false
    
    private let bundleID = "ws.hbang.Terminal"
    private let scheme = "newterm"
    
    /// 检查 NewTerm 是否已安装
    func isInstalled() -> Bool {
        let url = URL(string: "\(scheme)://")!
        return UIApplication.shared.canOpenURL(url)
    }
    
    /// 启动 NewTerm 并执行命令
    /// - Parameter command: 要执行的命令
    /// - Returns: 是否成功启动
    @MainActor
    func execute(command: String) -> Bool {
        // 对命令进行 URL 编码
        let encodedCommand = command.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? command
        
        // 构建 NewTerm URL
        // newterm://?cmd=<command>
        guard let url = URL(string: "\(scheme)://?cmd=\(encodedCommand)") else {
            return false
        }
        
        isLaunching = true
        lastCommand = command
        
        // 启动 NewTerm
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIApplication.shared.open(url, options: [:]) { success in
                Task { @MainActor in
                    self.isLaunching = false
                    if !success {
                        print("❌ 无法启动 NewTerm，请确认已安装")
                    }
                }
            }
        }
        
        return true
    }
    
    /// 启动 NewTerm 并进入指定目录
    /// - Parameter path: 目录路径
    @MainActor
    func cd(path: String) -> Bool {
        return execute(command: "cd \(path)")
    }
    
    /// 执行命令并获取输出（需要 a-Shell 支持）
    /// 注意：NewTerm 本身不支持返回输出，此方法仅启动终端
    func executeAndGetOutput(command: String) async -> String {
        // NewTerm 不支持回调获取输出
        // 需要使用 a-Shell 的 x-callback-url 或 SSH 隧道
        execute(command: command)
        return "[NewTerm 启动，无法直接获取输出]"
    }
}

// MARK: - a-Shell 终端集成（备选方案）
/// a-Shell 支持 x-callback-url，可以获取命令输出
class AShellClient: ObservableObject {
    static let shared = AShellClient()
    
    @Published var lastOutput: String = ""
    
    private let scheme = "x-callback-url"
    
    /// 检查 a-Shell 是否已安装
    func isInstalled() -> Bool {
        let url = URL(string: "ashell://")!
        return UIApplication.shared.canOpenURL(url)
    }
    
    /// 执行命令并获取输出（通过 x-callback-url）
    /// - Parameter command: 要执行的命令
    /// - Returns: 命令输出
    @MainActor
    func execute(command: String) async -> String {
        let encodedCommand = command.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? command
        
        // a-Shell x-callback-url 格式
        // x-callback-url://exec?cmd=<command>&x-success=<callback>
        guard let url = URL(string: "x-callback-url://exec?cmd=\(encodedCommand)") else {
            return "❌ 无效的命令格式"
        }
        
        do {
            try await UIApplication.shared.open(url)
            return "[a-Shell 已启动，输出将在终端中显示]"
        } catch {
            return "❌ 无法启动 a-Shell: \(error.localizedDescription)"
        }
    }
}
