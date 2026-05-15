import Foundation

// MARK: - Cloud Bridge Error
enum CloudBridgeError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case networkError(String)
    case serverError(Int, String)
    case timeout
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "云桥未配置"
        case .invalidURL:
            return "云桥URL格式错误"
        case .networkError(let msg):
            return "网络错误: \(msg)"
        case .serverError(let code, let msg):
            return "服务端错误 \(code): \(msg)"
        case .timeout:
            return "云桥请求超时"
        case .invalidResponse:
            return "云桥响应格式异常"
        }
    }
}

// MARK: - Cloud Bridge Client
class CloudBridgeClient {

    static let shared = CloudBridgeClient()

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Config Accessor

    var config: CloudBridgeConfig {
        get {
            if let data = defaults.data(forKey: "cloudBridgeConfig"),
               let decoded = try? JSONDecoder().decode(CloudBridgeConfig.self, from: data) {
                return decoded
            }
            return .default
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "cloudBridgeConfig")
            }
        }
    }

    // MARK: - Execute (Async)

    /// Execute a command on the cloud computer via Cloud Bridge
    /// - Parameters:
    ///   - command: Shell command to execute on the cloud computer
    ///   - timeout: Request timeout in seconds (default from config)
    ///   - completion: Result with CloudResult on success or CloudBridgeError on failure
    func execute(command: String, timeout: TimeInterval? = nil, completion: @escaping (Result<CloudResult, CloudBridgeError>) -> Void) {
        let cfg = config
        guard cfg.enabled, !cfg.serverUrl.isEmpty, !cfg.authToken.isEmpty else {
            completion(.failure(.notConfigured))
            return
        }

        guard let url = URL(string: cfg.serverUrl) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(cfg.authToken, forHTTPHeaderField: "X-StarCore-Token")
        request.timeoutInterval = timeout ?? Double(cfg.timeoutSeconds)

        let payload: [String: Any] = [
            "command": command,
            "source": "iphone",
            "timestamp": Int(Date().timeIntervalSince1970)
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(.networkError("序列化请求失败: \(error.localizedDescription)")))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                if (error as NSError).code == NSURLErrorTimedOut {
                    completion(.failure(.timeout))
                } else {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "unknown"
                completion(.failure(.serverError(httpResponse.statusCode, String(body.prefix(300)))))
                return
            }

            do {
                let result = try JSONDecoder().decode(CloudResult.self, from: data)
                completion(.success(result))
            } catch {
                // Try to parse as generic dict for better error info
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let output = json["output"] as? String {
                    let result = CloudResult(success: json["success"] as? Bool ?? true,
                                             output: output,
                                             exitCode: json["exitCode"] as? Int ?? 0,
                                             executionTime: json["executionTime"] as? Double ?? 0)
                    completion(.success(result))
                } else {
                    completion(.failure(.invalidResponse))
                }
            }
        }.resume()
    }

    // MARK: - Execute (Sync)

    /// Synchronous execute - blocks current thread until response or timeout
    func executeSync(command: String, timeout: TimeInterval? = nil) -> Result<CloudResult, CloudBridgeError> {
        var result: Result<CloudResult, CloudBridgeError>?
        let semaphore = DispatchSemaphore(value: 0)

        execute(command: command, timeout: timeout) { res in
            result = res
            semaphore.signal()
        }

        let waitTimeout = timeout ?? Double(config.timeoutSeconds)
        _ = semaphore.wait(timeout: .now() + waitTimeout + 5)

        return result ?? .failure(.timeout)
    }

    // MARK: - Health Check

    /// Check cloud bridge server health
    func healthCheck(completion: @escaping (Result<CloudHealth, CloudBridgeError>) -> Void) {
        let cfg = config
        guard !cfg.serverUrl.isEmpty else {
            completion(.failure(.notConfigured))
            return
        }

        // Build health check URL: base URL + /health
        let healthUrlStr: String
        if cfg.serverUrl.hasSuffix("/execute") {
            healthUrlStr = cfg.serverUrl.replacingOccurrences(of: "/execute", with: "/health")
        } else if cfg.serverUrl.hasSuffix("/") {
            healthUrlStr = cfg.serverUrl + "health"
        } else {
            healthUrlStr = cfg.serverUrl + "/health"
        }

        guard let url = URL(string: healthUrlStr) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cfg.authToken, forHTTPHeaderField: "X-StarCore-Token")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                if (error as NSError).code == NSURLErrorTimedOut {
                    completion(.failure(.timeout))
                } else {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                completion(.failure(.serverError(httpResponse.statusCode, "健康检查失败")))
                return
            }

            do {
                let health = try JSONDecoder().decode(CloudHealth.self, from: data)
                completion(.success(health))
            } catch {
                // Fallback: treat any 200 response as healthy
                let health = CloudHealth(status: "ok", uptime: nil, version: nil)
                completion(.success(health))
            }
        }.resume()
    }

    // MARK: - Sign Payload (MVP: Token-only auth, no HMAC)

    /// Sign a payload for authentication.
    /// MVP: Returns empty string (Token auth only).
    /// Future: Implement HMAC-SHA256 with CommonCrypto.
    func signPayload(_ payload: String) -> String {
        // MVP: Token-based auth only, no HMAC signing
        return ""
    }

    // MARK: - Availability Check

    /// Check if cloud bridge is available (enabled + configured)
    var isAvailable: Bool {
        let cfg = config
        return cfg.enabled && !cfg.serverUrl.isEmpty && !cfg.authToken.isEmpty
    }
}
