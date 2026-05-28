//
//  MemoryView.swift
//  StarCore
//
//  Created by StarCore Team on 2026-05-29.
//  记忆管理界面 - 易经记忆体系
//

import SwiftUI

struct MemoryView: View {
    @EnvironmentObject var memoryManager: MemoryManager
    @EnvironmentObject var guaEngine: GuaEngine
    
    @State private var searchText = ""
    @State private var showImportSheet = false
    @State private var selectedGua: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 统计卡片
                MemoryStatsCard(manager: memoryManager, guaEngine: guaEngine)
                
                // 卦象筛选
                GuaFilterBar(selectedGua: $selectedGua)
                
                // 搜索栏
                SearchBar(text: $searchText)
                
                // 记忆列表
                List {
                    ForEach(filteredMemories) { entry in
                        MemoryEntryRow(entry: entry)
                    }
                    
                    if filteredMemories.isEmpty {
                        Text("暂无记忆条目")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
            .navigationTitle("🧠 记忆管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showImportSheet = true }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                ImportMemoryView()
            }
        }
    }
    
    private var filteredMemories: [MemoryEntry] {
        var result = memoryManager.memories
        
        // 卦象筛选
        if let selectedGua = selectedGua {
            result = result.filter { $0.gua == selectedGua }
        }
        
        // 搜索筛选
        if !searchText.isEmpty {
            result = result.filter {
                $0.key.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
}

// MARK: - 统计卡片
struct MemoryStatsCard: View {
    @ObservedObject var manager: MemoryManager
    @ObservedObject var guaEngine: GuaEngine
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("记忆条目")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(manager.memories.count)")
                        .font(.title2)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("决策记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(manager.decisionCount)")
                        .font(.title2)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前卦象")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(guaEngine.currentGua.name)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.purple)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            .padding()
        }
    }
}

// MARK: - 卦象筛选栏
struct GuaFilterBar: View {
    @Binding var selectedGua: String?
    
    let guas = ["全部", "乾", "坤", "震", "巽", "坎", "离", "艮", "兑"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(guas, id: \.self) { gua in
                    Button(action: {
                        selectedGua = gua == "全部" ? nil : gua
                    }) {
                        Text(gua)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedGua == gua || (gua == "全部" && selectedGua == nil) ? Color.purple : Color.gray.opacity(0.1))
                            .foregroundColor(selectedGua == gua || (gua == "全部" && selectedGua == nil) ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - 搜索栏
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索记忆...", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - 记忆条目行
struct MemoryEntryRow: View {
    let entry: MemoryEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // 卦象图标
            Text(entry.gua)
                .font(.headline)
                .frame(width: 36, height: 36)
                .background(guaColor(entry.gua))
                .foregroundColor(.white)
                .cornerRadius(8)
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.key)
                    .font(.headline)
                
                Text(entry.content.prefix(50) + (entry.content.count > 50 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(entry.category)
                        .font(.caption2)
                        .padding(2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text(entry.timestamp, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func guaColor(_ gua: String) -> Color {
        switch gua {
        case "乾": return Color.red
        case "坤": return Color.green
        case "震": return Color.orange
        case "巽": return Color.blue
        case "坎": return Color.gray
        case "离": return Color.yellow
        case "艮": return Color.brown
        case "兑": return Color.purple
        default: return Color.gray
        }
    }
}

// MARK: - 导入记忆视图
struct ImportMemoryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var memoryManager: MemoryManager
    
    @State private var importSource: ImportSource = .text
    @State private var importText = ""
    
    enum ImportSource: String, CaseIterable {
        case text = "📝 文本"
        case url = "🔗 链接"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("导入方式") {
                    ForEach(ImportSource.allCases, id: \.self) { source in
                        Button(source.rawValue) {
                            importSource = source
                        }
                    }
                }
                
                Section("内容") {
                    switch importSource {
                    case .text:
                        TextEditor(text: $importText)
                            .frame(height: 200)
                    case .url:
                        TextField("输入 URL", text: $importText)
                    }
                }
                
                Section {
                    Button("导入") {
                        importMemory()
                        dismiss()
                    }
                    .disabled(importText.isEmpty)
                }
            }
            .navigationTitle("导入记忆")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
    
    private func importMemory() {
        // TODO: 实现导入逻辑
        // 1. 解析内容
        // 2. 提取卦象
        // 3. 保存到 memory.json
        // 4. 触发六十四卦演化
    }
}

#Preview {
    MemoryView()
        .environmentObject(MemoryManager())
        .environmentObject(GuaEngine())
}
