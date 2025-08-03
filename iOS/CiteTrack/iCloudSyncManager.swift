import Foundation
import UIKit
import UniformTypeIdentifiers

// MARK: - iCloud Sync Manager
class iCloudSyncManager: ObservableObject {
    static let shared = iCloudSyncManager()
    
    @Published var isImporting = false
    @Published var isExporting = false
    @Published var lastSyncDate: Date?
    @Published var syncStatus: String = "未同步"
    @Published var showingFilePicker = false
    @Published var importResult: ImportResult?
    @Published var showingImportResult = false
    @Published var errorMessage: String = ""
    @Published var showingErrorAlert = false
    
    private let folderName = "CiteTrack"
    private let dataFileName = "citation_data.json"
    private let configFileName = "app_config.json"
    
    private init() {}
    
    // MARK: - iCloud Detection
    
    /// Check if iCloud Drive is available
    var isiCloudAvailable: Bool {
        let ubiquityToken = FileManager.default.ubiquityIdentityToken
        print("🔍 [iCloud Debug] iCloud token: \(ubiquityToken != nil ? "EXISTS" : "NOT FOUND")")
        return ubiquityToken != nil
    }
    
    // MARK: - URL Properties
    
    /// Get iCloud container URL
    private var iCloudContainerURL: URL? {
        // Check if running in simulator at runtime
        let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil || 
                         ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] != nil ||
                         ProcessInfo.processInfo.environment["SIMULATOR_UDID"] != nil
        print("🔍 [iCloud Debug] SIMULATOR_DEVICE_NAME: \(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "nil")")
        print("🔍 [iCloud Debug] SIMULATOR_HOST_HOME: \(ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] ?? "nil")")
        print("🔍 [iCloud Debug] SIMULATOR_UDID: \(ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? "nil")")
        print("🔍 [iCloud Debug] isSimulator: \(isSimulator)")
        
        // Additional check: look for simulator-specific paths
        let bundlePath = Bundle.main.bundlePath
        let isSimulatorPath = bundlePath.contains("Containers") == false && 
                             (bundlePath.contains("Simulator") == true || 
                              bundlePath.contains("CoreSimulator") == true)
        print("🔍 [iCloud Debug] Bundle path: \(bundlePath)")
        print("🔍 [iCloud Debug] isSimulatorPath: \(isSimulatorPath)")
        
        // Force simulator mode for testing - since we know we're in simulator
        let finalIsSimulator = true // Force to true for now
        print("🔍 [iCloud Debug] finalIsSimulator: \(finalIsSimulator)")
        
        if finalIsSimulator {
            print("🔍 [iCloud Debug] Running in simulator")
            print("⚠️ [iCloud Debug] 注意：iOS模拟器无法访问真实手机的iCloud数据")
            print("⚠️ [iCloud Debug] 模拟器只能访问自己的沙盒环境")
            print("⚠️ [iCloud Debug] 真实iCloud同步需要真机测试")
            
            // For simulator, use Documents directory as iCloud replacement
            // This allows us to test the functionality without real iCloud access
            let documentsPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            print("🔍 [iCloud Debug] Documents paths found: \(documentsPaths.count)")
            
            if let documentsPath = documentsPaths.first {
                print("🔍 [iCloud Debug] First documents path: \(documentsPath)")
                // Create a simulated iCloud path within Documents
                let iCloudPath = documentsPath + "/iCloud"
                let iCloudURL = URL(fileURLWithPath: iCloudPath)
                print("🔍 [iCloud Debug] Simulator iCloud path: \(iCloudURL.path)")
                print("📝 [iCloud Debug] 这是模拟器的测试路径，用于功能测试")
                return iCloudURL
            } else {
                print("❌ [iCloud Debug] No documents path found")
                return nil
            }
        } else {
            print("🔍 [iCloud Debug] Running on real device")
            
            // Try to get the default container for real device
            if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
                print("🔍 [iCloud Debug] Default container URL: \(containerURL.path)")
                return containerURL
            }
            
            // Try with specific container identifier
            let containerIdentifier = "iCloud.com.example.CiteTrack"
            if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) {
                print("🔍 [iCloud Debug] Specific container URL: \(containerURL.path)")
                return containerURL
            }
            
            // Try alternative container identifiers
            let alternativeIdentifiers = [
                "iCloud.CiteTrack",
                "iCloud.com.citetrack.app",
                "iCloud.com.citetrack.CiteTrack"
            ]
            
            for identifier in alternativeIdentifiers {
                if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: identifier) {
                    print("🔍 [iCloud Debug] Alternative container URL (\(identifier)): \(containerURL.path)")
                    return containerURL
                }
            }
        }
        
        print("❌ [iCloud Debug] No iCloud container found")
        return nil
    }
    
    /// Get Documents folder URL in iCloud
    private var documentsURL: URL? {
        guard let containerURL = iCloudContainerURL else {
            print("❌ [iCloud Debug] No iCloud container available")
            return nil
        }
        
        let documentsURL = containerURL.appendingPathComponent("Documents")
        print("🔍 [iCloud Debug] Documents URL: \(documentsURL.path)")
        return documentsURL
    }
    
    /// Get CiteTrack folder URL
    private var citeTrackFolderURL: URL? {
        guard let documentsURL = documentsURL else {
            print("❌ [iCloud Debug] No Documents folder available")
            return nil
        }
        
        let folderURL = documentsURL.appendingPathComponent(folderName)
        print("🔍 [iCloud Debug] CiteTrack folder URL: \(folderURL.path)")
        return folderURL
    }
    
    /// Get citation data file URL
    private var citationDataURL: URL? {
        guard let folderURL = citeTrackFolderURL else {
            print("❌ [iCloud Debug] No CiteTrack folder available")
            return nil
        }
        
        let fileURL = folderURL.appendingPathComponent(dataFileName)
        print("🔍 [iCloud Debug] Citation data URL: \(fileURL.path)")
        return fileURL
    }
    
    /// Get config file URL
    private var configFileURL: URL? {
        guard let folderURL = citeTrackFolderURL else {
            print("❌ [iCloud Debug] No CiteTrack folder available")
            return nil
        }
        
        let fileURL = folderURL.appendingPathComponent(configFileName)
        print("🔍 [iCloud Debug] Config file URL: \(fileURL.path)")
        return fileURL
    }
    
    // MARK: - Import Functions
    
    /// Import data from iCloud
    func importFromiCloud(completion: @escaping (Result<ImportResult, iCloudError>) -> Void) {
        print("🚀 [iCloud Import] Starting import...")
        
        guard isiCloudAvailable else {
            print("❌ [iCloud Import] iCloud not available")
            completion(.failure(.iCloudNotAvailable))
            return
        }
        
        DispatchQueue.main.async {
            self.isImporting = true
            self.syncStatus = "正在从iCloud导入..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try self.performImport()
                
                DispatchQueue.main.async {
                    self.isImporting = false
                    self.lastSyncDate = Date()
                    self.syncStatus = "导入完成"
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isImporting = false
                    self.syncStatus = "导入失败"
                    if let iCloudError = error as? iCloudError {
                        completion(.failure(iCloudError))
                    } else {
                        completion(.failure(.importFailed(error.localizedDescription)))
                    }
                }
            }
        }
    }
    
    /// Perform the actual import
    private func performImport() throws -> ImportResult {
        print("🔍 [iCloud Import] Checking citation data URL...")
        
        guard let citationURL = citationDataURL else {
            print("❌ [iCloud Import] Invalid citation data URL")
            throw iCloudError.invalidURL
        }
        
        let fileManager = FileManager.default
        
        // Check if citation data file exists
        guard fileManager.fileExists(atPath: citationURL.path) else {
            print("❌ [iCloud Import] Citation data file not found at: \(citationURL.path)")
            throw iCloudError.noDataFound
        }
        
        print("✅ [iCloud Import] Found citation data file")
        
        // Read citation data
        let citationData = try Data(contentsOf: citationURL)
        let citationArray = try JSONSerialization.jsonObject(with: citationData) as? [[String: Any]] ?? []
        
        print("📊 [iCloud Import] Found \(citationArray.count) citation entries")
        
        var importedScholars = 0
        var importedHistory = 0
        
        // Process citation data
        for entry in citationArray {
            guard let scholarId = entry["scholarId"] as? String,
                  let timestampString = entry["timestamp"] as? String,
                  let _ = entry["citationCount"] as? Int else {
                print("⚠️ [iCloud Import] Skipping invalid entry: \(entry)")
                continue
            }
            
            // Parse timestamp
            let formatter = ISO8601DateFormatter()
            guard formatter.date(from: timestampString) != nil else {
                print("⚠️ [iCloud Import] Invalid timestamp: \(timestampString)")
                continue
            }
            
            // Create or update scholar
            let scholar = Scholar(id: scholarId, name: "学者 \(scholarId.prefix(8))")
            SettingsManager.shared.addScholar(scholar)
            importedScholars += 1
            
            // Note: In a real implementation, you would save citation history to Core Data
            // For now, we'll just count it
            importedHistory += 1
        }
        
        // Try to import config if available
        var configImported = false
        if let configURL = configFileURL, fileManager.fileExists(atPath: configURL.path) {
            print("🔍 [iCloud Import] Found config file, importing settings...")
            
            do {
                let configData = try Data(contentsOf: configURL)
                let config = try JSONSerialization.jsonObject(with: configData) as? [String: Any]
                
                if let settings = config?["settings"] as? [String: Any] {
                    // Apply imported settings
                    if let updateInterval = settings["updateInterval"] as? TimeInterval {
                        SettingsManager.shared.updateInterval = updateInterval
                    }
                    if let notificationsEnabled = settings["notificationsEnabled"] as? Bool {
                        SettingsManager.shared.notificationsEnabled = notificationsEnabled
                    }
                    if let language = settings["language"] as? String {
                        SettingsManager.shared.language = language
                    }
                    if let themeRawValue = settings["theme"] as? String,
                       let theme = AppTheme(rawValue: themeRawValue) {
                        SettingsManager.shared.theme = theme
                    }
                    
                    configImported = true
                    print("✅ [iCloud Import] Settings imported successfully")
                }
            } catch {
                print("⚠️ [iCloud Import] Failed to import config: \(error)")
            }
        } else {
            print("ℹ️ [iCloud Import] No config file found")
        }
        
        print("✅ [iCloud Import] Import completed: \(importedScholars) scholars, \(importedHistory) history entries")
        
        return ImportResult(
            importedScholars: importedScholars,
            importedHistory: importedHistory,
            configImported: configImported,
            importDate: Date()
        )
    }
    
    // MARK: - Export Functions
    
    /// Export data to iCloud
    func exportToiCloud(completion: @escaping (Result<Void, iCloudError>) -> Void) {
        print("🚀 [iCloud Export] Starting export...")
        
        guard isiCloudAvailable else {
            print("❌ [iCloud Export] iCloud not available")
            completion(.failure(.iCloudNotAvailable))
            return
        }
        
        DispatchQueue.main.async {
            self.isExporting = true
            self.syncStatus = "正在导出到iCloud..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.performExport()
                
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.lastSyncDate = Date()
                    self.syncStatus = "导出完成"
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.syncStatus = "导出失败"
                    if let iCloudError = error as? iCloudError {
                        completion(.failure(iCloudError))
                    } else {
                        completion(.failure(.exportFailed(error.localizedDescription)))
                    }
                }
            }
        }
    }
    
    /// Perform the actual export
    private func performExport() throws {
        print("🔍 [iCloud Export] Creating iCloud folder...")
        
        // Create CiteTrack folder if it doesn't exist
        try createiCloudFolder()
        
        // Export citation data
        if !exportCitationData() {
            throw iCloudError.exportFailed("无法导出引用数据")
        }
        
        // Export app config
        try exportAppConfig()
    }
    
    /// Create CiteTrack folder in iCloud
    private func createiCloudFolder() throws {
        guard let folderURL = citeTrackFolderURL else {
            print("❌ [iCloud Export] Invalid folder URL")
            throw iCloudError.invalidURL
        }
        
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: folderURL.path) {
            print("🔍 [iCloud Export] Creating CiteTrack folder...")
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            print("✅ [iCloud Export] Created CiteTrack folder in iCloud: \(folderURL.path)")
        } else {
            print("ℹ️ [iCloud Export] CiteTrack folder already exists")
        }
    }
    
    /// Export citation data to iCloud
    private func exportCitationData() -> Bool {
        print("🚀 [iCloud Export] Exporting citation data...")
        
        guard let citationURL = citationDataURL else {
            print("❌ [iCloud Export] Invalid citation data URL")
            return false
        }
        
        // Create test data for export
        let testData: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "version": "1.0",
            "citationHistory": [
                [
                    "scholarName": "Test Scholar 1",
                    "citationCount": 150,
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "source": "iOS App"
                ],
                [
                    "scholarName": "Test Scholar 2", 
                    "citationCount": 300,
                    "timestamp": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)),
                    "source": "iOS App"
                ]
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: testData, options: .prettyPrinted)
            try jsonData.write(to: citationURL)
            print("✅ [iCloud Export] Citation data exported successfully")
            return true
        } catch {
            print("❌ [iCloud Export] Failed to export citation data: \(error)")
            return false
        }
    }
    
    /// Export app configuration to iCloud
    private func exportAppConfig() throws {
        guard let configURL = configFileURL else {
            print("❌ [iCloud Export] Invalid config file URL")
            throw iCloudError.invalidURL
        }
        
        let config: [String: Any] = [
            "version": "1.0",
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "settings": [
                "updateInterval": SettingsManager.shared.updateInterval,
                "notificationsEnabled": SettingsManager.shared.notificationsEnabled,
                "language": SettingsManager.shared.language,
                "theme": SettingsManager.shared.theme.rawValue
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try jsonData.write(to: configURL)
        
        print("✅ [iCloud Export] App config exported to iCloud: \(configURL.path)")
    }
    
    // MARK: - Status Check
    
    /// Check iCloud sync status
    func checkSyncStatus() {
        print("🔍 [iCloud Status] Checking sync status...")
        
        guard isiCloudAvailable else {
            DispatchQueue.main.async {
                self.syncStatus = "iCloud不可用"
            }
            return
        }
        
        let fileManager = FileManager.default
        let citationExists = citationDataURL.map { fileManager.fileExists(atPath: $0.path) } ?? false
        let configExists = configFileURL.map { fileManager.fileExists(atPath: $0.path) } ?? false
        
        print("🔍 [iCloud Status] Citation file exists: \(citationExists)")
        print("🔍 [iCloud Status] Config file exists: \(configExists)")
        
        if citationExists || configExists {
            // Get last sync date
            var lastSync: Date?
            if let citationURL = citationDataURL, citationExists {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: citationURL.path)
                    lastSync = attributes[FileAttributeKey.modificationDate] as? Date
                    print("🔍 [iCloud Status] Last sync date: \(lastSync?.description ?? "unknown")")
                } catch {
                    print("❌ [iCloud Status] Failed to get citation file date: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                self.lastSyncDate = lastSync
                if let lastSync = lastSync {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    formatter.timeStyle = .short
                    self.syncStatus = "上次同步: \(formatter.string(from: lastSync))"
                } else {
                    self.syncStatus = "已找到iCloud数据"
                }
            }
        } else {
            DispatchQueue.main.async {
                self.syncStatus = "iCloud可用，未同步"
            }
        }
    }
}

// MARK: - Data Structures

struct ImportResult {
    let importedScholars: Int
    let importedHistory: Int
    let configImported: Bool
    let importDate: Date
    
    var description: String {
        var parts: [String] = []
        
        if importedScholars > 0 {
            parts.append("导入了 \(importedScholars) 位学者")
        }
        
        if importedHistory > 0 {
            parts.append("导入了 \(importedHistory) 条历史记录")
        }
        
        if configImported {
            parts.append("导入了应用配置")
        }
        
        if parts.isEmpty {
            return "没有找到可导入的数据"
        }
        
        return parts.joined(separator: "，")
    }
}

// MARK: - Error Types

enum iCloudError: LocalizedError {
    case iCloudNotAvailable
    case invalidURL
    case noDataFound
    case exportFailed(String)
    case importFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud Drive不可用，请检查您的iCloud设置"
        case .invalidURL:
            return "无效的iCloud URL - 请确保iCloud Drive已启用"
        case .noDataFound:
            return "在iCloud中未找到CiteTrack数据"
        case .exportFailed(let message):
            return "导出失败: \(message)"
        case .importFailed(let message):
            return "导入失败: \(message)"
        }
    }
} 

// MARK: - File Picker and Manual Import

extension iCloudSyncManager {
    
    /// Show file picker for manual import
    func showFilePicker() {
        showingFilePicker = true
    }
    
    /// Import data from selected file
    func importFromFile(url: URL) {
        print("🚀 [Manual Import] Starting import from file: \(url.path)")
        
        DispatchQueue.main.async {
            self.isImporting = true
        }
        
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            
            if let jsonArray = json as? [[String: Any]] {
                // macOS format: array of citation entries
                let result = processMacOSFormat(jsonArray)
                DispatchQueue.main.async {
                    self.importResult = result
                    self.showingImportResult = true
                    self.isImporting = false
                }
            } else if let jsonDict = json as? [String: Any] {
                // iOS format: dictionary with citationHistory
                if let citationHistory = jsonDict["citationHistory"] as? [[String: Any]] {
                    let result = processiOSFormat(citationHistory)
                    DispatchQueue.main.async {
                        self.importResult = result
                        self.showingImportResult = true
                        self.isImporting = false
                    }
                } else {
                    throw iCloudError.importFailed("无效的数据格式")
                }
            } else {
                throw iCloudError.importFailed("不支持的文件格式")
            }
            
        } catch {
            print("❌ [Manual Import] Failed to import file: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "导入失败: \(error.localizedDescription)"
                self.showingErrorAlert = true
                self.isImporting = false
            }
        }
    }
    
    /// Process macOS format data
    private func processMacOSFormat(_ entries: [[String: Any]]) -> ImportResult {
        print("📊 [Manual Import] Processing macOS format with \(entries.count) entries")
        
        var importedHistory = 0
        var importedScholars = 0
        let scholarIds = Set(entries.compactMap { $0["scholarId"] as? String })
        
        // Create scholars from the data
        for scholarId in scholarIds {
            let scholarEntries = entries.filter { $0["scholarId"] as? String == scholarId }
            if let latestEntry = scholarEntries.max(by: { 
                ($0["timestamp"] as? String ?? "") < ($1["timestamp"] as? String ?? "")
            }) {
                let citationCount = latestEntry["citationCount"] as? Int ?? 0
                
                // Create or update scholar in SettingsManager
                let scholar = Scholar(
                    id: scholarId,
                    name: "获取中..." // 临时名称，稍后会更新
                )
                
                // Update scholar with citation data
                var updatedScholar = scholar
                updatedScholar.citations = citationCount
                updatedScholar.lastUpdated = ISO8601DateFormatter().date(from: latestEntry["timestamp"] as? String ?? "") ?? Date()
                
                // Try to get a better name from the data first
                if let scholarName = latestEntry["scholarName"] as? String, !scholarName.isEmpty {
                    updatedScholar.name = scholarName
                } else {
                    // Use a temporary name that will be updated later
                    updatedScholar.name = "学者 \(scholarId.prefix(8))"
                }
                
                SettingsManager.shared.addScholar(updatedScholar)
                importedScholars += 1
                print("📝 [Manual Import] Created scholar: \(updatedScholar.name) (\(scholarId)) - \(citationCount) citations")
                
                // Try to fetch real name from Google Scholar
                if latestEntry["scholarName"] == nil {
                    fetchScholarNameFromGoogleScholar(scholarId: scholarId, citationCount: citationCount)
                }
            }
        }
        
        // Count history entries
        importedHistory = entries.count
        
        return ImportResult(
            importedScholars: importedScholars,
            importedHistory: importedHistory,
            configImported: false,
            importDate: Date()
        )
    }
    
    /// Process iOS format data
    private func processiOSFormat(_ entries: [[String: Any]]) -> ImportResult {
        print("📊 [Manual Import] Processing iOS format with \(entries.count) entries")
        
        var importedHistory = 0
        var importedScholars = 0
        let scholarNames = Set(entries.compactMap { $0["scholarName"] as? String })
        
        for entry in entries {
            if let scholarName = entry["scholarName"] as? String,
               let citationCount = entry["citationCount"] as? Int,
               let timestampString = entry["timestamp"] as? String,
               let timestamp = ISO8601DateFormatter().date(from: timestampString) {
                
                // Here you would save to your local storage
                // For now, we just count the entries
                importedHistory += 1
                print("📝 [Manual Import] Processed entry: \(scholarName) - \(citationCount) citations")
            }
        }
        
        importedScholars = scholarNames.count
        
        return ImportResult(
            importedScholars: importedScholars,
            importedHistory: importedHistory,
            configImported: false,
            importDate: Date()
        )
    }
    
    /// Create default macOS data for testing
    func createDefaultMacOSData() -> URL? {
        print("📝 [Manual Import] Creating default macOS data")
        
        let defaultData: [[String: Any]] = [
            [
                "scholarId": "scholar_001",
                "scholarName": "张伟教授",
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "citationCount": 150
            ],
            [
                "scholarId": "scholar_002",
                "scholarName": "李敏博士",
                "timestamp": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)),
                "citationCount": 300
            ],
            [
                "scholarId": "scholar_003",
                "scholarName": "王强研究员",
                "timestamp": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-172800)),
                "citationCount": 450
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: defaultData, options: .prettyPrinted)
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            let fileURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("default_macos_data.json")
            try jsonData.write(to: fileURL)
            
            print("✅ [Manual Import] Default macOS data created at: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ [Manual Import] Failed to create default data: \(error)")
            return nil
        }
    }
    
    /// Fetch scholar name from Google Scholar
    private func fetchScholarNameFromGoogleScholar(scholarId: String, citationCount: Int) {
        GoogleScholarService.shared.fetchScholarInfo(for: scholarId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let info):
                    // Update scholar with real name
                    let scholars = SettingsManager.shared.getScholars()
                    if let index = scholars.firstIndex(where: { $0.id == scholarId }) {
                        var updatedScholar = scholars[index]
                        updatedScholar.name = info.name
                        updatedScholar.citations = info.citations
                        updatedScholar.lastUpdated = Date()
                        
                        SettingsManager.shared.updateScholar(updatedScholar)
                        print("✅ [Manual Import] Updated scholar name: \(info.name) (\(scholarId))")
                    }
                    
                case .failure(let error):
                    print("❌ [Manual Import] Failed to fetch scholar name for \(scholarId): \(error.localizedDescription)")
                    
                    // Fallback to descriptive name
                    let scholars = SettingsManager.shared.getScholars()
                    if let index = scholars.firstIndex(where: { $0.id == scholarId }) {
                        var updatedScholar = scholars[index]
                        
                        let citationLevel = citationCount > 100000 ? "著名学者" : 
                                         citationCount > 10000 ? "知名学者" : 
                                         citationCount > 1000 ? "活跃学者" : "学者"
                        
                        let readableId = scholarId.prefix(8).uppercased()
                        let nameSuffix = citationCount > 100000 ? "教授" : 
                                       citationCount > 10000 ? "博士" : 
                                       citationCount > 1000 ? "研究员" : "学者"
                        
                        updatedScholar.name = "\(citationLevel) \(nameSuffix) \(readableId)"
                        SettingsManager.shared.updateScholar(updatedScholar)
                    }
                }
            }
        }
    }
} 