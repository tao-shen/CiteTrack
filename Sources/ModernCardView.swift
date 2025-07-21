import Cocoa

// MARK: - Modern Card View Component
class ModernCardView: NSView {
    
    // MARK: - Properties
    private let cornerRadius: CGFloat = 12
    private let shadowOpacity: Float = 0.08
    private let shadowOffset = NSSize(width: 0, height: 2)
    private let shadowRadius: CGFloat = 8
    
    var theme: ChartTheme = .academic {
        didSet {
            updateAppearance()
        }
    }
    
    private var backgroundLayer: CALayer?
    private var shadowLayer: CALayer?
    
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
        layer?.masksToBounds = false
        
        setupShadow()
        setupBackground()
        updateAppearance()
    }
    
    private func setupShadow() {
        shadowLayer = CALayer()
        shadowLayer?.backgroundColor = NSColor.black.cgColor
        shadowLayer?.shadowOpacity = shadowOpacity
        shadowLayer?.shadowOffset = shadowOffset
        shadowLayer?.shadowRadius = shadowRadius
        shadowLayer?.cornerRadius = cornerRadius
        
        layer?.insertSublayer(shadowLayer!, at: 0)
    }
    
    private func setupBackground() {
        backgroundLayer = CALayer()
        backgroundLayer?.cornerRadius = cornerRadius
        backgroundLayer?.masksToBounds = true
        
        layer?.addSublayer(backgroundLayer!)
    }
    
    private func updateAppearance() {
        backgroundLayer?.backgroundColor = theme.colors.surface.cgColor
        
        // Update shadow color based on theme
        shadowLayer?.shadowColor = theme.colors.onSurface.withAlphaComponent(0.15).cgColor
    }
    
    // MARK: - Layout
    override func layout() {
        super.layout()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        shadowLayer?.frame = bounds
        backgroundLayer?.frame = bounds
        
        CATransaction.commit()
    }
    
    // MARK: - Animation Support
    func animateIn() {
        layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
        layer?.opacity = 0.0
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            self.layer?.transform = CATransform3DIdentity
            self.layer?.opacity = 1.0
        }
    }
    
    func animatePress() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            self.layer?.transform = CATransform3DMakeScale(0.98, 0.98, 1.0)
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                
                self.layer?.transform = CATransform3DIdentity
            }
        }
    }
}

// MARK: - Statistics Card
class StatisticsCardView: ModernCardView {
    
    // MARK: - UI Components
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let iconImageView = NSImageView()
    private let changeIndicator = NSTextField(labelWithString: "")
    
    // MARK: - Properties
    var statistic: StatisticData? {
        didSet {
            updateContent()
        }
    }
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupStatisticsCard()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupStatisticsCard()
    }
    
    // MARK: - Setup
    private func setupStatisticsCard() {
        setupLabels()
        setupLayout()
        setupTrackingArea()
    }
    
    private func setupLabels() {
        // Title
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = theme.colors.textSecondary
        titleLabel.alignment = .left
        
        // Value
        valueLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        valueLabel.textColor = theme.colors.textPrimary
        valueLabel.alignment = .left
        
        // Subtitle
        subtitleLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        subtitleLabel.textColor = theme.colors.textSecondary
        subtitleLabel.alignment = .left
        
        // Change indicator
        changeIndicator.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        changeIndicator.alignment = .right
        
        // Icon
        iconImageView.imageScaling = .scaleAxesIndependently
        
        [titleLabel, valueLabel, subtitleLabel, iconImageView, changeIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            // Icon
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            iconImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: iconImageView.leadingAnchor, constant: -8),
            
            // Value
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            
            // Change indicator
            changeIndicator.centerYAnchor.constraint(equalTo: subtitleLabel.centerYAnchor),
            changeIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            changeIndicator.leadingAnchor.constraint(greaterThanOrEqualTo: subtitleLabel.trailingAnchor, constant: 8)
        ])
    }
    
    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    private func updateContent() {
        guard let stat = statistic else { return }
        
        titleLabel.stringValue = stat.title
        valueLabel.stringValue = stat.formattedValue
        subtitleLabel.stringValue = stat.subtitle
        
        if let icon = stat.icon {
            iconImageView.image = icon
            iconImageView.isHidden = false
        } else {
            iconImageView.isHidden = true
        }
        
        if let change = stat.change {
            changeIndicator.stringValue = change.formatted
            changeIndicator.textColor = change.isPositive ? theme.colors.success : theme.colors.error
            changeIndicator.isHidden = false
        } else {
            changeIndicator.isHidden = true
        }
    }
    
    // MARK: - Mouse Events
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.layer?.transform = CATransform3DMakeScale(1.02, 1.02, 1.0)
            self.shadowLayer?.shadowOpacity = shadowOpacity * 1.5
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.layer?.transform = CATransform3DIdentity
            self.shadowLayer?.shadowOpacity = shadowOpacity
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        animatePress()
    }
}

// MARK: - Data Models
struct StatisticData {
    let title: String
    let value: Any
    let subtitle: String
    let icon: NSImage?
    let change: StatisticChange?
    let type: StatisticType
    
    var formattedValue: String {
        switch type {
        case .number:
            if let num = value as? Int {
                return num.formattedWithCommas()
            }
        case .percentage:
            if let percent = value as? Double {
                return String(format: "%.1f%%", percent)
            }
        case .currency:
            if let amount = value as? Double {
                return String(format: "$%.2f", amount)
            }
        case .text:
            return String(describing: value)
        }
        return String(describing: value)
    }
}

struct StatisticChange {
    let value: Double
    let isPositive: Bool
    
    var formatted: String {
        let prefix = isPositive ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", value))%"
    }
}

enum StatisticType {
    case number
    case percentage
    case currency
    case text
}

// MARK: - Extensions
extension Int {
    func formattedWithCommas() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? String(self)
    }
}