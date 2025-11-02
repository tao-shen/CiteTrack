import Cocoa

// MARK: - Modern Toolbar Component
class ModernToolbar: NSView {
    
    // MARK: - UI Components
    private let stackView = NSStackView()
    private let leftSection = NSStackView()
    private let centerSection = NSStackView()
    private let rightSection = NSStackView()
    
    // Scholar selection
    private let scholarSelectionButton = ModernDropdownButton()
    
    // Time range selection
    private let timeRangeButton = ModernDropdownButton()
    
    // Chart type selection
    private let chartTypeButton = ModernDropdownButton()
    
    // Theme selection
    private let themeButton = ModernDropdownButton()
    
    // Action buttons
    private let refreshButton = ModernActionButton()
    private let exportButton = ModernActionButton()
    private let dataManagementButton = ModernActionButton()
    
    // Real-time indicator
    private let realTimeIndicator = RealTimeIndicator()
    
    // MARK: - Properties
    var theme: ChartTheme = .academic {
        didSet {
            updateTheme()
        }
    }
    
    // Callbacks
    var onScholarChanged: ((Scholar) -> Void)?
    var onTimeRangeChanged: ((TimeRange) -> Void)?
    var onChartTypeChanged: ((ChartType) -> Void)?
    var onThemeChanged: ((ChartTheme) -> Void)?
    var onRefresh: (() -> Void)?
    var onExport: (() -> Void)?
    var onDataManagement: (() -> Void)?
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupToolbar()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupToolbar()
    }
    
    // MARK: - Setup
    private func setupToolbar() {
        wantsLayer = true
        setupBackground()
        setupStackViews()
        setupControls()
        setupLayout()
        updateTheme()
    }
    
    private func setupBackground() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.cornerRadius = 0
    }
    
    private func setupStackViews() {
        // Main stack view
        stackView.orientation = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .centerY
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Section stack views
        [leftSection, centerSection, rightSection].forEach { section in
            section.orientation = .horizontal
            section.spacing = 12
            section.alignment = .centerY
        }
        
        stackView.addArrangedSubview(leftSection)
        stackView.addArrangedSubview(centerSection)
        stackView.addArrangedSubview(rightSection)
        
        addSubview(stackView)
    }
    
    private func setupControls() {
        // Scholar selection
        scholarSelectionButton.title = "Select Scholar"
        scholarSelectionButton.icon = NSImage(systemSymbolName: "person.circle", accessibilityDescription: "Scholar")
        scholarSelectionButton.onSelect = { [weak self] index in
            // Handle scholar selection
        }
        
        // Time range selection
        timeRangeButton.title = "Last Month"
        timeRangeButton.icon = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Time Range")
        timeRangeButton.options = TimeRange.allCases.map { $0.displayName }
        timeRangeButton.onSelect = { [weak self] index in
            let timeRange = TimeRange.allCases[index]
            self?.onTimeRangeChanged?(timeRange)
        }
        
        // Chart type selection
        chartTypeButton.title = "Line Chart"
        chartTypeButton.icon = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: "Chart Type")
        chartTypeButton.options = ChartType.allCases.map { $0.displayName }
        chartTypeButton.onSelect = { [weak self] index in
            let chartType = ChartType.allCases[index]
            self?.onChartTypeChanged?(chartType)
        }
        
        // Theme selection
        themeButton.title = "Academic"
        themeButton.icon = NSImage(systemSymbolName: "paintbrush", accessibilityDescription: "Theme")
        themeButton.options = ChartTheme.allCases.map { $0.displayName }
        themeButton.onSelect = { [weak self] index in
            let theme = ChartTheme.allCases[index]
            self?.theme = theme
            self?.onThemeChanged?(theme)
        }
        
        // Action buttons
        refreshButton.title = "Refresh"
        refreshButton.icon = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        refreshButton.style = .secondary
        refreshButton.onAction = { [weak self] in
            self?.onRefresh?()
        }
        
        exportButton.title = "Export"
        exportButton.icon = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Export")
        exportButton.style = .secondary
        exportButton.onAction = { [weak self] in
            self?.onExport?()
        }
        
        dataManagementButton.title = "Data"
        dataManagementButton.icon = NSImage(systemSymbolName: "tablecells", accessibilityDescription: "Data Management")
        dataManagementButton.style = .secondary
        dataManagementButton.onAction = { [weak self] in
            self?.onDataManagement?()
        }
        
        // Add to sections
        leftSection.addArrangedSubview(scholarSelectionButton)
        
        centerSection.addArrangedSubview(timeRangeButton)
        centerSection.addArrangedSubview(chartTypeButton)
        centerSection.addArrangedSubview(themeButton)
        
        rightSection.addArrangedSubview(refreshButton)
        rightSection.addArrangedSubview(exportButton)
        rightSection.addArrangedSubview(dataManagementButton)
        rightSection.addArrangedSubview(realTimeIndicator)
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            
            heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func updateTheme() {
        layer?.backgroundColor = theme.colors.surface.cgColor
        layer?.borderColor = theme.colors.gridLines.cgColor
        
        // Update all controls
        [scholarSelectionButton, timeRangeButton, chartTypeButton, themeButton].forEach {
            $0.theme = theme
        }
        
        [refreshButton, exportButton, dataManagementButton].forEach {
            $0.theme = theme
        }
        
        realTimeIndicator.theme = theme
    }
    
    // MARK: - Public Methods
    func updateScholarList(_ scholars: [Scholar], selectedScholar: Scholar?) {
        scholarSelectionButton.options = scholars.map { $0.name }
        scholarSelectionButton.isEnabled = !scholars.isEmpty

        if let selected = selectedScholar,
           let index = scholars.firstIndex(where: { $0.id == selected.id }) {
            scholarSelectionButton.setSelectedIndex(index, title: selected.name)
        } else if let first = scholars.first {
            scholarSelectionButton.setSelectedIndex(0, title: first.name)
        } else {
            scholarSelectionButton.setDisplayTitle(L("menu_no_scholars"))
        }

        scholarSelectionButton.onSelect = { [weak self] index in
            guard scholars.indices.contains(index) else { return }
            let scholar = scholars[index]
            self?.onScholarChanged?(scholar)
        }
    }
    
    func updateTimeRangeSelection(selectedRange: TimeRange, customLabel: String? = nil) {
        if let index = TimeRange.allCases.firstIndex(of: selectedRange) {
            timeRangeButton.setSelectedIndex(index, title: customLabel ?? selectedRange.displayName)
        } else {
            timeRangeButton.setDisplayTitle(customLabel ?? selectedRange.displayName)
        }
    }
    
    func updateChartTypeSelection(_ chartType: ChartType) {
        if let index = ChartType.allCases.firstIndex(of: chartType) {
            chartTypeButton.setSelectedIndex(index)
        }
    }
    
    func updateThemeSelection(_ theme: ChartTheme) {
        if let index = ChartTheme.allCases.firstIndex(of: theme) {
            themeButton.setSelectedIndex(index, title: theme.displayName)
        } else {
            themeButton.setDisplayTitle(theme.displayName)
        }
    }

    func setRealTimeStatus(_ isEnabled: Bool) {
        realTimeIndicator.isEnabled = isEnabled
    }
    
    func showRefreshProgress() {
        refreshButton.showProgress()
    }
    
    func hideRefreshProgress() {
        refreshButton.hideProgress()
    }
}

// MARK: - Modern Dropdown Button
class ModernDropdownButton: NSButton {
    
    // MARK: - Properties
    var options: [String] = []
    var selectedIndex: Int = 0
    var onSelect: ((Int) -> Void)?
    var icon: NSImage?
    
    var theme: ChartTheme = .academic {
        didSet {
            updateAppearance()
        }
    }
    
    private let titleLabel = NSTextField(labelWithString: "")
    private let iconImageView = NSImageView()
    private let arrowImageView = NSImageView()
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        wantsLayer = true
        bezelStyle = .rounded
        isBordered = false
        
        setupSubviews()
        setupLayout()
        updateAppearance()
        
        target = self
        action = #selector(showDropdown)
    }
    
    private func setupSubviews() {
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        
        iconImageView.imageScaling = .scaleAxesIndependently
        
        arrowImageView.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Dropdown")
        arrowImageView.imageScaling = .scaleAxesIndependently
        
        [iconImageView, titleLabel, arrowImageView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            arrowImageView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            arrowImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            arrowImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 12),
            arrowImageView.heightAnchor.constraint(equalToConstant: 12),
            
            heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func updateAppearance() {
        layer?.backgroundColor = theme.colors.surface.cgColor
        layer?.borderColor = theme.colors.gridLines.cgColor
        layer?.borderWidth = 1.0
        layer?.cornerRadius = 6.0
        
        titleLabel.textColor = theme.colors.textPrimary
        iconImageView.image = icon
        arrowImageView.contentTintColor = theme.colors.textSecondary
    }
    
    func setDisplayTitle(_ text: String) {
        title = text
        titleLabel.stringValue = text
    }
    
    func setSelectedIndex(_ index: Int, title customTitle: String? = nil) {
        selectedIndex = index
        let displayTitle: String
        if let customTitle = customTitle {
            displayTitle = customTitle
        } else if options.indices.contains(index) {
            displayTitle = options[index]
        } else {
            displayTitle = self.title
        }
        setDisplayTitle(displayTitle)
    }
 
    @objc private func showDropdown() {
        guard !options.isEmpty else { return }
        
        let menu = NSMenu()
        for (index, option) in options.enumerated() {
            let item = NSMenuItem(title: option, action: #selector(selectOption(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = index == selectedIndex ? .on : .off
            menu.addItem(item)
        }
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height), in: self)
    }
    
    @objc private func selectOption(_ sender: NSMenuItem) {
        selectedIndex = sender.tag
        setDisplayTitle(options[selectedIndex])
        onSelect?(selectedIndex)
    }
}

// MARK: - Modern Action Button
class ModernActionButton: NSButton {
    
    enum Style {
        case primary
        case secondary
        case ghost
    }
    
    // MARK: - Properties
    var style: Style = .primary {
        didSet {
            updateAppearance()
        }
    }
    
    var theme: ChartTheme = .academic {
        didSet {
            updateAppearance()
        }
    }
    
    var icon: NSImage? {
        didSet {
            updateAppearance()
        }
    }
    
    var onAction: (() -> Void)?
    
    private let progressIndicator = NSProgressIndicator()
    private var isShowingProgress = false
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        wantsLayer = true
        bezelStyle = .rounded
        isBordered = false
        
        setupProgressIndicator()
        updateAppearance()
        
        target = self
        action = #selector(buttonPressed)
    }
    
    private func setupProgressIndicator() {
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.isHidden = true
        addSubview(progressIndicator)
        
        NSLayoutConstraint.activate([
            progressIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    private func updateAppearance() {
        layer?.cornerRadius = 6.0
        
        switch style {
        case .primary:
            layer?.backgroundColor = theme.colors.primary.cgColor
            contentTintColor = theme.colors.onPrimary
        case .secondary:
            layer?.backgroundColor = theme.colors.surface.cgColor
            layer?.borderColor = theme.colors.gridLines.cgColor
            layer?.borderWidth = 1.0
            contentTintColor = theme.colors.textPrimary
        case .ghost:
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderWidth = 0
            contentTintColor = theme.colors.primary
        }
        
        if let icon = icon {
            image = icon
            imagePosition = title.isEmpty ? .imageOnly : .imageLeft
        }
        
        font = NSFont.systemFont(ofSize: 13, weight: .medium)
    }
    
    @objc private func buttonPressed() {
        onAction?()
    }
    
    func showProgress() {
        isShowingProgress = true
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        image = nil
        title = ""
    }
    
    func hideProgress() {
        isShowingProgress = false
        progressIndicator.isHidden = true
        progressIndicator.stopAnimation(nil)
        updateAppearance()
    }
}

// MARK: - Real-Time Indicator
class RealTimeIndicator: NSView {
    
    // MARK: - Properties
    var theme: ChartTheme = .academic {
        didSet {
            updateAppearance()
        }
    }
    
    var isEnabled: Bool = false {
        didSet {
            updateStatus()
        }
    }
    
    private let statusDot = NSView()
    private let label = NSTextField(labelWithString: "Real-time")
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupIndicator()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupIndicator()
    }
    
    private func setupIndicator() {
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 4
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(statusDot)
        addSubview(label)
        
        NSLayoutConstraint.activate([
            statusDot.leadingAnchor.constraint(equalTo: leadingAnchor),
            statusDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),
            
            label.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        updateAppearance()
        updateStatus()
    }
    
    private func updateAppearance() {
        label.textColor = theme.colors.textSecondary
    }
    
    private func updateStatus() {
        statusDot.layer?.backgroundColor = isEnabled ? theme.colors.success.cgColor : theme.colors.textSecondary.cgColor
        label.stringValue = isEnabled ? "Real-time: ON" : "Real-time: OFF"
        
        if isEnabled {
            startPulseAnimation()
        } else {
            statusDot.layer?.removeAllAnimations()
        }
    }
    
    private func startPulseAnimation() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.3
        animation.duration = 1.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        
        statusDot.layer?.add(animation, forKey: "pulse")
    }
}