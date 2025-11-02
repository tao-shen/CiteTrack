import Cocoa
import Foundation

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

// MARK: - Validated TextField with Scholar ID Validation
class ValidatedTextField: EditableTextField {
    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        
        let text = self.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 实时验证输入
        if !text.isEmpty {
            if GoogleScholarService.extractScholarId(from: text) != nil {
                // 有效输入 - 使用绿色边框
                self.layer?.borderColor = NSColor.systemGreen.cgColor
                self.layer?.borderWidth = 1.0
            } else {
                // 无效输入 - 使用红色边框
                self.layer?.borderColor = NSColor.systemRed.cgColor
                self.layer?.borderWidth = 1.0
            }
        } else {
            // 清除边框
            self.layer?.borderWidth = 0.0
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.wantsLayer = true
        self.layer?.cornerRadius = 3.0
    }
}

// MARK: - Settings Window Controller
class SettingsWindowController: NSWindowController {
    // UI Components
    private var sidebarListView: NSTableView!
    private var contentContainerView: NSView!
    private var tableView: NSTableView!
    
    // Data
    private var scholars: [Scholar] = []
    private let googleScholarService = GoogleScholarService()
    
    // Controls
    private var updateIntervalPopup: NSPopUpButton!
    private var showInDockCheckbox: NSButton!
    private var showInMenuBarCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private var languagePopup: NSPopUpButton!
    
    // Sidebar items
    private enum SidebarItem: CaseIterable {
        case general
        case scholars
        case data
        
        var titleKey: String {
            switch self {
            case .general: return "sidebar_general"
            case .scholars: return "sidebar_scholars"
            case .data: return "sidebar_data"
            }
        }
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .scholars: return "person.2"
            case .data: return "externaldrive"
            }
        }
        
        var localizedTitle: String {
            return L(titleKey)
        }
    }
    
    private let sidebarItems: [SidebarItem] = SidebarItem.allCases
    private var selectedSidebarItem: SidebarItem = .general
    
    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
        setupUI()
        loadData()
        
        // 监听语言变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: .languageChanged,
            object: nil
        )
        
        // 监听语言切换失败
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChangeFailed(_:)),
            name: .languageChangeFailed,
            object: nil
        )
        
        // 监听学者数据更新
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scholarsDataUpdated),
            name: .scholarsDataUpdated,
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 540),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = L("settings_title")
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 680, height: 480)
        
        self.window = window
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        // 清除现有内容
        window.contentView?.subviews.removeAll()
        
        let contentView = NSView()
        window.contentView = contentView
        
        // 创建主分割视图
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(splitView)
        
        // 创建侧边栏
        let sidebarContainer = createSidebar()
        splitView.addArrangedSubview(sidebarContainer)
        
        // 创建内容区域
        contentContainerView = NSView()
        contentContainerView.translatesAutoresizingMaskIntoConstraints = false
        splitView.addArrangedSubview(contentContainerView)
        
        // 设置分割视图约束
        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: contentView.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // 侧边栏宽度
            sidebarContainer.widthAnchor.constraint(equalToConstant: 200)
        ])
        
        // 设置分割视图的优先级，防止侧边栏被压缩
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 0)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 1)
        
        // 所有UI创建完成后，显示默认内容并选择侧边栏第一项
        showContent(for: .general)
        // 使用 DispatchQueue 延迟选择，避免在初始化时触发通知
        DispatchQueue.main.async { [weak self] in
            self?.sidebarListView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
    
    // MARK: - Sidebar
    
    private func createSidebar() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建滚动视图
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        container.addSubview(scrollView)
        
        // 创建表格视图
        sidebarListView = NSTableView()
        sidebarListView.style = .sourceList
        sidebarListView.dataSource = self
        sidebarListView.delegate = self
        sidebarListView.headerView = nil
        sidebarListView.backgroundColor = .clear
        sidebarListView.selectionHighlightStyle = .sourceList
        sidebarListView.allowsEmptySelection = false
        sidebarListView.allowsMultipleSelection = false
        
        // 添加单列
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SidebarColumn"))
        column.width = 200
        sidebarListView.addTableColumn(column)
        
        scrollView.documentView = sidebarListView
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 52), // 为标题栏留空间
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // 不在这里选择，等待 setupUI 完成后再选择
        
        return container
    }
    
    private func showContent(for item: SidebarItem) {
        selectedSidebarItem = item
        
        // 确保 contentContainerView 已经创建
        guard let containerView = contentContainerView else { return }
        
        // 清除当前内容
        containerView.subviews.forEach { $0.removeFromSuperview() }
        
        // 创建滚动视图
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        containerView.addSubview(scrollView)
        
        // 创建内容视图
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 52), // 为标题栏留空间
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // 根据选择的项目显示内容
        switch item {
        case .general:
            setupGeneralSettings(in: contentView)
        case .scholars:
            setupScholarManagement(in: contentView)
        case .data:
            setupDataManagementSection(in: contentView)
        }
    }
    
    private func setupDataManagementSection(in parentView: NSView) {
        // 创建主容器
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 32
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(mainStack)
        
        // 导出数据
        let exportSection = createSimpleSection(title: L("section_data_export"), content: [
            createButtonRowModern(
                label: L("label_export_citation_data"),
                button: {
                    let button = NSButton(title: L("button_export_data") + "...", target: self, action: #selector(exportData))
                    button.bezelStyle = .rounded
                    button.font = NSFont.systemFont(ofSize: 13)
                    return button
                }()
            )
        ])
        mainStack.addArrangedSubview(exportSection)
        
        // 导入数据
        let importSection = createSimpleSection(title: L("section_data_import"), content: [
            createButtonRowModern(
                label: L("label_import_citation_data"),
                button: {
                    let button = NSButton(title: L("button_import") + "...", target: self, action: #selector(importData))
                    button.bezelStyle = .rounded
                    button.font = NSFont.systemFont(ofSize: 13)
                    return button
                }()
            )
        ])
        mainStack.addArrangedSubview(importSection)
        
        // 设置约束
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 40),
            mainStack.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -40),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: parentView.bottomAnchor, constant: -20)
        ])
    }
    
    
    @objc private func exportData() {
        let savePanel = NSSavePanel()
        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [.json, .commaSeparatedText]
        } else {
            savePanel.allowedFileTypes = ["json", "csv"]
        }
        savePanel.nameFieldStringValue = "CiteTrack_Export_\(Date().timeIntervalSince1970).json"
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            
            let format: ExportFormat = url.pathExtension.lowercased() == "csv" ? .csv : .json
            
            CitationHistoryManager.shared.exportAllHistory(format: format) { result in
                DispatchQueue.main.async(qos: .userInitiated) {
                    switch result {
                    case .success(let data):
                        do {
                            try data.write(to: url)
                            self.showAlert(
                                title: L("export_successful"),
                                message: L("export_successful_message", url.lastPathComponent, data.count)
                            )
                        } catch {
                            self.showAlert(title: L("export_failed"), message: error.localizedDescription)
                        }
                    case .failure(let error):
                        self.showAlert(title: L("export_failed"), message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    @objc private func importData() {
        let openPanel = NSOpenPanel()
        if #available(macOS 11.0, *) {
            openPanel.allowedContentTypes = [.json]
        } else {
            openPanel.allowedFileTypes = ["json"]
        }
        openPanel.allowsMultipleSelection = false
        openPanel.message = L("import_file_panel_message")
        
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.urls.first else { return }
            
            do {
                let data = try Data(contentsOf: url)
                let result = try DataManager.shared.importFromiOSData(jsonData: data)
                
                DispatchQueue.main.async(qos: .userInitiated) {
                    self.showAlert(
                        title: L("import_success_title"),
                        message: L("import_success_message", result.importedScholars, result.importedHistory)
                    )
                    self.loadData()
                }
            } catch {
                DispatchQueue.main.async(qos: .userInitiated) {
                    self.showAlert(title: L("import_failed_title"), message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func syncToiCloud() {
        iCloudSyncManager.shared.exportUsingCloudKit { result in
            DispatchQueue.main.async(qos: .userInitiated) {
                switch result {
                case .success:
                    self.showAlert(title: L("sync_success_title"), message: L("sync_export_success_message"))
                case .failure(let error):
                    self.showAlert(title: L("sync_failed_title"), message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func syncFromiCloud() {
        iCloudSyncManager.shared.importUsingCloudKit { result in
            DispatchQueue.main.async(qos: .userInitiated) {
                switch result {
                case .success:
                    self.showAlert(title: L("sync_success_title"), message: L("sync_import_success_message"))
                    self.loadData()
                case .failure(let error):
                    self.showAlert(title: L("sync_failed_title"), message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("button_ok"))
        if let window = window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
    
    private func setupGeneralSettings(in parentView: NSView) {
        // 创建主容器
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 32
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(mainStack)
        
        // 应用设置
        let appSection = createSimpleSection(title: L("section_app_settings"), content: [
            createSettingRowModern(
                label: L("setting_update_interval"),
                control: {
                    updateIntervalPopup = NSPopUpButton()
                    updateIntervalPopup.addItem(withTitle: L("interval_30min"))
                    updateIntervalPopup.addItem(withTitle: L("interval_1hour"))
                    updateIntervalPopup.addItem(withTitle: L("interval_2hours"))
                    updateIntervalPopup.addItem(withTitle: L("interval_6hours"))
                    updateIntervalPopup.addItem(withTitle: L("interval_12hours"))
                    updateIntervalPopup.addItem(withTitle: L("interval_1day"))
                    updateIntervalPopup.addItem(withTitle: L("interval_3days"))
                    updateIntervalPopup.addItem(withTitle: L("interval_1week"))
                    updateIntervalPopup.font = NSFont.systemFont(ofSize: 13)
                    let currentInterval = PreferencesManager.shared.updateInterval
                    let index = intervalToIndex(currentInterval)
                    updateIntervalPopup.selectItem(at: index)
                    updateIntervalPopup.target = self
                    updateIntervalPopup.action = #selector(updateIntervalChanged)
                    return updateIntervalPopup
                }()
            ),
            createSettingRowModern(
                label: L("setting_language"),
                control: {
                    languagePopup = NSPopUpButton()
                    languagePopup.font = NSFont.systemFont(ofSize: 13)
                    setupLanguagePopup()
                    return languagePopup
                }()
            )
        ])
        mainStack.addArrangedSubview(appSection)
        
        // 外观
        let appearanceSection = createSimpleSection(title: L("section_display_options"), content: [
            createCheckboxRowModern(
                label: L("setting_show_in_dock"),
                checkbox: {
                    showInDockCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(showInDockChanged))
                    showInDockCheckbox.state = PreferencesManager.shared.showInDock ? .on : .off
                    return showInDockCheckbox
                }()
            ),
            createCheckboxRowModern(
                label: L("setting_show_in_menubar"),
                checkbox: {
                    showInMenuBarCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(showInMenuBarChanged))
                    showInMenuBarCheckbox.state = PreferencesManager.shared.showInMenuBar ? .on : .off
                    return showInMenuBarCheckbox
                }()
            )
        ])
        mainStack.addArrangedSubview(appearanceSection)
        
        // 启动
        let startupSection = createSimpleSection(title: L("section_startup_options"), content: [
            createCheckboxRowModern(
                label: L("setting_launch_at_login"),
                checkbox: {
                    launchAtLoginCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(launchAtLoginChanged))
                    launchAtLoginCheckbox.state = PreferencesManager.shared.launchAtLogin ? .on : .off
                    return launchAtLoginCheckbox
                }()
            )
        ])
        mainStack.addArrangedSubview(startupSection)
        
        // iCloud 同步
        let iCloudSection = createSimpleSection(title: L("section_icloud_sync"), content: [
            createCheckboxRowModern(
                label: L("setting_icloud_sync_enabled"),
                checkbox: {
                    let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(iCloudSyncToggled))
                    checkbox.state = PreferencesManager.shared.iCloudSyncEnabled ? .on : .off
                    return checkbox
                }()
            ),
            createButtonRowModern(
                label: L("setting_open_icloud_folder"),
                button: {
                    let button = NSButton(title: L("button_open_folder"), target: self, action: #selector(openiCloudFolder))
                    button.bezelStyle = .rounded
                    button.font = NSFont.systemFont(ofSize: 13)
                    objc_setAssociatedObject(self, "iCloudFolderButton", button, .OBJC_ASSOCIATION_RETAIN)
                    return button
                }()
            )
        ])
        mainStack.addArrangedSubview(iCloudSection)
        
        // 设置约束
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 40),
            mainStack.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -40),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: parentView.bottomAnchor, constant: -20)
        ])
        
        // 更新 iCloud 状态
        updateiCloudStatus()
    }
    
    // MARK: - Modern UI Helpers
    
    private func createSimpleSection(title: String, content: [NSView]) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 12
        container.alignment = .leading
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // 标题
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        container.addArrangedSubview(titleLabel)
        
        // 内容
        for view in content {
            container.addArrangedSubview(view)
        }
        
        return container
    }
    
    private func createSettingRowModern(label: String, control: NSView) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let labelView = NSTextField(labelWithString: label)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.font = NSFont.systemFont(ofSize: 13)
        labelView.textColor = .labelColor
        labelView.alignment = .left
        
        control.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(labelView)
        container.addSubview(control)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 26),
            
            labelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelView.widthAnchor.constraint(equalToConstant: 200),
            
            control.leadingAnchor.constraint(equalTo: labelView.trailingAnchor, constant: 16),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            control.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])
        
        return container
    }
    
    private func createCheckboxRowModern(label: String, checkbox: NSButton) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.title = label
        checkbox.font = NSFont.systemFont(ofSize: 13)
        
        container.addSubview(checkbox)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 20),
            
            checkbox.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            checkbox.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            checkbox.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])
        
        return container
    }
    
    private func createButtonRowModern(label: String, button: NSButton) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let labelView = NSTextField(labelWithString: label)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.font = NSFont.systemFont(ofSize: 13)
        labelView.textColor = .labelColor
        
        button.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(labelView)
        container.addSubview(button)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 28),
            
            labelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelView.widthAnchor.constraint(equalToConstant: 200),
            
            button.leadingAnchor.constraint(equalTo: labelView.trailingAnchor, constant: 16),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
    }
    
    private func setupScholarManagement(in parentView: NSView) {
        // 创建主容器
        let mainContainer = NSStackView()
        mainContainer.orientation = .vertical
        mainContainer.spacing = 12
        mainContainer.alignment = .leading
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(mainContainer)
        
        // 顶部工具栏
        let toolbar = createScholarToolbarModern()
        mainContainer.addArrangedSubview(toolbar)
        
        // 学者列表区域
        let listContainer = createScholarListModern()
        mainContainer.addArrangedSubview(listContainer)
        
        // 设置约束
        NSLayoutConstraint.activate([
            mainContainer.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 20),
            mainContainer.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 40),
            mainContainer.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -40),
            mainContainer.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func createScholarToolbarModern() -> NSView {
        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(stack)
        
        // 弹性空间
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(spacer)
        
        // 添加按钮
        let addButton = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: L("button_add"))!, target: self, action: #selector(addScholar))
        addButton.bezelStyle = .texturedRounded
        addButton.isBordered = true
        stack.addArrangedSubview(addButton)
        
        // 删除按钮
        let removeButton = NSButton(image: NSImage(systemSymbolName: "minus", accessibilityDescription: L("button_remove"))!, target: self, action: #selector(removeScholar))
        removeButton.bezelStyle = .texturedRounded
        removeButton.isBordered = true
        stack.addArrangedSubview(removeButton)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: toolbar.topAnchor),
            stack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        return toolbar
    }
    
    private func createScholarListModern() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .lineBorder
        scrollView.autohidesScrollers = true
        
        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        tableView.style = .inset
        tableView.rowSizeStyle = .default
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.intercellSpacing = NSSize(width: 10, height: 4)
        
        // 添加列
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = L("scholar_name")
        nameColumn.width = 160
        nameColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(nameColumn)
        
        let idColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("id"))
        idColumn.title = L("scholar_id")
        idColumn.width = 180
        idColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(idColumn)
        
        let citationsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("citations"))
        citationsColumn.title = L("scholar_citations")
        citationsColumn.width = 100
        citationsColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(citationsColumn)
        
        let lastUpdatedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lastUpdated"))
        lastUpdatedColumn.title = L("scholar_last_updated")
        lastUpdatedColumn.width = 120
        lastUpdatedColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(lastUpdatedColumn)
        
        scrollView.documentView = tableView
        container.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    // MARK: - Scholar Management Actions
    @objc private func addScholar() {
        // 实现添加学者的逻辑
        let alert = NSAlert()
        alert.messageText = L("add_scholar_title")
        alert.informativeText = L("add_scholar_message")
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.placeholderString = L("scholar_id_placeholder")
        alert.accessoryView = inputField
        
        alert.addButton(withTitle: L("button_add"))
        alert.addButton(withTitle: L("button_cancel"))
        
        if alert.runModal() == .alertFirstButtonReturn {
            let scholarId = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !scholarId.isEmpty {
                // 添加学者的逻辑
                let newScholar = Scholar(id: scholarId)
                PreferencesManager.shared.addScholar(newScholar)
                loadData()
            }
        }
    }
    
    
    private func intervalToIndex(_ interval: TimeInterval) -> Int {
        switch interval {
        case 1800: return 0    // 30分钟
        case 3600: return 1    // 1小时
        case 7200: return 2    // 2小时
        case 21600: return 3   // 6小时
        case 43200: return 4   // 12小时
        case 86400: return 5   // 1天
        case 259200: return 6  // 3天
        case 604800: return 7  // 1周
        default: return 5      // 默认1天
        }
    }
    
    private func indexToInterval(_ index: Int) -> TimeInterval {
        switch index {
        case 0: return 1800    // 30分钟
        case 1: return 3600    // 1小时
        case 2: return 7200    // 2小时
        case 3: return 21600   // 6小时
        case 4: return 43200   // 12小时
        case 5: return 86400   // 1天
        case 6: return 259200  // 3天
        case 7: return 604800  // 1周
        default: return 86400  // 默认1天
        }
    }
    
    private func setupLanguagePopup() {
        languagePopup.removeAllItems()
        
        for language in LocalizationManager.shared.availableLanguages {
            languagePopup.addItem(withTitle: language.displayName)
            languagePopup.lastItem?.representedObject = language
        }
        
        let currentLanguage = LocalizationManager.shared.currentLanguageCode
        for i in 0..<languagePopup.numberOfItems {
            if let language = languagePopup.item(at: i)?.representedObject as? LocalizationManager.Language,
               language.rawValue == currentLanguage {
                languagePopup.selectItem(at: i)
                break
            }
        }
        
        languagePopup.target = self
        languagePopup.action = #selector(languageSelectionChanged(_:))
    }
    
    @objc private func languageChanged() {
        // 确保UI更新在主线程执行
        DispatchQueue.main.async(qos: .userInitiated) { [weak self] in
            guard let strongSelf = self else { return }
            
            // 重新设置窗口标题和UI文本
            strongSelf.window?.title = L("settings_title")
            // 重新构建语言下拉菜单以更新语言名称
            strongSelf.setupLanguagePopup()
            // 重新构建UI以更新所有文本
            strongSelf.setupUI()
            strongSelf.tableView?.reloadData()
        }
    }
    
    @objc private func languageSelectionChanged(_ sender: NSPopUpButton) {
        guard let language = sender.selectedItem?.representedObject as? LocalizationManager.Language else { return }
        LocalizationManager.shared.setLanguage(language)
    }
    
    @objc private func languageChangeFailed(_ notification: Notification) {
        DispatchQueue.main.async(qos: .userInitiated) { [weak self] in
            guard let strongSelf = self else { return }
            
            // 重置语言选择到之前的值
            strongSelf.setupLanguagePopup()
            
            // 显示错误提示
            let alert = NSAlert()
            alert.messageText = L("language_change_failed_title")
            alert.informativeText = L("language_change_failed_message")
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("button_ok"))
            alert.runModal()
        }
    }
    
    
    @objc private func removeScholar() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < scholars.count else {
            let alert = NSAlert()
            alert.messageText = L("error_no_selection")
            alert.runModal()
            return
        }
        
        scholars.remove(at: selectedRow)
        PreferencesManager.shared.scholars = scholars
        tableView.reloadData()
    }
    
    @objc private func refreshData() {
        let currentScholars = PreferencesManager.shared.scholars
        guard !currentScholars.isEmpty else { return }
        
        // 显示更新中状态
        showRefreshingState()
        
        // 使用同步队列保护共享变量
        let refreshQueue = DispatchQueue(label: "com.citetrack.refresh", attributes: .concurrent)
        var completedCount = 0
        var successCount = 0
        let totalCount = currentScholars.count
        
        for scholar in currentScholars {
            googleScholarService.fetchCitationCount(for: scholar.id) { [weak self] result in
                // 使用 barrier 确保线程安全的计数更新
                refreshQueue.async(flags: .barrier) {
                    completedCount += 1
                    
                    switch result {
                    case .success(let citations):
                        successCount += 1
                        // 在主线程更新PreferencesManager
                        DispatchQueue.main.async(qos: .userInitiated) {
                            PreferencesManager.shared.updateScholar(withId: scholar.id, citations: citations)
                        }
                        
                    case .failure(let error):
                        print("刷新学者 \(scholar.id) 失败: \(error.localizedDescription)")
                    }
                    
                    // 当所有请求完成时
                    if completedCount == totalCount {
                        DispatchQueue.main.async(qos: .userInitiated) {
                            guard let strongSelf = self else { return }
                            
                            // 重新加载本地数据
                            strongSelf.loadData()
                            
                            // 发送数据更新通知给其他组件
                            NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
                            
                            // 显示更新结果
                            strongSelf.showRefreshResult(success: successCount, total: totalCount)
                        }
                    }
                }
            }
        }
    }
    
    private func showRefreshingState() {
        // 可以在这里添加进度指示器或更新按钮状态
        // 暂时只在控制台输出
        print("正在刷新学者数据...")
    }
    
    private func showRefreshResult(success: Int, total: Int) {
        let message: String
        let style: NSAlert.Style
        
        if success == total {
            message = L("refresh_success_message", success)
            style = .informational
        } else {
            let failed = total - success
            message = L("refresh_partial_message", success, total, failed)
            style = .warning
        }
        
        let alert = NSAlert()
        alert.messageText = L("refresh_completed")
        alert.informativeText = message
        alert.alertStyle = style
        alert.runModal()
    }
    
    @objc private func updateIntervalChanged() {
        let selectedIndex = updateIntervalPopup.indexOfSelectedItem
        let interval = indexToInterval(selectedIndex)
        PreferencesManager.shared.updateInterval = interval
    }
    
    @objc private func showInDockChanged() {
        PreferencesManager.shared.showInDock = showInDockCheckbox.state == .on
        updateAppearance()
    }
    
    @objc private func showInMenuBarChanged() {
        PreferencesManager.shared.showInMenuBar = showInMenuBarCheckbox.state == .on
        updateAppearance()
    }
    
    @objc private func launchAtLoginChanged() {
        PreferencesManager.shared.launchAtLogin = launchAtLoginCheckbox.state == .on
    }
    
    @objc private func openChartsWindow() {
        // Close settings window first
        window?.close()
        
        // Create and show charts window
        let chartsWindowController = ChartsWindowController()
        chartsWindowController.showWindow(nil)
        
        // Keep reference to prevent deallocation
        NSApp.delegate?.perform(Selector(("setChartsWindowController:")), with: chartsWindowController)
    }
    
    // MARK: - iCloud Sync Actions
    
    @objc private func iCloudSyncToggled(_ sender: NSButton) {
        let isEnabled = sender.state == .on
        PreferencesManager.shared.iCloudSyncEnabled = isEnabled
        
        // Update UI state
        updateiCloudSyncUIState(enabled: isEnabled)
        
        if isEnabled {
            // Show initial sync dialog
            let alert = NSAlert()
            alert.messageText = L("icloud_sync_enabled_title")
            alert.informativeText = L("icloud_sync_enabled_message")
            alert.alertStyle = .informational
            alert.runModal()
            
            // Trigger initial sync
            iCloudSyncManager.shared.performInitialSync()
        } else {
            let alert = NSAlert()
            alert.messageText = L("icloud_sync_disabled_title")
            alert.informativeText = L("icloud_sync_disabled_message")
            alert.alertStyle = .informational
            alert.runModal()
        }
        
        // Update status display
        updateiCloudStatus()
    }
    
    private func updateiCloudSyncUIState(enabled: Bool) {
        // Update the folder button state
        // This is handled automatically when the checkbox changes
        print("ℹ️ iCloud sync UI state updated: \(enabled ? "enabled" : "disabled")")
    }
    
    @objc private func openiCloudFolder() {
        iCloudSyncManager.shared.openFolderInFinder()
        
        // Update status after folder operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updateiCloudStatus()
        }
    }
    
    private func updateiCloudStatus() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let status = iCloudSyncManager.shared.getFileStatus()
            
            DispatchQueue.main.async(qos: .userInitiated) {
                guard let statusLabel = objc_getAssociatedObject(self as Any, "iCloudStatusLabel") as? NSTextField else { return }
                statusLabel.stringValue = status.description
                
                // Update status label color
                if status.iCloudAvailable {
                    if status.isSyncEnabled {
                        statusLabel.textColor = .systemGreen
                    } else {
                        statusLabel.textColor = .labelColor
                    }
                } else {
                    statusLabel.textColor = .systemRed
                }
                
                // Update folder button state
                if let folderButton = objc_getAssociatedObject(self as Any, "iCloudFolderButton") as? NSButton {
                    folderButton.isEnabled = status.folderButtonEnabled
                }
            }
        }
    }
    
    // MARK: - Alert Helpers
    
    private func showProgressAlert(_ title: String, _ message: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        
        let progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.startAnimation(nil)
        progressIndicator.frame = NSRect(x: 0, y: 0, width: 32, height: 32)
        alert.accessoryView = progressIndicator
        
        alert.runModal()
        return alert
    }
    
    private func showSuccessAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    private func showErrorAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
    
    private func showInfoAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    @objc private func scholarsDataUpdated() {
        // 确保数据更新在主线程执行
        DispatchQueue.main.async(qos: .userInitiated) { [weak self] in
            self?.loadData()
        }
    }
    
    private func updateAppearance() {
        // Update appearance settings if needed
        // This method can be used for future appearance customizations
    }
    
    private func loadData() {
        // 确保这个方法总是在主线程调用
        assert(Thread.isMainThread, "loadData() must be called on the main thread")
        
        scholars = PreferencesManager.shared.scholars
        tableView?.reloadData()
    }
}

// MARK: - Table View Data Source & Delegate
extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        // 区分侧边栏和内容表格
        if tableView == sidebarListView {
            return sidebarItems.count
        } else {
            return scholars.count
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // 侧边栏
        if tableView == sidebarListView {
            let cellView = NSTableCellView()
            cellView.translatesAutoresizingMaskIntoConstraints = false
            
            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.spacing = 8
            stack.alignment = .centerY
            stack.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(stack)
            
            let item = sidebarItems[row]
            let localizedTitle = item.localizedTitle
            
            // 图标
            let iconView = NSImageView()
            iconView.image = NSImage(systemSymbolName: item.icon, accessibilityDescription: localizedTitle)
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.contentTintColor = .secondaryLabelColor
            stack.addArrangedSubview(iconView)
            
            // 文本
            let textField = NSTextField(labelWithString: localizedTitle)
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(textField)
            
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
                stack.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
                stack.topAnchor.constraint(equalTo: cellView.topAnchor),
                stack.bottomAnchor.constraint(equalTo: cellView.bottomAnchor),
                
                iconView.widthAnchor.constraint(equalToConstant: 20),
                iconView.heightAnchor.constraint(equalToConstant: 20)
            ])
            
            return cellView
        }
        
        // 学者列表
        let scholar = scholars[row]
        let cellView = NSTableCellView()
        
        let textField = NSTextField()
        textField.isBordered = false
        textField.isEditable = false
        textField.backgroundColor = .clear
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = NSFont.systemFont(ofSize: 13)
        
        cellView.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        switch tableColumn?.identifier.rawValue {
        case "name":
            textField.stringValue = scholar.name
        case "id":
            textField.stringValue = scholar.id
        case "citations":
            if let citations = scholar.citations {
                textField.stringValue = "\(citations)"
            } else {
                textField.stringValue = "-"
            }
        case "lastUpdated":
            if let lastUpdated = scholar.lastUpdated {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                textField.stringValue = formatter.string(from: lastUpdated)
            } else {
                textField.stringValue = L("never")
            }
        default:
            break
        }
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if tableView == sidebarListView {
            return 28
        }
        return 24
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        
        // 侧边栏选择变化
        if tableView == sidebarListView {
            let selectedRow = tableView.selectedRow
            guard selectedRow >= 0 && selectedRow < sidebarItems.count else { return }
            
            let selectedItem = sidebarItems[selectedRow]
            showContent(for: selectedItem)
        }
    }
} 