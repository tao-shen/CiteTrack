import Foundation
import Combine
#if os(iOS)
import WidgetKit
#endif

// MARK: - Settings Manager
public class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    private let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    
    @Published public var updateInterval: TimeInterval {
        didSet { userDefaults.set(updateInterval, forKey: Keys.updateInterval) }
    }
    
    @Published public var showInDock: Bool {
        didSet { userDefaults.set(showInDock, forKey: Keys.showInDock) }
    }
    
    @Published public var showInMenuBar: Bool {
        didSet { userDefaults.set(showInMenuBar, forKey: Keys.showInMenuBar) }
    }
    
    @Published public var launchAtLogin: Bool {
        didSet { userDefaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }
    
    @Published public var iCloudSyncEnabled: Bool {
        didSet { userDefaults.set(iCloudSyncEnabled, forKey: Keys.iCloudSyncEnabled) }
    }
    
    @Published public var iCloudDriveFolderEnabled: Bool {
        didSet { userDefaults.set(iCloudDriveFolderEnabled, forKey: Keys.iCloudDriveFolderEnabled) }
    }
    
    @Published public var notificationsEnabled: Bool {
        didSet { userDefaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }
    
    @Published public var language: String {
        didSet { userDefaults.set(language, forKey: Keys.language) }
    }
    
    @Published public var theme: AppTheme {
        didSet { userDefaults.set(theme.rawValue, forKey: Keys.theme) }
    }
    
    // Widget 专用主题（独立于主App），持久化到 App Group，供小组件读取
    @Published public var widgetTheme: AppTheme {
        didSet {
            // 标准与 App Group 都写入，保证一致
            userDefaults.set(widgetTheme.rawValue, forKey: Keys.widgetTheme)
            appGroupDefaults?.set(widgetTheme.rawValue, forKey: Keys.widgetTheme)
            appGroupDefaults?.synchronize()
            print("🧪 [SettingsManager] \(String(format: "debug_write_widget_theme".localized, widgetTheme.rawValue, appGroupIdentifier))")
            // 通知小组件刷新以应用新主题
            #if os(iOS)
            WidgetCenter.shared.reloadAllTimelines()
            print("🧪 [SettingsManager] \("debug_reload_widget_timelines".localized)")
            #endif
        }
    }
    
    @Published public var chartConfiguration: ChartConfiguration {
        didSet { 
            if let data = try? JSONEncoder().encode(chartConfiguration) {
                userDefaults.set(data, forKey: Keys.chartConfiguration)
            }
        }
    }
    
    // 自动更新设置
    @Published public var autoUpdateEnabled: Bool {
        didSet { userDefaults.set(autoUpdateEnabled, forKey: Keys.autoUpdateEnabled) }
    }
    
    @Published public var autoUpdateFrequency: AutoUpdateFrequency {
        didSet { userDefaults.set(autoUpdateFrequency.rawValue, forKey: Keys.autoUpdateFrequency) }
    }
    
    @Published public var nextUpdateDate: Date? {
        didSet { 
            if let date = nextUpdateDate {
                userDefaults.set(date, forKey: Keys.nextUpdateDate)
            } else {
                userDefaults.removeObject(forKey: Keys.nextUpdateDate)
            }
        }
    }
    
    @Published public var scholars: [Scholar] = []
    
    // MARK: - Initialization
    
    private init() {
        // 从UserDefaults读取设置，如果不存在则使用默认值
        self.updateInterval = TimeInterval(userDefaults.object(forKey: Keys.updateInterval) as? Double ?? 3600.0) // 1小时
        self.showInDock = userDefaults.object(forKey: Keys.showInDock) as? Bool ?? true
        self.showInMenuBar = userDefaults.object(forKey: Keys.showInMenuBar) as? Bool ?? true
        self.launchAtLogin = userDefaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        self.iCloudSyncEnabled = userDefaults.object(forKey: Keys.iCloudSyncEnabled) as? Bool ?? false
        self.iCloudDriveFolderEnabled = userDefaults.object(forKey: Keys.iCloudDriveFolderEnabled) as? Bool ?? false
        self.notificationsEnabled = userDefaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        self.language = userDefaults.string(forKey: Keys.language) ?? "auto"
        
        // 主题设置（默认浅色）
        let themeRawValue = userDefaults.string(forKey: Keys.theme) ?? AppTheme.light.rawValue
        self.theme = AppTheme(rawValue: themeRawValue) ?? .light
        
        // Widget 主题（优先从 App Group 读取，其次标准，默认 system）
        if let agValue = appGroupDefaults?.string(forKey: Keys.widgetTheme),
           let t = AppTheme(rawValue: agValue) {
            self.widgetTheme = t
        } else if let stdValue = userDefaults.string(forKey: Keys.widgetTheme),
                  let t = AppTheme(rawValue: stdValue) {
            self.widgetTheme = t
        } else {
            // 默认小组件为深色
            self.widgetTheme = .dark
        }
        
        // 图表配置
        if let data = userDefaults.data(forKey: Keys.chartConfiguration),
           let config = try? JSONDecoder().decode(ChartConfiguration.self, from: data) {
            self.chartConfiguration = config
        } else {
            self.chartConfiguration = ChartConfiguration.default
        }
        
        // 自动更新设置
        self.autoUpdateEnabled = userDefaults.object(forKey: Keys.autoUpdateEnabled) as? Bool ?? false
        let frequencyRawValue = userDefaults.string(forKey: Keys.autoUpdateFrequency) ?? AutoUpdateFrequency.daily.rawValue
        self.autoUpdateFrequency = AutoUpdateFrequency(rawValue: frequencyRawValue) ?? .daily
        self.nextUpdateDate = userDefaults.object(forKey: Keys.nextUpdateDate) as? Date
        
        // 加载学者数据
        self.scholars = getScholars()
    }
    
    // MARK: - User Defaults Keys
    
    private enum Keys {
        static let updateInterval = "UpdateInterval"
        static let showInDock = "ShowInDock"
        static let showInMenuBar = "ShowInMenuBar"
        static let launchAtLogin = "LaunchAtLogin"
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let iCloudDriveFolderEnabled = "iCloudDriveFolderEnabled"
        static let notificationsEnabled = "NotificationsEnabled"
        static let language = "Language"
        static let theme = "Theme"
        static let chartConfiguration = "ChartConfiguration"
        static let lastUpdateDate = "LastUpdateDate"
        static let scholars = "Scholars"
        static let widgetTheme = "WidgetTheme"
        static let autoUpdateEnabled = "AutoUpdateEnabled"
        static let autoUpdateFrequency = "AutoUpdateFrequency"
        static let nextUpdateDate = "NextUpdateDate"
    }
    
    // MARK: - Scholar Management
    
    public func getScholars() -> [Scholar] {
        guard let data = userDefaults.data(forKey: Keys.scholars),
              let scholars = try? JSONDecoder().decode([Scholar].self, from: data) else {
            return []
        }
        return scholars
    }
    
    public func saveScholars(_ scholars: [Scholar]) {
        if let data = try? JSONEncoder().encode(scholars) {
            userDefaults.set(data, forKey: Keys.scholars)
        }
    }
    
    public func addScholar(_ scholar: Scholar) {
        var updatedScholars = getScholars()
        // Check if scholar already exists
        if !updatedScholars.contains(where: { $0.id == scholar.id }) {
            updatedScholars.append(scholar)
            saveScholars(updatedScholars)
            self.scholars = updatedScholars
        }
    }
    
    public func removeScholar(id: String) {
        var updatedScholars = getScholars()
        updatedScholars.removeAll { $0.id == id }
        saveScholars(updatedScholars)
        self.scholars = updatedScholars
    }
    
    public func updateScholar(_ scholar: Scholar) {
        var updatedScholars = getScholars()
        if let index = updatedScholars.firstIndex(where: { $0.id == scholar.id }) {
            updatedScholars[index] = scholar
            saveScholars(updatedScholars)
            self.scholars = updatedScholars
        }
    }
    
    // MARK: - Update Tracking
    
    public var lastUpdateDate: Date? {
        get {
            return userDefaults.object(forKey: Keys.lastUpdateDate) as? Date
        }
        set {
            if let date = newValue {
                userDefaults.set(date, forKey: Keys.lastUpdateDate)
            } else {
                userDefaults.removeObject(forKey: Keys.lastUpdateDate)
            }
        }
    }
    
    // MARK: - Configuration Presets
    
    public func applyDefaultSettings() {
        updateInterval = 3600.0
        showInDock = true
        showInMenuBar = true
        launchAtLogin = false
        iCloudSyncEnabled = false
        iCloudDriveFolderEnabled = false
        notificationsEnabled = true
        language = "auto"
        // 默认主应用浅色
        theme = .light
        // 默认小组件深色
        widgetTheme = .dark
        chartConfiguration = .default
    }
    
    public func exportSettings() -> [String: Any] {
        return [
            "updateInterval": updateInterval,
            "showInDock": showInDock,
            "showInMenuBar": showInMenuBar,
            "launchAtLogin": launchAtLogin,
            "iCloudSyncEnabled": iCloudSyncEnabled,
            "iCloudDriveFolderEnabled": iCloudDriveFolderEnabled,
            "notificationsEnabled": notificationsEnabled,
            "language": language,
            "theme": theme.rawValue,
            "widgetTheme": widgetTheme.rawValue,
            "chartConfiguration": chartConfiguration
        ]
    }
    
    public func importSettings(from dict: [String: Any]) {
        if let interval = dict["updateInterval"] as? TimeInterval {
            updateInterval = interval
        }
        if let dock = dict["showInDock"] as? Bool {
            showInDock = dock
        }
        if let menuBar = dict["showInMenuBar"] as? Bool {
            showInMenuBar = menuBar
        }
        if let launch = dict["launchAtLogin"] as? Bool {
            launchAtLogin = launch
        }
        if let icloud = dict["iCloudSyncEnabled"] as? Bool {
            iCloudSyncEnabled = icloud
        }
        if let icloudFolder = dict["iCloudDriveFolderEnabled"] as? Bool {
            iCloudDriveFolderEnabled = icloudFolder
        }
        if let notifications = dict["notificationsEnabled"] as? Bool {
            notificationsEnabled = notifications
        }
        if let lang = dict["language"] as? String {
            language = lang
        }
        if let themeValue = dict["theme"] as? String,
           let appTheme = AppTheme(rawValue: themeValue) {
            theme = appTheme
        }
        if let widgetThemeValue = dict["widgetTheme"] as? String,
           let wt = AppTheme(rawValue: widgetThemeValue) {
            widgetTheme = wt
        }
    }
}

// MARK: - App Theme
public enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    public var displayName: String {
        let localizationManager = LocalizationManager.shared
        switch self {
        case .light:
            return localizationManager.localized("light_mode")
        case .dark:
            return localizationManager.localized("dark_mode")
        case .system:
            return localizationManager.localized("system_mode")
        }
    }
}

// MARK: - Chart Configuration
public struct ChartConfiguration: Codable, Equatable {
    public let showTrendLine: Bool
    public let showDataPoints: Bool
    public let showGrid: Bool
    public let colorScheme: String
    public let chartType: String
    public let timeRange: String
    
    public init(
        showTrendLine: Bool = true,
        showDataPoints: Bool = true,
        showGrid: Bool = true,
        colorScheme: String = "default",
        chartType: String = "line",
        timeRange: String = "1month"
    ) {
        self.showTrendLine = showTrendLine
        self.showDataPoints = showDataPoints
        self.showGrid = showGrid
        self.colorScheme = colorScheme
        self.chartType = chartType
        self.timeRange = timeRange
    }
    
    public static let `default` = ChartConfiguration()
}

// MARK: - Auto Update Frequency
public enum AutoUpdateFrequency: String, CaseIterable {
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    public var displayName: String {
        let localizationManager = LocalizationManager.shared
        switch self {
        case .hourly:
            return localizationManager.localized("hourly")
        case .daily:
            return localizationManager.localized("daily")
        case .weekly:
            return localizationManager.localized("weekly")
        case .monthly:
            return localizationManager.localized("monthly")
        }
    }
    
    public var timeInterval: TimeInterval {
        switch self {
        case .hourly:
            return 3600 // 1小时
        case .daily:
            return 86400 // 24小时
        case .weekly:
            return 604800 // 7天
        case .monthly:
            return 2592000 // 30天
        }
    }
}