import UIKit

// MARK: - Chat View Controller（极简版：纯UILabel气泡 + 非流式）
class ChatViewController: UIViewController {

    // MARK: - UI
    private var tableView: UITableView!
    private var inputContainerView: UIView!
    private var inputTextField: UITextField!
    private var sendButton: UIButton!
    private var statusBarView: UIView!
    private var tweakStatusLabel: UILabel!
    private var llmStatusLabel: UILabel!
    private var mcpStatusLabel: UILabel!

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
        StarCoreAgent.shared.onTweakStatusChanged = { [weak self] _ in
            DispatchQueue.main.async { self?.updateStatusBar() }
        }
        StarCoreAgent.shared.checkTweakConnection()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Keyboard

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let inset = frame.height - view.safeAreaInsets.bottom
        tableView.contentInset.bottom = inset + 60
        tableView.scrollIndicatorInsets.bottom = inset + 60
        scrollToBottom()
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        tableView.contentInset.bottom = 60
        tableView.scrollIndicatorInsets.bottom = 60
    }

    // MARK: - Setup UI

    private func setupUI() {
        view.backgroundColor = UIColor(red: 10/255, green: 14/255, blue: 39/255, alpha: 1.0)
        setupStatusBar()
        setupTableView()
        setupInputArea()
    }

    private func setupStatusBar() {
        statusBarView = UIView()
        statusBarView.backgroundColor = UIColor(red: 10/255, green: 14/255, blue: 26/255, alpha: 0.95)
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

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        statusBarView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: statusBarView.centerXAnchor),
            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4)
        ])

        tweakStatusLabel = makeStatusLabel()
        llmStatusLabel = makeStatusLabel()
        mcpStatusLabel = makeStatusLabel()
        stack.addArrangedSubview(tweakStatusLabel)
        stack.addArrangedSubview(llmStatusLabel)
        stack.addArrangedSubview(mcpStatusLabel)

        let border = UIView()
        border.backgroundColor = UIColor(white: 1, alpha: 0.06)
        border.translatesAutoresizingMaskIntoConstraints = false
        statusBarView.addSubview(border)
        NSLayoutConstraint.activate([
            border.leadingAnchor.constraint(equalTo: statusBarView.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: statusBarView.trailingAnchor),
            border.bottomAnchor.constraint(equalTo: statusBarView.bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func makeStatusLabel() -> UILabel {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 11)
        l.textColor = UIColor(white: 1, alpha: 0.35)
        return l
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
        tableView.register(AssistantBubbleCell.self, forCellReuseIdentifier: "AssistantBubbleCell")
        tableView.register(UserBubbleCell.self, forCellReuseIdentifier: "UserBubbleCell")

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
        inputContainerView.backgroundColor = UIColor(red: 10/255, green: 14/255, blue: 26/255, alpha: 0.95)
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputContainerView)

        NSLayoutConstraint.activate([
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            inputContainerView.heightAnchor.constraint(equalToConstant: 56)
        ])

        let border = UIView()
        border.backgroundColor = UIColor(white: 1, alpha: 0.06)
        border.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.addSubview(border)
        NSLayoutConstraint.activate([
            border.topAnchor.constraint(equalTo: inputContainerView.topAnchor),
            border.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor),
            border.heightAnchor.constraint(equalToConstant: 1)
        ])

        inputTextField = UITextField()
        inputTextField.placeholder = "说点什么..."
        inputTextField.attributedPlaceholder = NSAttributedString(string: "说点什么...", attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.25)])
        inputTextField.font = UIFont.systemFont(ofSize: 15)
        inputTextField.textColor = .white
        inputTextField.backgroundColor = UIColor(white: 1, alpha: 0.06)
        inputTextField.layer.cornerRadius = 20
        inputTextField.layer.borderWidth = 1
        inputTextField.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        inputTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        inputTextField.leftViewMode = .always
        inputTextField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        inputTextField.rightViewMode = .always
        inputTextField.translatesAutoresizingMaskIntoConstraints = false
        inputTextField.delegate = self
        inputTextField.returnKeyType = .send
        inputContainerView.addSubview(inputTextField)

        sendButton = UIButton(type: .system)
        sendButton.setTitle("↑", for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.backgroundColor = UIColor(red: 0x25/255, green: 0x63/255, blue: 0xeb/255, alpha: 1.0)
        sendButton.layer.cornerRadius = 20
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        inputContainerView.addSubview(sendButton)

        NSLayoutConstraint.activate([
            inputTextField.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 12),
            inputTextField.centerYAnchor.constraint(equalTo: inputContainerView.safeAreaLayoutGuide.centerYAnchor),
            inputTextField.heightAnchor.constraint(equalToConstant: 40),
            sendButton.leadingAnchor.constraint(equalTo: inputTextField.trailingAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: inputTextField.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 40),
            sendButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    // MARK: - Status Bar

    private func updateStatusBar() {
        let tc = StarCoreAgent.shared.getTweakStatus()
        tweakStatusLabel?.text = tc ? "Tweak ✅" : "Tweak ❌"
        tweakStatusLabel?.textColor = tc ? UIColor(red: 0x4e/255, green: 0xca/255, blue: 0x80/255, alpha: 1) : UIColor(red: 0xf5/255, green: 0x9e/255, blue: 0x0b/255, alpha: 1)

        let p = StarCoreAgent.shared.currentProvider
        let llmOk = !p.apiKey.isEmpty
        llmStatusLabel?.text = llmOk ? "LLM ✅" : "LLM ⚠️"
        llmStatusLabel?.textColor = llmOk ? UIColor(red: 0x4e/255, green: 0xca/255, blue: 0x80/255, alpha: 1) : UIColor(red: 0xf5/255, green: 0x9e/255, blue: 0x0b/255, alpha: 1)

        let mc = StarCoreAgent.shared.getMcpStatus()
        mcpStatusLabel?.text = mc ? "MCP ✅" : "MCP ⚪"
        mcpStatusLabel?.textColor = mc ? UIColor(red: 0x4e/255, green: 0xca/255, blue: 0x80/255, alpha: 1) : UIColor(white: 1, alpha: 0.4)
    }

    // MARK: - Data

    private func loadHistory() {
        messages = StarCoreAgent.shared.chatHistory
    }

    private func addWelcomeMessage() {
        if messages.isEmpty {
            let welcome = ChatMessage(role: .assistant, content: "✦ 星核已就绪\n\n纯非流式模式，20步Agent循环。输入指令开始。")
            messages.append(welcome)
        }
    }

    // MARK: - Send

    @objc private func sendTapped() {
        guard let text = inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        inputTextField.text = nil
        inputTextField.resignFirstResponder()
        sendMessage(text)
    }

    private func sendMessage(_ text: String) {
        guard !isWaiting else { return }
        isWaiting = true
        sendButton.isEnabled = false

        // Add user bubble
        let userMsg = ChatMessage(role: .user, content: text)
        // (history is already updated by chatNonStreaming -> addToHistory)
        messages.append(userMsg)
        tableView.reloadData()
        scrollToBottom()

        // Add "thinking" placeholder
        let thinkingMsg = ChatMessage(role: .assistant, content: "⏳ 思考中...")
        messages.append(thinkingMsg)
        tableView.reloadData()
        scrollToBottom()

        let thinkingIdx = messages.count - 1

        // Call non-streaming
        StarCoreAgent.shared.chatNonStreaming(userInput: text) { [weak self] reply, actions in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isWaiting = false
                self.sendButton.isEnabled = true
                // Replace thinking placeholder with real reply
                if self.messages.count > thinkingIdx {
                    self.messages[thinkingIdx] = ChatMessage(role: .assistant, content: reply, actionResults: actions)
                }
                self.tableView.reloadData()
                self.scrollToBottom()
                self.updateStatusBar()
            }
        }
    }

    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let lastIdx = messages.count - 1
        tableView.scrollToRow(at: IndexPath(row: lastIdx, section: 0), at: .bottom, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension ChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
}

// MARK: - UITableViewDataSource & Delegate

extension ChatViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let msg = messages[indexPath.row]
        if msg.role == .user {
            let cell = tableView.dequeueReusableCell(withIdentifier: "UserBubbleCell", for: indexPath) as! UserBubbleCell
            cell.configure(with: msg)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AssistantBubbleCell", for: indexPath) as! AssistantBubbleCell
            cell.configure(with: msg)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - Assistant Bubble Cell（左对齐，半透明）

class AssistantBubbleCell: UITableViewCell {

    private let bubbleView = UIView()
    private let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 15)
        label.lineBreakMode = .byWordWrapping
        label.textColor = UIColor(white: 1, alpha: 0.9)

        bubbleView.layer.cornerRadius = 16
        bubbleView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        bubbleView.backgroundColor = UIColor(white: 1, alpha: 0.07)
        bubbleView.addSubview(label)

        contentView.addSubview(bubbleView)

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
            label.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),

            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.85),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2)
        ])
    }

    func configure(with message: ChatMessage) {
        var text = message.content
        if let actions = message.actionResults, !actions.isEmpty {
            text += "\n\n" + actions.map { "▸ \($0.prefix(120))" }.joined(separator: "\n")
        }
        label.text = text
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        label.text = nil
    }
}

// MARK: - User Bubble Cell（右对齐，蓝色）

class UserBubbleCell: UITableViewCell {

    private let bubbleView = UIView()
    private let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 15)
        label.lineBreakMode = .byWordWrapping
        label.textColor = .white

        bubbleView.layer.cornerRadius = 16
        bubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        bubbleView.backgroundColor = UIColor(red: 0x25/255, green: 0x63/255, blue: 0xeb/255, alpha: 1.0)
        bubbleView.addSubview(label)

        contentView.addSubview(bubbleView)

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
            label.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),

            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.8),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2)
        ])
    }

    func configure(with message: ChatMessage) {
        label.text = message.content
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        label.text = nil
    }
}
