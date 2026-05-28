//
//  FileView.swift
//  StarCore
//
//  Created by StarCore Team on 2026-05-29.
//  文件管理界面 - 本地 + 云电脑
//

import SwiftUI

struct FileView: View {
    @EnvironmentObject var fileManager: FileManager
    @EnvironmentObject var configManager: ConfigManager
    
    @State private var selectedFolder: FileFolder = .local
    @State private var showUploadSheet = false
    @State private var searchText = ""
    
    enum FileFolder: String, CaseIterable, Identifiable {
        case local = "📂 本地"
        case cloud = "☁️ 云电脑"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 文件夹切换
                FolderTabControl(selectedFolder: $selectedFolder)
                
                // 搜索栏
                SearchBar(text: $searchText)
                
                // 文件列表
                List {
                    Section(selectedFolder.rawValue) {
                        ForEach(filteredFiles) { file in
                            FileRow(file: file)
                        }
                        
                        if filteredFiles.isEmpty {
                            Text("暂无文件")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle("📁 文件管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showUploadSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedFolder == .cloud {
                        Button(action: {
                            if configManager.isCloudConnected {
                                configManager.disconnectCloud()
                            } else {
                                configManager.connectCloud()
                            }
                        }) {
                            Image(systemName: configManager.isCloudConnected ? "link" : "link.badge.plus")
                                .foregroundColor(configManager.isCloudConnected ? .green : .blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showUploadSheet) {
                UploadFileView(selectedFolder: selectedFolder)
            }
        }
    }
    
    private var filteredFiles: [FileInfo] {
        var files = selectedFolder == .local ? fileManager.localFiles : fileManager.cloudFiles
        
        if !searchText.isEmpty {
            files = files.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.path.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return files
    }
}

// MARK: - 文件夹标签
struct FolderTabControl: View {
    @Binding var selectedFolder: FileView.FileFolder
    
    var body: some View {
        HStack {
            ForEach(FileView.FileFolder.allCases) { folder in
                Button(action: { selectedFolder = folder }) {
                    Text(folder.rawValue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedFolder == folder ? Color.blue : Color.gray.opacity(0.1))
                        .foregroundColor(selectedFolder == folder ? .white : .primary)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
    }
}

// MARK: - 文件行
struct FileRow: View {
    let file: FileInfo
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: file.isDirectory ? "folder" : "doc")
                .font(.title2)
                .foregroundColor(file.isDirectory ? .blue : .gray)
            
            // 文件信息
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.headline)
                
                HStack {
                    if file.isDirectory {
                        Text("文件夹")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text(formatFileSize(file.size))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(file.timestamp, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 操作按钮
            Menu {
                Button(action: { openFile(file) }) {
                    Label("打开", systemImage: "arrow.up.right")
                }
                
                Button(action: { shareFile(file) }) {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                
                if !file.isDirectory {
                    Button(action: { downloadFile(file) }) {
                        Label("下载", systemImage: "arrow.down")
                    }
                }
                
                Button(role: .destructive, action: { deleteFile(file) }) {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func openFile(_ file: FileInfo) {
        // TODO: 打开文件
    }
    
    private func shareFile(_ file: FileInfo) {
        // TODO: 分享文件
    }
    
    private func downloadFile(_ file: FileInfo) {
        // TODO: 从云电脑下载
    }
    
    private func deleteFile(_ file: FileInfo) {
        // TODO: 删除文件
    }
}

// MARK: - 上传文件视图
struct UploadFileView: View {
    let selectedFolder: FileView.FileFolder
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var fileManager: FileManager
    
    @State private var selectedFile: URL?
    @State private var isUploading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("选择文件") {
                    Button(action: pickFile) {
                        HStack {
                            Image(systemName: "photo")
                            Text(selectedFile?.lastPathComponent ?? "选择文件...")
                            Spacer()
                        }
                    }
                }
                
                Section {
                    Button(isUploading ? "上传中..." : "上传到 \(selectedFolder == .local ? "本地" : "云电脑")") {
                        uploadFile()
                    }
                    .disabled(selectedFile == nil || isUploading)
                }
            }
            .navigationTitle("上传文件")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
    
    private func pickFile() {
        // TODO: 使用 UIDocumentPickerViewController
    }
    
    private func uploadFile() {
        isUploading = true
        // TODO: 实现上传逻辑
        // 本地：直接保存到文件系统
        // 云电脑：通过 SSH 反向隧道上传
    }
}

#Preview {
    FileView()
        .environmentObject(FileManager())
        .environmentObject(ConfigManager())
}
