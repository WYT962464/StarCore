
// MARK: - SSH 远程执行
/// 通过 SSH 隧道执行 iPhone 上的命令
/// 这是 AI 如臂指使的核心能力
class SSHExecutor: ObservableObject {
    static let shared = SSHExecutor()
    
    @Published var lastOutput: String = ""
    @Published var isExecuting: Bool = false
    
    private let sshPort = 8028
    private let sshUser = "mobile"
    
    /// 检查 SSH 隧道是否可用
    func isAvailable() -> Bool {
        // 检查端口是否监听
        let socket = socket(AF_INET, SOCK_STREAM, 0)
        defer { if socket >= 0 { close(socket) } }
        
        var sockaddr = sockaddr_in()
        sockaddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        sockaddr.sin_family = sa_family_t(AF_INET)
        sockaddr.sin_port = UInt16(sshPort).bigEndian
        sockaddr.sin_addr.s_addr = UInt32(0x7F000001) // 127.0.0.1
        
        let result = withUnsafePointer(to: &sockaddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        return result == 0
    }
    
    /// 执行远程命令
    /// - Parameter command: 要执行的命令
    /// - Returns: 命令输出
    @MainActor
    func execute(_ command: String) async -> String {
        isExecuting = true
        defer { isExecuting = false }
        
        // 注意：iOS 端无法直接执行 SSH，需要服务器端代理
        // 这里返回提示信息，实际执行需要通过服务器 API
        
        return """
        ⚠️ SSH 执行需要服务器端代理
        
        iOS 沙盒限制：无法直接执行 SSH 命令
        
        替代方案：
        1. 通过服务器 API: POST http://server:8080/api/exec
        2. 使用 NewTerm: NewTermTerminal.shared.execute(command:)
        3. 使用 a-Shell: AShellTerminal.shared.execute(command:)
        
        命令: \(command)
        """
    }
}
