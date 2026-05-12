import Foundation

// MARK: - Memory Manager
class MemoryManager {

    static let shared = MemoryManager()

    private let fileManager = FileManager.default
    private let defaults = UserDefaults.standard

    private var memoryPath: String {
        return defaults.string(forKey: "memoryPath") ?? "/var/mobile/StarCoreAgent/memory/files"
    }

    private init() {}

    // MARK: - SOUL.md Content

    func loadSOULContent() -> String {
        let soulPath = (memoryPath as NSString).appendingPathComponent("SOUL.md")
        let content = readFile(at: soulPath, maxChars: 2000)
        return content
    }

    func loadUserContent() -> String {
        let userPath = (memoryPath as NSString).appendingPathComponent("user.md")
        return readFile(at: userPath, maxChars: 2000)
    }

    func loadContextContent() -> String {
        let contextPath = (memoryPath as NSString).appendingPathComponent("context.md")
        return readFile(at: contextPath, maxChars: 3000)
    }

    func loadToolsContent() -> String {
        let toolsPath = (memoryPath as NSString).appendingPathComponent("tools.md")
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

        let context = loadContextContent()
        if !context.isEmpty {
            parts.append("\n\n【当前状态】\n" + context)
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
        let files = ["SOUL.md", "user.md", "context.md", "tools.md"]
        return files.map { name in
            let path = (memoryPath as NSString).appendingPathComponent(name)
            let exists = fileManager.fileExists(atPath: path)
            var size = 0
            if exists {
                size = readFile(at: path).count
            }
            return (name, exists, size)
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
