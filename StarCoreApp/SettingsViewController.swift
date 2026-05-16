import UIKit

// MARK: - Settings View Controller (v10.3.1: 基于能跑的旧版结构，只留必要的)
class SettingsViewController: UIViewController {

    private var scrollView: UIScrollView!
    private var contentView: UIView!

    // MARK: - Section spacing constants (和旧版一致)
    private let sectionGap: CGFloat = 24
    private let rowGap: CGFloat = 10
    private let bottomPadding: CGFloat = 60

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
        lastView = addSectionHeader("🤖 LLM Provider", below: lastView, isFirst: true)
        lastView = addAPIKeyRow(below: lastView)
        lastView = addModelRow(below: lastView)

        // Divider
        lastView = addDivider(below: lastView)

        // Section: Tweak Connection
        lastView = addSectionHeader("🔧 Tweak连接", below: lastView)
        lastView = addTweakStatus(below: lastView)
        lastView = addReconnectButton(below: lastView)

        // Divider
        lastView = addDivider(below: lastView)

        // Section: iOS MCP
        lastView = addSectionHeader("📱 ios-mcp", below: lastView)
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

    // MARK: - Section Builder Helpers (和旧版完全一致)

    @discardableResult
    private func addSectionHeader(_ title: String, below aboveView: UIView, isFirst: Bool = false) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        label.textColor = UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        let topOffset: CGFloat = isFirst ? 20 : 0
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
    private func addRow(label text: String, below aboveView: UIView) -> (label: UILabel, rowView: UIView) {
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

    // MARK: - API Key Row

    private var apiKeyField: UITextField!

    private func addAPIKeyRow(below aboveView: UIView) -> UIView {
        let rowView = UIView()
        rowView.backgroundColor = UIColor(white: 1, alpha: 0.04)
        rowView.layer.cornerRadius = 10
        rowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowView)

        let titleLabel = UILabel()
        titleLabel.text = "API Key"
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.textColor = UIColor(white: 1, alpha: 0.8)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(titleLabel)

        apiKeyField = UITextField()
        apiKeyField.placeholder = "填入API Key"
        apiKeyField.attributedPlaceholder = NSAttributedString(
            string: "填入API Key",
            attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.25)]
        )
        apiKeyField.font = UIFont.systemFont(ofSize: 13)
        apiKeyField.textColor = .white
        apiKeyField.backgroundColor = UIColor(white: 1, alpha: 0.06)
        apiKeyField.layer.cornerRadius = 6
        apiKeyField.layer.borderWidth = 1
        apiKeyField.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        apiKeyField.autocapitalizationType = .none
        apiKeyField.autocorrectionType = .no
        apiKeyField.translatesAutoresizingMaskIntoConstraints = false
        apiKeyField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
        apiKeyField.leftViewMode = .always
        apiKeyField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
        apiKeyField.rightViewMode = .always
        apiKeyField.addTarget(self, action: #selector(apiKeyChanged), for: .editingDidEnd)
        rowView.addSubview(apiKeyField)

        // Safe access to current provider
        let provider = StarCoreAgent.shared.currentProvider
        apiKeyField.text = provider.apiKey

        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            rowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            rowView.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: rowGap),
            rowView.heightAnchor.constraint(equalToConstant: 46),

            titleLabel.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),

            apiKeyField.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            apiKeyField.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -8),
            apiKeyField.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            apiKeyField.heightAnchor.constraint(equalToConstant: 30)
        ])

        return rowView
    }

    // MARK: - Model Row

    private var modelField: UITextField!

    private func addModelRow(below aboveView: UIView) -> UIView {
        let rowView = UIView()
        rowView.backgroundColor = UIColor(white: 1, alpha: 0.04)
        rowView.layer.cornerRadius = 10
        rowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowView)

        let titleLabel = UILabel()
        titleLabel.text = "Endpoint"
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.textColor = UIColor(white: 1, alpha: 0.8)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(titleLabel)

        modelField = UITextField()
        modelField.placeholder = "ep-xxxx"
        modelField.attributedPlaceholder = NSAttributedString(
            string: "ep-xxxx",
            attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.25)]
        )
        modelField.font = UIFont.systemFont(ofSize: 13)
        modelField.textColor = .white
        modelField.backgroundColor = UIColor(white: 1, alpha: 0.06)
        modelField.layer.cornerRadius = 6
        modelField.layer.borderWidth = 1
        modelField.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        modelField.autocapitalizationType = .none
        modelField.autocorrectionType = .no
        modelField.translatesAutoresizingMaskIntoConstraints = false
        modelField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
        modelField.leftViewMode = .always
        modelField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
        modelField.rightViewMode = .always
        modelField.addTarget(self, action: #selector(modelChanged), for: .editingDidEnd)
        rowView.addSubview(modelField)

        let provider = StarCoreAgent.shared.currentProvider
        modelField.text = provider.model

        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            rowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            rowView.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: rowGap),
            rowView.heightAnchor.constraint(equalToConstant: 46),

            titleLabel.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),

            modelField.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            modelField.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -8),
            modelField.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            modelField.heightAnchor.constraint(equalToConstant: 30)
        ])

        return rowView
    }

    // MARK: - Tweak Status

    private var tweakStatusLabel: UILabel!

    private func addTweakStatus(below aboveView: UIView) -> UIView {
        let (label, rowView) = addRow(label: "Tweak状态", below: aboveView)
        tweakStatusLabel = label
        let connected = StarCoreAgent.shared.getTweakStatus()
        updateTweakStatusLabel(connected)
        return rowView
    }

    private func updateTweakStatusLabel(_ connected: Bool) {
        tweakStatusLabel?.text = connected ? "✅ 已连接" : "❌ 未连接"
        tweakStatusLabel?.textColor = connected ? UIColor(red: 0x4e/255, green: 0xca/255, blue: 0x80/255, alpha: 1) : UIColor(red: 0xf5/255, green: 0x9e/255, blue: 0x0b/255, alpha: 1)
    }

    private func addReconnectButton(below aboveView: UIView) -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("重新连接Tweak", for: .normal)
        button.setTitleColor(UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa, alpha: 1.0), for: .normal)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            let connected = StarCoreAgent.shared.getTweakStatus()
            self?.updateTweakStatusLabel(connected)
        }
    }

    // MARK: - MCP Status

    private var mcpStatusLabel: UILabel!

    private func addMcpStatus(below aboveView: UIView) -> UIView {
        let (label, rowView) = addRow(label: "ios-mcp状态", below: aboveView)
        mcpStatusLabel = label
        let connected = StarCoreAgent.shared.getMcpStatus()
        updateMcpStatusLabel(connected)
        return rowView
    }

    private func updateMcpStatusLabel(_ connected: Bool) {
        mcpStatusLabel?.text = connected ? "✅ 已连接" : "⚪ 未连接"
        mcpStatusLabel?.textColor = connected ? UIColor(red: 0x4e/255, green: 0xca/255, blue: 0x80/255, alpha: 1) : UIColor(white: 1, alpha: 0.4)
    }

    private func addMcpReconnectButton(below aboveView: UIView) -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("重新连接ios-mcp", for: .normal)
        button.setTitleColor(UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa, alpha: 1.0), for: .normal)
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
        label.text = "星核 v10.3.1 | 纯非流式20步Agent"
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = UIColor(white: 1, alpha: 0.3)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 16)
        ])

        return label
    }

    // MARK: - Actions

    @objc private func apiKeyChanged() {
        guard let text = apiKeyField?.text else { return }
        var providers = StarCoreAgent.shared.providers
        let idx = StarCoreAgent.shared.currentProviderIndex
        guard idx >= 0 && idx < providers.count else { return }
        providers[idx].apiKey = text
        StarCoreAgent.shared.providers = providers
    }

    @objc private func modelChanged() {
        guard let text = modelField?.text else { return }
        var providers = StarCoreAgent.shared.providers
        let idx = StarCoreAgent.shared.currentProviderIndex
        guard idx >= 0 && idx < providers.count else { return }
        providers[idx].model = text
        StarCoreAgent.shared.providers = providers
    }

    // MARK: - Refresh

    private func refreshUI() {
        updateTweakStatusLabel(StarCoreAgent.shared.getTweakStatus())
        updateMcpStatusLabel(StarCoreAgent.shared.getMcpStatus())
        if let provider = StarCoreAgent.shared.providers.first(where: { !$0.apiKey.isEmpty }) {
            apiKeyField?.text = provider.apiKey
            modelField?.text = provider.model
        }
    }
}
