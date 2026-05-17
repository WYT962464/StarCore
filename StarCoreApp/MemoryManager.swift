import UIKit
import Foundation

class MemoryManager {
    static let shared = MemoryManager()
    private let fileManager = FileManager.default
    private let defaults = UserDefaults.standard
    var onDebugLog: ((String) -> Void)?

    private var memoryPath: String {
        // 固定用App沙盒Documents目录（FileManager直读，秒级，无需MCP）
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/var/mobile/StarCore"
    }

    private init() {
        // 写沙盒路径到/var/mobile/StarCore/app_sandbox_path.txt
        // 方便iOS MCP/云端找到App沙盒目录
        let sandboxPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
        if !sandboxPath.isEmpty {
            let markerDir = "/var/mobile/StarCore"
            let markerPath = markerDir + "/app_sandbox_path.txt"
            // 先尝试直接写（可能没权限）
            if !FileManager.default.fileExists(atPath: markerDir) {
                try? FileManager.default.createDirectory(atPath: markerDir, withIntermediateDirectories: true)
            }
            try? sandboxPath.write(toFile: markerPath, atomically: true, encoding: .utf8)
            // 如果没权限，通过MCP写
            if !FileManager.default.fileExists(atPath: markerPath) {
                let escaped = "'" + sandboxPath.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
                _ = smartShell("echo " + escaped + " > /var/mobile/StarCore/app_sandbox_path.txt")
            }
        }
    }

    private func debugLog(_ msg: String) {
        print("[Memory] \(msg)")
        onDebugLog?(msg)
    }

    func getMemoryPath() -> String { return memoryPath }



    // MARK: - Shell helpers

    @discardableResult
    private func tweakShell(_ cmd: String, timeout: TimeInterval = 2) -> String? {
        debugLog("tweak: \(cmd.prefix(80))")
        if let result = StarCoreAgent.shared.tweakCmd(action: "shell", params: ["command": cmd], timeout: timeout),
           let output = result["output"] as? String, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return output
        }
        return nil
    }

    @discardableResult
    private func mcpShell(_ cmd: String) -> String? {
        debugLog("mcp: \(cmd.prefix(80))")
        if let result = StarCoreAgent.shared.callMcpToolSync(name: "run_command", arguments: ["command": cmd]) {
            // run_command返回格式: {exitCode:0, output:"..."}
            if let output = result["output"] as? String, !output.isEmpty {
                debugLog("mcp got output: \(output.prefix(100))")
                return output
            }
            // 也可能是JSON-RPC包装: {result: {content: [{text: "{exitCode:0,output:...}"}]}}
            if let rpcResult = result["result"] as? [String: Any],
               let content = rpcResult["content"] as? [[String: Any]],
               let first = content.first,
               let text = first["text"] as? String, !text.isEmpty {
                // text本身可能是JSON: {"exitCode":0,"output":"..."}
                if let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let output = json["output"] as? String, !output.isEmpty {
                    return output
                }
                // 或者text直接就是输出
                return text
            }
            debugLog("mcp unexpected: \(String(describing: result).prefix(300))")
        }
        return nil
    }

    @discardableResult
    private func smartShell(_ cmd: String, timeout: TimeInterval = 2) -> String? {
        if let result = tweakShell(cmd, timeout: timeout) { return result }
        debugLog("Tweak failed, trying MCP...")
        return mcpShell(cmd)
    }

    private func shellEscape(_ s: String) -> String {
        return "'" + s.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    // MARK: - Directory check

    func memoryDirectoryExists() -> Bool {
        if fileManager.fileExists(atPath: memoryPath) { return true }
        if let output = smartShell("test -d " + shellEscape(memoryPath) + " && echo YES") {
            return output.contains("YES")
        }
        return false
    }

    // MARK: - List Memory Files (记忆区tab)
    func listMemoryFiles() -> [MemoryFileInfo] {
        let results = listFiles(at: memoryPath)
        debugLog("listMemoryFiles: \(results.count) items")
        return results
    }

    // MARK: - List Files (文件浏览器tab)
    func listFiles(at directoryPath: String) -> [MemoryFileInfo] {
        var results: [MemoryFileInfo] = []

        // Try FileManager first
        if let contents = try? fileManager.contentsOfDirectory(atPath: directoryPath) {
            for name in contents.sorted() {
                let fullPath = (directoryPath as NSString).appendingPathComponent(name)
                if let info = getFileInfo(at: fullPath) {
                    results.append(info)
                }
            }
            debugLog("FileManager: \(results.count) items")
            return results
        }

        // Fallback: ls -1p via iOS MCP/Tweak
        let escapedPath = shellEscape(directoryPath)
        let cmd = "ls -1p " + escapedPath + " 2>/dev/null"
        if let output = smartShell(cmd, timeout: 3) {
            let rawLines = output.components(separatedBy: "\n")
            for rawLine in rawLines {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line == "." || line == ".." { continue }
                let isDir = line.hasSuffix("/")
                let name = isDir ? String(line.dropLast()) : line
                let fullPath = (directoryPath as NSString).appendingPathComponent(name)
                results.append(MemoryFileInfo(name: name, path: fullPath, isDirectory: isDir, size: 0, modDate: nil))
            }
            debugLog("ls -1p: \(results.count) items in \(directoryPath)")
        }

        results.sort { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return results
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
        return nil
    }

    // MARK: - Read File
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

        // Fallback: smartShell cat
        let escaped = shellEscape(path)
        if let content = smartShell("cat " + escaped + " 2>/dev/null", timeout: 8) {
            return maxChars > 0 ? truncate(content, maxChars: maxChars) : content
        }
        return ""
    }

    // MARK: - Write File
    func writeFile(content: String, to path: String) -> Bool {
        // 优先用FileManager（沙盒内直写，秒级，无需Tweak/MCP）
        guard let data = content.data(using: .utf8) else {
            debugLog("writeFile: 内容转UTF8失败")
            return false
        }
        
        // 确保目录存在（含中文路径）
        let dir = (path as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: dir) {
            do {
                try fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
                debugLog("writeFile: 创建目录成功: " + dir)
            } catch {
                debugLog("writeFile: 创建目录失败: " + error.localizedDescription)
            }
        }
        
        // 方法1: Data.write(to:) — 最可靠的写入方式
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            debugLog("writeFile: Data.write成功: " + path)
            return true
        } catch {
            debugLog("writeFile: Data.write失败: " + error.localizedDescription + " path=" + path)
        }
        
        // 方法2: createFile（针对新文件）
        if fileManager.createFile(atPath: path, contents: data) {
            debugLog("writeFile: createFile成功: " + path)
            return true
        }
        debugLog("writeFile: createFile也失败: " + path)

        // Fallback: smartShell（用于写沙盒外的路径）
        debugLog("FileManager失败，尝试smartShell: " + path)
        let escaped = shellEscape(path)

        // 小文件直接echo
        if content.count < 1000 && !content.contains("'") {
            let cmd = "echo '" + content + "' > " + escaped + " 2>/dev/null && echo WRITE_OK"
            if let result = smartShell(cmd), result.contains("WRITE_OK") { return true }
        }

        // 大文件走base64
        guard let data = content.data(using: .utf8) else { return false }
        let base64 = data.base64EncodedString()
        let tmpBase64 = "/tmp/starcore_write.b64"

        _ = smartShell("echo -n '' > " + shellEscape(tmpBase64))

        let chunkSize = 4000
        var offset = base64.startIndex
        while offset < base64.endIndex {
            let end = base64.index(offset, offsetBy: chunkSize, limitedBy: base64.endIndex) ?? base64.endIndex
            let chunk = String(base64[offset..<end])
            _ = smartShell("printf '%s' '" + chunk + "' >> " + shellEscape(tmpBase64))
            offset = end
        }

        if let result = smartShell("base64 -d < " + shellEscape(tmpBase64) + " > " + escaped + " 2>/dev/null && echo WRITE_OK || echo WRITE_FAIL") {
            _ = smartShell("rm -f " + shellEscape(tmpBase64))
            return result.contains("WRITE_OK")
        }
        _ = smartShell("rm -f " + shellEscape(tmpBase64))
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
        let filename = "screenshot_" + formatter.string(from: Date()) + ".png"
        let filePath = (screenshotsDir as NSString).appendingPathComponent(filename)
        if fileManager.createFile(atPath: filePath, contents: data) { return filePath }
        return nil
    }

    // MARK: - Save Uploaded Image
    func saveUploadedImage(image: UIImage, to directoryPath: String) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "upload_" + formatter.string(from: Date()) + ".jpg"
        let filePath = (directoryPath as NSString).appendingPathComponent(filename)
        if fileManager.createFile(atPath: filePath, contents: data) { return filePath }
        return nil
    }

    // MARK: - Memory Files Info (for settings)
    func memoryFilesInfo() -> [(name: String, exists: Bool, size: Int)] {
        let files = ["SOUL.md", "USER.md", "MEMORY.md", "TOOLS.md", "SECRET.md", "EMAIL_RULES.md"]
        return files.map { name in
            let subDirs: [String?] = [nil, "基础设定"]
            for sub in subDirs {
                var path: String
                if let sub = sub {
                    path = (memoryPath as NSString).appendingPathComponent(sub)
                    path = (path as NSString).appendingPathComponent(name)
                } else {
                    path = (memoryPath as NSString).appendingPathComponent(name)
                }
                if fileManager.fileExists(atPath: path) {
                    let size = readFile(at: path).count
                    return (name, true, size)
                }
                let escaped = shellEscape(path)
                if let result = smartShell("stat -f%z " + escaped + " 2>/dev/null"),
                   let fileSize = Int(result.trimmingCharacters(in: .whitespacesAndNewlines)), fileSize > 0 {
                    return (name, true, fileSize)
                }
            }
            return (name, false, 0)
        }
    }

    // MARK: - Search
    func searchMemoryFiles(query: String) -> [(fileName: String, lineNumber: Int, line: String)] {
        var results: [(fileName: String, lineNumber: Int, line: String)] = []
        let lowercaseQuery = query.lowercased()
        let files = listMemoryFiles()
        for file in files where !file.isDirectory {
            let content = readFile(at: file.path)
            if content.isEmpty { continue }
            let lines = content.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                if line.lowercased().contains(lowercaseQuery) {
                    results.append((file.name, index + 1, line))
                    if results.count > 50 { return results }
                }
            }
        }
        return results
    }

    // MARK: - Load for system prompt
    func loadSOULContent() -> String {
        return readFile(at: (memoryPath as NSString).appendingPathComponent("基础设定/SOUL.md"), maxChars: 2000)
    }
    func loadUserContent() -> String {
        return readFile(at: (memoryPath as NSString).appendingPathComponent("USER.md"), maxChars: 2000)
    }
    func loadMemoryContent() -> String {
        return readFile(at: (memoryPath as NSString).appendingPathComponent("MEMORY.md"), maxChars: 3000)
    }
    func loadToolsContent() -> String {
        return readFile(at: (memoryPath as NSString).appendingPathComponent("基础设定/TOOLS.md"), maxChars: 2000)
    }

    func buildSystemPrompt(basePrompt: String) -> String {
        var parts = [basePrompt]

        // 上报App沙盒路径和可用action工具
        let sandboxPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
        if !sandboxPath.isEmpty {
            let pathInfo = "\n\n【App沙盒路径】" + sandboxPath
                + "\n这是星核App的本地记忆目录，你可以通过函数调用直接读写。"
                + "\n重要规则：每次只调一个函数！写完会自动校验。"
                + "\n记忆文件: SOUL.md USER.md MEMORY.md TOOLS.md SECRET.md"
                + "\n子目录: 基础设定/ (存放SOUL.md和TOOLS.md)"
                + "\n建议：单文件控制在2000字符内，更新记忆优先用appendFile追加"
                + "\n示例路径: " + sandboxPath + "/SOUL.md"
            parts.append(pathInfo)
        }

        let soul = loadSOULContent(); if !soul.isEmpty { parts.append("\n\n【灵魂】\n" + soul) }
        let user = loadUserContent(); if !user.isEmpty { parts.append("\n\n【阿腾】\n" + user) }
        let memory = loadMemoryContent(); if !memory.isEmpty { parts.append("\n\n【当前状态】\n" + memory) }
        let tools = loadToolsContent(); if !tools.isEmpty { parts.append("\n\n【经验】\n" + tools) }
        return parts.joined(separator: "")
    }

    private func truncate(_ content: String, maxChars: Int) -> String {
        if content.count <= maxChars { return content }
        let index = content.index(content.startIndex, offsetBy: maxChars)
        return String(content[..<index]) + "\n... (已截断)"
    }
}
