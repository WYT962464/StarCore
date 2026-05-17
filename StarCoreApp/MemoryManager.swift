import UIKit
import Foundation

// MARK: - Memory Manager
class MemoryManager {

    static let shared = MemoryManager()

    private let fileManager = FileManager.default
    private let defaults = UserDefaults.standard

    /// 调试日志回调
    var onDebugLog: ((String) -> Void)?

    private var memoryPath: String {
        return defaults.string(forKey: "memoryPath") ?? "/var/mobile/StarCore"
    }

    private init() {}

    // MARK: - Memory File Definitions

    private struct MemoryFile {
        let name: String
        let subdirectory: String?
        let displayName: String

        func fullPath(relativeTo root: String) -> String {
            if let sub = subdirectory {
                let withSub = (root as NSString).appendingPathComponent(sub)
                return (withSub as NSString).appendingPathComponent(name)
            } else {
                return (root as NSString).appendingPathComponent(name)
            }
        }
    }

    private let memoryFiles: [MemoryFile] = [
        MemoryFile(name: "SOUL.md",       subdirectory: "基础设定", displayName: "SOUL.md"),
        MemoryFile(name: "USER.md",       subdirectory: nil,       displayName: "USER.md"),
        MemoryFile(name: "MEMORY.md",     subdirectory: nil,       displayName: "MEMORY.md"),
        MemoryFile(name: "TOOLS.md",      subdirectory: "基础设定", displayName: "TOOLS.md"),
        MemoryFile(name: "SECRET.md",     subdirectory: nil,       displayName: "SECRET.md"),
        MemoryFile(name: "EMAIL_RULES.md",subdirectory: nil,       displayName: "EMAIL_RULES.md"),
    ]

    // MARK: - Debug Log

    private func debugLog(_ msg: String) {
        print("[Memory] \(msg)")
        onDebugLog?(msg)
    }

    // MARK: - Shell Command (Tweak优先，iOS MCP备选)

    @discardableResult
    private func tweakShell(_ cmd: String, timeout: TimeInterval = 5) -> String? {
        debugLog("shell: \(cmd.prefix(80))")
        if let result = StarCoreAgent.shared.tweakCmd(action: "shell", params: ["command": cmd], timeout: timeout),
           let output = result["output"] as? String, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return output
        }
        return nil
    }

    /// 通过iOS MCP执行shell命令（备选方案，当Tweak不可用时）
    /// iOS MCP工具: run_command, 参数: command
    @discardableResult
    private func mcpShell(_ cmd: String) -> String? {
        debugLog("mcp-shell: \(cmd.prefix(80))")
        // iOS MCP的正确工具名是 run_command
        if let result = StarCoreAgent.shared.callMcpToolSync(name: "run_command", arguments: ["command": cmd]) {
            // 解析MCP返回格式: {"result": {"content": [{"type": "text", "text": "..."}]}}
            if let rpcResult = result["result"] as? [String: Any],
               let content = rpcResult["content"] as? [[String: Any]],
               let first = content.first,
               let text = first["text"] as? String, !text.isEmpty {
                return text
            }
            // 也尝试直接取output
            if let output = result["output"] as? String, !output.isEmpty {
                return output
            }
            // 也尝试直接取content
            if let content = result["content"] as? [[String: Any]],
               let first = content.first,
               let text = first["text"] as? String, !text.isEmpty {
                return text
            }
            debugLog("mcp-shell: unexpected format: \(String(describing: result).prefix(200))")
        }
        return nil
    }

    /// 智能shell：Tweak优先，失败走iOS MCP
    @discardableResult
    private func smartShell(_ cmd: String, timeout: TimeInterval = 5) -> String? {
        // 先试Tweak
        if let result = tweakShell(cmd, timeout: timeout) {
            return result
        }
        // Tweak失败，走iOS MCP
        debugLog("Tweak failed, trying iOS MCP...")
        return mcpShell(cmd)
    }

    // MARK: - Load Memory Content

    func loadSOULContent() -> String {
        let path = (memoryPath as NSString).appendingPathComponent("基础设定/SOUL.md")
        return readFile(at: path, maxChars: 2000)
    }

    func loadUserContent() -> String {
        let path = (memoryPath as NSString).appendingPathComponent("USER.md")
        return readFile(at: path, maxChars: 2000)
    }

    func loadMemoryContent() -> String {
        let path = (memoryPath as NSString).appendingPathComponent("MEMORY.md")
        return readFile(at: path, maxChars: 3000)
    }

    func loadToolsContent() -> String {
        let path = (memoryPath as NSString).appendingPathComponent("基础设定/TOOLS.md")
        return readFile(at: path, maxChars: 2000)
    }

    // MARK: - Build System Prompt

    func buildSystemPrompt(basePrompt: String) -> String {
        var parts = [basePrompt]
        let soul = loadSOULContent(); if !soul.isEmpty { parts.append("\n\n【灵魂】\n" + soul) }
        let user = loadUserContent(); if !user.isEmpty { parts.append("\n\n【阿腾】\n" + user) }
        let memory = loadMemoryContent(); if !memory.isEmpty { parts.append("\n\n【当前状态】\n" + memory) }
        let tools = loadToolsContent(); if !tools.isEmpty { parts.append("\n\n【经验】\n" + tools) }
        return parts.joined(separator: "")
    }

    // MARK: - Get Memory Path

    func getMemoryPath() -> String { return memoryPath }

    func updateMemoryPath(_ newPath: String) {
        defaults.set(newPath, forKey: "memoryPath")
    }

    // MARK: - Check Memory Directory

    func memoryDirectoryExists() -> Bool {
        if fileManager.fileExists(atPath: memoryPath) { return true }
        if let output = smartShell("test -d \(shellEscape(memoryPath)) && echo YES") {
            return output.contains("YES")
        }
        return false
    }

    // MARK: - List Memory Files (记忆区tab)
    // 显示根目录md文件 + 基础设定/子目录下的md文件

    func listMemoryFiles() -> [MemoryFileInfo] {
        var results: [MemoryFileInfo] = []
        
        // 1. 根目录文件（只显示md）
        let rootItems = listFiles(at: memoryPath)
        for item in rootItems {
            if item.isDirectory || item.name.hasSuffix(".md") {
                results.append(item)
            }
        }
        
        // 2. 基础设定/子目录文件
        let subDir = (memoryPath as NSString).appendingPathComponent("基础设定")
        let subItems = listFiles(at: subDir)
        for item in subItems {
            if item.isDirectory || item.name.hasSuffix(".md") {
                // 标记为子目录文件，显示时加前缀
                var prefixed = item
                prefixed = MemoryFileInfo(
                    name: "基础设定/\(item.name)",
                    path: item.path,
                    isDirectory: item.isDirectory,
                    size: item.size,
                    modDate: item.modDate
                )
                results.append(prefixed)
            }
        }
        
        debugLog("listMemoryFiles: \(results.count) items")
        return results
    }

    // MARK: - List Files (文件浏览器tab)

    func listFiles(at directoryPath: String) -> [MemoryFileInfo] {
        var results: [MemoryFileInfo] = []

        // Try FileManager first (sandbox accessible paths)
        if let contents = try? fileManager.contentsOfDirectory(atPath: directoryPath) {
            for name in contents.sorted() {
                let fullPath = (directoryPath as NSString).appendingPathComponent(name)
                if let info = getFileInfo(at: fullPath) {
                    results.append(info)
                }
            }
            debugLog("FileManager: \(results.count) items in \(directoryPath)")
            return results
        }

        // ★ Fallback: 用 find 命令获取目录内容（比ls -la更可靠，不怕中文/特殊字符）
        let escapedPath = shellEscape(directoryPath)
        // find 输出: 每行一个完整路径
        // 同时获取文件类型和大小
        let cmd = "find \(escapedPath) -maxdepth 1 -exec stat -f '%z %Sp %N' {} \\; 2>/dev/null | tail -n +2"
        if let output = smartShell(cmd) {
            let lines = output.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            for line in lines {
                if let info = parseStatLine(line) {
                    results.append(info)
                }
            }
            debugLog("find+stat: \(results.count) items in \(directoryPath)")
        }

        // 如果find也失败，试最简单的ls
        if results.isEmpty {
            if let output = smartShell("ls -1A \(escapedPath) 2>/dev/null") {
                let names = output.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && $0 != "." && $0 != ".." }
                for name in names {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    let fullPath = (directoryPath as NSString).appendingPathComponent(trimmed)
                    let isDir = smartShell("test -d \(shellEscape(fullPath)) && echo DIR")?.contains("DIR") ?? false
                    results.append(MemoryFileInfo(name: trimmed, path: fullPath, isDirectory: isDir, size: 0, modDate: nil))
                }
                debugLog("ls -1A fallback: \(results.count) items")
            }
        }

        // Sort: directories first, then alphabetically
        results.sort { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        return results
    }

    /// 解析 stat -f '%z %Sp %N' 的输出
    /// 格式: 4096 drwxr-xr-x /var/mobile/StarCore/基础设定
    private func parseStatLine(_ line: String) -> MemoryFileInfo? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        
        // 格式: size perms path
        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard parts.count >= 3 else { return nil }
        
        let size = Int64(parts[0]) ?? 0
        let perms = parts[1]
        let isDir = perms.hasPrefix("d")
        // 路径可能包含空格，从第2个字段开始拼
        let pathStr = parts[2...].joined(separator: " ")
        
        let name = (pathStr as NSString).lastPathComponent
        guard name != "." && name != ".." else { return nil }
        
        return MemoryFileInfo(name: name, path: pathStr, isDirectory: isDir, size: size, modDate: nil)
    }



    // MARK: - Get File Info

    private func getFileInfo(at path: String) -> MemoryFileInfo? {
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path, isDirectory: &isDir)

        if exists {
            let name = (path as NSString).lastPathComponent
            var size: Int64 = 0
            var modDate: Date? = nil
            if let attrs = try? fileManager.attributesOfItem(atPath: path) {
                size = (attrs[.size] as? Int64) ?? 0
                modDate = attrs[.modificationDate] as? Date
            }
            return MemoryFileInfo(name: name, path: path, isDirectory: isDir.boolValue, size: size, modDate: modDate)
        }

        // Fallback: Tweak shell - 单次 test + stat
        let escaped = shellEscape(path)
        if let output = smartShell("test -e \(escaped) && stat -f '%z' \(escaped) 2>/dev/null && echo EXISTS") {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasSuffix("EXISTS") {
                let name = (path as NSString).lastPathComponent
                let sizeStr = trimmed.replacingOccurrences(of: "EXISTS", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let size = Int64(sizeStr) ?? 0
                let isDir = smartShell("test -d \(escaped) && echo DIR")?.contains("DIR") ?? false
                return MemoryFileInfo(name: name, path: path, isDirectory: isDir, size: size, modDate: nil)
            }
        }

        return nil
    }

    // MARK: - Memory Files Info

    func memoryFilesInfo() -> [(name: String, exists: Bool, size: Int)] {
        return memoryFiles.map { file in
            let path = file.fullPath(relativeTo: memoryPath)
            var exists = fileManager.fileExists(atPath: path)
            var size = 0
            if exists {
                size = readFile(at: path).count
            } else {
                let escaped = shellEscape(path)
                if let result = smartShell("stat -f%z \(escaped) 2>/dev/null"),
                   let fileSize = Int(result.trimmingCharacters(in: .whitespacesAndNewlines)), fileSize > 0 {
                    exists = true
                    size = fileSize
                }
            }
            return (file.displayName, exists, size)
        }
    }

    // MARK: - Read File Content

    func readFileContent(at path: String) -> String {
        return readFile(at: path, maxChars: 0)
    }

    private func readFile(at path: String, maxChars: Int = 0) -> String {
        // Try FileManager first
        if fileManager.fileExists(atPath: path),
           let data = fileManager.contents(atPath: path),
           let content = String(data: data, encoding: .utf8) {
            return maxChars > 0 ? truncate(content, maxChars: maxChars) : content
        }

        // Fallback: Tweak shell cat
        let escaped = shellEscape(path)
        if let content = smartShell("cat \(escaped) 2>/dev/null", timeout: 8) {
            return maxChars > 0 ? truncate(content, maxChars: maxChars) : content
        }

        return ""
    }

    // MARK: - Write File Content (via Tweak shell, base64 encoding)

    func writeFile(content: String, to path: String) -> Bool {
        let escaped = shellEscape(path)

        // 方案1: 小文件直接echo
        if content.count < 1000 && !content.contains("'") {
            let escapedContent = content.replacingOccurrences(of: "'", with: "'\\\"'\\\"'")
            if let result = tweakShell("echo '\(escapedContent)' > \(escaped) 2>/dev/null && echo WRITE_OK") {
                return result.contains("WRITE_OK")
            }
        }

        // 方案2: 大文件走base64
        guard let data = content.data(using: .utf8) else { return false }
        let base64 = data.base64EncodedString()

        let tmpBase64 = "/tmp/starcore_write.b64"

        // 清空临时文件
        _ = smartShell("echo -n '' > \(shellEscape(tmpBase64))")

        // 分块写入（每块4000字符避免shell命令行过长）
        let chunkSize = 4000
        var offset = base64.startIndex
        while offset < base64.endIndex {
            let end = base64.index(offset, offsetBy: chunkSize, limitedBy: base64.endIndex) ?? base64.endIndex
            let chunk = String(base64[offset..<end])
            let escapedChunk = chunk.replacingOccurrences(of: "'", with: "'\\\"'\\\"'")
            _ = smartShell("printf '%s' '\(escapedChunk)' >> \(shellEscape(tmpBase64))")
            offset = end
        }

        // base64解码到目标文件
        if let result = smartShell("base64 -d < \(shellEscape(tmpBase64)) > \(escaped) 2>/dev/null && echo WRITE_OK || echo WRITE_FAIL") {
            _ = smartShell("rm -f \(shellEscape(tmpBase64))")
            return result.contains("WRITE_OK")
        }

        _ = smartShell("rm -f \(shellEscape(tmpBase64))")
        return false
    }

    // MARK: - Save Screenshot

    @discardableResult
    func saveScreenshot(data: Data) -> String? {
        let screenshotsDir = (memoryPath as NSString).appendingPathComponent("screenshots")
        if !fileManager.fileExists(atPath: screenshotsDir) {
            try? fileManager.createDirectory(atPath: screenshotsDir, withIntermediateDirectories: true)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "screenshot_\(formatter.string(from: Date())).png"
        let filePath = (screenshotsDir as NSString).appendingPathComponent(filename)

        if fileManager.createFile(atPath: filePath, contents: data) {
            return filePath
        }

        // Fallback: Tweak shell
        let base64Str = data.base64EncodedString()
        let tmpPath = "/tmp/starcore_screenshot.png"

        // Write base64 chunks
        let tmpB64 = "/tmp/starcore_scr.b64"
        _ = smartShell("echo -n '' > \(shellEscape(tmpB64))")
        let chunkSize = 4000
        var offset = base64Str.startIndex
        while offset < base64Str.endIndex {
            let end = base64Str.index(offset, offsetBy: chunkSize, limitedBy: base64Str.endIndex) ?? base64Str.endIndex
            let chunk = String(base64Str[offset..<end])
            let escapedChunk = chunk.replacingOccurrences(of: "'", with: "'\\\"'\\\"'")
            _ = smartShell("printf '%s' '\(escapedChunk)' >> \(shellEscape(tmpB64))")
            offset = end
        }

        if let result = smartShell("base64 -d < \(shellEscape(tmpB64)) > \(shellEscape(filePath)) 2>/dev/null && echo OK"),
           result.contains("OK") {
            _ = smartShell("rm -f \(shellEscape(tmpB64))")
            return filePath
        }

        _ = smartShell("rm -f \(shellEscape(tmpB64))")
        return nil
    }

    // MARK: - Save Uploaded Image

    func saveUploadedImage(image: UIImage, to directoryPath: String) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "upload_\(formatter.string(from: Date())).jpg"
        let filePath = (directoryPath as NSString).appendingPathComponent(filename)

        if fileManager.createFile(atPath: filePath, contents: data) {
            return filePath
        }
        return nil
    }

    // MARK: - Search Memory Files

    func searchMemoryFiles(query: String) -> [(fileName: String, lineNumber: Int, line: String)] {
        var results: [(fileName: String, lineNumber: Int, line: String)] = []
        let lowercaseQuery = query.lowercased()

        for file in memoryFiles {
            let path = file.fullPath(relativeTo: memoryPath)
            let content = readFile(at: path)
            if content.isEmpty { continue }

            let lines = content.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                if line.lowercased().contains(lowercaseQuery) {
                    results.append((file.displayName, index + 1, line))
                    if results.count > 50 { return results }
                }
            }
        }

        return results
    }

    // MARK: - Helpers

    private func truncate(_ content: String, maxChars: Int) -> String {
        if content.count <= maxChars { return content }
        let index = content.index(content.startIndex, offsetBy: maxChars)
        return String(content[..<index]) + "\n... (已截断)"
    }

    private func shellEscape(_ s: String) -> String {
        return "'" + s.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
