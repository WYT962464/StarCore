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
                let msg = error["message"] as? String ?? "未知错误"
                let nsError = NSError(domain: "StarCore", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
                completion?(.failure(nsError))
                return
            }

            // 提取delta content
            if let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let delta = firstChoice["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                accumulated += content
                onToken?(content)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
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
