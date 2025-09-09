import Foundation
import UIKit
import UniformTypeIdentifiers

// MARK: - iCloud Sync Manager
class iCloudSyncManager: ObservableObject {
	static let shared = iCloudSyncManager()
	
	@Published var isImporting = false
	@Published var isExporting = false
	@Published var lastSyncDate: Date?
	@Published var syncStatus: String = "icloud_available_no_sync".localized
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
		
		// Handle simulator vs device compilation
		#if targetEnvironment(simulator)
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
		#else
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
		
		print("❌ [iCloud Debug] No iCloud container found")
		return nil
		#endif
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
			self.syncStatus = LocalizationManager.shared.localized("importing_from_icloud")
		}
		
		DispatchQueue.global(qos: .userInitiated).async {
			do {
				let result = try self.performImport()
				
				DispatchQueue.main.async {
					self.isImporting = false
					self.lastSyncDate = Date()
					self.syncStatus = LocalizationManager.shared.localized("import_completed")
					// 导入成功后，刷新小组件时间线，确保新学者出现在Widget
					DataManager.shared.refreshWidgets()
					completion(.success(result))
				}
			} catch {
				DispatchQueue.main.async {
					self.isImporting = false
					self.syncStatus = LocalizationManager.shared.localized("import_failed")
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
		// 使用内联处理导入
		let result = try importFromJSONData(citationData)
		
		// 尝试导入配置
		var configImported = false
		if let configURL = configFileURL, fileManager.fileExists(atPath: configURL.path) {
			print("🔍 [iCloud Import] Found config file, importing settings...")
			do {
				let configData = try Data(contentsOf: configURL)
				let config = try JSONSerialization.jsonObject(with: configData) as? [String: Any]
				if let settings = config?["settings"] as? [String: Any] {
					if let updateInterval = settings["updateInterval"] as? TimeInterval {
						SettingsManager.shared.updateInterval = updateInterval
					}
					if let notificationsEnabled = settings["notificationsEnabled"] as? Bool {
						SettingsManager.shared.notificationsEnabled = notificationsEnabled
					}
					if let language = settings["language"] as? String {
						SettingsManager.shared.language = language
					}
					if let themeRawValue = settings["theme"] as? String, let theme = AppTheme(rawValue: themeRawValue) {
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
		
		print("✅ [iCloud Import] Import completed")
		
		return ImportResult(
			importedScholars: result.importedScholars,
			importedHistory: result.importedHistory,
			configImported: configImported || result.configImported,
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
			self.syncStatus = LocalizationManager.shared.localized("exporting_to_icloud")
		}
		
		DispatchQueue.global(qos: .userInitiated).async {
			do {
				try self.performExport()
				
				DispatchQueue.main.async {
					self.isExporting = false
					self.lastSyncDate = Date()
					self.syncStatus = LocalizationManager.shared.localized("export_completed")
					completion(.success(()))
				}
			} catch {
				DispatchQueue.main.async {
					self.isExporting = false
					self.syncStatus = LocalizationManager.shared.localized("export_failed")
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
		try createiCloudFolder()
		// 使用内联实现构建导出JSON
		guard let citationURL = citationDataURL else { throw iCloudError.invalidURL }
		let jsonData = try makeExportJSONData()
		try jsonData.write(to: citationURL)
		print("✅ [iCloud Export] Citation data exported successfully")
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
				self.syncStatus = LocalizationManager.shared.localized("icloud_not_available")
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
					self.syncStatus = "\(LocalizationManager.shared.localized("last_sync")): \(formatter.string(from: lastSync))"
				} else {
					self.syncStatus = LocalizationManager.shared.localized("icloud_data_found")
				}
			}
		} else {
			DispatchQueue.main.async {
				self.syncStatus = LocalizationManager.shared.localized("icloud_available_no_sync")
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
		let localizationManager = LocalizationManager.shared
		
		if importedScholars > 0 {
			parts.append("\(localizationManager.localized("imported_scholars_count")) \(importedScholars) \(localizationManager.localized("scholars_unit"))")
		}
		
		if importedHistory > 0 {
			parts.append("\(localizationManager.localized("imported_history_count")) \(importedHistory) \(localizationManager.localized("history_entries_unit"))")
		}
		
		if configImported {
			parts.append(localizationManager.localized("imported_config"))
		}
		
		if parts.isEmpty {
			return localizationManager.localized("no_data_to_import")
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
		let localizationManager = LocalizationManager.shared
		switch self {
		case .iCloudNotAvailable:
			return localizationManager.localized("icloud_drive_unavailable")
		case .invalidURL:
			return localizationManager.localized("invalid_icloud_url")
		case .noDataFound:
			return localizationManager.localized("no_citetrack_data_in_icloud")
		case .exportFailed(let message):
			return "\(localizationManager.localized("export_failed_with_message")): \(message)"
		case .importFailed(let message):
			return "\(localizationManager.localized("import_failed_with_message")): \(message)"
		}
	}
}

// MARK: - File Picker and Manual Import

extension iCloudSyncManager {
	/// Show file picker for manual import
	func showFilePicker() { showingFilePicker = true }
	
	/// Import data from selected file
	func importFromFile(url: URL) {
		print("🚀 [Manual Import] Starting import from file: \(url.path)")
		DispatchQueue.main.async { self.isImporting = true }
		do {
			let data = try Data(contentsOf: url)
			let result = try importFromJSONData(data)
			DispatchQueue.main.async {
				self.importResult = result
				self.showingImportResult = true
				self.isImporting = false
				// 手动导入完成后也刷新Widget
				DataManager.shared.refreshWidgets()
			}
		} catch {
			print("❌ [Manual Import] Failed to import file: \(error)")
			DispatchQueue.main.async {
				self.errorMessage = "import_failed_with_message".localized + ": \(error.localizedDescription)"
				self.showingErrorAlert = true
				self.isImporting = false
			}
		}
	}

	// MARK: - 内联导入/导出实现
	private func makeExportJSONData() throws -> Data {
		let formatter = ISO8601DateFormatter()
		let scholars = DataManager.shared.scholars
		var exportEntries: [[String: Any]] = []

		for scholar in scholars {
			let histories = DataManager.shared.getHistory(for: scholar.id)
			if histories.isEmpty {
				if let citations = scholar.citations {
					let ts = scholar.lastUpdated ?? Date()
					exportEntries.append([
						"scholarId": scholar.id,
						"scholarName": scholar.displayName,
						"timestamp": formatter.string(from: ts),
						"citationCount": citations
					])
				}
			} else {
				for h in histories {
					exportEntries.append([
						"scholarId": scholar.id,
						"scholarName": scholar.displayName,
						"timestamp": formatter.string(from: h.timestamp),
						"citationCount": h.citationCount
					])
				}
			}
		}

		return try JSONSerialization.data(withJSONObject: exportEntries, options: .prettyPrinted)
	}

	@discardableResult
	private func importFromJSONData(_ data: Data) throws -> ImportResult {
		let json = try JSONSerialization.jsonObject(with: data, options: [])
		if let array = json as? [[String: Any]] {
			return importFromMacOSEntries(array)
		} else if let dict = json as? [String: Any], let citationHistory = dict["citationHistory"] as? [[String: Any]] {
			var importedHistory = 0
			let scholarNames = Set(citationHistory.compactMap { $0["scholarName"] as? String })
			for entry in citationHistory {
				if let _ = entry["scholarName"] as? String,
				   let _ = entry["citationCount"] as? Int,
				   let _ = entry["timestamp"] as? String {
					importedHistory += 1
				}
			}
			return ImportResult(importedScholars: scholarNames.count, importedHistory: importedHistory, configImported: false, importDate: Date())
		} else {
			throw iCloudError.importFailed("validation_error".localized)
		}
	}

	@discardableResult
	private func importFromMacOSEntries(_ entries: [[String: Any]]) -> ImportResult {
		var importedHistory = 0
		var importedScholars = 0
		let scholarIds = Set(entries.compactMap { $0["scholarId"] as? String })

		for scholarId in scholarIds {
			let scholarEntries = entries.filter { $0["scholarId"] as? String == scholarId }
			if let latestEntry = scholarEntries.max(by: {
				($0["timestamp"] as? String ?? "") < ($1["timestamp"] as? String ?? "")
			}) {
				let citationCount = latestEntry["citationCount"] as? Int ?? 0
				var scholar = Scholar(id: scholarId, name: "scholar_default_name".localized + " \(scholarId.prefix(8))")
				if let scholarName = latestEntry["scholarName"] as? String, !scholarName.isEmpty {
					scholar.name = scholarName
				}
				var updated = scholar
				updated.citations = citationCount
				updated.lastUpdated = ISO8601DateFormatter().date(from: latestEntry["timestamp"] as? String ?? "") ?? Date()
				DataManager.shared.addScholar(updated)
				importedScholars += 1

				for entry in scholarEntries {
					if let count = entry["citationCount"] as? Int,
					   let tsString = entry["timestamp"] as? String,
					   let ts = ISO8601DateFormatter().date(from: tsString) {
						DataManager.shared.saveHistoryIfChanged(scholarId: scholarId, citationCount: count, timestamp: ts)
						importedHistory += 1
					}
				}
			}
		}

		return ImportResult(
			importedScholars: importedScholars,
			importedHistory: importedHistory,
			configImported: false,
			importDate: Date()
		)
	}
} 