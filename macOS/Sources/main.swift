import Cocoa
import Foundation
import ServiceManagement
#if !APP_STORE
import Sparkle
#endif

// MARK: - User Defaults Keys
extension UserDefaults {
    enum Keys {
        static let scholars = "Scholars"
        static let updateInterval = "UpdateInterval"
        static let showInDock = "ShowInDock"
        static let showInMenuBar = "ShowInMenuBar"
        static let launchAtLogin = "LaunchAtLogin"
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
    }
}



// MARK: - Scholar Model
public struct Scholar: Codable, Identifiable {
    public let id: String
    public var name: String
    public var citations: Int?
    public var lastUpdated: Date?
    
    public init(id: String, name: String = "") {
        self.id = id
        self.name = name.isEmpty ? L("default_scholar_name", String(id.prefix(8))) : name
        self.citations = nil
        self.lastUpdated = nil
    }
}

// MARK: - Google Scholar Service
class GoogleScholarService {
    // 共享的URLSession配置，包含合理的超时设置
    private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0  // 单个请求超时30秒
        config.timeoutIntervalForResource = 60.0  // 总资源获取超时60秒
        config.allowsCellularAccess = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData  // 总是获取最新数据
        return URLSession(configuration: config)
    }()
    enum ScholarError: Error, LocalizedError {
        case invalidURL
        case noData
        case parsingError
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return L("error_invalid_url")
            case .noData:
                return L("error_no_data")
            case .parsingError:
                return L("error_parsing_error")
            case .networkError(let error):
                return L("error_network_error", error.localizedDescription)
            }
        }
    }
    
    static func extractScholarId(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 验证输入不为空
        guard !trimmed.isEmpty else {
            print("⚠️ Scholar ID 输入为空")
            return nil
        }
        
        // 验证输入长度（Google Scholar ID通常为8-20个字符）
        guard trimmed.count >= 8 && trimmed.count <= 100 else {
            print("⚠️ Scholar ID 长度无效: \(trimmed.count) 字符")
            return nil
        }
        
        if trimmed.contains("scholar.google.com") {
            let patterns = [
                #"user=([A-Za-z0-9_-]{8,20})"#,  // 更严格的长度验证
                #"citations\?user=([A-Za-z0-9_-]{8,20})"#,
                #"profile/([A-Za-z0-9_-]{8,20})"#
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.count)),
                   let range = Range(match.range(at: 1), in: trimmed) {
                    let extractedId = String(trimmed[range])
                    
                    // 验证提取的ID
                    if isValidScholarId(extractedId) {
                        print("✅ 从URL提取到有效的Scholar ID: \(extractedId)")
                        return extractedId
                    }
                }
            }
            
            print("❌ 无法从URL中提取有效的Scholar ID")
            return nil
        }
        
        // 如果是直接的ID，进行验证
        if isValidScholarId(trimmed) {
            print("✅ 直接输入的Scholar ID有效: \(trimmed)")
            return trimmed
        }
        
        print("❌ 无效的Scholar ID格式: \(trimmed)")
        return nil
    }
    
    /// 验证Scholar ID是否有效
    private static func isValidScholarId(_ id: String) -> Bool {
        // 基本格式验证：只包含字母、数字、下划线和短横线
        guard id.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
            print("⚠️ Scholar ID 包含无效字符: \(id)")
            return false
        }
        
        // 长度验证：Google Scholar ID 通常是8-20个字符
        guard id.count >= 8 && id.count <= 20 else {
            print("⚠️ Scholar ID 长度无效: \(id.count) 字符 (应为8-20)")
            return false
        }
        
        // 确保不是纯数字或纯特殊字符
        let hasLetter = id.range(of: "[A-Za-z]", options: .regularExpression) != nil
        let hasNumber = id.range(of: "[0-9]", options: .regularExpression) != nil
        
        guard hasLetter || hasNumber else {
            print("⚠️ Scholar ID 应包含字母或数字")
            return false
        }
        
        // 检查是否以特殊字符开头或结尾
        guard !id.hasPrefix("_") && !id.hasPrefix("-") && 
              !id.hasSuffix("_") && !id.hasSuffix("-") else {
            print("⚠️ Scholar ID 不应以特殊字符开头或结尾")
            return false
        }
        
        return true
    }
    
    func fetchScholarInfo(for scholarId: String, completion: @escaping (Result<(name: String, citations: Int), ScholarError>) -> Void) {
        let urlString = "https://scholar.google.com/citations?user=\(scholarId)&hl=en"
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        // 使用共享的URLSession进行请求
        GoogleScholarService.urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                // 检查是否是超时错误
                if (error as NSError).code == NSURLErrorTimedOut {
                    print("⏰ Google Scholar请求超时: \(scholarId)")
                    completion(.failure(.networkError(NSError(domain: "GoogleScholarService", code: -1001, userInfo: [NSLocalizedDescriptionKey: L("network_timeout_message")]))))
                } else {
                    completion(.failure(.networkError(error)))
                }
                return
            }
            
            // 检查HTTP响应状态码
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 429 {
                    print("🚦 Google Scholar访问频率限制: \(scholarId)")
                    completion(.failure(.networkError(NSError(domain: "GoogleScholarService", code: 429, userInfo: [NSLocalizedDescriptionKey: L("rate_limit_message")]))))
                    return
                } else if httpResponse.statusCode >= 400 {
                    print("❌ HTTP错误 \(httpResponse.statusCode): \(scholarId)")
                    completion(.failure(.networkError(NSError(domain: "GoogleScholarService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: L("server_error_message", httpResponse.statusCode)]))))
                    return
                }
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            self.parseScholarInfo(from: data, completion: completion)
        }.resume()
    }
    
    func fetchCitationCount(for scholarId: String, completion: @escaping (Result<Int, ScholarError>) -> Void) {
        fetchScholarInfo(for: scholarId) { result in
            switch result {
            case .success(let info):
                completion(.success(info.citations))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func parseScholarInfo(from data: Data, completion: @escaping (Result<(name: String, citations: Int), ScholarError>) -> Void) {
        guard let htmlString = String(data: data, encoding: .utf8) else {
            completion(.failure(.parsingError))
            return
        }
        
        // 解析学者姓名
        var scholarName = ""
        let namePatterns = [
            #"<div id="gsc_prf_in">([^<]+)</div>"#,
            #"<span id="gsc_prf_in">([^<]+)</span>"#,
            #"class="gsc_prf_in">([^<]+)<"#
        ]
        
        for pattern in namePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: htmlString, options: [], range: NSRange(location: 0, length: htmlString.count)),
               let range = Range(match.range(at: 1), in: htmlString) {
                scholarName = String(htmlString[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        // 解析引用量
        let citationPatterns = [
            #"Citations</a></td><td class="gsc_rsb_std">(\d+)</td>"#,
            #"Citations</a><td class="gsc_rsb_std">(\d+)</td>"#,
            #"总引用次数</a></td><td class="gsc_rsb_std">(\d+)</td>"#,
            #"被引次数</td><td[^>]*>(\d+)</td>"#,
            #"gsc_rsb_std">(\d+)</td>"#,
        ]
        
        for pattern in citationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: htmlString, options: [], range: NSRange(location: 0, length: htmlString.count)),
               let range = Range(match.range(at: 1), in: htmlString) {
                let citationString = String(htmlString[range])
                if let count = Int(citationString) {
                    let finalName = scholarName.isEmpty ? L("unknown_scholar") : scholarName
                    completion(.success((name: finalName, citations: count)))
                    return
                }
            }
        }
        
        completion(.failure(.parsingError))
    }
}

// MARK: - Preferences Manager
class PreferencesManager {
    static let shared = PreferencesManager()
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    var scholars: [Scholar] {
        get {
            guard let data = userDefaults.data(forKey: UserDefaults.Keys.scholars),
                  let scholars = try? JSONDecoder().decode([Scholar].self, from: data) else {
                return []
            }
            return scholars
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: UserDefaults.Keys.scholars)
            }
        }
    }
    
    var updateInterval: TimeInterval {
        get {
            let interval = userDefaults.double(forKey: UserDefaults.Keys.updateInterval)
            return interval > 0 ? interval : 86400 // 默认1天
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaults.Keys.updateInterval)
        }
    }
    
    var showInDock: Bool {
        get {
            if userDefaults.object(forKey: UserDefaults.Keys.showInDock) == nil {
                return true
            }
            return userDefaults.bool(forKey: UserDefaults.Keys.showInDock)
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaults.Keys.showInDock)
            updateActivationPolicy()
        }
    }
    
    var showInMenuBar: Bool {
        get {
            if userDefaults.object(forKey: UserDefaults.Keys.showInMenuBar) == nil {
                return true
            }
            return userDefaults.bool(forKey: UserDefaults.Keys.showInMenuBar)
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaults.Keys.showInMenuBar)
        }
    }
    
    var launchAtLogin: Bool {
        get {
            return userDefaults.bool(forKey: UserDefaults.Keys.launchAtLogin)
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaults.Keys.launchAtLogin)
            configureLaunchAtLogin(newValue)
        }
    }
    
    var iCloudSyncEnabled: Bool {
        get {
            return userDefaults.bool(forKey: UserDefaults.Keys.iCloudSyncEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaults.Keys.iCloudSyncEnabled)
            if newValue {
                // Enable iCloud sync
                iCloudSyncManager.shared.enableAutoSync()
            } else {
                // Disable iCloud sync
                iCloudSyncManager.shared.disableAutoSync()
            }
        }
    }
    
    private func updateActivationPolicy() {
        DispatchQueue.main.async(qos: .userInitiated) {
            if self.showInDock {
                NSApp.setActivationPolicy(.regular)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    private func configureLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            if enabled {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }
    
    func addScholar(_ scholar: Scholar) {
        var currentScholars = scholars
        if !currentScholars.contains(where: { $0.id == scholar.id }) {
            currentScholars.append(scholar)
            scholars = currentScholars
        }
    }
    
    func removeScholar(withId id: String) {
        var currentScholars = scholars
        currentScholars.removeAll { $0.id == id }
        scholars = currentScholars
    }
    
    func updateScholar(withId id: String, name: String? = nil, citations: Int? = nil) {
        var currentScholars = scholars
        if let index = currentScholars.firstIndex(where: { $0.id == id }) {
            let oldCitations = currentScholars[index].citations
            
            if let name = name {
                currentScholars[index].name = name
            }
            if let citations = citations {
                currentScholars[index].citations = citations
                currentScholars[index].lastUpdated = Date()
                
                // 保存历史数据到 Core Data (只有数据变化时才保存)
                let historyManager = CitationHistoryManager.shared
                historyManager.saveHistoryIfChanged(scholarId: id, citationCount: citations) { saved in
                    if saved {
                        print("✅ Citation data changed for scholar \(id): \(citations) citations - saved to history (updateScholar)")
                    } else {
                        print("ℹ️ Citation data unchanged for scholar \(id): \(citations) citations - not saved (updateScholar)")
                    }
                }
                
                // 如果引用数有变化，发送通知
                if citations != oldCitations {
                    NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
                }
            }
            scholars = currentScholars
        }
    }
}

// Note: SettingsWindowController and EditableTextField are now defined in SettingsWindow.swift

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarItem: NSStatusItem!
    private var menu: NSMenu!
    private var timer: Timer?
    private let scholarService = GoogleScholarService()
    private var settingsWindowController: SettingsWindowController?
    private var chartsWindowController: NSWindowController?
    private var scholars: [Scholar] = []
    private var currentCitations: [String: Int] = [:]
    private let backgroundDataService = BackgroundDataCollectionService.shared
    private var isUpdating = false
    
    // Sparkle updater (disabled for development)
    // #if !APP_STORE
    // private var updaterController: SPUStandardUpdaterController!
    // #endif
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 首先设置应用为常规模式，确保显示在 Dock 中
        NSApp.setActivationPolicy(.regular)
        
        // Initialize Sparkle updater (disabled for development)
        // #if !APP_STORE
        // setupSparkleUpdater()
        // #endif
        
        // Initialize Core Data stack
        initializeCoreData()
        
        // Only check iCloud if sync is enabled
        if PreferencesManager.shared.iCloudSyncEnabled {
            print("🚀 [App Startup] iCloud sync enabled, checking status...")
            let status = iCloudSyncManager.shared.getFileStatus()
            print("📋 [iCloud Status] \(status.description)")
        } else {
            print("🚀 [App Startup] iCloud sync disabled, skipping check")
        }
        
        updateActivationPolicy()
        setupNotifications()
        setupStatusBar()
        setupMenu()
        loadScholars()
        
        // 确保应用激活到前台
        NSApp.activate(ignoringOtherApps: true)
        
        if scholars.isEmpty {
            // 延迟一点显示首次设置，确保应用完全启动
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showFirstTimeSetup()
            }
        } else {
            backgroundDataService.startAutomaticCollection()
        }
    }
    
    // #if !APP_STORE
    // private func setupSparkleUpdater() {
    //     updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    // }
    // #endif
    
    private func initializeCoreData() {
        // Perform migration check
        CoreDataManager.shared.performMigrationIfNeeded()
        
        // Initialize the persistent container
        _ = CoreDataManager.shared.persistentContainer
        
        // Schedule maintenance tasks
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 30) {
            CoreDataManager.shared.performMaintenanceTasks()
        }
        
        // Listen for Core Data errors
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoreDataError(_:)),
            name: .coreDataError,
            object: nil
        )
    }
    
    @objc private func handleCoreDataError(_ notification: Notification) {
        guard let error = notification.userInfo?["error"] as? NSError else { return }
        
        DispatchQueue.main.async(qos: .userInitiated) {
            let alert = NSAlert()
            alert.messageText = L("error_database_title")
            alert.informativeText = L("error_database_message", error.localizedDescription)
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("button_ok"))
            alert.runModal()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Save Core Data context before terminating
        CoreDataManager.shared.saveContext()
        
        // Stop background data collection
        backgroundDataService.stopAutomaticCollection()
        
        // 清理定时器
        timer?.invalidate()
        timer = nil
        
        // 清理通知观察者
        NotificationCenter.default.removeObserver(self)
        
        // 清理设置窗口
        settingsWindowController?.window?.close()
        settingsWindowController = nil
        
        // 清理状态栏项
        if let statusBarItem = statusBarItem {
            NSStatusBar.system.removeStatusItem(statusBarItem)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 对于菜单栏应用，即使关闭所有窗口也不应该退出
        return false
    }
    
    private func updateActivationPolicy() {
        if PreferencesManager.shared.showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scholarsUpdated),
            name: NSNotification.Name("ScholarsUpdated"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateIntervalChanged),
            name: NSNotification.Name("UpdateIntervalChanged"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarVisibilityChanged),
            name: NSNotification.Name("MenuBarVisibilityChanged"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: .languageChanged,
            object: nil
        )
    }
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarDisplay()
    }
    
    private func updateMenuBarDisplay() {
        if !PreferencesManager.shared.showInMenuBar {
            statusBarItem.isVisible = false
            return
        }
        
        statusBarItem.isVisible = true
        
        if let button = statusBarItem.button {
            button.image = nil
            button.imagePosition = .noImage
            button.toolTip = L("tooltip_citetrack")
            button.title = "∞"
            button.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        }
    }
    
    private func updateMenuBarTitle(_ title: String) {
        // 确保在主线程执行UI更新
        assert(Thread.isMainThread, "updateMenuBarTitle() must be called on the main thread")
        
        if let button = statusBarItem.button {
            button.title = title
        }
    }
    
    private func setupMenu() {
        menu = NSMenu()
        statusBarItem.menu = menu
        rebuildMenu()
    }
    
    private func rebuildMenu() {
        // 确保在主线程执行UI更新
        assert(Thread.isMainThread, "rebuildMenu() must be called on the main thread")
        
        menu.removeAllItems()
        
        let titleItem = NSMenuItem(title: L("app_name"), action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        if isUpdating {
            // 显示更新中状态
            let updatingItem = NSMenuItem(title: L("status_updating"), action: nil, keyEquivalent: "")
            updatingItem.isEnabled = false
            menu.addItem(updatingItem)
        } else if scholars.isEmpty {
            let noScholarsItem = NSMenuItem(title: L("menu_no_scholars"), action: nil, keyEquivalent: "")
            noScholarsItem.isEnabled = false
            menu.addItem(noScholarsItem)
        } else {
            for scholar in scholars {
                let citationText = currentCitations[scholar.id].map { "\($0)" } ?? "--"
                let title = "\(scholar.name): \(citationText)"
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let refreshItem = NSMenuItem(title: L("menu_manual_update"), action: #selector(refreshCitations), keyEquivalent: "r")
        refreshItem.target = self
        if #available(macOS 11.0, *) {
            refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        }
        menu.addItem(refreshItem)
        
        let settingsItem = NSMenuItem(title: L("menu_preferences"), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        if #available(macOS 11.0, *) {
            settingsItem.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
        }
        menu.addItem(settingsItem)
        
        let chartsItem = NSMenuItem(title: L("menu_charts"), action: #selector(showCharts), keyEquivalent: "")
        chartsItem.target = self
        if #available(macOS 11.0, *) {
            chartsItem.image = NSImage(systemSymbolName: "rectangle.grid.2x2", accessibilityDescription: nil)
        }
        menu.addItem(chartsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let checkForUpdatesItem = NSMenuItem(title: L("menu_check_updates"), action: #selector(checkForUpdates), keyEquivalent: "")
        checkForUpdatesItem.target = self
        if #available(macOS 11.0, *) {
            checkForUpdatesItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        }
        menu.addItem(checkForUpdatesItem)
        
        let aboutItem = NSMenuItem(title: L("menu_about"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        if #available(macOS 11.0, *) {
            aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        }
        menu.addItem(aboutItem)
        
        let quitItem = NSMenuItem(title: L("menu_quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        if #available(macOS 11.0, *) {
            quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        }
        menu.addItem(quitItem)
    }
    
    private func loadScholars() {
        scholars = PreferencesManager.shared.scholars
        // 更新当前引用量缓存
        for scholar in scholars {
            if let citations = scholar.citations {
                currentCitations[scholar.id] = citations
            }
        }
        rebuildMenu()
    }
    
    private func showFirstTimeSetup() {
        // 延迟显示首次设置，确保应用完全启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 确保应用在前台
            NSApp.activate(ignoringOtherApps: true)
            
            let alert = NSAlert()
            alert.messageText = L("welcome_title")
            alert.informativeText = L("welcome_message")
            alert.addButton(withTitle: L("button_open_settings"))
            alert.addButton(withTitle: L("button_later"))
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.showSettings()
            }
        }
    }
    
    private func startPeriodicUpdate() {
        // Use the new background data collection service
        backgroundDataService.startAutomaticCollection()
    }
    
    @objc private func refreshCitations() {
        guard !scholars.isEmpty else {
            let alert = NSAlert()
            alert.messageText = L("menu_no_scholars")
            alert.informativeText = L("error_no_scholars_for_charts_message")
            alert.runModal()
            return
        }
        
        // 设置更新状态
        isUpdating = true
        
        // 显示更新中状态
        updateMenuBarTitle("⋯")
        rebuildMenu() // 重建菜单以显示updating状态
        
        // 使用同步队列保护共享变量
        let updateQueue = DispatchQueue(label: "com.citetrack.citationupdate", attributes: .concurrent)
        var updatedCount = 0
        let totalCount = scholars.count
        var hasChanges = false
        var changeDetails: [String] = []
        
        let group = DispatchGroup()
        
        for scholar in scholars {
            group.enter()
            let oldCitations = currentCitations[scholar.id] ?? 0
            
            scholarService.fetchScholarInfo(for: scholar.id) { [weak self] result in
                DispatchQueue.main.async(qos: .userInitiated) {
                    // 使用 weak-strong dance 模式
                    guard let strongSelf = self else { 
                        group.leave()
                        return 
                    }
                    
                    defer { group.leave() }
                    
                    switch result {
                    case .success(let info):
                        // 使用 barrier 确保线程安全的更新
                        updateQueue.async(flags: .barrier) {
                            updatedCount += 1
                            let newCitations = info.citations
                            let change = newCitations - oldCitations
                            
                            // 记录变化
                            if change != 0 {
                                hasChanges = true
                                let changeText = change > 0 ? "+\(change)" : "\(change)"
                                changeDetails.append("\(scholar.name): \(oldCitations) → \(newCitations) (\(changeText))")
                            }
                            
                            DispatchQueue.main.async(qos: .userInitiated) {
                                // 更新数据 (在主线程执行)
                                strongSelf.currentCitations[scholar.id] = newCitations
                                PreferencesManager.shared.updateScholar(withId: scholar.id, name: info.name, citations: newCitations)
                                
                                // 实时更新菜单显示
                                strongSelf.rebuildMenu()
                            }
                        }
                        
                    case .failure(let error):
                        print("更新学者 \(scholar.name) 失败: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // 等待所有请求完成
        group.notify(queue: .main) { [weak self] in
            guard let strongSelf = self else { return }
            
            // 重置更新状态
            strongSelf.isUpdating = false
            
            // 根据更新结果显示不同状态
            if updatedCount == totalCount {
                // 全部成功
                strongSelf.updateMenuBarTitle("✓")
                // 2秒后恢复正常显示
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.updateMenuBarTitle("∞")
                    strongSelf.rebuildMenu() // 恢复正常菜单显示
                }
            } else {
                // 有失败的情况
                strongSelf.updateMenuBarTitle("⚠️")
                // 3秒后恢复正常显示
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.updateMenuBarTitle("∞")
                    strongSelf.rebuildMenu() // 恢复正常菜单显示
                }
            }
            
            // 立即重建菜单以显示更新后的数据
            strongSelf.rebuildMenu()
            
            // 显示更新结果
            let alert = NSAlert()
            alert.messageText = L("update_completed")
            
            if hasChanges {
                alert.informativeText = L("update_result_with_changes", updatedCount, totalCount) + "\n\n" + L("change_details") + ":\n" + changeDetails.joined(separator: "\n")
                alert.alertStyle = .informational
            } else {
                alert.informativeText = L("update_result_no_changes", updatedCount, totalCount)
                alert.alertStyle = .informational
            }
            
            alert.runModal()
            
            // 通知其他组件数据已更新
            NotificationCenter.default.post(name: NSNotification.Name("ScholarsUpdated"), object: nil)
        }
    }
    
    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.loadWindow()
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showCharts() {
        print("AppDelegate: showCharts() called")
        
        // 防止多次调用导致的崩溃：如果窗口已存在，直接返回
        if let existingController = chartsWindowController,
           let existingWindow = existingController.window {
            print("AppDelegate: Charts window already exists, bringing to front")
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Ensure Core Data is initialized first
        let _ = CoreDataManager.shared.viewContext
        print("AppDelegate: Core Data is available")
        
        // Check if we have any scholars before showing charts
        if scholars.isEmpty {
            print("AppDelegate: No scholars available, showing alert")
            let alert = NSAlert()
            alert.messageText = L("error_no_scholars_for_charts")
            alert.informativeText = L("error_no_scholars_for_charts_message")
            alert.addButton(withTitle: L("button_open_settings"))
            alert.addButton(withTitle: L("button_cancel"))
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                showSettings()
            }
            return
        }
        
        print("AppDelegate: Attempting to create modern charts window controller")

        if let modernController = instantiateModernChartsWindowController() {
            chartsWindowController = modernController
            print("AppDelegate: Modern charts window controller created successfully")
        } else {
            print("AppDelegate: Falling back to legacy ChartsWindowController")
            chartsWindowController = ChartsWindowController()
        }

        guard chartsWindowController != nil else {
            print("AppDelegate: ERROR - Failed to create charts window controller")
            let alert = NSAlert()
            alert.messageText = L("charts_error_title")
            alert.informativeText = L("charts_error_message")
            alert.alertStyle = .critical
            alert.runModal()
            return
        }
        
        print("AppDelegate: Showing charts window...")
        chartsWindowController?.showWindow(self)

        if chartsWindowController is ChartsWindowController {
            chartsWindowController?.window?.delegate = self
        }
        print("AppDelegate: Charts window shown successfully")
    }
    
    // Called when charts window is closed
    func chartsWindowDidClose() {
        print("AppDelegate: Charts window closed, clearing reference")
        chartsWindowController = nil
    }
    
    @objc private func checkForUpdates() {
        // #if !APP_STORE
        // updaterController.checkForUpdates(nil)
        // #else
        // App Store 版本不支持内置更新（通过 App Store 更新）
        let alert = NSAlert()
        alert.messageText = L("menu_check_updates")
        alert.informativeText = L("please_update_from_app_store")
        alert.runModal()
        // #endif
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = L("app_name")
        alert.informativeText = L("app_about")
        alert.runModal()
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func scholarsUpdated() {
        // 确保UI和数据更新在主线程执行
        DispatchQueue.main.async(qos: .userInitiated) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.loadScholars()
            if !strongSelf.scholars.isEmpty {
                strongSelf.backgroundDataService.restartAutomaticCollection()
            }
        }
    }
    
    @objc private func updateIntervalChanged() {
        backgroundDataService.restartAutomaticCollection()
    }
    
    @objc private func menuBarVisibilityChanged() {
        updateMenuBarDisplay()
        updateActivationPolicy()
    }
    
    @objc private func languageChanged() {
        // 确保UI更新在主线程执行
        DispatchQueue.main.async(qos: .userInitiated) { [weak self] in
            guard let strongSelf = self else { return }
            // 重新构建菜单以更新所有文本
            strongSelf.rebuildMenu()
        }
    }
    
    private func updateAllCitations() {
        guard !scholars.isEmpty else {
            rebuildMenu()
            return
        }
        
        // Use the new background data collection service for manual updates
        backgroundDataService.performManualCollection { [weak self] result in
            DispatchQueue.main.async(qos: .userInitiated) {
                guard let self = self else { return }
                switch result {
                case .success(let results):
                    self.currentCitations = results
                    self.rebuildMenu()
                case .failure(let error):
                    print("更新所有学者引用量失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updateCitation(for scholar: Scholar) {
        // Use the new service with automatic history saving
        scholarService.fetchAndSaveCitationCount(for: scholar.id) { [weak self] result in
            DispatchQueue.main.async(qos: .userInitiated) {
                guard let self = self else { return }
                switch result {
                case .success(let count):
                    self.currentCitations[scholar.id] = count
                    PreferencesManager.shared.updateScholar(withId: scholar.id, citations: count)
                    self.rebuildMenu()
                case .failure(let error):
                    print("获取学者 \(scholar.id) 的引用量失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow,
           window == chartsWindowController?.window {
            chartsWindowDidClose()
        }
    }
}

// MARK: - Modern Charts Factory
private extension AppDelegate {
    func instantiateModernChartsWindowController() -> NSWindowController? {
        let moduleName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
        let candidates = [
            "\(moduleName).ModernChartsWindowController",
            "ModernChartsWindowController"
        ]
        for name in candidates {
            if let modernType = NSClassFromString(name) as? NSWindowController.Type {
                let controller = modernType.init(window: nil)
                return controller
            }
        }
        return nil
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
