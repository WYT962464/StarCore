/**
 * ServerConnectionManager.swift
 * 服务器连接管理器 - SSH 隧道管理
 * 
 * 功能：
 * - SSH 隧道连接状态监控
 * - 服务器端工具调用（通过隧道）
 * - 自动重连
 * 
 * 隧道配置：
 * - 服务器：124.222.29.75
 * - 端口：8028
 * - 用户：ubuntu
 */

import Foundation
import Combine

@available(iOS 15.0, *)
final class ServerConnectionManager: ObservableObject {
    // MARK: - 连接状态
    @Published var isConnected: Bool = false
    @Published var connectionError: String?
    @Published var lastActivity: Date?
    @Published var serverInfo: ServerInfo?
    
    // MARK: - 配置
    struct ServerConfig {
        let host: String
        let port: Int
        let user: String
        let tunnelPort: Int
    }
    
    private let config = ServerConfig(
        host: "124.222.29.75",
        port: 22,
        user: "ubuntu",
        tunnelPort: 8028
    )
    
    // 公共访问方法
    var tunnelHost: String { config.host }
    var tunnelPort: Int { config.tunnelPort }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // 定时检查连接状态 - 使用 Timer.publish 使其可取消
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkConnection()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 连接检查
    func checkConnection() {
        Task {
            // 检查隧道端口是否可达
            let socket = SocketConnection(host: "127.0.0.1", port: config.tunnelPort)
            let reachable = await socket.checkReachability(timeout: 3.0)
            
            await MainActor.run {
                self.isConnected = reachable
                self.connectionError = reachable ? nil : "SSH 隧道未连接"
                if reachable {
                    self.lastActivity = Date()
                    self.serverInfo = ServerInfo(
                        host: config.host,
                        user: config.user,
                        tunnelPort: config.tunnelPort,
                        status: "connected"
                    )
                }
            }
        }
    }
    
    // MARK: - 服务器端工具调用
    
    /// 执行服务器端命令
    func executeCommand(_ command: String) async throws -> String {
        guard isConnected else {
            throw ServerError.notConnected
        }
        
        // 通过隧道端口转发执行命令
        // 实际实现需要使用 SSH 库或通过 MCP 代理
        throw ServerError.notImplemented
    }
    
    /// 上传文件到服务器
    func uploadFile(localPath: String, remotePath: String) async throws {
        guard isConnected else {
            throw ServerError.notConnected
        }
        throw ServerError.notImplemented
    }
    
    /// 下载文件从服务器
    func downloadFile(remotePath: String, localPath: String) async throws {
        guard isConnected else {
            throw ServerError.notConnected
        }
        throw ServerError.notImplemented
    }
    
    /// 获取服务器状态
    func getServerStatus() async throws -> [String: Any] {
        guard isConnected else {
            throw ServerError.notConnected
        }
        
        // 通过隧道调用服务器 API
        let url = URL(string: "http://127.0.0.1:\(config.tunnelPort)/api/status")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServerError.serverError
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServerError.invalidResponse
        }
        
        return json
    }
}

// MARK: - 服务器信息
struct ServerInfo: Codable {
    let host: String
    let user: String
    let tunnelPort: Int
    let status: String
}

// MARK: - Socket 连接辅助类
class SocketConnection {
    private let host: String
    private let port: Int
    
    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
    
    func checkReachability(timeout: TimeInterval) async -> Bool {
        return await withCheckedContinuation { continuation in
            var sockaddr = sockaddr_in()
            sockaddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            sockaddr.sin_family = sa_family_t(AF_INET)
            sockaddr.sin_port = UInt16(port).bigEndian
            
            // 解析主机
            if let hostData = host.data(using: .ascii),
               inet_pton(AF_INET, (hostData as NSData).bytes.assumingMemoryBound(to: Int8.self), &sockaddr.sin_addr.s_addr) == 1 {
                
                let socketFD = socket(AF_INET, SOCK_STREAM, 0)
                guard socketFD >= 0 else {
                    continuation.resume(returning: false)
                    return
                }
                
                // 设置超时
                let timeoutSeconds = Int32(timeout)
                var tv = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
                setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                
                let result = connect(socketFD, sockaddr_cast(&sockaddr), socklen_t(MemoryLayout<sockaddr_in>.size))
                close(socketFD)
                
                continuation.resume(returning: result == 0)
            } else {
                continuation.resume(returning: false)
            }
        }
    }
    
    private func sockaddr_cast(_ ptr: inout sockaddr_in) -> UnsafeMutablePointer<sockaddr> {
        return withUnsafeMutablePointer(to: &ptr) {
            UnsafeMutableRawPointer($0).assumingMemoryBound(to: sockaddr.self)
        }
    }
}

// MARK: - 错误类型
enum ServerError: LocalizedError {
    case notConnected
    case notImplemented
    case serverError
    case invalidResponse
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .notConnected: return "未连接到服务器"
        case .notImplemented: return "功能未实现"
        case .serverError: return "服务器错误"
        case .invalidResponse: return "无效的响应"
        case .timeout: return "请求超时"
        }
    }
}
