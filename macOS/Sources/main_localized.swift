import Cocoa
import Foundation
#if !APP_STORE
import Sparkle
#endif

// MARK: - L() Function for Localization

// MARK: - User Defaults Keys
extension UserDefaults {
    enum Keys {
        static let scholars = "Scholars"
        static let updateInterval = "UpdateInterval"
        static let showInDock = "ShowInDock"
        static let showInMenuBar = "ShowInMenuBar"
        static let launchAtLogin = "LaunchAtLogin"
    }
}

// MARK: - Scholar Model
struct Scholar: Codable, Identifiable {
    let id: String
    var name: String
    var citations: Int?
    var lastUpdated: Date?
    
    init(id: String, name: String = "") {
        self.id = id
        self.name = name.isEmpty ? L("default_scholar_name", String(id.prefix(8))) : name
        self.citations = nil
        self.lastUpdated = nil
    }
}

// MARK: - Google Scholar Service
class GoogleScholarService {
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
        
        if trimmed.contains("scholar.google.com") {
            let patterns = [
                #"user=([A-Za-z0-9_-]+)"#,
                #"citations\?user=([A-Za-z0-9_-]+)"#,
                #"profile/([A-Za-z0-9_-]+)"#
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.count)),
                   let range = Range(match.range(at: 1), in: trimmed) {
                    return String(trimmed[range])
                }
            }
        }
        
        if trimmed.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil {
            return trimmed
        }
        
        return nil
    }
    
    func fetchScholarInfo(for scholarId: String, completion: @escaping (Result<(name: String, citations: Int), ScholarError>) -> Void) {
        let urlString = "https://scholar.google.com/citations?user=\(scholarId)&hl=en"
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
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
        }
    }
    
    func updateScholar(withId id: String, citations: Int) {
        var scholars = self.scholars
        if let index = scholars.firstIndex(where: { $0.id == id }) {
            scholars[index].citations = citations
            scholars[index].lastUpdated = Date()
            self.scholars = scholars
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private let googleScholarService = GoogleScholarService()
    private var updateTimer: Timer?
    
    // Sparkle自动更新
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusItem()
        updateAppearance()
        startPeriodicUpdates()
        
        // 监听语言变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: .languageChanged,
            object: nil
        )
        
        // 监听学者数据更新
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scholarsDataUpdated),
            name: .scholarsDataUpdated,
            object: nil
        )
        
        // 检查是否是首次启动
        if PreferencesManager.shared.scholars.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showWelcomeDialog()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func languageChanged() {
        updateStatusItemMenu()
    }
    
    @objc private func scholarsDataUpdated() {
        updateStatusItemMenu()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "∞"
            button.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
            button.toolTip = L("tooltip_citetrack")
        }
        
        updateStatusItemMenu()
    }
    
    private func updateStatusItemMenu() {
        let menu = NSMenu()
        
        let scholars = PreferencesManager.shared.scholars
        
        if scholars.isEmpty {
            let noScholarsItem = NSMenuItem(title: L("menu_no_scholars"), action: nil, keyEquivalent: "")
            noScholarsItem.isEnabled = false
            menu.addItem(noScholarsItem)
        } else {
            for scholar in scholars {
                let title: String
                if let citations = scholar.citations {
                    title = "\(scholar.name): \(citations)"
                } else {
                    title = "\(scholar.name): -"
                }
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                menu.addItem(item)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let refreshItem = NSMenuItem(title: L("menu_manual_update"), action: #selector(refreshCitations), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        let settingsItem = NSMenuItem(title: L("menu_preferences"), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let checkForUpdatesItem = NSMenuItem(title: L("menu_check_updates"), action: #selector(checkForUpdates), keyEquivalent: "")
        checkForUpdatesItem.target = self
        menu.addItem(checkForUpdatesItem)
        
        let aboutItem = NSMenuItem(title: L("menu_about"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let quitItem = NSMenuItem(title: L("menu_quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    func updateAppearance() {
        let showInDock = PreferencesManager.shared.showInDock
        let showInMenuBar = PreferencesManager.shared.showInMenuBar
        
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        statusItem?.isVisible = showInMenuBar
    }
    
    private func showWelcomeDialog() {
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.messageText = L("welcome_title")
        alert.informativeText = L("welcome_message")
        alert.addButton(withTitle: L("button_open_settings"))
        alert.addButton(withTitle: L("button_later"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            showSettings()
        }
    }
    
    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(window: nil)
        }
        
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = L("app_name")
        alert.informativeText = L("app_about")
        alert.runModal()
    }
    
    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    
    @objc private func refreshCitations() {
        let scholars = PreferencesManager.shared.scholars
        guard !scholars.isEmpty else { return }
        
        // 创建并显示进度窗口
        let progressWindow = createProgressWindow(totalCount: scholars.count)
        progressWindow.makeKeyAndOrderFront(nil)
        
        var completedCount = 0
        var successCount = 0
        let totalCount = scholars.count
        
        for (_, scholar) in scholars.enumerated() {
            googleScholarService.fetchCitationCount(for: scholar.id) { result in
                DispatchQueue.main.async {
                    completedCount += 1
                    
                    switch result {
                    case .success(let citations):
                        successCount += 1
                        PreferencesManager.shared.updateScholar(withId: scholar.id, citations: citations)
                        
                    case .failure(let error):
                        print("Failed to update scholar \(scholar.id): \(error)")
                    }
                    
                    // 更新进度窗口
                    self.updateProgressWindow(progressWindow, completed: completedCount, total: totalCount, success: successCount)
                    
                    // 检查是否完成
                    if completedCount == totalCount {
                        // 发送数据更新通知
                        NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
                        
                        // 显示完成状态并添加优雅的淡出动画
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.showCompletionAndCloseWindow(progressWindow, success: successCount, total: totalCount)
                        }
                    }
                }
            }
        }
    }
    
    private func createProgressWindow(totalCount: Int) -> NSWindow {
        let progressWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
            styleMask: .borderless,  // 无边框
            backing: .buffered,
            defer: false
        )
        progressWindow.level = .floating
        progressWindow.collectionBehavior = [.fullScreenAuxiliary]
        progressWindow.isOpaque = false
        progressWindow.backgroundColor = .clear
        progressWindow.hasShadow = true
        progressWindow.ignoresMouseEvents = false  // 允许鼠标事件以便显示阴影效果
        
        // 居中显示，但稍微偏上一些
        progressWindow.center()
        var frame = progressWindow.frame
        frame.origin.y += 100  // 往上偏移一些
        progressWindow.setFrame(frame, display: true)
        
        // 创建主容器视图
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 80))
        containerView.wantsLayer = true
        
        // 设置现代化的外观
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.blended(withFraction: 0.95, of: .white)?.cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        // 添加阴影
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOpacity = 0.2
        containerView.layer?.shadowOffset = NSSize(width: 0, height: -2)
        containerView.layer?.shadowRadius = 8
        
        // 创建图标
        let iconView = NSImageView(frame: NSRect(x: 15, y: 35, width: 24, height: 24))
        if #available(macOS 11.0, *) {
            iconView.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
            iconView.contentTintColor = .systemBlue
        } else {
            // 为较老的macOS版本创建简单的文本标签
            iconView.isHidden = true
        }
        containerView.addSubview(iconView)
        
        // 创建状态标签
        let statusLabel = NSTextField(frame: NSRect(x: 50, y: 45, width: 200, height: 20))
        statusLabel.stringValue = L("status_updating_progress", 0, totalCount)
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .labelColor
        
        // 为老版本macOS调整位置（因为没有图标）
        if #unavailable(macOS 11.0) {
            statusLabel.frame = NSRect(x: 20, y: 45, width: 240, height: 20)
        }
        
        containerView.addSubview(statusLabel)
        
        // 创建进度条
        let progressIndicator = NSProgressIndicator(frame: NSRect(x: 50, y: 20, width: 200, height: 8))
        progressIndicator.style = .bar
        progressIndicator.minValue = 0
        progressIndicator.maxValue = Double(totalCount)
        progressIndicator.doubleValue = 0
        progressIndicator.isIndeterminate = false
        progressIndicator.controlSize = .small
        progressIndicator.wantsLayer = true
        progressIndicator.layer?.cornerRadius = 4
        containerView.addSubview(progressIndicator)
        
        progressWindow.contentView = containerView
        
        // 添加淡入动画
        progressWindow.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            progressWindow.animator().alphaValue = 1.0
        }
        
        return progressWindow
    }
    
    private func updateProgressWindow(_ window: NSWindow, completed: Int, total: Int, success: Int) {
        DispatchQueue.main.async {
            guard let contentView = window.contentView else { return }
            
            for subview in contentView.subviews {
                if subview is NSProgressIndicator {
                    let progressIndicator = subview as! NSProgressIndicator
                    progressIndicator.maxValue = Double(total)
                    progressIndicator.doubleValue = Double(completed)
                } else if subview is NSTextField {
                    let statusLabel = subview as! NSTextField
                    statusLabel.stringValue = L("status_updating_progress", completed, total)
                }
            }
        }
    }
    
    private func showCompletionAndCloseWindow(_ window: NSWindow, success: Int, total: Int) {
        // 首先更新进度窗口显示完成状态
        updateProgressWindowToComplete(window, success: success, total: total)
        
        DispatchQueue.main.async {
            // 更新菜单栏按钮标题来显示反馈
            if let button = self.statusItem?.button {
                if success == total {
                    button.title = "✓"
                    // 2秒后恢复正常显示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        button.title = "∞"
                    }
                } else {
                    button.title = "⚠️"
                    // 3秒后恢复正常显示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        button.title = "∞"
                    }
                }
            }
            
            // 更新菜单内容
            self.updateStatusItemMenu()
            
            // 如果有失败的，显示详细信息
            if success < total {
                let failedCount = total - success
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let alert = NSAlert()
                    alert.messageText = L("update_completed")
                    alert.informativeText = L("update_result_message", success, total, failedCount)
                    alert.alertStyle = success > 0 ? .warning : .critical
                    alert.runModal()
                }
            }
            
            // 延迟1.5秒后添加优雅的淡出动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    window.animator().alphaValue = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    window.orderOut(nil)
                }
            }
        }
    }
    
    private func updateProgressWindowToComplete(_ window: NSWindow, success: Int, total: Int) {
        DispatchQueue.main.async {
            guard let contentView = window.contentView else { return }
            
            for subview in contentView.subviews {
                if subview is NSProgressIndicator {
                    let progressIndicator = subview as! NSProgressIndicator
                    progressIndicator.doubleValue = Double(total) // 完整进度条
                } else if subview is NSTextField {
                    let statusLabel = subview as! NSTextField
                    if success == total {
                        statusLabel.stringValue = L("update_completed") + " ✓"
                        statusLabel.textColor = .systemGreen
                    } else {
                        statusLabel.stringValue = L("update_completed") + " ⚠️"
                        statusLabel.textColor = .systemOrange
                    }
                } else if subview is NSImageView {
                    let iconView = subview as! NSImageView
                    if #available(macOS 11.0, *) {
                        if success == total {
                            iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
                            iconView.contentTintColor = .systemGreen
                        } else {
                            iconView.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
                            iconView.contentTintColor = .systemOrange
                        }
                    } else {
                        // 对于较老的macOS版本，隐藏图标
                        iconView.isHidden = true
                    }
                }
            }
        }
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
    
    private func startPeriodicUpdates() {
        updateTimer?.invalidate()
        
        let interval = PreferencesManager.shared.updateInterval
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.refreshCitations()
        }
    }
}

// Settings window is now in separate file

// MARK: - Main
@main
struct CiteTrackApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
} 