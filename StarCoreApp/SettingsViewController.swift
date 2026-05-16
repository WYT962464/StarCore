import UIKit

// MARK: - 设置页（极简版：API Key + Endpoint + 状态 + 清空）
class SettingsViewController: UIViewController {

    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var apiKeyField: UITextField!
    private var modelField: UITextField!
    private var tweakStatusLabel: UILabel!
    private var mcpStatusLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshUI()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func setupUI() {
        view.backgroundColor = UIColor(red: 10/255, green: 14/255, blue: 39/255, alpha: 1.0)
        title = "设置"
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]

        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
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

        // API Key
        lastView = addSectionTitle("🔑 API Key", below: lastView, isFirst: true)
        lastView = addTextField(placeholder: "填入火山方舟API Key", below: lastView, tag: 100)
        apiKeyField = (lastView as? UITextField)
        apiKeyField.text = StarCoreAgent.shared.currentProvider.apiKey
        apiKeyField.addTarget(self, action: #selector(apiKeyChanged), for: .editingDidEnd)

        // Model Endpoint
        lastView = addSectionTitle("📡 Model Endpoint", below: lastView)
        lastView = addTextField(placeholder: "ep-xxxx", below: lastView, tag: 200)
        modelField = (lastView as? UITextField)
        modelField.text = StarCoreAgent.shared.currentProvider.model
        modelField.addTarget(self, action: #selector(modelChanged), for: .editingDidEnd)

        // 连接状态
        lastView = addSectionTitle("🔗 连接状态", below: lastView)
        lastView = addStatusRow(title: "Tweak", below: lastView, labelOut: &tweakStatusLabel)
        lastView = addStatusRow(title: "ios-mcp", below: lastView, labelOut: &mcpStatusLabel)
        lastView = addButton(title: "重新检测连接", color: UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0), below: lastView, action: #selector(reconnect))

        // 清空对话
        lastView = addSectionTitle("💬 对话", below: lastView)
        lastView = addButton(title: "🗑 清空对话历史", color: UIColor(red: 0xef/255, green: 0x44/255, blue: 0x44/255, alpha: 1.0), below: lastView, action: #selector(clearHistory))

        // 版本号
        lastView = addVersionLabel(below: lastView)

        contentView.bottomAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 60).isActive = true
    }

    // MARK: - Builders

    @discardableResult
    private func addSectionTitle(_ text: String, below above: UIView, isFirst: Bool = false) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: above.topAnchor, constant: isFirst ? 20 : 24)
        ])
        return label
    }

    @discardableResult
    private func addTextField(placeholder: String, below above: UIView, tag: Int) -> UIView {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.25)])
        tf.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        tf.textColor = .white
        tf.backgroundColor = UIColor(white: 1, alpha: 0.06)
        tf.layer.cornerRadius = 10
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        tf.leftViewMode = .always
        tf.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        tf.rightViewMode = .always
        tf.tag = tag
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tf)
        NSLayoutConstraint.activate([
            tf.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tf.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            tf.topAnchor.constraint(equalTo: above.bottomAnchor, constant: 8),
            tf.heightAnchor.constraint(equalToConstant: 46)
        ])
        return tf
    }

    @discardableResult
    private func addStatusRow(title: String, below above: UIView, labelOut: inout UILabel) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.textColor = UIColor(white: 1, alpha: 0.7)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(titleLabel)

        let statusLabel = UILabel()
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(statusLabel)
        labelOut = statusLabel

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            row.topAnchor.constraint(equalTo: above.bottomAnchor, constant: 8),
            row.heightAnchor.constraint(equalToConstant: 36),
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    @discardableResult
    private func addButton(title: String, color: UIColor, below above: UIView, action: Selector) -> UIView {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(color, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        btn.backgroundColor = UIColor(white: 1, alpha: 0.04)
        btn.layer.cornerRadius = 10
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: action, for: .touchUpInside)
        contentView.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            btn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            btn.topAnchor.constraint(equalTo: above.bottomAnchor, constant: 4),
            btn.heightAnchor.constraint(equalToConstant: 40)
        ])
        return btn
    }

    @discardableResult
    private func addVersionLabel(below above: UIView) -> UIView {
        let label = UILabel()
        label.text = "星核 v10.3 | 纯非流式"
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor(white: 1, alpha: 0.2)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: above.bottomAnchor, constant: 24)
        ])
        return label
    }

    // MARK: - Actions

    @objc private func apiKeyChanged() {
        var providers = StarCoreAgent.shared.providers
        let idx = StarCoreAgent.shared.currentProviderIndex
        guard idx >= 0 && idx < providers.count else { return }
        providers[idx].apiKey = apiKeyField.text ?? ""
        StarCoreAgent.shared.providers = providers
    }

    @objc private func modelChanged() {
        var providers = StarCoreAgent.shared.providers
        let idx = StarCoreAgent.shared.currentProviderIndex
        guard idx >= 0 && idx < providers.count else { return }
        providers[idx].model = modelField.text ?? ""
        StarCoreAgent.shared.providers = providers
    }

    @objc private func reconnect() {
        StarCoreAgent.shared.reconnectTweak()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.refreshUI()
        }
    }

    @objc private func clearHistory() {
        let alert = UIAlertController(title: "确认", message: "清空所有对话？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { _ in StarCoreAgent.shared.clearHistory() })
        present(alert, animated: true)
    }

    private func refreshUI() {
        let tc = StarCoreAgent.shared.getTweakStatus()
        tweakStatusLabel?.text = tc ? "✅ 已连接" : "❌ 未连接"
        tweakStatusLabel?.textColor = tc ? UIColor(red: 0x4e/255, green: 0xca/255, blue: 0x80/255, alpha: 1) : UIColor(red: 0xf5/255, green: 0x9e/255, blue: 0x0b/255, alpha: 1)

        let mc = StarCoreAgent.shared.getMcpStatus()
        mcpStatusLabel?.text = mc ? "✅ 已连接" : "⚪ 未连接"
        mcpStatusLabel?.textColor = mc ? UIColor(red: 0x4e/255, green: 0xca/255, blue: 0x80/255, alpha: 1) : UIColor(white: 1, alpha: 0.4)

        apiKeyField?.text = StarCoreAgent.shared.currentProvider.apiKey
        modelField?.text = StarCoreAgent.shared.currentProvider.model
    }
}
