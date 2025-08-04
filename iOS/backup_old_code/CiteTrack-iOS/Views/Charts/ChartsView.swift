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
    @State private var showingScholarChart = false
    
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
                    scholarChartsList
                }
            }
            .navigationTitle("charts".localized)
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingScholarChart) {
                if let scholar = selectedScholar {
                    ScholarChartDetailView(scholar: scholar)
                }
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
    
    // MARK: - Scholar Charts List
    
    private var scholarChartsList: some View {
        List(scholars, id: \.id) { scholar in
            ScholarChartRowView(scholar: scholar) {
                selectedScholar = scholar
                showingScholarChart = true
            }
        }
        .listStyle(PlainListStyle())
    }
    
}

// MARK: - Scholar Chart Row View
struct ScholarChartRowView: View {
    let scholar: Scholar
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 学者头像
                Circle()
                    .fill(Color(scholar.id.hashColor))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(scholar.name.initials())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                // 学者信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(scholar.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack {
                        Image(systemName: "quote.bubble.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        if let citations = scholar.citations {
                            Text("\(citations) citations")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("no_data".localized)
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if let lastUpdated = scholar.lastUpdated {
                        Text("updated_time_ago".localized.replacingOccurrences(of: "%@", with: lastUpdated.timeAgoString))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 箭头图标
                Image(systemName: "chart.xyaxis.line")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Scholar Chart Detail View
@available(iOS 16.0, *)
struct ScholarChartDetailView: View {
    let scholar: Scholar
    
    @Environment(\.dismiss) private var dismiss
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
            case .line: return "折线图"
            case .bar: return "柱状图"
            case .area: return "面积图"
            }
        }
        
        var icon: String {
            switch self {
            case .line: return "chart.xyaxis.line"
            case .bar: return "chart.bar"
            case .area: return "chart.area"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 学者头部信息
                    scholarHeaderView
                    
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
                }
                .padding()
            }
            .navigationTitle("citation_chart".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadHistoryData()
            }
        }
    }
    
    // MARK: - Scholar Header View
    private var scholarHeaderView: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color(scholar.id.hashColor))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(scholar.name.initials())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(spacing: 4) {
                Text(scholar.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let citations = scholar.citations {
                    Text("\(citations) citations")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                } else {
                    Text("no_citation_data".localized)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
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
    
    private var chartDisplayView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(scholar.displayName) - \(selectedTimeRange.displayName)")
                .font(.headline)
                .foregroundColor(.primary)
            
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
            .frame(height: 250)
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
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("statistics".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            if !historyData.isEmpty {
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
        isLoading = true
        
        // 模拟加载数据
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
        
        for i in 0..<min(totalDays, 30) {
            let date = dateRange.start.addingTimeInterval(TimeInterval(i) * dayInterval)
            let variance = Int.random(in: -5...10)
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