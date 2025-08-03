import SwiftUI
import Charts

@available(iOS 16.0, *)
struct ChartsView: View {
    
    // MARK: - Properties
    let scholars: [Scholar]
    
    // MARK: - Environment Objects
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    // MARK: - State
    @State private var selectedScholar: Scholar?
    @State private var selectedTimeRange: DatePeriod = .lastMonth
    @State private var chartType: ChartType = .line
    @State private var historyData: [CitationHistory] = []
    @State private var isLoading = false
    
    // MARK: - Chart Type Enum
    enum ChartType: String, CaseIterable {
        case line = "line"
        case bar = "bar"
        case area = "area"
        
        var displayName: String {
            switch self {
            case .line:
                return "line_chart".localized
            case .bar:
                return "bar_chart".localized
            case .area:
                return "area_chart".localized
            }
        }
        
        var icon: String {
            switch self {
            case .line:
                return "chart.xyaxis.line"
            case .bar:
                return "chart.bar"
            case .area:
                return "chart.area"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if scholars.isEmpty {
                    emptyStateView
                } else {
                    chartsContent
                }
            }
            .navigationTitle("charts".localized)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if selectedScholar == nil && !scholars.isEmpty {
                    selectedScholar = scholars.first
                }
                loadHistoryData()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("no_data_to_chart".localized)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("add_scholars_to_see_charts".localized)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Charts Content
    
    private var chartsContent: some View {
        VStack(spacing: 16) {
            // 控制选项
            controlsSection
            
            // 图表区域
            if isLoading {
                chartLoadingView
            } else if historyData.isEmpty {
                chartEmptyView
            } else {
                chartDisplayView
            }
            
            // 统计信息
            statisticsSection
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Controls Section
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // 学者选择
            if scholars.count > 1 {
                Picker("select_scholar".localized, selection: $selectedScholar) {
                    ForEach(scholars, id: \.id) { scholar in
                        Text(scholar.displayName)
                            .tag(scholar as Scholar?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedScholar) { _ in
                    loadHistoryData()
                }
            }
            
            HStack {
                // 时间范围选择
                Picker("time_range".localized, selection: $selectedTimeRange) {
                    ForEach(DatePeriod.allCases, id: \.self) { period in
                        Text(period.displayName)
                            .tag(period)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedTimeRange) { _ in
                    loadHistoryData()
                }
                
                Spacer()
                
                // 图表类型选择
                Picker("chart_type".localized, selection: $chartType) {
                    ForEach(ChartType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Chart Views
    
    private var chartLoadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("loading_chart_data".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(height: 200)
    }
    
    private var chartEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("no_chart_data".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("chart_data_will_appear".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .padding()
    }
    
    @available(iOS 16.0, *)
    private var chartDisplayView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let scholar = selectedScholar {
                Text("\(scholar.displayName) - \(selectedTimeRange.displayName)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Chart(historyData, id: \.id) { item in
                switch chartType {
                case .line:
                    LineMark(
                        x: .value("Date", item.timestamp),
                        y: .value("Citations", item.citationCount)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    
                case .bar:
                    BarMark(
                        x: .value("Date", item.timestamp),
                        y: .value("Citations", item.citationCount)
                    )
                    .foregroundStyle(.blue)
                    
                case .area:
                    AreaMark(
                        x: .value("Date", item.timestamp),
                        y: .value("Citations", item.citationCount)
                    )
                    .foregroundStyle(.blue.opacity(0.3))
                    
                    LineMark(
                        x: .value("Date", item.timestamp),
                        y: .value("Citations", item.citationCount)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("statistics".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            if let scholar = selectedScholar, !historyData.isEmpty {
                let currentCitations = historyData.last?.citationCount ?? 0
                let previousCitations = historyData.count > 1 ? historyData[historyData.count - 2].citationCount : 0
                let change = currentCitations - previousCitations
                let growth = previousCitations > 0 ? Double(change) / Double(previousCitations) * 100 : 0
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatisticsCard(
                        title: "current_citations".localized,
                        value: "\(currentCitations)",
                        icon: "quote.bubble.fill",
                        color: .blue
                    )
                    
                    StatisticsCard(
                        title: "recent_change".localized,
                        value: change >= 0 ? "+\(change)" : "\(change)",
                        icon: change >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                        color: change >= 0 ? .green : .red
                    )
                    
                    StatisticsCard(
                        title: "growth_rate".localized,
                        value: String(format: "%.1f%%", growth),
                        icon: "percent",
                        color: growth >= 0 ? .green : .red
                    )
                    
                    StatisticsCard(
                        title: "data_points".localized,
                        value: "\(historyData.count)",
                        icon: "chart.dots.scatter",
                        color: .purple
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Methods
    
    private func loadHistoryData() {
        guard let scholar = selectedScholar else {
            historyData = []
            return
        }
        
        isLoading = true
        
        // 这里应该从Core Data加载历史数据
        // 暂时使用模拟数据进行演示
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.historyData = generateMockHistoryData(for: scholar)
            self.isLoading = false
        }
    }
    
    private func generateMockHistoryData(for scholar: Scholar) -> [CitationHistory] {
        let dateRange = Date.dateRange(for: selectedTimeRange)
        let dayInterval: TimeInterval = 24 * 60 * 60
        let totalDays = Int(dateRange.end.timeIntervalSince(dateRange.start) / dayInterval)
        
        var data: [CitationHistory] = []
        let baseCitations = scholar.citations ?? 100
        
        for i in 0..<min(totalDays, 30) { // 限制最多30个数据点
            let date = dateRange.start.addingTimeInterval(TimeInterval(i) * dayInterval)
            let variance = Int.random(in: -5...10) // 随机变化
            let citations = max(0, baseCitations + variance + i)
            
            let history = CitationHistory(
                scholarId: scholar.id,
                citationCount: citations,
                timestamp: date
            )
            data.append(history)
        }
        
        return data.sorted { $0.timestamp < $1.timestamp }
    }
}

// MARK: - iOS 15 Fallback
struct ChartsViewFallback: View {
    let scholars: [Scholar]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text("charts_require_ios16".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("update_ios_for_charts".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("charts".localized)
        }
    }
}

// MARK: - Main Charts View with Version Check
struct ChartsView: View {
    let scholars: [Scholar]
    
    var body: some View {
        if #available(iOS 16.0, *) {
            ChartsView(scholars: scholars)
        } else {
            ChartsViewFallback(scholars: scholars)
        }
    }
}

// MARK: - Preview
struct ChartsView_Previews: PreviewProvider {
    static let mockScholars = [
        Scholar.mock(id: "abc123", name: "张三教授", citations: 1500),
        Scholar.mock(id: "def456", name: "李四博士", citations: 800)
    ]
    
    static var previews: some View {
        if #available(iOS 16.0, *) {
            ChartsView(scholars: mockScholars)
                .environmentObject(LocalizationManager.shared)
        } else {
            ChartsViewFallback(scholars: mockScholars)
                .environmentObject(LocalizationManager.shared)
        }
    }
}