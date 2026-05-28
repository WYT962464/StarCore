//
//  ChatView.swift
//  StarCore
//
//  Created by StarCore Team on 2026-05-29.
//  对话窗口 - 核心交互界面
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var threeSages: ThreeSagesFramework
    @EnvironmentObject var guaEngine: GuaEngine
    
    @State private var inputText = ""
    @State private var isSending = false
    @State private var showDecisionDetail = false
    @State private var selectedDecision: ThreeSagesDecision?
    
    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(spacing: 12) {
                        ForEach(chatManager.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                                .onTapGesture {
                                    if let decision = message.decision {
                                        selectedDecision = decision
                                        showDecisionDetail = true
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
            
            // 输入区域
            InputArea(
                text: $inputText,
                isSending: $isSending,
                onSend: sendMessage
            )
        }
        .sheet(isPresented: $showDecisionDetail) {
            if let decision = selectedDecision {
                DecisionDetailView(decision: decision)
            }
        }
        .onAppear {
            // 滚动到底部
            if let lastMessageId = chatManager.messages.last?.id {
                withAnimation {
                    ScrollViewReader { proxy in
                        proxy.scrollTo(lastMessageId, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard !isSending else { return }
        
        isSending = true
        let userMessage = inputText
        inputText = ""
        
        Task {
            // 1. 添加用户消息
            let userMsg = Message(role: .user, content: userMessage)
            await chatManager.addMessage(userMsg)
            
            // 2. 三位一体决策评估
            let context = DecisionContext(
                userInput: userMessage,
                currentGua: guaEngine.currentGua,
                systemState: await chatManager.getSystemState()
            )
            let decision = threeSages.decide(context: context, options: ["本地执行", "云电脑执行"])
            
            // 3. 根据决策选择执行路径
            let aiMessage: Message
            if decision.requiresCloud {
                // 云电脑模式
                aiMessage = await chatManager.callCloudServer(userMessage, decision: decision)
            } else {
                // 本地 LLM 调用
                aiMessage = await chatManager.callLocalLLM(userMessage, decision: decision)
            }
            
            // 4. 添加 AI 消息（包含决策信息）
            await chatManager.addMessage(aiMessage)
            
            isSending = false
        }
    }
}

// MARK: - 消息行
struct MessageRow: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 头像
            Image(systemName: message.role == .user ? "person.fill" : "cpu")
                .frame(width: 36, height: 36)
                .background(message.role == .user ? Color.blue : Color.green)
                .foregroundColor(.white)
                .clipShape(Circle())
            
            // 消息内容
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // 模型名称（AI 消息显示）
                if message.role == .assistant, let model = message.model {
                    Text(model)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 消息文本
                Text(message.content)
                    .font(.body)
                    .padding(12)
                    .background(message.role == .user ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                    .cornerRadius(12)
                
                // 决策信息（如果有）
                if let decision = message.decision {
                    DecisionBadge(decision: decision)
                }
                
                // 时间戳
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - 决策徽章
struct DecisionBadge: View {
    let decision: ThreeSagesDecision
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
            Text(decision.primarySage)
            Text("→")
            Text(decision.suggestion.prefix(20) + (decision.suggestion.count > 20 ? "..." : ""))
        }
        .font(.caption2)
        .padding(4)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(4)
        .foregroundColor(.purple)
    }
}

// MARK: - 决策详情
struct DecisionDetailView: View {
    let decision: ThreeSagesDecision
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("🧭 三位一体决策详情")
                        .font(.title2)
                        .bold()
                    
                    Divider()
                    
                    // 主要智者
                    Section {
                        HStack {
                            Text("主要智者")
                            Spacer()
                            Text(decision.primarySage)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                    }
                    
                    // 决策内容
                    Section {
                        Text(decision.decision)
                            .font(.body)
                    } header: {
                        Text("决策内容")
                    }
                    
                    // 评估详情
                    Section {
                        ForEach(decision.assessments, id: \.dimension) { assessment in
                            HStack {
                                Text(assessment.dimension)
                                Spacer()
                                ProgressView(value: assessment.score)
                                Text(String(format: "%.0f%%", assessment.score * 100))
                                    .font(.caption)
                            }
                        }
                    } header: {
                        Text("维度评估")
                    }
                    
                    // 建议卦象
                    Section {
                        HStack {
                            Text("建议卦象")
                            Spacer()
                            Text("第 \(decision.nextGua ?? 1) 卦")
                        }
                    }
                    
                    // 优先级
                    Section {
                        HStack {
                            Text("优先级")
                            Spacer()
                            Text(decision.priority.rawValue)
                                .fontWeight(.bold)
                        }
                    }
                    
                    // 理由
                    Section {
                        Text(decision.rationale)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("决策详情")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 输入区域
struct InputArea: View {
    @Binding var text: String
    @Binding var isSending: Bool
    var onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 语音按钮
            Button(action: {
                // TODO: 语音输入
            }) {
                Image(systemName: "mic")
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // 文本输入
            TextField("输入消息...", text: $text, axis: .vertical)
                .padding(12)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
            
            // 发送按钮
            Button(action: onSend) {
                Image(systemName: isSending ? "arrow.clockwise" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(isSending ? .gray : .blue)
            }
            .disabled(isSending || text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }
}

#Preview {
    ChatView()
        .environmentObject(ChatManager())
        .environmentObject(ThreeSagesFramework())
        .environmentObject(GuaEngine())
}
