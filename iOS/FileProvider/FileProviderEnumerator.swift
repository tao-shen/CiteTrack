import FileProvider
import Foundation

/// 文件提供程序枚举器 - 负责列出特定容器中的文件和文件夹
class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    
    // MARK: - Properties
    private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
    private let domain: NSFileProviderDomain
    private var anchor: NSFileProviderSyncAnchor?
    
    // MARK: - Initialization
    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier, domain: NSFileProviderDomain) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        self.domain = domain
        super.init()
        
        NSLog("🔍 [FileProviderEnumerator] Initialized for container: \(enumeratedItemIdentifier.rawValue)")
    }
    
    // MARK: - NSFileProviderEnumerator Protocol
    
    func invalidate() {
        NSLog("🔍 [FileProviderEnumerator] Enumerator invalidated")
    }
    
    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        NSLog("🔍 [FileProviderEnumerator] Enumerating items for container: \(enumeratedItemIdentifier.rawValue)")
        
        var items: [NSFileProviderItem] = []
        
        if enumeratedItemIdentifier == .rootContainer {
            // 根容器 - 添加示例文件和文件夹
            items = createRootContainerItems()
        } else {
            // 其他容器 - 返回空列表或相应的子项
            items = createSubcontainerItems()
        }
        
        // 向观察者提供项目
        observer.didEnumerate(items)
        
        // 完成枚举
        observer.finishEnumerating(upTo: nil)
    }
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        NSLog("🔍 [FileProviderEnumerator] Enumerating changes from anchor")
        
        // 简化实现：返回所有当前项目作为"更新"
        let items = createRootContainerItems()
        
        // 将项目作为更新项目提供
        observer.didUpdate(items)
        
        // 创建新的同步锚点
        let newAnchor = createNewSyncAnchor()
        observer.finishEnumeratingChanges(upTo: newAnchor, moreComing: false)
    }
    
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        NSLog("🔍 [FileProviderEnumerator] Providing current sync anchor")
        
        let anchor = createNewSyncAnchor()
        completionHandler(anchor)
    }
}

// MARK: - Helper Methods
extension FileProviderEnumerator {
    
    private func createRootContainerItems() -> [NSFileProviderItem] {
        var items: [NSFileProviderItem] = []
        
        // 示例文档文件夹
        let documentsFolder = FileProviderItem(
            folderIdentifier: NSFileProviderItemIdentifier("documents_folder"),
            folderName: "My Documents"
        )
        items.append(documentsFolder)
        
        // 示例CiteTrack文档
        let sampleDoc = FileProviderItem(
            documentIdentifier: NSFileProviderItemIdentifier("sample_doc_1"),
            documentName: "Research Citations.citetrack",
            documentSize: 2048
        )
        items.append(sampleDoc)
        
        // 另一个示例文档
        let sampleDoc2 = FileProviderItem(
            documentIdentifier: NSFileProviderItemIdentifier("sample_doc_2"),
            documentName: "Publication List.citetrack",
            documentSize: 1536
        )
        items.append(sampleDoc2)
        
        // 备份文件夹
        let backupFolder = FileProviderItem(
            folderIdentifier: NSFileProviderItemIdentifier("backup_folder"),
            folderName: "Backups"
        )
        items.append(backupFolder)
        
        NSLog("✅ [FileProviderEnumerator] Created \(items.count) root container items")
        return items
    }
    
    private func createSubcontainerItems() -> [NSFileProviderItem] {
        // 对于子容器，可以返回相应的子项
        // 简化实现：返回空数组
        NSLog("📁 [FileProviderEnumerator] Creating subcontainer items for: \(enumeratedItemIdentifier.rawValue)")
        
        if enumeratedItemIdentifier.rawValue == "documents_folder" {
            // Documents文件夹的内容
            let subDoc = FileProviderItem(
                documentIdentifier: NSFileProviderItemIdentifier("sub_doc_1"),
                documentName: "Subfolder Document.citetrack",
                documentSize: 1024
            )
            return [subDoc]
        }
        
        return []
    }
    
    private func createNewSyncAnchor() -> NSFileProviderSyncAnchor {
        // 使用当前时间戳作为同步锚点
        let timestamp = Date().timeIntervalSince1970
        let anchorData = String(timestamp).data(using: .utf8) ?? Data()
        return NSFileProviderSyncAnchor(anchorData)
    }
    
    private func loadLocalFiles() -> [NSFileProviderItem] {
        // 从本地存储加载文件
        // 这里可以连接到App Group共享的数据
        var items: [NSFileProviderItem] = []
        
        do {
            let documentsURL = getLocalDocumentsDirectory()
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsURL, 
                                                                      includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], 
                                                                      options: .skipsHiddenFiles)
            
            for fileURL in fileURLs {
                let identifier = NSFileProviderItemIdentifier(fileURL.lastPathComponent)
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                let size = resourceValues.fileSize ?? 0
                
                let item = FileProviderItem(
                    documentIdentifier: identifier,
                    documentName: fileURL.lastPathComponent,
                    documentSize: Int64(size)
                )
                items.append(item)
            }
        } catch {
            NSLog("❌ [FileProviderEnumerator] Error loading local files: \(error)")
        }
        
        return items
    }
    
    private func getLocalDocumentsDirectory() -> URL {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.citetrack.CiteTrack")
        return containerURL?.appendingPathComponent("FileProvider") ?? FileManager.default.documentsDirectory
    }
}
