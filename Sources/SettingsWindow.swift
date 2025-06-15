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
    
    private func setupGeneralSettings(in parentView: NSView) {
        let settingsStack = NSStackView()
        settingsStack.orientation = .vertical
        settingsStack.spacing = 20
        settingsStack.alignment = .leading
        settingsStack.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(settingsStack)
        
        // 启动选项标题 - 移到最上面
        let startupTitle = createSectionTitle(L("section_startup_options"))
        settingsStack.addArrangedSubview(startupTitle)
        
        // 启动设置
        let launchContainer = createSettingRow(
            label: L("setting_launch_at_login"),
            control: {
                launchAtLoginCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(launchAtLoginChanged))
                launchAtLoginCheckbox.state = PreferencesManager.shared.launchAtLogin ? .on : .off
                return launchAtLoginCheckbox
            }()
        )
        settingsStack.addArrangedSubview(launchContainer)
        
        // 分隔线
        let separator1 = createSeparator()
        settingsStack.addArrangedSubview(separator1)
        
        // 应用设置标题
        let appSettingsTitle = createSectionTitle(L("section_app_settings"))
        settingsStack.addArrangedSubview(appSettingsTitle)
        
        // 更新间隔设置
        let updateIntervalContainer = createSettingRow(
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
                
                let currentInterval = PreferencesManager.shared.updateInterval
                let index = intervalToIndex(currentInterval)
                updateIntervalPopup.selectItem(at: index)
                updateIntervalPopup.target = self
                updateIntervalPopup.action = #selector(updateIntervalChanged)
                return updateIntervalPopup
            }()
        )
        settingsStack.addArrangedSubview(updateIntervalContainer)
        
        // 语言设置
        let languageContainer = createSettingRow(
            label: L("setting_language"),
            control: {
                languagePopup = NSPopUpButton()
                for language in LocalizationManager.shared.availableLanguages {
                    languagePopup.addItem(withTitle: language.displayName)
                    languagePopup.lastItem?.representedObject = language
                }
                
                // 选择当前语言
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
                return languagePopup
            }()
        )
        settingsStack.addArrangedSubview(languageContainer)
        
        // 分隔线
        let separator2 = createSeparator()
        settingsStack.addArrangedSubview(separator2)
        
        // 显示选项标题
        let displayTitle = createSectionTitle(L("section_display_options"))
        settingsStack.addArrangedSubview(displayTitle)
        
        // Dock显示设置
        let dockContainer = createSettingRow(
            label: L("setting_show_in_dock"),
            control: {
                showInDockCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(showInDockChanged))
                showInDockCheckbox.state = PreferencesManager.shared.showInDock ? .on : .off
                return showInDockCheckbox
            }()
        )
        settingsStack.addArrangedSubview(dockContainer)
        
        // 菜单栏显示设置
        let menuBarContainer = createSettingRow(
            label: L("setting_show_in_menubar"),
            control: {
                showInMenuBarCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(showInMenuBarChanged))
                showInMenuBarCheckbox.state = PreferencesManager.shared.showInMenuBar ? .on : .off
                return showInMenuBarCheckbox
            }()
        )
        settingsStack.addArrangedSubview(menuBarContainer)
        
        // 约束
        NSLayoutConstraint.activate([
            settingsStack.topAnchor.constraint(equalTo: parentView.topAnchor, constant: 20),
            settingsStack.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 20),
            settingsStack.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -20)
        ])
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
    
    @objc private func languageChanged() {
        // 重新设置窗口标题和UI文本
        window?.title = L("settings_title")
        // 重新构建UI以更新所有文本
        setupUI()
        tableView.reloadData()
    }
    
    @objc private func languageSelectionChanged(_ sender: NSPopUpButton) {
        guard let language = sender.selectedItem?.representedObject as? LocalizationManager.Language else { return }
        LocalizationManager.shared.setLanguage(language)
    }
    
    @objc private func addScholar() {
        let alert = NSAlert()
        alert.messageText = L("add_scholar_title")
        alert.informativeText = L("add_scholar_message")
        alert.addButton(withTitle: L("button_add"))
        alert.addButton(withTitle: L("button_cancel"))
        
        // 创建支持复制粘贴的输入字段
        let inputTextField = EditableTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
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
            
            guard let scholarId = GoogleScholarService.extractScholarId(from: input) else {
                let errorAlert = NSAlert()
                errorAlert.messageText = L("error_invalid_format")
                errorAlert.informativeText = L("error_invalid_format_message")
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
                DispatchQueue.main.async {
                    switch result {
                    case .success(let info):
                        let finalName = customName.isEmpty ? info.name : customName
                        let scholar = Scholar(id: scholarId, name: finalName)
                        var updatedScholar = scholar
                        updatedScholar.citations = info.citations
                        updatedScholar.lastUpdated = Date()
                        
                        self?.scholars.append(updatedScholar)
                        PreferencesManager.shared.scholars = self?.scholars ?? []
                        self?.tableView.reloadData()
                        
                        let successAlert = NSAlert()
                        successAlert.messageText = L("success_scholar_added")
                        successAlert.informativeText = L("success_scholar_added_message", finalName, info.citations)
                        successAlert.runModal()
                        
                    case .failure(let error):
                        let finalName = customName.isEmpty ? L("default_scholar_name", String(scholarId.prefix(8))) : customName
                        let scholar = Scholar(id: scholarId, name: finalName)
                        
                        self?.scholars.append(scholar)
                        PreferencesManager.shared.scholars = self?.scholars ?? []
                        self?.tableView.reloadData()
                        
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
        for (index, scholar) in scholars.enumerated() {
            googleScholarService.fetchCitationCount(for: scholar.id) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let citations):
                        self?.scholars[index].citations = citations
                        self?.scholars[index].lastUpdated = Date()
                        PreferencesManager.shared.scholars = self?.scholars ?? []
                        self?.tableView.reloadData()
                    case .failure(let error):
                        print("刷新学者 \(scholar.id) 失败: \(error.localizedDescription)")
                    }
                }
            }
        }
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
    
    private func updateAppearance() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.updateAppearance()
        }
    }
    
    private func loadData() {
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