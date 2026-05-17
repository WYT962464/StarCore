import UIKit

// MARK: - Memory View Controller (记忆 & 文件 Tab)
class MemoryViewController: UIViewController {

    // MARK: - Theme Colors
    private let bgDeep = UIColor(red: 10/255, green: 14/255, blue: 39/255, alpha: 1.0)
    private let cardBg = UIColor(red: 15/255, green: 20/255, blue: 50/255, alpha: 1.0)
    private let highlightColor = UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0)

    // MARK: - UI Components
    private var scrollView: UIScrollView!
    private var contentView: UIView!

    // Tweak status banner
    private var tweakBanner: UIView!
    private var tweakBannerLabel: UILabel!
    private var reconnectButton: UIButton!

    // Memory section
    private var searchBar: UISearchBar!
    private var memoryTableView: UITableView!
    private var searchResultsTableView: UITableView!
    private var memoryPathField: UITextField!

    // File browser section
    private var fileBrowserContainer: UIView!
    private var currentPathLabel: UILabel!
    private var fileTableView: UITableView!
    private var uploadButton: UIButton!
    private var screenshotButton: UIButton!

    // Data
    private var memoryFiles: [MemoryFileInfo] = []
    private var fileItems: [MemoryFileInfo] = []
    private var searchResults: [(fileName: String, lineNumber: Int, line: String)] = []
    private var isSearching = false
    private var currentBrowsePath: String = ""
    private var navigationStack: [String] = []

    private let memoryCellId = "MemoryCell"
    private let fileCellId = "FileCell"
    private let searchCellId = "SearchCell"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshData()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Data Refresh

    private func refreshData() {
        // Check Tweak connection first
        if !StarCoreAgent.shared.isTweakConnected {
            StarCoreAgent.shared.checkTweakConnection()
        StarCoreAgent.shared.checkMcpConnection()
        }

        // Small delay to let connection check complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateTweakBanner()
            self?.loadData()
        }
    }

    private func updateTweakBanner() {
        let tweakConnected = StarCoreAgent.shared.isTweakConnected
        // 也检查iOS MCP是否可用
        let mcpConnected = StarCoreAgent.shared.isMcpConnected
        let connected = tweakConnected || mcpConnected
        tweakBanner.backgroundColor = connected
            ? UIColor(red: 0x10/255, green: 0x60/255, blue: 0x30/255, alpha: 0.3)
            : UIColor(red: 0x60/255, green: 0x20/255, blue: 0x10/255, alpha: 0.3)
        tweakBannerLabel.text = connected
            ? "✅ Tweak已连接 — 文件读写正常"
            : "⚠️ Tweak和MCP均未连接 — 无法读写沙盒外文件，点击重连"
        reconnectButton.isHidden = connected
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = bgDeep
        title = "记忆 & 文件"
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]

        // Tweak status banner (pinned to top)
        tweakBanner = UIView()
        tweakBanner.translatesAutoresizingMaskIntoConstraints = false
        tweakBanner.layer.cornerRadius = 8
        view.addSubview(tweakBanner)

        tweakBannerLabel = UILabel()
        tweakBannerLabel.font = UIFont.systemFont(ofSize: 12)
        tweakBannerLabel.textColor = .white
        tweakBannerLabel.translatesAutoresizingMaskIntoConstraints = false
        tweakBanner.addSubview(tweakBannerLabel)

        reconnectButton = UIButton(type: .system)
        reconnectButton.setTitle("重连", for: .normal)
        reconnectButton.setTitleColor(highlightColor, for: .normal)
        reconnectButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        reconnectButton.translatesAutoresizingMaskIntoConstraints = false
        reconnectButton.addTarget(self, action: #selector(reconnectTweakTapped), for: .touchUpInside)
        tweakBanner.addSubview(reconnectButton)

        NSLayoutConstraint.activate([
            tweakBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            tweakBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            tweakBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            tweakBanner.heightAnchor.constraint(equalToConstant: 32),

            tweakBannerLabel.leadingAnchor.constraint(equalTo: tweakBanner.leadingAnchor, constant: 10),
            tweakBannerLabel.centerYAnchor.constraint(equalTo: tweakBanner.centerYAnchor),

            reconnectButton.trailingAnchor.constraint(equalTo: tweakBanner.trailingAnchor, constant: -10),
            reconnectButton.centerYAnchor.constraint(equalTo: tweakBanner.centerYAnchor)
        ])

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
            scrollView.topAnchor.constraint(equalTo: tweakBanner.bottomAnchor, constant: 4),
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

        // Section: Memory
        lastView = addSectionHeader("🧠 记忆区", below: lastView, isFirst: true)
        lastView = addMemoryPathRow(below: lastView)
        lastView = addSearchBar(below: lastView)
        lastView = addMemoryTable(below: lastView)
        lastView = addSearchResultsTable(below: lastView)

        // Divider
        lastView = addDivider(below: lastView)

        // Section: File Browser
        lastView = addSectionHeader("📁 文件区", below: lastView)
        lastView = addFileBrowserHeader(below: lastView)
        lastView = addFileActionButtons(below: lastView)
        lastView = addFileTable(below: lastView)

        // Bottom spacing
        contentView.bottomAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 80).isActive = true
    }

    // MARK: - Section Helpers

    @discardableResult
    private func addSectionHeader(_ title: String, below aboveView: UIView, isFirst: Bool = false) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = highlightColor
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        let topOffset: CGFloat = isFirst ? 16 : 0
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
            divider.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 20),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
        return divider
    }

    // MARK: - Memory Path Row

    private func addMemoryPathRow(below aboveView: UIView) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)

        let label = UILabel()
        label.text = "记忆路径"
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = UIColor(white: 1, alpha: 0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        memoryPathField = UITextField()
        memoryPathField.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        memoryPathField.textColor = .white
        memoryPathField.backgroundColor = UIColor(white: 1, alpha: 0.06)
        memoryPathField.layer.cornerRadius = 8
        memoryPathField.layer.borderWidth = 1
        memoryPathField.layer.borderColor = UIColor(white: 1, alpha: 0.1).cgColor
        memoryPathField.text = MemoryManager.shared.getMemoryPath()
        memoryPathField.translatesAutoresizingMaskIntoConstraints = false
        memoryPathField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
        memoryPathField.leftViewMode = .always
        memoryPathField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
        memoryPathField.rightViewMode = .always
        memoryPathField.addTarget(self, action: #selector(memoryPathEdited), for: .editingDidEnd)
        container.addSubview(memoryPathField)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            container.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 10),

            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor),

            memoryPathField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            memoryPathField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            memoryPathField.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6),
            memoryPathField.heightAnchor.constraint(equalToConstant: 36),
            memoryPathField.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    @objc private func memoryPathEdited() {
        if let path = memoryPathField.text, !path.isEmpty {
            MemoryManager.shared.updateMemoryPath(path)
            loadData()
        }
    }

    // MARK: - Search Bar

    private func addSearchBar(below aboveView: UIView) -> UIView {
        searchBar = UISearchBar()
        searchBar.placeholder = "搜索记忆文件内容..."
        searchBar.searchBarStyle = .minimal
        searchBar.barStyle = .black
        searchBar.tintColor = highlightColor
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            searchBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            searchBar.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 4)
        ])
        return searchBar
    }

    // MARK: - Memory Table

    private func addMemoryTable(below aboveView: UIView) -> UIView {
        memoryTableView = UITableView(frame: .zero, style: .plain)
        memoryTableView.translatesAutoresizingMaskIntoConstraints = false
        memoryTableView.separatorStyle = .none
        memoryTableView.backgroundColor = .clear
        memoryTableView.isScrollEnabled = false
        memoryTableView.delegate = self
        memoryTableView.dataSource = self
        memoryTableView.register(UITableViewCell.self, forCellReuseIdentifier: memoryCellId)
        contentView.addSubview(memoryTableView)

        let heightConstraint = memoryTableView.heightAnchor.constraint(equalToConstant: 200)
        heightConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            memoryTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            memoryTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            memoryTableView.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 4),
            heightConstraint
        ])
        return memoryTableView
    }

    // MARK: - Search Results Table

    private func addSearchResultsTable(below aboveView: UIView) -> UIView {
        searchResultsTableView = UITableView(frame: .zero, style: .plain)
        searchResultsTableView.translatesAutoresizingMaskIntoConstraints = false
        searchResultsTableView.separatorStyle = .none
        searchResultsTableView.backgroundColor = .clear
        searchResultsTableView.isScrollEnabled = false
        searchResultsTableView.isHidden = true
        searchResultsTableView.delegate = self
        searchResultsTableView.dataSource = self
        searchResultsTableView.register(UITableViewCell.self, forCellReuseIdentifier: searchCellId)
        contentView.addSubview(searchResultsTableView)

        let heightConstraint = searchResultsTableView.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            searchResultsTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchResultsTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            searchResultsTableView.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 0),
            heightConstraint
        ])
        return searchResultsTableView
    }

    // MARK: - File Browser Header

    private func addFileBrowserHeader(below aboveView: UIView) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)

        currentPathLabel = UILabel()
        currentPathLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        currentPathLabel.textColor = UIColor(white: 1, alpha: 0.5)
        currentPathLabel.numberOfLines = 0
        currentPathLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(currentPathLabel)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            container.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 8),

            currentPathLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            currentPathLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            currentPathLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            currentPathLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        return container
    }

    // MARK: - File Action Buttons

    private func addFileActionButtons(below aboveView: UIView) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)

        // Upload button
        uploadButton = makeActionButton(title: "📷 上传图片", color: UIColor(red: 0x25/255, green: 0x63/255, blue: 0xeb/255, alpha: 1.0))
        uploadButton.addTarget(self, action: #selector(uploadImageTapped), for: .touchUpInside)
        stackView.addArrangedSubview(uploadButton)

        // Screenshot button
        screenshotButton = makeActionButton(title: "📱 截图", color: UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0))
        screenshotButton.addTarget(self, action: #selector(screenshotTapped), for: .touchUpInside)
        stackView.addArrangedSubview(screenshotButton)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            container.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 8),

            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            stackView.heightAnchor.constraint(equalToConstant: 40)
        ])
        return container
    }

    private func makeActionButton(title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        button.backgroundColor = color.withAlphaComponent(0.2)
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1
        button.layer.borderColor = color.withAlphaComponent(0.4).cgColor
        return button
    }

    // MARK: - File Table

    private func addFileTable(below aboveView: UIView) -> UIView {
        fileTableView = UITableView(frame: .zero, style: .plain)
        fileTableView.translatesAutoresizingMaskIntoConstraints = false
        fileTableView.separatorStyle = .none
        fileTableView.backgroundColor = .clear
        fileTableView.isScrollEnabled = false
        fileTableView.delegate = self
        fileTableView.dataSource = self
        fileTableView.register(UITableViewCell.self, forCellReuseIdentifier: fileCellId)
        contentView.addSubview(fileTableView)

        let heightConstraint = fileTableView.heightAnchor.constraint(equalToConstant: 200)
        heightConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            fileTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            fileTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            fileTableView.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 8),
            heightConstraint
        ])
        return fileTableView
    }

    // MARK: - Data Loading

    private func loadData() {
        let rootPath = MemoryManager.shared.getMemoryPath()
        currentBrowsePath = rootPath
        navigationStack = []
        currentPathLabel.text = "📂 \(rootPath)"

        // 先检查Tweak连接
        if !StarCoreAgent.shared.isTweakConnected {
            StarCoreAgent.shared.checkTweakConnection()
        StarCoreAgent.shared.checkMcpConnection()
        }

        memoryFiles = MemoryManager.shared.listMemoryFiles()
        fileItems = MemoryManager.shared.listFiles(at: rootPath)

        // 调试信息
        let tweakOK = StarCoreAgent.shared.isTweakConnected
        print("[Memory] Tweak: \(tweakOK), memFiles: \(memoryFiles.count), fileItems: \(fileItems.count), path: \(rootPath)")

        if memoryFiles.isEmpty && fileItems.isEmpty {
            if !tweakOK {
                currentPathLabel.text = "⚠️ Tweak未连接，点击重试"
            } else {
                currentPathLabel.text = "📂 \(rootPath) (空目录或路径不存在)"
            }
        }

        memoryTableView.reloadData()
        fileTableView.reloadData()

        updateTableHeights()
    }

    private func updateTableHeights() {
        // Memory table
        let memHeight = CGFloat(max(memoryFiles.count, 1)) * 56.0
        memoryTableView.constraints.forEach { c in
            if c.firstAttribute == .height { c.constant = memHeight }
        }

        // Search results table
        if isSearching {
            let searchHeight = CGFloat(min(searchResults.count, 10)) * 60.0
            searchResultsTableView.constraints.forEach { c in
                if c.firstAttribute == .height { c.constant = searchHeight }
            }
        }

        // File table
        let fileHeight = CGFloat(max(fileItems.count, 1)) * 52.0
        fileTableView.constraints.forEach { c in
            if c.firstAttribute == .height { c.constant = fileHeight }
        }

        view.layoutIfNeeded()
    }

    // MARK: - Navigation

    private func navigateToDirectory(_ path: String) {
        navigationStack.append(currentBrowsePath)
        currentBrowsePath = path
        currentPathLabel.text = "📂 \(path)"
        fileItems = MemoryManager.shared.listFiles(at: path)
        fileTableView.reloadData()
        updateTableHeights()

        // Scroll to top
        scrollView.setContentOffset(.zero, animated: true)
    }

    private func navigateUp() {
        guard !navigationStack.isEmpty else { return }
        currentBrowsePath = navigationStack.removeLast()
        currentPathLabel.text = "📂 \(currentBrowsePath)"
        fileItems = MemoryManager.shared.listFiles(at: currentBrowsePath)
        fileTableView.reloadData()
        updateTableHeights()
    }

    // MARK: - File Viewing

    private func viewTextFile(at path: String) {
        let content = MemoryManager.shared.readFileContent(at: path)
        let viewer = FileViewerViewController()
        viewer.filePath = path
        viewer.fileContent = content
        viewer.title = (path as NSString).lastPathComponent
        navigationController?.pushViewController(viewer, animated: true)
    }

    private func viewImageFile(at path: String) {
        let viewer = ImageViewerViewController()
        viewer.imagePath = path
        viewer.title = (path as NSString).lastPathComponent
        navigationController?.pushViewController(viewer, animated: true)
    }

    // MARK: - Actions

    @objc private func reconnectTweakTapped() {
        reconnectButton.setTitle("⏳", for: .normal)
        reconnectButton.isEnabled = false
        StarCoreAgent.shared.checkTweakConnection()
        StarCoreAgent.shared.checkMcpConnection()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.reconnectButton.setTitle("重连", for: .normal)
            self?.reconnectButton.isEnabled = true
            self?.updateTweakBanner()
            self?.loadData()
        }
    }

    @objc private func uploadImageTapped() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }

    @objc private func screenshotTapped() {
        screenshotButton.isEnabled = false
        screenshotButton.setTitle("⏳ 截图中...", for: .normal)

        StarCoreAgent.shared.takeScreenshot { [weak self] filePath, error in
            guard let self = self else { return }
            self.screenshotButton.isEnabled = true
            self.screenshotButton.setTitle("📱 截图", for: .normal)

            if let filePath = filePath {
                // Refresh file list
                self.fileItems = MemoryManager.shared.listFiles(at: self.currentBrowsePath)
                self.fileTableView.reloadData()
                self.updateTableHeights()

                let alert = UIAlertController(
                    title: "截图成功",
                    message: "已保存到: \(filePath)",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "查看", style: .default) { _ in
                    self.viewImageFile(at: filePath)
                })
                alert.addAction(UIAlertAction(title: "好的", style: .cancel))
                self.present(alert, animated: true)
            } else {
                let alert = UIAlertController(
                    title: "截图失败",
                    message: error ?? "未知错误",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "好的", style: .cancel))
                self.present(alert, animated: true)
            }
        }
    }
}

// MARK: - UISearchBarDelegate

extension MemoryViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            searchResults = []
            searchResultsTableView.isHidden = true
            memoryTableView.isHidden = false
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text, !query.isEmpty else {
            isSearching = false
            searchResults = []
            searchResultsTableView.isHidden = true
            memoryTableView.isHidden = false
            return
        }

        isSearching = true
        searchResults = MemoryManager.shared.searchMemoryFiles(query: query)
        searchResultsTableView.isHidden = false
        memoryTableView.isHidden = true
        searchResultsTableView.reloadData()
        updateTableHeights()
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        isSearching = false
        searchResults = []
        searchResultsTableView.isHidden = true
        memoryTableView.isHidden = false
        searchBar.text = ""
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableView DataSource & Delegate

extension MemoryViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == memoryTableView {
            return max(memoryFiles.count, 1)
        } else if tableView == searchResultsTableView {
            return max(searchResults.count, 1)
        } else if tableView == fileTableView {
            // Add ".." entry if we can navigate up
            let extra = navigationStack.isEmpty ? 0 : 1
            return max(fileItems.count + extra, 1)
        }
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == memoryTableView {
            return configureMemoryCell(tableView, indexPath: indexPath)
        } else if tableView == searchResultsTableView {
            return configureSearchCell(tableView, indexPath: indexPath)
        } else {
            return configureFileCell(tableView, indexPath: indexPath)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if tableView == memoryTableView { return 56 }
        if tableView == searchResultsTableView { return 60 }
        return 52
    }

    // MARK: - Memory Cell

    private func configureMemoryCell(_ tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: memoryCellId, for: indexPath)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.selectionStyle = .none

        // Remove old subviews
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        if memoryFiles.isEmpty {
            let emptyLabel = UILabel()
            let tweakConnected = StarCoreAgent.shared.isTweakConnected
            emptyLabel.text = (tweakConnected || StarCoreAgent.shared.isMcpConnected) ? "📂 暂无记忆文件" : "⚠️ Tweak/MCP未连接，无法读取文件"
            emptyLabel.font = UIFont.systemFont(ofSize: 14)
            emptyLabel.textColor = UIColor(white: 1, alpha: 0.3)
            emptyLabel.textAlignment = .center
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(emptyLabel)
            NSLayoutConstraint.activate([
                emptyLabel.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                emptyLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
            ])
            return cell
        }

        let file = memoryFiles[indexPath.row]

        let cardView = UIView()
        cardView.backgroundColor = cardBg
        cardView.layer.cornerRadius = 10
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(cardView)

        let iconLabel = UILabel()
        iconLabel.text = "📄"
        iconLabel.font = UIFont.systemFont(ofSize: 18)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(iconLabel)

        let nameLabel = UILabel()
        nameLabel.text = file.name
        nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(nameLabel)

        let infoLabel = UILabel()
        infoLabel.text = "\(file.displaySize)  \(file.displayDate)"
        infoLabel.font = UIFont.systemFont(ofSize: 11)
        infoLabel.textColor = UIColor(white: 1, alpha: 0.4)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(infoLabel)

        let chevron = UILabel()
        chevron.text = "›"
        chevron.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        chevron.textColor = UIColor(white: 1, alpha: 0.3)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(chevron)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 4),
            cardView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -4),
            cardView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 2),
            cardView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -2),

            iconLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            iconLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            nameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),

            infoLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            infoLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10),

            chevron.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            chevron.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        ])

        return cell
    }

    // MARK: - Search Cell

    private func configureSearchCell(_ tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: searchCellId, for: indexPath)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.selectionStyle = .none

        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        if searchResults.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "🔍 未找到匹配内容"
            emptyLabel.font = UIFont.systemFont(ofSize: 14)
            emptyLabel.textColor = UIColor(white: 1, alpha: 0.3)
            emptyLabel.textAlignment = .center
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(emptyLabel)
            NSLayoutConstraint.activate([
                emptyLabel.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                emptyLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
            ])
            return cell
        }

        let result = searchResults[indexPath.row]

        let cardView = UIView()
        cardView.backgroundColor = cardBg
        cardView.layer.cornerRadius = 8
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(cardView)

        let fileLabel = UILabel()
        fileLabel.text = "📄 \(result.fileName):\(result.lineNumber)"
        fileLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        fileLabel.textColor = highlightColor
        fileLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(fileLabel)

        let lineLabel = UILabel()
        lineLabel.text = result.line
        lineLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        lineLabel.textColor = UIColor(white: 1, alpha: 0.7)
        lineLabel.numberOfLines = 2
        lineLabel.lineBreakMode = .byTruncatingTail
        lineLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(lineLabel)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 4),
            cardView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -4),
            cardView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 2),
            cardView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -2),

            fileLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            fileLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 8),
            fileLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),

            lineLabel.leadingAnchor.constraint(equalTo: fileLabel.leadingAnchor),
            lineLabel.trailingAnchor.constraint(equalTo: fileLabel.trailingAnchor),
            lineLabel.topAnchor.constraint(equalTo: fileLabel.bottomAnchor, constant: 4),
            lineLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -8)
        ])

        return cell
    }

    // MARK: - File Cell

    private func configureFileCell(_ tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: fileCellId, for: indexPath)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.selectionStyle = .none

        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        let hasParent = !navigationStack.isEmpty

        if fileItems.isEmpty && !hasParent {
            let emptyLabel = UILabel()
            emptyLabel.text = "📂 目录为空"
            emptyLabel.font = UIFont.systemFont(ofSize: 14)
            emptyLabel.textColor = UIColor(white: 1, alpha: 0.3)
            emptyLabel.textAlignment = .center
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(emptyLabel)
            NSLayoutConstraint.activate([
                emptyLabel.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                emptyLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
            ])
            return cell
        }

        // ".." row for going back up
        if hasParent && indexPath.row == 0 {
            let cardView = UIView()
            cardView.backgroundColor = UIColor(white: 1, alpha: 0.04)
            cardView.layer.cornerRadius = 8
            cardView.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(cardView)

            let icon = UILabel()
            icon.text = "⬆️"
            icon.font = UIFont.systemFont(ofSize: 16)
            icon.translatesAutoresizingMaskIntoConstraints = false
            cardView.addSubview(icon)

            let nameLabel = UILabel()
            nameLabel.text = ".. (上级目录)"
            nameLabel.font = UIFont.systemFont(ofSize: 13)
            nameLabel.textColor = UIColor(white: 1, alpha: 0.6)
            nameLabel.translatesAutoresizingMaskIntoConstraints = false
            cardView.addSubview(nameLabel)

            NSLayoutConstraint.activate([
                cardView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 4),
                cardView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -4),
                cardView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 1),
                cardView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -1),

                icon.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 10),
                icon.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),

                nameLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
                nameLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
            ])
            return cell
        }

        let adjustedRow = hasParent ? indexPath.row - 1 : indexPath.row
        guard adjustedRow >= 0 && adjustedRow < fileItems.count else { return cell }

        let file = fileItems[adjustedRow]

        let cardView = UIView()
        cardView.backgroundColor = UIColor(white: 1, alpha: 0.04)
        cardView.layer.cornerRadius = 8
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(cardView)

        let icon = UILabel()
        icon.text = file.isDirectory ? "📁" : iconForFile(file.name)
        icon.font = UIFont.systemFont(ofSize: 16)
        icon.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(icon)

        let nameLabel = UILabel()
        nameLabel.text = file.name
        nameLabel.font = UIFont.systemFont(ofSize: 13)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(nameLabel)

        let infoLabel = UILabel()
        infoLabel.text = file.isDirectory ? "\(fileItems.count) items" : "\(file.displaySize)  \(file.displayDate)"
        infoLabel.font = UIFont.systemFont(ofSize: 10)
        infoLabel.textColor = UIColor(white: 1, alpha: 0.35)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(infoLabel)

        let chevron = UILabel()
        chevron.text = file.isDirectory ? "›" : ""
        chevron.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        chevron.textColor = UIColor(white: 1, alpha: 0.3)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(chevron)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 4),
            cardView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -4),
            cardView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 1),
            cardView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -1),

            icon.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            nameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 8),

            infoLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            infoLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -8),

            chevron.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            chevron.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        ])

        return cell
    }

    private func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "md": return "📝"
        case "txt": return "📄"
        case "png", "jpg", "jpeg", "gif", "bmp": return "🖼"
        case "json": return "📋"
        case "py", "js", "swift", "sh": return "💻"
        case "mp4", "mov": return "🎬"
        case "mp3", "wav": return "🎵"
        default: return "📄"
        }
    }

    // MARK: - Cell Selection

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == memoryTableView {
            guard indexPath.row < memoryFiles.count else { return }
            let file = memoryFiles[indexPath.row]
            viewTextFile(at: file.path)
        } else if tableView == searchResultsTableView {
            guard indexPath.row < searchResults.count else { return }
            let result = searchResults[indexPath.row]
            // Find the full path for this file
            let rootPath = MemoryManager.shared.getMemoryPath()
            let possiblePaths = [
                (rootPath as NSString).appendingPathComponent(result.fileName),
                (rootPath as NSString).appendingPathComponent("基础设定/\(result.fileName)")
            ]
            for path in possiblePaths {
                let content = MemoryManager.shared.readFileContent(at: path)
                if !content.isEmpty {
                    viewTextFile(at: path)
                    return
                }
            }
        } else if tableView == fileTableView {
            let hasParent = !navigationStack.isEmpty

            // ".." row
            if hasParent && indexPath.row == 0 {
                navigateUp()
                return
            }

            let adjustedRow = hasParent ? indexPath.row - 1 : indexPath.row
            guard adjustedRow >= 0 && adjustedRow < fileItems.count else { return }

            let file = fileItems[adjustedRow]
            if file.isDirectory {
                navigateToDirectory(file.path)
            } else {
                let ext = (file.name as NSString).pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "gif", "bmp"].contains(ext) {
                    viewImageFile(at: file.path)
                } else {
                    viewTextFile(at: file.path)
                }
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate

extension MemoryViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else { return }

        let savedPath = MemoryManager.shared.saveUploadedImage(image: image, to: currentBrowsePath)
        if let path = savedPath {
            // Refresh
            fileItems = MemoryManager.shared.listFiles(at: currentBrowsePath)
            fileTableView.reloadData()
            updateTableHeights()

            let alert = UIAlertController(
                title: "上传成功",
                message: "已保存到: \(path)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "好的", style: .cancel))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(
                title: "上传失败",
                message: "图片保存失败，请检查目录权限",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "好的", style: .cancel))
            present(alert, animated: true)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - File Viewer Controller (Text + Edit/Save)

class FileViewerViewController: UIViewController {

    var filePath: String = ""
    var fileContent: String = ""

    private var textView: UITextView!
    private var pathLabel: UILabel!
    private var editButton: UIBarButtonItem!
    private var saveButton: UIBarButtonItem!
    private var isEditingFile = false
    private var originalContent: String = ""

    // Theme colors
    private let bgDeep = UIColor(red: 10/255, green: 14/255, blue: 39/255, alpha: 1.0)
    private let cardBg = UIColor(red: 15/255, green: 20/255, blue: 50/255, alpha: 1.0)
    private let highlightColor = UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgDeep

        originalContent = fileContent

        // Path label
        pathLabel = UILabel()
        pathLabel.text = filePath
        pathLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        pathLabel.textColor = UIColor(white: 1, alpha: 0.3)
        pathLabel.numberOfLines = 0
        pathLabel.translatesAutoresizingMaskIntoConstraints = false

        // Text view
        textView = UITextView()
        textView.backgroundColor = cardBg
        textView.textColor = .white
        textView.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isEditable = false
        textView.text = fileContent.isEmpty ? "（空文件或无法读取）" : fileContent
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.keyboardDismissMode = .interactive

        view.addSubview(pathLabel)
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            pathLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            pathLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            pathLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            textView.topAnchor.constraint(equalTo: pathLabel.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Navigation bar buttons
        editButton = UIBarButtonItem(title: "编辑", style: .plain, target: self, action: #selector(editTapped))
        editButton.tintColor = highlightColor

        saveButton = UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(saveTapped))
        saveButton.tintColor = UIColor(red: 0x34/255, green: 0xd3/255, blue: 0x99/255, alpha: 1.0)
        saveButton.isEnabled = false

        navigationItem.rightBarButtonItems = [editButton]
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    @objc private func editTapped() {
        if !isEditingFile {
            // Enter edit mode
            isEditingFile = true
            textView.isEditable = true
            textView.becomeFirstResponder()
            textView.layer.borderColor = highlightColor.withAlphaComponent(0.5).cgColor
            textView.layer.borderWidth = 1
            textView.layer.cornerRadius = 8
            editButton.title = "取消"
            saveButton.isEnabled = true
            navigationItem.rightBarButtonItems = [saveButton, editButton]
        } else {
            // Cancel edit mode — revert changes
            isEditingFile = false
            textView.isEditable = false
            textView.resignFirstResponder()
            textView.text = originalContent
            textView.layer.borderWidth = 0
            editButton.title = "编辑"
            saveButton.isEnabled = false
            navigationItem.rightBarButtonItems = [editButton]
        }
    }

    @objc private func saveTapped() {
        let newContent = textView.text ?? ""
        textView.isEditable = false
        textView.resignFirstResponder()
        textView.layer.borderWidth = 0

        // Show saving indicator
        saveButton.title = "⏳"
        saveButton.isEnabled = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let success = MemoryManager.shared.writeFile(content: newContent, to: self.filePath)

            DispatchQueue.main.async {
                if success {
                    self.originalContent = newContent
                    self.fileContent = newContent
                    self.isEditingFile = false
                    self.editButton.title = "编辑"
                    self.saveButton.title = "保存"
                    self.saveButton.isEnabled = false
                    self.navigationItem.rightBarButtonItems = [self.editButton]

                    // Brief success feedback
                    self.navigationItem.title = "✓ 已保存"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.navigationItem.title = (self.filePath as NSString).lastPathComponent
                    }
                } else {
                    // Save failed
                    self.isEditingFile = true
                    self.textView.isEditable = true
                    self.editButton.title = "取消"
                    self.saveButton.title = "保存"
                    self.saveButton.isEnabled = true
                    self.navigationItem.rightBarButtonItems = [self.saveButton, self.editButton]

                    let alert = UIAlertController(
                        title: "保存失败",
                        message: "无法写入文件。请确保Tweak已连接且有写入权限。",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "好的", style: .cancel))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

// MARK: - Image Viewer Controller

class ImageViewerViewController: UIViewController {

    var imagePath: String = ""

    private var scrollView: UIScrollView!
    private var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 10/255, green: 14/255, blue: 39/255, alpha: 1.0)

        scrollView = UIScrollView()
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 4.0
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        loadImage()
    }

    private func loadImage() {
        // Try loading from file path
        if let data = FileManager.default.contents(atPath: imagePath),
           let image = UIImage(data: data) {
            imageView.image = image
            return
        }

        // Fallback: try via Tweak
        let escapedPath = "'" + imagePath.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
        let base64Cmd = "base64 -i \(escapedPath) 2>/dev/null | head -c 100000"
        if let result = StarCoreAgent.shared.tweakCmd(action: "shell", params: ["command": base64Cmd]),
           let raw = result["output"] as? String,
           let data = Data(base64Encoded: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
           let image = UIImage(data: data) {
            imageView.image = image
            return
        }

        imageView.image = nil
        let label = UILabel()
        label.text = "无法加载图片"
        label.textColor = UIColor(white: 1, alpha: 0.4)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

extension ImageViewerViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}
