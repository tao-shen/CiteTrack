import Cocoa
import CoreGraphics

// MARK: - Chart View Delegate
protocol ChartViewDelegate: AnyObject {
    func chartView(_ chartView: ChartView, didSelectPoint point: ChartDataPoint)
    func chartView(_ chartView: ChartView, didHoverPoint point: ChartDataPoint?)
}

// MARK: - Chart View
class ChartView: NSView {
    
    // MARK: - Properties
    
    weak var delegate: ChartViewDelegate?
    
    var chartData: ChartData? {
        didSet {
            needsDisplay = true
            updateTrackingAreas()
        }
    }
    
    var configuration: ChartConfiguration = .default {
        didSet {
            needsDisplay = true
        }
    }
    
    private var hoveredPoint: ChartDataPoint?
    private var selectedPoint: ChartDataPoint?
    private var tooltipWindow: NSWindow?
    private var tooltipUpdateTimer: Timer?
    
    // Chart dimensions and margins
    private let margins = NSEdgeInsets(top: 40, left: 60, bottom: 60, right: 40)
    private var chartRect: NSRect {
        return NSRect(
            x: margins.left,
            y: margins.bottom,
            width: bounds.width - margins.left - margins.right,
            height: bounds.height - margins.top - margins.bottom
        )
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
        
        // Enable mouse tracking
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    deinit {
        print("ChartView: Starting cleanup in deinit")
        
        // 停止定时器
        tooltipUpdateTimer?.invalidate()
        tooltipUpdateTimer = nil
        
        // 立即清理tooltip
        if let tooltip = tooltipWindow {
            tooltip.orderOut(nil)
            tooltipWindow = nil
        }
        
        // 清理所有tracking areas
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        // 清理delegate引用
        delegate = nil
        
        // 清理数据引用
        chartData = nil
        hoveredPoint = nil
        selectedPoint = nil
        
        print("ChartView: Cleanup completed in deinit")
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Clear background
        context.setFillColor(NSColor.controlBackgroundColor.cgColor)
        context.fill(bounds)
        
        guard let data = chartData, !data.isEmpty else {
            drawEmptyState(in: context)
            return
        }
        
        // Draw chart components
        if configuration.showGrid {
            drawGrid(in: context, data: data)
        }
        
        drawAxes(in: context, data: data)
        drawAxisLabels(in: context, data: data)
        drawTitle(in: context, data: data)
        
        switch configuration.chartType {
        case .line:
            drawLineChart(in: context, data: data)
        case .bar:
            drawBarChart(in: context, data: data)
        case .area:
            drawAreaChart(in: context, data: data)
        }
        
        if configuration.showTrendLine, let trendLine = data.trendLine {
            drawTrendLine(in: context, trendLine: trendLine, data: data)
        }
        
        if configuration.showDataPoints {
            drawDataPoints(in: context, data: data)
        }
        
        // Draw hovered point highlight
        if let hoveredPoint = hoveredPoint {
            drawPointHighlight(in: context, point: hoveredPoint, data: data)
        }
    }
    
    // MARK: - Empty State
    
    private func drawEmptyState(in context: CGContext) {
        let message = "No citation data available"
        let subtitle = "Add scholars and refresh data to see charts"
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        
        let titleString = NSAttributedString(string: message, attributes: titleAttributes)
        let subtitleString = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
        
        let titleSize = titleString.size()
        let subtitleSize = subtitleString.size()
        
        let totalHeight = titleSize.height + 8 + subtitleSize.height
        let startY = (bounds.height - totalHeight) / 2
        
        let titleRect = NSRect(
            x: (bounds.width - titleSize.width) / 2,
            y: startY + subtitleSize.height + 8,
            width: titleSize.width,
            height: titleSize.height
        )
        
        let subtitleRect = NSRect(
            x: (bounds.width - subtitleSize.width) / 2,
            y: startY,
            width: subtitleSize.width,
            height: subtitleSize.height
        )
        
        titleString.draw(in: titleRect)
        subtitleString.draw(in: subtitleRect)
    }
    
    // MARK: - Grid Drawing
    
    private func drawGrid(in context: CGContext, data: ChartData) {
        context.setStrokeColor(NSColor.separatorColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        
        let rect = chartRect
        let _ = data.yAxisRange
        let gridLines = 5
        
        // Horizontal grid lines
        for i in 0...gridLines {
            let y = rect.minY + (rect.height / CGFloat(gridLines)) * CGFloat(i)
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        
        // Vertical grid lines
        if !data.points.isEmpty {
            let pointCount = data.points.count
            let maxVerticalLines = min(8, pointCount)
            let step = max(1, pointCount / maxVerticalLines)
            
            for i in stride(from: 0, to: pointCount, by: step) {
                let x = rect.minX + (rect.width / CGFloat(pointCount - 1)) * CGFloat(i)
                context.move(to: CGPoint(x: x, y: rect.minY))
                context.addLine(to: CGPoint(x: x, y: rect.maxY))
            }
        }
        
        context.strokePath()
    }
    
    // MARK: - Axes Drawing
    
    private func drawAxes(in context: CGContext, data: ChartData) {
        context.setStrokeColor(NSColor.labelColor.cgColor)
        context.setLineWidth(1.0)
        
        let rect = chartRect
        
        // X-axis
        context.move(to: CGPoint(x: rect.minX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Y-axis
        context.move(to: CGPoint(x: rect.minX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        context.strokePath()
    }
    
    // MARK: - Label Drawing
    
    private func drawAxisLabels(in context: CGContext, data: ChartData) {
        let rect = chartRect
        let yRange = data.yAxisRange
        
        // Y-axis labels
        let yLabelCount = 5
        let yStep = (yRange.max - yRange.min) / Double(yLabelCount)
        
        for i in 0...yLabelCount {
            let value = yRange.min + Double(i) * yStep
            let y = rect.minY + (rect.height / CGFloat(yLabelCount)) * CGFloat(i)
            
            let labelText = String(format: "%.0f", value)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            
            let attributedString = NSAttributedString(string: labelText, attributes: attributes)
            let size = attributedString.size()
            let labelRect = NSRect(
                x: rect.minX - size.width - 8,
                y: y - size.height / 2,
                width: size.width,
                height: size.height
            )
            
            attributedString.draw(in: labelRect)
        }
        
        // X-axis labels
        let xLabels = data.xAxisLabels
        if !xLabels.isEmpty && !data.points.isEmpty {
            let maxLabels = min(8, xLabels.count)
            let step = max(1, xLabels.count / maxLabels)
            
            for i in stride(from: 0, to: xLabels.count, by: step) {
                let x = rect.minX + (rect.width / CGFloat(data.points.count - 1)) * CGFloat(i)
                let label = xLabels[i]
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                
                let attributedString = NSAttributedString(string: label, attributes: attributes)
                let size = attributedString.size()
                let labelRect = NSRect(
                    x: x - size.width / 2,
                    y: rect.minY - size.height - 8,
                    width: size.width,
                    height: size.height
                )
                
                attributedString.draw(in: labelRect)
            }
        }
    }
    
    // MARK: - Title Drawing
    
    private func drawTitle(in context: CGContext, data: ChartData) {
        // Main title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: NSColor.labelColor
        ]
        
        let titleString = NSAttributedString(string: data.title, attributes: titleAttributes)
        let titleSize = titleString.size()
        let titleRect = NSRect(
            x: (bounds.width - titleSize.width) / 2,
            y: bounds.height - margins.top + 10,
            width: titleSize.width,
            height: titleSize.height
        )
        
        titleString.draw(in: titleRect)
        
        // Subtitle
        if let subtitle = data.subtitle {
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            
            let subtitleString = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
            let subtitleSize = subtitleString.size()
            let subtitleRect = NSRect(
                x: (bounds.width - subtitleSize.width) / 2,
                y: titleRect.minY - subtitleSize.height - 4,
                width: subtitleSize.width,
                height: subtitleSize.height
            )
            
            subtitleString.draw(in: subtitleRect)
        }
    }
    
    // MARK: - Chart Type Drawing
    
    private func drawLineChart(in context: CGContext, data: ChartData) {
        guard !data.points.isEmpty else { return }
        
        let rect = chartRect
        let yRange = data.yAxisRange
        let points = data.points
        
        context.setStrokeColor(configuration.colorScheme.primaryColor.cgColor)
        context.setLineWidth(2.0)
        
        // Handle single point case
        if points.count == 1 {
            let point = points[0]
            let x = rect.minX + rect.width / 2 // Center the single point
            let y = rect.minY + (rect.height * CGFloat((point.y - yRange.min) / (yRange.max - yRange.min)))
            
            // Draw a horizontal line to show the value
            context.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: y))
            context.addLine(to: CGPoint(x: rect.minX + rect.width * 0.8, y: y))
            context.strokePath()
            
            // Draw a prominent point
            context.setFillColor(configuration.colorScheme.primaryColor.cgColor)
            let pointRect = CGRect(x: x - 6, y: y - 6, width: 12, height: 12)
            context.fillEllipse(in: pointRect)
            
            return
        }
        
        // Create path for multiple points
        let path = CGMutablePath()
        
        for (index, point) in points.enumerated() {
            let x = rect.minX + (rect.width / CGFloat(points.count - 1)) * CGFloat(index)
            let y = rect.minY + (rect.height * CGFloat((point.y - yRange.min) / (yRange.max - yRange.min)))
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                if configuration.smoothLines {
                    // Add smooth curve (simplified Bezier curve)
                    let previousIndex = index - 1
                    let prevX = rect.minX + (rect.width / CGFloat(points.count - 1)) * CGFloat(previousIndex)
                    let prevY = rect.minY + (rect.height * CGFloat((points[previousIndex].y - yRange.min) / (yRange.max - yRange.min)))
                    
                    let controlPoint1 = CGPoint(x: prevX + (x - prevX) * 0.5, y: prevY)
                    let controlPoint2 = CGPoint(x: prevX + (x - prevX) * 0.5, y: y)
                    
                    path.addCurve(to: CGPoint(x: x, y: y), control1: controlPoint1, control2: controlPoint2)
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        
        context.addPath(path)
        context.strokePath()
    }
    
    private func drawBarChart(in context: CGContext, data: ChartData) {
        guard !data.points.isEmpty else { return }
        
        let rect = chartRect
        let yRange = data.yAxisRange
        let points = data.points
        
        context.setFillColor(configuration.colorScheme.primaryColor.cgColor)
        
        // Handle single point case
        if points.count == 1 {
            let point = points[0]
            let barWidth = min(rect.width * 0.3, 60) // Reasonable width for single bar
            let x = rect.minX + (rect.width - barWidth) / 2 // Center the bar
            let height = rect.height * CGFloat((point.y - yRange.min) / (yRange.max - yRange.min))
            let y = rect.minY
            
            let barRect = CGRect(x: x, y: y, width: barWidth, height: height)
            context.fill(barRect)
            return
        }
        
        // Multiple points
        let barWidth = rect.width / CGFloat(points.count) * 0.8
        let barSpacing = rect.width / CGFloat(points.count) * 0.2
        
        for (index, point) in points.enumerated() {
            let x = rect.minX + (rect.width / CGFloat(points.count)) * CGFloat(index) + barSpacing / 2
            let height = rect.height * CGFloat((point.y - yRange.min) / (yRange.max - yRange.min))
            let y = rect.minY
            
            let barRect = CGRect(x: x, y: y, width: barWidth, height: height)
            context.fill(barRect)
        }
    }
    
    private func drawAreaChart(in context: CGContext, data: ChartData) {
        guard !data.points.isEmpty else { return }
        
        let rect = chartRect
        let yRange = data.yAxisRange
        let points = data.points
        
        // Draw filled area
        context.setFillColor(configuration.colorScheme.secondaryColor.cgColor)
        
        // Handle single point case
        if points.count == 1 {
            let point = points[0]
            let _ = rect.minX + rect.width / 2
            let y = rect.minY + (rect.height * CGFloat((point.y - yRange.min) / (yRange.max - yRange.min)))
            
            // Create a small area around the single point
            let areaWidth = rect.width * 0.6
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.minX + (rect.width - areaWidth) / 2, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + (rect.width - areaWidth) / 2, y: y))
            path.addLine(to: CGPoint(x: rect.minX + (rect.width + areaWidth) / 2, y: y))
            path.addLine(to: CGPoint(x: rect.minX + (rect.width + areaWidth) / 2, y: rect.minY))
            path.closeSubpath()
            
            context.addPath(path)
            context.fillPath()
            
            // Draw line on top
            drawLineChart(in: context, data: data)
            return
        }
        
        let path = CGMutablePath()
        
        // Start from bottom-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Add points
        for (index, point) in points.enumerated() {
            let x = rect.minX + (rect.width / CGFloat(points.count - 1)) * CGFloat(index)
            let y = rect.minY + (rect.height * CGFloat((point.y - yRange.min) / (yRange.max - yRange.min)))
            
            if index == 0 {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Close path to bottom-right
        let lastX = rect.minX + rect.width
        path.addLine(to: CGPoint(x: lastX, y: rect.minY))
        path.closeSubpath()
        
        context.addPath(path)
        context.fillPath()
        
        // Draw line on top
        drawLineChart(in: context, data: data)
    }
    
    // MARK: - Trend Line Drawing
    
    private func drawTrendLine(in context: CGContext, trendLine: TrendLineData, data: ChartData) {
        let rect = chartRect
        let yRange = data.yAxisRange
        
        context.setStrokeColor(NSColor.systemRed.withAlphaComponent(0.7).cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [5, 3])
        
        let startPoint = trendLine.points.first!
        let endPoint = trendLine.points.last!
        
        // Convert trend line points to chart coordinates
        let startX = rect.minX
        let startY = rect.minY + (rect.height * CGFloat((startPoint.y - yRange.min) / (yRange.max - yRange.min)))
        
        let endX = rect.maxX
        let endY = rect.minY + (rect.height * CGFloat((endPoint.y - yRange.min) / (yRange.max - yRange.min)))
        
        context.move(to: CGPoint(x: startX, y: startY))
        context.addLine(to: CGPoint(x: endX, y: endY))
        context.strokePath()
        
        // Reset line dash
        context.setLineDash(phase: 0, lengths: [])
    }
    
    // MARK: - Data Points Drawing
    
    private func drawDataPoints(in context: CGContext, data: ChartData) {
        guard !data.points.isEmpty else { return }
        
        let rect = chartRect
        let yRange = data.yAxisRange
        let points = data.points
        
        context.setFillColor(configuration.colorScheme.primaryColor.cgColor)
        context.setStrokeColor(NSColor.controlBackgroundColor.cgColor)
        context.setLineWidth(2.0)
        
        for (index, point) in points.enumerated() {
            let x = rect.minX + (rect.width / CGFloat(points.count - 1)) * CGFloat(index)
            let y = rect.minY + (rect.height * CGFloat((point.y - yRange.min) / (yRange.max - yRange.min)))
            
            let pointRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
            
            context.fillEllipse(in: pointRect)
            context.strokeEllipse(in: pointRect)
        }
    }
    
    // MARK: - Point Highlight Drawing
    
    private func drawPointHighlight(in context: CGContext, point: ChartDataPoint, data: ChartData) {
        let rect = chartRect
        let yRange = data.yAxisRange
        
        guard let index = data.points.firstIndex(where: { $0.date == point.date }) else { return }
        
        let x = rect.minX + (rect.width / CGFloat(data.points.count - 1)) * CGFloat(index)
        let y = rect.minY + (rect.height * CGFloat((point.y - yRange.min) / (yRange.max - yRange.min)))
        
        // Draw highlight circle
        context.setFillColor(configuration.colorScheme.primaryColor.withAlphaComponent(0.3).cgColor)
        context.setStrokeColor(configuration.colorScheme.primaryColor.cgColor)
        context.setLineWidth(2.0)
        
        let highlightRect = CGRect(x: x - 8, y: y - 8, width: 16, height: 16)
        context.fillEllipse(in: highlightRect)
        context.strokeEllipse(in: highlightRect)
        
        // Draw vertical line
        context.setStrokeColor(configuration.colorScheme.primaryColor.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: x, y: rect.minY))
        context.addLine(to: CGPoint(x: x, y: rect.maxY))
        context.strokePath()
    }
    
    // MARK: - Mouse Handling
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func mouseMoved(with event: NSEvent) {
        // 停止之前的定时器
        tooltipUpdateTimer?.invalidate()
        tooltipUpdateTimer = nil
        
        // 立即处理鼠标移动
        let location = convert(event.locationInWindow, from: nil)
        
        // 检查基本条件
        guard window != nil, superview != nil, !isHidden, bounds.contains(location) else {
            // 如果条件不满足，清理状态
            if hoveredPoint != nil {
                hoveredPoint = nil
                needsDisplay = true
                hideTooltipImmediately()
                delegate?.chartView(self, didHoverPoint: nil)
            }
            return
        }
        
        let point = findNearestPoint(to: location)
        
        if point != hoveredPoint {
            hoveredPoint = point
            needsDisplay = true
            
            // 安全地调用delegate
            delegate?.chartView(self, didHoverPoint: point)
            
            if let point = point {
                // 直接同步显示tooltip，排查定时器问题
                print("[TooltipDebug] mouseMoved: 直接调用showTooltipSafely")
                if let currentWindow = self.window {
                    let currentLocation = NSEvent.mouseLocation
                    let windowLocation = currentWindow.convertFromScreen(NSRect(origin: currentLocation, size: .zero)).origin
                    let viewLocation = self.convert(windowLocation, from: nil)
                    self.showTooltipSafely(for: point, at: viewLocation)
                }
            } else {
                hideTooltipImmediately()
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        // 停止任何待处理的tooltip更新
        tooltipUpdateTimer?.invalidate()
        tooltipUpdateTimer = nil
        
        hoveredPoint = nil
        needsDisplay = true
        hideTooltipImmediately()
        
        // 安全地调用delegate
        delegate?.chartView(self, didHoverPoint: nil)
    }
    
    override func mouseDown(with event: NSEvent) {
        guard window != nil, superview != nil else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        if let point = findNearestPoint(to: location) {
            selectedPoint = point
            delegate?.chartView(self, didSelectPoint: point)
        }
    }
    
    // MARK: - Point Finding
    
    private func findNearestPoint(to location: NSPoint) -> ChartDataPoint? {
        guard let data = chartData, 
              !data.points.isEmpty else { 
            print("ChartView: findNearestPoint - no data or empty points")
            return nil 
        }
        
        let rect = chartRect
        
        // 检查rect是否有效
        guard rect.width > 0, rect.height > 0 else {
            print("ChartView: findNearestPoint - invalid chart rect")
            return nil
        }
        
        // 检查位置是否在图表区域内
        guard rect.contains(location) else { return nil }
        
        let yRange = data.yAxisRange
        let points = data.points
        
        // 防止除零错误和无效范围
        guard yRange.max > yRange.min, 
              yRange.max.isFinite, 
              yRange.min.isFinite else { 
            print("ChartView: findNearestPoint - invalid Y range")
            return nil 
        }
        
        var nearestPoint: ChartDataPoint?
        var nearestDistance: CGFloat = CGFloat.greatestFiniteMagnitude
        
        for (index, point) in points.enumerated() {
            // 验证point.y是有效数值
            guard point.y.isFinite else { continue }
            
            // 防止points.count为1时的除零错误
            let x: CGFloat
            if points.count == 1 {
                x = rect.minX + rect.width / 2
            } else {
                x = rect.minX + (rect.width / CGFloat(points.count - 1)) * CGFloat(index)
            }
            
            let normalizedY = (point.y - yRange.min) / (yRange.max - yRange.min)
            // 确保normalizedY在有效范围内
            let clampedY = max(0, min(1, normalizedY))
            let y = rect.minY + (rect.height * CGFloat(clampedY))
            
            // 确保计算的坐标是有效的
            guard x.isFinite, y.isFinite else { continue }
            
            let distance = sqrt(pow(location.x - x, 2) + pow(location.y - y, 2))
            
            // 确保distance是有效数值
            guard distance.isFinite else { continue }
            
            if distance < nearestDistance && distance < 20 { // 20 point tolerance
                nearestDistance = distance
                nearestPoint = point
            }
        }
        
        return nearestPoint
    }
    
    // MARK: - Tooltip
    
    private func showTooltipSafely(for point: ChartDataPoint, at location: NSPoint) {
        // 首先立即清理任何现有的tooltip
        hideTooltipImmediately()
        
        // 检查必要条件
        guard let window = window,
              !isHidden,
              window.isVisible else { 
            print("[TooltipDebug] 条件不满足，window: \(String(describing: self.window)), isHidden: \(self.isHidden), window?.isVisible: \(String(describing: self.window?.isVisible))")
            return 
        }
        
        let tooltipText = """
        Date: \(point.label)
        Citations: \(point.value)
        Source: \(point.metadata["source"] as? String ?? "Unknown")
        """
        print("[TooltipDebug] tooltipText: \n\(tooltipText)")
        
        // 创建tooltip view
        let tooltipView = TooltipView(text: tooltipText)
        let tooltipSize = tooltipView.intrinsicContentSize
        print("[TooltipDebug] tooltipSize: \(tooltipSize)")
        
        // 计算屏幕位置
        let windowLocation = convert(location, to: nil)
        let screenLocation = window.convertToScreen(NSRect(origin: windowLocation, size: .zero)).origin
        print("[TooltipDebug] screenLocation: \(screenLocation)")
        
        // 获取主窗口frame，防止tooltip超出主窗口边界
        let windowFrame = window.frame
        var tooltipX = screenLocation.x + 10
        var tooltipY = screenLocation.y - tooltipSize.height - 10
        
        // 如果tooltip超出右边界，向左偏移
        if tooltipX + tooltipSize.width > windowFrame.maxX - 8 {
            tooltipX = max(windowFrame.maxX - tooltipSize.width - 8, windowFrame.minX + 8)
        }
        // 如果tooltip超出左边界，向右偏移
        if tooltipX < windowFrame.minX + 8 {
            tooltipX = windowFrame.minX + 8
        }
        // 如果tooltip超出上边界，向下偏移
        if tooltipY + tooltipSize.height > windowFrame.maxY - 8 {
            tooltipY = windowFrame.maxY - tooltipSize.height - 8
        }
        // 如果tooltip超出下边界，向上偏移
        if tooltipY < windowFrame.minY + 8 {
            tooltipY = windowFrame.minY + 8
        }
        
        let tooltipFrame = NSRect(
            x: tooltipX,
            y: tooltipY,
            width: tooltipSize.width,
            height: tooltipSize.height
        )
        print("[TooltipDebug] tooltipFrame: \(tooltipFrame)")
        
        // 创建新的tooltip窗口
        let newTooltipWindow = NSWindow(
            contentRect: tooltipFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        newTooltipWindow.contentView = tooltipView
        newTooltipWindow.backgroundColor = NSColor.clear
        newTooltipWindow.isOpaque = false
        newTooltipWindow.level = .floating
        newTooltipWindow.hidesOnDeactivate = false  // 避免意外隐藏
        newTooltipWindow.ignoresMouseEvents = true  // 避免鼠标事件干扰
        
        // 设置窗口并显示
        tooltipWindow = newTooltipWindow
        newTooltipWindow.orderFront(nil)
        print("[TooltipDebug] tooltipWindow 已 orderFront")
    }
    
    private func hideTooltipImmediately() {
        if let tooltip = tooltipWindow {
            tooltip.orderOut(nil)
            tooltipWindow = nil
        }
    }
}

// MARK: - Tooltip View

class TooltipView: NSView {
    private let text: String
    private let attributes: [NSAttributedString.Key: Any]
    
    init(text: String) {
        self.text = text
        self.attributes = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor
        ]
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // 清理layer相关资源
        layer = nil
    }
    
    private func setupView() {
        // 确保线程安全
        guard Thread.isMainThread else {
            DispatchQueue.main.sync {
                setupView()
            }
            return
        }
        
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.95).cgColor
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
    }
    
    override var intrinsicContentSize: NSSize {
        let sizeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11)
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: sizeAttributes)
        let size = attributedString.size()
        
        return NSSize(width: size.width + 16, height: size.height + 12)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textRect = NSRect(
            x: 8,
            y: 6,
            width: bounds.width - 16,
            height: bounds.height - 12
        )
        
        attributedString.draw(in: textRect)
    }
}