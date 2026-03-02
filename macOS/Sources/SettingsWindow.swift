import Cocoa
import Foundation
import ObjectiveC

// MARK: - Flipped View for ScrollView Content
class FlippedView: NSView {
    override var isFlipped: Bool {
        return true
    }
}

// MARK: - Custom Tab View Controller with Window Resize Support
class ResizableTabViewController: NSTabViewController {
    weak var windowController: SettingsWindowController?
    
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        
        // 通知窗口控制器调整窗口尺寸
        windowController?.adjustWindowSize(for: tabViewItem)
    }
}

// MARK: - Custom TextField with Copy/Paste Support
class EditableTextField: NSTextField {
    private let commandKey = NSEvent.ModifierFlags.command.rawValue
    private let commandShiftKey = NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == NSEvent.EventType.keyDown {
            guard let characters = event.charactersIgnoringModifiers else {
                return super.performKeyEquivalent(with: event)
            }
            if (event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue) == commandKey {
                switch characters {
                case "x":
                    if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
                case "c":
                    if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
                case "v":
                    if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }
                case "z":
                    if let undoManager = self.undoManager, undoManager.canUndo {
                        undoManager.undo()
                        return true
                    }
                case "a":
                    if NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: self) { return true }
                default:
                    break
                }
            } else if (event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue) == commandShiftKey {
                if characters == "Z" {
                    if let undoManager = self.undoManager, undoManager.canRedo {
                        undoManager.redo()
                        return true
                    }
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
    
    // Add Scholar Dialog
    private var addScholarDialogWindow: NSWindow?
    private var addScholarInputField: NSTextField?
    
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
        // 获取屏幕尺寸
        guard let screen = NSScreen.main else {
            // 如果无法获取屏幕，使用默认尺寸
        let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 550, height: 500),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = L("settings_title")
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 500, height: 450)
            self.window = window
            return
        }
        
        let screenSize = screen.visibleFrame.size
        // 根据屏幕尺寸计算合适的窗口大小（屏幕的 40-50%）
        let preferredWidth: CGFloat = min(550, screenSize.width * 0.45)
        let preferredHeight: CGFloat = min(600, screenSize.height * 0.55)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: preferredWidth, height: preferredHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = L("settings_title")
        window.isReleasedWhenClosed = false
        // 最小尺寸：根据屏幕尺寸调整，但不要太小
        let minWidth = min(480, screenSize.width * 0.35)
        let minHeight = min(420, screenSize.height * 0.45)
        window.minSize = NSSize(width: minWidth, height: minHeight)
        
        // 最大尺寸：不超过屏幕的 90%
        let maxWidth = screenSize.width * 0.9
        let maxHeight = screenSize.height * 0.9
        window.maxSize = NSSize(width: maxWidth, height: maxHeight)
        
        self.window = window
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        // 使用自定义的 NSTabViewController 子类来监听标签页切换
        let tabViewController = ResizableTabViewController()
        tabViewController.tabStyle = .toolbar
        tabViewController.windowController = self
        
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
        // 创建内容容器视图 - 使用 FlippedView 确保坐标系从顶部开始
        let contentView = FlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // iCloud同步部分
        let iCloudSyncLabel = createSectionLabel(L("icloud_sync"))
        iCloudSyncLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // iCloud Drive显示开关
        let iCloudDriveCheckbox = NSButton(checkboxWithTitle: L("show_in_icloud_drive"), target: self, action: #selector(toggleiCloudDriveFolder(_:)))
        iCloudDriveCheckbox.state = PreferencesManager.shared.iCloudDriveFolderEnabled ? .on : .off
        iCloudDriveCheckbox.translatesAutoresizingMaskIntoConstraints = false
        
        // 立即同步按钮和状态
        let syncNowButton = NSButton(title: L("sync_now"), target: self, action: #selector(performImmediateSync))
        syncNowButton.bezelStyle = .rounded
        syncNowButton.translatesAutoresizingMaskIntoConstraints = false
        
        let syncStatusLabel = NSTextField(labelWithString: iCloudSyncManager.shared.getSyncStatus())
        syncStatusLabel.textColor = .secondaryLabelColor
        syncStatusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        syncStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        self.syncStatusLabel = syncStatusLabel
        
        let syncRow = NSStackView(views: [syncNowButton, syncStatusLabel])
        syncRow.orientation = .horizontal
        syncRow.spacing = 12
        syncRow.translatesAutoresizingMaskIntoConstraints = false
        
        // 分隔视图
        let separator = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        // 数据管理部分
        let dataManagementLabel = createSectionLabel(L("data_management"))
        dataManagementLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 本地导入按钮
        let importButton = NSButton(title: L("manual_import_file"), target: self, action: #selector(importData))
        importButton.bezelStyle = .rounded
        importButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 导出到本地按钮
        let exportButton = NSButton(title: L("export_to_device"), target: self, action: #selector(exportData))
        exportButton.bezelStyle = .rounded
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加到内容视图
        contentView.addSubview(iCloudSyncLabel)
        contentView.addSubview(iCloudDriveCheckbox)
        contentView.addSubview(syncRow)
        contentView.addSubview(separator)
        contentView.addSubview(dataManagementLabel)
        contentView.addSubview(importButton)
        contentView.addSubview(exportButton)
        
        // 设置约束 - 从上到下排列，左对齐
        // 优化间距：减少顶部和左右边距，使内容更紧凑但不拥挤
        NSLayoutConstraint.activate([
            // iCloud同步标签
            iCloudSyncLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            iCloudSyncLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 25),
            iCloudSyncLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -25),
            
            // iCloud Drive复选框
            iCloudDriveCheckbox.topAnchor.constraint(equalTo: iCloudSyncLabel.bottomAnchor, constant: 10),
            iCloudDriveCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 25),
            iCloudDriveCheckbox.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -25),
            
            // 同步按钮行
            syncRow.topAnchor.constraint(equalTo: iCloudDriveCheckbox.bottomAnchor, constant: 10),
            syncRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 25),
            syncRow.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -25),
            
            // 分隔视图
            separator.topAnchor.constraint(equalTo: syncRow.bottomAnchor, constant: 16),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // 数据管理标签
            dataManagementLabel.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 16),
            dataManagementLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 25),
            dataManagementLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -25),
            
            // 导入按钮
            importButton.topAnchor.constraint(equalTo: dataManagementLabel.bottomAnchor, constant: 10),
            importButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 25),
            importButton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -25),
            
            // 导出按钮
            exportButton.topAnchor.constraint(equalTo: importButton.bottomAnchor, constant: 10),
            exportButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 25),
            exportButton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -25),
            
            // 内容视图底部约束
            exportButton.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)
        ])
        
        // 创建滚动视图
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        parentView.addSubview(scrollView)
        
        // 滚动视图约束
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: parentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
        ])
        
        // 设置 documentView
        scrollView.documentView = contentView
        
        // 内容视图约束 - 确保宽度匹配，高度根据内容自动调整
        // 关键：不设置固定高度，让内容视图根据实际内容自动调整
        NSLayoutConstraint.activate([
            // 内容视图宽度约束（确保内容不会超出滚动视图）
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
            // 不设置高度约束，让内容视图根据子视图的约束自动计算高度
        ])
        
        // 确保滚动视图从顶部开始显示
        // 在布局完成后，滚动到顶部
        DispatchQueue.main.async {
            // 等待布局完成
            parentView.layoutSubtreeIfNeeded()
            contentView.layoutSubtreeIfNeeded()
            
            // 滚动到顶部
            // 在 macOS 中，NSScrollView 使用翻转坐标系
            // 要显示顶部内容，需要将 clipView 滚动到 documentView 的顶部
            let clipView = scrollView.contentView
            if let documentView = scrollView.documentView {
                // 计算需要滚动到的位置：documentView 的高度减去 clipView 的高度
                let documentHeight = documentView.bounds.height
                let clipHeight = clipView.bounds.height
                let scrollY = max(0, documentHeight - clipHeight)
                clipView.scroll(to: NSPoint(x: 0, y: scrollY))
            } else {
                // 如果没有 documentView，直接滚动到原点
                clipView.scroll(to: NSPoint(x: 0, y: 0))
            }
        }
        
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
            gridView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 25),
            gridView.trailingAnchor.constraint(lessThanOrEqualTo: parentView.trailingAnchor, constant: -25)
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
        
        // 更新按钮
        let updateButton = NSButton(image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: L("button_update"))!, target: self, action: #selector(updateScholars))
        updateButton.bezelStyle = .texturedRounded
        updateButton.isBordered = true
        toolbar.addArrangedSubview(updateButton)
        
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
            mainContainer.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 16),
            mainContainer.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 25),
            mainContainer.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -25),
            mainContainer.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -16),
            
            toolbar.widthAnchor.constraint(equalTo: mainContainer.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: mainContainer.widthAnchor)
        ])
    }
    
    // MARK: - Scholar Management Actions
    @objc private func addScholar() {
        // 创建自定义窗口而不是使用 NSAlert，以支持键盘快捷键和完整粘贴
        let dialogWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        dialogWindow.title = L("add_scholar_title")
        dialogWindow.center()
        dialogWindow.isReleasedWhenClosed = false
        
        // 创建内容视图
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // 提示文本
        let messageLabel = NSTextField(labelWithString: L("add_scholar_message"))
        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 输入框 - 使用支持键盘快捷键的自定义 TextField
        let inputField = ValidatedTextField()
        inputField.placeholderString = L("scholar_id_placeholder")
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.font = .systemFont(ofSize: 13)
        inputField.isEditable = true
        inputField.isSelectable = true
        inputField.focusRingType = .default
        
        // 提示文本（显示支持的格式）
        let hintLabel = NSTextField(labelWithString: L("add_scholar_hint", "例如：MeaDj20AAAAJ 或 https://scholar.google.com/citations?user=MeaDj20AAAAJ"))
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 按钮
        let addButton = NSButton(title: L("button_add"), target: nil, action: nil)
        addButton.keyEquivalent = "\r"  // Enter 键
        addButton.keyEquivalentModifierMask = []  // 不需要修饰键
        addButton.bezelStyle = .rounded
        addButton.translatesAutoresizingMaskIntoConstraints = false
        
        let cancelButton = NSButton(title: L("button_cancel"), target: nil, action: nil)
        cancelButton.keyEquivalent = "\u{1b}"  // Escape 键
        cancelButton.keyEquivalentModifierMask = []  // 不需要修饰键
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 按钮容器
        let buttonStack = NSStackView(views: [cancelButton, addButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加到视图
        contentView.addSubview(messageLabel)
        contentView.addSubview(inputField)
        contentView.addSubview(hintLabel)
        contentView.addSubview(buttonStack)
        
        // 布局约束
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            inputField.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12),
            inputField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            inputField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            inputField.heightAnchor.constraint(equalToConstant: 24),
            
            hintLabel.topAnchor.constraint(equalTo: inputField.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            buttonStack.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        dialogWindow.contentView = contentView
        
        // 存储窗口和输入框引用到实例变量
        addScholarDialogWindow = dialogWindow
        addScholarInputField = inputField
        
        // 设置按钮动作
        cancelButton.target = self
        cancelButton.action = #selector(cancelAddScholar(_:))
        
        addButton.target = self
        addButton.action = #selector(confirmAddScholar(_:))
        
        // 显示窗口并激活应用
        NSApp.activate(ignoringOtherApps: true)
        dialogWindow.makeKeyAndOrderFront(nil)
        
        // 确保窗口成为 key window 并可以接收事件
        dialogWindow.level = .normal
        dialogWindow.isMovableByWindowBackground = false
        
        // 延迟设置第一响应者，确保窗口已完全显示
        DispatchQueue.main.async {
            dialogWindow.makeFirstResponder(inputField)
            // 选中所有文本，方便直接粘贴替换
            inputField.selectText(nil)
        }
    }
    
    @objc private func confirmAddScholar(_ sender: NSButton) {
        print("🔍 [DEBUG] confirmAddScholar called")
        guard let inputField = addScholarInputField,
              let dialogWindow = addScholarDialogWindow else {
            print("❌ [DEBUG] Failed to get inputField or dialogWindow from instance variables")
            return
        }
        print("✅ [DEBUG] Got inputField and dialogWindow")
        
        let inputText = inputField.stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        guard !inputText.isEmpty else {
            let errorAlert = NSAlert()
            errorAlert.messageText = L("error_invalid_scholar_id")
            errorAlert.informativeText = L("error_invalid_scholar_id_message")
            errorAlert.alertStyle = .warning
            errorAlert.addButton(withTitle: L("button_ok"))
            errorAlert.runModal()
            return
        }
        
        // 从输入中提取 Scholar ID（支持完整链接或直接 ID）
        guard let scholarId = GoogleScholarService.extractScholarId(from: inputText) else {
            // 显示错误提示
            let errorAlert = NSAlert()
            errorAlert.messageText = L("error_invalid_scholar_id")
            errorAlert.informativeText = L("error_invalid_scholar_id_message")
            errorAlert.alertStyle = .warning
            errorAlert.addButton(withTitle: L("button_ok"))
            errorAlert.runModal()
            return
        }
        
        // 检查是否已存在
        if PreferencesManager.shared.scholars.contains(where: { $0.id == scholarId }) {
            let errorAlert = NSAlert()
            errorAlert.messageText = L("error_scholar_exists")
            errorAlert.informativeText = L("error_scholar_exists_message")
            errorAlert.alertStyle = .warning
            errorAlert.addButton(withTitle: L("button_ok"))
            errorAlert.runModal()
            return
        }
        
        // 添加学者
        let newScholar = Scholar(id: scholarId)
        PreferencesManager.shared.addScholar(newScholar)
        loadData()
        
        // 通知更新
        NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
        
        // 自动更新该学者的信息
        googleScholarService.fetchScholarInfo(for: scholarId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let info):
                    // 更新学者信息
                    PreferencesManager.shared.updateScholar(withId: scholarId, name: info.name, citations: info.citations)
                    // 重新加载数据以显示更新后的信息
                    self?.loadData()
                    // 通知更新
                    NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
                    print("✅ [SettingsWindow] 自动更新学者信息成功: \(info.name), 引用数: \(info.citations)")
                case .failure(let error):
                    print("⚠️ [SettingsWindow] 自动更新学者信息失败: \(error.localizedDescription)")
                    // 即使更新失败，也继续关闭对话框
                }
            }
        }
        
        // 关闭对话框并清理引用
        print("✅ [DEBUG] Closing dialog window after adding scholar")
        dialogWindow.close()
        addScholarDialogWindow = nil
        addScholarInputField = nil
    }
    
    @objc private func cancelAddScholar(_ sender: NSButton) {
        print("🔍 [DEBUG] cancelAddScholar called")
        guard let dialogWindow = addScholarDialogWindow else {
            print("❌ [DEBUG] Failed to get dialogWindow from instance variable")
            return
        }
        print("✅ [DEBUG] Closing dialog window")
        dialogWindow.close()
        addScholarDialogWindow = nil
        addScholarInputField = nil
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
    
    @objc private func updateScholars() {
        let selectedRows = tableView.selectedRowIndexes
        
        // 如果没有选中任何行，更新所有学者
        let scholarsToUpdate: [Scholar]
        if selectedRows.isEmpty {
            scholarsToUpdate = scholars
        } else {
            // 更新选中的学者
            scholarsToUpdate = selectedRows.map { scholars[$0] }
        }
        
        guard !scholarsToUpdate.isEmpty else {
            let alert = NSAlert()
            alert.messageText = L("error_no_scholars")
            alert.informativeText = L("error_no_scholars_message")
            alert.alertStyle = .informational
            alert.addButton(withTitle: L("button_ok"))
            alert.runModal()
            return
        }
        
        // 显示进度提示
        let alert = NSAlert()
        alert.messageText = selectedRows.isEmpty ? L("updating_all_scholars") : L("updating_selected_scholars")
        alert.informativeText = L("please_wait_updating")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("button_ok"))
        alert.runModal()
        
        // 更新学者信息
        var completedCount = 0
        let totalCount = scholarsToUpdate.count
        
        for scholar in scholarsToUpdate {
            googleScholarService.fetchScholarInfo(for: scholar.id) { [weak self] result in
                DispatchQueue.main.async {
                    completedCount += 1
                    
                    switch result {
                    case .success(let info):
                        // 更新学者信息
                        PreferencesManager.shared.updateScholar(withId: scholar.id, name: info.name, citations: info.citations)
                        print("✅ [SettingsWindow] 更新学者成功: \(info.name), 引用数: \(info.citations)")
                    case .failure(let error):
                        print("⚠️ [SettingsWindow] 更新学者失败 \(scholar.id): \(error.localizedDescription)")
                    }
                    
                    // 所有更新完成后，重新加载数据
                    if completedCount == totalCount {
                        self?.loadData()
                        // 通知更新
                        NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
                        
                        // 显示完成提示
                        let completionAlert = NSAlert()
                        completionAlert.messageText = L("update_completed")
                        completionAlert.informativeText = L("update_completed_message", completedCount, totalCount)
                        completionAlert.alertStyle = .informational
                        completionAlert.addButton(withTitle: L("button_ok"))
                        completionAlert.runModal()
                    }
                }
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
        
        // Keep reference to prevent deallocation using type-safe cast
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.chartsWindowController = chartsWindowController
        }
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

// MARK: - Window Size Adjustment
extension SettingsWindowController {
    func adjustWindowSize(for tabViewItem: NSTabViewItem?) {
        guard let window = window, let tabViewItem = tabViewItem else { return }
        
        // 根据选中的标签页调整窗口尺寸
        let currentFrame = window.frame
        let currentOrigin = currentFrame.origin
        let currentHeight = currentFrame.height
        
        var newWidth: CGFloat
        var newMinWidth: CGFloat
        
        // 获取屏幕尺寸，根据屏幕和内容调整窗口大小
        if let screen = NSScreen.main {
            let screenSize = screen.visibleFrame.size
            
            // 判断是哪个标签页
            if tabViewItem.label == L("sidebar_scholars") {
                // Scholars 标签页：需要更宽的窗口，但不超过屏幕的 70%
                newWidth = min(900, screenSize.width * 0.65)
                newMinWidth = min(750, screenSize.width * 0.55)
            } else {
                // General 和 Data 标签页：窄一些的窗口，屏幕的 40-45%
                newWidth = min(550, screenSize.width * 0.42)
                newMinWidth = min(480, screenSize.width * 0.35)
            }
        } else {
            // 如果无法获取屏幕，使用默认值
            if tabViewItem.label == L("sidebar_scholars") {
                newWidth = 900
                newMinWidth = 800
            } else {
                newWidth = 550
                newMinWidth = 500
            }
        }
        
        // 保持窗口顶部位置不变，调整宽度
        let widthDiff = newWidth - currentFrame.width
        let newOrigin = NSPoint(
            x: currentOrigin.x - widthDiff / 2,
            y: currentOrigin.y
        )
        
        // 更新最小尺寸和最大尺寸
        if let screen = NSScreen.main {
            let screenSize = screen.visibleFrame.size
            window.minSize = NSSize(width: newMinWidth, height: min(420, screenSize.height * 0.45))
            window.maxSize = NSSize(width: screenSize.width * 0.9, height: screenSize.height * 0.9)
        } else {
            window.minSize = NSSize(width: newMinWidth, height: 450)
        }
        
        // 动画调整窗口尺寸
        let newFrame = NSRect(
            origin: newOrigin,
            size: NSSize(width: newWidth, height: currentHeight)
        )
        
        window.setFrame(newFrame, display: true, animate: true)
    }
} 