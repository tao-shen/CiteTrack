import Cocoa

// MARK: - Modern Card View Component
// Design: Subtle elevation via tinted shadow, 1px border for definition
// No excessive border-radius. Clean, functional hierarchy.
class ModernCardView: NSView {

    // MARK: - Properties
    fileprivate let cornerRadius: CGFloat = DesignSpacing.cardCornerRadius
    fileprivate let defaultShadowOpacity: Float = DesignSpacing.cardShadowOpacity
    fileprivate let shadowOffset = NSSize(width: 0, height: -1)
    fileprivate let defaultShadowRadius: CGFloat = DesignSpacing.cardShadowRadius

    var theme: ChartTheme = .academic {
        didSet {
            updateAppearance()
        }
    }

    fileprivate var backgroundLayer: CALayer?
    fileprivate var borderLayer: CALayer?

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

        setupBackground()
        updateAppearance()
    }

    private func setupBackground() {
        backgroundLayer = CALayer()
        backgroundLayer?.cornerRadius = cornerRadius
        backgroundLayer?.masksToBounds = true
        layer?.addSublayer(backgroundLayer!)
    }

    private func updateAppearance() {
        let colors = theme.colors

        // Card background
        backgroundLayer?.backgroundColor = colors.cardBackground.cgColor

        // Tinted shadow — matches primary color for cohesion
        layer?.shadowColor = colors.shadowColor.withAlphaComponent(0.12).cgColor
        layer?.shadowOpacity = defaultShadowOpacity
        layer?.shadowOffset = shadowOffset
        layer?.shadowRadius = defaultShadowRadius
        layer?.cornerRadius = cornerRadius

        // 1px border for definition against background
        backgroundLayer?.borderColor = colors.border.withAlphaComponent(0.5).cgColor
        backgroundLayer?.borderWidth = 0.5
    }

    // MARK: - Layout
    override func layout() {
        super.layout()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer?.frame = bounds
        CATransaction.commit()
    }

    // MARK: - Animation Support
    func animateIn() {
        layer?.transform = CATransform3DMakeScale(0.97, 0.97, 1.0)
        layer?.opacity = 0.0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)

            self.layer?.transform = CATransform3DIdentity
            self.layer?.opacity = 1.0
        }
    }

    func animatePress() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.layer?.transform = CATransform3DMakeScale(0.98, 0.98, 1.0)
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
                self.layer?.transform = CATransform3DIdentity
            }
        }
    }
}

// MARK: - Statistics Card
// Design: Clear hierarchy — title (caption) / value (display) / subtitle (caption)
// Icon top-right with tinted background circle
class StatisticsCardView: ModernCardView {

    // MARK: - UI Components
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let iconContainerView = NSView()
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
        // Title — caption weight, secondary color
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = theme.colors.textSecondary
        titleLabel.alignment = .left

        // Value — large, bold, primary color
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 28, weight: .semibold)
        valueLabel.textColor = theme.colors.textPrimary
        valueLabel.alignment = .left

        // Subtitle — smallest, muted
        subtitleLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        subtitleLabel.textColor = theme.colors.textSecondary
        subtitleLabel.alignment = .left

        // Change indicator — monospaced for numbers
        changeIndicator.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        changeIndicator.alignment = .right

        // Icon container — tinted circle background
        iconContainerView.wantsLayer = true
        iconContainerView.layer?.cornerRadius = 14
        iconContainerView.layer?.backgroundColor = theme.colors.primary.withAlphaComponent(0.08).cgColor

        iconImageView.imageScaling = .scaleProportionallyDown

        iconContainerView.addSubview(iconImageView)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        [titleLabel, valueLabel, subtitleLabel, iconContainerView, changeIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }

    private func setupLayout() {
        let padding = DesignSpacing.cardPadding

        NSLayoutConstraint.activate([
            // Icon container — top right
            iconContainerView.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            iconContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            iconContainerView.widthAnchor.constraint(equalToConstant: 28),
            iconContainerView.heightAnchor.constraint(equalToConstant: 28),

            // Icon inside container
            iconImageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 14),
            iconImageView.heightAnchor.constraint(equalToConstant: 14),

            // Title — top left
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            titleLabel.trailingAnchor.constraint(equalTo: iconContainerView.leadingAnchor, constant: -DesignSpacing.xs),

            // Value — below title with breathing room
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignSpacing.xs),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),

            // Subtitle — at bottom
            subtitleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: DesignSpacing.xxs),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding),

            // Change indicator — aligned with subtitle
            changeIndicator.centerYAnchor.constraint(equalTo: subtitleLabel.centerYAnchor),
            changeIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            changeIndicator.leadingAnchor.constraint(greaterThanOrEqualTo: subtitleLabel.trailingAnchor, constant: DesignSpacing.xs)
        ])
    }

    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    private func updateContent() {
        guard let stat = statistic else { return }

        titleLabel.stringValue = stat.title.uppercased()
        titleLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        titleLabel.textColor = theme.colors.textSecondary

        valueLabel.stringValue = stat.formattedValue
        subtitleLabel.stringValue = stat.subtitle

        // Icon with tinted container
        if let icon = stat.icon {
            iconImageView.image = icon
            iconImageView.contentTintColor = theme.colors.primary
            iconContainerView.layer?.backgroundColor = theme.colors.primary.withAlphaComponent(0.08).cgColor
            iconContainerView.isHidden = false
        } else {
            iconContainerView.isHidden = true
        }

        if let change = stat.change {
            changeIndicator.stringValue = change.formatted
            changeIndicator.textColor = change.isPositive ? theme.colors.success : theme.colors.error
            changeIndicator.isHidden = false
        } else {
            changeIndicator.isHidden = true
        }
    }

    // MARK: - Mouse Events — subtle elevation on hover
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            self.layer?.shadowOpacity = self.defaultShadowOpacity * 2.0
            self.layer?.shadowRadius = self.defaultShadowRadius * 1.5
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.layer?.shadowOpacity = self.defaultShadowOpacity
            self.layer?.shadowRadius = self.defaultShadowRadius
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
