import UIKit

// MARK: - Settings View Controller
class SettingsViewController: UIViewController {

    private var scrollView: UIScrollView!
    private var contentView: UIView!

    // MARK: - Section spacing constants
    private let sectionGap: CGFloat = 24      // section之间的间距
    private let rowGap: CGFloat = 10           // 同一section内行间距
    private let sectionPadding: CGFloat = 16   // section header到第一个row的间距
    private let bottomPadding: CGFloat = 60    // 底部留白

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshUI()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor(red: 10/255, green: 14/255, blue: 39/255, alpha: 1.0)
        title = "设置"

        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        var lastView: UIView = contentView

        // Section: LLM Provider
        lastView = addSectionHeader("🤖 LLM Provider（免费）", below: lastView, isFirst: true)
        lastView = addProviderPicker(below: lastView)
        lastView = addKeyHint(below: lastView)
        lastView = addAPIKeyField(below: lastView)
        lastView = addGetFreeKeyButton(below: lastView)
        lastView = addModelField(below: lastView)

        // Divider
        lastView = addDivider(below: lastView)

        // Section: Tweak Connection
        lastView = addSectionHeader("🔧 Tweak连接", below: lastView)
        lastView = addTweakStatus(below: lastView)
        lastView = addReconnectButton(below: lastView)

        // Divider
        lastView = addDivider(below: lastView)

        // Section: iOS MCP
        lastView = addSectionHeader("📱 ios-mcp（备选）", below: lastView)
        lastView = addMcpStatus(below: lastView)
        lastView = addMcpReconnectButton(below: lastView)

        // Divider
        lastView = addDivider(below: lastView)

        // Section: Chat
        lastView = addSectionHeader("💬 对话", below: lastView)
        lastView = addClearHistoryButton(below: lastView)

        // Divider
        lastView = addDivider(below: lastView)

        // Section: About
        lastView = addSectionHeader("ℹ️ 关于", below: lastView)
        lastView = addVersionInfo(below: lastView)

        // Bottom spacing
        contentView.bottomAnchor.constraint(equalTo: lastView.bottomAnchor, constant: bottomPadding).isActive = true
    }

    // MARK: - Section Builder Helpers

    @discardableResult
    private func addSectionHeader(_ title: String, below aboveView: UIView, isFirst: Bool = false) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        label.textColor = UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        let topOffset: CGFloat = isFirst ? 20 : 0  // 第一个section不需要额外上方间距（divider已提供）
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: aboveView.topAnchor, constant: topOffset)
        ])

        return label
    }

    @discardableResult
    private func addDivider(below aboveView: UIView) -> UIView {
        let divider = UIView()
        divider.backgroundColor = UIColor(white: 1, alpha: 0.08)
        divider.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(divider)

        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            divider.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: sectionGap),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])

        return divider
    }

    @discardableResult
    private func addRow(label text: String, below aboveView: UIView, isLast: Bool = false) -> (label: UILabel, rowView: UIView) {
        let rowView = UIView()
        rowView.backgroundColor = UIColor(white: 1, alpha: 0.04)
        rowView.layer.cornerRadius = 10
        rowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowView)

        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(white: 1, alpha: 0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(label)

        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            rowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            rowView.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: rowGap),
            rowView.heightAnchor.constraint(equalToConstant: 46),

            label.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: rowView.centerYAnchor)
        ])

        return (label, rowView)
    }

    // MARK: - Provider picker

    private func addProviderPicker(below aboveView: UIView) -> UIView {
        let (label, rowView) = addRow(label: "当前Provider", below: aboveView)

        let segment = UISegmentedControl(items: LLMProvider.allProviders.map { $0.name })
        segment.selectedSegmentIndex = StarCoreAgent.shared.currentProviderIndex
        segment.translatesAutoresizingMaskIntoConstraints = false
        segment.tintColor = UIColor(red: 0x25/255, green: 0x63/255, blue: 0xeb/255, alpha: 1.0)
        segment.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segment.setTitleTextAttributes([.foregroundColor: UIColor(white: 1, alpha: 0.5)], for: .normal)
        segment.backgroundColor = UIColor(white: 1, alpha: 0.08)
        segment.addTarget(self, action: #selector(providerChanged(_:)), for: .valueChanged)
        rowView.addSubview(segment)

        NSLayoutConstraint.activate([
            segment.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -12),
            segment.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            segment.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12)
        ])

        return rowView
    }

    @objc private func providerChanged(_ sender: UISegmentedControl) {
        StarCoreAgent.shared.currentProviderIndex = sender.selectedSegmentIndex
        refreshUI()
    }

    // MARK: - Key Hint (获取免费Key提示)

    private var keyHintLabel: UILabel?

    private func addKeyHint(below aboveView: UIView) -> UIView {
        let hintLabel = UILabel()
        hintLabel.font = UIFont.systemFont(ofSize: 12)
        hintLabel.textColor = UIColor(red: 0x4e/255, green: 0xca/255, blue: 0x80/255, alpha: 1.0)  // 绿色
        hintLabel.numberOfLines = 0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hintLabel)
        keyHintLabel = hintLabel

        // 点击手势，打开注册页面
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(openKeyRegistrationPage))
        hintLabel.isUserInteractionEnabled = true
        hintLabel.addGestureRecognizer(tapGesture)

        NSLayoutConstraint.activate([
            hintLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            hintLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            hintLabel.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 4)
        ])

        updateKeyHintText()
        return hintLabel
    }

    private func updateKeyHintText() {
        let idx = StarCoreAgent.shared.currentProviderIndex
        let hint = LLMProvider.keyHint(forProviderIndex: idx)
        keyHintLabel?.text = "💡 \(hint)"
    }

    @objc private func openKeyRegistrationPage() {
        let idx = StarCoreAgent.shared.currentProviderIndex
        let urlString: String
        switch idx {
        case 0: return  // 访客模式无需打开注册页面
        case 1: urlString = "https://console.volcengine.com/ark"
        case 2: urlString = "https://platform.deepseek.com"
        case 3: urlString = "https://aistudio.google.com"
        case 4: urlString = "https://console.groq.com"
        case 5: urlString = "https://siliconflow.cn"
        default: return
        }
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    // MARK: - API Key Field

    private func addAPIKeyField(below aboveView: UIView) -> UIView {
        let rowView = UIView()
        rowView.backgroundColor = UIColor(white: 1, alpha: 0.04)
        rowView.layer.cornerRadius = 10
        rowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowView)

        let label = UILabel()
        label.text = "API Key"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(white: 1, alpha: 0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(label)

        let textField = UITextField()
        textField.placeholder = "sk-..."
        textField.attributedPlaceholder = NSAttributedString(
            string: "sk-...",
            attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.25)]
        )
        textField.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textField.textColor = .white
        textField.backgroundColor = UIColor(white: 1, alpha: 0.06)
        textField.layer.cornerRadius = 8
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
        textField.rightViewMode = .always
        textField.isSecureTextEntry = true
        textField.text = StarCoreAgent.shared.currentProvider.apiKey
        textField.tag = 100
        textField.addTarget(self, action: #selector(apiKeyChanged(_:)), for: .editingDidEnd)
        rowView.addSubview(textField)

        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            rowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            rowView.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: rowGap),
            rowView.heightAnchor.constraint(equalToConstant: 46),

            label.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),

            textField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -12),
            textField.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 32)
        ])

        return rowView
    }

    @objc private func apiKeyChanged(_ sender: UITextField) {
        var providers = StarCoreAgent.shared.providers
        let idx = StarCoreAgent.shared.currentProviderIndex
        guard idx >= 0 && idx < providers.count else { return }
        providers[idx].apiKey = sender.text ?? ""
        StarCoreAgent.shared.providers = providers
    }

    // MARK: - Get Free Key Button

    private var getFreeKeyButton: UIButton!

    private func addGetFreeKeyButton(below aboveView: UIView) -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("🔑 获取免费API Key", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = UIColor(red: 0x25/255, green: 0x63/255, blue: 0xeb/255, alpha: 1.0)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(openGetFreeKey), for: .touchUpInside)
        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            button.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: rowGap),
            button.heightAnchor.constraint(equalToConstant: 46)
        ])

        getFreeKeyButton = button
        updateGetFreeKeyButton()

        return button
    }

    private func updateGetFreeKeyButton() {
        let idx = StarCoreAgent.shared.currentProviderIndex
        let all = StarCoreAgent.shared.providers
        guard idx >= 0 && idx < all.count else { return }
        let provider = all[idx]

        // Hide button for guest mode and custom provider
        if provider.isGuestMode || provider.name == "自定义" {
            getFreeKeyButton?.isHidden = true
        } else {
            getFreeKeyButton?.isHidden = false
            let urls: [Int: (String, String)] = [
                1: ("🔑 获取火山方舟免费Key（50万tokens/模型）", "https://console.volcengine.com/ark"),
                2: ("🔑 获取DeepSeek免费Key（500万token）", "https://platform.deepseek.com"),
                3: ("🔑 获取Gemini免费Key（1500次/天）", "https://aistudio.google.com"),
                4: ("🔑 获取Groq免费Key（30RPM）", "https://console.groq.com"),
                5: ("🔑 获取硅基流动Key", "https://siliconflow.cn"),
            ]
            if let (title, _) = urls[idx] {
                getFreeKeyButton?.setTitle(title, for: .normal)
            }
        }
    }

    @objc private func openGetFreeKey() {
        let idx = StarCoreAgent.shared.currentProviderIndex
        let urls: [Int: String] = [
            1: "https://console.volcengine.com/ark",
            2: "https://platform.deepseek.com",
            3: "https://aistudio.google.com",
            4: "https://console.groq.com",
            5: "https://siliconflow.cn",
        ]
        guard let urlString = urls[idx], let url = URL(string: urlString) else { return }
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:])
        } else {
            UIApplication.shared.openURL(url)
        }
    }

    private func addModelField(below aboveView: UIView) -> UIView {
        let label = UILabel()
        label.text = "Model"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(white: 1, alpha: 0.5)
        label.translatesAutoresizingMaskIntoConstraints = false

        let rowView = UIView()
        rowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowView)

        let textField = UITextField()
        textField.placeholder = "模型/Endpoint ID"
        textField.font = UIFont.systemFont(ofSize: 14)
        textField.textColor = .white
        textField.backgroundColor = UIColor(white: 1, alpha: 0.06)
        textField.layer.cornerRadius = 8
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
        textField.rightViewMode = .always
        textField.text = StarCoreAgent.shared.currentProvider.model
        textField.tag = 200
        textField.addTarget(self, action: #selector(modelChanged(_:)), for: .editingDidEnd)
        rowView.addSubview(label)
        rowView.addSubview(textField)

        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            rowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            rowView.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 10),
            rowView.heightAnchor.constraint(equalToConstant: 46),
            label.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            textField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -12),
            textField.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 32)
        ])

        return rowView
    }

    @objc private func modelChanged(_ sender: UITextField) {
        var providers = StarCoreAgent.shared.providers
        let idx = StarCoreAgent.shared.currentProviderIndex
        guard idx >= 0 && idx < providers.count else { return }
        providers[idx].model = sender.text ?? ""
        StarCoreAgent.shared.providers = providers
    }

    // MARK: - Cloud Brain

    // MARK: - Tweak Status

    private var tweakStatusLabel: UILabel!

    private func addTweakStatus(below aboveView: UIView) -> UIView {
        let (label, rowView) = addRow(label: "连接状态", below: aboveView)
        tweakStatusLabel = label
        let connected = StarCoreAgent.shared.getTweakStatus()
        updateTweakStatusLabel(connected)
        return rowView
    }

    private func updateTweakStatusLabel(_ connected: Bool) {
        tweakStatusLabel?.text = connected ? "✅ 已连接 (localhost:6000)" : "❌ 未连接"
        tweakStatusLabel?.textColor = connected ? UIColor(red: 0x4e/255, green: 0xca/255, blue: 0x80/255, alpha: 1) : UIColor(red: 0xf5/255, green: 0x9e/255, blue: 0x0b/255, alpha: 1)
    }

    private func addReconnectButton(below aboveView: UIView) -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("重新检测连接", for: .normal)
        button.setTitleColor(UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.backgroundColor = UIColor(white: 1, alpha: 0.04)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(reconnectTweak), for: .touchUpInside)
        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            button.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: rowGap),
            button.heightAnchor.constraint(equalToConstant: 46)
        ])

        return button
    }

    @objc private func reconnectTweak() {
        StarCoreAgent.shared.reconnectTweak()
        // Delay to allow connection check
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            let connected = StarCoreAgent.shared.getTweakStatus()
            self?.updateTweakStatusLabel(connected)
        }
    }

    // MARK: - iOS MCP Status

    private var mcpStatusLabel: UILabel!

    private func addMcpStatus(below aboveView: UIView) -> UIView {
        let (label, rowView) = addRow(label: "ios-mcp状态", below: aboveView)
        mcpStatusLabel = label
        let connected = StarCoreAgent.shared.getMcpStatus()
        updateMcpStatusLabel(connected)
        return rowView
    }

    private func updateMcpStatusLabel(_ connected: Bool) {
        mcpStatusLabel?.text = connected ? "✅ 已连接 (localhost:8090)" : "⚪ 未连接"
        mcpStatusLabel?.textColor = connected ? UIColor(red: 0x4e/255, green: 0xca/255, blue: 0x80/255, alpha: 1) : UIColor(white: 1, alpha: 0.4)
    }

    private func addMcpReconnectButton(below aboveView: UIView) -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("重新连接ios-mcp", for: .normal)
        button.setTitleColor(UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.backgroundColor = UIColor(white: 1, alpha: 0.04)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(reconnectMcp), for: .touchUpInside)
        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            button.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: rowGap),
            button.heightAnchor.constraint(equalToConstant: 46)
        ])

        return button
    }

    @objc private func reconnectMcp() {
        StarCoreAgent.shared.reconnectMcp()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            let connected = StarCoreAgent.shared.getMcpStatus()
            self?.updateMcpStatusLabel(connected)
        }
    }

    // MARK: - Clear History

    private func addClearHistoryButton(below aboveView: UIView) -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("🗑 清空对话历史", for: .normal)
        button.setTitleColor(UIColor(red: 0xef/255, green: 0x44/255, blue: 0x44/255, alpha: 1.0), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.backgroundColor = UIColor(white: 1, alpha: 0.04)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(clearHistory), for: .touchUpInside)
        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            button.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: rowGap),
            button.heightAnchor.constraint(equalToConstant: 46)
        ])

        return button
    }

    @objc private func clearHistory() {
        let alert = UIAlertController(title: "确认清空", message: "确定要清空所有对话历史吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { _ in
            StarCoreAgent.shared.clearHistory()
        })
        present(alert, animated: true)
    }

    // MARK: - Version Info

    private func addVersionInfo(below aboveView: UIView) -> UIView {
        let label = UILabel()
        label.text = "星核 v10.3 | StarCore Native\n开箱即用 · 自研Tweak · Agent循环 · 记忆管理"
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = UIColor(white: 1, alpha: 0.3)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: updateButton.bottomAnchor, constant: 16)
        ])

        return label
    }

    // MARK: - Input Row Helper

    private func makeInputRow(placeholder: String, tag: Int, below aboveView: UIView) -> UIView {
        let rowView = UIView()
        rowView.backgroundColor = UIColor(white: 1, alpha: 0.04)
        rowView.layer.cornerRadius = 10
        rowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowView)

        let textField = UITextField()
        textField.placeholder = placeholder
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.25)]
        )
        textField.font = UIFont.systemFont(ofSize: 14)
        textField.textColor = .white
        textField.backgroundColor = UIColor(white: 1, alpha: 0.06)
        textField.layer.cornerRadius = 8
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        textField.tag = tag
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        textField.rightViewMode = .always
        textField.addTarget(self, action: #selector(inputFieldChanged(_:)), for: .editingDidEnd)
        rowView.addSubview(textField)

        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            rowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            rowView.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: rowGap),
            rowView.heightAnchor.constraint(equalToConstant: 46),

            textField.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -12),
            textField.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 34)
        ])

        return rowView
    }

    @objc private func inputFieldChanged(_ sender: UITextField) {
        // All config fields removed - reserved for future use
    }

    // MARK: - Refresh

    private func refreshUI() {
        updateTweakStatusLabel(StarCoreAgent.shared.getTweakStatus())
        updateMcpStatusLabel(StarCoreAgent.shared.getMcpStatus())
        updateKeyHintText()
    }

    // MARK: - Online Update (v10.3)

    @objc private func checkForUpdate() {
        let alert = UIAlertController(title: "检查更新", message: "正在检查最新版本...", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)

        guard let url = URL(string: "https://api.github.com/repos/WYT962464/StarCore/releases/latest") else { return }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let assets = json["assets"] as? [[String: Any]] else {
                    alert.message = "❌ 无法获取版本信息"
                    return
                }

                let currentVersion = "v10.3"
                if tagName == currentVersion || tagName <= currentVersion {
                    alert.message = "✅ 已是最新版本 (\(currentVersion))"
                    return
                }

                // 找到IPA下载链接
                let ipaAsset = assets.first { ($0["name"] as? String)?.hasSuffix(".ipa") == true }
                let downloadURL = ipaAsset?["browser_download_url"] as? String

                alert.message = "🆕 发现新版本 \(tagName)！\n\n当前: \(currentVersion)\n最新: \(tagName)"

                if let downloadURL = downloadURL, let url = URL(string: downloadURL) {
                    alert.addAction(UIAlertAction(title: "📥 下载更新", style: .default) { _ in
                        // 在Safari中打开下载链接，iOS会提示安装
                        if #available(iOS 10.0, *) {
                            UIApplication.shared.open(url, options: [:])
                        } else {
                            UIApplication.shared.openURL(url)
                        }
                    })
                }
            }
        }
        task.resume()
    }
}
