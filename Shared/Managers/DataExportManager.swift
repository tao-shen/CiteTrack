import Foundation
import Combine

// MARK: - Data Export Manager
public class DataExportManager: ObservableObject {
    public static let shared = DataExportManager()
    
    @Published public var isExporting: Bool = false
    @Published public var exportProgress: Double = 0.0
    @Published public var lastExportDate: Date?
    
    private let settingsManager = SettingsManager.shared
    private let historyManager = CitationHistoryManager.shared
    
    private init() {}
    
    // MARK: - Export Methods
    
    /// Export all data to specified format
    public func exportAllData(
        format: ExportFormat,
        includeHistory: Bool = true,
        completion: @escaping (Result<ExportResult, ExportError>) -> Void
    ) {
        guard !isExporting else {
            completion(.failure(.exportInProgress))
            return
        }
        
        DispatchQueue.main.async {
            self.isExporting = true
            self.exportProgress = 0.0
        }
        
        Task {
            do {
                let result = try await performExport(format: format, includeHistory: includeHistory)
                
                await MainActor.run {
                    self.isExporting = false
                    self.exportProgress = 1.0
                    self.lastExportDate = Date()
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.exportProgress = 0.0
                    
                    if let exportError = error as? ExportError {
                        completion(.failure(exportError))
                    } else {
                        completion(.failure(.unknown(error)))
                    }
                }
            }
        }
    }
    
    /// Export specific scholars
    public func exportScholars(
        _ scholars: [Scholar],
        format: ExportFormat,
        includeHistory: Bool = true,
        completion: @escaping (Result<ExportResult, ExportError>) -> Void
    ) {
        guard !isExporting else {
            completion(.failure(.exportInProgress))
            return
        }
        
        DispatchQueue.main.async {
            self.isExporting = true
            self.exportProgress = 0.0
        }
        
        Task {
            do {
                let result = try await performScholarExport(
                    scholars: scholars,
                    format: format,
                    includeHistory: includeHistory
                )
                
                await MainActor.run {
                    self.isExporting = false
                    self.exportProgress = 1.0
                    self.lastExportDate = Date()
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.exportProgress = 0.0
                    
                    if let exportError = error as? ExportError {
                        completion(.failure(exportError))
                    } else {
                        completion(.failure(.unknown(error)))
                    }
                }
            }
        }
    }
    
    /// Export chart data
    public func exportChartData(
        for scholar: Scholar,
        timeRange: DatePeriod,
        format: ExportFormat,
        completion: @escaping (Result<ExportResult, ExportError>) -> Void
    ) {
        Task {
            do {
                let result = try await performChartExport(
                    scholar: scholar,
                    timeRange: timeRange,
                    format: format
                )
                
                await MainActor.run {
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    if let exportError = error as? ExportError {
                        completion(.failure(exportError))
                    } else {
                        completion(.failure(.unknown(error)))
                    }
                }
            }
        }
    }
    
    // MARK: - Import Methods
    
    /// Import data from file
    public func importData(
        from data: Data,
        format: ExportFormat,
        mergeStrategy: ImportMergeStrategy = .merge,
        completion: @escaping (Result<ImportResult, ImportError>) -> Void
    ) {
        Task {
            do {
                let result = try await performImport(
                    data: data,
                    format: format,
                    mergeStrategy: mergeStrategy
                )
                
                await MainActor.run {
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    if let importError = error as? ImportError {
                        completion(.failure(importError))
                    } else {
                        completion(.failure(.unknown(error)))
                    }
                }
            }
        }
    }
    
    // MARK: - Private Export Methods
    
    private func performExport(format: ExportFormat, includeHistory: Bool) async throws -> ExportResult {
        // Step 1: Get all scholars (10%)
        await updateProgress(0.1)
        let scholars = settingsManager.getScholars()
        
        // Step 2: Get history data if needed (60%)
        var allHistory: [CitationHistory] = []
        if includeHistory {
            allHistory = try await getAllHistoryData()
        }
        await updateProgress(0.7)
        
        // Step 3: Create export data (80%)
        let exportData = ExportData(scholars: scholars, history: allHistory)
        await updateProgress(0.8)
        
        // Step 4: Format data (90%)
        let formattedData = try formatExportData(exportData, format: format)
        await updateProgress(0.9)
        
        // Step 5: Create result (100%)
        let fileName = generateFileName(format: format, prefix: "CiteTrack_Export")
        await updateProgress(1.0)
        
        return ExportResult(
            data: formattedData,
            fileName: fileName,
            format: format,
            scholars: scholars,
            historyEntries: allHistory.count,
            exportDate: Date()
        )
    }
    
    private func performScholarExport(
        scholars: [Scholar],
        format: ExportFormat,
        includeHistory: Bool
    ) async throws -> ExportResult {
        // Get history for specific scholars
        var allHistory: [CitationHistory] = []
        
        if includeHistory {
            for (index, scholar) in scholars.enumerated() {
                let progress = 0.1 + (0.6 * Double(index) / Double(scholars.count))
                await updateProgress(progress)
                
                let history = try await getHistoryForScholar(scholar.id)
                allHistory.append(contentsOf: history)
            }
        }
        
        await updateProgress(0.7)
        
        let exportData = ExportData(scholars: scholars, history: allHistory)
        let formattedData = try formatExportData(exportData, format: format)
        let fileName = generateFileName(format: format, prefix: "CiteTrack_Scholars")
        
        return ExportResult(
            data: formattedData,
            fileName: fileName,
            format: format,
            scholars: scholars,
            historyEntries: allHistory.count,
            exportDate: Date()
        )
    }
    
    private func performChartExport(
        scholar: Scholar,
        timeRange: DatePeriod,
        format: ExportFormat
    ) async throws -> ExportResult {
        let dateRange = Date.dateRange(for: timeRange)
        let history = try await getHistoryForScholar(
            scholar.id,
            from: dateRange.start,
            to: dateRange.end
        )
        
        let exportData = ExportData(scholars: [scholar], history: history)
        let formattedData = try formatExportData(exportData, format: format)
        let fileName = generateFileName(
            format: format,
            prefix: "CiteTrack_Chart_\(scholar.name.safeFileName())"
        )
        
        return ExportResult(
            data: formattedData,
            fileName: fileName,
            format: format,
            scholars: [scholar],
            historyEntries: history.count,
            exportDate: Date()
        )
    }
    
    // MARK: - Private Import Methods
    
    private func performImport(
        data: Data,
        format: ExportFormat,
        mergeStrategy: ImportMergeStrategy
    ) async throws -> ImportResult {
        let importData: ExportData
        
        switch format {
        case .json:
            importData = try JSONDecoder().decode(ExportData.self, from: data)
        case .csv:
            importData = try parseCSVData(data)
        }
        
        var importedScholars = 0
        var importedHistory = 0
        var skippedScholars = 0
        
        // Import scholars
        for scholar in importData.scholars {
            let exists = settingsManager.getScholars().contains { $0.id == scholar.id }
            
            switch mergeStrategy {
            case .merge:
                settingsManager.addScholar(scholar)
                importedScholars += 1
            case .overwrite:
                if exists {
                    settingsManager.updateScholar(scholar)
                } else {
                    settingsManager.addScholar(scholar)
                }
                importedScholars += 1
            case .skipExisting:
                if !exists {
                    settingsManager.addScholar(scholar)
                    importedScholars += 1
                } else {
                    skippedScholars += 1
                }
            }
        }
        
        // Import history
        for history in importData.history {
            await withCheckedContinuation { continuation in
                historyManager.saveHistoryEntry(history) { result in
                    if result.isSuccess {
                        importedHistory += 1
                    }
                    continuation.resume()
                }
            }
        }
        
        return ImportResult(
            importedScholars: importedScholars,
            importedHistory: importedHistory,
            skippedScholars: skippedScholars,
            importDate: Date()
        )
    }
    
    // MARK: - Helper Methods
    
    private func getAllHistoryData() async throws -> [CitationHistory] {
        return await withCheckedContinuation { continuation in
            historyManager.exportAllHistory(format: .json) { result in
                switch result {
                case .success(let jsonString):
                    if let data = jsonString.data(using: .utf8),
                       let exportData = try? JSONDecoder().decode(ExportData.self, from: data) {
                        continuation.resume(returning: exportData.history)
                    } else {
                        continuation.resume(returning: [])
                    }
                case .failure:
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func getHistoryForScholar(_ scholarId: String) async throws -> [CitationHistory] {
        return await withCheckedContinuation { continuation in
            historyManager.getAllHistory(for: scholarId) { result in
                switch result {
                case .success(let history):
                    continuation.resume(returning: history)
                case .failure:
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func getHistoryForScholar(
        _ scholarId: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [CitationHistory] {
        return await withCheckedContinuation { continuation in
            historyManager.getHistory(for: scholarId, from: startDate, to: endDate) { result in
                switch result {
                case .success(let history):
                    continuation.resume(returning: history)
                case .failure:
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func formatExportData(_ exportData: ExportData, format: ExportFormat) throws -> Data {
        switch format {
        case .json:
            return try JSONEncoder().encode(exportData)
        case .csv:
            return try createCSVData(from: exportData)
        }
    }
    
    private func createCSVData(from exportData: ExportData) throws -> Data {
        var csvContent = "Type,Scholar ID,Scholar Name,Citation Count,Date\n"
        
        // Add scholar data
        for scholar in exportData.scholars {
            let citationCount = scholar.citations ?? 0
            let date = scholar.lastUpdated?.displayString ?? ""
            csvContent += "Scholar,\(scholar.id),\"\(scholar.name)\",\(citationCount),\"\(date)\"\n"
        }
        
        // Add history data
        for history in exportData.history {
            let date = history.timestamp.displayString
            csvContent += "History,\(history.scholarId),,\(history.citationCount),\"\(date)\"\n"
        }
        
        guard let data = csvContent.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        return data
    }
    
    private func parseCSVData(_ data: Data) throws -> ExportData {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidFormat
        }
        
        let lines = csvString.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            throw ImportError.noData
        }
        
        var scholars: [Scholar] = []
        var history: [CitationHistory] = []
        
        // Skip header line
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            
            let components = parseCSVLine(line)
            guard components.count >= 5 else { continue }
            
            let type = components[0]
            let scholarId = components[1]
            
            if type == "Scholar" {
                let name = components[2]
                let citations = Int(components[3])
                
                var scholar = Scholar(id: scholarId, name: name)
                scholar.citations = citations
                scholars.append(scholar)
                
            } else if type == "History" {
                let citationCount = Int(components[3]) ?? 0
                let dateString = components[4]
                
                if let date = DateFormatter.export.date(from: dateString) {
                    let historyEntry = CitationHistory(
                        scholarId: scholarId,
                        citationCount: citationCount,
                        timestamp: date
                    )
                    history.append(historyEntry)
                }
            }
        }
        
        return ExportData(scholars: scholars, history: history)
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var components: [String] = []
        var currentComponent = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                components.append(currentComponent)
                currentComponent = ""
            } else {
                currentComponent.append(char)
            }
        }
        
        components.append(currentComponent)
        return components
    }
    
    private func generateFileName(format: ExportFormat, prefix: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        return "\(prefix)_\(timestamp).\(format.fileExtension)"
    }
    
    @MainActor
    private func updateProgress(_ progress: Double) {
        exportProgress = progress
    }
}

// MARK: - Supporting Types

public struct ExportResult {
    public let data: Data
    public let fileName: String
    public let format: ExportFormat
    public let scholars: [Scholar]
    public let historyEntries: Int
    public let exportDate: Date
    
    public var fileSize: Int {
        return data.count
    }
}

public struct ImportResult {
    public let importedScholars: Int
    public let importedHistory: Int
    public let skippedScholars: Int
    public let importDate: Date
}

public enum ImportMergeStrategy {
    case merge          // Add new, keep existing
    case overwrite      // Replace existing
    case skipExisting   // Only add new
}

public enum ExportError: Error, LocalizedError {
    case exportInProgress
    case noData
    case encodingFailed
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .exportInProgress:
            return "导出正在进行中"
        case .noData:
            return "没有数据可导出"
        case .encodingFailed:
            return "数据编码失败"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

public enum ImportError: Error, LocalizedError {
    case invalidFormat
    case noData
    case decodingFailed
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "无效的文件格式"
        case .noData:
            return "文件中没有数据"
        case .decodingFailed:
            return "数据解析失败"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}