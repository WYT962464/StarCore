import UIKit

// MARK: - Chat View Controller
class ChatViewController: UIViewController {

    // MARK: - UI Components
    private var tableView: UITableView!
    private var inputContainerView: UIView!
    private var inputTextField: UITextField!
    private var sendButton: UIButton!
    private var screenshotButton: UIButton!
    private var statusBarView: UIView!
    private var tweakStatusLabel: UILabel!
    private var providerLabel: UILabel!
    private var cloudStatusLabel: UILabel!
    private var mcpStatusLabel: UILabel!
    private var cloudBridgeStatusLabel: UILabel!
    private var typingIndicatorView: UIActivityIndicatorView!

    // MARK: - Data
    private var messages: [ChatMessage] = []
    private var isWaiting = false

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
        cloudStatusLabel = makeStatusLabel(text: "超脑: ·")
        mcpStatusLabel = makeStatusLabel(text: "MCP: ·")
        cloudBridgeStatusLabel = makeStatusLabel(text: "云桥: ·")

        statusStack.addArrangedSubview(tweakStatusLabel)
        statusStack.addArrangedSubview(providerLabel)
        statusStack.addArrangedSubview(cloudStatusLabel)
        statusStack.addArrangedSubview(mcpStatusLabel)
        statusStack.addArrangedSubview(cloudBridgeStatusLabel)

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
        tableView.register(ChatBubbleCell.self, forCellReuseIdentifier: "ChatBubbleCell")
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

        // Screenshot button (left of input)
        screenshotButton = UIButton(type: .custom)
        screenshotButton.setTitle("📱", for: .normal)
        screenshotButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        screenshotButton.translatesAutoresizingMaskIntoConstraints = false
        screenshotButton.addTarget(self, action: #selector(takeScreenshot), for: .touchUpInside)
        inputContainerView.addSubview(screenshotButton)

        inputTextField = UITextField()
        inputTextField.placeholder = "对我说..."
        inputTextField.attributedPlaceholder = NSAttributedString(
            string: "对我说...",
            attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.3)]
        )
        inputTextField.backgroundColor = UIColor(white: 1, alpha: 0.08)
        inputTextField.layer.borderWidth = 1
        inputTextField.layer.borderColor = UIColor(white: 1, alpha: 0.1).cgColor
        inputTextField.layer.cornerRadius = 20
        inputTextField.textColor = .white
        inputTextField.font = UIFont.systemFont(ofSize: 15)
        inputTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        inputTextField.leftViewMode = .always
        inputTextField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        inputTextField.rightViewMode = .always
        inputTextField.translatesAutoresizingMaskIntoConstraints = false
        inputTextField.delegate = self
        inputContainerView.addSubview(inputTextField)

        sendButton = UIButton(type: .custom)
        sendButton.setBackgroundImage(gradientImage(size: CGSize(width: 40, height: 40), colors: [
            UIColor(red: 0x25/255, green: 0x63/255, blue: 0xeb/255, alpha: 1).cgColor,
            UIColor(red: 0x1d/255, green: 0x4e/255, blue: 0xd8/255, alpha: 1).cgColor
        ]), for: .normal)
        sendButton.layer.cornerRadius = 20
        sendButton.clipsToBounds = true
        sendButton.setTitle("↑", for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        inputContainerView.addSubview(sendButton)

        NSLayoutConstraint.activate([
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            borderLine.topAnchor.constraint(equalTo: inputContainerView.topAnchor),
            borderLine.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor),
            borderLine.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor),
            borderLine.heightAnchor.constraint(equalToConstant: 1),

            screenshotButton.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 8),
            screenshotButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            screenshotButton.widthAnchor.constraint(equalToConstant: 40),
            screenshotButton.heightAnchor.constraint(equalToConstant: 40),

            inputTextField.leadingAnchor.constraint(equalTo: screenshotButton.trailingAnchor, constant: 4),
            inputTextField.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            inputTextField.heightAnchor.constraint(equalToConstant: 40),
            inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),

            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 40),
            sendButton.heightAnchor.constraint(equalToConstant: 40),

            inputContainerView.topAnchor.constraint(equalTo: inputTextField.topAnchor, constant: -10),
            inputContainerView.bottomAnchor.constraint(equalTo: inputTextField.bottomAnchor, constant: 10)
        ])
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
        providerLabel.textColor = provider.apiKey.isEmpty ? UIColor(red: 0xf5/255, green: 0x9e/255, blue: 0x0b/255, alpha: 1) : UIColor(white: 1, alpha: 0.5)

        let cloudConfig = agent.cloudBrainConfig
        cloudStatusLabel.text = cloudConfig.enabled ? "超脑: 🟢" : "超脑: ⚪"
        cloudStatusLabel.textColor = cloudConfig.enabled ? UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1) : UIColor(white: 1, alpha: 0.3)

        let mcpConnected = agent.getMcpStatus()
        mcpStatusLabel.text = mcpConnected ? "MCP: ✅" : "MCP: ⚪"
        mcpStatusLabel.textColor = mcpConnected ? UIColor(red: 0x4e/255, green: 0xca/255, blue: 0x80/255, alpha: 1) : UIColor(white: 1, alpha: 0.3)

        let cloudBridgeAvailable = CloudBridgeClient.shared.isAvailable
        cloudBridgeStatusLabel.text = cloudBridgeAvailable ? "云桥: 🟢" : "云桥: ⚪"
        cloudBridgeStatusLabel.textColor = cloudBridgeAvailable ? UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1) : UIColor(white: 1, alpha: 0.3)
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

    // MARK: - Send Message

    @objc private func sendMessage() {
        guard let text = inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        guard !isWaiting else { return }

        inputTextField.text = ""
        inputTextField.resignFirstResponder()

        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        tableView.insertRows(at: [IndexPath(row: messages.count - 1, section: 0)], with: .bottom)
        scrollToBottom()

        setWaiting(true)

        // Add a placeholder assistant message that will be updated during agent loop
        let placeholderMsg = ChatMessage(role: .assistant, content: "⏳ 思考中...")
        messages.append(placeholderMsg)
        let placeholderIndex = messages.count - 1
        tableView.insertRows(at: [IndexPath(row: placeholderIndex, section: 0)], with: .bottom)
        scrollToBottom()

        var accumulatedReplies: [String] = []
        var accumulatedActions: [String] = []

        StarCoreAgent.shared.chat(
            userInput: text,
            onPartialReply: { [weak self] partialReply, actionResults, step in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    accumulatedReplies.append("【第\(step)步】\(partialReply)")
                    accumulatedActions.append(contentsOf: actionResults)

                    // Update the placeholder message
                    let displayText = accumulatedReplies.joined(separator: "\n\n")
                    self.messages[placeholderIndex] = ChatMessage(
                        role: .assistant,
                        content: displayText,
                        actionResults: accumulatedActions
                    )
                    self.tableView.reloadRows(at: [IndexPath(row: placeholderIndex, section: 0)], with: .none)
                    self.scrollToBottom()
                }
            },
            completion: { [weak self] finalReply, actionResults in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    // Final update with clean text (without step markers)
                    var displayText = finalReply
                    if !actionResults.isEmpty && !finalReply.contains("已执行") {
                        // Keep it clean for the final display
                    }

                    self.messages[placeholderIndex] = ChatMessage(
                        role: .assistant,
                        content: displayText.isEmpty ? finalReply : displayText,
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
                // Add screenshot message to chat
                let screenshotMsg = ChatMessage(
                    role: .user,
                    content: "📸 截图",
                    imagePaths: [filePath]
                )
                self.messages.append(screenshotMsg)
                self.tableView.insertRows(at: [IndexPath(row: self.messages.count - 1, section: 0)], with: .bottom)
                self.scrollToBottom()

                // Also save to history
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

        // Use ImageBubbleCell for messages with images
        if let imagePaths = message.imagePaths, !imagePaths.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ImageBubbleCell", for: indexPath) as! ImageBubbleCell
            cell.configure(with: message)
            cell.onImageTapped = { [weak self] imagePath in
                self?.showFullScreenImage(at: imagePath)
            }
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatBubbleCell", for: indexPath) as! ChatBubbleCell
        cell.configure(with: message)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        let message = messages[indexPath.row]
        if message.imagePaths != nil { return 200 }
        return 60
    }

    // MARK: - Full Screen Image Viewer

    private func showFullScreenImage(at path: String) {
        let viewer = ImageViewerViewController()
        viewer.imagePath = path
        viewer.title = (path as NSString).lastPathComponent
        navigationController?.pushViewController(viewer, animated: true)
    }
}

// MARK: - UITextField Delegate

extension ChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessage()
        return true
    }
}

// MARK: - Chat Bubble Cell

class ChatBubbleCell: UITableViewCell {

    private let bubbleView = UIView()
    private let label = UILabel()
    private let timeLabel = UILabel()
    private let actionResultLabel = UILabel()

    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var timeLeadingConstraint: NSLayoutConstraint!
    private var timeTrailingConstraint: NSLayoutConstraint!

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

        timeLabel.font = UIFont.systemFont(ofSize: 10)
        timeLabel.textColor = UIColor(white: 1, alpha: 0.25)

        actionResultLabel.numberOfLines = 0
        actionResultLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        actionResultLabel.textColor = UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 0.7)
        actionResultLabel.isHidden = true

        bubbleView.layer.cornerRadius = 16
        bubbleView.addSubview(label)

        contentView.addSubview(bubbleView)
        contentView.addSubview(timeLabel)
        contentView.addSubview(actionResultLabel)

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        actionResultLabel.translatesAutoresizingMaskIntoConstraints = false

        // Label inside bubble
        label.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10).isActive = true
        label.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10).isActive = true
        label.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14).isActive = true
        label.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14).isActive = true

        // Bubble position
        bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6).isActive = true
        bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.8).isActive = true

        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)

        // Time label
        timeLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 3).isActive = true
        timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2).isActive = true

        timeLeadingConstraint = timeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        timeTrailingConstraint = timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)

        // Action results
        actionResultLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 2).isActive = true
        actionResultLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20).isActive = true
        actionResultLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20).isActive = true
        actionResultLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -4).isActive = true
    }

    func configure(with message: ChatMessage) {
        label.text = message.content

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        timeLabel.text = formatter.string(from: message.timestamp)

        // Reset alignment constraints
        leadingConstraint.isActive = false
        trailingConstraint.isActive = false
        timeLeadingConstraint.isActive = false
        timeTrailingConstraint.isActive = false

        if message.role == .user {
            trailingConstraint.isActive = true
            timeTrailingConstraint.isActive = true
            bubbleView.backgroundColor = UIColor(red: 0x25/255, green: 0x63/255, blue: 0xeb/255, alpha: 1.0)
            label.textColor = .white
            timeLabel.textAlignment = .right
            bubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        } else {
            leadingConstraint.isActive = true
            timeLeadingConstraint.isActive = true
            bubbleView.backgroundColor = UIColor(white: 1, alpha: 0.08)
            label.textColor = UIColor(white: 1, alpha: 0.9)
            timeLabel.textAlignment = .left
            bubbleView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }

        // Action results
        if let results = message.actionResults, !results.isEmpty {
            actionResultLabel.isHidden = false
            actionResultLabel.text = results.map { "▸ \($0)" }.joined(separator: "\n")
        } else {
            actionResultLabel.isHidden = true
            actionResultLabel.text = nil
        }

        setNeedsLayout()
        layoutIfNeeded()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        label.text = nil
        timeLabel.text = nil
        actionResultLabel.text = nil
        actionResultLabel.isHidden = true
        bubbleView.backgroundColor = .clear
    }
}

// MARK: - Image Bubble Cell

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

        // Load thumbnail
        if let imagePath = message.imagePaths?.first {
            loadImageThumbnail(at: imagePath)
        }
    }

    private func loadImageThumbnail(at path: String) {
        // Try FileManager
        if let data = FileManager.default.contents(atPath: path),
           let image = UIImage(data: data) {
            thumbnailImageView.image = image
            return
        }

        // Fallback: try via Tweak shell
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let base64Cmd = "base64 -i \(path) 2>/dev/null | head -c 50000"
            if let result = StarCoreAgent.shared.tweakCmd(action: "shell", params: ["command": base64Cmd], timeout: 10),
               let raw = result["raw"] as? String,
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
