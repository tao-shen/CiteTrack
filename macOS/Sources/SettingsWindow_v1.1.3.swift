import Cocoa
import Foundation

@MainActor
class SettingsWindow: NSObject {
    private var window: NSWindow?
    private var dataManager: DataManager
    private var tableView: NSTableView!
    private var scholars: [Scholar] = []
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
        super.init()
        self.scholars = dataManager.scholars
    }
    
    func showWindow() {
        if window == nil {
            createWindow()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func createWindow() {
        // Create window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window?.title = "Settings"
        window?.center()
        
        // Create content view
        let contentView = NSView()
        window?.contentView = contentView
        
        // Create table view
        let scrollView = NSScrollView()
        tableView = NSTableView()
        
        // Configure table view
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("scholar"))
        column.title = "Scholar"
        column.width = 400
        tableView.addTableColumn(column)
        
        tableView.dataSource = self
        tableView.delegate = self
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        
        // Create buttons
        let addButton = NSButton(title: "Add Scholar", target: self, action: #selector(addScholar))
        let removeButton = NSButton(title: "Remove", target: self, action: #selector(removeScholar))
        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshData))
        
        // Layout
        contentView.addSubview(scrollView)
        contentView.addSubview(addButton)
        contentView.addSubview(removeButton)
        contentView.addSubview(refreshButton)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -20),
            
            addButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            addButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 10),
            removeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            refreshButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            refreshButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
    }
    
    @objc private func addScholar() {
        let alert = NSAlert()
        alert.messageText = "Add Scholar"
        alert.informativeText = "Please enter the Scholar ID (from Google Scholar profile URL)"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "Scholar ID"
        alert.accessoryView = input
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let scholarId = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !scholarId.isEmpty {
                let scholar = Scholar(id: scholarId)
                dataManager.addScholar(scholar)
                scholars = dataManager.scholars
                tableView.reloadData()
            }
        }
    }
    
    @objc private func removeScholar() {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < scholars.count {
            dataManager.removeScholar(at: selectedRow)
            scholars = dataManager.scholars
            tableView.reloadData()
        }
    }
    
    @objc private func refreshData() {
        Task { @MainActor in
            await dataManager.updateAllScholars()
            self.scholars = self.dataManager.scholars
            self.tableView.reloadData()
        }
    }
}

extension SettingsWindow: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return scholars.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let scholar = scholars[row]
        let citationText = scholar.citations.map { "\($0) citations" } ?? "Loading..."
        return "\(scholar.name): \(citationText)"
    }
}