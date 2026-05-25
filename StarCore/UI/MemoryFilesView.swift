/**
 * MemoryFilesView.swift
 * 记忆 & 文件管理页面
 * 
 * 功能：
 * - 记忆文件列表浏览
 * - 搜索记忆内容
 * - 文件详情查看
 */

import SwiftUI

struct MemoryFile: Identifiable {
    let id = UUID()
    let name: String
    let size: String
    let timestamp: String
    let type: FileType
    
    enum FileType {
        case md, plist, py, makefile, theos, folder, other
    }
}

@available(iOS 15.0, *)
struct MemoryFilesView: View {
    @State private var searchQuery = ""
    @State private var memoryFiles: [MemoryFile] = []
    @State private var selectedFile: MemoryFile?
    
    // 模拟记忆文件数据
    private let sampleFiles: [MemoryFile] = [
        MemoryFile(name: ".theos", size: "160B", timestamp: "05-20 14:47", type: .theos),
        MemoryFile(name: "MCP.md", size: "2KB", timestamp: "05-20 18:07", type: .md),
        MemoryFile(name: "MEMORY.md", size: "230B", timestamp: "05-21 01:58", type: .md),
        MemoryFile(name: "Makefile", size: "319B", timestamp: "05-20 14:36", type: .makefile),
        MemoryFile(name: "SECRET.md", size: "4KB", timestamp: "05-20 05:37", type: .md),
        MemoryFile(name: "SOUL.md", size: "5KB", timestamp: "05-20 05:33", type: .md),
        MemoryFile(name: "StarCore", size: "640B", timestamp: "05-08 04:06", type: .folder),
        MemoryFile(name: "StarCoreTweak.plist", size: "344B", timestamp: "05-20 04:23", type: .plist),
        MemoryFile(name: "StarCore_API.py", size: "357B", timestamp: "05-21 03:33", type: .py),
    ]
    
    var filteredFiles: [MemoryFile] {
        if searchQuery.isEmpty {
            return sampleFiles
        }
        return sampleFiles.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部通知条
                tweakConnectedBanner
                
                // 搜索栏
                searchBar
                
                // 文件列表
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(filteredFiles) { file in
                            memoryFileRow(file)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("记忆 & 文件")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - 顶部通知条
    private var tweakConnectedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Tweak 已连接 — 文件读写正常")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.green.opacity(0.3))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("搜索记忆文件内容...", text: $searchQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - 文件行
    private func memoryFileRow(_ file: MemoryFile) -> some View {
        HStack(spacing: 12) {
            // 文件图标
            fileIcon(for: file.type)
                .frame(width: 40, height: 40)
            
            // 文件信息
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text(file.size)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("•")
                        .foregroundColor(.gray)
                    Text(file.timestamp)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // 箭头
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 30/255, green: 30/255, blue: 63/255)))
        .padding(.horizontal)
        .onTapGesture {
            selectedFile = file
        }
    }
    
    // MARK: - 文件图标
    private func fileIcon(for type: MemoryFile.FileType) -> some View {
        let imageName: String
        let color: Color
        
        switch type {
        case .md:
            imageName = "doc.text"
            color = .blue
        case .plist:
            imageName = "list.bullet"
            color = .orange
        case .py:
            imageName = "swift"
            color = .yellow
        case .makefile:
            imageName = "gearshape"
            color = .gray
        case .theos:
            imageName = "terminal"
            color = .purple
        case .folder:
            imageName = "folder"
            color = .blue
        case .other:
            imageName = "doc"
            color = .gray
        }
        
        return Image(systemName: imageName)
            .foregroundColor(color)
    }
}

// MARK: - Preview
struct MemoryFilesView_Previews: PreviewProvider {
    static var previews: some View {
        MemoryFilesView()
    }
}
