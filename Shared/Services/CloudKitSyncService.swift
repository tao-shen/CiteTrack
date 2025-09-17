import Foundation
import CloudKit

/// CloudKit 同步服务（共享于 iOS 与 macOS）
/// - 目标：长期同步使用单一记录，保证多端一致（同一“文件名”语义）
/// - 实现：使用私有数据库中的固定 `recordID` 存储 JSON 资产
public final class CloudKitSyncService {
    public static let shared = CloudKitSyncService()

    // 固定的记录与字段，确保跨设备“同名文件”语义
    private let recordType = "CiteTrackData"
    private let recordName = "CiteTrackSync" // 跨端固定
    private let assetFieldKey = "payload"
    private let filenameFieldKey = "filename"
    // 供 UI 显示/记录的人类可读文件名（跨端一致）
    public let normalizedFileName = "CiteTrack_sync.json"

    private let container: CKContainer
    private let database: CKDatabase

    private init(container: CKContainer = .default()) {
        self.container = container
        self.database = container.privateCloudDatabase
    }

    /// 写入 JSON 数据到固定记录
    /// - Parameter data: 导出的 JSON 数据
    /// - Parameter completion: 结果回调
    public func saveJSONData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: recordName)

        // 先抓取旧记录，存在则更新，不存在则创建
        database.fetch(withRecordID: recordID) { [weak self] existing, fetchError in
            if let fetchError = fetchError as? CKError, fetchError.code != .unknownItem {
                DispatchQueue.main.async { completion(.failure(fetchError)) }
                return
            }

            let record = existing ?? CKRecord(recordType: self?.recordType ?? "CiteTrackData", recordID: recordID)

            // 将数据写入临时文件作为 CKAsset
            do {
                let tempURL = try self?.writeToTemporaryFile(data: data, suggestedName: self?.normalizedFileName ?? "CiteTrack_sync.json")
                guard let assetURL = tempURL else {
                    DispatchQueue.main.async { completion(.failure(NSError(domain: "CloudKitSyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create temp file"])))}
                    return
                }
                let asset = CKAsset(fileURL: assetURL)
                record[self?.assetFieldKey ?? "payload"] = asset
                record[self?.filenameFieldKey ?? "filename"] = self?.normalizedFileName

                self?.database.save(record) { _, saveError in
                    // 清理临时文件
                    try? FileManager.default.removeItem(at: assetURL)
                    if let saveError = saveError {
                        DispatchQueue.main.async { completion(.failure(saveError)) }
                    } else {
                        DispatchQueue.main.async { completion(.success(())) }
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// 读取固定记录中的 JSON 数据
    /// - Parameter completion: 返回 Data
    public func fetchJSONData(completion: @escaping (Result<Data, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: recordName)
        database.fetch(withRecordID: recordID) { [weak self] record, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let record = record,
                  let asset = record[self?.assetFieldKey ?? "payload"] as? CKAsset,
                  let fileURL = asset.fileURL,
                  let data = try? Data(contentsOf: fileURL) else {
                DispatchQueue.main.async { completion(.failure(NSError(domain: "CloudKitSyncService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data found"])))}
                return
            }
            DispatchQueue.main.async { completion(.success(data)) }
        }
    }

    // MARK: - Helpers

    private func writeToTemporaryFile(data: Data, suggestedName: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(suggestedName)
        try data.write(to: url, options: [.atomic])
        return url
    }
}


