//
//  SettingsView.swift
//  StarCore
//
//  Created by StarCore Team on 2026-05-29.
//  设置界面 - API 配置 + 系统设置
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var threeSages: ThreeSagesFramework
    @EnvironmentObject var guaEngine: GuaEngine
    
    @State private var showAddModelSheet = false
    @State private var showServerConfigSheet = false
    @State private var showModelConfigSheet = false
    @State private var showDecisionHistory = false
    @State private var showGuaHistory = false
    @State private var showFeedbackSheet = false
    @State private var showClearDataAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // 模型设置
                Section("🤖 LLM 模型") {
                    HStack {
                        Text("当前模型")
                        Spacer()
                        Text(configManager.currentModel.displayName)
                            .foregroundColor(.blue)
                    }
                    .onTapGesture {
                        showModelSelector = true
                    }
                    
                    Button("管理模型配置") {
                        showModelConfigSheet = true
                    }
                    
                    HStack {
                        Text("自定义模型")
                        Spacer()
                        Text("\(configManager.customModels.count) 个")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("添加新模型") {
                        showAddModelSheet = true
                    }
                }
                
                // 云电脑设置
                Section("☁️ 云电脑") {
                    HStack {
                        Text("服务器地址")
                        Spacer()
                        Text(configManager.serverIP)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        showServerConfigSheet = true
                    }
                    
                    HStack {
                        Text("SSH 隧道端口")
                        Spacer()
                        Text("\(configManager.sshPort)")
                    }
                    
                    HStack {
                        Text("连接状态")
                        Spacer()
                        if configManager.isCloudConnected {
                            Text("✅ 已连接")
                                .foregroundColor(.green)
                        } else {
                            Text("❌ 未连接")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button(configManager.isCloudConnected ? "断开连接" : "连接云电脑") {
                        if configManager.isCloudConnected {
                            configManager.disconnectCloud()
                        } else {
                            configManager.connectCloud()
                        }
                    }
                }
                
                // 三位一体设置
                Section("🧭 三位一体决策") {
                    HStack {
                        Text("当前焦点")
                        Spacer()
                        Text(threeSages.currentFocus)
                            .foregroundColor(.purple)
                    }
                    
                    HStack {
                        Text("决策记录")
                        Spacer()
                        Text("\(threeSages.decisionCount) 条")
                    }
                    
                    Button("查看决策历史") {
                        showDecisionHistory = true
                    }
                }
                
                // 六十四卦设置
                Section("🔮 六十四卦") {
                    HStack {
                        Text("当前卦象")
                        Spacer()
                        Text(guaEngine.currentGua.name)
                            .foregroundColor(.purple)
                    }
                    
                    HStack {
                        Text("演化周期")
                        Spacer()
                        Text("\(guaEngine.cycleCount) 次")
                    }
                    
                    Button("查看卦象历史") {
                        showGuaHistory = true
                    }
                }
                
                // 系统设置
                Section("⚙️ 系统") {
                    Toggle("自动连接云电脑", isOn: $configManager.autoConnectCloud)
                    
                    Toggle("启用三位一体决策", isOn: $configManager.enableThreeSages)
                    
                    Toggle("启用六十四卦自循环", isOn: $configManager.enableGuaCycle)
                    
                    HStack {
                        Text("自循环间隔")
                        Spacer()
                        Picker("", selection: $configManager.cycleInterval) {
                            Text("30 秒").tag(30)
                            Text("60 秒").tag(60)
                            Text("5 分钟").tag(300)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                // 关于
                Section("ℹ️ 关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                    }
                    
                    HStack {
                        Text("卦象")
                        Spacer()
                        Text("乾 ☰")
                    }
                    
                    Button("查看开源地址") {
                        openGitHub()
                    }
                    
                    Button("反馈问题") {
                        showFeedbackSheet = true
                    }
                }
                
                // 危险操作
                Section {
                    Button("清除所有数据", role: .destructive) {
                        showClearDataAlert = true
                    }
                }
            }
            .navigationTitle("⚙️ 设置")
            .sheet(isPresented: $showAddModelSheet) {
                AddModelView()
            }
            .sheet(isPresented: $showServerConfigSheet) {
                ServerConfigView()
            }
            .sheet(isPresented: $showModelConfigSheet) {
                ModelConfigListView()
            }
            .sheet(isPresented: $showDecisionHistory) {
                DecisionHistoryView()
            }
            .sheet(isPresented: $showGuaHistory) {
                GuaHistoryView()
            }
            .sheet(isPresented: $showFeedbackSheet) {
                FeedbackView()
            }
            .alert("确认清除所有数据", isPresented: $showClearDataAlert) {
                Button("取消", role: .cancel) {}
                Button("确认清除", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("此操作不可逆，将删除所有本地数据、记忆条目和配置。")
            }
        }
    }
    
    // 状态变量
    @State private var showModelSelector = false
    
    private func openGitHub() {
        // TODO: 打开 GitHub 仓库
    }
    
    private func clearAllData() {
        // TODO: 清除所有数据
        configManager.resetConfig()
        chatManager.clearMessages()
    }
}

// MARK: - 决策历史行
struct DecisionHistoryRow: View {
    let decision: ThreeSagesDecision
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(decision.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text(decision.context.userInput.prefix(50))
                .lineLimit(2)
            
            HStack(spacing: 8) {
                Text("诸葛亮: \(decision.assessments.first(where: { $0.dimension == "诸葛亮" })?.status ?? "")")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("伟人: \(decision.assessments.first(where: { $0.dimension == "伟人" })?.status ?? "")")
                    .font(.caption)
                    .foregroundColor(.red)
                Text("系统论: \(decision.assessments.first(where: { $0.dimension == "系统论" })?.status ?? "")")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Text("最终决策: \(decision.decision)")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 卦象历史行
struct GuaHistoryRow: View {
    let entry: GuaHistoryEntry
    
    var body: some View {
        HStack {
            Text(entry.newGua.name)
                .font(.headline)
                .foregroundColor(.purple)
            
            Text(entry.timestamp, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("从 \(entry.oldGua.name)")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - 添加模型视图
struct AddModelView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var configManager: ConfigManager
    
    @State private var modelName = ""
    @State private var apiKey = ""
    @State private var baseURL = ""
    @State private var modelType: ModelType = .openai
    
    enum ModelType: String, CaseIterable, Identifiable {
        case openai = "OpenAI 兼容"
        case anthropic = "Anthropic"
        case custom = "自定义"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("模型信息") {
                    TextField("模型名称", text: $modelName)
                        .autocapitalization(.none)
                    
                    Picker("模型类型", selection: $modelType) {
                        ForEach(ModelType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("API 配置") {
                    SecureField("API Key", text: $apiKey)
                    
                    TextField("Base URL", text: $baseURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                }
                
                Section {
                    Button("保存") {
                        saveModel()
                        dismiss()
                    }
                    .disabled(modelName.isEmpty || apiKey.isEmpty)
                }
                
                Section("ℹ️ 说明") {
                    Text("• OpenAI 兼容：适用于大多数 LLM API（包括 SenseNova、DeepSeek 等）")
                    Text("• Base URL 留空将使用默认端点")
                    Text("• API Key 将安全存储在本地")
                }
            }
            .navigationTitle("添加模型")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
    
    private func saveModel() {
        let newModel = CustomModelConfig(
            name: modelName,
            type: modelType.rawValue,
            apiKey: apiKey,
            baseURL: baseURL.isEmpty ? nil : baseURL
        )
        configManager.addCustomModel(newModel)
        print("✅ 已保存自定义模型: \(modelName)")
    }
}

// MARK: - 服务器配置视图
struct ServerConfigView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var configManager: ConfigManager
    
    @State private var serverIP = ""
    @State private var sshPort = 22
    @State private var username = ""
    @State private var useKeyAuth = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("服务器信息") {
                    TextField("服务器 IP", text: $serverIP)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    
                    TextField("用户名", text: $username)
                }
                
                Section("SSH 配置") {
                    HStack {
                        Text("端口")
                        Spacer()
                        TextField("端口", value: $sshPort, format: .number)
                            .frame(width: 80)
                    }
                    
                    Toggle("使用密钥认证", isOn: $useKeyAuth)
                    
                    if !useKeyAuth {
                        SecureField("密码", text: .constant(""))
                    }
                }
                
                Section {
                    Button("保存并连接") {
                        saveAndConnect()
                        dismiss()
                    }
                    .disabled(serverIP.isEmpty)
                }
            }
            .navigationTitle("云电脑配置")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
    
    private func saveAndConnect() {
        configManager.updateServerConfig(
            ip: serverIP,
            port: sshPort,
            username: username,
            useKeyAuth: useKeyAuth
        )
        configManager.connectCloud()
    }
}

// MARK: - 模型配置列表
struct ModelConfigListView: View {
    @EnvironmentObject var configManager: ConfigManager
    @Environment(\.dismiss) var dismiss
    
    @State private var editingModel: CustomModelConfig?
    @State private var showEditSheet = false
    
    var body: some View {
        NavigationView {
            List {
                // 内置模型
                Section("📦 内置模型") {
                    ForEach(LLMModel.allCases) { model in
                        ModelRow(
                            displayName: model.displayName,
                            isCurrent: model == configManager.currentModel,
                            isCustom: false,
                            onTap: { configManager.switchModel(model) }
                        )
                    }
                }
                
                // 自定义模型
                if !configManager.customModels.isEmpty {
                    Section("🔧 自定义模型") {
                        ForEach(configManager.customModels) { model in
                            ModelRow(
                                displayName: model.name,
                                isCurrent: configManager.currentModel.displayName == model.name,
                                isCustom: true,
                                onTap: {
                                    if let customModel = configManager.getCustomModel(byName: model.name) {
                                        // 切换到自定义模型需要特殊处理
                                        print("Switching to custom model: \(model.name)")
                                    }
                                },
                                onEdit: {
                                    editingModel = model
                                    showEditSheet = true
                                },
                                onDelete: {
                                    configManager.removeCustomModel(model)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("模型配置")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let model = editingModel {
                EditModelView(model: model, onSave: { updated in
                    configManager.addCustomModel(updated)
                })
            }
        }
    }
}

// MARK: - 模型行
struct ModelRow: View {
    let displayName: String
    let isCurrent: Bool
    let isCustom: Bool
    let onTap: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.body)
                if isCustom {
                    Text("自定义")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
            if isCustom, let onEdit = onEdit, let onDelete = onDelete {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.secondary)
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - 编辑模型视图
struct EditModelView: View {
    let model: CustomModelConfig
    let onSave: (CustomModelConfig) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var modelName: String
    @State private var apiKey: String
    @State private var baseURL: String
    
    init(model: CustomModelConfig, onSave: @escaping (CustomModelConfig) -> Void) {
        self.model = model
        self.onSave = onSave
        _modelName = State(initialValue: model.name)
        _apiKey = State(initialValue: model.apiKey)
        _baseURL = State(initialValue: model.baseURL ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("模型信息") {
                    TextField("模型名称", text: $modelName)
                }
                
                Section("API 配置") {
                    SecureField("API Key", text: $apiKey)
                    
                    TextField("Base URL", text: $baseURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
                
                Section {
                    Button("保存") {
                        let updated = CustomModelConfig(
                            name: modelName,
                            type: model.type,
                            apiKey: apiKey,
                            baseURL: baseURL.isEmpty ? nil : baseURL
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(modelName.isEmpty || apiKey.isEmpty)
                }
            }
            .navigationTitle("编辑模型")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 决策历史视图
struct DecisionHistoryView: View {
    @EnvironmentObject var threeSages: ThreeSagesFramework
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(threeSages.decisionHistory) { decision in
                    DecisionHistoryRow(decision: decision)
                }
            }
            .navigationTitle("决策历史")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 卦象历史视图
struct GuaHistoryView: View {
    @EnvironmentObject var guaEngine: GuaEngine
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(guaEngine.history) { entry in
                    GuaHistoryRow(entry: entry)
                }
            }
            .navigationTitle("卦象历史")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 反馈视图
struct FeedbackView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var feedbackText = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("反馈内容") {
                    TextEditor(text: $feedbackText)
                        .frame(height: 200)
                }
                
                Section {
                    Button("提交反馈") {
                        // TODO: 提交反馈
                    }
                }
            }
            .navigationTitle("反馈")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ConfigManager())
        .environmentObject(ChatManager())
        .environmentObject(ThreeSagesFramework())
        .environmentObject(GuaEngine())
}
