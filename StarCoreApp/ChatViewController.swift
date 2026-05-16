import UIKit
import WebKit

// MARK: - Chat View Controller（重写版：多行输入+Markdown渲染+流式输出）
class ChatViewController: UIViewController {

    // MARK: - UI Components
    private var tableView: UITableView!
    private var inputContainerView: UIView!
    private var inputTextView: UITextView!       // 多行输入框
    private var sendButton: UIButton!
    private var screenshotButton: UIButton!
    private var imagePickerButton: UIButton!     // 图片选择按钮
    private var statusBarView: UIView!
    private var tweakStatusLabel: UILabel!
    private var providerLabel: UILabel!
    private var mcpStatusLabel: UILabel!
    private var typingIndicatorView: UIActivityIndicatorView!

    // MARK: - Data
    private var messages: [ChatMessage] = []
    private var isWaiting = false

    // 流式输出防抖
    private var streamingDebounceTimer: Timer?
    private var streamingAccumulated = ""

    // 输入框高度约束
    private var inputHeightConstraint: NSLayoutConstraint!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadHistory()
        addWelcomeMessage()
        updateStatusBar()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        StarCoreAgent.shared.onTweakStatusChanged = { [weak self] connected in
            DispatchQueue.main.async {
                self?.updateStatusBar()
            }
        }
        StarCoreAgent.shared.checkTweakConnection()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var prefersStatusBarHidden: Bool {
        return false
    }

    // MARK: - Keyboard Handling

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let inset = frame.height - view.safeAreaInsets.bottom
        tableView.contentInset.bottom = inset + 60
        tableView.scrollIndicatorInsets.bottom = inset + 60
        scrollToBottom()
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        tableView.contentInset.bottom = 60
        tableView.scrollIndicatorInsets.bottom = 60
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor(red: 10/255, green: 14/255, blue: 39/255, alpha: 1.0)

        setupStatusBar()
        setupTableView()
        setupInputArea()
        setupTypingIndicator()
    }

    private func setupStatusBar() {
        statusBarView = UIView()
        statusBarView.backgroundColor = UIColor(red: 10/255, green: 14/255, blue: 26/255, alpha: 0.92)
        statusBarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusBarView)

        NSLayoutConstraint.activate([
            statusBarView.topAnchor.constraint(equalTo: view.topAnchor),
            statusBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBarView.heightAnchor.constraint(equalToConstant: 88)
        ])

        let titleLabel = UILabel()
        titleLabel.text = "✦ 星核"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = UIColor(red: 126/255, green: 184/255, blue: 255/255, alpha: 1.0)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        statusBarView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: statusBarView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: statusBarView.safeAreaLayoutGuide.topAnchor, constant: 8)
        ])

        let statusStack = UIStackView()
        statusStack.axis = .horizontal
        statusStack.spacing = 8
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusBarView.addSubview(statusStack)

        NSLayoutConstraint.activate([
            statusStack.centerXAnchor.constraint(equalTo: statusBarView.centerXAnchor),
            statusStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4)
        ])

        tweakStatusLabel = makeStatusLabel(text: "Tweak: ·")
        providerLabel = makeStatusLabel(text: "LLM: ·")
        mcpStatusLabel = makeStatusLabel(text: "MCP: ·")

        statusStack.addArrangedSubview(tweakStatusLabel)
        statusStack.addArrangedSubview(providerLabel)
        statusStack.addArrangedSubview(mcpStatusLabel)

        let borderView = UIView()
        borderView.backgroundColor = UIColor(white: 1, alpha: 0.06)
        borderView.translatesAutoresizingMaskIntoConstraints = false
        statusBarView.addSubview(borderView)

        NSLayoutConstraint.activate([
            borderView.leadingAnchor.constraint(equalTo: statusBarView.leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: statusBarView.trailingAnchor),
            borderView.bottomAnchor.constraint(equalTo: statusBarView.bottomAnchor),
            borderView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func makeStatusLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 11)
        label.textColor = UIColor(white: 1, alpha: 0.35)
        label.sizeToFit()
        return label
    }

    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.contentInset = UIEdgeInsets(top: 88, left: 0, bottom: 60, right: 0)
        tableView.scrollIndicatorInsets = tableView.contentInset
        tableView.keyboardDismissMode = .interactive
        tableView.register(MarkdownBubbleCell.self, forCellReuseIdentifier: "MarkdownBubbleCell")
        tableView.register(UserBubbleCell.self, forCellReuseIdentifier: "UserBubbleCell")
        tableView.register(ImageBubbleCell.self, forCellReuseIdentifier: "ImageBubbleCell")

        view.insertSubview(tableView, belowSubview: statusBarView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupInputArea() {
        inputContainerView = UIView()
        inputContainerView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputContainerView)

        let borderLine = UIView()
        borderLine.backgroundColor = UIColor(white: 1, alpha: 0.06)
        borderLine.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.addSubview(borderLine)

        // 截图按钮（最左）
        screenshotButton = UIButton(type: .custom)
        screenshotButton.setTitle("📱", for: .normal)
        screenshotButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        screenshotButton.translatesAutoresizingMaskIntoConstraints = false
        screenshotButton.addTarget(self, action: #selector(takeScreenshot), for: .touchUpInside)
        inputContainerView.addSubview(screenshotButton)

        // 图片选择按钮
        imagePickerButton = UIButton(type: .custom)
        imagePickerButton.setTitle("🖼️", for: .normal)
        imagePickerButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        imagePickerButton.translatesAutoresizingMaskIntoConstraints = false
        imagePickerButton.addTarget(self, action: #selector(pickImage), for: .touchUpInside)
        inputContainerView.addSubview(imagePickerButton)

        // 多行输入框（UITextView替代UITextField）
        inputTextView = UITextView()
        inputTextView.font = UIFont.systemFont(ofSize: 15)
        inputTextView.textColor = .white
        inputTextView.backgroundColor = UIColor(white: 1, alpha: 0.08)
        inputTextView.layer.borderWidth = 1
        inputTextView.layer.borderColor = UIColor(white: 1, alpha: 0.1).cgColor
        inputTextView.layer.cornerRadius = 18
        inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        inputTextView.isScrollEnabled = false  // 关键：禁用滚动才能自动扩展
        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        inputTextView.delegate = self

        // placeholder
        inputTextView.text = ""
        inputTextView.textColor = .white
        setPlaceholder("对我说...")

        inputContainerView.addSubview(inputTextView)

        // 发送按钮
        sendButton = UIButton(type: .custom)
        sendButton.setBackgroundImage(gradientImage(size: CGSize(width: 36, height: 36), colors: [
            UIColor(red: 0x25/255, green: 0x63/255, blue: 0xeb/255, alpha: 1).cgColor,
            UIColor(red: 0x1d/255, green: 0x4e/255, blue: 0xd8/255, alpha: 1).cgColor
        ]), for: .normal)
        sendButton.layer.cornerRadius = 18
        sendButton.clipsToBounds = true
        sendButton.setTitle("↑", for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        inputContainerView.addSubview(sendButton)

        // 输入框高度约束（1行≈36，4行≈120）
        inputHeightConstraint = inputTextView.heightAnchor.constraint(equalToConstant: 36)
        inputHeightConstraint.priority = .required

        NSLayoutConstraint.activate([
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            borderLine.topAnchor.constraint(equalTo: inputContainerView.topAnchor),
            borderLine.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor),
            borderLine.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor),
            borderLine.heightAnchor.constraint(equalToConstant: 1),

            // 左侧按钮横排
            screenshotButton.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 6),
            screenshotButton.bottomAnchor.constraint(equalTo: inputContainerView.bottomAnchor, constant: -8),
            screenshotButton.widthAnchor.constraint(equalToConstant: 36),
            screenshotButton.heightAnchor.constraint(equalToConstant: 36),

            imagePickerButton.leadingAnchor.constraint(equalTo: screenshotButton.trailingAnchor, constant: 2),
            imagePickerButton.centerYAnchor.constraint(equalTo: screenshotButton.centerYAnchor),
            imagePickerButton.widthAnchor.constraint(equalToConstant: 36),
            imagePickerButton.heightAnchor.constraint(equalToConstant: 36),

            // 输入框
            inputTextView.leadingAnchor.constraint(equalTo: imagePickerButton.trailingAnchor, constant: 4),
            inputTextView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -6),
            inputTextView.bottomAnchor.constraint(equalTo: inputContainerView.bottomAnchor, constant: -8),
            inputHeightConstraint,

            // 发送按钮
            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -10),
            sendButton.centerYAnchor.constraint(equalTo: inputTextView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 36),

            // 容器顶部对齐输入框顶部
            inputContainerView.topAnchor.constraint(equalTo: inputTextView.topAnchor, constant: -8)
        ])
    }

    // MARK: - Placeholder管理

    private var isShowingPlaceholder = true

    private func setPlaceholder(_ text: String) {
        isShowingPlaceholder = true
        inputTextView.text = text
        inputTextView.textColor = UIColor(white: 1, alpha: 0.3)
    }

    private func removePlaceholder() {
        if isShowingPlaceholder {
            isShowingPlaceholder = false
            inputTextView.text = ""
            inputTextView.textColor = .white
        }
    }

    // MARK: - 输入框高度自适应

    private func updateInputHeight() {
        let size = inputTextView.sizeThatFits(CGSize(width: inputTextView.frame.width, height: .greatestFiniteMagnitude))
        let minHeight: CGFloat = 36
        let maxHeight: CGFloat = 120  // 约4行
        let newHeight = max(minHeight, min(maxHeight, size.height))
        inputHeightConstraint.constant = newHeight

        // 超过最大高度时启用滚动
        inputTextView.isScrollEnabled = size.height > maxHeight
    }

    private func setupTypingIndicator() {
        typingIndicatorView = UIActivityIndicatorView(style: .white)
        typingIndicatorView.hidesWhenStopped = true
        typingIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(typingIndicatorView)

        NSLayoutConstraint.activate([
            typingIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            typingIndicatorView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: -8)
        ])
    }

    private func gradientImage(size: CGSize, colors: [CGColor]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
    }

    // MARK: - Status Bar Update

    private func updateStatusBar() {
        let agent = StarCoreAgent.shared
        let connected = agent.getTweakStatus()
        tweakStatusLabel.text = connected ? "Tweak: ✅" : "Tweak: ❌"
        tweakStatusLabel.textColor = connected ? UIColor(red: 0x4e/255, green: 0xca/255, blue: 0x80/255, alpha: 1) : UIColor(white: 1, alpha: 0.3)

        let provider = agent.currentProvider
        providerLabel.text = "LLM: \(provider.name)"
        // 访客模式(GUEST apiKey)或已配置Key的Provider显示正常色，未配置Key的显示警告色
        providerLabel.textColor = (provider.isGuestMode || !provider.apiKey.isEmpty) ? UIColor(white: 1, alpha: 0.5) : UIColor(red: 0xf5/255, green: 0x9e/255, blue: 0x0b/255, alpha: 1)


        let mcpConnected = agent.getMcpStatus()
        mcpStatusLabel.text = mcpConnected ? "MCP: ✅" : "MCP: ⚪"
        mcpStatusLabel.textColor = mcpConnected ? UIColor(red: 0x4e/255, green: 0xca/255, blue: 0x80/255, alpha: 1) : UIColor(white: 1, alpha: 0.3)
    }

    // MARK: - Data

    private func loadHistory() {
        messages = StarCoreAgent.shared.chatHistory
    }

    private func addWelcomeMessage() {
        if messages.isEmpty {
            let welcome = ChatMessage(role: .assistant, content: "核心就位｜星核系统｜启动完毕。随时响应你的一切指令。")
            messages.append(welcome)
            StarCoreAgent.shared.addToHistory(welcome)
        }
    }

    // MARK: - Send Message（流式输出版）

    @objc private func sendMessage() {
        let text: String
        if isShowingPlaceholder {
            return
        } else {
            text = inputTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        guard !text.isEmpty else { return }
        guard !isWaiting else { return }

        inputTextView.text = ""
        isShowingPlaceholder = false
        inputTextView.textColor = .white
        updateInputHeight()
        inputTextView.resignFirstResponder()

        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        tableView.insertRows(at: [IndexPath(row: messages.count - 1, section: 0)], with: .bottom)
        scrollToBottom()

        setWaiting(true)

        // 添加占位的assistant消息
        let placeholderMsg = ChatMessage(role: .assistant, content: "")
        messages.append(placeholderMsg)
        let placeholderIndex = messages.count - 1
        tableView.insertRows(at: [IndexPath(row: placeholderIndex, section: 0)], with: .bottom)
        scrollToBottom()

        streamingAccumulated = ""

        // 使用流式Agent对话
        StarCoreAgent.shared.chatStreaming(
            userInput: text,
            onToken: { [weak self] token in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    starcore_log("[StarCore] ChatVC onToken: \(token.prefix(30)), total=\(self.streamingAccumulated.count + token.count)")
                    self.streamingAccumulated += token

                    // 防抖：300ms内只渲染一次
                    self.streamingDebounceTimer?.invalidate()
                    self.streamingDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        self.messages[placeholderIndex] = ChatMessage(
                            role: .assistant,
                            content: self.streamingAccumulated
                        )
                        self.tableView.reloadRows(at: [IndexPath(row: placeholderIndex, section: 0)], with: .none)
                        self.scrollToBottom()
                    }
                }
            },
            onStatus: { [weak self] status in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    // 更新执行状态显示
                    if let cell = self.tableView.cellForRow(at: IndexPath(row: placeholderIndex, section: 0)) as? MarkdownBubbleCell {
                        cell.updateStatus(status)
                    }
                }
            },
            completion: { [weak self] finalReply, actionResults in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    // 取消防抖计时器
                    self.streamingDebounceTimer?.invalidate()
                    self.streamingDebounceTimer = nil

                    // 如果流式输出没有任何token，确保最终回复被显示
                    starcore_log("[StarCore] ChatVC completion: finalReply=\(finalReply.prefix(80)), len=\(finalReply.count)")
                    var displayReply = finalReply
                    if finalReply.isEmpty || finalReply == "（空回复）" {
                        displayReply = "❌ 未收到回复，请检查网络和API Key设置"
                    }

                    // 最终完整渲染
                    self.messages[placeholderIndex] = ChatMessage(
                        role: .assistant,
                        content: displayReply,
                        actionResults: actionResults
                    )
                    self.tableView.reloadRows(at: [IndexPath(row: placeholderIndex, section: 0)], with: .none)
                    self.scrollToBottom()
                    self.setWaiting(false)
                    self.updateStatusBar()
                }
            }
        )
    }

    // MARK: - Screenshot

    @objc private func takeScreenshot() {
        guard !isWaiting else { return }

        screenshotButton.isEnabled = false

        StarCoreAgent.shared.takeScreenshot { [weak self] filePath, error in
            guard let self = self else { return }
            self.screenshotButton.isEnabled = true

            if let filePath = filePath {
                let screenshotMsg = ChatMessage(
                    role: .user,
                    content: "📸 截图",
                    imagePaths: [filePath]
                )
                self.messages.append(screenshotMsg)
                self.tableView.insertRows(at: [IndexPath(row: self.messages.count - 1, section: 0)], with: .bottom)
                self.scrollToBottom()
                StarCoreAgent.shared.addToHistory(screenshotMsg)
            } else {
                let errorMsg = ChatMessage(
                    role: .assistant,
                    content: "❌ 截图失败: \(error ?? "未知错误")"
                )
                self.messages.append(errorMsg)
                self.tableView.insertRows(at: [IndexPath(row: self.messages.count - 1, section: 0)], with: .bottom)
                self.scrollToBottom()
            }
        }
    }

    // MARK: - Image Picker

    @objc private func pickImage() {
        guard !isWaiting else { return }

        ImagePickerHelper.showPicker(from: self) { [weak self] image, data in
            guard let self = self else { return }

            // 保存图片到本地
            let filePath = MemoryManager.shared.saveUploadedImage(image: image)

            // 添加图片消息到对话
            let imageMsg = ChatMessage(
                role: .user,
                content: "🖼️ 图片",
                imagePaths: filePath != nil ? [filePath!] : nil
            )
            self.messages.append(imageMsg)
            self.tableView.insertRows(at: [IndexPath(row: self.messages.count - 1, section: 0)], with: .bottom)
            self.scrollToBottom()

            // 如果图片有路径，保存到历史
            if let filePath = filePath {
                StarCoreAgent.shared.addToHistory(imageMsg)
            }

            // 发送图片给AI（多模态API）
            self.setWaiting(true)

            let placeholderMsg = ChatMessage(role: .assistant, content: "")
            self.messages.append(placeholderMsg)
            let placeholderIndex = self.messages.count - 1
            self.tableView.insertRows(at: [IndexPath(row: placeholderIndex, section: 0)], with: .bottom)
            self.scrollToBottom()

            self.streamingAccumulated = ""

            StarCoreAgent.shared.chatWithImage(
                text: "请看这张图片",
                imageData: data,
                onToken: { [weak self] token in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.streamingAccumulated += token
                        self.streamingDebounceTimer?.invalidate()
                        self.streamingDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                            guard let self = self else { return }
                            self.messages[placeholderIndex] = ChatMessage(role: .assistant, content: self.streamingAccumulated)
                            self.tableView.reloadRows(at: [IndexPath(row: placeholderIndex, section: 0)], with: .none)
                            self.scrollToBottom()
                        }
                    }
                },
                completion: { [weak self] reply, actionResults in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.streamingDebounceTimer?.invalidate()
                        self.streamingDebounceTimer = nil
                        var displayReply = reply
                        if reply.isEmpty || reply == "（空回复）" {
                            displayReply = "❌ 未收到回复，请检查网络和API Key设置"
                        }
                        self.messages[placeholderIndex] = ChatMessage(role: .assistant, content: displayReply, actionResults: actionResults)
                        self.tableView.reloadRows(at: [IndexPath(row: placeholderIndex, section: 0)], with: .none)
                        self.scrollToBottom()
                        self.setWaiting(false)
                    }
                }
            )
        }
    }

    private func setWaiting(_ waiting: Bool) {
        isWaiting = waiting
        if waiting {
            typingIndicatorView.startAnimating()
            sendButton.isEnabled = false
            sendButton.alpha = 0.5
        } else {
            typingIndicatorView.stopAnimating()
            sendButton.isEnabled = true
            sendButton.alpha = 1.0
        }
    }

    private func scrollToBottom() {
        if messages.count > 0 {
            tableView.scrollToRow(at: IndexPath(row: messages.count - 1, section: 0), at: .bottom, animated: true)
        }
    }
}

// MARK: - UITableView DataSource & Delegate

extension ChatViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]

        // 图片消息
        if let imagePaths = message.imagePaths, !imagePaths.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ImageBubbleCell", for: indexPath) as! ImageBubbleCell
            cell.configure(with: message)
            cell.onImageTapped = { [weak self] imagePath in
                self?.showFullScreenImage(at: imagePath)
            }
            return cell
        }

        // 用户消息（纯文本，用UILabel）
        if message.role == .user {
            let cell = tableView.dequeueReusableCell(withIdentifier: "UserBubbleCell", for: indexPath) as! UserBubbleCell
            cell.configure(with: message)
            return cell
        }

        // AI消息（Markdown渲染）
        let cell = tableView.dequeueReusableCell(withIdentifier: "MarkdownBubbleCell", for: indexPath) as! MarkdownBubbleCell
        cell.configure(with: message)
        cell.onLinkTapped = { [weak self] url in
            self?.openURL(url)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        let message = messages[indexPath.row]
        if message.imagePaths != nil { return 200 }
        if message.role == .user { return 60 }
        return 80
    }

    // MARK: - 长按菜单

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 不做处理，但用于取消高亮
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return false
    }

    // MARK: - Full Screen Image Viewer

    private func showFullScreenImage(at path: String) {
        let viewer = ImageViewerViewController()
        viewer.imagePath = path
        viewer.title = (path as NSString).lastPathComponent
        navigationController?.pushViewController(viewer, animated: true)
    }

    // MARK: - Open URL

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:])
        } else {
            UIApplication.shared.openURL(url)
        }
    }
}

// MARK: - UITextView Delegate（多行输入框）

extension ChatViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        updateInputHeight()

        // 更新发送按钮状态
        let hasText = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !isWaiting {
            sendButton.isEnabled = hasText
            sendButton.alpha = hasText ? 1.0 : 0.5
        }
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        removePlaceholder()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            setPlaceholder("对我说...")
        }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // 按回车键发送（Shift+回车换行暂不支持，直接换行）
        if text == "\n" {
            // 如果输入为空则换行，否则发送
            let currentText = textView.text ?? ""
            if currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true  // 空输入时允许换行
            }
            sendMessage()
            return false
        }
        return true
    }
}

// MARK: - Markdown Bubble Cell（AI消息，使用WKWebView渲染）

class MarkdownBubbleCell: UITableViewCell {

    private let bubbleView = UIView()
    private var webView: WKWebView!
    private let timeLabel = UILabel()
    private let actionResultLabel = UILabel()
    private let statusLabel = UILabel()
    private let statusSpinner = UIActivityIndicatorView(style: .white)

    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var webViewHeightConstraint: NSLayoutConstraint!
    private var currentContent: String = ""

    var onLinkTapped: ((String) -> Void)?

    // 消息内容脚本处理器
    private class ContentScriptHandler: NSObject, WKScriptMessageHandler {
        var onLinkTapped: ((String) -> Void)?
        var onSizeUpdate: ((CGFloat) -> Void)?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "sizeUpdate" {
                if let body = message.body as? [String: Any],
                   let height = body["height"] as? CGFloat {
                    onSizeUpdate?(height)
                }
            } else if message.name == "linkClick" {
                if let body = message.body as? [String: Any],
                   let url = body["url"] as? String {
                    onLinkTapped?(url)
                }
            }
        }
    }

    private var scriptHandler = ContentScriptHandler()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        bubbleView.layer.cornerRadius = 16
        bubbleView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        bubbleView.backgroundColor = UIColor(white: 1, alpha: 0.08)
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)

        // WKWebView配置
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        scriptHandler = ContentScriptHandler()
        scriptHandler.onLinkTapped = { [weak self] url in
            self?.onLinkTapped?(url)
        }
        scriptHandler.onSizeUpdate = { [weak self] height in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // 更新webView高度约束
                let newHeight = max(30, height + 8)  // 8px padding
                if abs(self.webViewHeightConstraint.constant - newHeight) > 1 {
                    self.webViewHeightConstraint.constant = newHeight
                    // 通知tableView重新计算高度
                    if let tableView = self.superview as? UITableView ?? self.superview?.superview as? UITableView {
                        tableView.beginUpdates()
                        tableView.endUpdates()
                    }
                }
            }
        }
        contentController.add(scriptHandler, name: "sizeUpdate")
        contentController.add(scriptHandler, name: "linkClick")
        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(webView)

        webViewHeightConstraint = webView.heightAnchor.constraint(equalToConstant: 30)

        timeLabel.font = UIFont.systemFont(ofSize: 10)
        timeLabel.textColor = UIColor(white: 1, alpha: 0.25)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timeLabel)

        actionResultLabel.numberOfLines = 0
        actionResultLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        actionResultLabel.textColor = UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 0.7)
        actionResultLabel.isHidden = true
        actionResultLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionResultLabel)

        // Agent执行状态
        statusLabel.font = UIFont.systemFont(ofSize: 12)
        statusLabel.textColor = UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 0.8)
        statusLabel.isHidden = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusLabel)

        statusSpinner.hidesWhenStopped = true
        statusSpinner.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusSpinner)

        NSLayoutConstraint.activate([
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.85),

            webView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 4),
            webView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 2),
            webView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -2),
            webView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -4),
            webViewHeightConstraint,

            timeLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 3),
            timeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),

            actionResultLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 2),
            actionResultLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            actionResultLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            actionResultLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -4),

            statusLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 8),
            statusLabel.bottomAnchor.constraint(equalTo: bubbleView.topAnchor, constant: -2),

            statusSpinner.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 4),
            statusSpinner.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor)
        ])
    }

    func configure(with message: ChatMessage) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        timeLabel.text = formatter.string(from: message.timestamp)

        // 渲染Markdown
        let content = message.content
        if content != currentContent {
            currentContent = content
            if content.isEmpty {
                // 空内容：显示思考中动画
                let html = MarkdownRenderer.render("⏳ 思考中...")
                webView.loadHTMLString(html, baseURL: nil)
                webViewHeightConstraint.constant = 40
            } else {
                let html = MarkdownRenderer.render(content)
                webView.loadHTMLString(html, baseURL: nil)
            }
        }

        // Action results
        if let results = message.actionResults, !results.isEmpty {
            actionResultLabel.isHidden = false
            actionResultLabel.text = results.map { "▸ \($0)" }.joined(separator: "\n")
        } else {
            actionResultLabel.isHidden = true
            actionResultLabel.text = nil
        }

        // 添加长按手势
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        bubbleView.addGestureRecognizer(longPress)

        setNeedsLayout()
        layoutIfNeeded()
    }

    /// 更新Agent执行状态
    func updateStatus(_ status: String) {
        if status.isEmpty {
            statusLabel.isHidden = true
            statusSpinner.stopAnimating()
        } else {
            statusLabel.isHidden = false
            statusLabel.text = status
            statusSpinner.startAnimating()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentContent = ""
        timeLabel.text = nil
        actionResultLabel.text = nil
        actionResultLabel.isHidden = true
        statusLabel.isHidden = true
        statusLabel.text = nil
        statusSpinner.stopAnimating()
        onLinkTapped = nil
        webView.loadHTMLString("", baseURL: nil)
        webViewHeightConstraint.constant = 30
    }

    // MARK: - 长按菜单

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            // 触发Haptic反馈
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            // 获取cell所在的viewController
            var responder: UIResponder? = self
            while responder != nil {
                if let vc = responder as? ChatViewController {
                    // 弹出菜单
                    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                    alert.addAction(UIAlertAction(title: "📋 复制", style: .default) { _ in
                        UIPasteboard.general.string = self.currentContent
                    })
                    alert.addAction(UIAlertAction(title: "🔄 重新生成", style: .default) { _ in
                        // TODO: 重新生成逻辑
                    })
                    alert.addAction(UIAlertAction(title: "🗑 删除", style: .destructive) { _ in
                        // TODO: 删除消息逻辑
                    })
                    alert.addAction(UIAlertAction(title: "取消", style: .cancel))

                    if let popover = alert.popoverPresentationController {
                        popover.sourceView = self.bubbleView
                        popover.sourceRect = self.bubbleView.bounds
                    }

                    vc.present(alert, animated: true)
                    break
                }
                responder = responder?.next
            }
        }
    }
}

// MARK: - User Bubble Cell（用户消息，纯文本UILabel）

class UserBubbleCell: UITableViewCell {

    private let bubbleView = UIView()
    private let label = UILabel()
    private let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 15)
        label.lineBreakMode = .byWordWrapping
        label.textColor = .white

        timeLabel.font = UIFont.systemFont(ofSize: 10)
        timeLabel.textColor = UIColor(white: 1, alpha: 0.25)
        timeLabel.textAlignment = .right

        bubbleView.layer.cornerRadius = 16
        bubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        bubbleView.backgroundColor = UIColor(red: 0x25/255, green: 0x63/255, blue: 0xeb/255, alpha: 1.0)
        bubbleView.addSubview(label)

        contentView.addSubview(bubbleView)
        contentView.addSubview(timeLabel)

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        // Label inside bubble
        label.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10).isActive = true
        label.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10).isActive = true
        label.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14).isActive = true
        label.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14).isActive = true

        // Bubble position (右对齐)
        bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6).isActive = true
        bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16).isActive = true
        bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.8).isActive = true

        // Time label
        timeLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 3).isActive = true
        timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16).isActive = true
        timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2).isActive = true
    }

    func configure(with message: ChatMessage) {
        label.text = message.content

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        timeLabel.text = formatter.string(from: message.timestamp)

        setNeedsLayout()
        layoutIfNeeded()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        label.text = nil
        timeLabel.text = nil
    }
}

// MARK: - Image Bubble Cell（图片消息，保留原版）

class ImageBubbleCell: UITableViewCell {

    private let bubbleView = UIView()
    private let captionLabel = UILabel()
    private let thumbnailImageView = UIImageView()
    private let timeLabel = UILabel()

    var onImageTapped: ((String) -> Void)?
    private var currentImagePath: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        bubbleView.layer.cornerRadius = 16
        bubbleView.clipsToBounds = true
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)

        captionLabel.numberOfLines = 1
        captionLabel.font = UIFont.systemFont(ofSize: 13)
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(captionLabel)

        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 8
        thumbnailImageView.backgroundColor = UIColor(red: 15/255, green: 20/255, blue: 50/255, alpha: 1.0)
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(thumbnailImageView)

        timeLabel.font = UIFont.systemFont(ofSize: 10)
        timeLabel.textColor = UIColor(white: 1, alpha: 0.25)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timeLabel)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        thumbnailImageView.isUserInteractionEnabled = true
        thumbnailImageView.addGestureRecognizer(tapGesture)

        NSLayoutConstraint.activate([
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.7),

            captionLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            captionLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            captionLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),

            thumbnailImageView.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 6),
            thumbnailImageView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 8),
            thumbnailImageView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -8),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 180),
            thumbnailImageView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),

            timeLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 3),
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2)
        ])

        bubbleView.backgroundColor = UIColor(red: 0x25/255, green: 0x63/255, blue: 0xeb/255, alpha: 1.0)
        captionLabel.textColor = .white
        bubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
    }

    func configure(with message: ChatMessage) {
        captionLabel.text = message.content
        currentImagePath = message.imagePaths?.first

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        timeLabel.text = formatter.string(from: message.timestamp)

        if let imagePath = message.imagePaths?.first {
            loadImageThumbnail(at: imagePath)
        }
    }

    private func loadImageThumbnail(at path: String) {
        if let data = FileManager.default.contents(atPath: path),
           let image = UIImage(data: data) {
            thumbnailImageView.image = image
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let base64Cmd = "base64 -i \(path) 2>/dev/null | head -c 50000"
            if let result = StarCoreAgent.shared.tweakCmd(action: "shell", params: ["command": base64Cmd], timeout: 10),
               let raw = result["output"] as? String,
               let data = Data(base64Encoded: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
               let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.thumbnailImageView.image = image
                }
            } else {
                DispatchQueue.main.async {
                    self?.thumbnailImageView.image = nil
                }
            }
        }
    }

    @objc private func imageTapped() {
        if let path = currentImagePath {
            onImageTapped?(path)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        captionLabel.text = nil
        thumbnailImageView.image = nil
        currentImagePath = nil
        onImageTapped = nil
    }
}
