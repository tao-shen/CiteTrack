import Foundation
import FileProvider
import UIKit

/// File Provider Domain 管理器 - 负责注册和管理文件提供程序域
@available(iOS 16.0, *)
class FileProviderManager: ObservableObject {
    
    static let shared = FileProviderManager()
    
    // MARK: - Constants
    private let domainIdentifier = NSFileProviderDomainIdentifier("com.citetrack.fileprovider")
    private let domainDisplayName = "CiteTrack Documents"
    
    // MARK: - Published Properties
    @Published var isFileProviderEnabled = false
    @Published var lastError: Error?
    
    private init() {
        checkFileProviderStatus()
    }
    
    // MARK: - Domain Management
    
    /// 初始化File Provider Domain（应在应用启动时调用）
    func initializeFileProvider() {
        NSLog("🔧 [FileProviderManager] 初始化 File Provider")
        
        Task {
            await registerDomainIfNeeded()
        }
    }
    
    /// 检查并注册域（如果需要）
    @MainActor
    private func registerDomainIfNeeded() async {
        do {
            // 检查域是否已存在
            let manager = NSFileProviderManager.default
            let existingDomains = await manager.domains
            
            let domainExists = existingDomains.contains { $0.identifier == domainIdentifier }
            
            if domainExists {
                NSLog("✅ [FileProviderManager] Domain 已存在: \(domainIdentifier.rawValue)")
                isFileProviderEnabled = true
                return
            }
            
            // 创建新域
            let domain = NSFileProviderDomain(
                identifier: domainIdentifier,
                displayName: domainDisplayName
            )
            
            // 注册域
            try await manager.add(domain)
            
            NSLog("✅ [FileProviderManager] Domain 注册成功: \(domainDisplayName)")
            isFileProviderEnabled = true
            lastError = nil
            
        } catch {
            NSLog("❌ [FileProviderManager] Domain 注册失败: \(error)")
            lastError = error
            isFileProviderEnabled = false
        }
    }
    
    /// 移除File Provider Domain
    func removeFileProvider() {
        NSLog("🔧 [FileProviderManager] 移除 File Provider Domain")
        
        Task {
            await removeDomain()
        }
    }
    
    @MainActor
    private func removeDomain() async {
        do {
            let manager = NSFileProviderManager.default
            try await manager.remove(domainIdentifier)
            
            NSLog("✅ [FileProviderManager] Domain 移除成功")
            isFileProviderEnabled = false
            lastError = nil
            
        } catch {
            NSLog("❌ [FileProviderManager] Domain 移除失败: \(error)")
            lastError = error
        }
    }
    
    /// 检查File Provider状态
    private func checkFileProviderStatus() {
        Task {
            await updateFileProviderStatus()
        }
    }
    
    @MainActor
    private func updateFileProviderStatus() async {
        do {
            let manager = NSFileProviderManager.default
            let existingDomains = await manager.domains
            
            let domainExists = existingDomains.contains { $0.identifier == domainIdentifier }
            isFileProviderEnabled = domainExists
            
            NSLog("🔍 [FileProviderManager] File Provider 状态: \(domainExists ? "已启用" : "未启用")")
            
        } catch {
            NSLog("❌ [FileProviderManager] 检查状态失败: \(error)")
            lastError = error
            isFileProviderEnabled = false
        }
    }
    
    // MARK: - File Operations
    
    /// 将学者数据导出到File Provider
    func exportScholarData(_ scholars: [Scholar]) {
        NSLog("📤 [FileProviderManager] 导出学者数据到 File Provider")
        
        Task {
            await performExportScholarData(scholars)
        }
    }
    
    @MainActor
    private func performExportScholarData(_ scholars: [Scholar]) async {
        do {
            // 创建JSON数据
            let exportData = FileProviderExportData(
                exportDate: Date(),
                version: "2.0.0",
                scholars: scholars
            )
            
            let jsonData = try JSONEncoder().encode(exportData)
            
            // 保存到App Group共享位置
            let sharedURL = getSharedDocumentsDirectory()
            let exportURL = sharedURL.appendingPathComponent("CiteTrack_Export_\(ISO8601DateFormatter().string(from: Date())).citetrack")
            
            try FileManager.default.createDirectory(at: sharedURL, withIntermediateDirectories: true, attributes: nil)
            try jsonData.write(to: exportURL)
            
            NSLog("✅ [FileProviderManager] 学者数据导出成功: \(exportURL.path)")
            
            // 通知File Provider Extension更新
            signalFileProviderUpdate()
            
        } catch {
            NSLog("❌ [FileProviderManager] 导出失败: \(error)")
            lastError = error
        }
    }
    
    /// 从File Provider导入学者数据
    func importScholarDataFromFile(at url: URL) -> [Scholar]? {
        NSLog("📥 [FileProviderManager] 从文件导入学者数据: \(url.path)")
        
        do {
            let data = try Data(contentsOf: url)
            let importData = try JSONDecoder().decode(FileProviderExportData.self, from: data)
            
            NSLog("✅ [FileProviderManager] 成功导入 \(importData.scholars.count) 位学者的数据")
            return importData.scholars
            
        } catch {
            NSLog("❌ [FileProviderManager] 导入失败: \(error)")
            lastError = error
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func getSharedDocumentsDirectory() -> URL {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.citetrack.CiteTrack")
        return containerURL?.appendingPathComponent("FileProvider") ?? FileManager.default.documentsDirectory
    }
    
    private func signalFileProviderUpdate() {
        // 通知File Provider Extension有新文件
        do {
            let manager = NSFileProviderManager(for: domainIdentifier)
            Task {
                try await manager?.signalEnumerator(for: .rootContainer) { _ in }
            }
        } catch {
            NSLog("⚠️ [FileProviderManager] 信号更新失败: \(error)")
        }
    }
    
    /// 获取File Provider Manager实例
    func getFileProviderManager() -> NSFileProviderManager? {
        guard isFileProviderEnabled else {
            NSLog("⚠️ [FileProviderManager] File Provider 未启用")
            return nil
        }
        
        return NSFileProviderManager(for: domainIdentifier)
    }
}

// MARK: - Export Data Model
struct FileProviderExportData: Codable {
    let exportDate: Date
    let version: String
    let scholars: [Scholar]
    
    enum CodingKeys: String, CodingKey {
        case exportDate = "export_date"
        case version
        case scholars
    }
}

// MARK: - Extensions for iOS 15 Compatibility
extension FileProviderManager {
    
    /// iOS 15兼容性检查
    var isAvailable: Bool {
        if #available(iOS 16.0, *) {
            return true
        } else {
            return false
        }
    }
    
    /// 为旧版本iOS提供占位方法
    func initializeForLegacyiOS() {
        if !isAvailable {
            NSLog("ℹ️ [FileProviderManager] File Provider 需要 iOS 16.0+，当前版本不支持")
        }
    }
}
