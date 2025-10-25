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
        self.name = name.isEmpty ? "学者 \(id.prefix(8))" : name
        self.citations = nil
        self.lastUpdated = nil
    }
}

// MARK: - Google Scholar Service
class GoogleScholarService {
    private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.allowsCellularAccess = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
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
                return "Invalid Scholar ID"
            case .noData:
                return "No data received"
            case .parsingError:
                return "Failed to parse citation count"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    static func extractScholarId(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it's already just an ID
        if trimmed.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil {
            return trimmed
        }
        
        // Extract from URL
        let patterns = [
            "user=([a-zA-Z0-9_-]+)",
            "citations\\?user=([a-zA-Z0-9_-]+)",
            "/citations/([a-zA-Z0-9_-]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: trimmed) {
                return String(trimmed[range])
            }
        }
        
        return nil
    }
    
    static func fetchCitations(for scholarId: String) async throws -> Int {
        let urlString = "https://scholar.google.com/citations?user=\(scholarId)"
        guard let url = URL(string: urlString) else {
            throw ScholarError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await urlSession.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                throw ScholarError.noData
            }
            
            let citationCount = try parseCitationCount(from: html)
            return citationCount
        } catch {
            throw ScholarError.networkError(error)
        }
    }
    
    private static func parseCitationCount(from html: String) throws -> Int {
        let patterns = [
            #"<td class="gsc_rsb_std">(\d+)</td>"#,
            #"Citations</a></td><td class="gsc_rsb_std">(\d+)</td>"#,
            #">Citations<[^>]*></[^>]*><[^>]*>(\d+)<"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: html),
                   let count = Int(String(html[swiftRange])) {
                    return count
                }
            }
        }
        
        throw ScholarError.parsingError
    }
}

// MARK: - Data Manager
class DataManager: ObservableObject {
    @Published var scholars: [Scholar] = []
    private let updateInterval: TimeInterval
    private var updateTimer: Timer?
    
    init() {
        self.updateInterval = TimeInterval(UserDefaults.standard.integer(forKey: UserDefaults.Keys.updateInterval) == 0 ? 3600 : UserDefaults.standard.integer(forKey: UserDefaults.Keys.updateInterval))
        loadScholars()
        startPeriodicUpdates()
    }
    
    private func loadScholars() {
        if let data = UserDefaults.standard.data(forKey: UserDefaults.Keys.scholars),
           let scholars = try? JSONDecoder().decode([Scholar].self, from: data) {
            self.scholars = scholars
        }
    }
    
    func saveScholars() {
        if let data = try? JSONEncoder().encode(scholars) {
            UserDefaults.standard.set(data, forKey: UserDefaults.Keys.scholars)
        }
    }
    
    func addScholar(_ scholar: Scholar) {
        scholars.append(scholar)
        saveScholars()
        Task {
            await updateScholar(scholar.id)
        }
    }
    
    func removeScholar(at index: Int) {
        scholars.remove(at: index)
        saveScholars()
    }
    
    @MainActor
    func updateScholar(_ scholarId: String) async {
        guard let index = scholars.firstIndex(where: { $0.id == scholarId }) else { return }
        
        do {
            let citations = try await GoogleScholarService.fetchCitations(for: scholarId)
            scholars[index].citations = citations
            scholars[index].lastUpdated = Date()
            saveScholars()
        } catch {
            print("Error updating scholar \(scholarId): \(error)")
        }
    }
    
    @MainActor
    func updateAllScholars() async {
        for scholar in scholars {
            await updateScholar(scholar.id)
        }
    }
    
    private func startPeriodicUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task {
                await self.updateAllScholars()
            }
        }
    }
}

// MARK: - Menu Bar Manager
class MenuBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var dataManager: DataManager
    private var settingsWindow: SettingsWindow?
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
        super.init()
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "📚"
            button.toolTip = "CiteTrack"
        }
        
        updateMenu()
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        
        // Title
        let titleItem = NSMenuItem(title: "CiteTrack", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        // Scholars
        if dataManager.scholars.isEmpty {
            let noScholarsItem = NSMenuItem(title: "No scholars added", action: nil, keyEquivalent: "")
            noScholarsItem.isEnabled = false
            menu.addItem(noScholarsItem)
        } else {
            for scholar in dataManager.scholars {
                let scholarItem = NSMenuItem()
                let citationText = scholar.citations.map { "\($0) citations" } ?? "Loading..."
                scholarItem.title = "\(scholar.name): \(citationText)"
                scholarItem.isEnabled = false
                menu.addItem(scholarItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Update manually
        let updateItem = NSMenuItem(title: "Update Now", action: #selector(updateNow), keyEquivalent: "u")
        updateItem.target = self
        menu.addItem(updateItem)
        
        // Check for Updates
        let checkUpdatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        checkUpdatesItem.target = self
        menu.addItem(checkUpdatesItem)
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func updateNow() {
        Task {
            await dataManager.updateAllScholars()
            DispatchQueue.main.async {
                self.updateMenu()
            }
        }
    }
    
    @objc private func checkForUpdates() {
        #if !APP_STORE
        SUUpdater.shared()?.checkForUpdates(nil)
        #else
        // App Store 版本不支持内置更新（通过 App Store 更新）
        #endif
    }
    
    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(dataManager: dataManager)
        }
        settingsWindow?.showWindow()
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - App Delegate
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var dataManager: DataManager!
    private var menuBarManager: MenuBarManager!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        
        // 初始化 Sparkle（仅非 App Store）
        #if !APP_STORE
        SUUpdater.shared()?.automaticallyChecksForUpdates = true
        SUUpdater.shared()?.updateCheckInterval = 86400 // 24 hours
        #endif
        
        dataManager = DataManager()
        menuBarManager = MenuBarManager(dataManager: dataManager)
        
        // 初始更新
        Task {
            await dataManager.updateAllScholars()
        }
    }
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}