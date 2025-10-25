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
        // 创建主容器
        let mainContainer = NSStackView()
        mainContainer.orientation = .vertical
        mainContainer.spacing = 20
        mainContainer.alignment = .leading
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(mainContainer)
        
        // 标题区域
        let titleContainer = createDataTitleContainer()
        mainContainer.addArrangedSubview(titleContainer)
        
        // 数据概览区域
        let overviewContainer = createDataOverviewContainer()
        mainContainer.addArrangedSubview(overviewContainer)
        
        // 操作按钮区域
        let actionsContainer = createDataActionsContainer()
        mainContainer.addArrangedSubview(actionsContainer)
        
        // 设置约束
        NSLayoutConstraint.activate([
            mainContainer.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 16),
            mainContainer.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 16),
            mainContainer.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -16),
            mainContainer.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -16)
        ])
    }
    
    private func createDataTitleContainer() -> NSView {
        let titleView = NSView()
        titleView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "数据管理")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleView.addSubview(titleLabel)
        
        let subtitleLabel = NSTextField(labelWithString: "管理您的引用数据，包括导出、导入和同步功能")
        subtitleLabel.font = NSFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleView.addSubview(subtitleLabel)
        
        // 设置约束
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: titleView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: titleView.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: titleView.bottomAnchor),
            
            titleView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        return titleView
    }
    
    private func createDataOverviewContainer() -> NSView {
        let overviewView = NSView()
        overviewView.wantsLayer = true
        overviewView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        overviewView.layer?.cornerRadius = 12
        overviewView.layer?.borderWidth = 1
        overviewView.layer?.borderColor = NSColor.separatorColor.cgColor
        overviewView.translatesAutoresizingMaskIntoConstraints = false
        
        let overviewStack = NSStackView()
        overviewStack.orientation = .vertical
        overviewStack.spacing = 16
        overviewStack.alignment = .leading
        overviewStack.translatesAutoresizingMaskIntoConstraints = false
        overviewView.addSubview(overviewStack)
        
        // 概览标题
        let overviewTitle = NSTextField(labelWithString: "数据概览")
        overviewTitle.font = NSFont.boldSystemFont(ofSize: 16)
        overviewTitle.textColor = .labelColor
        overviewStack.addArrangedSubview(overviewTitle)
        
        // 数据统计网格
        let statsGrid = createDataStatsGrid()
        overviewStack.addArrangedSubview(statsGrid)
        
        // 设置约束
        NSLayoutConstraint.activate([
            overviewStack.topAnchor.constraint(equalTo: overviewView.topAnchor, constant: 16),
            overviewStack.leadingAnchor.constraint(equalTo: overviewView.leadingAnchor, constant: 16),
            overviewStack.trailingAnchor.constraint(equalTo: overviewView.trailingAnchor, constant: -16),
            overviewStack.bottomAnchor.constraint(equalTo: overviewView.bottomAnchor, constant: -16)
        ])
        
        return overviewView
    }
    
    private func createDataStatsGrid() -> NSView {
        let gridView = NSView()
        gridView.translatesAutoresizingMaskIntoConstraints = false
        
        let gridStack = NSStackView()
        gridStack.orientation = .horizontal
        gridStack.spacing = 20
        gridStack.distribution = .fillEqually
        gridStack.translatesAutoresizingMaskIntoConstraints = false
        gridView.addSubview(gridStack)
        
        // 学者数量统计
        let scholarsCount = scholars.count
        let scholarsStat = createDataStatItem(
            title: "学者数量",
            value: "\(scholarsCount)",
            icon: "person.3",
            color: .systemBlue
        )
        gridStack.addArrangedSubview(scholarsStat)
        
        // 历史记录数量统计
        let historyCount = getHistoryRecordCount()
        let historyStat = createDataStatItem(
            title: "历史记录",
            value: "\(historyCount)",
            icon: "clock.arrow.circlepath",
            color: .systemGreen
        )
        gridStack.addArrangedSubview(historyStat)
        
        // 数据大小统计
        let dataSize = getDataSize()
        let sizeStat = createDataStatItem(
            title: "数据大小",
            value: dataSize,
            icon: "externaldrive",
            color: .systemOrange
        )
        gridStack.addArrangedSubview(sizeStat)
        
        // 最后备份时间
        let lastBackup = getLastBackupTime()
        let backupStat = createDataStatItem(
            title: "最后备份",
            value: lastBackup,
            icon: "icloud.and.arrow.up",
            color: .systemPurple
        )
        gridStack.addArrangedSubview(backupStat)
        
        // 设置约束
        NSLayoutConstraint.activate([
            gridStack.topAnchor.constraint(equalTo: gridView.topAnchor),
            gridStack.leadingAnchor.constraint(equalTo: gridView.leadingAnchor),
            gridStack.trailingAnchor.constraint(equalTo: gridView.trailingAnchor),
            gridStack.bottomAnchor.constraint(equalTo: gridView.bottomAnchor)
        ])
        
        return gridView
    }
    
    private func createDataStatItem(title: String, value: String, icon: String, color: NSColor) -> NSView {
        let itemView = NSView()
        itemView.translatesAutoresizingMaskIntoConstraints = false
        
        let itemStack = NSStackView()
        itemStack.orientation = .vertical
        itemStack.spacing = 8
        itemStack.alignment = .centerX
        itemStack.translatesAutoresizingMaskIntoConstraints = false
        itemView.addSubview(itemStack)
        
        // 图标
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        // 图标颜色设置（暂时禁用，因为API兼容性问题）
        itemStack.addArrangedSubview(iconView)
        
        // 数值
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.boldSystemFont(ofSize: 18)
        valueLabel.textColor = .labelColor
        valueLabel.alignment = .center
        itemStack.addArrangedSubview(valueLabel)
        
        // 标题
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        itemStack.addArrangedSubview(titleLabel)
        
        // 设置约束
        NSLayoutConstraint.activate([
            itemStack.centerXAnchor.constraint(equalTo: itemView.centerXAnchor),
            itemStack.centerYAnchor.constraint(equalTo: itemView.centerYAnchor),
            itemStack.leadingAnchor.constraint(greaterThanOrEqualTo: itemView.leadingAnchor, constant: 8),
            itemStack.trailingAnchor.constraint(lessThanOrEqualTo: itemView.trailingAnchor, constant: -8)
        ])
        
        return itemView
    }
    
    private func createDataActionsContainer() -> NSView {
        let actionsView = NSView()
        actionsView.translatesAutoresizingMaskIntoConstraints = false
        
        let actionsStack = NSStackView()
        actionsStack.orientation = .vertical
        actionsStack.spacing = 16
        actionsStack.alignment = .leading
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        actionsView.addSubview(actionsStack)
        
        // 导出数据部分
        let exportSection = createActionSection(
            title: "导出数据",
            description: "将您的引用数据导出为CSV或JSON格式",
            buttonTitle: "导出数据...",
            buttonAction: #selector(exportData),
            icon: "square.and.arrow.up"
        )
        actionsStack.addArrangedSubview(exportSection)
        
        // 导入数据部分
        let importSection = createActionSection(
            title: "导入数据",
            description: "从备份文件或iOS设备导入数据",
            buttonTitle: "导入数据...",
            buttonAction: #selector(importData),
            icon: "square.and.arrow.down"
        )
        actionsStack.addArrangedSubview(importSection)
        
        // iCloud同步部分
        let syncSection = createActionSection(
            title: "iCloud同步",
            description: "与iCloud同步您的数据，实现跨设备访问",
            buttonTitle: "管理iCloud同步",
            buttonAction: #selector(manageiCloudSync),
            icon: "icloud.and.arrow.up"
        )
        actionsStack.addArrangedSubview(syncSection)
        
        // 设置约束
        NSLayoutConstraint.activate([
            actionsStack.topAnchor.constraint(equalTo: actionsView.topAnchor),
            actionsStack.leadingAnchor.constraint(equalTo: actionsView.leadingAnchor),
            actionsStack.trailingAnchor.constraint(equalTo: actionsView.trailingAnchor),
            actionsStack.bottomAnchor.constraint(equalTo: actionsView.bottomAnchor)
        ])
        
        return actionsView
    }
    
    private func createActionSection(title: String, description: String, buttonTitle: String, buttonAction: Selector, icon: String) -> NSView {
        let sectionView = NSView()
        sectionView.wantsLayer = true
        sectionView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        sectionView.layer?.cornerRadius = 8
        sectionView.layer?.borderWidth = 1
        sectionView.layer?.borderColor = NSColor.separatorColor.cgColor
        sectionView.translatesAutoresizingMaskIntoConstraints = false
        
        let sectionStack = NSStackView()
        sectionStack.orientation = .horizontal
        sectionStack.spacing = 16
        sectionStack.alignment = .centerY
        sectionStack.translatesAutoresizingMaskIntoConstraints = false
        sectionView.addSubview(sectionStack)
        
        // 图标
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        // 图标颜色设置（暂时禁用，因为API兼容性问题）
        iconView.translatesAutoresizingMaskIntoConstraints = false
        sectionStack.addArrangedSubview(iconView)
        
        // 文本信息
        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false
        sectionStack.addArrangedSubview(textStack)
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        titleLabel.textColor = .labelColor
        textStack.addArrangedSubview(titleLabel)
        
        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor
        textStack.addArrangedSubview(descLabel)
        
        // 弹性空间
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        sectionStack.addArrangedSubview(spacer)
        
        // 按钮
        let actionButton = NSButton(title: buttonTitle, target: self, action: buttonAction)
        actionButton.bezelStyle = .rounded
        sectionStack.addArrangedSubview(actionButton)
        
        // 设置约束
        NSLayoutConstraint.activate([
            sectionStack.topAnchor.constraint(equalTo: sectionView.topAnchor, constant: 16),
            sectionStack.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor, constant: 16),
            sectionStack.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor, constant: -16),
            sectionStack.bottomAnchor.constraint(equalTo: sectionView.bottomAnchor, constant: -16),
            
            sectionView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        return sectionView
    }
    
    // MARK: - Data Management Helper Methods
    private func getHistoryRecordCount() -> Int {
        // 获取历史记录数量的逻辑
        return 0 // 临时返回0，实际应该从Core Data获取
    }
    
    private func getDataSize() -> String {
        // 获取数据大小的逻辑
        return "0 KB" // 临时返回，实际应该计算数据大小
    }
    
    private func getLastBackupTime() -> String {
        // 获取最后备份时间的逻辑
        return "从未备份" // 临时返回，实际应该从用户偏好设置获取
    }
    
    @objc private func manageiCloudSync() {
        // 管理iCloud同步的逻辑
        let alert = NSAlert()
        alert.messageText = "iCloud同步管理"
        alert.informativeText = "这里可以管理iCloud同步设置"
        alert.runModal()
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
        // 创建主滚动视图以支持内容过多时的滚动
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        parentView.addSubview(scrollView)
        
        // 创建内容视图
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView
        
        // 创建主布局容器 - 使用水平布局分为两列
        let mainContainer = NSStackView()
        mainContainer.orientation = .horizontal
        mainContainer.spacing = 32
        mainContainer.alignment = .top
        mainContainer.distribution = .fillEqually
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainContainer)
        
        // 左列：应用设置和启动选项
        let leftColumn = createLeftColumn()
        mainContainer.addArrangedSubview(leftColumn)
        
        // 右列：显示选项和iCloud同步
        let rightColumn = createRightColumn()
        mainContainer.addArrangedSubview(rightColumn)
        
        // 设置约束
        NSLayoutConstraint.activate([
            // 滚动视图约束
            scrollView.topAnchor.constraint(equalTo: parentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            
            // 内容视图约束
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 主容器约束
            mainContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            mainContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            mainContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainContainer.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24)
        ])
    }
    
    private func createLeftColumn() -> NSView {
        let columnView = NSView()
        columnView.translatesAutoresizingMaskIntoConstraints = false
        
        let columnStack = NSStackView()
        columnStack.orientation = .vertical
        columnStack.spacing = 24
        columnStack.alignment = .leading
        columnStack.translatesAutoresizingMaskIntoConstraints = false
        columnView.addSubview(columnStack)
        
        // 应用设置部分
        setupAppSettingsSection(in: columnStack)
        columnStack.addArrangedSubview(createSeparator())
        
        // 启动选项部分
        setupStartupSection(in: columnStack)
        
        // 设置约束
        NSLayoutConstraint.activate([
            columnStack.topAnchor.constraint(equalTo: columnView.topAnchor),
            columnStack.leadingAnchor.constraint(equalTo: columnView.leadingAnchor),
            columnStack.trailingAnchor.constraint(equalTo: columnView.trailingAnchor),
            columnStack.bottomAnchor.constraint(lessThanOrEqualTo: columnView.bottomAnchor)
        ])
        
        return columnView
    }
    
    private func createRightColumn() -> NSView {
        let columnView = NSView()
        columnView.translatesAutoresizingMaskIntoConstraints = false
        
        let columnStack = NSStackView()
        columnStack.orientation = .vertical
        columnStack.spacing = 24
        columnStack.alignment = .leading
        columnStack.translatesAutoresizingMaskIntoConstraints = false
        columnView.addSubview(columnStack)
        
        // 显示选项部分
        setupDisplaySection(in: columnStack)
        columnStack.addArrangedSubview(createSeparator())
        
        // iCloud同步部分
        setupiCloudSyncSection(in: columnStack)
        
        // 设置约束
        NSLayoutConstraint.activate([
            columnStack.topAnchor.constraint(equalTo: columnView.topAnchor),
            columnStack.leadingAnchor.constraint(equalTo: columnView.leadingAnchor),
            columnStack.trailingAnchor.constraint(equalTo: columnView.trailingAnchor),
            columnStack.bottomAnchor.constraint(lessThanOrEqualTo: columnView.bottomAnchor)
        ])
        
        return columnView
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
        // 创建主容器
        let mainContainer = NSStackView()
        mainContainer.orientation = .vertical
        mainContainer.spacing = 16
        mainContainer.alignment = .leading
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(mainContainer)
        
        // 顶部工具栏
        let toolbarContainer = createScholarToolbar()
        mainContainer.addArrangedSubview(toolbarContainer)
        
        // 统计信息卡片区域
        let statsContainer = createScholarStatsContainer()
        mainContainer.addArrangedSubview(statsContainer)
        
        // 学者列表区域
        let listContainer = createScholarListContainer()
        mainContainer.addArrangedSubview(listContainer)
        
        // 设置约束
        NSLayoutConstraint.activate([
            mainContainer.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 16),
            mainContainer.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 16),
            mainContainer.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -16),
            mainContainer.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -16)
        ])
    }
    
    private func createScholarToolbar() -> NSView {
        let toolbarView = NSView()
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        
        let toolbarStack = NSStackView()
        toolbarStack.orientation = .horizontal
        toolbarStack.spacing = 12
        toolbarStack.alignment = .centerY
        toolbarStack.translatesAutoresizingMaskIntoConstraints = false
        toolbarView.addSubview(toolbarStack)
        
        // 标题
        let titleLabel = NSTextField(labelWithString: L("section_scholar_management"))
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = .labelColor
        toolbarStack.addArrangedSubview(titleLabel)
        
        // 弹性空间
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        toolbarStack.addArrangedSubview(spacer)
        
        // 添加学者按钮
        let addButton = NSButton(title: L("button_add_scholar"), target: self, action: #selector(addScholar))
        addButton.bezelStyle = .rounded
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add Scholar")
        toolbarStack.addArrangedSubview(addButton)
        
        // 刷新按钮
        let refreshButton = NSButton(title: L("button_refresh"), target: self, action: #selector(refreshAllScholars))
        refreshButton.bezelStyle = .rounded
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        toolbarStack.addArrangedSubview(refreshButton)
        
        // 设置约束
        NSLayoutConstraint.activate([
            toolbarStack.topAnchor.constraint(equalTo: toolbarView.topAnchor),
            toolbarStack.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor),
            toolbarStack.trailingAnchor.constraint(equalTo: toolbarView.trailingAnchor),
            toolbarStack.bottomAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        return toolbarView
    }
    
    private func createScholarStatsContainer() -> NSView {
        let statsView = NSView()
        statsView.translatesAutoresizingMaskIntoConstraints = false
        
        let statsStack = NSStackView()
        statsStack.orientation = .horizontal
        statsStack.spacing = 16
        statsStack.distribution = .fillEqually
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        statsView.addSubview(statsStack)
        
        // 总学者数卡片
        let totalCard = createStatCard(title: "总学者数", value: "\(scholars.count)", icon: "person.3")
        statsStack.addArrangedSubview(totalCard)
        
        // 总引用数卡片
        let totalCitations = scholars.compactMap { $0.citations }.reduce(0, +)
        let citationsCard = createStatCard(title: "总引用数", value: "\(totalCitations)", icon: "chart.bar")
        statsStack.addArrangedSubview(citationsCard)
        
        // 最后更新卡片
        let lastUpdate = scholars.compactMap { $0.lastUpdated }.max()
        let lastUpdateText: String
        if #available(macOS 12.0, *) {
            lastUpdateText = lastUpdate?.formatted(date: .abbreviated, time: .shortened) ?? "从未更新"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            lastUpdateText = lastUpdate.map { formatter.string(from: $0) } ?? "从未更新"
        }
        let updateCard = createStatCard(title: "最后更新", value: lastUpdateText, icon: "clock")
        statsStack.addArrangedSubview(updateCard)
        
        // 设置约束
        NSLayoutConstraint.activate([
            statsStack.topAnchor.constraint(equalTo: statsView.topAnchor),
            statsStack.leadingAnchor.constraint(equalTo: statsView.leadingAnchor),
            statsStack.trailingAnchor.constraint(equalTo: statsView.trailingAnchor),
            statsStack.bottomAnchor.constraint(equalTo: statsView.bottomAnchor),
            statsView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        return statsView
    }
    
    private func createStatCard(title: String, value: String, icon: String) -> NSView {
        let cardView = NSView()
        cardView.wantsLayer = true
        cardView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        cardView.layer?.cornerRadius = 8
        cardView.layer?.borderWidth = 1
        cardView.layer?.borderColor = NSColor.separatorColor.cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let cardStack = NSStackView()
        cardStack.orientation = .vertical
        cardStack.spacing = 4
        cardStack.alignment = .centerX
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(cardStack)
        
        // 图标
        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        // 图标颜色设置（暂时禁用，因为API兼容性问题）
        cardStack.addArrangedSubview(iconView)
        
        // 数值
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.boldSystemFont(ofSize: 16)
        valueLabel.textColor = .labelColor
        valueLabel.alignment = .center
        cardStack.addArrangedSubview(valueLabel)
        
        // 标题
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        cardStack.addArrangedSubview(titleLabel)
        
        // 设置约束
        NSLayoutConstraint.activate([
            cardStack.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            cardStack.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            cardStack.leadingAnchor.constraint(greaterThanOrEqualTo: cardView.leadingAnchor, constant: 8),
            cardStack.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -8)
        ])
        
        return cardView
    }
    
    private func createScholarListContainer() -> NSView {
        let listView = NSView()
        listView.translatesAutoresizingMaskIntoConstraints = false
        
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
        tableView.intercellSpacing = NSSize(width: 8, height: 4)
        
        // 启用拖拽排序
        tableView.registerForDraggedTypes([.string])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)
        
        // 添加列
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = L("scholar_name")
        nameColumn.width = 180
        nameColumn.minWidth = 120
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
        lastUpdatedColumn.width = 140
        lastUpdatedColumn.minWidth = 120
        tableView.addTableColumn(lastUpdatedColumn)
        
        tableScrollView.documentView = tableView
        listView.addSubview(tableScrollView)
        
        // 设置约束
        NSLayoutConstraint.activate([
            tableScrollView.topAnchor.constraint(equalTo: listView.topAnchor),
            tableScrollView.leadingAnchor.constraint(equalTo: listView.leadingAnchor),
            tableScrollView.trailingAnchor.constraint(equalTo: listView.trailingAnchor),
            tableScrollView.bottomAnchor.constraint(equalTo: listView.bottomAnchor)
        ])
        
        return listView
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
    
    @objc private func refreshAllScholars() {
        // 实现刷新所有学者的逻辑
        // 这里可以调用现有的刷新逻辑
        NotificationCenter.default.post(name: NSNotification.Name("ScholarsUpdated"), object: nil)
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