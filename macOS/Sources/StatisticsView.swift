import Cocoa

// MARK: - Statistics View
// Design: Clean horizontal stats with divider separators instead of cards
// Monospaced numbers, muted labels, clear value hierarchy
class StatisticsView: NSView {

    // MARK: - UI Components
    private var containerStackView: NSStackView!
    private var titleLabel: NSTextField!
    private var detailsStackView: NSStackView!

    // MARK: - Data
    var statistics: ChartStatistics? {
        didSet {
            updateContent()
        }
    }

    // MARK: - Initialization

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
        layer?.backgroundColor = NSColor(hex: "#FAFAF8").cgColor
        layer?.cornerRadius = DesignSpacing.cardCornerRadius
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor(hex: "#D8D6D0").withAlphaComponent(0.5).cgColor

        // Tinted shadow
        layer?.shadowColor = NSColor(hex: "#3B6B9A").withAlphaComponent(0.1).cgColor
        layer?.shadowOpacity = DesignSpacing.cardShadowOpacity
        layer?.shadowOffset = NSSize(width: 0, height: -1)
        layer?.shadowRadius = DesignSpacing.cardShadowRadius

        setupUI()
        updateContent()
    }

    private func setupUI() {
        containerStackView = NSStackView()
        containerStackView.orientation = .vertical
        containerStackView.spacing = DesignSpacing.xs
        containerStackView.alignment = .leading
        containerStackView.distribution = .fill
        containerStackView.translatesAutoresizingMaskIntoConstraints = false

        // Uppercase tracked section label
        titleLabel = NSTextField(labelWithString: "STATISTICS")
        titleLabel.attributedStringValue = NSAttributedString(
            string: "STATISTICS",
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor(hex: "#6E6E73"),
                .kern: 1.2
            ]
        )

        detailsStackView = NSStackView()
        detailsStackView.orientation = .horizontal
        detailsStackView.spacing = DesignSpacing.xl
        detailsStackView.alignment = .centerY
        detailsStackView.distribution = .fillEqually

        containerStackView.addArrangedSubview(titleLabel)
        containerStackView.addArrangedSubview(detailsStackView)

        addSubview(containerStackView)

        let padding = DesignSpacing.cardPadding
        NSLayoutConstraint.activate([
            containerStackView.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            containerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            containerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            containerStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding)
        ])
    }

    private func updateContent() {
        for subview in detailsStackView.arrangedSubviews {
            detailsStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        guard let stats = statistics else {
            let noDataLabel = NSTextField(labelWithString: "No statistics available")
            noDataLabel.font = NSFont.systemFont(ofSize: 11)
            noDataLabel.textColor = NSColor(hex: "#8E8E93")
            detailsStackView.addArrangedSubview(noDataLabel)
            return
        }

        let statisticItems = createStatisticItems(from: stats)

        for item in statisticItems {
            detailsStackView.addArrangedSubview(item)
        }
    }

    private func createStatisticItems(from stats: ChartStatistics) -> [NSView] {
        var items: [NSView] = []

        items.append(createStatisticItem(
            title: "DATA POINTS",
            value: "\(stats.totalDataPoints)"
        ))

        if let valueRange = stats.valueRange {
            items.append(createStatisticItem(
                title: "RANGE",
                value: "\(valueRange.min) - \(valueRange.max)"
            ))
        }

        let changeSign = stats.totalChange >= 0 ? "+" : ""
        items.append(createStatisticItem(
            title: "CHANGE",
            value: "\(changeSign)\(stats.totalChange)",
            color: stats.totalChange >= 0 ? NSColor(hex: "#3D8B5E") : NSColor(hex: "#B84A3C")
        ))

        let growthSign = stats.growthRate >= 0 ? "+" : ""
        items.append(createStatisticItem(
            title: "GROWTH",
            value: "\(growthSign)\(String(format: "%.1f", stats.growthRate))%",
            color: stats.growthRate >= 0 ? NSColor(hex: "#3D8B5E") : NSColor(hex: "#B84A3C")
        ))

        items.append(createStatisticItem(
            title: "TREND",
            value: "\(stats.trend.symbol) \(stats.trend.displayName)",
            color: stats.trend.color
        ))

        return items
    }

    private func createStatisticItem(title: String, value: String, color: NSColor = NSColor(hex: "#1C1C1E")) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.attributedStringValue = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: NSColor(hex: "#8E8E93"),
                .kern: 0.8
            ]
        )
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        valueLabel.textColor = color
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(titleLabel)
        container.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignSpacing.xxs),
            valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])

        return container
    }

    deinit {
        print("StatisticsView: Deallocated")
    }
}
