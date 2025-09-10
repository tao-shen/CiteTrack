import FileProvider
import Foundation
import UniformTypeIdentifiers

/// CiteTrack File Provider Extension - 方法2实现
/// 为CiteTrack应用提供文件系统集成，在Files app中显示为独立的文件提供程序
class FileProviderExtension: NSFileProviderReplicatedExtension {
    
    // MARK: - 初始化
    required init(domain: NSFileProviderDomain) {
        super.init(domain: domain)
        
        // 设置日志
        NSLog("🔧 [FileProvider] Extension initialized for domain: \(domain.displayName)")
    }
    
    // MARK: - 域管理
    override func invalidate() {
        NSLog("🔧 [FileProvider] Extension invalidated")
        super.invalidate()
    }
    
    // MARK: - 项目枚举
    override func item(for identifier: NSFileProviderItemIdentifier, 
                      request: NSFileProviderRequest, 
                      completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress {
        
        NSLog("🔧 [FileProvider] Fetching item for identifier: \(identifier.rawValue)")
        
        // 根目录
        if identifier == .rootContainer {
            let rootItem = FileProviderItem(
                identifier: .rootContainer,
                filename: "CiteTrack Documents",
                contentType: .folder
            )
            completionHandler(rootItem, nil)
            return Progress()
        }
        
        // 创建示例文件项
        let item = FileProviderItem(
            identifier: identifier,
            filename: "Sample Document.citetrack",
            contentType: UTType(filenameExtension: "citetrack") ?? .json
        )
        
        completionHandler(item, nil)
        return Progress()
    }
    
    // MARK: - 内容获取
    override func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, 
                               version: NSFileProviderItemVersion?, 
                               request: NSFileProviderRequest, 
                               completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
        
        NSLog("🔧 [FileProvider] Fetching contents for item: \(itemIdentifier.rawValue)")
        
        // 创建临时文件
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("sample.citetrack")
        
        do {
            let sampleData = """
            {
                "applicationName": "CiteTrack",
                "version": "2.0.0",
                "message": "This is a sample document from CiteTrack File Provider Extension",
                "createdDate": "\(ISO8601DateFormatter().string(from: Date()))",
                "scholars": []
            }
            """.data(using: .utf8)
            
            try sampleData?.write(to: tempURL)
            
            let item = FileProviderItem(
                identifier: itemIdentifier,
                filename: "Sample Document.citetrack",
                contentType: UTType(filenameExtension: "citetrack") ?? .json
            )
            
            completionHandler(tempURL, item, nil)
        } catch {
            NSLog("❌ [FileProvider] Error creating sample file: \(error)")
            completionHandler(nil, nil, error)
        }
        
        return Progress()
    }
    
    // MARK: - 文件创建
    override func createItem(basedOn itemTemplate: NSFileProviderItem, 
                           fields: NSFileProviderItemFields, 
                           contents: URL?, 
                           options: NSFileProviderCreateItemOptions = [], 
                           request: NSFileProviderRequest, 
                           completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        
        NSLog("🔧 [FileProvider] Creating item: \(itemTemplate.filename)")
        
        // 创建新文件项
        let newIdentifier = NSFileProviderItemIdentifier(UUID().uuidString)
        let newItem = FileProviderItem(
            identifier: newIdentifier,
            filename: itemTemplate.filename,
            contentType: itemTemplate.contentType ?? .data
        )
        
        // 如果有内容，保存到本地存储
        if let contentURL = contents {
            saveFileContent(from: contentURL, identifier: newIdentifier)
        }
        
        completionHandler(newItem, [], false, nil)
        return Progress()
    }
    
    // MARK: - 文件修改
    override func modifyItem(_ item: NSFileProviderItem, 
                           baseVersion: NSFileProviderItemVersion, 
                           changedFields: NSFileProviderItemFields, 
                           contents: URL?, 
                           options: NSFileProviderModifyItemOptions = [], 
                           request: NSFileProviderRequest, 
                           completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        
        NSLog("🔧 [FileProvider] Modifying item: \(item.filename)")
        
        // 如果有新内容，更新文件
        if let contentURL = contents {
            saveFileContent(from: contentURL, identifier: item.itemIdentifier)
        }
        
        completionHandler(item, [], false, nil)
        return Progress()
    }
    
    // MARK: - 文件删除
    override func deleteItem(identifier: NSFileProviderItemIdentifier, 
                           baseVersion: NSFileProviderItemVersion, 
                           options: NSFileProviderDeleteItemOptions = [], 
                           request: NSFileProviderRequest, 
                           completionHandler: @escaping (Error?) -> Void) -> Progress {
        
        NSLog("🔧 [FileProvider] Deleting item: \(identifier.rawValue)")
        
        // 从本地存储中删除文件
        deleteFileContent(identifier: identifier)
        
        completionHandler(nil)
        return Progress()
    }
    
    // MARK: - 枚举器工厂
    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, 
                           request: NSFileProviderRequest) throws -> NSFileProviderEnumerator {
        
        NSLog("🔧 [FileProvider] Creating enumerator for container: \(containerItemIdentifier.rawValue)")
        
        return FileProviderEnumerator(
            enumeratedItemIdentifier: containerItemIdentifier,
            domain: domain
        )
    }
}

// MARK: - Helper Methods
extension FileProviderExtension {
    
    private func saveFileContent(from sourceURL: URL, identifier: NSFileProviderItemIdentifier) {
        do {
            let documentsURL = getLocalDocumentsDirectory()
            let destinationURL = documentsURL.appendingPathComponent(identifier.rawValue)
            
            // 确保目录存在
            try FileManager.default.createDirectory(at: documentsURL, 
                                                  withIntermediateDirectories: true, 
                                                  attributes: nil)
            
            // 复制文件
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            NSLog("✅ [FileProvider] File saved: \(destinationURL.path)")
        } catch {
            NSLog("❌ [FileProvider] Error saving file: \(error)")
        }
    }
    
    private func deleteFileContent(identifier: NSFileProviderItemIdentifier) {
        do {
            let documentsURL = getLocalDocumentsDirectory()
            let fileURL = documentsURL.appendingPathComponent(identifier.rawValue)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                NSLog("✅ [FileProvider] File deleted: \(fileURL.path)")
            }
        } catch {
            NSLog("❌ [FileProvider] Error deleting file: \(error)")
        }
    }
    
    private func getLocalDocumentsDirectory() -> URL {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.citetrack.CiteTrack")
        return containerURL?.appendingPathComponent("FileProvider") ?? FileManager.default.documentsDirectory
    }
}
