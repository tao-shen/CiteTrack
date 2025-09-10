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
	@Published var hasBookmarkedDriveDirectory: Bool = false
	
	private let folderName = "CiteTrack"
	private let dataFileName = "citation_data.json"
	private let configFileName = "app_config.json"
	private let driveBookmarkKey = "iCloudDrivePreferredDirectoryBookmark"
	
	private init() {}

	// MARK: - CloudDocs Folder Bookmarking

	/// 返回 iCloud Drive 根目录（com~apple~CloudDocs）URL
	func cloudDocsRootURL() -> URL? {
		#if targetEnvironment(simulator)
		return nil
		#else
		guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
		return container.deletingLastPathComponent().appendingPathComponent("com~apple~CloudDocs", isDirectory: true)
		#endif
	}

	/// 判断URL是否位于 iCloud Drive 根（com~apple~CloudDocs）之下
	private func isInCloudDocs(_ url: URL) -> Bool {
		let p = url.path
		return p.contains("/Mobile Documents/com~apple~CloudDocs/") || p.hasSuffix("/Mobile Documents/com~apple~CloudDocs")
	}

	/// 保存用户在 CloudDocs 下选择的目录为安全作用域书签
	func savePreferredDriveDirectoryBookmark(from directoryURL: URL) {
		do {
			// 只接受 CloudDocs 根下的目录，避免误选应用容器的 Documents
			guard isInCloudDocs(directoryURL) else {
				print("⚠️ [CloudDocs Bookmark] Rejected non-CloudDocs URL: \(directoryURL.path)")
				return
			}
			let bookmarkData = try directoryURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
			UserDefaults.standard.set(bookmarkData, forKey: driveBookmarkKey)
			UserDefaults.standard.synchronize()
			DispatchQueue.main.async { self.hasBookmarkedDriveDirectory = true }
			print("✅ [CloudDocs Bookmark] Saved bookmark for: \(directoryURL.path)")
		} catch {
			print("❌ [CloudDocs Bookmark] Save failed: \(error)")
		}
	}
	
	/// 在iCloud Drive中创建并显示应用文件夹
	func createiCloudDriveFolder(completion: @escaping (Result<Void, iCloudError>) -> Void) {
		print("🚀 [iCloud Drive] 开始在iCloud Drive中创建应用文件夹...")
		
		guard isiCloudAvailable else {
			print("❌ [iCloud Drive] iCloud不可用")
			DispatchQueue.main.async {
				completion(.failure(.iCloudNotAvailable))
			}
			return
		}
		
		let workItem = DispatchWorkItem {
			do {
				print("🔍 [iCloud Drive] 开始设置CiteTrack应用在iCloud Drive中的可见性...")
				
				// 确保Documents文件夹存在
				guard let documentsURL = self.documentsURL else {
					print("❌ [iCloud Drive] 无法获取Documents URL")
					DispatchQueue.main.async {
						completion(.failure(.invalidURL))
					}
					return
				}
				
				print("🔍 [iCloud Drive] Documents路径: \(documentsURL.path)")
				
				let fileManager = FileManager.default
				
				// 确保Documents文件夹存在
				if !fileManager.fileExists(atPath: documentsURL.path) {
					print("🔧 [iCloud Drive] 正在创建Documents文件夹...")
					try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
					print("✅ [iCloud Drive] 创建了Documents文件夹: \(documentsURL.path)")
				} else {
					print("ℹ️ [iCloud Drive] Documents文件夹已存在: \(documentsURL.path)")
				}
				
				// 在Documents根目录直接创建多个文件，确保应用文件夹在iCloud Drive中可见
				let sampleFiles = [
					("README.txt", """
					欢迎使用CiteTrack！
					
					这是您的CiteTrack数据文件夹，会在iCloud Drive中显示为带应用图标的"CiteTrack"文件夹。
					
					文件说明：
					• citation_data.json - 学者引用数据
					• app_config.json - 应用配置
					• 导出的文件 - 通过应用导出的备份文件
					
					您可以：
					✓ 在多个设备间自动同步数据
					✓ 手动备份和恢复数据
					✓ 与他人分享引用数据文件
					
					---
					Welcome to CiteTrack!
					
					This is your CiteTrack data folder, which will appear as the "CiteTrack" folder with app icon in iCloud Drive.
					"""),
					("用户指南.txt", """
					CiteTrack iCloud 文件夹使用指南
					
					1. 自动同步
					   应用会自动将数据同步到这个文件夹
					
					2. 手动导入导出
					   您可以在应用设置中手动导入或导出数据
					
					3. 备份恢复
					   定期备份文件可帮助您在需要时恢复数据
					
					4. 多设备使用
					   登录同一iCloud账户的设备会自动同步这个文件夹
					
					注意：请不要直接修改citation_data.json等核心文件，建议通过应用界面操作。
					"""),
					(".keep", "这个文件确保文件夹在iCloud Drive中保持可见")
				]
				
				// 创建所有示例文件
				for (fileName, content) in sampleFiles {
					let fileURL = documentsURL.appendingPathComponent(fileName)
					if !fileManager.fileExists(atPath: fileURL.path) {
						print("🔧 [iCloud Drive] 正在创建文件: \(fileName)")
						try content.write(to: fileURL, atomically: true, encoding: .utf8)
						print("✅ [iCloud Drive] 创建了文件: \(fileName)")
					} else {
						print("ℹ️ [iCloud Drive] 文件已存在: \(fileName)")
					}
				}
				
				// 确保核心数据文件存在
				if let citationURL = self.citationDataURL {
					if !fileManager.fileExists(atPath: citationURL.path) {
						print("🔧 [iCloud Drive] 创建初始citation_data.json...")
						let initialData = [
							"scholars": [],
							"lastUpdated": ISO8601DateFormatter().string(from: Date()),
							"version": "1.0"
						] as [String : Any]
						let jsonData = try JSONSerialization.data(withJSONObject: initialData, options: .prettyPrinted)
						try jsonData.write(to: citationURL)
						print("✅ [iCloud Drive] 创建了初始数据文件")
					}
				}
				
				if let configURL = self.configFileURL {
					if !fileManager.fileExists(atPath: configURL.path) {
						print("🔧 [iCloud Drive] 创建初始app_config.json...")
						let initialConfig = [
							"version": "1.0",
							"settings": [:],
							"lastModified": ISO8601DateFormatter().string(from: Date())
						] as [String : Any]
						let jsonData = try JSONSerialization.data(withJSONObject: initialConfig, options: .prettyPrinted)
						try jsonData.write(to: configURL)
						print("✅ [iCloud Drive] 创建了初始配置文件")
					}
				}
				
				// Documents文件夹已经创建，无需额外设置属性
				print("✅ [iCloud Drive] Documents文件夹已准备就绪")
				
				// 强制同步到iCloud Drive
				print("🔧 [iCloud Drive] 开始强制同步到iCloud...")
				
				if let containerURL = self.iCloudContainerURL {
					// 同步容器
					do {
						try fileManager.startDownloadingUbiquitousItem(at: containerURL)
						print("✅ [iCloud Drive] 启动了iCloud容器同步")
					} catch {
						print("⚠️ [iCloud Drive] 容器同步失败: \(error)")
					}
					
					// 同步Documents文件夹
					do {
						try fileManager.startDownloadingUbiquitousItem(at: documentsURL)
						print("✅ [iCloud Drive] 启动了Documents文件夹同步")
					} catch {
						print("⚠️ [iCloud Drive] Documents同步失败: \(error)")
					}
					
					// 同步所有创建的文件
					for (fileName, _) in sampleFiles {
						let fileURL = documentsURL.appendingPathComponent(fileName)
						do {
							try fileManager.startDownloadingUbiquitousItem(at: fileURL)
							print("✅ [iCloud Drive] 启动了文件同步: \(fileName)")
						} catch {
							print("⚠️ [iCloud Drive] 文件同步失败 \(fileName): \(error)")
						}
					}
					
					// 同步数据文件
					if let citationURL = self.citationDataURL {
						do {
							try fileManager.startDownloadingUbiquitousItem(at: citationURL)
							print("✅ [iCloud Drive] 启动了引用数据同步")
						} catch {
							print("⚠️ [iCloud Drive] 引用数据同步失败: \(error)")
						}
					}
					
					if let configURL = self.configFileURL {
						do {
							try fileManager.startDownloadingUbiquitousItem(at: configURL)
							print("✅ [iCloud Drive] 启动了配置文件同步")
						} catch {
							print("⚠️ [iCloud Drive] 配置文件同步失败: \(error)")
						}
					}
				}
				
				// 等待同步开始
				Thread.sleep(forTimeInterval: 2.0)
				
				print("🎉 [iCloud Drive] CiteTrack文件夹设置完成！")
				print("📱 [iCloud Drive] 请打开\"文件\"应用 → iCloud Drive，查看带CiteTrack图标的文件夹")
				print("📝 [iCloud Drive] 如果文件夹未立即显示，请等待几分钟让iCloud同步完成")
				
				DispatchQueue.main.async {
					completion(.success(()))
				}
				
			} catch {
				print("❌ [iCloud Drive] 创建文件夹失败: \(error)")
				print("❌ [iCloud Drive] 错误详情: \(error.localizedDescription)")
				DispatchQueue.main.async {
					completion(.failure(.exportFailed(error.localizedDescription)))
				}
			}
		}
		
		DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
	}

	/// 解析已保存的书签，返回可访问的目录 URL
	func resolvePreferredDriveDirectory() -> URL? {
		guard let data = UserDefaults.standard.data(forKey: driveBookmarkKey) else { return nil }
		var stale = false
		do {
			let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
			if stale {
				print("⚠️ [CloudDocs Bookmark] Bookmark is stale, need reselect")
				return nil
			}
			print("✅ [CloudDocs Bookmark] Resolved: \(url.path)")
			return url
		} catch {
			print("❌ [CloudDocs Bookmark] Resolve failed: \(error)")
			return nil
		}
	}

	/// 清除已保存的书签
	func clearPreferredDriveDirectoryBookmark() {
		UserDefaults.standard.removeObject(forKey: driveBookmarkKey)
		UserDefaults.standard.synchronize()
		DispatchQueue.main.async { self.hasBookmarkedDriveDirectory = false }
		print("🧹 [CloudDocs Bookmark] Cleared bookmark")
	}

	// 在应用启动时尝试创建容器和占位文件，帮助系统显示应用图标文件夹
	func bootstrapContainerIfPossible() {
        NSLog("🚀 [iCloud Debug] bootstrapContainerIfPossible() called")
		#if targetEnvironment(simulator)
		print("ℹ️ [iCloud Debug] Simulator environment - skip real iCloud bootstrap")
		return
		#endif
		
		// 检查用户是否启用了iCloud Drive文件夹功能
		let settingsManager = SettingsManager.shared
		guard settingsManager.iCloudDriveFolderEnabled else {
			print("ℹ️ [iCloud Debug] iCloud Drive folder disabled by user setting")
			return
		}
		
		print("🚀 [iCloud Debug] Bootstrap iCloud container if possible ...")
		guard isiCloudAvailable else {
			print("❌ [iCloud Debug] iCloud not available at bootstrap")
			return
		}
		guard let docs = documentsURL else {
			print("❌ [iCloud Debug] documentsURL is nil during bootstrap")
			return
		}
		let fm = FileManager.default
		// 创建 Documents（若不存在）
		if !fm.fileExists(atPath: docs.path) {
			do {
				try fm.createDirectory(at: docs, withIntermediateDirectories: true, attributes: nil)
				print("✅ [iCloud Debug] Created iCloud Documents at: \(docs.path)")
			} catch {
				print("❌ [iCloud Debug] Failed to create Documents: \(error)")
			}
		}
		// 写入占位文件
		let keep = docs.appendingPathComponent(".keep")
		if !fm.fileExists(atPath: keep.path) {
			do {
				try Data("keep".utf8).write(to: keep)
				print("✅ [iCloud Debug] Wrote placeholder at: \(keep.path)")
			} catch {
				print("❌ [iCloud Debug] Failed writing placeholder: \(error)")
			}
		}
		// 再写入一个可见文件，确保 Files 能立刻展示该文件夹
		let readme = docs.appendingPathComponent("README.txt")
		if !fm.fileExists(atPath: readme.path) {
			let content = "This folder stores CiteTrack exports."
			do {
				try content.data(using: .utf8)?.write(to: readme)
				print("✅ [iCloud Debug] Wrote visible README at: \(readme.path)")
			} catch {
				print("❌ [iCloud Debug] Failed writing README: \(error)")
			}
		}
	}

	// MARK: - Deep Diagnostics

	/// 打印容器与目录内文件的详细 iCloud 资源状态，帮助定位 Files 不显示的问题
	func runDeepDiagnostics() {
		print("🧪 [iCloud Diag] ===== BEGIN =====")
		// Token 与 Bundle 信息
		if let token = FileManager.default.ubiquityIdentityToken {
			print("🧪 [iCloud Diag] ubiquityIdentityToken: \(token)")
		} else {
			print("🧪 [iCloud Diag] ubiquityIdentityToken: nil")
		}
		print("🧪 [iCloud Diag] bundleIdentifier: \(Bundle.main.bundleIdentifier ?? "nil")")

		// 容器与 Documents URL
		if let container = iCloudContainerURL {
			print("🧪 [iCloud Diag] containerURL: \(container.path)")
		} else {
			print("🧪 [iCloud Diag] containerURL: nil")
		}
		guard let docs = documentsURL else {
			print("🧪 [iCloud Diag] documentsURL: nil")
			print("🧪 [iCloud Diag] ===== END (no docs) =====")
			return
		}
		print("🧪 [iCloud Diag] documentsURL: \(docs.path)")

		// 列出 Documents 下的文件并打印资源状态
		let fm = FileManager.default
		do {
			let items = try fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: [
				.isUbiquitousItemKey,
				.ubiquitousItemIsUploadingKey,
				.ubiquitousItemIsDownloadingKey,
				.ubiquitousItemHasUnresolvedConflictsKey,
				.isHiddenKey,
				.isExcludedFromBackupKey
			], options: [.skipsHiddenFiles])

			print("🧪 [iCloud Diag] documents items count: \(items.count)")
			for url in items {
				do {
					let values = try url.resourceValues(forKeys: [
						.isUbiquitousItemKey,
						.ubiquitousItemIsUploadingKey,
						.ubiquitousItemIsDownloadingKey,
						.ubiquitousItemHasUnresolvedConflictsKey,
						.isHiddenKey,
						.isExcludedFromBackupKey
					])
					let name = url.lastPathComponent
					let ubi = values.isUbiquitousItem ?? false
					let up = values.ubiquitousItemIsUploading ?? false
					let down = values.ubiquitousItemIsDownloading ?? false
					let conf = values.ubiquitousItemHasUnresolvedConflicts ?? false
					let hidden = values.isHidden ?? false
					let excluded = values.isExcludedFromBackup ?? false
					print("🧪 [iCloud Diag] • \(name) | ubi=\(ubi) up=\(up) down=\(down) conflicts=\(conf) hidden=\(hidden) excluded=\(excluded)")
				} catch {
					print("🧪 [iCloud Diag] • \(url.lastPathComponent) | failed to read resource values: \(error)")
				}
			}
		} catch {
			print("🧪 [iCloud Diag] list documents failed: \(error)")
		}

		// 启动一次 Metadata 查询，检查系统视角下的可见文件
		startMetadataSnapshot()
		print("🧪 [iCloud Diag] ===== END (metadata will print async) =====")
	}

	private var metadataQuery: NSMetadataQuery?

	private func startMetadataSnapshot() {
		let query = NSMetadataQuery()
		metadataQuery = query
		NotificationCenter.default.addObserver(forName: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: query, queue: .main) { [weak self] _ in
			guard let q = self?.metadataQuery else { return }
			q.disableUpdates()
			print("🧪 [iCloud Diag][MD] results: \(q.resultCount)")
			for case let item as NSMetadataItem in q.results {
				let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? "<nil>"
				let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL
				let size = item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber
				let cdate = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date
				let mdate = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
				print("🧪 [iCloud Diag][MD] • name=\(name) url=\(url?.path ?? "nil") size=\(size?.intValue ?? -1) c=\(cdate?.description ?? "nil") m=\(mdate?.description ?? "nil")")
			}
			q.stop()
			NotificationCenter.default.removeObserver(self as Any, name: .NSMetadataQueryDidFinishGathering, object: q)
		}
		query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
		query.predicate = NSPredicate(value: true)
		print("🧪 [iCloud Diag][MD] start query in UbiquitousDocumentsScope …")
		query.start()
	}
	
	// MARK: - iCloud Detection
	
	/// Check if iCloud Drive is available
	var isiCloudAvailable: Bool {
		let ubiquityToken = FileManager.default.ubiquityIdentityToken
		print("🔍 [iCloud Debug] iCloud token: \(ubiquityToken != nil ? "EXISTS" : "NOT FOUND")")
		return ubiquityToken != nil
	}
	
	// MARK: - URL Properties
	
	/// 按照指南标准实现：获取iCloud容器URL
	func getiCloudContainerURL() -> URL? {
		// 使用在Xcode中配置的容器标识符
		// 如果传nil，则会获取第一个在entitlements中声明的容器
		guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.citetrack.CiteTrack") else {
			print("无法获取iCloud容器URL。请检查：")
			print("- 用户是否已登录iCloud？")
			print("- 应用的iCloud同步是否已在系统设置中启用？")
			print("- 项目的Entitlements配置是否正确？")
			return nil
		}
		print("✅ [iCloud] 成功获取iCloud容器URL: \(containerURL.path)")
		return containerURL
	}
	
	/// 按照指南标准实现：获取公共Documents URL
	func getPublicDocumentsURL() -> URL? {
		// 用户在iCloud Drive中看到的文件夹实际对应容器内的"Documents"子目录
		return getiCloudContainerURL()?.appendingPathComponent("Documents")
	}
	
	/// 按照指南标准实现：关键激活步骤 - 创建初始文件确保文件夹可见
	func createInitialFileForVisibility() {
		guard let documentsURL = getPublicDocumentsURL() else {
			print("❌ [iCloud Activation] 无法获取Documents URL")
			return
		}

		let fileURL = documentsURL.appendingPathComponent("Welcome.txt")
		if !FileManager.default.fileExists(atPath: fileURL.path) {
			do {
				try "Hello, iCloud! 欢迎使用CiteTrack！".write(to: fileURL, atomically: true, encoding: .utf8)
				print("✅ [iCloud Activation] 初始文件创建成功：\(fileURL.path)")
				print("📝 [iCloud Activation] 这确保了应用文件夹在iCloud Drive中可见")
			} catch {
				print("❌ [iCloud Activation] 创建初始文件失败: \(error)")
			}
		} else {
			print("ℹ️ [iCloud Activation] 初始文件已存在：\(fileURL.path)")
		}
	}
	
	/// 手动创建iCloud Drive文件夹（用户主动触发）
	func createiCloudDriveFolder() -> Bool {
		guard isiCloudAvailable else {
			print("❌ [iCloud Drive] iCloud不可用")
			return false
		}
		
		guard let documentsURL = getPublicDocumentsURL() else {
			print("❌ [iCloud Drive] 无法获取Documents URL")
			return false
		}
		
		let fm = FileManager.default
		
		// 创建Documents目录（如果不存在）
		if !fm.fileExists(atPath: documentsURL.path) {
			do {
				try fm.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
				print("✅ [iCloud Drive] 创建Documents目录：\(documentsURL.path)")
			} catch {
				print("❌ [iCloud Drive] 创建Documents目录失败: \(error)")
				return false
			}
		}
		
		// 创建欢迎文件
		let welcomeFile = documentsURL.appendingPathComponent("Welcome.txt")
		if !fm.fileExists(atPath: welcomeFile.path) {
			do {
				let content = "欢迎使用CiteTrack！\n\n这个文件夹用于存储您的学术数据。\n\nWelcome to CiteTrack!\n\nThis folder stores your academic data."
				try content.write(to: welcomeFile, atomically: true, encoding: .utf8)
				print("✅ [iCloud Drive] 创建欢迎文件：\(welcomeFile.path)")
			} catch {
				print("❌ [iCloud Drive] 创建欢迎文件失败: \(error)")
				return false
			}
		}
		
		// 创建README文件
		let readmeFile = documentsURL.appendingPathComponent("README.txt")
		if !fm.fileExists(atPath: readmeFile.path) {
			do {
				let content = "CiteTrack数据文件夹\n\n此文件夹包含您的学术引用数据，会自动同步到所有登录相同Apple ID的设备。\n\nCiteTrack Data Folder\n\nThis folder contains your academic citation data and syncs automatically across all devices signed in with the same Apple ID."
				try content.write(to: readmeFile, atomically: true, encoding: .utf8)
				print("✅ [iCloud Drive] 创建README文件：\(readmeFile.path)")
			} catch {
				print("❌ [iCloud Drive] 创建README文件失败: \(error)")
			}
		}
		
		// 创建应用标识文件，帮助系统识别文件夹
		let appInfoFile = documentsURL.appendingPathComponent(".citetrack_app_info")
		if !fm.fileExists(atPath: appInfoFile.path) {
			do {
				let appInfo = [
					"app_name": "CiteTrack",
					"bundle_id": "com.citetrack.CiteTrack",
					"version": "1.0.1",
					"created_at": ISO8601DateFormatter().string(from: Date())
				]
				let jsonData = try JSONSerialization.data(withJSONObject: appInfo, options: .prettyPrinted)
				try jsonData.write(to: appInfoFile)
				print("✅ [iCloud Drive] 创建应用标识文件：\(appInfoFile.path)")
			} catch {
				print("❌ [iCloud Drive] 创建应用标识文件失败: \(error)")
			}
		}
		
		// 强制同步到iCloud
		do {
			try fm.setUbiquitous(true, itemAt: documentsURL, destinationURL: documentsURL)
			print("✅ [iCloud Drive] 强制同步到iCloud")
		} catch {
			print("⚠️ [iCloud Drive] 强制同步失败: \(error)")
		}
		
		print("✅ [iCloud Drive] iCloud Drive文件夹创建成功！")
		
		// 延迟刷新文件夹状态，确保图标正确显示
		DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
			self.refreshFolderIcon()
		}
		
		return true
	}
	
	/// 刷新文件夹图标显示
	func refreshFolderIcon() {
		guard let documentsURL = getPublicDocumentsURL() else { return }
		
		let fm = FileManager.default
		
		// 创建一个临时文件来触发系统重新评估文件夹
		let tempFile = documentsURL.appendingPathComponent(".refresh_\(Date().timeIntervalSince1970)")
		do {
			try "refresh".write(to: tempFile, atomically: true, encoding: .utf8)
			// 立即删除临时文件
			try fm.removeItem(at: tempFile)
			print("✅ [iCloud Drive] 刷新文件夹图标")
		} catch {
			print("⚠️ [iCloud Drive] 刷新文件夹图标失败: \(error)")
		}
	}
	
	/// Get iCloud container URL - 按照指南的标准实现
	private var iCloudContainerURL: URL? {
		return getiCloudContainerURL()
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

	/// 导入/导出的首选目录：优先用户书签的iCloud Drive文件夹，其次回退到应用容器Documents
	func preferredExportDirectory() -> URL? {
		if let bookmarked = resolvePreferredDriveDirectory() {
			print("🔍 [CloudDocs] Using bookmarked drive directory: \(bookmarked.path)")
			return bookmarked
		}
		return documentsURL
	}

	/// 用户可见的 iCloud Drive 根（com~apple~CloudDocs）下的推荐目录（CiteTrack）
	/// 仅用于作为 UIDocumentPicker 的初始目录，避免直接跨容器写入
	func preferredUserDriveDirectory() -> URL? {
		#if targetEnvironment(simulator)
		return nil
		#else
		// 取默认容器，然后回退到其父目录，拼接 com~apple~CloudDocs
		guard let container = iCloudContainerURL else { return nil }
		let cloudRoot = container.deletingLastPathComponent().appendingPathComponent("com~apple~CloudDocs", isDirectory: true)
		return cloudRoot.appendingPathComponent("CiteTrack", isDirectory: true)
		#endif
	}

	/// 构造 CloudDocs 下推荐的数据文件 URL（基于书签或推荐目录）
	private func cloudDocsDataFileURL() -> URL? {
		if let bookmarked = resolvePreferredDriveDirectory() {
			return bookmarked.appendingPathComponent(dataFileName)
		}
		if let suggested = preferredUserDriveDirectory() {
			return suggested.appendingPathComponent(dataFileName)
		}
		return nil
	}
	
	/// 获取当前数据根目录：优先用户书签的iCloud Drive文件夹，否则使用应用容器Documents
	private var citeTrackFolderURL: URL? {
		if let bookmarked = resolvePreferredDriveDirectory() {
			print("🔍 [CloudDocs] Using bookmarked folder for data root: \(bookmarked.path)")
			return bookmarked
		}
		guard let documentsURL = documentsURL else {
			print("❌ [iCloud Debug] No Documents folder available")
			return nil
		}
		print("🔍 [iCloud Debug] Using app iCloud Documents as export folder: \(documentsURL.path)")
		return documentsURL
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
	
	/// Export only citation data JSON to iCloud app folder (Documents root)
	func exportDataOnlyToiCloud(completion: @escaping (Result<Void, iCloudError>) -> Void) {
		print("🚀 [iCloud Export] Starting export (data only) ...")
		guard isiCloudAvailable else {
			print("❌ [iCloud Export] iCloud not available")
			completion(.failure(.iCloudNotAvailable))
			return
		}
		DispatchQueue.main.async { self.isExporting = true; self.syncStatus = LocalizationManager.shared.localized("exporting_to_icloud") }
		DispatchQueue.global(qos: .userInitiated).async {
			do {
				let jsonData = try self.makeExportJSONData()
				// 优先 CloudDocs（若已书签/可访问），否则回退到应用容器
				if let cloudURL = self.cloudDocsDataFileURL() {
					let fm = FileManager.default
					let dir = cloudURL.deletingLastPathComponent()
					try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
					try jsonData.write(to: cloudURL, options: [.atomic])
					print("✅ [iCloud Export] Data exported to CloudDocs: \(cloudURL.path)")
				} else {
					try self.createiCloudFolder()
					guard let citationURL = self.citationDataURL else { throw iCloudError.invalidURL }
					try jsonData.write(to: citationURL)
					print("✅ [iCloud Export] Data exported to App Container: \(citationURL.path)")
				}
				DispatchQueue.main.async { self.isExporting = false; self.lastSyncDate = Date(); self.syncStatus = LocalizationManager.shared.localized("export_completed"); completion(.success(())) }
			} catch {
				DispatchQueue.main.async {
					self.isExporting = false
					self.syncStatus = LocalizationManager.shared.localized("export_failed")
					if let icErr = error as? iCloudError { completion(.failure(icErr)) } else { completion(.failure(.exportFailed(error.localizedDescription))) }
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
        NSLog("🔍 [iCloud Status] checkSyncStatus() called")
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