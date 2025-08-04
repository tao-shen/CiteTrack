import Foundation
import SwiftUI
import Combine

@MainActor
class ChartViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var selectedScholar: Scholar?
    @Published var selectedTimeRange: DatePeriod = .lastMonth
    @Published var chartType: ChartType = .line
    @Published var historyData: [CitationHistory] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // MARK: - Dependencies
    private let coreDataManager = CoreDataManager.shared
    private let historyManager = CitationHistoryManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Chart Configuration
    @Published var chartConfiguration: ChartConfiguration = .default
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func setSelectedScholar(_ scholar: Scholar?) {
        selectedScholar = scholar
        loadHistoryData()
    }
    
    func setTimeRange(_ timeRange: DatePeriod) {
        selectedTimeRange = timeRange
        loadHistoryData()
    }
    
    func setChartType(_ type: ChartType) {
        chartType = type
    }
    
    func loadHistoryData() {
        guard let scholar = selectedScholar else {
            historyData = []
            return
        }
        
        isLoading = true
        error = nil
        
        Task {
            await fetchHistoryData(for: scholar)
        }
    }
    
    func refreshData() async {
        await loadHistoryData()
    }
    
    // MARK: - Statistics
    
    var currentCitations: Int {
        historyData.last?.citationCount ?? 0
    }
    
    var previousCitations: Int {
        guard historyData.count > 1 else { return 0 }
        return historyData[historyData.count - 2].citationCount
    }
    
    var citationChange: Int {
        currentCitations - previousCitations
    }
    
    var growthRate: Double {
        guard previousCitations > 0 else { return 0 }
        return Double(citationChange) / Double(previousCitations) * 100
    }
    
    var dataPointsCount: Int {
        historyData.count
    }
    
    var averageCitationsPerDay: Double {
        guard !historyData.isEmpty, historyData.count > 1 else { return 0 }
        
        let firstDate = historyData.first!.timestamp
        let lastDate = historyData.last!.timestamp
        let daysDifference = lastDate.timeIntervalSince(firstDate) / (24 * 60 * 60)
        
        guard daysDifference > 0 else { return 0 }
        
        let totalIncrease = currentCitations - historyData.first!.citationCount
        return Double(totalIncrease) / daysDifference
    }
    
    var dateRange: (start: Date, end: Date) {
        let range = Date.dateRange(for: selectedTimeRange)
        return (start: range.start, end: range.end)
    }
    
    var filteredData: [CitationHistory] {
        let range = dateRange
        return historyData.filter { $0.timestamp >= range.start && $0.timestamp <= range.end }
    }
    
    // MARK: - Chart Data Processing
    
    var chartData: [(x: Date, y: Double)] {
        return filteredData.map { ($0.timestamp, Double($0.citationCount)) }
    }
    
    var trendlineData: [(x: Date, y: Double)] {
        guard chartData.count >= 2 else { return [] }
        
        // 简单线性趋势计算
        let xValues = chartData.enumerated().map { Double($0.offset) }
        let yValues = chartData.map { $0.y }
        
        let n = Double(chartData.count)
        let sumX = xValues.reduce(0, +)
        let sumY = yValues.reduce(0, +)
        let sumXY = zip(xValues, yValues).map(*).reduce(0, +)
        let sumXX = xValues.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        
        return chartData.enumerated().map { index, point in
            let trendY = slope * Double(index) + intercept
            return (point.x, trendY)
        }
    }
    
    // MARK: - Export Functions
    
    func exportChartData() -> ExportData {
        guard let scholar = selectedScholar else {
            return ExportData(scholars: [], history: [])
        }
        
        return ExportData(scholars: [scholar], history: filteredData)
    }
    
    func exportCSV() -> String {
        var csv = "Date,Citations\n"
        
        for dataPoint in filteredData {
            let dateString = DateFormatter.export.string(from: dataPoint.timestamp)
            csv += "\(dateString),\(dataPoint.citationCount)\n"
        }
        
        return csv
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 监听时间范围变化
        $selectedTimeRange
            .dropFirst()
            .sink { [weak self] _ in
                self?.loadHistoryData()
            }
            .store(in: &cancellables)
        
        // 监听学者变化
        $selectedScholar
            .dropFirst()
            .sink { [weak self] _ in
                self?.loadHistoryData()
            }
            .store(in: &cancellables)
    }
    
    private func fetchHistoryData(for scholar: Scholar) async {
        let range = dateRange
        
        await withCheckedContinuation { continuation in
            historyManager.fetchHistory(
                for: scholar.id,
                from: range.start,
                to: range.end
            ) { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success(let history):
                        self?.historyData = history
                        self?.error = nil
                        
                    case .failure(let error):
                        self?.error = error.localizedDescription
                        self?.historyData = []
                    }
                    
                    self?.isLoading = false
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Chart Type
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

// MARK: - Chart Configuration
struct ChartConfiguration: Codable, Equatable {
    let showTrendLine: Bool
    let showDataPoints: Bool
    let showGrid: Bool
    let colorScheme: String
    let animationEnabled: Bool
    
    init(
        showTrendLine: Bool = true,
        showDataPoints: Bool = true,
        showGrid: Bool = true,
        colorScheme: String = "default",
        animationEnabled: Bool = true
    ) {
        self.showTrendLine = showTrendLine
        self.showDataPoints = showDataPoints
        self.showGrid = showGrid
        self.colorScheme = colorScheme
        self.animationEnabled = animationEnabled
    }
    
    static let `default` = ChartConfiguration()
}

// MARK: - Citation History Manager Extension
extension CitationHistoryManager {
    func fetchHistory(
        for scholarId: String,
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[CitationHistory], Error>) -> Void
    ) {
        // 这里应该从Core Data获取历史数据
        // 暂时返回模拟数据
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            let mockData = self.generateMockData(for: scholarId, from: startDate, to: endDate)
            completion(.success(mockData))
        }
    }
    
    private func generateMockData(for scholarId: String, from startDate: Date, to endDate: Date) -> [CitationHistory] {
        var data: [CitationHistory] = []
        let dayInterval: TimeInterval = 24 * 60 * 60
        let totalDays = Int(endDate.timeIntervalSince(startDate) / dayInterval)
        
        // 生成最多30个数据点
        let stepSize = max(1, totalDays / 30)
        var baseCitations = Int.random(in: 100...1000)
        
        for i in stride(from: 0, through: totalDays, by: stepSize) {
            let date = startDate.addingTimeInterval(TimeInterval(i) * dayInterval)
            let variance = Int.random(in: -2...8) // 模拟引用数的自然增长
            baseCitations = max(0, baseCitations + variance)
            
            let history = CitationHistory(
                scholarId: scholarId,
                citationCount: baseCitations,
                timestamp: date
            )
            data.append(history)
        }
        
        return data.sorted { $0.timestamp < $1.timestamp }
    }
}