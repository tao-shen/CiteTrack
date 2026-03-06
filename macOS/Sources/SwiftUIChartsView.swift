import SwiftUI
import Charts

// MARK: - Main Charts View
struct ChartsContentView: View {
    @StateObject private var viewModel = ChartsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.scholars.isEmpty {
                emptyState
            } else {
                // Compact toolbar
                ChartsToolbar(viewModel: viewModel)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)

                Divider()
                    .opacity(0.5)

                // Stats strip
                DashboardStripView(viewModel: viewModel)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                // Full-width chart — the hero
                CitationChartView(viewModel: viewModel)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .scholarsDataUpdated)) { _ in
            viewModel.reload()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.blue.opacity(0.6))
            }

            VStack(spacing: 6) {
                Text(L("no_scholars_title"))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                Text(L("no_scholars_message"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - View Model
class ChartsViewModel: ObservableObject {
    @Published var scholars: [Scholar] = []
    @Published var currentScholar: Scholar?
    @Published var timeRange: TimeRange = .lastMonth
    @Published var chartType: ChartType = .line
    @Published var theme: ChartTheme = .academic
    @Published var chartData: ChartData?
    @Published var isLoading = false
    @Published var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var customEndDate = Date()

    private let chartDataService = ChartDataService.shared
    private let historyManager = CitationHistoryManager.shared

    init() {
        reload()
    }

    func reload() {
        scholars = PreferencesManager.shared.scholars
        if currentScholar == nil || !scholars.contains(where: { $0.id == currentScholar?.id }) {
            currentScholar = scholars.first
        }
        loadChartData()
    }

    func selectScholar(_ scholar: Scholar) {
        guard scholar.id != currentScholar?.id else { return }
        currentScholar = scholar
        loadChartData()
    }

    func selectTimeRange(_ range: TimeRange) {
        if range == .custom { return }
        timeRange = range
        loadChartData()
    }

    func applyCustomRange(start: Date, end: Date) {
        customStartDate = min(start, end)
        customEndDate = max(start, end)
        timeRange = .custom
        loadChartData()
    }

    func refresh() {
        guard !isLoading else { return }
        loadChartData()
    }

    func loadChartData() {
        guard let scholar = currentScholar else {
            chartData = nil
            return
        }

        isLoading = true

        let completion: (Result<[CitationHistory], Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                switch result {
                case .success(let history):
                    self.processChartData(history, for: scholar)
                case .failure:
                    self.chartData = nil
                }
            }
        }

        if timeRange == .custom {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: customStartDate)
            let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: customEndDate)) ?? customEndDate
            historyManager.getHistory(for: scholar.id, from: start, to: end, completion: completion)
        } else {
            historyManager.getHistory(for: scholar.id, in: timeRange, completion: completion)
        }
    }

    private func processChartData(_ history: [CitationHistory], for scholar: Scholar) {
        let config = ChartConfiguration(
            timeRange: timeRange,
            chartType: mappedChartType,
            showTrendLine: chartType != .bar && chartType != .scatter,
            showDataPoints: chartType != .area,
            showGrid: true,
            smoothLines: chartType == .smoothLine,
            colorScheme: colorScheme
        )
        chartData = chartDataService.prepareChartData(from: history, configuration: config, scholarName: scholar.name)
    }

    private var mappedChartType: ChartConfiguration.ChartType {
        switch chartType {
        case .bar: return .bar
        case .area: return .area
        default: return .line
        }
    }

    private var colorScheme: ChartConfiguration.ColorScheme {
        switch theme {
        case .academic: return .blue
        case .nature: return .green
        case .warm: return .orange
        case .mono, .auto: return .system
        }
    }

    func exportData() {
        guard let scholar = currentScholar else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText, .json]
        savePanel.nameFieldStringValue = "citations-\(scholar.id)"

        savePanel.begin { [weak self] response in
            guard response == .OK, let url = savePanel.url, let self = self else { return }

            let completion: (Result<[CitationHistory], Error>) -> Void = { result in
                switch result {
                case .success(let history):
                    do {
                        let data: Data
                        if url.pathExtension.lowercased() == "json" {
                            data = try JSONEncoder().encode(history)
                        } else {
                            var csv = "Date,Citations,Scholar\n"
                            for entry in history {
                                csv += "\(entry.timestamp),\(entry.citationCount),\(scholar.name)\n"
                            }
                            data = csv.data(using: .utf8) ?? Data()
                        }
                        try data.write(to: url)
                    } catch {
                        print("Export error: \(error)")
                    }
                case .failure(let error):
                    print("Export error: \(error)")
                }
            }

            if self.timeRange == .custom {
                let calendar = Calendar.current
                let start = calendar.startOfDay(for: self.customStartDate)
                let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: self.customEndDate)) ?? self.customEndDate
                self.historyManager.getHistory(for: scholar.id, from: start, to: end, completion: completion)
            } else {
                self.historyManager.getHistory(for: scholar.id, in: self.timeRange, completion: completion)
            }
        }
    }
}

// MARK: - Toolbar
struct ChartsToolbar: View {
    @ObservedObject var viewModel: ChartsViewModel
    @State private var showCustomRange = false

    var body: some View {
        HStack(spacing: 12) {
            // Scholar picker — prominent
            Menu {
                ForEach(viewModel.scholars, id: \.id) { scholar in
                    Button(action: { viewModel.selectScholar(scholar) }) {
                        HStack {
                            Text(scholar.name.isEmpty ? "Scholar \(scholar.id.prefix(8))" : scholar.name)
                            if scholar.id == viewModel.currentScholar?.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                    Text(viewModel.currentScholar.map { $0.name.isEmpty ? "Scholar \($0.id.prefix(8))" : $0.name } ?? "Select")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Spacer()

            // Time range as segmented pills
            HStack(spacing: 2) {
                ForEach(TimeRange.allCases.filter { $0 != .custom }, id: \.self) { range in
                    Button(action: { viewModel.selectTimeRange(range) }) {
                        Text(shortLabel(for: range))
                            .font(.system(size: 11, weight: viewModel.timeRange == range ? .semibold : .regular))
                            .foregroundStyle(viewModel.timeRange == range ? .white : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                viewModel.timeRange == range
                                ? AnyShapeStyle(Color.blue)
                                : AnyShapeStyle(Color.clear),
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { showCustomRange = true }) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(viewModel.timeRange == .custom ? .white : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            viewModel.timeRange == .custom
                            ? AnyShapeStyle(Color.blue)
                            : AnyShapeStyle(Color.clear),
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                }
                .buttonStyle(.plain)
                .help(L("time_range_custom"))
            }
            .padding(3)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 7))

            Spacer()

            // Chart type picker
            Picker("", selection: $viewModel.chartType) {
                ForEach(ChartType.allCases, id: \.self) { type in
                    Image(systemName: chartTypeIcon(type)).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .onChange(of: viewModel.chartType) { _ in
                viewModel.loadChartData()
            }

            // Actions
            HStack(spacing: 4) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 20)
                }

                Button(action: viewModel.refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoading)
                .help(L("button_update"))

                Button(action: viewModel.exportData) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.currentScholar == nil)
                .help(L("export_to_device"))
            }
        }
        .sheet(isPresented: $showCustomRange) {
            CustomRangeSheet(
                startDate: $viewModel.customStartDate,
                endDate: $viewModel.customEndDate,
                onApply: {
                    viewModel.applyCustomRange(start: viewModel.customStartDate, end: viewModel.customEndDate)
                    showCustomRange = false
                },
                onCancel: { showCustomRange = false }
            )
        }
    }

    private func shortLabel(for range: TimeRange) -> String {
        switch range {
        case .lastWeek: return "1W"
        case .lastMonth: return "1M"
        case .lastQuarter: return "3M"
        case .lastYear: return "1Y"
        case .custom: return ""
        }
    }

    private func chartTypeIcon(_ type: ChartType) -> String {
        switch type {
        case .line: return "chart.xyaxis.line"
        case .smoothLine: return "point.topleft.down.to.point.bottomright.curvepath"
        case .area: return "chart.line.uptrend.xyaxis"
        case .bar: return "chart.bar"
        case .scatter: return "circle.dotted"
        }
    }
}

// MARK: - Custom Range Sheet
struct CustomRangeSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    var onApply: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text(L("time_range_custom_title"))
                    .font(.headline)
            }

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("label_start_date"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("label_end_date"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }

            HStack {
                Spacer()
                Button(L("button_cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(L("button_apply"), action: onApply)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

// MARK: - Dashboard Stats Strip
struct DashboardStripView: View {
    @ObservedObject var viewModel: ChartsViewModel

    var body: some View {
        HStack(spacing: 0) {
            if let data = viewModel.chartData, let scholar = viewModel.currentScholar {
                let stats = data.statistics

                StripStat(
                    label: L("total_citations"),
                    value: "\((scholar.citations ?? 0).formatted())",
                    icon: "quote.bubble.fill",
                    color: .blue
                )

                StripDivider()

                StripStat(
                    label: L("monthly_change"),
                    value: formatChange(stats.totalChange),
                    icon: stats.totalChange >= 0 ? "arrow.up.right" : "arrow.down.right",
                    color: stats.totalChange >= 0 ? .green : .red,
                    badge: String(format: "%+.1f%%", stats.growthRate)
                )

                StripDivider()

                StripStat(
                    label: L("growth_rate"),
                    value: String(format: "%.1f%%", stats.growthRate),
                    icon: "percent",
                    color: stats.growthRate >= 0 ? .green : .orange
                )

                StripDivider()

                StripStat(
                    label: L("trend_label"),
                    value: "\(stats.trend.symbol) \(stats.trend.displayName)",
                    icon: trendIcon(stats.trend),
                    color: Color(nsColor: stats.trend.color)
                )

                StripDivider()

                StripStat(
                    label: "DATA POINTS",
                    value: "\(stats.totalDataPoints)",
                    icon: "number",
                    color: .secondary
                )

                if let range = stats.valueRange {
                    StripDivider()
                    StripStat(
                        label: "RANGE",
                        value: "\(range.min) - \(range.max)",
                        icon: "arrow.left.and.right",
                        color: .secondary
                    )
                }
            } else {
                ForEach(0..<4, id: \.self) { i in
                    if i > 0 { StripDivider() }
                    StripStat(label: "--", value: "--", icon: "minus", color: .gray)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
    }

    private func formatChange(_ change: Int) -> String {
        change >= 0 ? "+\(change)" : "\(change)"
    }

    private func trendIcon(_ trend: CitationTrend) -> String {
        switch trend {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "arrow.right"
        case .unknown: return "questionmark"
        }
    }
}

struct StripStat: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)

                HStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(color)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

struct StripDivider: View {
    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 28)
            .padding(.horizontal, 4)
    }
}

// MARK: - Citation Chart
struct CitationChartView: View {
    @ObservedObject var viewModel: ChartsViewModel
    @State private var hoveredPoint: ChartDataPoint?
    @State private var hoverLocation: CGPoint = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Chart header
            if let data = viewModel.chartData {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.title)
                            .font(.system(size: 15, weight: .semibold))
                        if let subtitle = data.subtitle {
                            Text(subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Theme selector — minimal
                    Menu {
                        ForEach(ChartTheme.allCases, id: \.self) { theme in
                            Button(action: {
                                viewModel.theme = theme
                                viewModel.loadChartData()
                            }) {
                                HStack {
                                    Text(theme.displayName)
                                    if theme == viewModel.theme {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(nsColor: viewModel.theme.colors.primary))
                                .frame(width: 8, height: 8)
                            Text(viewModel.theme.displayName)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }

            // The chart
            if let data = viewModel.chartData, !data.isEmpty {
                chartContent(data)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundStyle(.quaternary)
                    Text(L("no_data_available"))
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
    }

    private func yAxisDomain(for data: ChartData) -> ClosedRange<Int> {
        let values = data.points.map { $0.value }
        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }
        if minVal == maxVal {
            let center = minVal
            let pad = max(center / 20, 10)
            return (center - pad)...(center + pad)
        }
        let spread = maxVal - minVal
        let padding = max(spread / 4, 5)
        // For bar charts, start from 0 if the min is close to 0
        if viewModel.chartType == .bar && minVal < spread * 2 {
            return 0...(maxVal + padding)
        }
        return max(0, minVal - padding)...(maxVal + padding)
    }

    @ViewBuilder
    private func chartContent(_ data: ChartData) -> some View {
        let themeColors = viewModel.theme.colors

        Chart {
            ForEach(Array(data.points.enumerated()), id: \.offset) { _, point in
                switch viewModel.chartType {
                case .line, .smoothLine:
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Citations", point.value)
                    )
                    .foregroundStyle(Color(nsColor: themeColors.primary))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(viewModel.chartType == .smoothLine ? .catmullRom : .linear)

                    if viewModel.chartType != .smoothLine {
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Citations", point.value)
                        )
                        .foregroundStyle(Color(nsColor: themeColors.primary))
                        .symbolSize(24)
                    }

                case .area:
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Citations", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(nsColor: themeColors.primary).opacity(0.25),
                                Color(nsColor: themeColors.primary).opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Citations", point.value)
                    )
                    .foregroundStyle(Color(nsColor: themeColors.primary))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                case .bar:
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value("Citations", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(nsColor: themeColors.primary).opacity(0.8),
                                Color(nsColor: themeColors.primary).opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(3)

                case .scatter:
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Citations", point.value)
                    )
                    .foregroundStyle(Color(nsColor: themeColors.primary).opacity(0.7))
                    .symbolSize(50)
                }
            }

            // Trend line
            if let trendLine = data.trendLine, viewModel.chartType != .bar && viewModel.chartType != .scatter {
                if let firstPoint = data.points.first, let lastPoint = data.points.last {
                    let startY = trendLine.slope * 0 + trendLine.intercept
                    let endY = trendLine.slope * Double(data.points.count - 1) + trendLine.intercept

                    RuleMark(
                        xStart: .value("Start", firstPoint.date),
                        xEnd: .value("End", lastPoint.date),
                        y: .value("Trend", (startY + endY) / 2)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundStyle(Color(nsColor: themeColors.accent).opacity(0.4))
                }
            }
        }
        .chartYScale(domain: yAxisDomain(for: data))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(.quaternary)
                AxisValueLabel()
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(.quaternary)
                AxisValueLabel()
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                .border(Color.primary.opacity(0.05), width: 0.5)
        }
    }
}
