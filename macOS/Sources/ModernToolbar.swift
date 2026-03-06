import Cocoa

// MARK: - Modern Toolbar Component
// Design: Clean horizontal bar with subtle bottom border
// Three sections: left (context), center (controls), right (actions)
// Consistent 8px spacing between grouped items, 16px between sections
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
        // Subtle bottom border only — no full border
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func setupStackViews() {
        stackView.orientation = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .centerY
        stackView.spacing = DesignSpacing.md
        stackView.translatesAutoresizingMaskIntoConstraints = false

        [leftSection, centerSection, rightSection].forEach { section in
            section.orientation = .horizontal
            section.spacing = DesignSpacing.xs
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
            _ = self
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

        // Action buttons — ghost style, icon-only feel
        refreshButton.title = "Refresh"
        refreshButton.icon = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        refreshButton.style = .ghost
        refreshButton.onAction = { [weak self] in
            self?.onRefresh?()
        }

        exportButton.title = "Export"
        exportButton.icon = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Export")
        exportButton.style = .ghost
        exportButton.onAction = { [weak self] in
            self?.onExport?()
        }

        dataManagementButton.title = "Data"
        dataManagementButton.icon = NSImage(systemSymbolName: "tablecells", accessibilityDescription: "Data Management")
        dataManagementButton.style = .ghost
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
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignSpacing.xl),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignSpacing.xl),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: DesignSpacing.sm),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignSpacing.sm),

            heightAnchor.constraint(equalToConstant: DesignSpacing.toolbarHeight)
        ])
    }

    private func updateTheme() {
        // Background blends with surface
        layer?.backgroundColor = theme.colors.surface.cgColor

        // Bottom border only via sublayer
        layer?.sublayers?.filter { $0.name == "bottomBorder" }.forEach { $0.removeFromSuperlayer() }
        let borderLayer = CALayer()
        borderLayer.name = "bottomBorder"
        borderLayer.backgroundColor = theme.colors.border.withAlphaComponent(0.4).cgColor
        borderLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0.5)
        layer?.addSublayer(borderLayer)

        // Update all controls
        [scholarSelectionButton, timeRangeButton, chartTypeButton, themeButton].forEach {
            $0.theme = theme
        }

        [refreshButton, exportButton, dataManagementButton].forEach {
            $0.theme = theme
        }

        realTimeIndicator.theme = theme
    }

    override func layout() {
        super.layout()
        // Update bottom border width on resize
        layer?.sublayers?.first(where: { $0.name == "bottomBorder" })?.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0.5)
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
// Design: Minimal chrome — subtle background on hover, clean typography
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
        setupTracking()
        updateAppearance()

        target = self
        action = #selector(showDropdown)
    }

    private func setupSubviews() {
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear

        iconImageView.imageScaling = .scaleProportionallyDown

        let chevronConfig = NSImage.SymbolConfiguration(pointSize: 8, weight: .semibold)
        arrowImageView.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Dropdown")?
            .withSymbolConfiguration(chevronConfig)
        arrowImageView.imageScaling = .scaleProportionallyDown

        [iconImageView, titleLabel, arrowImageView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignSpacing.xs),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 14),
            iconImageView.heightAnchor.constraint(equalToConstant: 14),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: DesignSpacing.xxs),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            arrowImageView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: DesignSpacing.xxs),
            arrowImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignSpacing.xs),
            arrowImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 8),
            arrowImageView.heightAnchor.constraint(equalToConstant: 8),

            heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    private func setupTracking() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    private func updateAppearance() {
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 6.0

        titleLabel.textColor = theme.colors.textPrimary
        iconImageView.image = icon
        iconImageView.contentTintColor = theme.colors.textSecondary
        arrowImageView.contentTintColor = theme.colors.textSecondary.withAlphaComponent(0.6)
    }

    // Hover state — subtle background fill
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.layer?.backgroundColor = self.theme.colors.primary.withAlphaComponent(0.06).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.layer?.backgroundColor = NSColor.clear.cgColor
        }
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
        menu.font = NSFont.systemFont(ofSize: 12)
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
// Design: Ghost buttons for toolbar — icon + label, subtle hover
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
        setupTracking()
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

    private func setupTracking() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    private func updateAppearance() {
        layer?.cornerRadius = 6.0

        switch style {
        case .primary:
            layer?.backgroundColor = theme.colors.primary.cgColor
            contentTintColor = theme.colors.onPrimary
        case .secondary:
            layer?.backgroundColor = theme.colors.cardBackground.cgColor
            layer?.borderColor = theme.colors.border.withAlphaComponent(0.5).cgColor
            layer?.borderWidth = 0.5
            contentTintColor = theme.colors.textPrimary
        case .ghost:
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderWidth = 0
            contentTintColor = theme.colors.textSecondary
        }

        if let icon = icon {
            image = icon
            imagePosition = title.isEmpty ? .imageOnly : .imageLeft
        }

        font = NSFont.systemFont(ofSize: 12, weight: .medium)
    }

    // Hover — subtle fill for ghost, deeper for others
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard !isShowingProgress else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            switch self.style {
            case .ghost:
                self.layer?.backgroundColor = self.theme.colors.primary.withAlphaComponent(0.06).cgColor
                self.contentTintColor = self.theme.colors.textPrimary
            case .secondary:
                self.layer?.backgroundColor = self.theme.colors.primary.withAlphaComponent(0.04).cgColor
            case .primary:
                self.layer?.backgroundColor = self.theme.colors.primary.withAlphaComponent(0.85).cgColor
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard !isShowingProgress else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.updateAppearance()
        }
    }

    @objc private func buttonPressed() {
        // Tactile press feedback
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.06
            self.layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                self.layer?.transform = CATransform3DIdentity
            }
        }
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
// Design: Breathing dot with label — clean status communication
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
    private let label = NSTextField(labelWithString: "Live")

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
        statusDot.layer?.cornerRadius = 3
        statusDot.translatesAutoresizingMaskIntoConstraints = false

        label.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(statusDot)
        addSubview(label)

        NSLayoutConstraint.activate([
            statusDot.leadingAnchor.constraint(equalTo: leadingAnchor),
            statusDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 6),
            statusDot.heightAnchor.constraint(equalToConstant: 6),

            label.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: DesignSpacing.xxs),
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
        statusDot.layer?.backgroundColor = isEnabled ? theme.colors.success.cgColor : theme.colors.textSecondary.withAlphaComponent(0.3).cgColor
        label.stringValue = isEnabled ? "Live" : "Paused"
        label.textColor = isEnabled ? theme.colors.success : theme.colors.textSecondary

        if isEnabled {
            startPulseAnimation()
        } else {
            statusDot.layer?.removeAllAnimations()
        }
    }

    private func startPulseAnimation() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.35
        animation.duration = 1.2
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        statusDot.layer?.add(animation, forKey: "pulse")
    }
}
