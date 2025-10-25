import Foundation
import Cocoa

// MARK: - iCloud Sync Manager
class iCloudSyncManager {
    static let shared = iCloudSyncManager()
    
    private let iCloudContainerIdentifier: String? = "iCloud.com.citetrack.CiteTrack" // Use explicit shared container
    private let folderName = "CiteTrack"
    private let dataFileName = "citation_data.json"
    private let configFileName = "ios_data.json"
    
    // Auto sync properties
    private var syncTimer: Timer?
    private var isAutoSyncEnabled: Bool = false
    private let syncQueue = DispatchQueue(label: "com.citetrack.icloud.sync", qos: .utility)
    private let syncInterval: TimeInterval = 300 // 5 minutes
    
    private init() {}

    // MARK: - CloudKit Long-term Sync
    // Note: CloudKitSyncService is not implemented in this version
    // Using iCloud Drive file-based sync instead
    func exportUsingCloudKit(completion: @escaping (Result<Void, Error>) -> Void) {
        // Fallback to file-based export
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 使用新的DataManager导出为iOS兼容格式
                let jsonData = try DataManager.shared.exportToiOSFormat()
                try self.exportCitationData(jsonData: jsonData)
                try self.exportAppConfig()
                DispatchQueue.main.async(qos: .userInitiated) {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async(qos: .userInitiated) {
                    completion(.failure(error))
                }
            }
        }
    }

    func importUsingCloudKit(completion: @escaping (Result<Void, Error>) -> Void) {
        // Fallback to file-based import - not fully implemented yet
        completion(.failure(NSError(domain: "iCloudSyncManager", code: -1, 
            userInfo: [NSLocalizedDescriptionKey: "CloudKit import not available, please use iCloud Drive sync"])))
    }
    
    // MARK: - iCloud Detection
    
    /// Check if iCloud Drive is available
    var isiCloudAvailable: Bool {
        print("🔍 [iCloud Debug] Checking iCloud availability...")
        
        // First check if user is logged in to iCloud
        let ubiquityToken = FileManager.default.ubiquityIdentityToken
        print("🔍 [iCloud Debug] iCloud account token: \(ubiquityToken != nil ? "EXISTS" : "NOT FOUND")")
        
        guard ubiquityToken != nil else {
            print("❌ [iCloud Debug] User is not logged into iCloud")
            return false
        }
        
        // Try to get the default container
        if let defaultContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            print("🔍 [iCloud Debug] Default container: \(defaultContainer)")
            print("🔍 [iCloud Debug] Container path exists: \(FileManager.default.fileExists(atPath: defaultContainer.path))")
            
            // Test if we can actually access this directory
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: defaultContainer.path)
                print("✅ [iCloud Debug] Successfully accessed default iCloud container directory")
                print("🔍 [iCloud Debug] Container contents count: \(contents.count)")
                print("🔍 [iCloud Debug] Container contents: \(contents.prefix(5))")
                return true
            } catch {
                print("❌ [iCloud Debug] Cannot access default container: \(error.localizedDescription)")
                
                // Try to create the directory if it doesn't exist
                do {
                    try FileManager.default.createDirectory(at: defaultContainer, withIntermediateDirectories: true, attributes: nil)
                    print("✅ [iCloud Debug] Created iCloud container directory")
                    return true
                } catch {
                    print("❌ [iCloud Debug] Cannot create iCloud container: \(error.localizedDescription)")
                    return false
                }
            }
        } else {
            print("❌ [iCloud Debug] Default container is nil")
            
            // Try alternative method - check for iCloud Drive folder directly
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            let iCloudDriveURL = homeURL.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
            
            print("🔍 [iCloud Debug] Trying alternative path: \(iCloudDriveURL.path)")
            
            if FileManager.default.fileExists(atPath: iCloudDriveURL.path) {
                print("✅ [iCloud Debug] Found iCloud Drive folder directly")
                
                // Test if we can access it
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: iCloudDriveURL.path)
                    print("✅ [iCloud Debug] iCloud Drive accessible, contents count: \(contents.count)")
                    return true
                } catch {
                    print("❌ [iCloud Debug] Cannot access iCloud Drive: \(error.localizedDescription)")
                    return false
                }
            } else {
                print("❌ [iCloud Debug] iCloud Drive folder not found")
                return false
            }
        }
    }
    
    // MARK: - URL Properties
    
    /// Get iCloud container URL
    private var iCloudContainerURL: URL? {
        // Try default container first
        if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerIdentifier) {
            return containerURL
        }
        
        // Fallback: use iCloud Drive directly
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let iCloudDriveURL = homeURL.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        
        if FileManager.default.fileExists(atPath: iCloudDriveURL.path) {
            return iCloudDriveURL
        }
        
        return nil
    }
    
    /// Get Documents folder URL in iCloud
    private var documentsURL: URL? {
        return iCloudContainerURL?.appendingPathComponent("Documents")
    }
    
    /// Get CiteTrack folder URL（与 iOS 对齐：直接使用容器 Documents 根目录）
    private var citeTrackFolderURL: URL? {
        return documentsURL
    }
    
    /// Get citation data file URL
    private var citationDataURL: URL? {
        return citeTrackFolderURL?.appendingPathComponent(dataFileName)
    }
    
    /// Get config file URL
    private var configFileURL: URL? {
        return citeTrackFolderURL?.appendingPathComponent(configFileName)
    }
    
    // MARK: - Folder Management
    
    /// Create CiteTrack folder in iCloud if it doesn't exist
    func createiCloudFolder() throws {
        guard isiCloudAvailable else {
            throw iCloudError.iCloudNotAvailable
        }
        
        guard let folderURL = citeTrackFolderURL else {
            throw iCloudError.invalidURL
        }
        
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: folderURL.path) {
            do {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                print("✅ Created CiteTrack folder in iCloud: \(folderURL.path)")
            } catch {
                print("❌ Failed to create CiteTrack folder: \(error.localizedDescription)")
                throw iCloudError.folderCreationFailed
            }
        } else {
            print("ℹ️ CiteTrack folder already exists in iCloud")
        }
    }
    
    // MARK: - Export Functions
    
    /// Export citation data to iCloud (新方法 - 兼容iOS格式)
    private func exportCitationData(jsonData: Data) throws {
        guard let citationURL = citationDataURL else {
            throw iCloudError.invalidURL
        }
        try jsonData.write(to: citationURL)
        print("✅ Citation data exported to iCloud: \(citationURL.path)")
    }
    
    /// Export citation data to iCloud (向后兼容的方法)
    func exportCitationData() throws {
        let jsonData = try DataManager.shared.exportToiOSFormat()
        try exportCitationData(jsonData: jsonData)
    }
    
    /// Export app configuration to iCloud
    func exportAppConfig() throws {
        guard let configURL = configFileURL else {
            throw iCloudError.invalidURL
        }
        let jsonData = try JSONSerialization.data(withJSONObject: makeCurrentAppData(), options: .prettyPrinted)
        try jsonData.write(to: configURL)
        
        print("✅ App config exported to iCloud: \(configURL.path)")
    }
    
    // MARK: - Auto Sync Management
    
    /// Enable automatic iCloud synchronization
    func enableAutoSync() {
        print("🔄 [iCloud Sync] Enabling automatic sync...")
        isAutoSyncEnabled = true
        
        DispatchQueue.main.async(qos: .userInitiated) { [weak self] in
            self?.startSyncTimer()
        }
        
        // Perform initial sync
        performInitialSync()
    }
    
    /// Disable automatic iCloud synchronization
    func disableAutoSync() {
        print("⏹️ [iCloud Sync] Disabling automatic sync...")
        isAutoSyncEnabled = false
        
        DispatchQueue.main.async(qos: .userInitiated) { [weak self] in
            self?.stopSyncTimer()
        }
    }
    
    /// Start the periodic sync timer
    private func startSyncTimer() {
        stopSyncTimer() // Stop any existing timer
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            self?.performPeriodicSync()
        }
        
        print("⏰ [iCloud Sync] Started sync timer with interval: \(syncInterval) seconds")
    }
    
    /// Stop the periodic sync timer
    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
        print("⏰ [iCloud Sync] Stopped sync timer")
    }
    
    /// Perform initial sync when enabled
    func performInitialSync() {
        guard isAutoSyncEnabled else {
            print("⚠️ [iCloud Sync] Initial sync requested but auto sync is disabled")
            return
        }
        
        print("🚀 [iCloud Sync] Performing initial sync...")
        
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 使用 CloudKit 保存一次长期同步快照；失败不影响后续本地导出
            self.exportUsingCloudKit { result in
                switch result {
                case .success: print("✅ [CloudKit] Initial save success")
                case .failure(let error): print("⚠️ [CloudKit] Initial save failed: \(error.localizedDescription)")
                }
            }
            do {
                // 兼容保留：仍写 iCloud Drive 文件
                try self.createiCloudFolder()
                try self.exportCitationData()
                try self.exportAppConfig()
                print("✅ [iCloud Sync] Initial sync completed successfully")
            } catch {
                print("❌ [iCloud Sync] Initial sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Perform periodic sync
    private func performPeriodicSync() {
        guard isAutoSyncEnabled else { return }
        
        print("🔄 [iCloud Sync] Performing periodic sync...")
        
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            // CloudKit 长期同步
            self.exportUsingCloudKit { result in
                switch result {
                case .success: print("✅ [CloudKit] Periodic save success")
                case .failure(let error): print("⚠️ [CloudKit] Periodic save failed: \(error.localizedDescription)")
                }
            }
            // 兼容保留：仍写 iCloud Drive 文件
            do {
                try self.exportCitationData()
                try self.exportAppConfig()
                print("✅ [iCloud Sync] Periodic sync completed")
            } catch {
                print("❌ [iCloud Sync] Periodic sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Get current auto sync status
    var autoSyncEnabled: Bool {
        return isAutoSyncEnabled
    }
    
    // MARK: - File Status
    
    /// Get file status for display
    func getFileStatus() -> iCloudFileStatus {
        guard isiCloudAvailable else {
            return iCloudFileStatus(
                iCloudAvailable: false, 
                folderExists: false, 
                citationDataExists: false, 
                configExists: false,
                lastSyncDate: nil,
                isSyncEnabled: PreferencesManager.shared.iCloudSyncEnabled
            )
        }
        
        let fileManager = FileManager.default
        
        let folderExists = citeTrackFolderURL.map { fileManager.fileExists(atPath: $0.path) } ?? false
        let citationExists = citationDataURL.map { fileManager.fileExists(atPath: $0.path) } ?? false
        let configExists = configFileURL.map { fileManager.fileExists(atPath: $0.path) } ?? false
        
        // Get last sync date from the most recent file
        var lastSyncDate: Date?
        if let citationURL = citationDataURL, citationExists {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: citationURL.path)
                lastSyncDate = attributes[FileAttributeKey.modificationDate] as? Date
            } catch {
                print("❌ [iCloud] Failed to get citation file date: \(error)")
            }
        } else if let configURL = configFileURL, configExists {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: configURL.path)
                lastSyncDate = attributes[FileAttributeKey.modificationDate] as? Date
            } catch {
                print("❌ [iCloud] Failed to get config file date: \(error)")
            }
        }
        
        return iCloudFileStatus(
            iCloudAvailable: true,
            folderExists: folderExists,
            citationDataExists: citationExists,
            configExists: configExists,
            lastSyncDate: lastSyncDate,
            isSyncEnabled: PreferencesManager.shared.iCloudSyncEnabled
        )
    }
    
    /// Open CiteTrack folder in Finder
    func openFolderInFinder() {
        print("🔍 [iCloud Debug] Attempting to open CiteTrack folder...")
        
        // First try the CiteTrack specific folder
        if let folderURL = citeTrackFolderURL {
            print("🔍 [iCloud Debug] CiteTrack folder URL: \(folderURL.path)")
            
            if FileManager.default.fileExists(atPath: folderURL.path) {
                print("✅ [iCloud Debug] CiteTrack folder exists, opening...")
                NSWorkspace.shared.open(folderURL)
                return
            } else {
                print("⚠️ [iCloud Debug] CiteTrack folder doesn't exist, trying to create it...")
                
                // Try to create the folder
                do {
                    try createiCloudFolder()
                    print("✅ [iCloud Debug] Created CiteTrack folder, opening...")
                    
                    // Add app icon to the folder
                    addAppIconToFolder(folderURL)
                    
                    NSWorkspace.shared.open(folderURL)
                    return
                } catch {
                    print("❌ [iCloud Debug] Failed to create CiteTrack folder: \(error.localizedDescription)")
                }
            }
        }
        
        // Fallback: open the Documents folder or iCloud Drive root
        if let documentsURL = documentsURL, FileManager.default.fileExists(atPath: documentsURL.path) {
            print("📁 [iCloud Debug] Opening iCloud Documents folder instead...")
            NSWorkspace.shared.open(documentsURL)
            return
        }
        
        // Last resort: open iCloud Drive root
        if let containerURL = iCloudContainerURL, FileManager.default.fileExists(atPath: containerURL.path) {
            print("📁 [iCloud Debug] Opening iCloud container root...")
            NSWorkspace.shared.open(containerURL)
            return
        }
        
        // Ultimate fallback: try to open iCloud Drive directly
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let iCloudDriveURL = homeURL.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        
        if FileManager.default.fileExists(atPath: iCloudDriveURL.path) {
            print("📁 [iCloud Debug] Opening main iCloud Drive folder...")
            NSWorkspace.shared.open(iCloudDriveURL)
        } else {
            print("❌ [iCloud Debug] Cannot find any iCloud folder to open")
            
            // Show an alert to the user
            DispatchQueue.main.async(qos: .userInitiated) {
                let alert = NSAlert()
                alert.messageText = "iCloud Drive Not Available"
                alert.informativeText = "Please ensure iCloud Drive is enabled in System Preferences and try again."
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
    
    // MARK: - Folder Icon Management
    
    /// Add app icon to the CiteTrack folder
    private func addAppIconToFolder(_ folderURL: URL) {
        print("🎨 [iCloud Debug] Adding app icon to CiteTrack folder...")
        
        // Multiple approaches to try for setting folder icon
        var iconSet = false
        
        // Approach 1: Try using app bundle icon
        let appBundle = Bundle.main.bundleURL
        let iconURL = appBundle.appendingPathComponent("Contents/Resources/app_icon.icns")
        
        if FileManager.default.fileExists(atPath: iconURL.path) {
            print("🔍 [iCloud Debug] Found app icon at: \(iconURL.path)")
            
            if let iconImage = NSImage(contentsOf: iconURL) {
                print("🔍 [iCloud Debug] Successfully loaded icon image")
                let result = NSWorkspace.shared.setIcon(iconImage, forFile: folderURL.path, options: [])
                if result {
                    print("✅ [iCloud Debug] Successfully added app icon to CiteTrack folder")
                    iconSet = true
                } else {
                    print("⚠️ [iCloud Debug] NSWorkspace.setIcon returned false")
                }
            } else {
                print("❌ [iCloud Debug] Failed to create NSImage from icon file")
            }
        } else {
            print("❌ [iCloud Debug] App icon not found at: \(iconURL.path)")
        }
        
        // Approach 2: Try using app icon by name
        if !iconSet {
            print("🔍 [iCloud Debug] Trying to get app icon by name...")
            if let appIcon = NSApp.applicationIconImage {
                print("🔍 [iCloud Debug] Got application icon image")
                let result = NSWorkspace.shared.setIcon(appIcon, forFile: folderURL.path, options: [])
                if result {
                    print("✅ [iCloud Debug] Successfully added app icon to CiteTrack folder (using NSApp.applicationIconImage)")
                    iconSet = true
                } else {
                    print("⚠️ [iCloud Debug] Failed to set folder icon using NSApp.applicationIconImage")
                }
            }
        }
        
        // Approach 3: Use default folder icon with custom badge (fallback)
        if !iconSet {
            print("🔍 [iCloud Debug] Using default folder icon as fallback...")
            let folderIcon = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
            let result = NSWorkspace.shared.setIcon(folderIcon, forFile: folderURL.path, options: [])
            if result {
                print("✅ [iCloud Debug] Set default folder icon")
            } else {
                print("❌ [iCloud Debug] Failed to set any folder icon")
            }
        }
        
        // Check permissions issue
        if !iconSet {
            print("⚠️ [iCloud Debug] Icon setting failed - may be due to sandboxing restrictions")
            print("🔍 [iCloud Debug] Folder path: \(folderURL.path)")
            print("🔍 [iCloud Debug] Folder exists: \(FileManager.default.fileExists(atPath: folderURL.path))")
        }
    }
}

    // MARK: - Unified Export/Import Helpers (align with iOS)

    /// 构建当前应用数据（与 iOS 的 makeCurrentAppData 保持兼容）
    private func makeCurrentAppData() -> [String: Any] {
        let settings = PreferencesManager.shared
        let dict: [String: Any] = [
            "version": "1.1",
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "settings": [
                "updateInterval": settings.updateInterval,
                "showInDock": settings.showInDock,
                "showInMenuBar": settings.showInMenuBar,
                "launchAtLogin": settings.launchAtLogin,
                "iCloudSyncEnabled": settings.iCloudSyncEnabled,
                "language": LocalizationManager.shared.currentLanguageCode
            ]
        ]
        return dict
    }

    /// 包装导出负载（学术数据）为统一应用数据 JSON
    private func makeAppDataJSON(exportPayload: Data) throws -> Data {
        var unified = makeCurrentAppData()
        if let arr = try? JSONSerialization.jsonObject(with: exportPayload) as? [[String: Any]] {
            unified["citationHistory"] = arr
        } else if let obj = try? JSONSerialization.jsonObject(with: exportPayload) as? [String: Any] {
            unified.merge(obj) { _, new in new }
        }
        return try JSONSerialization.data(withJSONObject: unified, options: .prettyPrinted)
    }

    /// 生成导出JSON数据（与 iOS 相同的条目结构）
    private func makeExportJSONData() throws -> Data {
        let formatter = ISO8601DateFormatter()
        let scholars = PreferencesManager.shared.scholars
        let scholarNameById: [String: String] = Dictionary(uniqueKeysWithValues: scholars.map { ($0.id, $0.name) })

        let semaphore = DispatchSemaphore(value: 0)
        var allHistory: [CitationHistory] = []
        CitationHistoryManager.shared.getAllHistory { result in
            if case .success(let items) = result { allHistory = items }
            semaphore.signal()
        }
        semaphore.wait()

        let historyByScholar: [String: [CitationHistory]] = Dictionary(grouping: allHistory, by: { $0.scholarId })
        var exportEntries: [[String: Any]] = []

        for (scholarId, histories) in historyByScholar {
            let scholarName = scholarNameById[scholarId] ?? "Scholar \(scholarId.prefix(8))"
            for h in histories.sorted(by: { $0.timestamp < $1.timestamp }) {
                exportEntries.append([
                    "scholarId": scholarId,
                    "scholarName": scholarName,
                    "timestamp": formatter.string(from: h.timestamp),
                    "citationCount": h.citationCount
                ])
            }
        }

        for s in scholars {
            if historyByScholar[s.id] == nil, let citations = s.citations {
                let ts = s.lastUpdated ?? Date()
                exportEntries.append([
                    "scholarId": s.id,
                    "scholarName": s.name,
                    "timestamp": formatter.string(from: ts),
                    "citationCount": citations
                ])
            }
        }

        return try JSONSerialization.data(withJSONObject: exportEntries, options: .prettyPrinted)
    }

    /// 统一导入：支持 settings + citationHistory
    private func importFromUnifiedData(_ data: Data) throws -> (importedScholars: Int, importedHistory: Int) {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = json as? [String: Any] else {
            if let _ = json as? [[String: Any]] { return try importFromArrayPayload(data) }
            throw iCloudError.importFailed("Invalid JSON structure")
        }

        if let settings = dict["settings"] as? [String: Any] {
            let pm = PreferencesManager.shared
            if let updateInterval = settings["updateInterval"] as? TimeInterval { pm.updateInterval = updateInterval }
            if let showInDock = settings["showInDock"] as? Bool { pm.showInDock = showInDock }
            if let showInMenuBar = settings["showInMenuBar"] as? Bool { pm.showInMenuBar = showInMenuBar }
            if let launchAtLogin = settings["launchAtLogin"] as? Bool { pm.launchAtLogin = launchAtLogin }
            if let iCloudSyncEnabled = settings["iCloudSyncEnabled"] as? Bool { pm.iCloudSyncEnabled = iCloudSyncEnabled }
            if let languageCode = settings["language"] as? String, let lang = LocalizationManager.Language(rawValue: languageCode) {
                LocalizationManager.shared.setLanguage(lang)
            }
        }

        var importedHistory = 0
        var importedScholars = 0

        if let citationHistory = dict["citationHistory"] as? [[String: Any]] {
            let pm = PreferencesManager.shared
            let existing = pm.scholars
            let existingIds = Set(existing.map { $0.id })

            let groupedByScholar = Dictionary(grouping: citationHistory) { $0["scholarId"] as? String ?? "" }
            for (scholarId, entries) in groupedByScholar {
                guard !scholarId.isEmpty else { continue }
                let name = (entries.last? ["scholarName"]) as? String ?? "Scholar \(scholarId.prefix(8))"
                if !existingIds.contains(scholarId) {
                    var s = Scholar(id: scholarId, name: name)
                    if let last = entries.last,
                       let count = last["citationCount"] as? Int,
                       let tsStr = last["timestamp"] as? String,
                       let ts = ISO8601DateFormatter().date(from: tsStr) {
                        s.citations = count
                        s.lastUpdated = ts
                    }
                    pm.addScholar(s)
                    importedScholars += 1
                }
            }

            let group = DispatchGroup()
            for entry in citationHistory {
                guard let scholarId = entry["scholarId"] as? String,
                      let count = entry["citationCount"] as? Int,
                      let tsString = entry["timestamp"] as? String,
                      let ts = ISO8601DateFormatter().date(from: tsString) else { continue }
                group.enter()
                let h = CitationHistory(scholarId: scholarId, citationCount: count, timestamp: ts)
                CitationHistoryManager.shared.saveHistoryEntry(h) { result in
                    if case .success = result { importedHistory += 1 }
                    group.leave()
                }
            }
            group.wait()
        }

        return (importedScholars, importedHistory)
    }

    /// 兼容仅数组负载（[[String:Any]]）的导入
    private func importFromArrayPayload(_ data: Data) throws -> (importedScholars: Int, importedHistory: Int) {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let array = json as? [[String: Any]] else { return (0, 0) }
        var importedHistory = 0
        var importedScholars = 0

        let pm = PreferencesManager.shared
        let existing = pm.scholars
        let existingIds = Set(existing.map { $0.id })

        let grouped = Dictionary(grouping: array) { $0["scholarId"] as? String ?? "" }
        for (scholarId, entries) in grouped {
            guard !scholarId.isEmpty else { continue }
            let name = (entries.last? ["scholarName"]) as? String ?? "Scholar \(scholarId.prefix(8))"
            if !existingIds.contains(scholarId) {
                var s = Scholar(id: scholarId, name: name)
                if let last = entries.last,
                   let count = last["citationCount"] as? Int,
                   let tsStr = last["timestamp"] as? String,
                   let ts = ISO8601DateFormatter().date(from: tsStr) {
                    s.citations = count
                    s.lastUpdated = ts
                }
                pm.addScholar(s)
                importedScholars += 1
            }
        }

        let group = DispatchGroup()
        for entry in array {
            guard let scholarId = entry["scholarId"] as? String,
                  let count = entry["citationCount"] as? Int,
                  let tsString = entry["timestamp"] as? String,
                  let ts = ISO8601DateFormatter().date(from: tsString) else { continue }
            group.enter()
            let h = CitationHistory(scholarId: scholarId, citationCount: count, timestamp: ts)
            CitationHistoryManager.shared.saveHistoryEntry(h) { result in
                if case .success = result { importedHistory += 1 }
                group.leave()
            }
        }
        group.wait()

        return (importedScholars, importedHistory)
    }

struct iCloudFileStatus {
    let iCloudAvailable: Bool
    let folderExists: Bool
    let citationDataExists: Bool
    let configExists: Bool
    let lastSyncDate: Date?
    let isSyncEnabled: Bool
    
    var description: String {
        guard iCloudAvailable else {
            return "iCloud Drive not available"
        }
        
        if !isSyncEnabled {
            // Not syncing yet
            if citationDataExists || configExists {
                if let lastSync = lastSyncDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    return "Found previous backup - \(formatter.string(from: lastSync))"
                } else {
                    return "Found previous backup - Unknown date"
                }
            } else {
                return "iCloud Drive available - Ready to sync"
            }
        } else {
            // Syncing is enabled
            if folderExists && (citationDataExists || configExists) {
                if let lastSync = lastSyncDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .none
                    formatter.timeStyle = .short
                    return "Syncing enabled - Last sync: \(formatter.string(from: lastSync))"
                } else {
                    return "Syncing enabled - Ready"
                }
            } else {
                return "Syncing enabled - Setting up..."
            }
        }
    }
    
    var folderButtonEnabled: Bool {
        return iCloudAvailable // Always enabled if iCloud is available
    }
}

// MARK: - Error Types

enum iCloudError: LocalizedError {
    case iCloudNotAvailable
    case invalidURL
    case invalidFileFormat
    case folderCreationFailed
    case exportFailed(String)
    case importFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud Drive is not available. Please check your iCloud settings."
        case .invalidURL:
            return "Invalid iCloud URL"
        case .invalidFileFormat:
            return "Invalid file format"
        case .folderCreationFailed:
            return "Failed to create CiteTrack folder in iCloud"
        case .exportFailed(let message):
            return "Export failed: \(message)"
        case .importFailed(let message):
            return "Import failed: \(message)"
        }
    }
}

// MARK: - TimeRange Extension

extension TimeRange {
    static let allTime = TimeRange.lastYear // Use a reasonable default for "all time" data
}