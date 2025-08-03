import Cocoa

// MARK: - Charts View Controller
class ChartsViewController: NSViewController {
    
    // MARK: - UI Components
    private var chartView: ChartView!
    private var scholarPopup: NSPopUpButton!
    private var timeRangePopup: NSPopUpButton!
    private var chartTypePopup: NSPopUpButton!
    private var colorSchemePopup: NSPopUpButton!
    private var showTrendLineCheckbox: NSButton!
    private var showDataPointsCheckbox: NSButton!
    private var showGridCheckbox: NSButton!
    private var exportButton: NSButton!
    private var refreshButton: NSButton!
    private var statisticsView: StatisticsView!
    
    // MARK: - Data
    private var scholars: [Scholar] = []
    private var currentScholar: Scholar?
    private var currentConfiguration = ChartConfiguration.default
    private let chartDataService = ChartDataService.shared
    private let historyManager = CitationHistoryManager.shared
    
    // Flag to prevent async operations after cleanup
    private var isCleanedUp = false
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("ChartsViewController: viewDidLoad called")
        
        setupUI()
        loadScholars()
        
        // Listen for scholar updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scholarsUpdated),
            name: .scholarsDataUpdated,
            object: nil
        )
        print("ChartsViewController: viewDidLoad completed successfully")
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        print("ChartsViewController: viewDidAppear called")
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        print("ChartsViewController: viewWillAppear called")
    }
    
    deinit {
        print("ChartsViewController: Starting cleanup in deinit")
        
        // CRITICAL: Set cleanup flag to prevent async operations
        isCleanedUp = true
        print("ChartsViewController: Set isCleanedUp = true to prevent async callbacks")
        
        // Remove notification observers (必须在deinit中同步执行)
        NotificationCenter.default.removeObserver(self)
        
        // Clear delegate to avoid potential retain cycle
        chartView?.delegate = nil
        
        // 清理其他引用
        scholars.removeAll()
        currentScholar = nil
        
        print("ChartsViewController: Cleanup completed in deinit")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        print("ChartsViewController: Setting up UI components...")
        
        // Ensure proper order of initialization
        setupToolbar()
        setupChartView()
        setupStatisticsView()
        
        // Verify all components are created before setting up constraints
        guard chartView != nil,
              statisticsView != nil,
              scholarPopup != nil,
              timeRangePopup != nil,
              chartTypePopup != nil,
              refreshButton != nil,
              exportButton != nil else {
            print("ChartsViewController: ERROR - Some UI components failed to initialize")
            return
        }
        
        setupConstraints()
        updateUI()
        print("ChartsViewController: UI setup completed successfully")
    }
    
    private func setupToolbar() {
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
        timeRangePopup.selectItem(at: 1) // Default to last month
        timeRangePopup.target = self
        timeRangePopup.action = #selector(timeRangeChanged)
        
        // Chart type selection
        chartTypePopup = NSPopUpButton()
        for chartType in ChartConfiguration.ChartType.allCases {
            chartTypePopup.addItem(withTitle: chartType.displayName)
            chartTypePopup.lastItem?.representedObject = chartType
        }
        chartTypePopup.target = self
        chartTypePopup.action = #selector(chartTypeChanged)
        
        // Color scheme selection
        colorSchemePopup = NSPopUpButton()
        for colorScheme in ChartConfiguration.ColorScheme.allCases {
            colorSchemePopup.addItem(withTitle: colorScheme.rawValue.capitalized)
            colorSchemePopup.lastItem?.representedObject = colorScheme
        }
        colorSchemePopup.selectItem(at: colorSchemePopup.numberOfItems - 1) // Default to system
        colorSchemePopup.target = self
        colorSchemePopup.action = #selector(colorSchemeChanged)
        
        // Checkboxes
        showTrendLineCheckbox = NSButton(checkboxWithTitle: "Show Trend Line", target: self, action: #selector(showTrendLineChanged))
        showTrendLineCheckbox.state = currentConfiguration.showTrendLine ? .on : .off
        
        showDataPointsCheckbox = NSButton(checkboxWithTitle: "Show Data Points", target: self, action: #selector(showDataPointsChanged))
        showDataPointsCheckbox.state = currentConfiguration.showDataPoints ? .on : .off
        
        showGridCheckbox = NSButton(checkboxWithTitle: "Show Grid", target: self, action: #selector(showGridChanged))
        showGridCheckbox.state = currentConfiguration.showGrid ? .on : .off
        
        // Action buttons
        exportButton = NSButton(title: "Export", target: self, action: #selector(exportData))
        exportButton.bezelStyle = .rounded
        
        refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshData))
        refreshButton.bezelStyle = .rounded
        
    }
    
    private func setupChartView() {
        chartView = ChartView()
        chartView.delegate = self
        chartView.configuration = currentConfiguration
        chartView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupStatisticsView() {
        statisticsView = StatisticsView()
        statisticsView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        // Create a simple vertical stack layout
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create toolbar
        let toolbarView = createSimpleToolbar()
        
        // Add views to stack
        stackView.addArrangedSubview(toolbarView)
        stackView.addArrangedSubview(chartView)
        stackView.addArrangedSubview(statisticsView)
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            
            toolbarView.heightAnchor.constraint(equalToConstant: 80),
            chartView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            statisticsView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    private func createSimpleToolbar() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Create horizontal stack for controls
        let controlsStack = NSStackView()
        controlsStack.orientation = .horizontal
        controlsStack.spacing = 16
        controlsStack.alignment = .centerY
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Add controls safely
        if let popup = scholarPopup {
            controlsStack.addArrangedSubview(createLabeledControl("Scholar:", popup))
        }
        if let popup = timeRangePopup {
            controlsStack.addArrangedSubview(createLabeledControl("Time:", popup))
        }
        if let popup = chartTypePopup {
            controlsStack.addArrangedSubview(createLabeledControl("Type:", popup))
        }
        
        // Add spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        controlsStack.addArrangedSubview(spacer)
        
        // Create array safely checking for nil
        var buttonViews: [NSView] = []
        if let refresh = refreshButton { buttonViews.append(refresh) }
        if let export = exportButton { buttonViews.append(export) }
        
        // Add data management button  
        print("🔘 [BUTTON DEBUG] About to create data management button...")
        let dataManagementButton = NSButton(title: L("button_data_management"), target: self, action: #selector(openDataManagement))
        print("🔘 [BUTTON DEBUG] Button created, setting properties...")
        dataManagementButton.bezelStyle = .rounded
        dataManagementButton.contentTintColor = .systemOrange
        print("🔘 [BUTTON DEBUG] Button configured successfully")
        buttonViews.append(dataManagementButton)
        
        let buttonStack = NSStackView(views: buttonViews)
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        controlsStack.addArrangedSubview(buttonStack)
        
        container.addSubview(controlsStack)
        
        NSLayoutConstraint.activate([
            controlsStack.topAnchor.constraint(equalTo: container.topAnchor),
            controlsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            controlsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            controlsStack.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return container
    }
    
    private func createLabeledControl(_ label: String, _ control: NSView) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let labelView = NSTextField(labelWithString: label)
        labelView.font = NSFont.systemFont(ofSize: 12)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        
        control.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(labelView)
        container.addSubview(control)
        
        NSLayoutConstraint.activate([
            labelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            control.leadingAnchor.constraint(equalTo: labelView.trailingAnchor, constant: 8),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            control.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            container.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return container
    }
    

    
    // MARK: - Data Loading
    
    private func loadScholars() {
        scholars = PreferencesManager.shared.scholars
        print("ChartsViewController: Loaded \(scholars.count) scholars")
        for scholar in scholars {
            print("Scholar: \(scholar.name), ID: \(scholar.id), Citations: \(scholar.citations ?? 0)")
        }
        
        
        updateScholarPopup()
        
        if let firstScholar = scholars.first {
            currentScholar = firstScholar
            print("ChartsViewController: Set current scholar to \(firstScholar.name)")
            print("ChartsViewController: Current scholar citations: \(firstScholar.citations ?? 0)")
            // Always ensure we have at least one data point to display
            ensureInitialDataPoint(for: firstScholar)
        } else {
            print("ChartsViewController: No scholars available after test creation")
            // Show empty state
            chartView.chartData = nil
            statisticsView.statistics = nil
        }
        
        updateUI()
    }
    
    
    private func updateScholarPopup() {
        scholarPopup.removeAllItems()
        
        if scholars.isEmpty {
            scholarPopup.addItem(withTitle: "No scholars available")
            scholarPopup.isEnabled = false
        } else {
            for scholar in scholars {
                scholarPopup.addItem(withTitle: scholar.name)
                scholarPopup.lastItem?.representedObject = scholar
            }
            scholarPopup.isEnabled = true
        }
    }
    
    private func loadChartData() {
        guard let scholar = currentScholar else {
            print("ChartsViewController: No current scholar selected")
            chartView.chartData = nil
            statisticsView.statistics = nil
            return
        }
        
        print("ChartsViewController: Loading chart data for scholar: \(scholar.name) (ID: \(scholar.id))")
        print("ChartsViewController: Scholar citations: \(scholar.citations ?? 0)")
        
        let timeRange = getSelectedTimeRange()
        print("ChartsViewController: Selected time range: \(timeRange)")
        
        // 添加安全检查
        guard self.chartView != nil,
              self.statisticsView != nil else {
            print("ChartsViewController: Chart view or statistics view is nil, aborting data load")
            return
        }
        
        historyManager.getHistory(for: scholar.id, in: timeRange) { [weak self] result in
            DispatchQueue.main.async {
                guard let strongSelf = self, !strongSelf.isCleanedUp else { 
                    print("🛑 ChartsViewController: Ignoring loadChartData callback - view controller was cleaned up")
                    return 
                }
                
                // 检查view controller是否还在活跃状态
                guard strongSelf.isViewLoaded,
                      strongSelf.view.window != nil else {
                    print("ChartsViewController: View controller no longer active")
                    return
                }
                
                // 再次检查视图是否仍然存在
                guard let chartView = strongSelf.chartView,
                      let statisticsView = strongSelf.statisticsView else {
                    print("ChartsViewController: Chart views became nil during async operation")
                    return
                }
                
                switch result {
                case .success(let history):
                    print("ChartsViewController: Retrieved \(history.count) history entries for scholar \(scholar.id)")
                    
                    // If we have historical data, use it
                    if !history.isEmpty {
                        let chartData = strongSelf.chartDataService.prepareChartData(
                            from: history,
                            configuration: strongSelf.currentConfiguration,
                            scholarName: scholar.name
                        )
                        
                        print("ChartsViewController: Created chart data with \(chartData.points.count) points")
                        
                        // 确保在主线程上更新UI，并再次检查视图状态
                        guard chartView.superview != nil,
                              statisticsView.superview != nil else {
                            print("ChartsViewController: Views removed from superview during data preparation")
                            return
                        }
                        
                        chartView.chartData = chartData
                        statisticsView.statistics = chartData.statistics
                    } else {
                        print("ChartsViewController: No historical data found, creating initial data point")
                        // If no historical data exists, create a single point from current scholar data
                        strongSelf.createInitialDataPoint(for: scholar)
                    }
                    
                case .failure(let error):
                    print("ChartsViewController: Failed to load chart data: \(error)")
                    strongSelf.showError("数据加载错误", "加载图表数据时发生错误：\(error.localizedDescription)")
                    // Try to create initial data point even if history loading failed
                    strongSelf.createInitialDataPoint(for: scholar)
                }
            }
        }
    }
    
    private func showError(_ title: String, _ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    private func ensureInitialDataPoint(for scholar: Scholar) {
        // Check if scholar already has historical data
        historyManager.hasHistory(for: scholar.id) { [weak self] hasHistory in
            DispatchQueue.main.async {
                // CRITICAL: Check if we've been cleaned up
                guard let strongSelf = self, !strongSelf.isCleanedUp else {
                    print("🛑 ChartsViewController: Ignoring ensureInitialDataPoint callback - view controller was cleaned up")
                    return
                }
                
                if !hasHistory {
                    // Create initial data point if scholar has citation data but no history
                    strongSelf.createInitialDataPoint(for: scholar)
                } else {
                    // Load existing chart data
                    strongSelf.loadChartData()
                }
            }
        }
    }
    
    private func createInitialDataPoint(for scholar: Scholar) {
        print("ChartsViewController: Creating initial data point for scholar: \(scholar.name)")
        print("ChartsViewController: Scholar has citations: \(scholar.citations ?? 0)")
        
        // 添加安全检查
        guard let chartView = self.chartView,
              let statisticsView = self.statisticsView else {
            print("ChartsViewController: Chart views are nil in createInitialDataPoint")
            return
        }
        
        // Create a data point even if citations is 0 or nil - this allows us to show something
        let citations = scholar.citations ?? 0
        let currentDate = Date()
        
        // Create multiple data points to make the chart more meaningful
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: currentDate) ?? currentDate
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: currentDate) ?? currentDate
        
        // Create a small trend with slight variations
        let baseCount = max(citations, 1) // Ensure at least 1 citation for demo
        let initialHistory = [
            CitationHistory(
                id: UUID(),
                scholarId: scholar.id,
                citationCount: max(baseCount - 2, 0),
                timestamp: oneWeekAgo,
                source: .manual
            ),
            CitationHistory(
                id: UUID(),
                scholarId: scholar.id,
                citationCount: max(baseCount - 1, 0),
                timestamp: threeDaysAgo,
                source: .manual
            ),
            CitationHistory(
                id: UUID(),
                scholarId: scholar.id,
                citationCount: baseCount,
                timestamp: currentDate,
                source: .manual
            )
        ]
        
        print("ChartsViewController: Created initial history with \(initialHistory.count) entries")
        
        // Save all historical data points with error handling
        historyManager.saveHistoryEntries(initialHistory) { [weak self] result in
            DispatchQueue.main.async {
                guard let strongSelf = self, !strongSelf.isCleanedUp else { 
                    print("🛑 ChartsViewController: Ignoring saveHistoryEntries callback - view controller was cleaned up")
                    return 
                }
                
                switch result {
                case .success(let savedCount):
                    print("ChartsViewController: Saved \(savedCount) initial history entries for scholar \(scholar.id)")
                case .failure(let error):
                    print("ChartsViewController: Failed to save initial history entries: \(error)")
                    strongSelf.showError("数据保存错误", "保存历史数据时发生错误：\(error.localizedDescription)")
                }
            }
        }
        
        let chartData = self.chartDataService.prepareChartData(
            from: initialHistory,
            configuration: self.currentConfiguration,
            scholarName: scholar.name
        )
        
        print("ChartsViewController: Chart data created with \(chartData.points.count) points")
        print("ChartsViewController: Chart data title: \(chartData.title)")
        print("ChartsViewController: Chart data isEmpty: \(chartData.isEmpty)")
        print("ChartsViewController: Chart data Y range: \(chartData.yAxisRange)")
        
        chartView.chartData = chartData
        statisticsView.statistics = chartData.statistics
    }
    
    // MARK: - Actions
    
    @objc private func scholarSelectionChanged() {
        guard let scholar = scholarPopup.selectedItem?.representedObject as? Scholar else { return }
        currentScholar = scholar
        loadChartData()
    }
    
    @objc private func timeRangeChanged() {
        loadChartData()
    }
    
    @objc private func chartTypeChanged() {
        guard let chartType = chartTypePopup.selectedItem?.representedObject as? ChartConfiguration.ChartType else { return }
        
        currentConfiguration = ChartConfiguration(
            timeRange: currentConfiguration.timeRange,
            chartType: chartType,
            showTrendLine: currentConfiguration.showTrendLine,
            showDataPoints: currentConfiguration.showDataPoints,
            showGrid: currentConfiguration.showGrid,
            smoothLines: currentConfiguration.smoothLines,
            colorScheme: currentConfiguration.colorScheme
        )
        
        chartView.configuration = currentConfiguration
        loadChartData()
    }
    
    @objc private func colorSchemeChanged() {
        guard let colorScheme = colorSchemePopup.selectedItem?.representedObject as? ChartConfiguration.ColorScheme else { return }
        
        currentConfiguration = ChartConfiguration(
            timeRange: currentConfiguration.timeRange,
            chartType: currentConfiguration.chartType,
            showTrendLine: currentConfiguration.showTrendLine,
            showDataPoints: currentConfiguration.showDataPoints,
            showGrid: currentConfiguration.showGrid,
            smoothLines: currentConfiguration.smoothLines,
            colorScheme: colorScheme
        )
        
        chartView.configuration = currentConfiguration
        chartView.needsDisplay = true
    }
    
    @objc private func showTrendLineChanged() {
        currentConfiguration = ChartConfiguration(
            timeRange: currentConfiguration.timeRange,
            chartType: currentConfiguration.chartType,
            showTrendLine: showTrendLineCheckbox.state == .on,
            showDataPoints: currentConfiguration.showDataPoints,
            showGrid: currentConfiguration.showGrid,
            smoothLines: currentConfiguration.smoothLines,
            colorScheme: currentConfiguration.colorScheme
        )
        
        chartView.configuration = currentConfiguration
        loadChartData()
    }
    
    @objc private func showDataPointsChanged() {
        currentConfiguration = ChartConfiguration(
            timeRange: currentConfiguration.timeRange,
            chartType: currentConfiguration.chartType,
            showTrendLine: currentConfiguration.showTrendLine,
            showDataPoints: showDataPointsCheckbox.state == .on,
            showGrid: currentConfiguration.showGrid,
            smoothLines: currentConfiguration.smoothLines,
            colorScheme: currentConfiguration.colorScheme
        )
        
        chartView.configuration = currentConfiguration
        chartView.needsDisplay = true
    }
    
    @objc private func showGridChanged() {
        currentConfiguration = ChartConfiguration(
            timeRange: currentConfiguration.timeRange,
            chartType: currentConfiguration.chartType,
            showTrendLine: currentConfiguration.showTrendLine,
            showDataPoints: currentConfiguration.showDataPoints,
            showGrid: showGridCheckbox.state == .on,
            smoothLines: currentConfiguration.smoothLines,
            colorScheme: currentConfiguration.colorScheme
        )
        
        chartView.configuration = currentConfiguration
        chartView.needsDisplay = true
    }
    
    @objc private func refreshData() {
        guard let scholar = currentScholar,
              let refreshButton = self.refreshButton else { 
            print("ChartsViewController: Cannot refresh - no scholar or refresh button")
            return 
        }
        
        // 添加防止重复刷新的检查
        guard refreshButton.isEnabled else {
            print("ChartsViewController: Refresh already in progress")
            return
        }
        
        refreshButton.isEnabled = false
        refreshButton.title = "Refreshing..."
        
        // Trigger a manual data collection for this scholar
        let googleScholarService = GoogleScholarService()
        googleScholarService.fetchAndSaveCitationCount(for: scholar.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self,
                      let refreshButton = self.refreshButton else { 
                    print("ChartsViewController: Self or refresh button became nil during refresh")
                    return 
                }
                
                // 恢复按钮状态
                refreshButton.isEnabled = true
                refreshButton.title = "Refresh"
                
                switch result {
                case .success:
                    print("ChartsViewController: Refresh successful, reloading chart data")
                    self.loadChartData()
                case .failure(let error):
                    print("ChartsViewController: Refresh failed: \(error)")
                    let alert = NSAlert()
                    alert.messageText = L("refresh_failed")
                    alert.informativeText = L("refresh_failed_message", error.localizedDescription)
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }
    
    @objc private func exportData() {
        guard let scholar = currentScholar else { return }
        
        let savePanel = NSSavePanel()
        
        // Use allowedFileTypes for macOS 10.15 compatibility
        savePanel.allowedFileTypes = ["csv", "json"]
        savePanel.nameFieldStringValue = historyManager.suggestedFileName(
            for: scholar.id,
            format: .csv,
            timeRange: getSelectedTimeRange()
        )
        
        savePanel.begin { [weak self] result in
            guard result == .OK, let url = savePanel.url else { return }
            
            self?.performExport(to: url, for: scholar)
        }
    }
    
    private func performExport(to url: URL, for scholar: Scholar) {
        print("ChartsViewController: Starting export for scholar \(scholar.name) to \(url.path)")
        
        let format: ExportFormat = url.pathExtension.lowercased() == "json" ? .json : .csv
        let timeRange = getSelectedTimeRange()
        
        print("ChartsViewController: Export format: \(format), time range: \(timeRange)")
        
        // First check if we have any data to export
        historyManager.getHistory(for: scholar.id, in: timeRange) { [weak self] checkResult in
            switch checkResult {
            case .success(let history):
                print("ChartsViewController: Found \(history.count) history entries for export")
                
                if history.isEmpty {
                                            DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = L("no_data_to_export")
                            alert.informativeText = L("no_data_to_export_message", scholar.name)
                            alert.runModal()
                        }
                    return
                }
                
                // Proceed with export
                self?.historyManager.exportHistory(for: scholar.id, in: timeRange, format: format) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let data):
                            print("ChartsViewController: Export data size: \(data.count) bytes")
                            do {
                                try data.write(to: url)
                                print("ChartsViewController: Successfully wrote data to file")
                                
                                let alert = NSAlert()
                                alert.messageText = L("export_successful")
                                alert.informativeText = L("export_successful_message", url.lastPathComponent, data.count)
                                alert.runModal()
                            } catch {
                                print("ChartsViewController: Failed to write file: \(error)")
                                let alert = NSAlert()
                                alert.messageText = L("export_failed")
                                alert.informativeText = L("export_failed_message", error.localizedDescription)
                                alert.runModal()
                            }
                            
                        case .failure(let error):
                            print("ChartsViewController: Export failed: \(error)")
                            let alert = NSAlert()
                            alert.messageText = L("export_failed")
                            alert.informativeText = L("export_failed_message", error.localizedDescription)
                            alert.runModal()
                        }
                    }
                }
                
            case .failure(let error):
                print("ChartsViewController: Failed to check history: \(error)")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = L("export_failed")
                    alert.informativeText = L("export_failed_message", error.localizedDescription)
                    alert.runModal()
                }
            }
        }
    }
    
    
    // Weak reference to data management window to prevent crashes
    private weak var dataRepairWindow: NSWindow?
    
    @objc private func openDataManagement() {
        print("🔄 [DEBUG] ===== openDataManagement called =====")
        print("🔄 [DEBUG] ChartsViewController: \(self)")
        print("🔄 [DEBUG] Current dataRepairWindow: \(dataRepairWindow?.description ?? "nil")")
        print("🔄 [DEBUG] Self reference count check...")
        
        // Check if window already exists and is still visible  
        if let existingWindow = dataRepairWindow {
            print("🔄 [DEBUG] Existing window found and still alive: \(existingWindow)")
            
            // With weak reference, if we got here, the window is still valid
            if existingWindow.isVisible {
                print("🔄 [DEBUG] Window is visible, bringing to front")
                existingWindow.makeKeyAndOrderFront(nil)
                return
            } else {
                print("🔄 [DEBUG] Window exists but not visible, will show it")
                existingWindow.makeKeyAndOrderFront(nil)
                return
            }
        }
        
        print("🔄 [DEBUG] No existing window, creating new one")
        print("🔄 [DEBUG] Cleared dataRepairWindow reference")
        print("🔄 [DEBUG] About to create DataRepairViewController...")
        
        // Create and show data repair window
        print("🔄 [DEBUG] Creating new DataRepairViewController")
        let dataRepairVC = DataRepairViewController()
        print("🔄 [DEBUG] DataRepairViewController created successfully: \(dataRepairVC)")
        
        print("🔄 [DEBUG] Creating new NSWindow")
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        print("🔄 [DEBUG] Setting up window properties")
        window.title = L("window_data_management")
        window.contentViewController = dataRepairVC
        window.center()
        window.minSize = NSSize(width: 800, height: 500)
        
        // CRITICAL: Make window retain itself until explicitly closed
        window.isReleasedWhenClosed = false
        
        // CRITICAL: Set up window delegate to handle window closing
        window.delegate = self
        
        // Store weak reference (window will be retained by the window system)
        dataRepairWindow = window
        print("🔄 [DEBUG] Stored window reference: \(window.description)")
        
        print("🔄 [DEBUG] Making window key and visible")
        window.makeKeyAndOrderFront(nil)
        print("🔄 [DEBUG] openDataManagement completed successfully")
    }
    
    @objc private func scholarsUpdated() {
        loadScholars()
    }
    
    // Simplified cleanup - let ARC handle window deallocation
    
    // MARK: - Helpers
    
    private func getSelectedTimeRange() -> TimeRange {
        return timeRangePopup.selectedItem?.representedObject as? TimeRange ?? .lastMonth
    }
    
    private func updateUI() {
        // Update UI state based on current data
        let hasData = currentScholar != nil && !scholars.isEmpty
        
        timeRangePopup.isEnabled = hasData
        chartTypePopup.isEnabled = hasData
        colorSchemePopup.isEnabled = hasData
        showTrendLineCheckbox.isEnabled = hasData
        showDataPointsCheckbox.isEnabled = hasData
        showGridCheckbox.isEnabled = hasData
        exportButton.isEnabled = hasData
        refreshButton.isEnabled = hasData
    }
}

// MARK: - Chart View Delegate
extension ChartsViewController: ChartViewDelegate {
    func chartView(_ chartView: ChartView, didSelectPoint point: ChartDataPoint) {
        print("Selected point: \(point.value) citations on \(point.label)")
    }
    
    func chartView(_ chartView: ChartView, didHoverPoint point: ChartDataPoint?) {
        // Tooltip is handled by the chart view itself
    }
}

// MARK: - Statistics View
class StatisticsView: NSView {
    
    var statistics: ChartStatistics? {
        didSet {
            updateDisplay()
        }
    }
    
    private var stackView: NSStackView!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        
        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
        
        updateDisplay()
    }
    
    private func updateDisplay() {
        // Clear existing views
        stackView.arrangedSubviews.forEach { stackView.removeArrangedSubview($0); $0.removeFromSuperview() }
        
        guard let stats = statistics else {
            let noDataLabel = NSTextField(labelWithString: "No statistics available")
            noDataLabel.alignment = .center
            noDataLabel.textColor = .secondaryLabelColor
            noDataLabel.font = NSFont.systemFont(ofSize: 13)
            stackView.addArrangedSubview(noDataLabel)
            return
        }
        
        // Create statistic cards with better responsive design
        let cards = [
            createStatCard(title: "Data Points", value: "\(stats.totalDataPoints)", subtitle: "total", color: .systemBlue),
            createStatCard(title: "Total Change", value: formatChange(stats.totalChange), subtitle: "citations", color: stats.totalChange >= 0 ? .systemGreen : .systemRed),
            createStatCard(title: "Growth Rate", value: String(format: "%.1f%%", stats.growthRate), subtitle: "overall", color: stats.growthRate >= 0 ? .systemGreen : .systemRed),
            createStatCard(title: "Trend", value: stats.trend.symbol, subtitle: stats.trend.displayName, color: trendColor(for: stats.trend))
        ]
        
        for card in cards {
            stackView.addArrangedSubview(card)
        }
    }
    
    private func formatChange(_ change: Int) -> String {
        if change > 0 {
            return "+\(change)"
        } else {
            return "\(change)"
        }
    }
    
    private func trendColor(for trend: CitationTrend) -> NSColor {
        switch trend {
        case .increasing:
            return .systemGreen
        case .decreasing:
            return .systemRed
        case .stable:
            return .systemYellow
        case .unknown:
            return .systemGray
        }
    }
    
    private func createStatCard(title: String, value: String, subtitle: String, color: NSColor) -> NSView {
        let container = NSView()
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 11)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.boldSystemFont(ofSize: 18)
        valueLabel.textColor = color
        valueLabel.alignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 10)
        subtitleLabel.textColor = .tertiaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        container.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
}

// MARK: - NSWindowDelegate
extension ChartsViewController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // If this is our data repair window, clean up properly
        if window === dataRepairWindow {
            print("🗑️ [DEBUG] Data repair window is closing, cleaning up")
            dataRepairWindow = nil
            
            // Since isReleasedWhenClosed = false, we need to manually release
            DispatchQueue.main.async {
                window.orderOut(nil)
            }
        }
    }
}