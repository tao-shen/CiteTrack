import Cocoa
import Foundation
import ServiceManagement

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
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private let googleScholarService = GoogleScholarService()
    private var updateTimer: Timer?
    
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
    
    @objc private func refreshCitations() {
        var scholars = PreferencesManager.shared.scholars
        
        for (index, scholar) in scholars.enumerated() {
            googleScholarService.fetchCitationCount(for: scholar.id) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let citations):
                        scholars[index].citations = citations
                        scholars[index].lastUpdated = Date()
                        PreferencesManager.shared.scholars = scholars
                        self.updateStatusItemMenu()
                    case .failure(let error):
                        print("获取学者 \(scholar.id) 的引用量失败: \(error.localizedDescription)")
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