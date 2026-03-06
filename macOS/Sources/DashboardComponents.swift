import Cocoa

// MARK: - Dashboard View
// Design: 4-column statistics grid with consistent card sizing
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
        stackView.spacing = DesignSpacing.sm
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
    }

    private func createStatisticsCards() {
        for _ in 0..<4 {
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

        var statisticsData: [StatisticData] = []

        if #available(macOS 11.0, *) {
            statisticsData = [
                StatisticData(
                    title: L("total_citations"),
                    value: scholar.citations ?? 0,
                    subtitle: L("dashboard_subtitle_all_time"),
                    icon: NSImage(systemSymbolName: "quote.bubble", accessibilityDescription: L("citations_label")),
                    change: nil,
                    type: .number
                ),
                StatisticData(
                    title: L("monthly_change"),
                    value: stats.totalChange,
                    subtitle: L("dashboard_subtitle_this_period"),
                    icon: NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: L("total_change")),
                    change: StatisticChange(value: stats.growthRate, isPositive: stats.totalChange >= 0),
                    type: .number
                ),
                StatisticData(
                    title: L("growth_rate"),
                    value: stats.growthRate,
                    subtitle: L("dashboard_subtitle_percentage"),
                    icon: NSImage(systemSymbolName: "percent", accessibilityDescription: L("growth_rate")),
                    change: nil,
                    type: .percentage
                ),
                StatisticData(
                    title: L("trend_label"),
                    value: stats.trend.symbol,
                    subtitle: stats.trend.displayName,
                    icon: trendIcon(for: stats.trend),
                    change: nil,
                    type: .text
                )
            ]
        } else {
            statisticsData = [
                StatisticData(
                    title: L("total_citations"),
                    value: scholar.citations ?? 0,
                    subtitle: L("dashboard_subtitle_all_time"),
                    icon: nil, change: nil, type: .number
                ),
                StatisticData(
                    title: L("monthly_change"),
                    value: stats.totalChange,
                    subtitle: L("dashboard_subtitle_this_period"),
                    icon: nil,
                    change: StatisticChange(value: stats.growthRate, isPositive: stats.totalChange >= 0),
                    type: .number
                ),
                StatisticData(
                    title: L("growth_rate"),
                    value: stats.growthRate,
                    subtitle: L("dashboard_subtitle_percentage"),
                    icon: nil, change: nil, type: .percentage
                ),
                StatisticData(
                    title: L("trend_label"),
                    value: stats.trend.symbol,
                    subtitle: stats.trend.displayName,
                    icon: nil, change: nil, type: .text
                )
            ]
        }

        // Update cards with staggered animation
        for (index, cardData) in statisticsData.enumerated() {
            if index < statisticsCards.count {
                statisticsCards[index].statistic = cardData

                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.06) {
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
        if #available(macOS 11.0, *) {
            switch trend {
            case .increasing:
                return NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: L("trend_increasing"))
            case .decreasing:
                return NSImage(systemSymbolName: "arrow.down.right", accessibilityDescription: L("trend_decreasing"))
            case .stable:
                return NSImage(systemSymbolName: "arrow.right", accessibilityDescription: L("trend_stable"))
            case .unknown:
                return NSImage(systemSymbolName: "questionmark", accessibilityDescription: L("trend_unknown"))
            }
        } else {
            return nil
        }
    }
}

// MARK: - Insight Panel
// Design: Right sidebar with clean card list, subtle top-border separator
class InsightPanel: NSView {

    // MARK: - UI Components
    private let headerView = NSView()
    private let titleLabel = NSTextField(labelWithString: L("dashboard_title_insights"))
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
        layer?.backgroundColor = theme.colors.cardBackground.cgColor
        layer?.cornerRadius = DesignSpacing.cardCornerRadius
        layer?.borderWidth = 0.5
        layer?.borderColor = theme.colors.border.withAlphaComponent(0.5).cgColor

        // Tinted shadow
        layer?.shadowColor = theme.colors.shadowColor.withAlphaComponent(0.1).cgColor
        layer?.shadowOpacity = DesignSpacing.cardShadowOpacity
        layer?.shadowOffset = NSSize(width: 0, height: -1)
        layer?.shadowRadius = DesignSpacing.cardShadowRadius

        setupTitle()
        setupScrollView()
        setupLayout()
        updateTheme()
    }

    private func setupTitle() {
        // Section header — uppercase, tracked, small
        titleLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        titleLabel.textColor = theme.colors.textSecondary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
    }

    private func setupScrollView() {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        stackView.orientation = .vertical
        stackView.spacing = DesignSpacing.xs
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = stackView
        addSubview(scrollView)
    }

    private func setupLayout() {
        let padding = DesignSpacing.cardPadding

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignSpacing.sm),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignSpacing.sm),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignSpacing.sm),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignSpacing.sm),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func updateTheme() {
        layer?.backgroundColor = theme.colors.cardBackground.cgColor
        layer?.borderColor = theme.colors.border.withAlphaComponent(0.5).cgColor
        layer?.shadowColor = theme.colors.shadowColor.withAlphaComponent(0.1).cgColor

        // Uppercase tracked title
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: theme.colors.textSecondary,
            .kern: 1.2
        ]
        titleLabel.attributedStringValue = NSAttributedString(
            string: L("dashboard_title_insights").uppercased(),
            attributes: attributes
        )

        insightCards.forEach { card in
            card.theme = theme
        }
    }

    // MARK: - Public Methods
    func updateInsights(_ insights: [ChartInsight]) {
        clearInsights()

        for insight in insights {
            let card = InsightCardView()
            card.theme = theme
            card.insight = insight

            insightCards.append(card)
            stackView.addArrangedSubview(card)

            card.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }

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
            card.layer?.transform = CATransform3DMakeTranslation(12, 0, 0)

            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)

                    card.layer?.opacity = 1
                    card.layer?.transform = CATransform3DIdentity
                }
            }
        }
    }
}

// MARK: - Insight Card View
// Design: Minimal — left color accent bar, clean text hierarchy
class InsightCardView: NSView {

    // MARK: - UI Components
    private let accentBar = NSView()
    private let iconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(wrappingLabelWithString: "")

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
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.clear.cgColor

        setupContent()
        setupLayout()
        updateTheme()
    }

    private func setupContent() {
        // Left accent bar — 3px wide, colored by insight type
        accentBar.wantsLayer = true
        accentBar.layer?.cornerRadius = 1.5
        accentBar.translatesAutoresizingMaskIntoConstraints = false

        iconImageView.imageScaling = .scaleProportionallyDown
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        messageLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        messageLabel.maximumNumberOfLines = 3
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        [accentBar, iconImageView, titleLabel, messageLabel].forEach {
            addSubview($0)
        }
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            // Accent bar — left edge
            accentBar.topAnchor.constraint(equalTo: topAnchor, constant: DesignSpacing.xs),
            accentBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignSpacing.xs),
            accentBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignSpacing.xs),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            // Icon
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: DesignSpacing.sm),
            iconImageView.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: DesignSpacing.xs),
            iconImageView.widthAnchor.constraint(equalToConstant: 12),
            iconImageView.heightAnchor.constraint(equalToConstant: 12),

            // Title
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: DesignSpacing.sm),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: DesignSpacing.xxs),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignSpacing.sm),

            // Message
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignSpacing.xxs),
            messageLabel.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: DesignSpacing.xs),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignSpacing.sm),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignSpacing.sm),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    private func updateTheme() {
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

        let accentColor = colorForInsightType(insight.type)
        iconImageView.contentTintColor = accentColor
        accentBar.layer?.backgroundColor = accentColor.cgColor
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

    // Hover — subtle background
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.layer?.backgroundColor = self.theme.colors.primary.withAlphaComponent(0.03).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}

// Note: ChartInsight definitions are now in ChartDataService.swift
