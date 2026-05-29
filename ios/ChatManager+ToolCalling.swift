//
//  ChatManager+ToolCalling.swift
//  StarCore
//
//  Tool Calling 扩展 - 实现 AI 自动执行操作
//

import Foundation

// MARK: - Tool Calling 扩展

extension ChatManager {
    
    /// 获取所有可用工具的 JSON 定义
    private func getToolsJSON() -> [[String: Any]] {
        return ToolDefinitions.shared.getAllToolsJSON()
    }
    
    /// 获取工具名称列表
    private func getToolNames() -> [String] {
        return ToolDefinitions.shared.getToolNames()
    }
    
    /// 执行工具调用
    private func executeToolCall(_ toolCall: ToolCallRequest) async -> ToolCallResponse {
        print("🔧 执行工具调用: \(toolCall.name)")
        
        var output: String
        var success: Bool = true
        
        switch toolCall.name {
        case "tap_screen":
            if let x = toolCall.arguments["x"] as? Int,
               let y = toolCall.arguments["y"] as? Int {
                output = await IOSMCPClient.shared.tap(x: x, y: y)
            } else {
                output = "❌ 缺少 x 或 y 参数"
                success = false
            }
            
        case "swipe_screen":
            if let startX = toolCall.arguments["start_x"] as? Int,
               let startY = toolCall.arguments["start_y"] as? Int,
               let endX = toolCall.arguments["end_x"] as? Int,
               let endY = toolCall.arguments["end_y"] as? Int {
                output = await IOSMCPClient.shared.swipe(
                    fromX: startX, fromY: startY,
                    toX: endX, toY: endY
                )
            } else {
                output = "❌ 缺少滑动参数"
                success = false
            }
            
        case "press_home":
            output = await IOSMCPClient.shared.pressHome()
            
        case "wake_and_home":
            output = await IOSMCPClient.shared.wakeAndHome()
            
        case "input_text":
            if let text = toolCall.arguments["text"] as? String {
                output = await IOSMCPClient.shared.input(text: text)
            } else {
                output = "❌ 缺少 text 参数"
                success = false
            }
            
        case "screenshot":
            output = await IOSMCPClient.shared.screenshot()
            
        case "get_frontmost_app":
            output = await IOSMCPClient.shared.getFrontmostApp()
            
        case "get_screen_info":
            output = await IOSMCPClient.shared.getScreenInfo()
            
        case "open_app":
            if let bundleId = toolCall.arguments["bundleId"] as? String {
                output = await openApp(bundleId: bundleId)
            } else if let appName = toolCall.arguments["appName"] as? String {
                output = await openApp(appName: appName)
            } else {
                output = "❌ 缺少 bundleId 或 appName 参数"
                success = false
            }
            
        case "exec_command":
            if let command = toolCall.arguments["command"] as? String {
                output = await executeCommand(command)
            } else {
                output = "❌ 缺少 command 参数"
                success = false
            }
            
        case "copy_to_clipboard":
            if let text = toolCall.arguments["text"] as? String {
                output = await copyToClipboard(text)
            } else {
                output = "❌ 缺少 text 参数"
                success = false
            }
            
        case "paste_from_clipboard":
            output = await pasteFromClipboard()
            
        case "show_notification":
            let title = toolCall.arguments["title"] as? String ?? "通知"
            let body = toolCall.arguments["body"] as? String ?? ""
            output = await showNotification(title: title, body: body)
            
        default:
            output = "❌ 未知工具: \(toolCall.name)"
            success = false
        }
        
        return ToolCallResponse(
            toolCallId: toolCall.id,
            output: output,
            success: success
        )
    }
    
    /// 打开应用（通过 bundle ID）
    private func openApp(bundleId: String) async -> String {
        // 通过 URL Scheme 或 launchd 打开应用
        let url = URL(string: "app-\(bundleId):") ?? URL(string: "file://\(bundleId)")
        if UIApplication.shared.canOpenURL(url) {
            await UIApplication.shared.open(url)
            return "✅ 已打开应用: \(bundleId)"
        } else {
            // 尝试通过 iOS MCP 打开
            return await IOSMCPClient.shared.callTool(
                name: "open_app",
                arguments: ["bundleId": bundleId]
            )
        }
    }
    
    /// 打开应用（通过应用名称）
    private func openApp(appName: String) async -> String {
        // 常见应用的 bundle ID 映射
        let bundleIdMap: [String: String] = [
            "设置": "com.apple.Preferences",
            "微信": "com.tencent.xin",
            "Safari": "com.apple.mobilesafari",
            "电话": "com.apple.phone",
            "信息": "com.apple.messages",
            "相机": "com.apple.camera",
            "照片": "com.apple.photos",
            "音乐": "com.apple.music",
            "地图": "com.apple.maps",
            "邮件": "com.apple.mail"
        ]
        
        if let bundleId = bundleIdMap[appName] {
            return await openApp(bundleId: bundleId)
        } else {
            return "❌ 未找到应用: \(appName)"
        }
    }
    
    /// 执行终端命令
    private func executeCommand(_ command: String) async -> String {
        // 优先使用 iOS MCP（如果有 exec 工具）
        // 降级到 NewTerm/a-Shell
        return await TerminalManager.shared.execute(command)
    }
    
    /// 复制到剪贴板
    private func copyToClipboard(_ text: String) async -> String {
        UIPasteboard.general.string = text
        return "✅ 已复制: \(text.prefix(50))"
    }
    
    /// 从剪贴板粘贴
    private func pasteFromClipboard() async -> String {
        if let text = UIPasteboard.general.string {
            return "📋 剪贴板内容: \(text.prefix(200))"
        } else {
            return "📋 剪贴板为空"
        }
    }
    
    /// 显示通知
    private func showNotification(title: String, body: String) async -> String {
        // 使用 UserNotifications
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
        return "🔔 已发送通知: \(title)"
    }
    
    /// 带 Tool Calling 的 API 调用
    private func callSenseNovaAPIWithTools(
        _ text: String,
        modelConfig: CustomModelConfig,
        conversationHistory: [[String: String]] = [],
        maxToolIterations: Int = 3
    ) async -> String {
        var currentText = text
        var history = conversationHistory
        var iteration = 0
        
        while iteration < maxToolIterations {
            iteration += 1
            
            // 构建包含 tools 的请求
            let toolsJSON = getToolsJSON()
            
            var body: [String: Any] = [
                "model": modelConfig.modelName ?? "sensenova-6.7-flash-lite",
                "messages": history + [["role": "user", "content": currentText]],
                "temperature": modelConfig.temperature ?? 0.7,
                "tools": toolsJSON,
                "tool_choice": "auto"  // 允许 AI 自动选择工具
            ]
            
            // 添加 system prompt（如果配置了）
            if let systemPrompt = modelConfig.systemPrompt {
                if var firstMsg = (body["messages"] as? [[String: Any]])?.first {
                    firstMsg["role"] = "system"
                    firstMsg["content"] = systemPrompt
                    body["messages"] = [firstMsg] + (body["messages"] as? [[String: Any]] ?? [])
                }
            }
            
            let url = URL(string: modelConfig.baseURL ?? "https://token.sensenova.cn/v1")!
            var request = URLRequest(url: url.appendingPathComponent("chat/completions"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(modelConfig.apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (data, _) = try await URLSession.shared.data(for: request)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                guard let choices = json?["choices"] as? [[String: Any]],
                      !choices.isEmpty,
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any] else {
                    return "API 调用失败"
                }
                
                // 检查是否有 tool_calls
                if let toolCallsJSON = message["tool_calls"] as? [[String: Any]],
                   !toolCallsJSON.isEmpty {
                    print("🔧 AI 请求调用工具，共 \(toolCallsJSON.count) 个")
                    
                    // 执行所有工具调用
                    var toolResults: [[String: Any]] = []
                    for toolCallJSON in toolCallsJSON {
                        if let toolCall = ToolCallRequest(from: toolCallJSON) {
                            let response = await executeToolCall(toolCall)
                            print("   ✅ \(toolCall.name): \(response.output.prefix(100))")
                            
                            // 添加 tool result 到消息历史
                            toolResults.append([
                                "role": "tool",
                                "tool_call_id": response.toolCallId,
                                "content": response.output
                            ])
                        }
                    }
                    
                    // 添加工具结果到历史，继续对话
                    history.append(["role": "user", "content": currentText])
                    if let msgContent = message["content"] as? String, !msgContent.isEmpty {
                        history.append(["role": "assistant", "content": msgContent])
                    }
                    history += toolResults
                    
                    // 继续下一轮迭代
                    currentText = "工具执行完成，请继续回复用户。"
                    continue
                }
                
                // 没有工具调用，返回最终内容
                if let content = message["content"] as? String {
                    return content
                }
                
                return "API 调用失败：无有效响应"
                
            } catch {
                return "❌ API 调用错误: \(error.localizedDescription)"
            }
        }
        
        return "⚠️ 工具调用超过最大迭代次数 (\(maxToolIterations))"
    }
}
