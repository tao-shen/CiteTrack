import Cocoa

// MARK: - Dashboard View
class DashboardView: NSView {
    
    // MARK: - UI Components
    private let stackView = NSStackView()
    private var statisticsCards: [StatisticsCardView] = []
    
    // MARK: - Properties
    var theme: ChartTheme = .academic {
        didSet {
            updateTheme()
        }
    }
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDashboard()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDashboard()
    }
    
    // MARK: - Setup
    private func setupDashboard() {
        setupStackView()
        createStatisticsCards()
        setupLayout()
        updateTheme()
    }
    
    private func setupStackView() {
        stackView.orientation = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
    }
    
    private func createStatisticsCards() {
        // Create 4 statistics cards
        let cardTitles = ["Total Citations", "Monthly Change", "Growth Rate", "Trend"]
        
        for title in cardTitles {
            let card = StatisticsCardView()
            card.theme = theme
            statisticsCards.append(card)
            stackView.addArrangedSubview(card)
        }
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func updateTheme() {
        statisticsCards.forEach { card in
            card.theme = theme
        }
    }
    
    // MARK: - Public Methods
    func updateStatistics(_ statistics: ChartStatistics?, scholar: Scholar) {
        guard let stats = statistics else {
            clearStatistics()
            return
        }
        
        let statisticsData = [
            StatisticData(
                title: "Total Citations",
                value: scholar.citations ?? 0,
                subtitle: "all time",
                icon: NSImage(systemSymbolName: "quote.bubble", accessibilityDescription: "Citations"),
                change: nil,
                type: .number
            ),
            StatisticData(
                title: "Monthly Change",
                value: stats.totalChange,
                subtitle: "this period",
                icon: NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: "Change"),
                change: StatisticChange(value: stats.growthRate, isPositive: stats.totalChange >= 0),
                type: .number
            ),
            StatisticData(
                title: "Growth Rate",
                value: stats.growthRate,
                subtitle: "percentage",
                icon: NSImage(systemSymbolName: "percent", accessibilityDescription: "Growth"),
                change: nil,
                type: .percentage
            ),
            StatisticData(
                title: "Trend",
                value: stats.trend.symbol,
                subtitle: stats.trend.displayName,
                icon: trendIcon(for: stats.trend),
                change: nil,
                type: .text
            )
        ]
        
        // Update cards with animation
        for (index, cardData) in statisticsData.enumerated() {
            if index < statisticsCards.count {
                statisticsCards[index].statistic = cardData
                
                // Staggered animation
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                    self.statisticsCards[index].animateIn()
                }
            }
        }
    }
    
    func clearStatistics() {
        statisticsCards.forEach { card in
            card.statistic = nil
        }
    }
    
    private func trendIcon(for trend: CitationTrend) -> NSImage? {
        switch trend {
        case .increasing:
            return NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: "Increasing")
        case .decreasing:
            return NSImage(systemSymbolName: "arrow.down.right", accessibilityDescription: "Decreasing")
        case .stable:
            return NSImage(systemSymbolName: "arrow.right", accessibilityDescription: "Stable")
        case .unknown:
            return NSImage(systemSymbolName: "questionmark", accessibilityDescription: "Unknown")
        }
    }
}

// MARK: - Insight Panel
class InsightPanel: NSView {
    
    // MARK: - UI Components
    private let titleLabel = NSTextField(labelWithString: "📊 Insights")
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private var insightCards: [InsightCardView] = []
    
    // MARK: - Properties
    var theme: ChartTheme = .academic {
        didSet {
            updateTheme()
        }
    }
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupInsightPanel()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInsightPanel()
    }
    
    // MARK: - Setup
    private func setupInsightPanel() {
        wantsLayer = true
        layer?.backgroundColor = theme.colors.surface.cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = theme.colors.gridLines.cgColor
        
        setupTitle()
        setupScrollView()
        setupLayout()
        updateTheme()
    }
    
    private func setupTitle() {
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = theme.colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleLabel)
    }
    
    private func setupScrollView() {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.documentView = stackView
        addSubview(scrollView)
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func updateTheme() {
        layer?.backgroundColor = theme.colors.surface.cgColor
        layer?.borderColor = theme.colors.gridLines.cgColor
        titleLabel.textColor = theme.colors.textPrimary
        
        insightCards.forEach { card in
            card.theme = theme
        }
    }
    
    // MARK: - Public Methods
    func updateInsights(_ insights: [ChartInsight]) {
        // Clear existing insights
        clearInsights()
        
        // Create new insight cards
        for insight in insights {
            let card = InsightCardView()
            card.theme = theme
            card.insight = insight
            
            insightCards.append(card)
            stackView.addArrangedSubview(card)
            
            // Set width constraint
            card.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }
        
        // Animate appearance
        animateInsights()
    }
    
    func clearInsights() {
        insightCards.forEach { card in
            card.removeFromSuperview()
        }
        insightCards.removeAll()
    }
    
    private func animateInsights() {
        for (index, card) in insightCards.enumerated() {
            card.layer?.opacity = 0
            card.layer?.transform = CATransform3DMakeTranslation(20, 0, 0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.4
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    
                    card.layer?.opacity = 1
                    card.layer?.transform = CATransform3DIdentity
                }
            }
        }
    }
}

// MARK: - Insight Card View
class InsightCardView: NSView {
    
    // MARK: - UI Components
    private let iconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let backgroundLayer = CALayer()
    
    // MARK: - Properties
    var theme: ChartTheme = .academic {
        didSet {
            updateTheme()
        }
    }
    
    var insight: ChartInsight? {
        didSet {
            updateContent()
        }
    }
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupCard()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCard()
    }
    
    // MARK: - Setup
    private func setupCard() {
        wantsLayer = true
        
        setupBackground()
        setupContent()
        setupLayout()
        updateTheme()
    }
    
    private func setupBackground() {
        backgroundLayer.cornerRadius = 8
        backgroundLayer.borderWidth = 1
        layer?.addSublayer(backgroundLayer)
    }
    
    private func setupContent() {
        iconImageView.imageScaling = .scaleAxesIndependently
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        messageLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        messageLabel.maximumNumberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        [iconImageView, titleLabel, messageLabel].forEach {
            addSubview($0)
        }
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),
            
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            messageLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            
            heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
    }
    
    private func updateTheme() {
        backgroundLayer.backgroundColor = theme.colors.surface.cgColor
        backgroundLayer.borderColor = theme.colors.gridLines.cgColor
        
        titleLabel.textColor = theme.colors.textPrimary
        messageLabel.textColor = theme.colors.textSecondary
    }
    
    private func updateContent() {
        guard let insight = insight else {
            titleLabel.stringValue = ""
            messageLabel.stringValue = ""
            iconImageView.image = nil
            return
        }
        
        titleLabel.stringValue = insight.title
        messageLabel.stringValue = insight.message
        iconImageView.image = insight.icon
        iconImageView.contentTintColor = colorForInsightType(insight.type)
    }
    
    private func colorForInsightType(_ type: InsightType) -> NSColor {
        switch type {
        case .positive:
            return theme.colors.success
        case .negative:
            return theme.colors.error
        case .neutral:
            return theme.colors.textSecondary
        case .warning:
            return theme.colors.warning
        }
    }
    
    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
    }
}

// Note: ChartInsight definitions are now in ChartDataService.swift