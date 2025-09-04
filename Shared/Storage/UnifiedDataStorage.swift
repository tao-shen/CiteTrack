import Foundation

// MARK: - 统一数据存储管理器
/// 负责管理App Group和标准UserDefaults的数据存储
/// 确保数据的一致性和可靠性
public class UnifiedDataStorage {
    
    // MARK: - Properties
    
    private let appGroupDefaults: UserDefaults?
    private let standardDefaults: UserDefaults
    private let dataQueue = DispatchQueue(label: "com.citetrack.data.storage", qos: .userInitiated)
    
    // MARK: - Initialization
    
    public init() {
        self.standardDefaults = UserDefaults.standard
        self.appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier)
        
        // 验证App Group可用性
        if appGroupDefaults == nil {
            print("⚠️ [UnifiedDataStorage] App Group不可用，将只使用标准UserDefaults")
        } else {
            print("✅ [UnifiedDataStorage] 初始化成功，App Group可用")
        }
    }
    
    // MARK: - 数据写入
    
    /// 写入数据到统一存储
    /// - Parameters:
    ///   - data: 要存储的数据
    ///   - key: 存储键
    ///   - syncToAppGroup: 是否同时写入App Group
    public func writeData<T: Codable>(_ data: T, forKey key: String, syncToAppGroup: Bool = true) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            dataQueue.async {
                do {
                    let encodedData = try JSONEncoder().encode(data)
                    
                    // 写入标准UserDefaults
                    self.standardDefaults.set(encodedData, forKey: key)
                    
                    // 如果需要且App Group可用，也写入App Group
                    if syncToAppGroup, let appGroupDefaults = self.appGroupDefaults {
                        appGroupDefaults.set(encodedData, forKey: key)
                        appGroupDefaults.synchronize()
                    }
                    
                    print("✅ [UnifiedDataStorage] 写入数据成功: \(key)")
                    continuation.resume()
                } catch {
                    print("❌ [UnifiedDataStorage] 写入数据失败: \(key), 错误: \(error)")
                    continuation.resume(throwing: DataRepositoryError.storageError(error))
                }
            }
        }
    }
    
    /// 写入简单值到统一存储
    public func writeValue(_ value: Any, forKey key: String, syncToAppGroup: Bool = true) async {
        await withCheckedContinuation { continuation in
            dataQueue.async {
                // 写入标准UserDefaults
                self.standardDefaults.set(value, forKey: key)
                
                // 如果需要且App Group可用，也写入App Group
                if syncToAppGroup, let appGroupDefaults = self.appGroupDefaults {
                    appGroupDefaults.set(value, forKey: key)
                    appGroupDefaults.synchronize()
                }
                
                print("✅ [UnifiedDataStorage] 写入值成功: \(key)")
                continuation.resume()
            }
        }
    }
    
    // MARK: - 数据读取
    
    /// 从统一存储读取数据
    /// - Parameters:
    ///   - type: 数据类型
    ///   - key: 存储键
    ///   - preferAppGroup: 是否优先从App Group读取
    public func readData<T: Codable>(_ type: T.Type, forKey key: String, preferAppGroup: Bool = true) async throws -> T? {
        return try await withCheckedThrowingContinuation { continuation in
            dataQueue.async {
                do {
                    var data: Data?
                    
                    // 根据偏好选择读取源
                    if preferAppGroup, let appGroupDefaults = self.appGroupDefaults {
                        data = appGroupDefaults.data(forKey: key)
                        if data == nil {
                            // App Group中没有数据，尝试从标准UserDefaults读取
                            data = self.standardDefaults.data(forKey: key)
                        }
                    } else {
                        data = self.standardDefaults.data(forKey: key)
                        if data == nil, let appGroupDefaults = self.appGroupDefaults {
                            // 标准UserDefaults中没有数据，尝试从App Group读取
                            data = appGroupDefaults.data(forKey: key)
                        }
                    }
                    
                    guard let validData = data else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let decodedData = try JSONDecoder().decode(type, from: validData)
                    print("✅ [UnifiedDataStorage] 读取数据成功: \(key)")
                    continuation.resume(returning: decodedData)
                } catch {
                    print("❌ [UnifiedDataStorage] 读取数据失败: \(key), 错误: \(error)")
                    continuation.resume(throwing: DataRepositoryError.storageError(error))
                }
            }
        }
    }
    
    /// 读取简单值
    public func readValue(forKey key: String, preferAppGroup: Bool = true) async -> Any? {
        return await withCheckedContinuation { continuation in
            dataQueue.async {
                var value: Any?
                
                // 根据偏好选择读取源
                if preferAppGroup, let appGroupDefaults = self.appGroupDefaults {
                    value = appGroupDefaults.object(forKey: key)
                    if value == nil {
                        value = self.standardDefaults.object(forKey: key)
                    }
                } else {
                    value = self.standardDefaults.object(forKey: key)
                    if value == nil, let appGroupDefaults = self.appGroupDefaults {
                        value = appGroupDefaults.object(forKey: key)
                    }
                }
                
                continuation.resume(returning: value)
            }
        }
    }
    
    // MARK: - 数据删除
    
    /// 删除指定键的数据
    public func removeData(forKey key: String, fromAppGroup: Bool = true) async {
        await withCheckedContinuation { continuation in
            dataQueue.async {
                // 从标准UserDefaults删除
                self.standardDefaults.removeObject(forKey: key)
                
                // 如果需要，也从App Group删除
                if fromAppGroup, let appGroupDefaults = self.appGroupDefaults {
                    appGroupDefaults.removeObject(forKey: key)
                    appGroupDefaults.synchronize()
                }
                
                print("✅ [UnifiedDataStorage] 删除数据成功: \(key)")
                continuation.resume()
            }
        }
    }
    
    // MARK: - 数据同步
    
    /// 同步标准UserDefaults到App Group
    public func syncToAppGroup(keys: [String]) async throws {
        guard let appGroupDefaults = appGroupDefaults else {
            throw DataRepositoryError.syncFailure("App Group不可用")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            dataQueue.async {
                do {
                    for key in keys {
                        if let value = self.standardDefaults.object(forKey: key) {
                            appGroupDefaults.set(value, forKey: key)
                        }
                    }
                    appGroupDefaults.synchronize()
                    print("✅ [UnifiedDataStorage] 同步到App Group成功")
                    continuation.resume()
                } catch {
                    print("❌ [UnifiedDataStorage] 同步到App Group失败: \(error)")
                    continuation.resume(throwing: DataRepositoryError.syncFailure(error.localizedDescription))
                }
            }
        }
    }
    
    /// 从App Group同步到标准UserDefaults
    public func syncFromAppGroup(keys: [String]) async throws {
        guard let appGroupDefaults = appGroupDefaults else {
            throw DataRepositoryError.syncFailure("App Group不可用")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            dataQueue.async {
                do {
                    for key in keys {
                        if let value = appGroupDefaults.object(forKey: key) {
                            self.standardDefaults.set(value, forKey: key)
                        }
                    }
                    print("✅ [UnifiedDataStorage] 从App Group同步成功")
                    continuation.resume()
                } catch {
                    print("❌ [UnifiedDataStorage] 从App Group同步失败: \(error)")
                    continuation.resume(throwing: DataRepositoryError.syncFailure(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - 数据验证
    
    /// 验证App Group和标准UserDefaults的数据一致性
    public func validateConsistency(for keys: [String]) async -> [String: Bool] {
        return await withCheckedContinuation { continuation in
            dataQueue.async {
                var results: [String: Bool] = [:]
                
                for key in keys {
                    let standardValue = self.standardDefaults.object(forKey: key)
                    let appGroupValue = self.appGroupDefaults?.object(forKey: key)
                    
                    // 简单比较（可以根据需要扩展更复杂的比较逻辑）
                    let isConsistent = (standardValue == nil && appGroupValue == nil) ||
                                     (standardValue != nil && appGroupValue != nil)
                    
                    results[key] = isConsistent
                }
                
                continuation.resume(returning: results)
            }
        }
    }
    
    // MARK: - 工具方法
    
    /// 获取所有存储的键
    public func getAllKeys() async -> (standard: [String], appGroup: [String]) {
        return await withCheckedContinuation { continuation in
            dataQueue.async {
                let standardKeys = Array(self.standardDefaults.dictionaryRepresentation().keys)
                let appGroupKeys = self.appGroupDefaults?.dictionaryRepresentation().keys.map(Array.init) ?? []
                
                continuation.resume(returning: (standardKeys, appGroupKeys))
            }
        }
    }
    
    /// 检查App Group是否可用
    public var isAppGroupAvailable: Bool {
        return appGroupDefaults != nil
    }
}

// MARK: - 存储键常量
public extension UnifiedDataStorage {
    struct Keys {
        public static let scholars = "ScholarsList"
        public static let citationHistory = "CitationHistoryData"
        public static let widgetScholars = "WidgetScholars"
        public static let selectedScholarId = "SelectedWidgetScholarId"
        public static let selectedScholarName = "SelectedWidgetScholarName"
        public static let lastRefreshTime = "LastRefreshTime"
        public static let refreshInProgress = "RefreshInProgress"
        public static let refreshStartTime = "RefreshStartTime"
        public static let widgetTheme = "WidgetTheme"
    }
}
