import Cocoa

// MARK: - Enhanced Chart Types
enum ChartType: String, CaseIterable {
    case line = "line"
    case area = "area"
    case bar = "bar"
    case scatter = "scatter"
    case smoothLine = "smoothLine"
    
    var displayName: String {
        switch self {
        case .line: return "Line Chart"
        case .area: return "Area Chart"
        case .bar: return "Bar Chart"
        case .scatter: return "Scatter Plot"
        case .smoothLine: return "Smooth Line"
        }
    }
    
    var icon: NSImage? {
        switch self {
        case .line: return NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: displayName)
        case .area: return NSImage(systemSymbolName: "chart.line.uptrend.xyaxis.circle", accessibilityDescription: displayName)
        case .bar: return NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: displayName)
        case .scatter: return NSImage(systemSymbolName: "chart.dots.scatter", accessibilityDescription: displayName)
        case .smoothLine: return NSImage(systemSymbolName: "chart.line.flattrend.xyaxis", accessibilityDescription: displayName)
        }
    }
    
    var description: String {
        switch self {
        case .line: return "Clean line visualization showing citation trends over time"
        case .area: return "Filled area chart emphasizing cumulative growth"
        case .bar: return "Bar chart comparing citation counts across time periods"
        case .scatter: return "Individual data points showing citation distribution"
        case .smoothLine: return "Smooth curved line highlighting overall trends"
        }
    }
}

// MARK: - Modern Chart View
class ModernChartView: NSView {
    
    // MARK: - Properties
    var chartType: ChartType = .line {
        didSet {
            updateChart()
        }
    }
    
    var theme: ChartTheme = .academic {
        didSet {
            updateTheme()
        }
    }
    
    var chartData: ChartData? {
        didSet {
            updateChart()
        }
    }
    
    var animationEnabled: Bool = true
    
    // Chart layers
    private var backgroundLayer: CALayer?
    private var gridLayer: CAShapeLayer?
    private var dataLayer: CAShapeLayer?
    private var highlightLayer: CAShapeLayer?
    
    // Interaction
    private var trackingArea: NSTrackingArea?
    private var tooltipWindow: TooltipWindow?
    private var isMouseInside = false
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupChart()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupChart()
    }
    
    // MARK: - Setup
    private func setupChart() {
        wantsLayer = true
        layer?.masksToBounds = false
        
        setupLayers()
        setupTrackingArea()
        updateTheme()
    }
    
    private func setupLayers() {
        // Background
        backgroundLayer = CALayer()
        backgroundLayer?.cornerRadius = 8
        layer?.addSublayer(backgroundLayer!)
        
        // Grid
        gridLayer = CAShapeLayer()
        gridLayer?.fillColor = NSColor.clear.cgColor
        gridLayer?.lineWidth = 0.5
        layer?.addSublayer(gridLayer!)
        
        // Data
        dataLayer = CAShapeLayer()
        dataLayer?.fillColor = NSColor.clear.cgColor
        dataLayer?.lineWidth = 2.0
        dataLayer?.lineCap = .round
        dataLayer?.lineJoin = .round
        layer?.addSublayer(dataLayer!)
        
        // Highlight
        highlightLayer = CAShapeLayer()
        highlightLayer?.fillColor = NSColor.clear.cgColor
        highlightLayer?.lineWidth = 3.0
        highlightLayer?.lineCap = .round
        highlightLayer?.isHidden = true
        layer?.addSublayer(highlightLayer!)
    }
    
    private func setupTrackingArea() {
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    private func updateTheme() {
        backgroundLayer?.backgroundColor = theme.colors.surface.cgColor
        backgroundLayer?.borderColor = theme.colors.gridLines.cgColor
        backgroundLayer?.borderWidth = 1.0
        
        gridLayer?.strokeColor = theme.colors.gridLines.cgColor
        dataLayer?.strokeColor = theme.colors.primary.cgColor
        highlightLayer?.strokeColor = theme.colors.accent.cgColor
        
        needsDisplay = true
    }
    
    private func updateChart() {
        guard let data = chartData else {
            clearChart()
            return
        }
        
        drawGrid()
        drawData(data)
        
        if animationEnabled {
            animateChart()
        }
    }
    
    // MARK: - Drawing
    private func clearChart() {
        dataLayer?.path = nil
        gridLayer?.path = nil
    }
    
    private func drawGrid() {
        guard let data = chartData, !data.points.isEmpty else { return }
        
        let gridPath = CGMutablePath()
        let chartRect = chartBounds()
        
        // Vertical grid lines
        let xStep = chartRect.width / CGFloat(max(data.points.count - 1, 1))
        for i in 0..<data.points.count {
            let x = chartRect.minX + CGFloat(i) * xStep
            gridPath.move(to: CGPoint(x: x, y: chartRect.minY))
            gridPath.addLine(to: CGPoint(x: x, y: chartRect.maxY))
        }
        
        // Horizontal grid lines
        let gridLineCount = 5
        let yStep = chartRect.height / CGFloat(gridLineCount)
        for i in 0...gridLineCount {
            let y = chartRect.minY + CGFloat(i) * yStep
            gridPath.move(to: CGPoint(x: chartRect.minX, y: y))
            gridPath.addLine(to: CGPoint(x: chartRect.maxX, y: y))
        }
        
        gridLayer?.path = gridPath
    }
    
    private func drawData(_ data: ChartData) {
        switch chartType {
        case .line, .smoothLine:
            drawLineChart(data)
        case .area:
            drawAreaChart(data)
        case .bar:
            drawBarChart(data)
        case .scatter:
            drawScatterChart(data)
        }
    }
    
    private func drawLineChart(_ data: ChartData) {
        let path = createLinePath(data)
        dataLayer?.path = path
    }
    
    private func drawAreaChart(_ data: ChartData) {
        let linePath = createLinePath(data)
        let areaPath = createAreaPath(data)
        
        // Create gradient fill
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            theme.colors.primary.withAlphaComponent(0.3).cgColor,
            theme.colors.primary.withAlphaComponent(0.0).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = bounds
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = areaPath
        gradientLayer.mask = maskLayer
        
        // Remove existing area layer if present
        layer?.sublayers?.forEach { sublayer in
            if sublayer is CAGradientLayer {
                sublayer.removeFromSuperlayer()
            }
        }
        
        layer?.insertSublayer(gradientLayer, below: dataLayer)
        dataLayer?.path = linePath
    }
    
    private func drawBarChart(_ data: ChartData) {
        let path = createBarPath(data)
        dataLayer?.path = path
        dataLayer?.fillColor = theme.colors.primary.withAlphaComponent(0.7).cgColor
    }
    
    private func drawScatterChart(_ data: ChartData) {
        let path = createScatterPath(data)
        dataLayer?.path = path
        dataLayer?.fillColor = theme.colors.primary.cgColor
    }
    
    // MARK: - Path Creation
    private func createLinePath(_ data: ChartData) -> CGPath {
        let path = CGMutablePath()
        let chartRect = chartBounds()
        let points = normalizedPoints(data.points, in: chartRect)
        
        guard !points.isEmpty else { return path }
        
        if chartType == .smoothLine {
            return createSmoothPath(points)
        } else {
            path.move(to: points[0])
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
        }
        
        return path
    }
    
    private func createSmoothPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard points.count > 1 else { return path }
        
        path.move(to: points[0])
        
        for i in 1..<points.count {
            let previousPoint = points[i - 1]
            let currentPoint = points[i]
            let nextPoint = i + 1 < points.count ? points[i + 1] : currentPoint
            
            let controlPoint1 = CGPoint(
                x: previousPoint.x + (currentPoint.x - previousPoint.x) * 0.3,
                y: previousPoint.y + (currentPoint.y - previousPoint.y) * 0.3
            )
            
            let controlPoint2 = CGPoint(
                x: currentPoint.x - (nextPoint.x - currentPoint.x) * 0.3,
                y: currentPoint.y - (nextPoint.y - currentPoint.y) * 0.3
            )
            
            path.addCurve(to: currentPoint, control1: controlPoint1, control2: controlPoint2)
        }
        
        return path
    }
    
    private func createAreaPath(_ data: ChartData) -> CGPath {
        let linePath = createLinePath(data)
        let areaPath = CGMutablePath()
        let chartRect = chartBounds()
        let points = normalizedPoints(data.points, in: chartRect)
        
        guard !points.isEmpty else { return areaPath }
        
        // Start from bottom-left
        areaPath.move(to: CGPoint(x: points[0].x, y: chartRect.minY))
        areaPath.addLine(to: points[0])
        
        // Add the line path
        areaPath.addPath(linePath)
        
        // Close to bottom-right
        areaPath.addLine(to: CGPoint(x: points.last!.x, y: chartRect.minY))
        areaPath.closeSubpath()
        
        return areaPath
    }
    
    private func createBarPath(_ data: ChartData) -> CGPath {
        let path = CGMutablePath()
        let chartRect = chartBounds()
        let barWidth = chartRect.width / CGFloat(data.points.count) * 0.6
        
        for (index, point) in data.points.enumerated() {
            let normalizedY = normalizeValue(Double(point.value), in: data) * chartRect.height
            let x = chartRect.minX + (CGFloat(index) + 0.5) * (chartRect.width / CGFloat(data.points.count)) - barWidth / 2
            let y = chartRect.maxY - normalizedY
            
            let barRect = CGRect(x: x, y: y, width: barWidth, height: normalizedY)
            path.addRect(barRect)
        }
        
        return path
    }
    
    private func createScatterPath(_ data: ChartData) -> CGPath {
        let path = CGMutablePath()
        let chartRect = chartBounds()
        let pointRadius: CGFloat = 4
        
        for (index, point) in data.points.enumerated() {
            let normalizedY = normalizeValue(Double(point.value), in: data) * chartRect.height
            let x = chartRect.minX + CGFloat(index) * (chartRect.width / CGFloat(max(data.points.count - 1, 1)))
            let y = chartRect.maxY - normalizedY
            
            let pointRect = CGRect(
                x: x - pointRadius,
                y: y - pointRadius,
                width: pointRadius * 2,
                height: pointRadius * 2
            )
            path.addEllipse(in: pointRect)
        }
        
        return path
    }
    
    // MARK: - Helper Methods
    private func chartBounds() -> CGRect {
        let margin: CGFloat = 20
        return bounds.insetBy(dx: margin, dy: margin)
    }
    
    private func normalizedPoints(_ points: [ChartDataPoint], in rect: CGRect) -> [CGPoint] {
        guard let data = chartData else { return [] }
        
        return points.enumerated().map { index, point in
            let normalizedY = normalizeValue(Double(point.value), in: data) * rect.height
            let x = rect.minX + CGFloat(index) * (rect.width / CGFloat(max(points.count - 1, 1)))
            let y = rect.maxY - normalizedY
            return CGPoint(x: x, y: y)
        }
    }
    
    private func normalizeValue(_ value: Double, in data: ChartData) -> CGFloat {
        guard let minValue = data.points.map({ Double($0.value) }).min(),
              let maxValue = data.points.map({ Double($0.value) }).max(),
              maxValue > minValue else { return 0.5 }
        
        return CGFloat((value - minValue) / (maxValue - minValue))
    }
    
    // MARK: - Animation
    private func animateChart() {
        guard let path = dataLayer?.path else { return }
        
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = 0.8
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        dataLayer?.add(animation, forKey: "drawChart")
    }
    
    // MARK: - Mouse Events
    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        hideTooltip()
        highlightLayer?.isHidden = true
    }
    
    override func mouseMoved(with event: NSEvent) {
        guard isMouseInside, let data = chartData else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        let chartRect = chartBounds()
        
        // Find nearest data point
        if let nearestPoint = findNearestDataPoint(to: location, in: chartRect) {
            showTooltip(for: nearestPoint.point, at: nearestPoint.location)
            highlightPoint(at: nearestPoint.location)
        }
    }
    
    private func findNearestDataPoint(to location: CGPoint, in rect: CGRect) -> (point: ChartDataPoint, location: CGPoint)? {
        guard let data = chartData else { return nil }
        
        let points = normalizedPoints(data.points, in: rect)
        var minDistance: CGFloat = .greatestFiniteMagnitude
        var nearestIndex = 0
        
        for (index, point) in points.enumerated() {
            let distance = sqrt(pow(point.x - location.x, 2) + pow(point.y - location.y, 2))
            if distance < minDistance {
                minDistance = distance
                nearestIndex = index
            }
        }
        
        guard nearestIndex < data.points.count && nearestIndex < points.count else { return nil }
        
        return (data.points[nearestIndex], points[nearestIndex])
    }
    
    private func showTooltip(for dataPoint: ChartDataPoint, at location: CGPoint) {
        if tooltipWindow == nil {
            tooltipWindow = TooltipWindow()
        }
        
        let windowLocation = convert(location, to: nil)
        let screenLocation = window?.convertToScreen(NSRect(origin: windowLocation, size: .zero)).origin ?? .zero
        
        tooltipWindow?.showTooltip(
            value: dataPoint.value,
            date: dataPoint.date,
            at: screenLocation,
            theme: theme
        )
    }
    
    private func hideTooltip() {
        tooltipWindow?.hideTooltip()
    }
    
    private func highlightPoint(at location: CGPoint) {
        let path = CGMutablePath()
        let radius: CGFloat = 6
        let pointRect = CGRect(
            x: location.x - radius,
            y: location.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        path.addEllipse(in: pointRect)
        
        highlightLayer?.path = path
        highlightLayer?.isHidden = false
        highlightLayer?.fillColor = theme.colors.accent.cgColor
    }
    
    // MARK: - Layout
    override func layout() {
        super.layout()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        backgroundLayer?.frame = bounds
        gridLayer?.frame = bounds
        dataLayer?.frame = bounds
        highlightLayer?.frame = bounds
        
        CATransaction.commit()
        
        updateTrackingArea()
        updateChart()
    }
    
    private func updateTrackingArea() {
        if let area = trackingArea {
            removeTrackingArea(area)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
}

// MARK: - Tooltip Window
class TooltipWindow: NSWindow {
    
    private let contentView = TooltipContentView()
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
    }
    
    private func setupWindow() {
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        ignoresMouseEvents = true
        
        self.contentView = contentView
    }
    
    func showTooltip(value: Int, date: Date, at location: NSPoint, theme: ChartTheme) {
        contentView.configure(value: value, date: date, theme: theme)
        
        let windowRect = NSRect(
            x: location.x - frame.width / 2,
            y: location.y + 20,
            width: frame.width,
            height: frame.height
        )
        setFrame(windowRect, display: true)
        
        if !isVisible {
            alphaValue = 0
            makeKeyAndOrderFront(nil)
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                animator().alphaValue = 1.0
            }
        }
    }
    
    func hideTooltip() {
        guard isVisible else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            animator().alphaValue = 0.0
        } completionHandler: {
            self.orderOut(nil)
        }
    }
}

// MARK: - Tooltip Content View
class TooltipContentView: NSView {
    
    private let backgroundLayer = CALayer()
    private let valueLabel = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    
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
        
        backgroundLayer.cornerRadius = 8
        backgroundLayer.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
        layer?.addSublayer(backgroundLayer)
        
        valueLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        valueLabel.textColor = .white
        valueLabel.alignment = .center
        
        dateLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        dateLabel.textColor = NSColor.white.withAlphaComponent(0.8)
        dateLabel.alignment = .center
        
        [valueLabel, dateLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            valueLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            dateLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            dateLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            dateLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
    func configure(value: Int, date: Date, theme: ChartTheme) {
        valueLabel.stringValue = "\(value.formattedWithCommas()) citations"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        dateLabel.stringValue = formatter.string(from: date)
    }
    
    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
    }
}