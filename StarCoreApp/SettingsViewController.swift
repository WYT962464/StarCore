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
        lastView = addSectionHeader("🤖 LLM Provider", below: lastView, isFirst: true)
        lastView = addProviderPicker(below: lastView)
        lastView = addAPIKeyField(below: lastView)
        lastView = addModelField(below: lastView)

        // Divider
        lastView = addDivider(below: lastView)

        // Section: Cloud Brain
        lastView = addSectionHeader("☁️ 云端超脑", below: lastView)
        lastView = addCloudBrainToggle(below: lastView)
        lastView = addCloudAPIUrlField(below: lastView)
        lastView = addCloudBotIdField(below: lastView)
        lastView = addCloudTokenField(below: lastView)

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

        // Section: Cloud Bridge (云控)
        lastView = addSectionHeader("🖥️ 云控桥接", below: lastView)
        lastView = addCloudBridgeToggle(below: lastView)
        lastView = addCloudBridgeServerUrlField(below: lastView)
        lastView = addCloudBridgeTokenField(below: lastView)
        lastView = addCloudBridgeTimeoutField(below: lastView)
        lastView = addCloudBridgeHealthButton(below: lastView)

        // Divider
        lastView = addDivider(below: lastView)

        // Section: Chat
        lastView = addSectionHeader("💬 对话", below: lastView)
        lastView = addModeSwitch(below: lastView)
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

    private var cloudToggle: UISwitch!

    private func addCloudBrainToggle(below aboveView: UIView) -> UIView {
        let (label, rowView) = addRow(label: "启用云端超脑", below: aboveView)

        cloudToggle = UISwitch()
        cloudToggle.isOn = StarCoreAgent.shared.cloudBrainConfig.enabled
        cloudToggle.onTintColor = UIColor(red: 0x25/255, green: 0x63/255, blue: 0xeb/255, alpha: 1.0)
        cloudToggle.translatesAutoresizingMaskIntoConstraints = false
        cloudToggle.addTarget(self, action: #selector(cloudToggleChanged(_:)), for: .valueChanged)
        rowView.addSubview(cloudToggle)

        NSLayoutConstraint.activate([
            cloudToggle.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -12),
            cloudToggle.centerYAnchor.constraint(equalTo: rowView.centerYAnchor)
        ])

        return rowView
    }

    @objc private func cloudToggleChanged(_ sender: UISwitch) {
        var config = StarCoreAgent.shared.cloudBrainConfig
        config.enabled = sender.isOn
        StarCoreAgent.shared.cloudBrainConfig = config
    }

    private func addCloudAPIUrlField(below aboveView: UIView) -> UIView {
        let rowView = makeInputRow(placeholder: "API地址", tag: 101, below: aboveView)
        (rowView.viewWithTag(101) as? UITextField)?.text = StarCoreAgent.shared.cloudBrainConfig.apiUrl
        return rowView
    }

    private func addCloudTokenField(below aboveView: UIView) -> UIView {
        let rowView = makeInputRow(placeholder: "PAT (个人访问令牌)", tag: 102, below: aboveView)
        (rowView.viewWithTag(102) as? UITextField)?.text = StarCoreAgent.shared.cloudBrainConfig.botToken
        return rowView
    }

    private func addCloudBotIdField(below aboveView: UIView) -> UIView {
        let rowView = makeInputRow(placeholder: "Bot ID", tag: 104, below: aboveView)
        (rowView.viewWithTag(104) as? UITextField)?.text = StarCoreAgent.shared.cloudBrainConfig.botId
        return rowView
    }

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

    // MARK: - Cloud Bridge Settings

    private var cloudBridgeToggle: UISwitch!
    private var cloudBridgeStatusLabel: UILabel!

    private func addCloudBridgeToggle(below aboveView: UIView) -> UIView {
        let (label, rowView) = addRow(label: "启用云控", below: aboveView)

        cloudBridgeToggle = UISwitch()
        cloudBridgeToggle.isOn = StarCoreAgent.shared.cloudBridgeConfig.enabled
        cloudBridgeToggle.onTintColor = UIColor(red: 0x25/255, green: 0x63/255, blue: 0xeb/255, alpha: 1.0)
        cloudBridgeToggle.translatesAutoresizingMaskIntoConstraints = false
        cloudBridgeToggle.addTarget(self, action: #selector(cloudBridgeToggleChanged(_:)), for: .valueChanged)
        rowView.addSubview(cloudBridgeToggle)

        NSLayoutConstraint.activate([
            cloudBridgeToggle.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -12),
            cloudBridgeToggle.centerYAnchor.constraint(equalTo: rowView.centerYAnchor)
        ])

        cloudBridgeStatusLabel = label
        updateCloudBridgeStatusLabel()

        return rowView
    }

    private func updateCloudBridgeStatusLabel() {
        let cfg = StarCoreAgent.shared.cloudBridgeConfig
        cloudBridgeStatusLabel?.text = cfg.enabled ? "启用云控 ✅" : "启用云控"
    }

    @objc private func cloudBridgeToggleChanged(_ sender: UISwitch) {
        var config = StarCoreAgent.shared.cloudBridgeConfig
        config.enabled = sender.isOn
        StarCoreAgent.shared.cloudBridgeConfig = config
        updateCloudBridgeStatusLabel()
    }

    private func addCloudBridgeServerUrlField(below aboveView: UIView) -> UIView {
        let rowView = makeInputRow(placeholder: "Server URL", tag: 201, below: aboveView)
        (rowView.viewWithTag(201) as? UITextField)?.text = StarCoreAgent.shared.cloudBridgeConfig.serverUrl
        return rowView
    }

    private func addCloudBridgeTokenField(below aboveView: UIView) -> UIView {
        let rowView = makeInputRow(placeholder: "Auth Token", tag: 202, below: aboveView)
        let field = rowView.viewWithTag(202) as? UITextField
        field?.isSecureTextEntry = true
        field?.text = StarCoreAgent.shared.cloudBridgeConfig.authToken
        return rowView
    }

    private func addCloudBridgeTimeoutField(below aboveView: UIView) -> UIView {
        let rowView = makeInputRow(placeholder: "超时(秒) 默认30", tag: 204, below: aboveView)
        let field = rowView.viewWithTag(204) as? UITextField
        field?.keyboardType = .numberPad
        field?.text = String(StarCoreAgent.shared.cloudBridgeConfig.timeoutSeconds)
        return rowView
    }

    private func addCloudBridgeHealthButton(below aboveView: UIView) -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("🏥 健康检查", for: .normal)
        button.setTitleColor(UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.backgroundColor = UIColor(white: 1, alpha: 0.04)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(cloudBridgeHealthCheck), for: .touchUpInside)
        contentView.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            button.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: rowGap),
            button.heightAnchor.constraint(equalToConstant: 46)
        ])

        return button
    }

    @objc private func cloudBridgeHealthCheck() {
        guard CloudBridgeClient.shared.isAvailable else {
            showAlert(title: "云桥未启用", message: "请先启用云控并填写Server URL和Auth Token")
            return
        }

        CloudBridgeClient.shared.healthCheck { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let health):
                    let msg = "状态: \(health.status)\n版本: \(health.version ?? "未知")\n运行时间: \(health.uptime.map { String(format: "%.0fs", $0) } ?? "未知")"
                    self?.showAlert(title: "✅ 云桥健康", message: msg)
                case .failure(let error):
                    self?.showAlert(title: "❌ 云桥异常", message: error.localizedDescription)
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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

    // MARK: - Mode Switch

    private var modeSegment: UISegmentedControl!

    private func addModeSwitch(below aboveView: UIView) -> UIView {
        let (label, rowView) = addRow(label: "对话模式", below: aboveView)

        modeSegment = UISegmentedControl(items: ["本地LLM", "云端超脑"])
        modeSegment.selectedSegmentIndex = StarCoreAgent.shared.isCloudMode ? 1 : 0
        modeSegment.translatesAutoresizingMaskIntoConstraints = false
        modeSegment.tintColor = UIColor(red: 0x25/255, green: 0x63/255, blue: 0xeb/255, alpha: 1.0)
        modeSegment.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        modeSegment.setTitleTextAttributes([.foregroundColor: UIColor(white: 1, alpha: 0.5)], for: .normal)
        modeSegment.backgroundColor = UIColor(white: 1, alpha: 0.08)
        modeSegment.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        rowView.addSubview(modeSegment)

        NSLayoutConstraint.activate([
            modeSegment.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -12),
            modeSegment.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            modeSegment.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12)
        ])

        return rowView
    }

    @objc private func modeChanged(_ sender: UISegmentedControl) {
        StarCoreAgent.shared.isCloudMode = (sender.selectedSegmentIndex == 1)
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
        label.text = "星核 v4.1 | StarCore Native\n双控架构 · 云控桥接 · Agent循环 · 记忆管理"
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
        switch sender.tag {
        case 101:
            var config = StarCoreAgent.shared.cloudBrainConfig
            config.apiUrl = sender.text ?? ""
            StarCoreAgent.shared.cloudBrainConfig = config
        case 102:
            var config = StarCoreAgent.shared.cloudBrainConfig
            config.botToken = sender.text ?? ""
            StarCoreAgent.shared.cloudBrainConfig = config
        case 104:
            var config = StarCoreAgent.shared.cloudBrainConfig
            config.botId = sender.text ?? ""
            StarCoreAgent.shared.cloudBrainConfig = config
        // Cloud Bridge fields
        case 201:
            var config = StarCoreAgent.shared.cloudBridgeConfig
            config.serverUrl = sender.text ?? ""
            StarCoreAgent.shared.cloudBridgeConfig = config
        case 202:
            var config = StarCoreAgent.shared.cloudBridgeConfig
            config.authToken = sender.text ?? ""
            StarCoreAgent.shared.cloudBridgeConfig = config
        case 203:
            var config = StarCoreAgent.shared.cloudBridgeConfig
            config.hmacSecret = sender.text ?? ""
            StarCoreAgent.shared.cloudBridgeConfig = config
        case 204:
            var config = StarCoreAgent.shared.cloudBridgeConfig
            config.timeoutSeconds = Int(sender.text ?? "30") ?? 30
            StarCoreAgent.shared.cloudBridgeConfig = config
        default:
            break
        }
    }

    // MARK: - Refresh

    private func refreshUI() {
        updateTweakStatusLabel(StarCoreAgent.shared.getTweakStatus())
        updateMcpStatusLabel(StarCoreAgent.shared.getMcpStatus())
    }
}
