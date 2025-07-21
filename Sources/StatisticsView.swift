import Cocoa

// MARK: - Statistics View
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
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        
        setupUI()
        updateContent()
    }
    
    private func setupUI() {
        // Main container
        containerStackView = NSStackView()
        containerStackView.orientation = .vertical
        containerStackView.spacing = 8
        containerStackView.alignment = .leading
        containerStackView.distribution = .fill
        containerStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title
        titleLabel = NSTextField(labelWithString: "Statistics")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        
        // Details stack view
        detailsStackView = NSStackView()
        detailsStackView.orientation = .horizontal
        detailsStackView.spacing = 16
        detailsStackView.alignment = .centerY
        detailsStackView.distribution = .fillEqually
        
        containerStackView.addArrangedSubview(titleLabel)
        containerStackView.addArrangedSubview(detailsStackView)
        
        addSubview(containerStackView)
        
        NSLayoutConstraint.activate([
            containerStackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            containerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            containerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            containerStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    private func updateContent() {
        // Clear existing details
        for subview in detailsStackView.arrangedSubviews {
            detailsStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        guard let stats = statistics else {
            // Show no data state
            let noDataLabel = NSTextField(labelWithString: "No statistics available")
            noDataLabel.font = NSFont.systemFont(ofSize: 12)
            noDataLabel.textColor = .secondaryLabelColor
            detailsStackView.addArrangedSubview(noDataLabel)
            return
        }
        
        // Create statistic items
        let statisticItems = createStatisticItems(from: stats)
        
        for item in statisticItems {
            detailsStackView.addArrangedSubview(item)
        }
    }
    
    private func createStatisticItems(from stats: ChartStatistics) -> [NSView] {
        var items: [NSView] = []
        
        // Total data points
        items.append(createStatisticItem(
            title: "Data Points",
            value: "\(stats.totalDataPoints)"
        ))
        
        // Value range
        if let valueRange = stats.valueRange {
            items.append(createStatisticItem(
                title: "Range",
                value: "\(valueRange.min) - \(valueRange.max)"
            ))
        }
        
        // Total change
        let changeSign = stats.totalChange >= 0 ? "+" : ""
        items.append(createStatisticItem(
            title: "Change",
            value: "\(changeSign)\(stats.totalChange)",
            color: stats.totalChange >= 0 ? .systemGreen : .systemRed
        ))
        
        // Growth rate
        let growthSign = stats.growthRate >= 0 ? "+" : ""
        items.append(createStatisticItem(
            title: "Growth",
            value: "\(growthSign)\(String(format: "%.1f", stats.growthRate))%",
            color: stats.growthRate >= 0 ? .systemGreen : .systemRed
        ))
        
        // Trend
        items.append(createStatisticItem(
            title: "Trend",
            value: "\(stats.trend.symbol) \(stats.trend.displayName)",
            color: stats.trend.color
        ))
        
        return items
    }
    
    private func createStatisticItem(title: String, value: String, color: NSColor = .labelColor) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 11)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        valueLabel.textColor = color
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        
        return container
    }
    
    deinit {
        print("StatisticsView: Deallocated")
    }
}