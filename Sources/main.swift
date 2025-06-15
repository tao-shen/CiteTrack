import Cocoa
import Foundation
import ServiceManagement

// MARK: - User Defaults Keys
extension UserDefaults {
    enum Keys {
        static let scholars = "Scholars"
        static let updateInterval = "UpdateInterval"
        static let showInDock = "ShowInDock"
        static let showInMenuBar = "ShowInMenuBar"
        static let launchAtLogin = "LaunchAtLogin"
    }
}

// MARK: - Scholar Model
struct Scholar: Codable, Identifiable {
    let id: String
    var name: String
    var citations: Int?
    var lastUpdated: Date?
    
    init(id: String, name: String = "") {
        self.id = id
        self.name = name.isEmpty ? "学者 \(id.prefix(8))" : name
        self.citations = nil
        self.lastUpdated = nil
    }
}

// MARK: - Google Scholar Service
class GoogleScholarService {
    enum ScholarError: Error, LocalizedError {
        case invalidURL
        case noData
        case parsingError
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的Google Scholar URL"
            case .noData:
                return "无法获取数据"
            case .parsingError:
                return "解析数据失败"
            case .networkError(let error):
                return "网络错误: \(error.localizedDescription)"
            }
        }
    }
    
    static func extractScholarId(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.contains("scholar.google.com") {
            let patterns = [
                #"user=([A-Za-z0-9_-]+)"#,
                #"citations\?user=([A-Za-z0-9_-]+)"#,
                #"profile/([A-Za-z0-9_-]+)"#
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.count)),
                   let range = Range(match.range(at: 1), in: trimmed) {
                    return String(trimmed[range])
                }
            }
        }
        
        if trimmed.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil {
            return trimmed
        }
        
        return nil
    }
    
    func fetchScholarInfo(for scholarId: String, completion: @escaping (Result<(name: String, citations: Int), ScholarError>) -> Void) {
        let urlString = "https://scholar.google.com/citations?user=\(scholarId)&hl=en"
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            self.parseScholarInfo(from: data, completion: completion)
        }.resume()
    }
    
    func fetchCitationCount(for scholarId: String, completion: @escaping (Result<Int, ScholarError>) -> Void) {
        fetchScholarInfo(for: scholarId) { result in
            switch result {
            case .success(let info):
                completion(.success(info.citations))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func parseScholarInfo(from data: Data, completion: @escaping (Result<(name: String, citations: Int), ScholarError>) -> Void) {
        guard let htmlString = String(data: data, encoding: .utf8) else {
            completion(.failure(.parsingError))
            return
        }
        
        // 解析学者姓名
        var scholarName = ""
        let namePatterns = [
            #"<div id="gsc_prf_in">([^<]+)</div>"#,
            #"<span id="gsc_prf_in">([^<]+)</span>"#,
            #"class="gsc_prf_in">([^<]+)<"#
        ]
        
        for pattern in namePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: htmlString, options: [], range: NSRange(location: 0, length: htmlString.count)),
               let range = Range(match.range(at: 1), in: htmlString) {
                scholarName = String(htmlString[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        // 解析引用量
        let citationPatterns = [
            #"Citations</a></td><td class="gsc_rsb_std">(\d+)</td>"#,
            #"Citations</a><td class="gsc_rsb_std">(\d+)</td>"#,
            #"总引用次数</a></td><td class="gsc_rsb_std">(\d+)</td>"#,
            #"被引次数</td><td[^>]*>(\d+)</td>"#,
            #"gsc_rsb_std">(\d+)</td>"#,
        ]
        
        for pattern in citationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: htmlString, options: [], range: NSRange(location: 0, length: htmlString.count)),
               let range = Range(match.range(at: 1), in: htmlString) {
                let citationString = String(htmlString[range])
                if let count = Int(citationString) {
                    let finalName = scholarName.isEmpty ? "未知学者" : scholarName
                    completion(.success((name: finalName, citations: count)))
                    return
                }
            }
        }
        
        completion(.failure(.parsingError))
    }
}

// MARK: - Preferences Manager
class PreferencesManager {
    static let shared = PreferencesManager()
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    var scholars: [Scholar] {
        get {
            guard let data = userDefaults.data(forKey: UserDefaults.Keys.scholars),
                  let scholars = try? JSONDecoder().decode([Scholar].self, from: data) else {
                return []
            }
            return scholars
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: UserDefaults.Keys.scholars)
            }
        }
    }
    
    var updateInterval: TimeInterval {
        get {
            let interval = userDefaults.double(forKey: UserDefaults.Keys.updateInterval)
            return interval > 0 ? interval : 86400 // 默认1天
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaults.Keys.updateInterval)
        }
    }
    
    var showInDock: Bool {
        get {
            if userDefaults.object(forKey: UserDefaults.Keys.showInDock) == nil {
                return true
            }
            return userDefaults.bool(forKey: UserDefaults.Keys.showInDock)
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaults.Keys.showInDock)
            updateActivationPolicy()
        }
    }
    
    var showInMenuBar: Bool {
        get {
            if userDefaults.object(forKey: UserDefaults.Keys.showInMenuBar) == nil {
                return true
            }
            return userDefaults.bool(forKey: UserDefaults.Keys.showInMenuBar)
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaults.Keys.showInMenuBar)
        }
    }
    
    var launchAtLogin: Bool {
        get {
            return userDefaults.bool(forKey: UserDefaults.Keys.launchAtLogin)
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaults.Keys.launchAtLogin)
            configureLaunchAtLogin(newValue)
        }
    }
    
    private func updateActivationPolicy() {
        DispatchQueue.main.async {
            if self.showInDock {
                NSApp.setActivationPolicy(.regular)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    private func configureLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            if enabled {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }
    
    func addScholar(_ scholar: Scholar) {
        var currentScholars = scholars
        if !currentScholars.contains(where: { $0.id == scholar.id }) {
            currentScholars.append(scholar)
            scholars = currentScholars
        }
    }
    
    func removeScholar(withId id: String) {
        var currentScholars = scholars
        currentScholars.removeAll { $0.id == id }
        scholars = currentScholars
    }
    
    func updateScholar(withId id: String, name: String? = nil, citations: Int? = nil) {
        var currentScholars = scholars
        if let index = currentScholars.firstIndex(where: { $0.id == id }) {
            if let name = name {
                currentScholars[index].name = name
            }
            if let citations = citations {
                currentScholars[index].citations = citations
                currentScholars[index].lastUpdated = Date()
            }
            scholars = currentScholars
        }
    }
}

// MARK: - Custom TextField with Copy/Paste Support
class EditableTextField: NSTextField {
    private let commandKey = NSEvent.ModifierFlags.command.rawValue
    private let commandShiftKey = NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == NSEvent.EventType.keyDown {
            if (event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue) == commandKey {
                switch event.charactersIgnoringModifiers! {
                case "x":
                    if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
                case "c":
                    if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
                case "v":
                    if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }
                case "z":
                    if NSApp.sendAction(Selector(("undo:")), to: nil, from: self) { return true }
                case "a":
                    if NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: self) { return true }
                default:
                    break
                }
            } else if (event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue) == commandShiftKey {
                if event.charactersIgnoringModifiers == "Z" {
                    if NSApp.sendAction(Selector(("redo:")), to: nil, from: self) { return true }
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Settings Window Controller
class SettingsWindowController: NSWindowController {
    private var scholars: [Scholar] = []
    private var tableView: NSTableView!
    private var updateIntervalPopup: NSPopUpButton!
    private var showInDockCheckbox: NSButton!
    private var showInMenuBarCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private let scholarService = GoogleScholarService()
    
    deinit {
        // 清理资源
    }
    
    override func loadWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 550),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CiteTrack - 设置"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        
        setupUI()
        loadData()
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        let contentView = NSView()
        window.contentView = contentView
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 20
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)
        
        // 学者管理区域
        let scholarSection = createScholarSection()
        mainStack.addArrangedSubview(scholarSection)
        
        // 设置区域
        let settingsSection = createSettingsSection()
        mainStack.addArrangedSubview(settingsSection)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func createScholarSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "学者管理")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowSizeStyle = .medium
        
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "姓名"
        nameColumn.width = 150
        tableView.addTableColumn(nameColumn)
        
        let idColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("id"))
        idColumn.title = "学者ID"
        idColumn.width = 200
        tableView.addTableColumn(idColumn)
        
        let citationsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("citations"))
        citationsColumn.title = "引用量"
        citationsColumn.width = 80
        tableView.addTableColumn(citationsColumn)
        
        tableView.dataSource = self
        tableView.delegate = self
        scrollView.documentView = tableView
        container.addSubview(scrollView)
        
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        let addButton = NSButton(title: "添加学者", target: self, action: #selector(addScholar))
        let removeButton = NSButton(title: "删除", target: self, action: #selector(removeScholar))
        let refreshButton = NSButton(title: "刷新数据", target: self, action: #selector(refreshData))
        
        addButton.bezelStyle = .rounded
        removeButton.bezelStyle = .rounded
        refreshButton.bezelStyle = .rounded
        
        buttonStack.addArrangedSubview(addButton)
        buttonStack.addArrangedSubview(removeButton)
        buttonStack.addArrangedSubview(refreshButton)
        buttonStack.addArrangedSubview(NSView()) // 弹簧
        
        container.addSubview(buttonStack)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 200),
            
            buttonStack.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 12),
            buttonStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            buttonStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createSettingsSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "应用设置")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let formStack = NSStackView()
        formStack.orientation = .vertical
        formStack.spacing = 16
        formStack.translatesAutoresizingMaskIntoConstraints = false
        
        // 更新频率
        let updateRow = createFormRow(
            label: "自动更新间隔:",
            control: {
                updateIntervalPopup = NSPopUpButton()
                updateIntervalPopup.addItem(withTitle: "30分钟")
                updateIntervalPopup.addItem(withTitle: "1小时")
                updateIntervalPopup.addItem(withTitle: "2小时")
                updateIntervalPopup.addItem(withTitle: "6小时")
                updateIntervalPopup.addItem(withTitle: "12小时")
                updateIntervalPopup.addItem(withTitle: "1天")
                updateIntervalPopup.addItem(withTitle: "3天")
                updateIntervalPopup.addItem(withTitle: "1周")
                updateIntervalPopup.target = self
                updateIntervalPopup.action = #selector(updateIntervalChanged)
                return updateIntervalPopup
            }()
        )
        formStack.addArrangedSubview(updateRow)
        
        // 显示选项
        let displaySection = createSectionTitle("显示选项")
        formStack.addArrangedSubview(displaySection)
        
        let dockRow = createCheckboxRow(
            label: "在Dock中显示:",
            checkbox: {
                showInDockCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(showInDockChanged))
                return showInDockCheckbox
            }()
        )
        formStack.addArrangedSubview(dockRow)
        
        let menuBarRow = createCheckboxRow(
            label: "在菜单栏中显示:",
            checkbox: {
                showInMenuBarCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(showInMenuBarChanged))
                return showInMenuBarCheckbox
            }()
        )
        formStack.addArrangedSubview(menuBarRow)
        
        // 启动选项
        let startupSection = createSectionTitle("启动选项")
        formStack.addArrangedSubview(startupSection)
        
        let launchRow = createCheckboxRow(
            label: "随系统启动:",
            checkbox: {
                launchAtLoginCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(launchAtLoginChanged))
                return launchAtLoginCheckbox
            }()
        )
        formStack.addArrangedSubview(launchRow)
        
        container.addSubview(formStack)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            formStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            formStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            formStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            formStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createFormRow(label: String, control: NSView) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = NSFont.systemFont(ofSize: 13)
        labelField.translatesAutoresizingMaskIntoConstraints = false
        
        control.translatesAutoresizingMaskIntoConstraints = false
        
        row.addSubview(labelField)
        row.addSubview(control)
        
        NSLayoutConstraint.activate([
            labelField.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            labelField.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            labelField.widthAnchor.constraint(equalToConstant: 120),
            
            control.leadingAnchor.constraint(equalTo: labelField.trailingAnchor, constant: 12),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            control.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor),
            
            row.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        return row
    }
    
    private func createSectionTitle(_ title: String) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        titleLabel.textColor = .secondaryLabelColor
        return titleLabel
    }
    
    private func createCheckboxRow(label: String, checkbox: NSButton) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = NSFont.systemFont(ofSize: 13)
        labelField.translatesAutoresizingMaskIntoConstraints = false
        
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        
        row.addSubview(labelField)
        row.addSubview(checkbox)
        
        NSLayoutConstraint.activate([
            labelField.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            labelField.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            labelField.widthAnchor.constraint(equalToConstant: 120),
            
            checkbox.leadingAnchor.constraint(equalTo: labelField.trailingAnchor, constant: 12),
            checkbox.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            checkbox.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor),
            
            row.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        return row
    }
    
    private func loadData() {
        scholars = PreferencesManager.shared.scholars
        tableView.reloadData()
        
        // 设置更新频率
        let interval = PreferencesManager.shared.updateInterval
        let index: Int
        switch interval {
        case 1800: index = 0   // 30分钟
        case 3600: index = 1   // 1小时
        case 7200: index = 2   // 2小时
        case 21600: index = 3  // 6小时
        case 43200: index = 4  // 12小时
        case 86400: index = 5  // 1天
        case 259200: index = 6 // 3天
        case 604800: index = 7 // 1周
        default: index = 5     // 默认1天
        }
        updateIntervalPopup.selectItem(at: index)
        
        // 设置显示选项
        showInDockCheckbox.state = PreferencesManager.shared.showInDock ? .on : .off
        showInMenuBarCheckbox.state = PreferencesManager.shared.showInMenuBar ? .on : .off
        launchAtLoginCheckbox.state = PreferencesManager.shared.launchAtLogin ? .on : .off
    }
    
    @objc private func addScholar() {
        // 使用简单的NSAlert方式，避免复杂的模态窗口管理
        let alert = NSAlert()
        alert.messageText = "添加学者"
        alert.informativeText = "请输入Google Scholar用户ID或完整链接"
        alert.addButton(withTitle: "添加")
        alert.addButton(withTitle: "取消")
        
        // 创建输入框
        let inputTextField = EditableTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputTextField.placeholderString = "例如：USER_ID 或完整链接"
        inputTextField.isEditable = true
        inputTextField.isSelectable = true
        inputTextField.usesSingleLineMode = true
        inputTextField.cell?.wraps = false
        inputTextField.cell?.isScrollable = true
        
        // 创建姓名输入框
        let nameTextField = EditableTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        nameTextField.placeholderString = "学者姓名（可选）"
        nameTextField.isEditable = true
        nameTextField.isSelectable = true
        nameTextField.usesSingleLineMode = true
        nameTextField.cell?.wraps = false
        nameTextField.cell?.isScrollable = true
        
        // 创建容器视图
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
        
        let idLabel = NSTextField(labelWithString: "Scholar ID或链接:")
        idLabel.frame = NSRect(x: 0, y: 50, width: 300, height: 20)
        idLabel.font = NSFont.systemFont(ofSize: 12)
        containerView.addSubview(idLabel)
        
        inputTextField.frame = NSRect(x: 0, y: 30, width: 300, height: 24)
        containerView.addSubview(inputTextField)
        
        let nameLabel = NSTextField(labelWithString: "姓名（可选）:")
        nameLabel.frame = NSRect(x: 0, y: 5, width: 300, height: 20)
        nameLabel.font = NSFont.systemFont(ofSize: 12)
        containerView.addSubview(nameLabel)
        
        nameTextField.frame = NSRect(x: 0, y: -15, width: 300, height: 24)
        containerView.addSubview(nameTextField)
        
        alert.accessoryView = containerView
        
        // 设置初始焦点
        alert.window.initialFirstResponder = inputTextField
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let input = inputTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let customName = nameTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if input.isEmpty {
                let errorAlert = NSAlert()
                errorAlert.messageText = "输入为空"
                errorAlert.informativeText = "请输入有效的Google Scholar用户ID或链接"
                errorAlert.runModal()
                return
            }
            
            if let scholarId = GoogleScholarService.extractScholarId(from: input) {
                // 检查是否已存在
                if scholars.contains(where: { $0.id == scholarId }) {
                    let existAlert = NSAlert()
                    existAlert.messageText = "学者已存在"
                    existAlert.informativeText = "该学者已在列表中"
                    existAlert.runModal()
                    return
                }
                
                // 立即获取学者信息
                scholarService.fetchScholarInfo(for: scholarId) { [weak self] result in
                    DispatchQueue.main.async {
                        guard let self = self, let _ = self.window else { return }
                        
                        switch result {
                        case .success(let info):
                            // 使用自定义姓名（如果提供）或从Google Scholar获取的姓名
                            let finalName = customName.isEmpty ? info.name : customName
                            let scholar = Scholar(id: scholarId, name: finalName)
                            PreferencesManager.shared.addScholar(scholar)
                            PreferencesManager.shared.updateScholar(withId: scholarId, citations: info.citations)
                            self.loadData()
                            NotificationCenter.default.post(name: NSNotification.Name("ScholarsUpdated"), object: nil)
                            
                            // 安全地显示成功消息
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                guard let _ = self.window else { return }
                                let successAlert = NSAlert()
                                successAlert.messageText = "添加成功"
                                successAlert.informativeText = "学者 \(finalName) 已添加，引用量：\(info.citations)"
                                successAlert.runModal()
                            }
                            
                        case .failure(let error):
                            // 使用自定义姓名或默认姓名
                            let finalName = customName.isEmpty ? "学者 \(scholarId.prefix(8))" : customName
                            let scholar = Scholar(id: scholarId, name: finalName)
                            PreferencesManager.shared.addScholar(scholar)
                            self.loadData()
                            NotificationCenter.default.post(name: NSNotification.Name("ScholarsUpdated"), object: nil)
                            
                            // 安全地显示错误消息
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                guard let _ = self.window else { return }
                                let errorAlert = NSAlert()
                                errorAlert.messageText = "获取学者信息失败"
                                errorAlert.informativeText = "学者已添加为 \(finalName)，但无法获取详细信息：\(error.localizedDescription)"
                                errorAlert.runModal()
                            }
                        }
                    }
                }
            } else {
                let errorAlert = NSAlert()
                errorAlert.messageText = "输入格式错误"
                errorAlert.informativeText = "请输入有效的Google Scholar用户ID或完整链接\n\n支持格式：\n• 直接输入用户ID\n• https://scholar.google.com/citations?user=USER_ID"
                errorAlert.runModal()
            }
        }
    }
    

    
    @objc private func removeScholar() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < scholars.count else {
            let alert = NSAlert()
            alert.messageText = "请选择要删除的学者"
            alert.runModal()
            return
        }
        
        let scholar = scholars[selectedRow]
        PreferencesManager.shared.removeScholar(withId: scholar.id)
        loadData()
        NotificationCenter.default.post(name: NSNotification.Name("ScholarsUpdated"), object: nil)
    }
    
    @objc private func refreshData() {
        // 立即刷新所有学者数据
        for scholar in scholars {
            scholarService.fetchScholarInfo(for: scholar.id) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self, let _ = self.window else { return }
                    
                    switch result {
                    case .success(let info):
                        PreferencesManager.shared.updateScholar(withId: scholar.id, name: info.name, citations: info.citations)
                        self.loadData()
                        NotificationCenter.default.post(name: NSNotification.Name("ScholarsUpdated"), object: nil)
                    case .failure(let error):
                        print("刷新学者 \(scholar.id) 失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    @objc private func updateIntervalChanged() {
        let intervals: [TimeInterval] = [1800, 3600, 7200, 21600, 43200, 86400, 259200, 604800]
        let selectedIndex = updateIntervalPopup.indexOfSelectedItem
        if selectedIndex >= 0 && selectedIndex < intervals.count {
            PreferencesManager.shared.updateInterval = intervals[selectedIndex]
            NotificationCenter.default.post(name: NSNotification.Name("UpdateIntervalChanged"), object: nil)
        }
    }
    
    @objc private func showInDockChanged() {
        PreferencesManager.shared.showInDock = showInDockCheckbox.state == .on
    }
    
    @objc private func showInMenuBarChanged() {
        PreferencesManager.shared.showInMenuBar = showInMenuBarCheckbox.state == .on
        NotificationCenter.default.post(name: NSNotification.Name("MenuBarVisibilityChanged"), object: nil)
    }
    
    @objc private func launchAtLoginChanged() {
        PreferencesManager.shared.launchAtLogin = launchAtLoginCheckbox.state == .on
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 隐藏窗口而不是关闭，避免重复创建
        sender.orderOut(nil)
        return false
    }
}

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return scholars.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let scholar = scholars[row]
        let cellView = NSTableCellView()
        
        let textField = NSTextField()
        textField.isEditable = false
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.font = NSFont.systemFont(ofSize: 13)
        
        switch tableColumn?.identifier.rawValue {
        case "name":
            textField.stringValue = scholar.name
        case "id":
            textField.stringValue = scholar.id
            textField.textColor = .secondaryLabelColor
        case "citations":
            if let citations = scholar.citations {
                textField.stringValue = "\(citations)"
                textField.alignment = .right
            } else {
                textField.stringValue = "--"
                textField.alignment = .right
                textField.textColor = .tertiaryLabelColor
            }
        default:
            textField.stringValue = ""
        }
        
        cellView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        return cellView
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarItem: NSStatusItem!
    private var menu: NSMenu!
    private var timer: Timer?
    private let scholarService = GoogleScholarService()
    private var settingsWindowController: SettingsWindowController?
    private var scholars: [Scholar] = []
    private var currentCitations: [String: Int] = [:]
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        updateActivationPolicy()
        setupNotifications()
        setupStatusBar()
        setupMenu()
        loadScholars()
        
        // 确保应用激活到前台
        NSApp.activate(ignoringOtherApps: true)
        
        if scholars.isEmpty {
            // 延迟一点显示首次设置，确保应用完全启动
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showFirstTimeSetup()
            }
        } else {
            startPeriodicUpdate()
            updateAllCitations()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // 清理定时器
        timer?.invalidate()
        timer = nil
        
        // 清理通知观察者
        NotificationCenter.default.removeObserver(self)
        
        // 清理设置窗口
        settingsWindowController?.window?.close()
        settingsWindowController = nil
        
        // 清理状态栏项
        if let statusBarItem = statusBarItem {
            NSStatusBar.system.removeStatusItem(statusBarItem)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 对于菜单栏应用，即使关闭所有窗口也不应该退出
        return false
    }
    
    private func updateActivationPolicy() {
        if PreferencesManager.shared.showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scholarsUpdated),
            name: NSNotification.Name("ScholarsUpdated"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateIntervalChanged),
            name: NSNotification.Name("UpdateIntervalChanged"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarVisibilityChanged),
            name: NSNotification.Name("MenuBarVisibilityChanged"),
            object: nil
        )
    }
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarDisplay()
    }
    
    private func updateMenuBarDisplay() {
        if !PreferencesManager.shared.showInMenuBar {
            statusBarItem.isVisible = false
            return
        }
        
        statusBarItem.isVisible = true
        
        if let button = statusBarItem.button {
            button.title = "∞"
            button.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
            button.toolTip = "CiteTrack - Google Scholar引用量监控"
        }
    }
    
    private func setupMenu() {
        menu = NSMenu()
        statusBarItem.menu = menu
        rebuildMenu()
    }
    
    private func rebuildMenu() {
        menu.removeAllItems()
        
        let titleItem = NSMenuItem(title: "CiteTrack", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        if scholars.isEmpty {
            let noScholarsItem = NSMenuItem(title: "暂无学者数据", action: nil, keyEquivalent: "")
            noScholarsItem.isEnabled = false
            menu.addItem(noScholarsItem)
        } else {
            for scholar in scholars {
                let citationText = currentCitations[scholar.id].map { "\($0)" } ?? "--"
                let title = "\(scholar.name): \(citationText)"
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let refreshItem = NSMenuItem(title: "手动更新", action: #selector(refreshCitations), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        let settingsItem = NSMenuItem(title: "偏好设置...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: "关于 CiteTrack", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    private func loadScholars() {
        scholars = PreferencesManager.shared.scholars
        // 更新当前引用量缓存
        for scholar in scholars {
            if let citations = scholar.citations {
                currentCitations[scholar.id] = citations
            }
        }
        rebuildMenu()
    }
    
    private func showFirstTimeSetup() {
        // 延迟显示首次设置，确保应用完全启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 确保应用在前台
            NSApp.activate(ignoringOtherApps: true)
            
            let alert = NSAlert()
            alert.messageText = "欢迎使用 CiteTrack"
            alert.informativeText = "这是一个精美专业的macOS菜单栏应用，用于实时监控您的Google Scholar引用量。\n\n小而精，专业可靠。\n\n请先添加学者信息来开始使用。"
            alert.addButton(withTitle: "打开设置")
            alert.addButton(withTitle: "稍后设置")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.showSettings()
            }
        }
    }
    
    private func startPeriodicUpdate() {
        timer?.invalidate()
        let interval = PreferencesManager.shared.updateInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.updateAllCitations()
        }
    }
    
    @objc private func refreshCitations() {
        updateAllCitations()
    }
    
    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.loadWindow()
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "CiteTrack"
        alert.informativeText = "版本 1.0\n\n一个精美专业的macOS菜单栏应用\n实时监控Google Scholar引用量\n\n小而精，专业可靠\n支持多学者监控，智能更新\n\n© 2024"
        alert.runModal()
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func scholarsUpdated() {
        loadScholars()
        if !scholars.isEmpty {
            startPeriodicUpdate()
            updateAllCitations()
        }
    }
    
    @objc private func updateIntervalChanged() {
        startPeriodicUpdate()
    }
    
    @objc private func menuBarVisibilityChanged() {
        updateMenuBarDisplay()
        updateActivationPolicy()
    }
    
    private func updateAllCitations() {
        guard !scholars.isEmpty else {
            rebuildMenu()
            return
        }
        
        for scholar in scholars {
            updateCitation(for: scholar)
        }
    }
    
    private func updateCitation(for scholar: Scholar) {
        scholarService.fetchCitationCount(for: scholar.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let count):
                    self.currentCitations[scholar.id] = count
                    PreferencesManager.shared.updateScholar(withId: scholar.id, citations: count)
                    self.rebuildMenu()
                case .failure(let error):
                    print("获取学者 \(scholar.id) 的引用量失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run() 