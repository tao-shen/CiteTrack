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
    private var tabView: NSTabView!
    private var tableView: NSTableView!
    private var scholars: [Scholar] = []
    private let googleScholarService = GoogleScholarService()
    private var updateIntervalPopup: NSPopUpButton!
    private var showInDockCheckbox: NSButton!
    private var showInMenuBarCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private var languagePopup: NSPopUpButton!
    // Charts functionality moved to separate window
    
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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = L("settings_title")
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 500, height: 400)
        
        self.window = window
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        // 清除现有内容
        window.contentView?.subviews.removeAll()
        
        let contentView = NSView()
        window.contentView = contentView
        
        // 创建标签视图
        tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.tabViewType = .topTabsBezelBorder
        contentView.addSubview(tabView)
        
        // 设置约束
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        setupGeneralTab()
        setupScholarTab()
        setupDataManagementTab()
        // Charts tab removed - now available as separate window from main menu
    }
    
    private func setupGeneralTab() {
        let generalTabItem = NSTabViewItem()
        generalTabItem.label = L("tab_general")
        
        let generalView = NSView()
        generalTabItem.view = generalView
        
        setupGeneralSettings(in: generalView)
        
        tabView.addTabViewItem(generalTabItem)
    }
    
    private func setupScholarTab() {
        let scholarTabItem = NSTabViewItem()
        scholarTabItem.label = L("tab_scholars")
        
        let scholarView = NSView()
        scholarTabItem.view = scholarView
        
        setupScholarManagement(in: scholarView)
        
        tabView.addTabViewItem(scholarTabItem)
    }
    
    private func setupDataManagementTab() {
        let dataTabItem = NSTabViewItem()
        dataTabItem.label = "Data"  // Will be localized
        
        let dataView = NSView()
        dataTabItem.view = dataView
        
        setupDataManagementSection(in: dataView)
        
        tabView.addTabViewItem(dataTabItem)
    }
    
    // Charts tab functionality moved to separate ChartsWindowController
    // Access via main menu > Charts
    
    private func setupDataManagementSection(in parentView: NSView) {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 16
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(stackView)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Data Management")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        stackView.addArrangedSubview(titleLabel)
        
        // Export section
        let exportButton = NSButton(title: "Export Data...", target: self, action: #selector(exportData))
        exportButton.bezelStyle = .rounded
        stackView.addArrangedSubview(exportButton)
        
        let exportLabel = NSTextField(labelWithString: "Export citation history to CSV or JSON file")
        exportLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        exportLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(exportLabel)
        
        stackView.addArrangedSubview(NSView()) // Spacer
        
        // Import section
        let importButton = NSButton(title: "Import Data...", target: self, action: #selector(importData))
        importButton.bezelStyle = .rounded
        stackView.addArrangedSubview(importButton)
        
        let importLabel = NSTextField(labelWithString: "Import data from backup file")
        importLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        importLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(importLabel)
        
        stackView.addArrangedSubview(NSView()) // Spacer
        
        // iCloud sync section
        let icloudLabel = NSTextField(labelWithString: "iCloud Sync")
        icloudLabel.font = NSFont.boldSystemFont(ofSize: 14)
        stackView.addArrangedSubview(icloudLabel)
        
        let syncToiCloudButton = NSButton(title: "Export to iCloud", target: self, action: #selector(syncToiCloud))
        syncToiCloudButton.bezelStyle = .rounded
        stackView.addArrangedSubview(syncToiCloudButton)
        
        let syncFromiCloudButton = NSButton(title: "Import from iCloud", target: self, action: #selector(syncFromiCloud))
        syncFromiCloudButton.bezelStyle = .rounded
        stackView.addArrangedSubview(syncFromiCloudButton)
        
        let icloudStatusLabel = NSTextField(labelWithString: iCloudSyncManager.shared.isiCloudAvailable ? "iCloud is available" : "iCloud is not available")
        icloudStatusLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        icloudStatusLabel.textColor = iCloudSyncManager.shared.isiCloudAvailable ? .systemGreen : .systemRed
        stackView.addArrangedSubview(icloudStatusLabel)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: parentView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: parentView.bottomAnchor, constant: -24)
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
                            self.showAlert(title: "Export Successful", message: "Data exported to \(url.lastPathComponent)")
                        } catch {
                            self.showAlert(title: "Export Failed", message: error.localizedDescription)
                        }
                    case .failure(let error):
                        self.showAlert(title: "Export Failed", message: error.localizedDescription)
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
        openPanel.message = "选择从iOS导出的数据文件（citation_data.json 或 ios_data.json）"
        
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.urls.first else { return }
            
            do {
                let data = try Data(contentsOf: url)
                let result = try DataManager.shared.importFromiOSData(jsonData: data)
                
                DispatchQueue.main.async(qos: .userInitiated) {
                    self.showAlert(
                        title: "导入成功",
                        message: "成功导入 \(result.importedScholars) 位学者和 \(result.importedHistory) 条历史记录"
                    )
                    self.loadData()
                }
            } catch {
                DispatchQueue.main.async(qos: .userInitiated) {
                    self.showAlert(title: "导入失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func syncToiCloud() {
        iCloudSyncManager.shared.exportUsingCloudKit { result in
            DispatchQueue.main.async(qos: .userInitiated) {
                switch result {
                case .success:
                    self.showAlert(title: "Sync Successful", message: "Data exported to iCloud successfully")
                case .failure(let error):
                    self.showAlert(title: "Sync Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func syncFromiCloud() {
        iCloudSyncManager.shared.importUsingCloudKit { result in
            DispatchQueue.main.async(qos: .userInitiated) {
                switch result {
                case .success:
                    self.showAlert(title: "Sync Successful", message: "Data imported from iCloud successfully")
                    self.loadData()
                case .failure(let error):
                    self.showAlert(title: "Sync Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        if let window = window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
    
    private func setupGeneralSettings(in parentView: NSView) {
        let settingsStack = NSStackView()
        settingsStack.orientation = .vertical
        settingsStack.spacing = 24
        settingsStack.alignment = .leading
        settingsStack.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(settingsStack)
        
        // Create organized sections with better spacing
        setupStartupSection(in: settingsStack)
        settingsStack.addArrangedSubview(createSeparator())
        setupAppSettingsSection(in: settingsStack)
        settingsStack.addArrangedSubview(createSeparator())
        setupDisplaySection(in: settingsStack)
        settingsStack.addArrangedSubview(createSeparator())
        setupiCloudSyncSection(in: settingsStack)
        
        // Set up constraints to fill the parent view properly
        NSLayoutConstraint.activate([
            settingsStack.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 24),
            settingsStack.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 24),
            settingsStack.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -24),
            settingsStack.bottomAnchor.constraint(lessThanOrEqualTo: parentView.bottomAnchor, constant: -24)
        ])
    }
    
    private func setupStartupSection(in stackView: NSStackView) {
        let sectionContainer = createSectionContainer()
        
        let titleLabel = createSectionTitle(L("section_startup_options"))
        sectionContainer.addArrangedSubview(titleLabel)
        
        let launchContainer = createImprovedSettingRow(
            label: L("setting_launch_at_login"),
            description: "Automatically start CiteTrack when you log in",
            control: {
                launchAtLoginCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(launchAtLoginChanged))
                launchAtLoginCheckbox.state = PreferencesManager.shared.launchAtLogin ? .on : .off
                return launchAtLoginCheckbox
            }()
        )
        sectionContainer.addArrangedSubview(launchContainer)
        
        stackView.addArrangedSubview(sectionContainer)
    }
    
    private func setupAppSettingsSection(in stackView: NSStackView) {
        let sectionContainer = createSectionContainer()
        
        let titleLabel = createSectionTitle(L("section_app_settings"))
        sectionContainer.addArrangedSubview(titleLabel)
        
        let updateIntervalContainer = createImprovedSettingRow(
            label: L("setting_update_interval"),
            description: "How often to automatically check for citation updates",
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
                
                let currentInterval = PreferencesManager.shared.updateInterval
                let index = intervalToIndex(currentInterval)
                updateIntervalPopup.selectItem(at: index)
                updateIntervalPopup.target = self
                updateIntervalPopup.action = #selector(updateIntervalChanged)
                return updateIntervalPopup
            }()
        )
        sectionContainer.addArrangedSubview(updateIntervalContainer)
        
        let languageContainer = createImprovedSettingRow(
            label: L("setting_language"),
            description: "Choose your preferred language for the interface",
            control: {
                languagePopup = NSPopUpButton()
                setupLanguagePopup()
                return languagePopup
            }()
        )
        sectionContainer.addArrangedSubview(languageContainer)
        
        stackView.addArrangedSubview(sectionContainer)
    }
    
    private func setupDisplaySection(in stackView: NSStackView) {
        let sectionContainer = createSectionContainer()
        
        let titleLabel = createSectionTitle(L("section_display_options"))
        sectionContainer.addArrangedSubview(titleLabel)
        
        let dockContainer = createImprovedSettingRow(
            label: L("setting_show_in_dock"),
            description: "Show CiteTrack icon in the Dock",
            control: {
                showInDockCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(showInDockChanged))
                showInDockCheckbox.state = PreferencesManager.shared.showInDock ? .on : .off
                return showInDockCheckbox
            }()
        )
        sectionContainer.addArrangedSubview(dockContainer)
        
        let menuBarContainer = createImprovedSettingRow(
            label: L("setting_show_in_menubar"),
            description: "Show CiteTrack icon in the menu bar",
            control: {
                showInMenuBarCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(showInMenuBarChanged))
                showInMenuBarCheckbox.state = PreferencesManager.shared.showInMenuBar ? .on : .off
                return showInMenuBarCheckbox
            }()
        )
        sectionContainer.addArrangedSubview(menuBarContainer)
        
        // Add Open Charts button
        let chartsContainer = createImprovedSettingRow(
            label: L("setting_open_charts"),
            description: "Open the charts window to view citation trends and statistics",
            control: {
                let openChartsButton = NSButton(title: L("button_open_charts"), target: self, action: #selector(openChartsWindow))
                openChartsButton.bezelStyle = .rounded
                return openChartsButton
            }()
        )
        sectionContainer.addArrangedSubview(chartsContainer)
        
        stackView.addArrangedSubview(sectionContainer)
    }
    
    private func setupiCloudSyncSection(in stackView: NSStackView) {
        let sectionContainer = createSectionContainer()
        
        let titleLabel = createSectionTitle(L("section_icloud_sync"))
        sectionContainer.addArrangedSubview(titleLabel)
        
        // iCloud sync checkbox
        let syncContainer = createImprovedSettingRow(
            label: L("setting_icloud_sync_enabled"),
            description: L("setting_icloud_sync_description"),
            control: {
                let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(iCloudSyncToggled))
                checkbox.state = PreferencesManager.shared.iCloudSyncEnabled ? .on : .off
                return checkbox
            }()
        )
        sectionContainer.addArrangedSubview(syncContainer)
        
        // iCloud status display
        let statusContainer = createiCloudStatusRow()
        sectionContainer.addArrangedSubview(statusContainer)
        
        // Open folder in Finder (enabled when iCloud is available)
        let folderContainer = createImprovedSettingRow(
            label: L("setting_open_icloud_folder"),
            description: L("setting_open_icloud_folder_description"),
            control: {
                let folderButton = NSButton(title: L("button_open_folder"), target: self, action: #selector(openiCloudFolder))
                folderButton.bezelStyle = .rounded
                
                // Store reference for later updates
                objc_setAssociatedObject(self, "iCloudFolderButton", folderButton, .OBJC_ASSOCIATION_RETAIN)
                
                return folderButton
            }()
        )
        sectionContainer.addArrangedSubview(folderContainer)
        
        stackView.addArrangedSubview(sectionContainer)
    }
    
    private func createiCloudStatusRow() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let statusLabel = NSTextField(labelWithString: L("setting_icloud_status"))
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .labelColor
        
        let statusValue = NSTextField(labelWithString: "Checking...")
        statusValue.translatesAutoresizingMaskIntoConstraints = false
        statusValue.font = NSFont.systemFont(ofSize: 11)
        statusValue.textColor = .secondaryLabelColor
        statusValue.lineBreakMode = .byWordWrapping
        statusValue.maximumNumberOfLines = 3
        statusValue.preferredMaxLayoutWidth = 300
        
        // Store reference for updates
        objc_setAssociatedObject(self, "iCloudStatusLabel", statusValue, .OBJC_ASSOCIATION_RETAIN)
        
        container.addSubview(statusLabel)
        container.addSubview(statusValue)
        
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            statusLabel.topAnchor.constraint(equalTo: container.topAnchor),
            statusLabel.widthAnchor.constraint(equalToConstant: 120),
            
            statusValue.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 16),
            statusValue.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            statusValue.topAnchor.constraint(equalTo: container.topAnchor),
            statusValue.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        
        // Update status immediately
        updateiCloudStatus()
        
        return container
    }
    
    private func createSectionContainer() -> NSStackView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 16
        container.alignment = .leading
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }
    
    private func createImprovedSettingRow(label: String, description: String, control: NSView) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let labelView = NSTextField(labelWithString: label)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        labelView.textColor = .labelColor
        
        let descriptionView = NSTextField(labelWithString: description)
        descriptionView.translatesAutoresizingMaskIntoConstraints = false
        descriptionView.font = NSFont.systemFont(ofSize: 11)
        descriptionView.textColor = .secondaryLabelColor
        descriptionView.lineBreakMode = .byWordWrapping
        descriptionView.maximumNumberOfLines = 2
        
        control.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(labelView)
        container.addSubview(descriptionView)
        container.addSubview(control)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            
            labelView.topAnchor.constraint(equalTo: container.topAnchor),
            labelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelView.widthAnchor.constraint(equalToConstant: 200),
            
            descriptionView.topAnchor.constraint(equalTo: labelView.bottomAnchor, constant: 4),
            descriptionView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            descriptionView.widthAnchor.constraint(equalToConstant: 200),
            descriptionView.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
            
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            control.leadingAnchor.constraint(equalTo: labelView.trailingAnchor, constant: 24),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        return container
    }
    
    private func setupScholarManagement(in parentView: NSView) {
        // 标题
        let titleLabel = NSTextField(labelWithString: L("section_scholar_management"))
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(titleLabel)
        
        // 创建表格视图
        let tableScrollView = NSScrollView()
        tableScrollView.translatesAutoresizingMaskIntoConstraints = false
        tableScrollView.hasVerticalScroller = true
        tableScrollView.hasHorizontalScroller = false
        tableScrollView.borderType = .bezelBorder
        
        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        tableView.rowSizeStyle = .medium
        
        // 启用拖拽排序
        tableView.registerForDraggedTypes([.string])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)
        
        // 添加列
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = L("scholar_name")
        nameColumn.width = 150
        nameColumn.minWidth = 100
        tableView.addTableColumn(nameColumn)
        
        let idColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("id"))
        idColumn.title = L("scholar_id")
        idColumn.width = 200
        idColumn.minWidth = 150
        tableView.addTableColumn(idColumn)
        
        let citationsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("citations"))
        citationsColumn.title = L("scholar_citations")
        citationsColumn.width = 100
        citationsColumn.minWidth = 80
        tableView.addTableColumn(citationsColumn)
        
        let lastUpdatedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lastUpdated"))
        lastUpdatedColumn.title = L("scholar_last_updated")
        lastUpdatedColumn.width = 120
        lastUpdatedColumn.minWidth = 100
        tableView.addTableColumn(lastUpdatedColumn)
        
        tableScrollView.documentView = tableView
        parentView.addSubview(tableScrollView)
        
        // 按钮容器
        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(buttonContainer)
        
        // 按钮
        let addButton = NSButton(title: L("button_add_scholar"), target: self, action: #selector(addScholar))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.bezelStyle = .rounded
        buttonContainer.addSubview(addButton)
        
        let removeButton = NSButton(title: L("button_remove"), target: self, action: #selector(removeScholar))
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.bezelStyle = .rounded
        buttonContainer.addSubview(removeButton)
        
        let refreshButton = NSButton(title: L("button_refresh"), target: self, action: #selector(refreshData))
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.bezelStyle = .rounded
        buttonContainer.addSubview(refreshButton)
        
        // 约束
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 20),
            
            tableScrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            tableScrollView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 20),
            tableScrollView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -20),
            tableScrollView.bottomAnchor.constraint(equalTo: buttonContainer.topAnchor, constant: -15),
            
            buttonContainer.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 20),
            buttonContainer.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -20),
            buttonContainer.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -20),
            buttonContainer.heightAnchor.constraint(equalToConstant: 40),
            
            addButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            addButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            addButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 10),
            removeButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            removeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            refreshButton.leadingAnchor.constraint(equalTo: removeButton.trailingAnchor, constant: 10),
            refreshButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            refreshButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }
    
    private func createSettingRow(label: String, control: NSView) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let labelView = NSTextField(labelWithString: label)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.alignment = .right
        labelView.font = NSFont.systemFont(ofSize: 13)
        
        control.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(labelView)
        container.addSubview(control)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 30),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 400),
            
            labelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelView.widthAnchor.constraint(equalToConstant: 180),
            
            control.leadingAnchor.constraint(equalTo: labelView.trailingAnchor, constant: 15),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            control.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])
        
        return container
    }
    
    private func createSectionTitle(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 25),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
    }
    
    private func createSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        return separator
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
            alert.messageText = "语言切换失败"
            alert.informativeText = "无法切换到所选语言，已恢复到之前的设置。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
    
    @objc private func addScholar() {
        let alert = NSAlert()
        alert.messageText = L("add_scholar_title")
        alert.informativeText = L("add_scholar_message")
        alert.addButton(withTitle: L("button_add"))
        alert.addButton(withTitle: L("button_cancel"))
        
        // 创建支持复制粘贴的输入字段
        let inputTextField = ValidatedTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputTextField.placeholderString = L("add_scholar_id_placeholder")
        inputTextField.isEditable = true
        inputTextField.isSelectable = true
        inputTextField.usesSingleLineMode = true
        inputTextField.cell?.wraps = false
        inputTextField.cell?.isScrollable = true
        
        let nameTextField = EditableTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        nameTextField.placeholderString = L("add_scholar_name_placeholder")
        nameTextField.isEditable = true
        nameTextField.isSelectable = true
        nameTextField.usesSingleLineMode = true
        nameTextField.cell?.wraps = false
        nameTextField.cell?.isScrollable = true
        
        // 创建容器视图
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 80))
        
        let idLabel = NSTextField(labelWithString: L("add_scholar_id_label"))
        idLabel.frame = NSRect(x: 0, y: 50, width: 150, height: 20)
        idLabel.alignment = .right
        
        inputTextField.frame = NSRect(x: 160, y: 50, width: 160, height: 24)
        
        let nameLabel = NSTextField(labelWithString: L("add_scholar_name_label"))
        nameLabel.frame = NSRect(x: 0, y: 20, width: 150, height: 20)
        nameLabel.alignment = .right
        
        nameTextField.frame = NSRect(x: 160, y: 20, width: 160, height: 24)
        
        containerView.addSubview(idLabel)
        containerView.addSubview(inputTextField)
        containerView.addSubview(nameLabel)
        containerView.addSubview(nameTextField)
        
        alert.accessoryView = containerView
        
        // 设置初始焦点到第一个输入框
        alert.window.initialFirstResponder = inputTextField
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let input = inputTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let customName = nameTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if input.isEmpty {
                let errorAlert = NSAlert()
                errorAlert.messageText = L("error_empty_input")
                errorAlert.informativeText = L("error_empty_input_message")
                errorAlert.runModal()
                return
            }
            
            // 进行详细的输入验证
            if input.count < 8 {
                let errorAlert = NSAlert()
                errorAlert.messageText = L("error_invalid_format")
                errorAlert.informativeText = "Scholar ID 至少需要8个字符。请输入完整的Google Scholar用户ID或链接。"
                errorAlert.runModal()
                return
            }
            
            if input.count > 100 {
                let errorAlert = NSAlert()
                errorAlert.messageText = L("error_invalid_format")
                errorAlert.informativeText = "输入内容过长。请输入有效的Google Scholar用户ID或链接。"
                errorAlert.runModal()
                return
            }
            
            guard let scholarId = GoogleScholarService.extractScholarId(from: input) else {
                let errorAlert = NSAlert()
                errorAlert.messageText = L("error_invalid_format")
                errorAlert.informativeText = L("error_invalid_format_message") + "\n\n输入的内容：\(input.prefix(50))..."
                errorAlert.runModal()
                return
            }
            
            // 检查是否已存在
            if scholars.contains(where: { $0.id == scholarId }) {
                let existAlert = NSAlert()
                existAlert.messageText = L("error_scholar_exists")
                existAlert.informativeText = L("error_scholar_exists_message")
                existAlert.runModal()
                return
            }
            
            // 获取学者信息
            googleScholarService.fetchScholarInfo(for: scholarId) { [weak self] result in
                DispatchQueue.main.async(qos: .userInitiated) {
                    guard let strongSelf = self else { return }
                    
                    switch result {
                    case .success(let info):
                        let finalName = customName.isEmpty ? info.name : customName
                        let scholar = Scholar(id: scholarId, name: finalName)
                        var updatedScholar = scholar
                        updatedScholar.citations = info.citations
                        updatedScholar.lastUpdated = Date()
                        
                        strongSelf.scholars.append(updatedScholar)
                        PreferencesManager.shared.scholars = strongSelf.scholars
                        strongSelf.tableView.reloadData()
                        
                        let successAlert = NSAlert()
                        successAlert.messageText = L("success_scholar_added")
                        successAlert.informativeText = L("success_scholar_added_message", finalName, info.citations)
                        successAlert.runModal()
                        
                    case .failure(let error):
                        let finalName = customName.isEmpty ? L("default_scholar_name", String(scholarId.prefix(8))) : customName
                        let scholar = Scholar(id: scholarId, name: finalName)
                        
                        strongSelf.scholars.append(scholar)
                        PreferencesManager.shared.scholars = strongSelf.scholars
                        strongSelf.tableView.reloadData()
                        
                        let errorAlert = NSAlert()
                        errorAlert.messageText = L("error_fetch_failed")
                        errorAlert.informativeText = L("error_fetch_failed_message", finalName, error.localizedDescription)
                        errorAlert.runModal()
                    }
                }
            }
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
        return scholars.count
    }
    
    // MARK: - Drag and Drop Support
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: .string)
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        var oldIndexes = [Int]()
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { draggingItem, _, _ in
            if let str = (draggingItem.item as! NSPasteboardItem).string(forType: .string), let index = Int(str) {
                oldIndexes.append(index)
            }
        }
        
        var oldIndexOffset = 0
        var newIndexOffset = 0
        
        // 移动学者数组中的项目
        for oldIndex in oldIndexes {
            if oldIndex < row {
                let scholar = scholars.remove(at: oldIndex + oldIndexOffset)
                scholars.insert(scholar, at: row - 1)
                oldIndexOffset -= 1
            } else {
                let scholar = scholars.remove(at: oldIndex)
                scholars.insert(scholar, at: row + newIndexOffset)
                newIndexOffset += 1
            }
        }
        
        // 保存更新后的学者列表
        PreferencesManager.shared.scholars = scholars
        
        // 重新加载表格
        tableView.reloadData()
        
        return true
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let scholar = scholars[row]
        let cellView = NSTableCellView()
        
        let textField = NSTextField()
        textField.isBordered = false
        textField.isEditable = false
        textField.backgroundColor = .clear
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = NSFont.systemFont(ofSize: 12)
        
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
} 