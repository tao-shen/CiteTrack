import Cocoa
import Foundation

// MARK: - Data Repair View Controller
class DataRepairViewController: NSViewController {
    
    // MARK: - UI Components
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var scholarPopup: NSPopUpButton!
    private var timeRangePopup: NSPopUpButton!
    private var actionButtonsStack: NSStackView!
    
    // MARK: - Data
    private var scholars: [Scholar] = []
    private var currentScholar: Scholar?
    private var historyEntries: [CitationHistory] = []
    private let historyManager = CitationHistoryManager.shared
    
    // Flag to prevent async operations after cleanup
    private var isCleanedUp = false
    
    // Initial scholar to select when window opens
    private var initialScholar: Scholar?
    
    // MARK: - Initialization
    
    convenience init(initialScholar: Scholar?) {
        self.init()
        self.initialScholar = initialScholar
        print("🎯 [DataRepair DEBUG] DataRepairViewController initialized with scholar: \(initialScholar?.name ?? "nil")")
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🟢 [DataRepair DEBUG] viewDidLoad called - \(self)")
        print("🟢 [DataRepair DEBUG] About to setupUI...")
        setupUI()
        print("🟢 [DataRepair DEBUG] setupUI completed, about to loadScholars...")
        loadScholars()
        print("🟢 [DataRepair DEBUG] viewDidLoad completed successfully")
    }
    
    deinit {
        print("🗑️ [DataRepair DEBUG] DataRepairViewController is being deallocated - \(self)")
        performCleanup()
    }
    
    // MARK: - Cleanup
    
    func performCleanup() {
        print("🧹 [DataRepair DEBUG] DataRepairViewController performing cleanup - \(self)")
        
        // CRITICAL: Set cleanup flag to prevent async operations
        isCleanedUp = true
        print("🧹 [DataRepair DEBUG] Set isCleanedUp = true to prevent async callbacks")
        
        // Clean up table view references
        if let table = tableView {
            print("🧹 [DataRepair DEBUG] Clearing table view delegate and dataSource")
            table.delegate = nil
            table.dataSource = nil
        }
        
        // Clear data arrays
        print("🧹 [DataRepair DEBUG] Clearing data arrays")
        scholars.removeAll()
        historyEntries.removeAll()
        currentScholar = nil
        
        // Remove any remaining observers
        print("🧹 [DataRepair DEBUG] Removing notification observers")
        NotificationCenter.default.removeObserver(self)
        
        print("✅ [DataRepair DEBUG] DataRepairViewController cleanup completed - \(self)")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        setupHeader()
        setupTableView()
        setupActionButtons()
        setupConstraints()
    }
    
    private func setupHeader() {
        // Scholar selection
        scholarPopup = NSPopUpButton()
        scholarPopup.target = self
        scholarPopup.action = #selector(scholarSelectionChanged)
        
        // Time range selection
        timeRangePopup = NSPopUpButton()
        for timeRange in TimeRange.allCases {
            timeRangePopup.addItem(withTitle: timeRange.displayName)
            timeRangePopup.lastItem?.representedObject = timeRange
        }
        timeRangePopup.target = self
        timeRangePopup.action = #selector(timeRangeChanged)
    }
    
    private func setupTableView() {
        // Create table view
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        tableView.usesAlternatingRowBackgroundColors = true
        
        // Add columns
        setupTableColumns()
        
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupTableColumns() {
        // Timestamp column
        let timestampColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("timestamp"))
        timestampColumn.title = L("column_timestamp")
        timestampColumn.width = 150
        tableView.addTableColumn(timestampColumn)
        
        // Citation count column
        let citationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("citations"))
        citationColumn.title = L("column_citations")
        citationColumn.width = 100
        tableView.addTableColumn(citationColumn)
        
        // Change column
        let changeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("change"))
        changeColumn.title = L("column_change")
        changeColumn.width = 80
        tableView.addTableColumn(changeColumn)
        
        // Source column
        let sourceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("source"))
        sourceColumn.title = L("column_source")
        sourceColumn.width = 100
        tableView.addTableColumn(sourceColumn)
        
        // Actions column
        let actionsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("actions"))
        actionsColumn.title = L("column_actions")
        actionsColumn.width = 120
        tableView.addTableColumn(actionsColumn)
    }
    
    private func setupActionButtons() {
        actionButtonsStack = NSStackView()
        actionButtonsStack.orientation = .horizontal
        actionButtonsStack.spacing = 12
        actionButtonsStack.alignment = .centerY
        actionButtonsStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Edit selected entry button
        let editButton = NSButton(title: L("button_edit_entry"), target: self, action: #selector(editSelectedEntry))
        editButton.bezelStyle = .rounded
        actionButtonsStack.addArrangedSubview(editButton)
        
        // Delete selected entries button
        let deleteButton = NSButton(title: L("button_delete_entries"), target: self, action: #selector(deleteSelectedEntries))
        deleteButton.bezelStyle = .rounded
        deleteButton.contentTintColor = .systemRed
        actionButtonsStack.addArrangedSubview(deleteButton)
        
        // Restore to point button
        let restoreButton = NSButton(title: L("button_restore_to_point"), target: self, action: #selector(restoreToSelectedPoint))
        restoreButton.bezelStyle = .rounded
        restoreButton.contentTintColor = .systemOrange
        actionButtonsStack.addArrangedSubview(restoreButton)
        
        // Refresh data from point button
        let refreshFromButton = NSButton(title: L("button_refresh_from_point"), target: self, action: #selector(refreshFromSelectedPoint))
        refreshFromButton.bezelStyle = .rounded
        refreshFromButton.contentTintColor = .systemBlue
        actionButtonsStack.addArrangedSubview(refreshFromButton)
        
        // Add spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        actionButtonsStack.addArrangedSubview(spacer)
        
        // Export data button
        let exportButton = NSButton(title: L("button_export_data"), target: self, action: #selector(exportData))
        exportButton.bezelStyle = .rounded
        actionButtonsStack.addArrangedSubview(exportButton)
    }
    
    private func setupConstraints() {
        view.addSubview(scrollView)
        view.addSubview(actionButtonsStack)
        
        // Create header container
        let headerContainer = NSView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerContainer)
        
        headerContainer.addSubview(scholarPopup)
        headerContainer.addSubview(timeRangePopup)
        
        scholarPopup.translatesAutoresizingMaskIntoConstraints = false
        timeRangePopup.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Header constraints
            headerContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            headerContainer.heightAnchor.constraint(equalToConstant: 40),
            
            scholarPopup.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            scholarPopup.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            scholarPopup.widthAnchor.constraint(equalToConstant: 200),
            
            timeRangePopup.leadingAnchor.constraint(equalTo: scholarPopup.trailingAnchor, constant: 20),
            timeRangePopup.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            timeRangePopup.widthAnchor.constraint(equalToConstant: 150),
            
            // Table view constraints
            scrollView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: actionButtonsStack.topAnchor, constant: -20),
            
            // Action buttons constraints
            actionButtonsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            actionButtonsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            actionButtonsStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            actionButtonsStack.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadScholars() {
        scholars = PreferencesManager.shared.scholars
        updateScholarPopup()
        
        // Use initial scholar if provided, otherwise use first scholar
        let selectedScholar: Scholar?
        if let initial = initialScholar,
           scholars.contains(where: { $0.id == initial.id }) {
            selectedScholar = initial
            print("🎯 [DataRepair DEBUG] Using initial scholar: \(initial.name)")
        } else {
            selectedScholar = scholars.first
            print("🎯 [DataRepair DEBUG] Using first scholar: \(selectedScholar?.name ?? "none")")
        }
        
        if let scholar = selectedScholar {
            currentScholar = scholar
            // Select the scholar in popup
            selectScholarInPopup(scholar)
            loadHistoryData()
        }
    }
    
    private func selectScholarInPopup(_ scholar: Scholar) {
        for i in 0..<scholarPopup.numberOfItems {
            if let item = scholarPopup.item(at: i),
               let itemScholar = item.representedObject as? Scholar,
               itemScholar.id == scholar.id {
                scholarPopup.selectItem(at: i)
                print("🎯 [DataRepair DEBUG] Selected scholar in popup: \(scholar.name)")
                break
            }
        }
    }
    
    private func updateScholarPopup() {
        scholarPopup.removeAllItems()
        
        for scholar in scholars {
            scholarPopup.addItem(withTitle: scholar.name)
            scholarPopup.lastItem?.representedObject = scholar
        }
    }
    
    private func loadHistoryData() {
        guard let scholar = currentScholar else { return }
        
        let timeRange = getSelectedTimeRange()
        print("🔄 [DataRepair DEBUG] Loading history data for scholar: \(scholar.name)")
        
        historyManager.getHistory(for: scholar.id, in: timeRange) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else {
                    print("⚠️ [DataRepair DEBUG] Self is nil in async callback")
                    return
                }
                
                // CRITICAL: Check if we've been cleaned up
                if self.isCleanedUp {
                    print("🛑 [DataRepair DEBUG] Ignoring async callback - view controller was cleaned up")
                    return
                }
                
                print("✅ [DataRepair DEBUG] Processing async callback - view controller is still active")
                switch result {
                case .success(let history):
                    self.historyEntries = history.sorted { $0.timestamp > $1.timestamp }
                    self.tableView?.reloadData()
                    print("✅ [DataRepair DEBUG] Table view reloaded with \(history.count) entries")
                case .failure(let error):
                    self.showError("Failed to load history", error.localizedDescription)
                    print("❌ [DataRepair DEBUG] History loading failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func scholarSelectionChanged() {
        guard let scholar = scholarPopup.selectedItem?.representedObject as? Scholar else { return }
        currentScholar = scholar
        loadHistoryData()
    }
    
    @objc private func timeRangeChanged() {
        loadHistoryData()
    }
    
    @objc private func editSelectedEntry() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < historyEntries.count else {
            showAlert("Please select an entry to edit")
            return
        }
        
        let entry = historyEntries[selectedRow]
        showEditEntryDialog(for: entry)
    }
    
    @objc private func deleteSelectedEntries() {
        let selectedRows = tableView.selectedRowIndexes
        guard !selectedRows.isEmpty else {
            showAlert("Please select entries to delete")
            return
        }
        
        let selectedEntries = selectedRows.compactMap { index in
            index < historyEntries.count ? historyEntries[index] : nil
        }
        
        showDeleteConfirmation(for: selectedEntries)
    }
    
    @objc private func restoreToSelectedPoint() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < historyEntries.count else {
            showAlert("Please select a restore point")
            return
        }
        
        let restorePoint = historyEntries[selectedRow]
        showRestoreConfirmation(to: restorePoint)
    }
    
    @objc private func refreshFromSelectedPoint() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < historyEntries.count else {
            showAlert("Please select a starting point")
            return
        }
        
        let startPoint = historyEntries[selectedRow]
        showRefreshFromPointConfirmation(from: startPoint)
    }
    
    @objc private func exportData() {
        guard let scholar = currentScholar else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["csv", "json"]
        savePanel.nameFieldStringValue = "citation_history_\(scholar.id)_\(Date().timeIntervalSince1970)"
        
        savePanel.begin { [weak self] result in
            guard result == .OK, let url = savePanel.url else { return }
            self?.performExport(to: url, for: scholar)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getSelectedTimeRange() -> TimeRange {
        return timeRangePopup.selectedItem?.representedObject as? TimeRange ?? .lastMonth
    }
    
    private func showError(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    private func showAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Data Repair"
        alert.informativeText = message
        alert.runModal()
    }
    
    private func performExport(to url: URL, for scholar: Scholar) {
        // Implementation for exporting data
        // This would use the existing export functionality
    }
}

// MARK: - Table View Data Source
extension DataRepairViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return historyEntries.count
    }
}

// MARK: - Table View Delegate  
extension DataRepairViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < historyEntries.count else { return nil }
        
        let entry = historyEntries[row]
        let identifier = tableColumn?.identifier
        
        switch identifier {
        case NSUserInterfaceItemIdentifier("timestamp"):
            let cellView = NSTableCellView()
            let textField = NSTextField(labelWithString: formatDate(entry.timestamp))
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            return cellView
            
        case NSUserInterfaceItemIdentifier("citations"):
            let cellView = NSTableCellView()
            let textField = NSTextField(labelWithString: "\(entry.citationCount)")
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            return cellView
            
        case NSUserInterfaceItemIdentifier("change"):
            let cellView = NSTableCellView()
            let change = calculateChange(for: entry, at: row)
            let textField = NSTextField(labelWithString: change.text)
            textField.textColor = change.color
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            return cellView
            
        case NSUserInterfaceItemIdentifier("source"):
            let cellView = NSTableCellView()
            let textField = NSTextField(labelWithString: entry.source.displayName)
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            return cellView
            
        case NSUserInterfaceItemIdentifier("actions"):
            let cellView = NSTableCellView()
            let editButton = NSButton(title: "Edit", target: self, action: #selector(editEntryAtRow(_:)))
            editButton.tag = row
            editButton.bezelStyle = .rounded
            editButton.controlSize = .small
            editButton.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(editButton)
            NSLayoutConstraint.activate([
                editButton.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                editButton.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                editButton.widthAnchor.constraint(equalToConstant: 50)
            ])
            return cellView
            
        default:
            return nil
        }
    }
    
    @objc private func editEntryAtRow(_ sender: NSButton) {
        let row = sender.tag
        guard row < historyEntries.count else { return }
        
        let entry = historyEntries[row]
        showEditEntryDialog(for: entry)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func calculateChange(for entry: CitationHistory, at index: Int) -> (text: String, color: NSColor) {
        guard index < historyEntries.count - 1 else {
            return ("--", .labelColor)
        }
        
        let previousEntry = historyEntries[index + 1]
        let change = entry.citationCount - previousEntry.citationCount
        
        if change > 0 {
            return ("+\(change)", .systemGreen)
        } else if change < 0 {
            return ("\(change)", .systemRed)
        } else {
            return ("0", .systemYellow)
        }
    }
}

// MARK: - Dialog Methods
extension DataRepairViewController {
    private func showEditEntryDialog(for entry: CitationHistory) {
        let alert = NSAlert()
        alert.messageText = L("edit_entry_title")
        alert.informativeText = L("edit_entry_message")
        
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        
        let citationField = NSTextField()
        citationField.stringValue = "\(entry.citationCount)"
        citationField.frame = NSRect(x: 100, y: 30, width: 100, height: 24)
        
        let citationLabel = NSTextField(labelWithString: "Citations:")
        citationLabel.frame = NSRect(x: 0, y: 30, width: 90, height: 24)
        
        accessoryView.addSubview(citationLabel)
        accessoryView.addSubview(citationField)
        
        alert.accessoryView = accessoryView
        alert.addButton(withTitle: L("button_save"))
        alert.addButton(withTitle: L("button_cancel"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let newCount = Int(citationField.stringValue) {
                updateEntry(entry, newCitationCount: newCount)
            }
        }
    }
    
    private func showDeleteConfirmation(for entries: [CitationHistory]) {
        let alert = NSAlert()
        alert.messageText = L("delete_entries_title")
        alert.informativeText = L("delete_entries_message", entries.count)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("button_delete"))
        alert.addButton(withTitle: L("button_cancel"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            deleteEntries(entries)
        }
    }
    
    private func showRestoreConfirmation(to restorePoint: CitationHistory) {
        let alert = NSAlert()
        alert.messageText = L("restore_data_title")
        alert.informativeText = L("restore_data_message", formatDate(restorePoint.timestamp))
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("button_restore"))
        alert.addButton(withTitle: L("button_cancel"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            restoreToPoint(restorePoint)
        }
    }
    
    private func showRefreshFromPointConfirmation(from startPoint: CitationHistory) {
        let alert = NSAlert()
        alert.messageText = L("refresh_from_point_title")
        alert.informativeText = L("refresh_from_point_message", formatDate(startPoint.timestamp))
        alert.addButton(withTitle: L("button_refresh"))
        alert.addButton(withTitle: L("button_cancel"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            refreshFromPoint(startPoint)
        }
    }
}

// MARK: - Data Operations
extension DataRepairViewController {
    private func updateEntry(_ entry: CitationHistory, newCitationCount: Int) {
        let updatedEntry = CitationHistory(
            id: entry.id,
            scholarId: entry.scholarId,
            citationCount: newCitationCount,
            timestamp: entry.timestamp,
            source: entry.source,
            createdAt: entry.createdAt
        )
        
        historyManager.updateHistoryEntry(updatedEntry) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadHistoryData()
                    self?.showAlert("Entry updated successfully")
                case .failure(let error):
                    self?.showError("Update failed", error.localizedDescription)
                }
            }
        }
    }
    
    private func deleteEntries(_ entries: [CitationHistory]) {
        historyManager.deleteHistoryEntries(entries) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadHistoryData()
                    self?.showAlert("Entries deleted successfully")
                case .failure(let error):
                    self?.showError("Delete failed", error.localizedDescription)
                }
            }
        }
    }
    
    private func restoreToPoint(_ restorePoint: CitationHistory) {
        guard let scholar = currentScholar else { return }
        
        // Delete all entries after the restore point
        let entriesToDelete = historyEntries.filter { $0.timestamp > restorePoint.timestamp }
        
        historyManager.deleteHistoryEntries(entriesToDelete) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Update scholar's current citation count
                    var updatedScholar = scholar
                    updatedScholar.citations = restorePoint.citationCount
                    updatedScholar.lastUpdated = restorePoint.timestamp
                    
                    // Save updated scholar info
                    var allScholars = PreferencesManager.shared.scholars
                    if let index = allScholars.firstIndex(where: { $0.id == scholar.id }) {
                        allScholars[index] = updatedScholar
                        PreferencesManager.shared.scholars = allScholars
                    }
                    
                    self?.currentScholar = updatedScholar
                    self?.loadHistoryData()
                    self?.showAlert("Data restored successfully")
                    
                case .failure(let error):
                    self?.showError("Restore failed", error.localizedDescription)
                }
            }
        }
    }
    
    private func refreshFromPoint(_ startPoint: CitationHistory) {
        guard let scholar = currentScholar else { return }
        
        // This would trigger a data collection from the start point to now
        let googleScholarService = GoogleScholarService()
        googleScholarService.fetchAndSaveCitationCount(for: scholar.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadHistoryData()
                    self?.showAlert("Data refreshed successfully")
                case .failure(let error):
                    self?.showError("Refresh failed", error.localizedDescription)
                }
            }
        }
    }
}

