import Foundation

// MARK: - SSE Streaming LLM 封装
// 兼容 iOS 14，使用 URLSessionDataDelegate 方式处理SSE流
class StreamingLLM: NSObject, URLSessionDataDelegate {

    private var onToken: ((String) -> Void)?
    private var onStatus: ((String) -> Void)?
    private var completion: ((Result<String, Error>) -> Void)?
    private var accumulated = ""
    private var buffer = ""
    private var session: URLSession?

    /// 流式调用LLM（iOS 14兼容，使用delegate模式）
    /// - Parameters:
    ///   - provider: LLM Provider配置
    ///   - messages: 消息数组，支持文字和图片
    ///   - onToken: 每收到一个token就回调
    ///   - onStatus: 执行状态回调（如"思考中..."、"生成中..."）
    ///   - completion: 全部完成后回调
    static func call(
        provider: LLMProvider,
        messages: [[String: Any]],
        onToken: @escaping (String) -> Void,
        onStatus: ((String) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Guest DeepSeek provider走专用路径
        if provider.name.contains("访客") {
            GuestLLM.chat(
                provider: provider,
                messages: messages,
                onToken: onToken,
                onStatus: onStatus,
                completion: completion
            )
            return
        }

        guard !provider.apiKey.isEmpty else {
            completion(.success("⚠️ 当前Provider未配置API Key，请在设置中填写。\n💡 \(LLMProvider.keyHint(forProviderIndex: StarCoreAgent.shared.currentProviderIndex))"))
            return
        }
        guard !provider.url.isEmpty else {
            completion(.success("⚠️ 当前Provider URL为空，请在设置中配置。"))
            return
        }

        // 构建请求URL（Gemini需要在URL中加key参数）
        var requestURLString = provider.url
        if provider.url.contains("generativelanguage.googleapis.com") {
            let separator = provider.url.contains("?") ? "&" : "?"
            requestURLString = "\(provider.url)\(separator)key=\(provider.apiKey)"
        }

        guard let url = URL(string: requestURLString) else {
            completion(.success("⚠️ API URL格式错误。"))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Gemini通过URL参数认证，但仍兼容Bearer token方式
        if !provider.url.contains("generativelanguage.googleapis.com") {
            request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.timeoutInterval = 120  // 流式请求需要更长超时

        let payload: [String: Any] = [
            "model": provider.model,
            "messages": messages,
            "max_tokens": 2048,
            "temperature": 0.7,
            "stream": true  // 关键！启用SSE流式
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        // 创建StreamingLLM实例处理delegate
        let streamer = StreamingLLM()
        streamer.onToken = onToken
        streamer.onStatus = onStatus
        streamer.completion = completion

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        streamer.session = URLSession(configuration: config, delegate: streamer, delegateQueue: nil)

        let task = streamer.session?.dataTask(with: request)
        task?.resume()

        // 保持streamer强引用直到完成
        objc_setAssociatedObject(task!, "streamer", streamer, .OBJC_ASSOCIATION_RETAIN)
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text

        // 按行处理SSE数据
        let lines = buffer.components(separatedBy: "\n")
        // 最后一行可能不完整，保留在buffer中
        // 如果buffer以\n结尾，所有行都是完整的（最后一行是空字符串）
        if buffer.hasSuffix("\n") {
            buffer = ""
            // 过滤掉空行
            let processLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            for line in processLines {
                processSSELine(line)
            }
        } else {
            // 最后一行不完整，保留在buffer中
            buffer = lines.last ?? ""
            let processLines = lines.dropLast().filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            for line in processLines {
                processSSELine(line)
            }
        }
    }

    /// 处理单行SSE数据
    private func processSSELine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("data: ") else { return }

        let jsonStr = String(trimmed.dropFirst(6))

        // SSE结束标记
        if jsonStr == "[DONE]" {
            finishWithAccumulated()
            return
        }

        // 解析SSE JSON
        guard let jsonData = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return
        }

        // 检查错误
        if let error = json["error"] as? [String: Any] {
            let msg = error["message"] as? String ?? "未知错误"
            let nsError = NSError(domain: "StarCore", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
            completion?(.failure(nsError))
            return
        }

        // 提取delta content（标准OpenAI兼容格式 + reasoning_content深度思考）
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let delta = firstChoice["delta"] as? [String: Any] {
            // reasoning_content: 深度思考模型的思考过程（如doubao-seed）
            if let reasoning = delta["reasoning_content"] as? String, !reasoning.isEmpty {
                accumulated += reasoning
                onToken?(reasoning)
            }
            // content: 正式回复内容
            if let content = delta["content"] as? String, !content.isEmpty {
                accumulated += content
                onToken?(content)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // 检查HTTP状态码错误
        if let httpResponse = task.response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            if accumulated.isEmpty {
                let msg: String
                switch httpResponse.statusCode {
                case 401: msg = "API Key无效或未填写，请在设置中检查"
                case 402: msg = "API余额不足，请充值或切换Provider"
                case 429: msg = "API速率限制，请稍后重试或切换Provider"
                case 500...599: msg = "服务器错误(\(httpResponse.statusCode))，请稍后重试"
                default: msg = "HTTP错误(\(httpResponse.statusCode))"
                }
                let nsError = NSError(domain: "StarCore", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
                completion?(.failure(nsError))
                session.invalidateAndCancel()
                return
            }
        }

        if let error = error {
            // 如果已经积累了一些内容，说明是中途断开，返回已有内容
            if !accumulated.isEmpty {
                completion?(.success(accumulated))
            } else {
                completion?(.failure(error))
            }
        } else {
            // 正常完成（可能没有收到[DONE]标记）
            finishWithAccumulated()
        }

        // 清理
        session.invalidateAndCancel()
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // 允许所有证书（开发阶段）
        completionHandler(.performDefaultHandling, nil)
    }

    private func finishWithAccumulated() {
        if accumulated.isEmpty {
            completion?(.success("（空回复）"))
        } else {
            completion?(.success(accumulated))
        }
    }
}

// MARK: - DeepSeek 访客模式 LLM
// 逆向自DeepSeek App的GuestApi/GuestContext，无需API Key
class GuestLLM: NSObject, URLSessionDataDelegate {

    private var onToken: ((String) -> Void)?
    private var onStatus: ((String) -> Void)?
    private var completion: ((Result<String, Error>) -> Void)?
    private var accumulated = ""
    private var buffer = ""
    private var session: URLSession?
    private var cookies: [HTTPCookie] = []

    // 共享Cookie存储（访客会话自动获取Cookie）
    private static var sharedCookies: [HTTPCookie] = []

    /// 访客模式聊天（SSE流式）
    static func chat(
        provider: LLMProvider,
        messages: [[String: Any]],
        onToken: @escaping (String) -> Void,
        onStatus: ((String) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        onStatus?("🔑 获取访客权限...")

        // 提取用户消息（最后一条user消息）
        let userMessage = messages.last(where: { $0["role"] as? String == "user" })?["content"] as? String ?? ""

        // 第一步：尝试获取PoW挑战
        fetchPowChallenge { powResult in
            switch powResult {
            case .success(let powResponse):
                // 有PoW挑战，需要求解
                onStatus?("⛏️ 计算PoW证明...")

                DispatchQueue.global(qos: .userInitiated).async {
                    if let answer = solvePowChallenge(challenge: powResponse) {
                        let powHeader = buildPowResponse(challenge: powResponse, answer: answer)

                        DispatchQueue.main.async {
                            onStatus?("🤔 思考中...")
                            sendGuestChat(message: userMessage, powHeader: powHeader, onToken: onToken, onStatus: onStatus, completion: completion)
                        }
                    } else {
                        // PoW求解失败，尝试不带PoW请求
                        print("[GuestLLM] PoW求解失败，尝试不带PoW...")
                        DispatchQueue.main.async {
                            onStatus?("🤔 思考中...")
                            sendGuestChat(message: userMessage, powHeader: nil, onToken: onToken, onStatus: onStatus, completion: completion)
                        }
                    }
                }

            case .failure:
                // 无PoW或获取失败，直接请求
                print("[GuestLLM] 获取PoW失败，尝试不带PoW直接请求...")
                onStatus?("🤔 思考中...")
                sendGuestChat(message: userMessage, powHeader: nil, onToken: onToken, onStatus: onStatus, completion: completion)
            }
        }
    }

    // MARK: - PoW Challenge 获取

    /// PoW挑战响应结构
    struct PowChallengeResponse {
        let algorithm: String
        let challenge: String
        let salt: String
        let difficulty: Int
        let expireAt: Int
        let signature: String
        let targetPath: String
    }

    /// 获取PoW挑战
    private static func fetchPowChallenge(completion: @escaping (Result<PowChallengeResponse, Error>) -> Void) {
        // 先尝试guest专用挑战端点
        guard let url = URL(string: "https://chat.deepseek.com/api/v0/chat/create_pow_challenge") else {
            completion(.failure(NSError(domain: "GuestLLM", code: -1, userInfo: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("chat.deepseek.com", forHTTPHeaderField: "Host")
        request.setValue("https://chat.deepseek.com", forHTTPHeaderField: "Origin")
        request.setValue("https://chat.deepseek.com", forHTTPHeaderField: "Referer")
        request.setValue("StarCore/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let payload: [String: Any] = [
            "target_path": "/api/v0/guest/chat/completion"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        // 附加已有Cookie
        if !sharedCookies.isEmpty {
            let cookieHeader = sharedCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[GuestLLM] PoW挑战请求失败: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            // 保存Cookie
            if let httpResponse = response as? HTTPURLResponse {
                saveCookies(from: httpResponse)
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "GuestLLM", code: -2, userInfo: [NSLocalizedDescriptionKey: "空响应"])))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // 检查是否有data字段嵌套
                    let challengeData = json["data"] as? [String: Any] ?? json

                    let algorithm = challengeData["algorithm"] as? String ?? "DeepSeekHashV1"
                    let challenge = challengeData["challenge"] as? String ?? ""
                    let salt = challengeData["salt"] as? String ?? ""
                    let difficulty = challengeData["difficulty"] as? Int ?? 0
                    let expireAt = challengeData["expire_at"] as? Int ?? 0
                    let signature = challengeData["signature"] as? String ?? ""

                    if challenge.isEmpty {
                        print("[GuestLLM] PoW挑战为空，可能不需要PoW")
                        completion(.failure(NSError(domain: "GuestLLM", code: -3, userInfo: nil)))
                        return
                    }

                    let result = PowChallengeResponse(
                        algorithm: algorithm,
                        challenge: challenge,
                        salt: salt,
                        difficulty: difficulty,
                        expireAt: expireAt,
                        signature: signature,
                        targetPath: "/api/v0/guest/chat/completion"
                    )

                    print("[GuestLLM] 获取PoW挑战成功: algorithm=\(algorithm), difficulty=\(difficulty), expireAt=\(expireAt)")
                    completion(.success(result))
                } else {
                    completion(.failure(NSError(domain: "GuestLLM", code: -4, userInfo: [NSLocalizedDescriptionKey: "JSON解析失败"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - PoW 求解

    /// 求解PoW挑战（SHA3-256暴力搜索nonce）
    /// DeepSeek的PoW算法: 找到answer使得 SHA3(salt + "_" + expire_at + "_" + answer) 的前difficulty位为0
    private static func solvePowChallenge(challenge: PowChallengeResponse) -> String? {
        print("[GuestLLM] 开始求解PoW: difficulty=\(challenge.difficulty)")

        let prefix = "\(challenge.salt)_\(challenge.expireAt)_"
        let difficulty = challenge.difficulty
        let targetPrefix = String(repeating: "0", count: difficulty) // 前导零数量

        // 难度上限保护：太高难度直接放弃
        let maxAttempts: Int
        switch difficulty {
        case 0...3: maxAttempts = 1_000_000
        case 4...5: maxAttempts = 10_000_000
        case 6: maxAttempts = 100_000_000
        default:
            print("[GuestLLM] PoW难度太高(\(difficulty))，放弃求解")
            return nil
        }

        var answer = 0
        while answer < maxAttempts {
            let input = prefix + String(answer)
            let hash = sha3_256_hex(input)

            if hash.hasPrefix(targetPrefix) {
                print("[GuestLLM] PoW求解成功! answer=\(answer), hash=\(hash.prefix(16))...")
                return String(answer)
            }

            answer += 1
        }

        print("[GuestLLM] PoW求解超时(\(maxAttempts)次尝试)")
        return nil
    }

    /// 构建PoW响应Header（Base64编码的JSON）
    private static func buildPowResponse(challenge: PowChallengeResponse, answer: String) -> String {
        let response: [String: Any] = [
            "algorithm": challenge.algorithm,
            "challenge": challenge.challenge,
            "salt": challenge.salt,
            "answer": answer,
            "signature": challenge.signature,
            "target_path": challenge.targetPath
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response)
            return jsonData.base64EncodedString()
        } catch {
            print("[GuestLLM] 构建PoW响应失败: \(error)")
            return ""
        }
    }

    // MARK: - Guest Chat 请求

    /// 发送访客聊天请求（SSE流式）
    private static func sendGuestChat(
        message: String,
        powHeader: String?,
        onToken: @escaping (String) -> Void,
        onStatus: ((String) -> Void)?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "https://chat.deepseek.com/api/v0/guest/chat/completion") else {
            completion(.failure(NSError(domain: "GuestLLM", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL格式错误"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("chat.deepseek.com", forHTTPHeaderField: "Host")
        request.setValue("https://chat.deepseek.com", forHTTPHeaderField: "Origin")
        request.setValue("https://chat.deepseek.com", forHTTPHeaderField: "Referer")
        request.setValue("StarCore/1.0", forHTTPHeaderField: "User-Agent")

        // 添加PoW响应Header
        if let pow = powHeader, !pow.isEmpty {
            request.setValue(pow, forHTTPHeaderField: "X-DS-Guest-PoW-Response")
            print("[GuestLLM] 已添加PoW响应Header")
        }

        // 附加已有Cookie
        if !sharedCookies.isEmpty {
            let cookieHeader = sharedCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }

        request.timeoutInterval = 120

        // 访客聊天请求格式
        let payload: [String: Any] = [
            "message": message,
            "stream": true
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        // 创建流式处理实例
        let guestLLM = GuestLLM()
        guestLLM.onToken = onToken
        guestLLM.onStatus = onStatus
        guestLLM.completion = completion

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180

        // 让URLSession自动处理Cookie
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always

        guestLLM.session = URLSession(configuration: config, delegate: guestLLM, delegateQueue: nil)

        let task = guestLLM.session?.dataTask(with: request)
        task?.resume()

        // 保持强引用
        objc_setAssociatedObject(task!, "guestLLM", guestLLM, .OBJC_ASSOCIATION_RETAIN)
    }

    // MARK: - URLSessionDataDelegate (GuestLLM)

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // 保存Cookie
        if let httpResponse = dataTask.response as? HTTPURLResponse {
            GuestLLM.saveCookies(from: httpResponse)
        }

        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text

        // 按行处理SSE数据
        let lines = buffer.components(separatedBy: "\n")
        if !text.hasSuffix("\n") {
            buffer = lines.last ?? ""
        } else {
            buffer = ""
        }

        let processLines = buffer.isEmpty ? lines : Array(lines.dropLast())

        for line in processLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data: ") else { continue }

            let jsonStr = String(trimmed.dropFirst(6))

            // SSE结束标记
            if jsonStr == "[DONE]" {
                finishWithAccumulated()
                return
            }

            // 解析SSE JSON
            guard let jsonData = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }

            // 检查错误
            if let error = json["error"] as? [String: Any] {
                let msg = error["message"] as? String ?? "访客模式错误"
                // 如果是PoW相关错误，给出友好提示
                if msg.contains("pow") || msg.contains("PoW") || msg.contains("challenge") {
                    let nsError = NSError(domain: "GuestLLM", code: -10, userInfo: [NSLocalizedDescriptionKey: "⚠️ 需要PoW验证，请稍后重试"])
                    completion?(.failure(nsError))
                } else if msg.contains("rate") || msg.contains("limit") || msg.contains("频繁") {
                    let nsError = NSError(domain: "GuestLLM", code: -11, userInfo: [NSLocalizedDescriptionKey: "⚠️ 访客模式频率限制，请稍后重试"])
                    completion?(.failure(nsError))
                } else {
                    let nsError = NSError(domain: "GuestLLM", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
                    completion?(.failure(nsError))
                }
                return
            }

            // 提取内容 - 兼容多种SSE格式
            // 格式1: OpenAI标准 choices[0].delta.content
            if let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let delta = firstChoice["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                accumulated += content
                onToken?(content)
                continue
            }

            // 格式2: DeepSeek格式 message/content 或 choices[0].message.content
            if let message = json["message"] as? String {
                accumulated += message
                onToken?(message)
                continue
            }

            // 格式3: content字段
            if let content = json["content"] as? String {
                accumulated += content
                onToken?(content)
                continue
            }

            // 格式4: choices[0].text
            if let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let text = firstChoice["text"] as? String {
                accumulated += text
                onToken?(text)
                continue
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let httpResponse = task.response as? HTTPURLResponse {
            GuestLLM.saveCookies(from: httpResponse)

            // 检查HTTP状态码
            if httpResponse.statusCode == 429 {
                let nsError = NSError(domain: "GuestLLM", code: -11, userInfo: [NSLocalizedDescriptionKey: "⚠️ 访客模式频率限制，请稍后重试"])
                completion?(.failure(nsError))
                session.invalidateAndCancel()
                return
            }
            if httpResponse.statusCode == 403 {
                // 可能需要PoW或者Cookie过期
                if accumulated.isEmpty {
                    let nsError = NSError(domain: "GuestLLM", code: -12, userInfo: [NSLocalizedDescriptionKey: "⚠️ 访客权限被拒，可能需要PoW验证"])
                    completion?(.failure(nsError))
                    session.invalidateAndCancel()
                    return
                }
            }
            if httpResponse.statusCode >= 400 && accumulated.isEmpty {
                let nsError = NSError(domain: "GuestLLM", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "⚠️ 访客模式HTTP错误(\(httpResponse.statusCode))"])
                completion?(.failure(nsError))
                session.invalidateAndCancel()
                return
            }
        }

        if let error = error {
            if !accumulated.isEmpty {
                completion?(.success(accumulated))
            } else {
                completion?(.failure(error))
            }
        } else {
            finishWithAccumulated()
        }

        session.invalidateAndCancel()
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }

    private func finishWithAccumulated() {
        if accumulated.isEmpty {
            let nsError = NSError(domain: "GuestLLM", code: -13, userInfo: [NSLocalizedDescriptionKey: "访客模式暂不可用，建议切换到DeepSeek免费API（platform.deepseek.com获取免费Key）"])
            completion?(.failure(nsError))
        } else {
            completion?(.success(accumulated))
        }
    }

    // MARK: - Cookie管理

    private static func saveCookies(from response: HTTPURLResponse) {
        if let allHeaderFields = response.allHeaderFields as? [String: String] {
            let url = response.url ?? URL(string: "https://chat.deepseek.com")!
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: allHeaderFields, for: url)
            if !cookies.isEmpty {
                // 合并Cookie：新的覆盖旧的
                var cookieDict: [String: HTTPCookie] = [:]
                for cookie in sharedCookies {
                    cookieDict[cookie.name] = cookie
                }
                for cookie in cookies {
                    cookieDict[cookie.name] = cookie
                }
                sharedCookies = Array(cookieDict.values)
                print("[GuestLLM] 保存了\(cookies.count)个Cookie，总计\(sharedCookies.count)个")
            }
        }
    }
}

// MARK: - SHA3-256 纯Swift实现（Keccak）
// DeepSeek PoW使用SHA3哈希，iOS CommonCrypto不直接提供SHA3，需自行实现

/// SHA3-256 哈希计算（返回十六进制字符串）
private func sha3_256_hex(_ input: String) -> String {
    let data = input.data(using: .utf8) ?? Data()
    let hashBytes = sha3_256(data)
    return hashBytes.map { String(format: "%02x", $0) }.joined()
}

/// SHA3-256 (Keccak-256 with SHA3 padding 0x06)
private func sha3_256(_ data: Data) -> [UInt8] {
    let rate = 136  // 200 - 2*32 = 136 bytes for SHA3-256
    let outputLen = 32

    // State: 5x5 array of 64-bit words = 25 words = 200 bytes
    var state = [UInt64](repeating: 0, count: 25)

    // Absorb phase: process full rate-sized blocks
    var offset = 0
    while offset + rate <= data.count {
        for i in 0..<rate {
            let wordIndex = i / 8
            let byteIndex = i % 8
            state[wordIndex] ^= UInt64(data[offset + i]) << (UInt64(byteIndex) * 8)
        }
        keccakF(&state)
        offset += rate
    }

    // Padding: SHA3 uses pad10*1 with domain separator 0x06
    // Create last block with remaining data + padding
    var lastBlock = [UInt8](repeating: 0, count: rate)
    let remaining = data.count - offset
    for i in 0..<remaining {
        lastBlock[i] = data[offset + i]
    }

    // SHA3 domain separator at position remaining
    lastBlock[remaining] ^= 0x06
    // High bit at position rate-1
    lastBlock[rate - 1] ^= 0x80

    // Absorb last block
    for i in 0..<rate {
        let wordIndex = i / 8
        let byteIndex = i % 8
        state[wordIndex] ^= UInt64(lastBlock[i]) << (UInt64(byteIndex) * 8)
    }
    keccakF(&state)

    // Squeeze phase (only one squeeze needed for SHA3-256)
    var output = [UInt8](repeating: 0, count: outputLen)
    for i in 0..<outputLen {
        let wordIndex = i / 8
        let byteIndex = i % 8
        output[i] = UInt8((state[wordIndex] >> (UInt64(byteIndex) * 8)) & 0xFF)
    }

    return output
}

/// Keccak-f[1600] permutation (24 rounds)
private func keccakF(_ state: inout [UInt64]) {
    let RC: [UInt64] = [
        0x0000000000000001, 0x0000000000008082, 0x800000000000808A,
        0x8000000080008000, 0x000000000000808B, 0x0000000080000001,
        0x8000000080008081, 0x8000000000008009, 0x000000000000008A,
        0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
        0x000000008000808B, 0x800000000000008B, 0x8000000000008089,
        0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
        0x000000000000800A, 0x800000008000000A, 0x8000000080008081,
        0x8000000000008080, 0x0000000080000001, 0x8000000080008008
    ]

    // Rotation offsets (for state[x + 5*y])
    let ROT: [[Int]] = [
        [0, 36, 3, 41, 18],
        [1, 44, 10, 45, 2],
        [62, 6, 43, 15, 61],
        [28, 55, 25, 21, 56],
        [27, 20, 39, 8, 14]
    ]

    for round in 0..<24 {
        // θ (theta)
        var C = [UInt64](repeating: 0, count: 5)
        for x in 0..<5 {
            C[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
        }
        var D = [UInt64](repeating: 0, count: 5)
        for x in 0..<5 {
            D[x] = C[(x + 4) % 5] ^ rotl64(C[(x + 1) % 5], 1)
        }
        for x in 0..<5 {
            for y in 0..<5 {
                state[x + 5 * y] ^= D[x]
            }
        }

        // ρ (rho) and π (pi)
        var B = [UInt64](repeating: 0, count: 25)
        for x in 0..<5 {
            for y in 0..<5 {
                let newX = y
                let newY = (2 * x + 3 * y) % 5
                B[newX + 5 * newY] = rotl64(state[x + 5 * y], ROT[x][y])
            }
        }

        // χ (chi)
        for y in 0..<5 {
            for x in 0..<5 {
                state[x + 5 * y] = B[x + 5 * y] ^ (~B[(x + 1) % 5 + 5 * y] & B[(x + 2) % 5 + 5 * y])
            }
        }

        // ι (iota)
        state[0] ^= RC[round]
    }
}

/// 64-bit left rotation
private func rotl64(_ x: UInt64, _ n: Int) -> UInt64 {
    let n = n % 64
    if n == 0 { return x }
    return (x << UInt64(n)) | (x >> UInt64(64 - n))
}
