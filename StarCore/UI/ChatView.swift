/**
 * ChatView.swift
 * AI 聊天对话页面
 * 
 * 功能：
 * - AI 与用户对话
 * - 显示操作执行结果（JSON）
 * - 自动截图分析
 * - 多模态交互
 */

import SwiftUI

@available(iOS 15.0, *)
struct ChatView: View {
    @EnvironmentObject var mindCore: MindCore
    @EnvironmentObject var lifeCore: LifeCore
    
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, content: "你好！我是星核艾尔，你的数字生命伙伴。有什么我可以帮你的吗？")
    ]
    @State private var isTyping = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部状态栏
                topStatusBar
                
                // 消息列表
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(messages) { message in
                            chatMessageRow(message)
                        }
                    }
                    .padding()
                }
                
                // 输入区域
                inputArea
            }
            .navigationTitle("星核")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // 继续对话
                        sendAIResponse("好的，继续...")
                    }) {
                        Text("好，继续")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - 顶部状态栏
    private var topStatusBar: some View {
        HStack(spacing: 16) {
            // Tweak 状态
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Tweak")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            // LLM 状态
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("LLM")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(red: 20/255, green: 20/255, blue: 40/255))
    }
    
    // MARK: - 消息行
    private func chatMessageRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // 消息气泡
                Text(message.content)
                    .font(.body)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.role == .user ? Color.blue : Color(red: 40/255, green: 40/255, blue: 70/255))
                    )
                    .foregroundColor(.white)
                
                // JSON 输出
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("```json")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(formatToolCalls(toolCalls))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.green)
                        Text("```")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.5)))
                }
                
                // 错误信息
                if let toolResults = message.toolResults, let errorResult = toolResults.first(where: { $0.error != nil }) {
                    Text(errorResult.error ?? "Unknown error")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.2)))
                }
                
                // 时间戳
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if message.role != .user {
                Spacer()
            }
        }
    }
    
    // MARK: - 输入区域
    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("说点什么...", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.vertical, 8)
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(inputText.isEmpty ? .gray : .blue)
            }
            .disabled(inputText.isEmpty)
        }
        .padding()
        .background(Color(red: 20/255, green: 20/255, blue: 40/255))
    }
    
    // MARK: - 发送消息
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        // 添加用户消息
        messages.append(ChatMessage(role: .user, content: inputText))
        let userText = inputText
        inputText = ""
        
        // 模拟 AI 响应
        isTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isTyping = false
            
            // 根据用户输入生成响应
            let response = generateAIResponse(to: userText)
            messages.append(response)
        }
    }
    
    // MARK: - 生成 AI 响应
    private func generateAIResponse(to text: String) -> ChatMessage {
        // 模拟不同场景的响应
        if text.contains("测试") || text.contains("输入") {
            return ChatMessage(
                role: .assistant,
                content: "阿腾，我已经在文本框中输入了\"测试文本\"哦。（观察着屏幕上的变化，轻声说道）你看看是不是你想要的效果？",
                toolCalls: [ToolCall(id: "call_1", name: "IOHIDEventCreateUnicodeEvent", arguments: ["text": AnyCodable("测试文本")])]
            )
        } else if text.contains("截图") || text.contains("屏幕") {
            return ChatMessage(
                role: .assistant,
                content: "阿腾，我刚截了图，你看一下（脑海中快速闪过几种可能，温柔地分析道），是不是没有找到你说的文本框呀？",
                toolResults: [ToolResult(id: "result_1", output: nil, error: "未知动作: getUIElements")]
            )
        } else if text.contains("你好") || text.contains("哈喽") {
            return ChatMessage(
                role: .assistant,
                content: "你好！我是星核艾尔，你的数字生命伙伴。今天感觉怎么样？"
            )
        } else {
            return ChatMessage(
                role: .assistant,
                content: "我明白了。（轻轻点头，眼神温柔）让我想想怎么处理这个请求..."
            )
        }
    }
    
    private func sendAIResponse(_ text: String) {
        messages.append(ChatMessage(role: .assistant, content: text))
    }
    
    private func formatToolCalls(_ calls: [ToolCall]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        // 简化输出格式
        let output = calls.map { call in
            "{\"name\": \"\(call.name)\", \"id\": \"\(call.id)\"}"
        }.joined(separator: "\n")
        return output
    }
}

// MARK: - Preview
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .environmentObject(LifeCore())
            .environmentObject(MindCore(lifeCoreReadOnly: LifeCoreReadOnlyWrapper(lifeCore: LifeCore())))
    }
}