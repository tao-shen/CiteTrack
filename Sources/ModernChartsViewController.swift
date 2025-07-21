import Cocoa

// MARK: - Modern Charts View Controller
class ModernChartsViewController: NSViewController {
    
    // MARK: - Modern UI Components
    private var modernToolbar: ModernToolbar!
    private var modernChartView: ModernChartView!
    private var dashboardView: DashboardView!
    private var insightPanel: InsightPanel!
    
    // MARK: - Data & State
    private var scholars: [Scholar] = []
    private var currentScholar: Scholar?
    private var currentTimeRange: TimeRange = .lastMonth
    private var currentChartType: ChartType = .line
    private var currentTheme: ChartTheme = .academic
    
    // Services
    private let chartDataService = ChartDataService()
    private let historyManager = CitationHistoryManager.shared
    
    // Animation & Interaction
    private var isDataLoading = false
    private var animationTimer: Timer?
    
    // Cleanup flag
    private var isCleanedUp = false
    
    // MARK: - Lifecycle
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("ModernChartsViewController: viewDidLoad called")
        
        setupModernUI()
        loadData()
        
        // Setup notifications
        setupNotifications()
        
        print("ModernChartsViewController: viewDidLoad completed")
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        animateViewAppearance()
    }
    
    deinit {
        print("ModernChartsViewController: Starting cleanup")
        isCleanedUp = true
        
        animationTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        
        print("ModernChartsViewController: Cleanup completed")
    }
    
    // MARK: - Modern UI Setup
    private func setupModernUI() {
        setupModernToolbar()
        setupModernChartView()
        setupDashboard()
        setupInsightPanel()
        setupLayout()
        setupTheme()
    }
    
    private func setupModernToolbar() {
        modernToolbar = ModernToolbar()
        modernToolbar.theme = currentTheme
        modernToolbar.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup callbacks
        modernToolbar.onScholarChanged = { [weak self] scholar in
            self?.selectScholar(scholar)
        }
        
        modernToolbar.onTimeRangeChanged = { [weak self] timeRange in
            self?.selectTimeRange(timeRange)
        }
        
        modernToolbar.onChartTypeChanged = { [weak self] chartType in
            self?.selectChartType(chartType)
        }
        
        modernToolbar.onThemeChanged = { [weak self] theme in
            self?.applyTheme(theme)
        }
        
        modernToolbar.onRefresh = { [weak self] in
            self?.refreshData()
        }
        
        modernToolbar.onExport = { [weak self] in
            self?.exportData()
        }
        
        modernToolbar.onDataManagement = { [weak self] in
            self?.openDataManagement()
        }
        
        view.addSubview(modernToolbar)
    }
    
    private func setupModernChartView() {
        modernChartView = ModernChartView()
        modernChartView.theme = currentTheme
        modernChartView.chartType = currentChartType
        modernChartView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(modernChartView)
    }
    
    private func setupDashboard() {
        dashboardView = DashboardView()
        dashboardView.theme = currentTheme
        dashboardView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(dashboardView)
    }
    
    private func setupInsightPanel() {
        insightPanel = InsightPanel()
        insightPanel.theme = currentTheme
        insightPanel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(insightPanel)
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            // Toolbar at top
            modernToolbar.topAnchor.constraint(equalTo: view.topAnchor),
            modernToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            modernToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Dashboard cards below toolbar
            dashboardView.topAnchor.constraint(equalTo: modernToolbar.bottomAnchor, constant: 16),
            dashboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            dashboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            dashboardView.heightAnchor.constraint(equalToConstant: 120),
            
            // Chart view in center
            modernChartView.topAnchor.constraint(equalTo: dashboardView.bottomAnchor, constant: 16),
            modernChartView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            modernChartView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -200),
            modernChartView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            
            // Insight panel on right
            insightPanel.topAnchor.constraint(equalTo: dashboardView.bottomAnchor, constant: 16),
            insightPanel.leadingAnchor.constraint(equalTo: modernChartView.trailingAnchor, constant: 16),
            insightPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            insightPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            insightPanel.widthAnchor.constraint(equalToConstant: 168)
        ])
    }
    
    private func setupTheme() {
        applyTheme(currentTheme)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scholarsUpdated),
            name: .scholarsDataUpdated,
            object: nil
        )
    }
    
    // MARK: - Data Management
    private func loadData() {
        scholars = PreferencesManager.shared.scholars
        
        if let firstScholar = scholars.first {
            currentScholar = firstScholar
        }
        
        updateToolbarData()
        loadChartData()
    }
    
    private func updateToolbarData() {
        modernToolbar.updateScholarList(scholars, selectedScholar: currentScholar)
        modernToolbar.setRealTimeStatus(true) // Configure based on settings
    }
    
    private func loadChartData() {
        guard let scholar = currentScholar else {
            clearChartData()
            return
        }
        
        isDataLoading = true
        modernToolbar.showRefreshProgress()
        
        historyManager.getHistory(for: scholar.id, in: currentTimeRange) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, !self.isCleanedUp else { return }
                
                self.isDataLoading = false
                self.modernToolbar.hideRefreshProgress()
                
                switch result {
                case .success(let history):
                    self.processChartData(history, for: scholar)
                case .failure(let error):
                    print("Failed to load chart data: \\(error)")
                    self.showError("数据加载失败", error.localizedDescription)
                }
            }
        }
    }
    
    private func processChartData(_ history: [CitationHistory], for scholar: Scholar) {
        let chartData = chartDataService.prepareChartData(
            from: history,
            configuration: ChartConfiguration(
                timeRange: currentTimeRange,
                chartType: currentChartType,
                theme: currentTheme
            ),
            scholarName: scholar.name
        )
        
        // Update all views with new data
        modernChartView.chartData = chartData
        dashboardView.updateStatistics(chartData.statistics, scholar: scholar)
        insightPanel.updateInsights(chartData.insights)
        
        // Animate chart appearance
        animateChartUpdate()
    }
    
    private func clearChartData() {
        modernChartView.chartData = nil
        dashboardView.clearStatistics()
        insightPanel.clearInsights()
    }
    
    // MARK: - User Actions
    private func selectScholar(_ scholar: Scholar) {
        guard scholar.id != currentScholar?.id else { return }
        
        currentScholar = scholar
        loadChartData()
        
        // Update UI with selection feedback
        provideHapticFeedback()
    }
    
    private func selectTimeRange(_ timeRange: TimeRange) {
        guard timeRange != currentTimeRange else { return }
        
        currentTimeRange = timeRange
        loadChartData()
        
        provideHapticFeedback()
    }
    
    private func selectChartType(_ chartType: ChartType) {
        guard chartType != currentChartType else { return }
        
        currentChartType = chartType
        modernChartView.chartType = chartType
        
        provideHapticFeedback()
    }
    
    private func applyTheme(_ theme: ChartTheme) {
        guard theme != currentTheme else { return }
        
        currentTheme = theme
        
        // Apply theme to all components
        modernToolbar.theme = theme
        modernChartView.theme = theme
        dashboardView.theme = theme
        insightPanel.theme = theme
        
        // Update view background
        view.layer?.backgroundColor = theme.colors.background.cgColor
        
        // Animate theme transition
        animateThemeChange()
    }
    
    private func refreshData() {
        guard !isDataLoading else { return }
        
        loadChartData()
        provideHapticFeedback()
        
        // Show refresh success animation
        showRefreshSuccessAnimation()
    }
    
    private func exportData() {
        guard let scholar = currentScholar else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText, .json]
        savePanel.nameFieldStringValue = "citations-\\(scholar.id)-\\(Date().formatted())"
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            
            self.performExport(to: url, scholar: scholar)
        }
    }
    
    private func performExport(to url: URL, scholar: Scholar) {
        // Implementation for data export
        historyManager.getHistory(for: scholar.id, in: currentTimeRange) { result in
            switch result {
            case .success(let history):
                self.exportHistory(history, to: url, scholar: scholar)
            case .failure(let error):
                DispatchQueue.main.async {
                    self.showError("导出失败", error.localizedDescription)
                }
            }
        }
    }
    
    private func exportHistory(_ history: [CitationHistory], to url: URL, scholar: Scholar) {
        do {
            let data: Data
            
            if url.pathExtension.lowercased() == "json" {
                data = try JSONEncoder().encode(history)
            } else {
                // CSV format
                var csvContent = "Date,Citations,Scholar\\n"
                for entry in history {
                    csvContent += "\\(entry.date),\\(entry.citationCount),\\(scholar.name)\\n"
                }
                data = csvContent.data(using: .utf8) ?? Data()
            }
            
            try data.write(to: url)
            
            DispatchQueue.main.async {
                self.showExportSuccessMessage(url: url)
            }
        } catch {
            DispatchQueue.main.async {
                self.showError("导出失败", error.localizedDescription)
            }
        }
    }
    
    private func openDataManagement() {
        // Create and show data management window using the existing logic
        let dataRepairVC = DataRepairViewController()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = L("window_data_management")
        window.contentViewController = dataRepairVC
        window.center()
        window.minSize = NSSize(width: 800, height: 500)
        window.isReleasedWhenClosed = false
        
        window.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - Animations
    private func animateViewAppearance() {
        // Staggered animation for components
        let components = [modernToolbar, dashboardView, modernChartView, insightPanel]
        
        for (index, component) in components.enumerated() {
            component?.layer?.opacity = 0
            component?.layer?.transform = CATransform3DMakeTranslation(0, 20, 0)
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                    component?.layer?.opacity = 1
                    component?.layer?.transform = CATransform3DIdentity
                }
            })
        }
    }
    
    private func animateChartUpdate() {
        modernChartView.layer?.removeAllAnimations()
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.95
        scaleAnimation.toValue = 1.0
        scaleAnimation.duration = 0.3
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        modernChartView.layer?.add(scaleAnimation, forKey: "chartUpdate")
    }
    
    private func animateThemeChange() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            view.layer?.backgroundColor = currentTheme.colors.background.cgColor
        })
    }
    
    private func showRefreshSuccessAnimation() {
        // Create a success indicator
        let successView = NSView(frame: NSRect(x: 0, y: 0, width: 60, height: 60))
        successView.wantsLayer = true
        successView.layer?.backgroundColor = currentTheme.colors.success.cgColor
        successView.layer?.cornerRadius = 30
        
        let checkmark = NSImageView(image: NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Success")!)
        checkmark.contentTintColor = .white
        checkmark.frame = NSRect(x: 20, y: 20, width: 20, height: 20)
        successView.addSubview(checkmark)
        
        view.addSubview(successView)
        successView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        
        // Animate appearance and disappearance
        successView.layer?.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
        successView.layer?.opacity = 0
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            successView.layer?.transform = CATransform3DIdentity
            successView.layer?.opacity = 1
        }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    successView.layer?.opacity = 0
                }) {
                    successView.removeFromSuperview()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func provideHapticFeedback() {
        // macOS doesn't have haptic feedback, but we can provide visual feedback
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            view.layer?.brightness = 0.05
        }) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.1
                self.view.layer?.brightness = 0
            })
        }
    }
    
    private func showError(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("button_ok"))
        alert.runModal()
    }
    
    private func showExportSuccessMessage(url: URL) {
        let alert = NSAlert()
        alert.messageText = "导出成功"
        alert.informativeText = "数据已保存至: \\(url.lastPathComponent)"
        alert.addButton(withTitle: L("button_ok"))
        alert.addButton(withTitle: "打开文件夹")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    @objc private func scholarsUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isCleanedUp else { return }
            self.loadData()
        }
    }
}

// MARK: - Extension for NSView center property
extension NSView {
    var center: CGPoint {
        get {
            return CGPoint(x: frame.midX, y: frame.midY)
        }
        set {
            frame.origin = CGPoint(
                x: newValue.x - frame.width / 2,
                y: newValue.y - frame.height / 2
            )
        }
    }
}

// MARK: - Chart Configuration
struct ChartConfiguration {
    let timeRange: TimeRange
    let chartType: ChartType
    let theme: ChartTheme
    
    static let `default` = ChartConfiguration(
        timeRange: .lastMonth,
        chartType: .line,
        theme: .academic
    )
}