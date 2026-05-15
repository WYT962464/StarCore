import UIKit

// MARK: - Markdown → HTML 渲染器
// 将Markdown文本转换为带内嵌CSS的HTML，供WKWebView渲染
class MarkdownRenderer {

    /// 将Markdown文本转为完整HTML文档（内嵌深空蓝主题CSS）
    static func render(_ markdown: String) -> String {
        var html = escapeHTML(markdown)
        html = renderCodeBlocks(&html)
        html = renderInlineCode(html)
        html = renderBold(html)
        html = renderItalic(html)
        html = renderLinks(html)
        html = renderImages(html)
        html = renderHeadings(html)
        html = renderUnorderedLists(html)
        html = renderOrderedLists(html)
        html = renderHorizontalRule(html)
        html = renderTables(html)
        html = renderBlockquotes(html)
        html = renderParagraphs(html)

        return wrapInDocument(html)
    }

    // MARK: - HTML转义

    private static func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - 代码块 ```lang ... ```

    private static func renderCodeBlocks(_ html: inout String) -> String {
        // 匹配 ```lang\n...\n```
        let pattern = "```(\\w*)\\s*\\n([\\s\\S]*?)\\n\\s*```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return html }

        let fullRange = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: fullRange)

        // 从后往前替换，避免索引偏移
        for match in matches.reversed() {
            guard let langRange = Range(match.range(at: 1), in: html),
                  let codeRange = Range(match.range(at: 2), in: html),
                  let fullMatchRange = Range(match.range, in: html) else { continue }

            let lang = String(html[langRange])
            let code = String(html[codeRange])

            // 语言标签
            let langLabel = lang.isEmpty ? "" : "<div class=\"code-lang\">\(lang)</div>"
            // 一键复制按钮
            let copyBtn = "<button class=\"copy-btn\" onclick=\"copyCode(this)\">复制</button>"

            let replacement = "<div class=\"code-block\">\(langLabel)\(copyBtn)<pre><code class=\"language-\(lang)\">\(code)</code></pre></div>"
            html.replaceSubrange(fullMatchRange, with: replacement)
        }

        return html
    }

    // MARK: - 行内代码 `code`

    private static func renderInlineCode(_ html: String) -> String {
        let pattern = "`([^`]+)`"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return html }
        let fullRange = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, options: [], range: fullRange, withTemplate: "<code class=\"inline-code\">$1</code>")
    }

    // MARK: - 粗体 **text**

    private static func renderBold(_ html: String) -> String {
        let pattern = "\\*\\*([^*]+)\\*\\*"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return html }
        let fullRange = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, options: [], range: fullRange, withTemplate: "<strong>$1</strong>")
    }

    // MARK: - 斜体 *text*

    private static func renderItalic(_ html: String) -> String {
        // 注意：避免匹配粗体标记内的星号，用负向前瞻/回顾
        let pattern = "(?<!\\*)\\*([^*]+)\\*(?!\\*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return html }
        let fullRange = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, options: [], range: fullRange, withTemplate: "<em>$1</em>")
    }

    // MARK: - 链接 [text](url)

    private static func renderLinks(_ html: String) -> String {
        let pattern = "\\[([^]]+)\\]\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return html }
        let fullRange = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, options: [], range: fullRange, withTemplate: "<a href=\"$2\" target=\"_blank\">$1</a>")
    }

    // MARK: - 图片 ![alt](url)

    private static func renderImages(_ html: String) -> String {
        let pattern = "!\\[([^]]*)\\]\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return html }
        let fullRange = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, options: [], range: fullRange, withTemplate: "<img src=\"$2\" alt=\"$1\" class=\"markdown-image\" />")
    }

    // MARK: - 标题 # ## ### 等

    private static func renderHeadings(_ html: String) -> String {
        var result = html

        for level in (1...6).reversed() {
            let hashes = String(repeating: "#", count: level)
            let pattern = "\(hashes)\\s+(.+?)(?:\\n|$)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let fullRange = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: fullRange, withTemplate: "<h\(level)>$1</h\(level)>\n")
        }

        return result
    }

    // MARK: - 无序列表 - item

    private static func renderUnorderedLists(_ html: String) -> String {
        var result = html
        let lines = result.components(separatedBy: "\n")
        var inList = false
        var output: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                if !inList {
                    output.append("<ul>")
                    inList = true
                }
                let content = String(trimmed.dropFirst(2))
                output.append("<li>\(content)</li>")
            } else {
                if inList {
                    output.append("</ul>")
                    inList = false
                }
                output.append(line)
            }
        }

        if inList {
            output.append("</ul>")
        }

        return output.joined(separator: "\n")
    }

    // MARK: - 有序列表 1. item

    private static func renderOrderedLists(_ html: String) -> String {
        var result = html
        let lines = result.components(separatedBy: "\n")
        var inList = false
        var output: [String] = []

        let olPattern = "^\\d+\\.\\s+"
        guard let regex = try? NSRegularExpression(pattern: olPattern, options: []) else { return html }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                if !inList {
                    output.append("<ol>")
                    inList = true
                }
                let content = regex.stringByReplacingMatches(in: trimmed, options: [], range: range, withTemplate: "")
                output.append("<li>\(content)</li>")
            } else {
                if inList {
                    output.append("</ol>")
                    inList = false
                }
                output.append(line)
            }
        }

        if inList {
            output.append("</ol>")
        }

        return output.joined(separator: "\n")
    }

    // MARK: - 水平线 ---

    private static func renderHorizontalRule(_ html: String) -> String {
        let pattern = "^-{3,}$|^\\*{3,}$|^_{3,}$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return html }
        let fullRange = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, options: [], range: fullRange, withTemplate: "<hr />")
    }

    // MARK: - 表格

    private static func renderTables(_ html: String) -> String {
        var result = html
        let lines = result.components(separatedBy: "\n")
        var output: [String] = []
        var inTable = false
        var headerProcessed = false

        var i = 0
        while i < lines.count {
            let line = lines[i]

            if line.hasPrefix("|") && line.hasSuffix("|") {
                // 检查是否是分隔行 |---|---|
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let separatorPattern = "^\\|[-:| ]+\\|$"
                if let sepRegex = try? NSRegularExpression(pattern: separatorPattern),
                   sepRegex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                    // 跳过分隔行
                    headerProcessed = true
                    i += 1
                    continue
                }

                if !inTable {
                    output.append("<table>")
                    inTable = true
                    headerProcessed = false
                }

                // 解析单元格
                let cells = trimmed.components(separatedBy: "|").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

                if !headerProcessed {
                    output.append("<thead><tr>")
                    for cell in cells {
                        output.append("<th>\(cell.trimmingCharacters(in: .whitespaces))</th>")
                    }
                    output.append("</tr></thead><tbody>")
                    headerProcessed = true
                } else {
                    output.append("<tr>")
                    for cell in cells {
                        output.append("<td>\(cell.trimmingCharacters(in: .whitespaces))</td>")
                    }
                    output.append("</tr>")
                }
            } else {
                if inTable {
                    output.append("</tbody></table>")
                    inTable = false
                }
                output.append(line)
            }

            i += 1
        }

        if inTable {
            output.append("</tbody></table>")
        }

        return output.joined(separator: "\n")
    }

    // MARK: - 引用 > text

    private static func renderBlockquotes(_ html: String) -> String {
        var result = html
        let lines = result.components(separatedBy: "\n")
        var output: [String] = []
        var inQuote = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("&gt; ") {
                if !inQuote {
                    output.append("<blockquote>")
                    inQuote = true
                }
                let content = String(trimmed.dropFirst(5))
                output.append(content)
            } else {
                if inQuote {
                    output.append("</blockquote>")
                    inQuote = false
                }
                output.append(line)
            }
        }

        if inQuote {
            output.append("</blockquote>")
        }

        return output.joined(separator: "\n")
    }

    // MARK: - 段落处理

    private static func renderParagraphs(_ html: String) -> String {
        // 将连续非空行（不在HTML标签内的）包裹为<p>
        let lines = html.components(separatedBy: "\n")
        var output: [String] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            if paragraphLines.isEmpty { return }
            let text = paragraphLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                // 检查是否已经是HTML块级元素
                let blockTags = ["<h", "<p>", "<div", "<ul", "<ol", "<li", "<table", "<hr", "<blockquote", "<pre", "<img"]
                let isBlock = blockTags.contains { text.hasPrefix($0) }
                if isBlock {
                    output.append(text)
                } else {
                    output.append("<p>\(text)</p>")
                }
            }
            paragraphLines = []
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                flushParagraph()
            } else if trimmed.hasPrefix("<h") || trimmed.hasPrefix("<div") || trimmed.hasPrefix("<ul") ||
                        trimmed.hasPrefix("<ol") || trimmed.hasPrefix("<table") || trimmed.hasPrefix("<hr") ||
                        trimmed.hasPrefix("<blockquote") || trimmed.hasPrefix("<pre") || trimmed.hasPrefix("<img") ||
                        trimmed.hasPrefix("<thead") || trimmed.hasPrefix("<tbody") ||
                        trimmed.hasPrefix("</") {
                flushParagraph()
                output.append(line)
            } else {
                paragraphLines.append(line)
            }
        }
        flushParagraph()

        return output.joined(separator: "\n")
    }

    // MARK: - 包装为完整HTML文档

    private static func wrapInDocument(_ body: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                    -webkit-tap-highlight-color: transparent;
                }
                body {
                    font-family: -apple-system, 'PingFang SC', 'Helvetica Neue', sans-serif;
                    color: rgba(255,255,255,0.9);
                    background: transparent;
                    font-size: 15px;
                    line-height: 1.6;
                    margin: 0;
                    padding: 4px 8px;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                    -webkit-text-size-adjust: 100%;
                }
                p {
                    margin: 0 0 8px 0;
                }
                h1 { font-size: 22px; font-weight: 700; margin: 12px 0 8px 0; color: #60A5FA; }
                h2 { font-size: 19px; font-weight: 700; margin: 10px 0 6px 0; color: #60A5FA; }
                h3 { font-size: 17px; font-weight: 600; margin: 8px 0 6px 0; color: #93C5FD; }
                h4 { font-size: 15px; font-weight: 600; margin: 6px 0 4px 0; color: #93C5FD; }
                h5, h6 { font-size: 14px; font-weight: 600; margin: 6px 0 4px 0; color: rgba(255,255,255,0.7); }

                a {
                    color: #60A5FA;
                    text-decoration: none;
                }
                a:active {
                    color: #93C5FD;
                }

                .code-block {
                    position: relative;
                    background: rgba(0,0,0,0.35);
                    border-radius: 10px;
                    margin: 8px 0;
                    overflow: hidden;
                }
                .code-lang {
                    font-size: 11px;
                    color: rgba(255,255,255,0.4);
                    padding: 6px 12px 0 12px;
                    text-transform: uppercase;
                    font-family: 'Menlo', 'Courier New', monospace;
                }
                .copy-btn {
                    position: absolute;
                    top: 6px;
                    right: 8px;
                    font-size: 11px;
                    color: rgba(255,255,255,0.5);
                    background: rgba(255,255,255,0.1);
                    border: none;
                    border-radius: 4px;
                    padding: 2px 8px;
                    cursor: pointer;
                    font-family: -apple-system, sans-serif;
                }
                .copy-btn:active {
                    background: rgba(255,255,255,0.2);
                    color: #60A5FA;
                }
                pre {
                    background: rgba(0,0,0,0.15);
                    border-radius: 0 0 10px 10px;
                    padding: 10px 12px;
                    overflow-x: auto;
                    -webkit-overflow-scrolling: touch;
                    margin: 0;
                }
                pre code {
                    font-family: 'Menlo', 'Courier New', monospace;
                    font-size: 13px;
                    color: rgba(255,255,255,0.85);
                    line-height: 1.5;
                    white-space: pre;
                }
                .inline-code {
                    font-family: 'Menlo', 'Courier New', monospace;
                    font-size: 13px;
                    background: rgba(255,255,255,0.1);
                    padding: 1px 5px;
                    border-radius: 4px;
                    color: #F0ABFC;
                }

                ul, ol {
                    padding-left: 20px;
                    margin: 4px 0 8px 0;
                }
                li {
                    margin: 2px 0;
                }
                ul li::marker {
                    color: #60A5FA;
                }

                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 8px 0;
                    font-size: 13px;
                }
                th {
                    background: rgba(96,165,250,0.15);
                    color: #93C5FD;
                    padding: 6px 10px;
                    text-align: left;
                    font-weight: 600;
                    border: 1px solid rgba(255,255,255,0.1);
                }
                td {
                    padding: 5px 10px;
                    border: 1px solid rgba(255,255,255,0.08);
                    color: rgba(255,255,255,0.85);
                }
                tr:nth-child(even) td {
                    background: rgba(255,255,255,0.03);
                }

                blockquote {
                    border-left: 3px solid #60A5FA;
                    padding: 4px 12px;
                    margin: 6px 0;
                    color: rgba(255,255,255,0.65);
                    background: rgba(96,165,250,0.05);
                    border-radius: 0 6px 6px 0;
                }

                hr {
                    border: none;
                    border-top: 1px solid rgba(255,255,255,0.1);
                    margin: 12px 0;
                }

                img.markdown-image {
                    max-width: 100%;
                    border-radius: 8px;
                    margin: 6px 0;
                }

                strong {
                    font-weight: 600;
                    color: #E0E7FF;
                }
                em {
                    font-style: italic;
                    color: rgba(255,255,255,0.8);
                }
            </style>
            <script>
                // 高度变化通知原生端
                function notifyHeight() {
                    var h = document.body.scrollHeight;
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.sizeUpdate) {
                        window.webkit.messageHandlers.sizeUpdate.postMessage({ height: h });
                    }
                }

                // 代码块一键复制
                function copyCode(btn) {
                    var codeBlock = btn.parentElement.querySelector('code');
                    if (codeBlock) {
                        var text = codeBlock.textContent;
                        // 使用 clipboard API
                        if (navigator.clipboard) {
                            navigator.clipboard.writeText(text).then(function() {
                                btn.textContent = '已复制';
                                setTimeout(function() { btn.textContent = '复制'; }, 1500);
                            });
                        } else {
                            // fallback
                            var textarea = document.createElement('textarea');
                            textarea.value = text;
                            document.body.appendChild(textarea);
                            textarea.select();
                            document.execCommand('copy');
                            document.body.removeChild(textarea);
                            btn.textContent = '已复制';
                            setTimeout(function() { btn.textContent = '复制'; }, 1500);
                        }
                    }
                }

                // 链接点击通知原生端
                document.addEventListener('click', function(e) {
                    if (e.target.tagName === 'A') {
                        e.preventDefault();
                        var href = e.target.getAttribute('href');
                        if (href && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.linkClick) {
                            window.webkit.messageHandlers.linkClick.postMessage({ url: href });
                        }
                    }
                });

                // 页面加载完成后通知高度
                window.addEventListener('load', function() {
                    setTimeout(notifyHeight, 50);
                });

                // MutationObserver 监听内容变化
                var observer = new MutationObserver(function() {
                    setTimeout(notifyHeight, 50);
                });
                observer.observe(document.body, { childList: true, subtree: true, characterData: true });
            </script>
        </head>
        <body>
            \(body)
        </body>
        </html>
        """
    }
}
