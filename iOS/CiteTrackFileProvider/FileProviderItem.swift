import FileProvider
import Foundation
import UniformTypeIdentifiers

/// 文件提供程序中的文件或文件夹项
class FileProviderItem: NSObject, NSFileProviderItem {
    
    // MARK: - Properties
    let identifier: NSFileProviderItemIdentifier
    let filename: String
    let contentType: UTType
    private let creationDate: Date
    private let modificationDate: Date
    private let size: Int64
    private let isDirectory: Bool
    
    // MARK: - Initialization
    init(identifier: NSFileProviderItemIdentifier, 
         filename: String, 
         contentType: UTType,
         size: Int64 = 0,
         isDirectory: Bool = false) {
        
        self.identifier = identifier
        self.filename = filename
        self.contentType = contentType
        self.size = size
        self.isDirectory = isDirectory || contentType.conforms(to: .folder)
        self.creationDate = Date()
        self.modificationDate = Date()
        
        super.init()
    }
    
    // MARK: - NSFileProviderItem Protocol
    
    var itemIdentifier: NSFileProviderItemIdentifier {
        return identifier
    }
    
    var parentItemIdentifier: NSFileProviderItemIdentifier {
        // 简化实现：所有项目都在根目录下
        return .rootContainer
    }
    
    var capabilities: NSFileProviderItemCapabilities {
        var caps: NSFileProviderItemCapabilities = []
        
        if isDirectory {
            caps.insert([.allowsAddingSubItems, .allowsContentEnumerating])
        } else {
            caps.insert([.allowsReading, .allowsWriting, .allowsRenaming, .allowsDeleting])
        }
        
        return caps
    }
    
    var documentSize: NSNumber? {
        return isDirectory ? nil : NSNumber(value: size)
    }
    
    var childItemCount: NSNumber? {
        // 对于文件夹，可以返回子项数量
        return isDirectory ? NSNumber(value: 0) : nil
    }
    
    var creationDate: Date? {
        return creationDate
    }
    
    var contentModificationDate: Date? {
        return modificationDate
    }
    
    var isUploaded: Bool {
        // 简化实现：所有文件都被认为已上传
        return true
    }
    
    var isUploading: Bool {
        return false
    }
    
    var uploadingError: Error? {
        return nil
    }
    
    var isDownloaded: Bool {
        // 简化实现：所有文件都被认为已下载
        return true
    }
    
    var isDownloading: Bool {
        return false
    }
    
    var downloadingError: Error? {
        return nil
    }
    
    var isMostRecentVersionDownloaded: Bool {
        return true
    }
    
    var isShared: Bool {
        return false
    }
    
    var isSharedByCurrentUser: Bool {
        return false
    }
    
    var ownerNameComponents: PersonNameComponents? {
        return nil
    }
    
    var mostRecentEditorNameComponents: PersonNameComponents? {
        return nil
    }
    
    var versionIdentifier: Data? {
        // 使用修改日期作为版本标识符
        return modificationDate.timeIntervalSince1970.description.data(using: .utf8)
    }
    
    var userInfo: [AnyHashable : Any]? {
        return nil
    }
    
    var tagData: Data? {
        return nil
    }
    
    var favoriteRank: NSNumber? {
        return nil
    }
    
    var isTrashed: Bool {
        return false
    }
    
    var trashedDate: Date? {
        return nil
    }
    
    var fileSystemFlags: NSFileProviderFileSystemFlags {
        return []
    }
    
    var extendedAttributes: [String : Data] {
        return [:]
    }
    
    var typeAndCreator: NSFileProviderTypeAndCreator {
        return NSFileProviderTypeAndCreator()
    }
}

// MARK: - Convenience Initializers
extension FileProviderItem {
    
    /// 创建文件夹项
    convenience init(folderIdentifier: NSFileProviderItemIdentifier, folderName: String) {
        self.init(
            identifier: folderIdentifier,
            filename: folderName,
            contentType: .folder,
            size: 0,
            isDirectory: true
        )
    }
    
    /// 创建CiteTrack文档项
    convenience init(documentIdentifier: NSFileProviderItemIdentifier, 
                    documentName: String, 
                    documentSize: Int64 = 1024) {
        
        let contentType = UTType(filenameExtension: "citetrack") ?? .json
        
        self.init(
            identifier: documentIdentifier,
            filename: documentName,
            contentType: contentType,
            size: documentSize,
            isDirectory: false
        )
    }
}
