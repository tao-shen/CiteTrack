import Foundation
import Cocoa

// MARK: - iCloud Sync Manager
class iCloudSyncManager {
    static let shared = iCloudSyncManager()
    
    private let iCloudContainerIdentifier: String? = nil // Use default container
    private let folderName = "CiteTrack"
    private let dataFileName = "citation_data.json"
    private let configFileName = "app_config.json"
    
    // Auto sync properties
    private var syncTimer: Timer?
    private var isAutoSyncEnabled: Bool = false
    private let syncQueue = DispatchQueue(label: "com.citetrack.icloud.sync", qos: .utility)
    private let syncInterval: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
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
    
    /// Get CiteTrack folder URL
    private var citeTrackFolderURL: URL? {
        return documentsURL?.appendingPathComponent(folderName)
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
    
    /// Export citation data to iCloud
    func exportCitationData() throws {
        let semaphore = DispatchSemaphore(value: 0)
        var historyEntries: [CitationHistory] = []
        var fetchError: Error?
        
        CitationHistoryManager.shared.getAllHistory { result in
            switch result {
            case .success(let entries):
                historyEntries = entries
            case .failure(let error):
                fetchError = error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = fetchError {
            throw error
        }
        
        let exportData: [[String: Any]] = historyEntries.map { entry in
            return [
                "scholarId": entry.scholarId,
                "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
                "citationCount": entry.citationCount
            ]
        }
        
        guard let citationURL = citationDataURL else {
            throw iCloudError.invalidURL
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        try jsonData.write(to: citationURL)
        
        print("✅ Citation data exported to iCloud: \(citationURL.path)")
    }
    
    /// Export app configuration to iCloud
    func exportAppConfig() throws {
        guard let configURL = configFileURL else {
            throw iCloudError.invalidURL
        }
        
        let prefs = PreferencesManager.shared
        let config: [String: Any] = [
            "version": "1.0",
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "settings": [
                "language": LocalizationManager.shared.currentLanguageCode,
                "updateInterval": prefs.updateInterval,
                "showInDock": prefs.showInDock,
                "showInMenuBar": prefs.showInMenuBar,
                "launchAtLogin": prefs.launchAtLogin
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try jsonData.write(to: configURL)
        
        print("✅ App config exported to iCloud: \(configURL.path)")
    }
    
    // MARK: - Auto Sync Management
    
    /// Enable automatic iCloud synchronization
    func enableAutoSync() {
        print("🔄 [iCloud Sync] Enabling automatic sync...")
        isAutoSyncEnabled = true
        
        DispatchQueue.main.async { [weak self] in
            self?.startSyncTimer()
        }
        
        // Perform initial sync
        performInitialSync()
    }
    
    /// Disable automatic iCloud synchronization
    func disableAutoSync() {
        print("⏹️ [iCloud Sync] Disabling automatic sync...")
        isAutoSyncEnabled = false
        
        DispatchQueue.main.async { [weak self] in
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
            
            do {
                // Create folder if needed
                try self.createiCloudFolder()
                
                // Export current data
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
            
            do {
                // Always try to sync during periodic checks
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
            DispatchQueue.main.async {
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

// MARK: - Data Structures

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