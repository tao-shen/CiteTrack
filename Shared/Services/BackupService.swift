import Foundation

public final class BackupService {
	public static let shared = BackupService()
	private init() {}

	// MARK: - Export
	/// 构建导出用的扁平数组（与现有iCloud导入格式兼容）
	public func buildExportEntries() -> [[String: Any]] {
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
		return exportEntries
	}

	/// 生成导出JSON数据
	public func makeExportJSONData() throws -> Data {
		let entries = buildExportEntries()
		return try JSONSerialization.data(withJSONObject: entries, options: .prettyPrinted)
	}

	/// 写入临时文件并返回URL（供分享/保存）
	public func writeExportToTemporaryFile(filename: String = "CiteTrack_AllData.json") throws -> URL {
		let data = try makeExportJSONData()
		let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		try data.write(to: tempURL, options: [.atomic])
		return tempURL
	}

	// MARK: - Import
	/// 从macOS/iCloud导出的扁平数组导入
	@discardableResult
	public func importFromMacOSEntries(_ entries: [[String: Any]]) -> ImportResult {
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
				// 尝试使用数据内的名称
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

	/// 从原始JSON数据导入（自动判断数组/字典结构）
	@discardableResult
	public func importFromJSONData(_ data: Data) throws -> ImportResult {
		let json = try JSONSerialization.jsonObject(with: data, options: [])
		if let array = json as? [[String: Any]] {
			return importFromMacOSEntries(array)
		} else if let dict = json as? [String: Any], let citationHistory = dict["citationHistory"] as? [[String: Any]] {
			// 兼容iOS格式：仅统计，不含学者ID，按名称汇总
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
}
