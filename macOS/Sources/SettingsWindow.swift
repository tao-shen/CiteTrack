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

// MARK: - Custom TableView with Keyboard Support
class ScholarTableView: NSTableView {
    weak var keyboardDelegate: ScholarTableViewKeyboardDelegate?
    
    override func keyDown(with event: NSEvent) {
        // 处理 Delete/Backspace 键
        if event.keyCode == 51 || event.keyCode == 117 { // Delete or Forward Delete
            keyboardDelegate?.tableViewDidPressDelete(self)
            return
        }
        
        // 处理 Command+A (全选)
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "a" {
            selectAll(nil)
            return
        }
        
        super.keyDown(with: event)
    }
}

protocol ScholarTableViewKeyboardDelegate: AnyObject {
    func tableViewDidPressDelete(_ tableView: NSTableView)
}

// MARK: - Settings Window Controller
class SettingsWindowController: NSWindowController {
    // UI Components
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
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = L("settings_title")
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 750, height: 550)
        
        self.window = window
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        // 使用原生 NSTabViewController
        let tabViewController = NSTabViewController()
        tabViewController.tabStyle = .toolbar
        
        // 通用设置
        let generalVC = NSViewController()
        generalVC.view = NSView()
        setupGeneralSettings(in: generalVC.view)
        let generalTab = NSTabViewItem(viewController: generalVC)
        generalTab.label = L("sidebar_general")
        if #available(macOS 11.0, *) {
            generalTab.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        }
        tabViewController.addTabViewItem(generalTab)
        
        // 学者管理
        let scholarsVC = NSViewController()
        scholarsVC.view = NSView()
        setupScholarManagement(in: scholarsVC.view)
        let scholarsTab = NSTabViewItem(viewController: scholarsVC)
        scholarsTab.label = L("sidebar_scholars")
        if #available(macOS 11.0, *) {
            scholarsTab.image = NSImage(systemSymbolName: "person.2", accessibilityDescription: nil)
        }
        tabViewController.addTabViewItem(scholarsTab)
        
        // 数据管理
        let dataVC = NSViewController()
        dataVC.view = NSView()
        setupDataManagementSection(in: dataVC.view)
        let dataTab = NSTabViewItem(viewController: dataVC)
        dataTab.label = L("sidebar_data")
        if #available(macOS 11.0, *) {
            dataTab.image = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: nil)
        }
        tabViewController.addTabViewItem(dataTab)
        
        window.contentViewController = tabViewController
    }
    
    // MARK: - Content Setup
    
    private func setupDataManagementSection(in parentView: NSView) {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // iCloud同步部分
        let iCloudSyncLabel = createSectionLabel(L("icloud_sync"))
        
        // iCloud Drive显示开关
        let iCloudDriveCheckbox = NSButton(checkboxWithTitle: L("show_in_icloud_drive"), target: self, action: #selector(toggleiCloudDriveFolder(_:)))
        iCloudDriveCheckbox.state = PreferencesManager.shared.iCloudDriveFolderEnabled ? .on : .off
        
        // 立即同步按钮和状态
        let syncNowButton = NSButton(title: L("sync_now"), target: self, action: #selector(performImmediateSync))
        syncNowButton.bezelStyle = .rounded
        
        let syncStatusLabel = NSTextField(labelWithString: iCloudSyncManager.shared.getSyncStatus())
        syncStatusLabel.textColor = .secondaryLabelColor
        syncStatusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        self.syncStatusLabel = syncStatusLabel
        
        let syncRow = NSStackView(views: [syncNowButton, syncStatusLabel])
        syncRow.orientation = .horizontal
        syncRow.spacing = 12
        
        // 数据管理部分
        let dataManagementLabel = createSectionLabel(L("data_management"))
        
        // 本地导入按钮
        let importButton = NSButton(title: L("manual_import_file"), target: self, action: #selector(importData))
        importButton.bezelStyle = .rounded
        
        // 导出到本地按钮
        let exportButton = NSButton(title: L("export_to_device"), target: self, action: #selector(exportData))
        exportButton.bezelStyle = .rounded
        
        // 垂直布局
        let stackView = NSStackView(views: [
            iCloudSyncLabel,
            iCloudDriveCheckbox,
            syncRow,
            NSView(), // 分隔
            dataManagementLabel,
            importButton,
            exportButton
        ])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])
        
        scrollView.documentView = contentView
        parentView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: parentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // 启动时检查iCloud状态
        updateiCloudStatus()
    }
    
    private var syncStatusLabel: NSTextField?
    
    private func createSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize + 1)
        label.textColor = .labelColor
        return label
    }
    
    private func createLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        return label
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
                    // 通知其他界面更新
                    NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
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
    
    @objc private func toggleiCloudDriveFolder(_ sender: NSButton) {
        let enabled = sender.state == .on
        PreferencesManager.shared.iCloudDriveFolderEnabled = enabled
        
        if enabled {
            // 用户开启时创建文件夹
            do {
                try iCloudSyncManager.shared.createiCloudFolder()
                print("✅ [Settings] iCloud文件夹创建成功")
            } catch {
                print("❌ [Settings] iCloud文件夹创建失败: \(error)")
                // 如果创建失败,将开关重置为关闭状态
                DispatchQueue.main.async {
                    sender.state = .off
                    PreferencesManager.shared.iCloudDriveFolderEnabled = false
                    self.showAlert(title: L("error"), message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func performImmediateSync() {
        // 若用户未开启在 iCloud Drive 中显示,则点击"立即同步"时自动开启
        if !PreferencesManager.shared.iCloudDriveFolderEnabled {
            PreferencesManager.shared.iCloudDriveFolderEnabled = true
            do {
                try iCloudSyncManager.shared.createiCloudFolder()
            } catch {
                print("⚠️ 创建iCloud文件夹失败: \(error)")
            }
        }
        
        syncStatusLabel?.stringValue = L("syncing")
        
        iCloudSyncManager.shared.exportUsingCloudKit { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.updateiCloudStatus()
                    self?.showAlert(title: L("sync_success_title"), message: L("sync_export_success_message"))
                case .failure(let error):
                    self?.syncStatusLabel?.stringValue = L("sync_failed")
                    self?.showAlert(title: L("sync_failed_title"), message: error.localizedDescription)
                }
            }
        }
    }
    
    private func updateiCloudStatus() {
        DispatchQueue.global(qos: .utility).async {
            let status = iCloudSyncManager.shared.getSyncStatus()
            DispatchQueue.main.async {
                self.syncStatusLabel?.stringValue = status
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
        // 创建更新间隔下拉菜单
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
        
        // 创建语言下拉菜单
        languagePopup = NSPopUpButton()
        setupLanguagePopup()
        
        // 创建复选框
        showInDockCheckbox = NSButton(checkboxWithTitle: L("setting_show_in_dock"), target: self, action: #selector(showInDockChanged))
        showInDockCheckbox.state = PreferencesManager.shared.showInDock ? .on : .off
        
        showInMenuBarCheckbox = NSButton(checkboxWithTitle: L("setting_show_in_menubar"), target: self, action: #selector(showInMenuBarChanged))
        showInMenuBarCheckbox.state = PreferencesManager.shared.showInMenuBar ? .on : .off
        
        launchAtLoginCheckbox = NSButton(checkboxWithTitle: L("setting_launch_at_login"), target: self, action: #selector(launchAtLoginChanged))
        launchAtLoginCheckbox.state = PreferencesManager.shared.launchAtLogin ? .on : .off
        
        let iCloudCheckbox = NSButton(checkboxWithTitle: L("setting_icloud_sync_enabled"), target: self, action: #selector(iCloudSyncToggled))
        iCloudCheckbox.state = PreferencesManager.shared.iCloudSyncEnabled ? .on : .off
        
        let iCloudButton = NSButton(title: L("button_open_folder"), target: self, action: #selector(openiCloudFolder))
        iCloudButton.bezelStyle = .rounded
        objc_setAssociatedObject(self, "iCloudFolderButton", iCloudButton, .OBJC_ASSOCIATION_RETAIN)
        
        // 使用 NSGridView 布局
        let gridView = NSGridView(views: [
            [createLabel(L("setting_update_interval")), updateIntervalPopup],
            [createLabel(L("setting_language")), languagePopup],
            [NSGridCell.emptyContentView, showInDockCheckbox],
            [NSGridCell.emptyContentView, showInMenuBarCheckbox],
            [NSGridCell.emptyContentView, launchAtLoginCheckbox],
            [NSGridCell.emptyContentView, iCloudCheckbox],
            [createLabel(L("setting_open_icloud_folder")), iCloudButton]
        ])
        
        gridView.translatesAutoresizingMaskIntoConstraints = false
        gridView.rowSpacing = 12
        gridView.columnSpacing = 16
        gridView.column(at: 0).xPlacement = .trailing
        gridView.column(at: 1).xPlacement = .leading
        
        parentView.addSubview(gridView)
        
        NSLayoutConstraint.activate([
            gridView.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 20),
            gridView.centerXAnchor.constraint(equalTo: parentView.centerXAnchor)
        ])
        
        // 更新 iCloud 状态
        updateiCloudStatus()
    }
    
    // MARK: - Scholar Management
    
    private func setupScholarManagement(in parentView: NSView) {
        let mainContainer = NSStackView()
        mainContainer.orientation = .vertical
        mainContainer.spacing = 8
        mainContainer.alignment = .leading
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(mainContainer)
        
        // 工具栏
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.alignment = .centerY
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addArrangedSubview(spacer)
        
        // 添加按钮
        let addButton = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: L("button_add"))!, target: self, action: #selector(addScholar))
        addButton.bezelStyle = .texturedRounded
        addButton.isBordered = true
        toolbar.addArrangedSubview(addButton)
        
        // 删除按钮
        let removeButton = NSButton(image: NSImage(systemSymbolName: "minus", accessibilityDescription: L("button_remove"))!, target: self, action: #selector(removeScholar))
        removeButton.bezelStyle = .texturedRounded
        removeButton.isBordered = true
        toolbar.addArrangedSubview(removeButton)
        
        // 分隔符
        let separator1 = NSBox()
        separator1.boxType = .separator
        separator1.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addArrangedSubview(separator1)
        NSLayoutConstraint.activate([
            separator1.widthAnchor.constraint(equalToConstant: 1),
            separator1.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // 上移按钮
        let moveUpButton = NSButton(image: NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "上移")!, target: self, action: #selector(moveScholarUp))
        moveUpButton.bezelStyle = .texturedRounded
        moveUpButton.isBordered = true
        toolbar.addArrangedSubview(moveUpButton)
        
        // 下移按钮
        let moveDownButton = NSButton(image: NSImage(systemSymbolName: "arrow.down", accessibilityDescription: "下移")!, target: self, action: #selector(moveScholarDown))
        moveDownButton.bezelStyle = .texturedRounded
        moveDownButton.isBordered = true
        toolbar.addArrangedSubview(moveDownButton)
        
        mainContainer.addArrangedSubview(toolbar)
        
        // 学者列表
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true
        
        tableView = ScholarTableView()
        (tableView as? ScholarTableView)?.keyboardDelegate = self
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.allowsColumnSelection = false
        tableView.style = .plain
        tableView.rowSizeStyle = .default
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.intercellSpacing = NSSize(width: 3, height: 2)
        
        // 启用拖拽排序
        tableView.registerForDraggedTypes([.string])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)
        
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
        mainContainer.addArrangedSubview(scrollView)
        
        NSLayoutConstraint.activate([
            mainContainer.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 20),
            mainContainer.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 20),
            mainContainer.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -20),
            mainContainer.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -20),
            
            toolbar.widthAnchor.constraint(equalTo: mainContainer.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: mainContainer.widthAnchor)
        ])
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
                // 通知更新
                NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
            }
        }
    }
    
    @objc private func removeScholar() {
        let selectedRows = tableView.selectedRowIndexes
        guard !selectedRows.isEmpty else { return }
        
        let alert = NSAlert()
        alert.messageText = selectedRows.count == 1 ? L("remove_scholar_title") : L("remove_scholars_title")
        alert.informativeText = selectedRows.count == 1 ? L("remove_scholar_message") : L("remove_scholars_message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("button_remove"))
        alert.addButton(withTitle: L("button_cancel"))
        
        if alert.runModal() == .alertFirstButtonReturn {
            // 从后往前删除，避免索引变化
            let sortedRows = selectedRows.sorted(by: >)
            for row in sortedRows {
                let scholar = scholars[row]
                PreferencesManager.shared.removeScholar(withId: scholar.id)
            }
            loadData()
            // 通知更新
            NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
        }
    }
    
    @objc private func moveScholarUp() {
        let selectedRow = tableView.selectedRow
        guard selectedRow > 0 else { return }
        
        // 交换位置
        scholars.swapAt(selectedRow, selectedRow - 1)
        PreferencesManager.shared.scholars = scholars
        
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: selectedRow - 1), byExtendingSelection: false)
        
        // 通知更新
        NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
    }
    
    @objc private func moveScholarDown() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < scholars.count - 1 else { return }
        
        // 交换位置
        scholars.swapAt(selectedRow, selectedRow + 1)
        PreferencesManager.shared.scholars = scholars
        
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: selectedRow + 1), byExtendingSelection: false)
        
        // 通知更新
        NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
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
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
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
        return 24
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
        guard let item = info.draggingPasteboard.pasteboardItems?.first,
              let rowString = item.string(forType: .string),
              let sourceRow = Int(rowString) else {
            return false
        }
        
        var destinationRow = row
        if sourceRow < destinationRow {
            destinationRow -= 1
        }
        
        // 移动学者
        let scholar = scholars.remove(at: sourceRow)
        scholars.insert(scholar, at: destinationRow)
        
        // 保存到 PreferencesManager
        PreferencesManager.shared.scholars = scholars
        
        // 刷新表格
        tableView.beginUpdates()
        tableView.moveRow(at: sourceRow, to: destinationRow)
        tableView.endUpdates()
        
        // 选中移动后的行
        tableView.selectRowIndexes(IndexSet(integer: destinationRow), byExtendingSelection: false)
        
        // 通知更新
        NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
        
        return true
    }
}

// MARK: - Keyboard Delegate
extension SettingsWindowController: ScholarTableViewKeyboardDelegate {
    func tableViewDidPressDelete(_ tableView: NSTableView) {
        removeScholar()
    }
} 