import UIKit
import Foundation

// MARK: - Memory Manager
class MemoryManager {

    static let shared = MemoryManager()

    private let fileManager = FileManager.default
    private let defaults = UserDefaults.standard

    private var memoryPath: String {
        return defaults.string(forKey: "memoryPath") ?? "/var/mobile/StarCoreAgent"
    }

    private init() {}

    // MARK: - Memory File Definitions

    /// 记忆文件定义：文件名 + 是否在子目录下
    private struct MemoryFile {
        let name: String        // 显示名（也是文件名）
        let subdirectory: String? // 子目录，nil 表示根目录
        let displayName: String // 在设置页显示的名称

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

    // MARK: - Load Memory Content

    func loadSOULContent() -> String {
        let withSub = (memoryPath as NSString).appendingPathComponent("基础设定")
        let soulPath = (withSub as NSString).appendingPathComponent("SOUL.md")
        return readFile(at: soulPath, maxChars: 2000)
    }

    func loadUserContent() -> String {
        let userPath = (memoryPath as NSString).appendingPathComponent("USER.md")
        return readFile(at: userPath, maxChars: 2000)
    }

    func loadMemoryContent() -> String {
        let memoryPathFile = (memoryPath as NSString).appendingPathComponent("MEMORY.md")
        return readFile(at: memoryPathFile, maxChars: 3000)
    }

    func loadToolsContent() -> String {
        let withSub = (memoryPath as NSString).appendingPathComponent("基础设定")
        let toolsPath = (withSub as NSString).appendingPathComponent("TOOLS.md")
        return readFile(at: toolsPath, maxChars: 2000)
    }

    // MARK: - Build Full System Prompt with Memory

    func buildSystemPrompt(basePrompt: String) -> String {
        var parts = [basePrompt]

        let soul = loadSOULContent()
        if !soul.isEmpty {
            parts.append("\n\n【灵魂】\n" + soul)
        }

        let user = loadUserContent()
        if !user.isEmpty {
            parts.append("\n\n【阿腾】\n" + user)
        }

        let memory = loadMemoryContent()
        if !memory.isEmpty {
            parts.append("\n\n【当前状态】\n" + memory)
        }

        let tools = loadToolsContent()
        if !tools.isEmpty {
            parts.append("\n\n【经验】\n" + tools)
        }

        return parts.joined(separator: "")
    }

    // MARK: - Check Memory Directory (with Tweak fallback)

    func memoryDirectoryExists() -> Bool {
        // First try FileManager
        if fileManager.fileExists(atPath: memoryPath) {
            return true
        }
        // Fallback: use Tweak shell command (works in sandboxed全能签 App)
        let cmd = "ls -d \(memoryPath) 2>/dev/null && echo EXISTS"
        if let result = StarCoreAgent.shared.tweakCmd(action: "shell", params: ["command": cmd]),
           let raw = result["raw"] as? String, raw.contains("EXISTS") {
            return true
        }
        return false
    }

    func memoryFilesInfo() -> [(name: String, exists: Bool, size: Int)] {
        return memoryFiles.map { file in
            let path = file.fullPath(relativeTo: memoryPath)

            // Try FileManager first
            var exists = fileManager.fileExists(atPath: path)
            var size = 0
            if exists {
                size = readFile(at: path).count
            } else {
                // Fallback: use Tweak shell to check existence and get size
                let checkCmd = "stat -f%z \(path) 2>/dev/null"
                if let result = StarCoreAgent.shared.tweakCmd(action: "shell", params: ["command": checkCmd]),
                   let raw = result["raw"] as? String {
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let fileSize = Int(trimmed), fileSize > 0 {
                        exists = true
                        size = fileSize
                    }
                }
            }
            return (file.displayName, exists, size)
        }
    }

    func updateMemoryPath(_ newPath: String) {
        defaults.set(newPath, forKey: "memoryPath")
    }

    // MARK: - Get Memory Path

    func getMemoryPath() -> String {
        return memoryPath
    }

    // MARK: - List All Memory Files (for Memory Tab)

    func listMemoryFiles() -> [MemoryFileInfo] {
        return memoryFiles.compactMap { file -> MemoryFileInfo? in
            let path = file.fullPath(relativeTo: memoryPath)
            return getFileInfo(at: path)
        }
    }

    // MARK: - File Browsing (for File Browser)

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
            return results
        }

        // Fallback: use Tweak shell
        let cmd = "ls -1 \(directoryPath) 2>/dev/null"
        if let result = StarCoreAgent.shared.tweakCmd(action: "shell", params: ["command": cmd]),
           let raw = result["raw"] as? String {
            let names = raw.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            for name in names {
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                let fullPath = (directoryPath as NSString).appendingPathComponent(trimmed)
                if let info = getFileInfo(at: fullPath) {
                    results.append(info)
                }
            }
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

            return MemoryFileInfo(
                name: name,
                path: path,
                isDirectory: isDir.boolValue,
                size: size,
                modDate: modDate
            )
        }

        // Fallback: use Tweak shell
        let statCmd = "stat -f '%z %Sm' \(path) 2>/dev/null"
        if let result = StarCoreAgent.shared.tweakCmd(action: "shell", params: ["command": statCmd]),
           let raw = result["raw"] as? String, !raw.trimmingCharacters(in: .whitespaces).isEmpty {
            let name = (path as NSString).lastPathComponent
            let isDir = path.hasSuffix("/")
            var size: Int64 = 0
            let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
            if let s = Int64(parts.first ?? "") {
                size = s
            }
            return MemoryFileInfo(
                name: name,
                path: path,
                isDirectory: isDir,
                size: size,
                modDate: nil
            )
        }

        return nil
    }

    // MARK: - Read File Content

    func readFileContent(at path: String) -> String {
        return readFile(at: path, maxChars: 0)
    }

    // MARK: - Search Memory Files

    func searchMemoryFiles(query: String) -> [(fileName: String, lineNumber: Int, line: String)] {
        var results: [(fileName: String, lineNumber: Int, line: String)] = []
        let lowercaseQuery = query.lowercased()

        for file in memoryFiles {
            let path = file.fullPath(relativeTo: memoryPath)
            let content = readFile(at: path, maxChars: 0)
            if content.isEmpty { continue }

            let lines = content.components(separatedBy: "\n")
            for (idx, line) in lines.enumerated() {
                if line.lowercased().contains(lowercaseQuery) {
                    results.append((file.displayName, idx + 1, line))
                    if results.count >= 50 { return results } // limit results
                }
            }
        }

        return results
    }

    // MARK: - Save Screenshot

    @discardableResult
    func saveScreenshot(data: Data) -> String? {
        let screenshotsDir = (memoryPath as NSString).appendingPathComponent("screenshots")

        // Create directory if needed
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

        // Fallback: use Tweak shell
        if let base64Str = data.base64EncodedString().data(using: .utf8) {
            let tmpPath = NSTemporaryDirectory() + filename
            fileManager.createFile(atPath: tmpPath, contents: data)
            let cmd = "cp \(tmpPath) \(filePath) 2>/dev/null && echo OK"
            if let result = StarCoreAgent.shared.tweakCmd(action: "shell", params: ["command": cmd]),
               let raw = result["raw"] as? String, raw.contains("OK") {
                return filePath
            }
        }

        return nil
    }

    // MARK: - Save Uploaded Image

    @discardableResult
    func saveUploadedImage(image: UIImage, to directory: String? = nil) -> String? {
        let targetDir = directory ?? (memoryPath as NSString).appendingPathComponent("uploads")

        // Create directory if needed
        if !fileManager.fileExists(atPath: targetDir) {
            try? fileManager.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "upload_\(formatter.string(from: Date())).png"
        let filePath = (targetDir as NSString).appendingPathComponent(filename)

        if let pngData = image.pngData() {
            if fileManager.createFile(atPath: filePath, contents: pngData) {
                return filePath
            }

            // Fallback via Tweak
            let tmpPath = NSTemporaryDirectory() + filename
            fileManager.createFile(atPath: tmpPath, contents: pngData)
            let cmd = "cp \(tmpPath) \(filePath) 2>/dev/null && echo OK"
            if let result = StarCoreAgent.shared.tweakCmd(action: "shell", params: ["command": cmd]),
               let raw = result["raw"] as? String, raw.contains("OK") {
                return filePath
            }
        }

        return nil
    }

    // MARK: - Private Helpers

    private func readFile(at path: String, maxChars: Int = 0) -> String {
        // Try FileManager first
        if fileManager.fileExists(atPath: path),
           let data = fileManager.contents(atPath: path),
           let content = String(data: data, encoding: .utf8) {
            if maxChars > 0 && content.count > maxChars {
                let index = content.index(content.startIndex, offsetBy: maxChars)
                return String(content[..<index]) + "\n... (已截断)"
            }
            return content
        }

        // Fallback: use Tweak shell command to read file (bypasses sandbox)
        let catCmd = "cat \(path) 2>/dev/null"
        if let result = StarCoreAgent.shared.tweakCmd(action: "shell", params: ["command": catCmd], timeout: 3),
           let raw = result["raw"] as? String, !raw.isEmpty {
            let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                if maxChars > 0 && content.count > maxChars {
                    let index = content.index(content.startIndex, offsetBy: maxChars)
                    return String(content[..<index]) + "\n... (已截断)"
                }
                return content
            }
        }

        return ""
    }
}
