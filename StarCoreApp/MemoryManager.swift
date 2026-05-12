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
                return (root as NSString).appendingPathComponent(sub).appendingPathComponent(name)
            } else {
                return (root as NSString).appendingPathComponent(name)
            }
        }
    }

    private let memoryFiles: [MemoryFile] = [
        MemoryFile(name: "SOUL.md",   subdirectory: "基础设定", displayName: "SOUL.md"),
        MemoryFile(name: "USER.md",   subdirectory: nil,       displayName: "USER.md"),
        MemoryFile(name: "MEMORY.md", subdirectory: nil,       displayName: "MEMORY.md"),
        MemoryFile(name: "TOOLS.md",  subdirectory: "基础设定", displayName: "TOOLS.md"),
    ]

    // MARK: - Load Memory Content

    func loadSOULContent() -> String {
        let soulPath = (memoryPath as NSString).appendingPathComponent("基础设定").appendingPathComponent("SOUL.md")
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
        let toolsPath = (memoryPath as NSString).appendingPathComponent("基础设定").appendingPathComponent("TOOLS.md")
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

    // MARK: - Check Memory Directory

    func memoryDirectoryExists() -> Bool {
        return fileManager.fileExists(atPath: memoryPath)
    }

    func memoryFilesInfo() -> [(name: String, exists: Bool, size: Int)] {
        return memoryFiles.map { file in
            let path = file.fullPath(relativeTo: memoryPath)
            let exists = fileManager.fileExists(atPath: path)
            var size = 0
            if exists {
                size = readFile(at: path).count
            }
            return (file.displayName, exists, size)
        }
    }

    func updateMemoryPath(_ newPath: String) {
        defaults.set(newPath, forKey: "memoryPath")
    }

    // MARK: - Private Helpers

    private func readFile(at path: String, maxChars: Int = 0) -> String {
        guard fileManager.fileExists(atPath: path) else { return "" }
        guard let data = fileManager.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return "" }

        if maxChars > 0 && content.count > maxChars {
            let index = content.index(content.startIndex, offsetBy: maxChars)
            return String(content[..<index]) + "\n... (已截断)"
        }
        return content
    }
}
