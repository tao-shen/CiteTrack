import Foundation
import UserNotifications
import Cocoa

// MARK: - Notification Settings
struct NotificationSettings: Codable {
    var isEnabled: Bool
    var threshold: Int
    var notificationTypes: Set<NotificationType>
    var quietHours: QuietHours?
    var soundEnabled: Bool
    
    enum NotificationType: String, CaseIterable, Codable {
        case system = "system"
        case popup = "popup"
        case menuBar = "menuBar"
        
        var displayName: String {
            switch self {
            case .system:
                return L("notification_type_system")
            case .popup:
                return L("notification_type_popup")
            case .menuBar:
                return L("notification_type_menu_bar")
            }
        }
    }
    
    struct QuietHours: Codable {
        let startHour: Int // 0-23
        let endHour: Int   // 0-23
        let enabled: Bool
        
        func isQuietTime(at date: Date = Date()) -> Bool {
            guard enabled else { return false }
            
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            
            if startHour <= endHour {
                return hour >= startHour && hour < endHour
            } else {
                // Quiet hours span midnight
                return hour >= startHour || hour < endHour
            }
        }
    }
    
    static let `default` = NotificationSettings(
        isEnabled: true,
        threshold: 5,
        notificationTypes: [.system, .menuBar],
        quietHours: QuietHours(startHour: 22, endHour: 8, enabled: true),
        soundEnabled: true
    )
}

// MARK: - Notification Manager
class NotificationManager {
    static let shared = NotificationManager()
    
    private let userDefaults = UserDefaults.standard
    private let notificationCenter = UNUserNotificationCenter.current()
    private let settingsKey = "NotificationSettings"
    
    var settings: NotificationSettings {
        get {
            guard let data = userDefaults.data(forKey: settingsKey),
                  let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) else {
                return .default
            }
            return settings
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: settingsKey)
            }
        }
    }
    
    private init() {
        requestNotificationPermission()
    }
    
    // MARK: - Permission Management
    
    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
            print("Notification permission granted: \(granted)")
        }
    }
    
    func checkNotificationPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async(qos: .userInitiated) {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    // MARK: - Change Detection
    
    func checkForSignificantChanges(_ newData: CitationHistory, previous: CitationHistory?) -> Bool {
        guard settings.isEnabled else { return false }
        
        guard let previous = previous else {
            // First time tracking this scholar - not significant
            return false
        }
        
        let change = newData.citationCount - previous.citationCount
        return abs(change) >= settings.threshold
    }
    
    func processScholarUpdate(_ scholar: Scholar, newCitations: Int, previousCitations: Int?) {
        guard settings.isEnabled else { return }
        
        guard let previousCitations = previousCitations else { return }
        
        let change = newCitations - previousCitations
        
        if abs(change) >= settings.threshold {
            let citationChange = CitationChange(
                scholarId: scholar.id,
                scholarName: scholar.name,
                previousCount: previousCitations,
                newCount: newCitations,
                change: change,
                timestamp: Date(),
                isSignificant: true
            )
            
            sendNotification(for: citationChange)
        }
    }
    
    // MARK: - Notification Sending
    
    func sendNotification(for change: CitationChange) {
        guard settings.isEnabled else { return }
        
        // Check quiet hours
        if let quietHours = settings.quietHours, quietHours.isQuietTime() {
            print("Skipping notification due to quiet hours")
            return
        }
        
        // Send different types of notifications based on settings
        if settings.notificationTypes.contains(.system) {
            sendSystemNotification(for: change)
        }
        
        if settings.notificationTypes.contains(.popup) {
            sendPopupNotification(for: change)
        }
        
        if settings.notificationTypes.contains(.menuBar) {
            sendMenuBarNotification(for: change)
        }
    }
    
    private func sendSystemNotification(for change: CitationChange) {
        let content = UNMutableNotificationContent()
        content.title = L("notification_title_single", change.scholarName)
        content.body = change.changeDescription
        content.sound = settings.soundEnabled ? .default : nil
        
        // Add custom data
        content.userInfo = [
            "scholarId": change.scholarId,
            "scholarName": change.scholarName,
            "change": change.change,
            "newCount": change.newCount
        ]
        
        // Create request
        let identifier = "citation-change-\(change.scholarId)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to send system notification: \(error)")
            }
        }
    }
    
    private func sendPopupNotification(for change: CitationChange) {
        DispatchQueue.main.async(qos: .userInitiated) {
            let alert = NSAlert()
            alert.messageText = L("notification_popup_title")
            alert.informativeText = L("notification_popup_body", change.scholarName, change.changeDescription)
            alert.alertStyle = change.change > 0 ? .informational : .warning
            alert.addButton(withTitle: L("button_ok"))
            alert.addButton(withTitle: L("button_open_charts"))
            
            let response = alert.runModal()
            
            if response == .alertSecondButtonReturn {
                // Open charts view for this scholar
                self.openChartsForScholar(change.scholarId)
            }
        }
    }
    
    private func sendMenuBarNotification(for change: CitationChange) {
        // Post notification for menu bar to update badge or indicator
        NotificationCenter.default.post(
            name: .citationChangeDetected,
            object: nil,
            userInfo: [
                "change": change,
                "timestamp": Date()
            ]
        )
    }
    
    // MARK: - Batch Processing
    
    func processMultipleChanges(_ changes: [CitationChange]) {
        guard settings.isEnabled && !changes.isEmpty else { return }
        
        let significantChanges = changes.filter { $0.isSignificant }
        
        if significantChanges.count == 1 {
            sendNotification(for: significantChanges.first!)
        } else if significantChanges.count > 1 {
            sendBatchNotification(for: significantChanges)
        }
    }
    
    private func sendBatchNotification(for changes: [CitationChange]) {
        let totalIncrease = changes.filter { $0.change > 0 }.reduce(0) { $0 + $1.change }
        let totalDecrease = changes.filter { $0.change < 0 }.reduce(0) { $0 + abs($1.change) }
        
        var message = L("notification_multiple_updates_header")
        if totalIncrease > 0 {
            message += " " + L("notification_multiple_updates_increase", totalIncrease)
        }
        if totalDecrease > 0 {
            message += " " + L("notification_multiple_updates_decrease", totalDecrease)
        }
        
        if settings.notificationTypes.contains(.system) {
            let content = UNMutableNotificationContent()
            content.title = L("notification_title_multiple")
            content.body = message
            content.sound = settings.soundEnabled ? .default : nil
            
            let identifier = "batch-citation-changes-\(Date().timeIntervalSince1970)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            
            notificationCenter.add(request) { error in
                if let error = error {
                    print("Failed to send batch notification: \(error)")
                }
            }
        }
        
        if settings.notificationTypes.contains(.popup) {
            DispatchQueue.main.async(qos: .userInitiated) {
                let alert = NSAlert()
                alert.messageText = L("notification_title_multiple")
                alert.informativeText = message + "\n\n" + L("notification_affected_scholars", changes.map { $0.scholarName }.joined(separator: ", "))
                alert.alertStyle = .informational
                alert.addButton(withTitle: L("button_ok"))
                alert.addButton(withTitle: L("button_open_charts"))
                
                let response = alert.runModal()
                
                if response == .alertSecondButtonReturn {
                    self.openChartsView()
                }
            }
        }
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: NotificationSettings) {
        settings = newSettings
        
        // Re-request permission if needed
        if newSettings.isEnabled && newSettings.notificationTypes.contains(.system) {
            requestNotificationPermission()
        }
    }
    
    
    // MARK: - Navigation Helpers
    
    private func openChartsForScholar(_ scholarId: String) {
        // Post notification to open charts view for specific scholar
        NotificationCenter.default.post(
            name: .openChartsForScholar,
            object: nil,
            userInfo: ["scholarId": scholarId]
        )
    }
    
    private func openChartsView() {
        // Post notification to open charts view
        NotificationCenter.default.post(
            name: .openChartsView,
            object: nil
        )
    }
    
    // MARK: - Notification History
    
    private var notificationHistory: [CitationChange] = []
    private let maxHistoryCount = 50
    
    func addToHistory(_ change: CitationChange) {
        notificationHistory.insert(change, at: 0)
        
        // Keep only recent notifications
        if notificationHistory.count > maxHistoryCount {
            notificationHistory = Array(notificationHistory.prefix(maxHistoryCount))
        }
    }
    
    func getNotificationHistory() -> [CitationChange] {
        return notificationHistory
    }
    
    func clearNotificationHistory() {
        notificationHistory.removeAll()
    }
    
    // MARK: - Cleanup
    
    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let citationChangeDetected = Notification.Name("CitationChangeDetected")
    static let openChartsForScholar = Notification.Name("OpenChartsForScholar")
    static let openChartsView = Notification.Name("OpenChartsView")
}

// MARK: - Notification Settings View Controller
class NotificationSettingsViewController: NSViewController {
    
    private var enabledCheckbox: NSButton!
    private var thresholdTextField: NSTextField!
    private var systemNotificationCheckbox: NSButton!
    private var popupNotificationCheckbox: NSButton!
    private var menuBarNotificationCheckbox: NSButton!
    private var quietHoursCheckbox: NSButton!
    private var startHourPopup: NSPopUpButton!
    private var endHourPopup: NSPopUpButton!
    private var soundEnabledCheckbox: NSButton!
    
    private let notificationManager = NotificationManager.shared
    
    override func loadView() {
        view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
    }
    
    private func setupUI() {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 16
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Enable notifications
        enabledCheckbox = NSButton(checkboxWithTitle: L("notification_enable_checkbox"), target: self, action: #selector(settingsChanged))
        stackView.addArrangedSubview(enabledCheckbox)
        
        // Threshold setting
        let thresholdContainer = NSView()
        let thresholdLabel = NSTextField(labelWithString: L("notification_threshold_label"))
        thresholdTextField = NSTextField()
        thresholdTextField.placeholderString = L("notification_threshold_placeholder")
        thresholdTextField.target = self
        thresholdTextField.action = #selector(settingsChanged)
        
        thresholdContainer.addSubview(thresholdLabel)
        thresholdContainer.addSubview(thresholdTextField)
        
        thresholdLabel.translatesAutoresizingMaskIntoConstraints = false
        thresholdTextField.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            thresholdLabel.leadingAnchor.constraint(equalTo: thresholdContainer.leadingAnchor),
            thresholdLabel.centerYAnchor.constraint(equalTo: thresholdContainer.centerYAnchor),
            thresholdTextField.leadingAnchor.constraint(equalTo: thresholdLabel.trailingAnchor, constant: 12),
            thresholdTextField.centerYAnchor.constraint(equalTo: thresholdContainer.centerYAnchor),
            thresholdTextField.widthAnchor.constraint(equalToConstant: 60),
            thresholdContainer.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        stackView.addArrangedSubview(thresholdContainer)
        
        // Notification types
        let typesLabel = NSTextField(labelWithString: L("notification_types_label"))
        typesLabel.font = NSFont.boldSystemFont(ofSize: 13)
        stackView.addArrangedSubview(typesLabel)
        
        systemNotificationCheckbox = NSButton(checkboxWithTitle: L("notification_type_system_checkbox"), target: self, action: #selector(settingsChanged))
        popupNotificationCheckbox = NSButton(checkboxWithTitle: L("notification_type_popup_checkbox"), target: self, action: #selector(settingsChanged))
        menuBarNotificationCheckbox = NSButton(checkboxWithTitle: L("notification_type_menu_bar_checkbox"), target: self, action: #selector(settingsChanged))
        
        stackView.addArrangedSubview(systemNotificationCheckbox)
        stackView.addArrangedSubview(popupNotificationCheckbox)
        stackView.addArrangedSubview(menuBarNotificationCheckbox)
        
        // Sound setting
        soundEnabledCheckbox = NSButton(checkboxWithTitle: L("notification_sound_checkbox"), target: self, action: #selector(settingsChanged))
        stackView.addArrangedSubview(soundEnabledCheckbox)
        
        // Quiet hours
        quietHoursCheckbox = NSButton(checkboxWithTitle: L("notification_quiet_hours_checkbox"), target: self, action: #selector(settingsChanged))
        stackView.addArrangedSubview(quietHoursCheckbox)
        
        let quietHoursContainer = NSView()
        let fromLabel = NSTextField(labelWithString: L("notification_quiet_hours_from"))
        let toLabel = NSTextField(labelWithString: L("notification_quiet_hours_to"))
        
        startHourPopup = NSPopUpButton()
        endHourPopup = NSPopUpButton()
        
        for hour in 0...23 {
            let timeString = String(format: "%02d:00", hour)
            startHourPopup.addItem(withTitle: timeString)
            endHourPopup.addItem(withTitle: timeString)
        }
        
        startHourPopup.target = self
        startHourPopup.action = #selector(settingsChanged)
        endHourPopup.target = self
        endHourPopup.action = #selector(settingsChanged)
        
        quietHoursContainer.addSubview(fromLabel)
        quietHoursContainer.addSubview(startHourPopup)
        quietHoursContainer.addSubview(toLabel)
        quietHoursContainer.addSubview(endHourPopup)
        
        fromLabel.translatesAutoresizingMaskIntoConstraints = false
        startHourPopup.translatesAutoresizingMaskIntoConstraints = false
        toLabel.translatesAutoresizingMaskIntoConstraints = false
        endHourPopup.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            fromLabel.leadingAnchor.constraint(equalTo: quietHoursContainer.leadingAnchor, constant: 20),
            fromLabel.centerYAnchor.constraint(equalTo: quietHoursContainer.centerYAnchor),
            startHourPopup.leadingAnchor.constraint(equalTo: fromLabel.trailingAnchor, constant: 8),
            startHourPopup.centerYAnchor.constraint(equalTo: quietHoursContainer.centerYAnchor),
            toLabel.leadingAnchor.constraint(equalTo: startHourPopup.trailingAnchor, constant: 12),
            toLabel.centerYAnchor.constraint(equalTo: quietHoursContainer.centerYAnchor),
            endHourPopup.leadingAnchor.constraint(equalTo: toLabel.trailingAnchor, constant: 8),
            endHourPopup.centerYAnchor.constraint(equalTo: quietHoursContainer.centerYAnchor),
            quietHoursContainer.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        stackView.addArrangedSubview(quietHoursContainer)
        
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func loadSettings() {
        let settings = notificationManager.settings
        
        enabledCheckbox.state = settings.isEnabled ? .on : .off
        thresholdTextField.stringValue = "\(settings.threshold)"
        systemNotificationCheckbox.state = settings.notificationTypes.contains(.system) ? .on : .off
        popupNotificationCheckbox.state = settings.notificationTypes.contains(.popup) ? .on : .off
        menuBarNotificationCheckbox.state = settings.notificationTypes.contains(.menuBar) ? .on : .off
        soundEnabledCheckbox.state = settings.soundEnabled ? .on : .off
        
        if let quietHours = settings.quietHours {
            quietHoursCheckbox.state = quietHours.enabled ? .on : .off
            startHourPopup.selectItem(at: quietHours.startHour)
            endHourPopup.selectItem(at: quietHours.endHour)
        }
        
        updateUIState()
    }
    
    @objc private func settingsChanged() {
        let threshold = Int(thresholdTextField.stringValue) ?? 5
        
        var notificationTypes: Set<NotificationSettings.NotificationType> = []
        if systemNotificationCheckbox.state == .on {
            notificationTypes.insert(.system)
        }
        if popupNotificationCheckbox.state == .on {
            notificationTypes.insert(.popup)
        }
        if menuBarNotificationCheckbox.state == .on {
            notificationTypes.insert(.menuBar)
        }
        
        let quietHours = NotificationSettings.QuietHours(
            startHour: startHourPopup.indexOfSelectedItem,
            endHour: endHourPopup.indexOfSelectedItem,
            enabled: quietHoursCheckbox.state == .on
        )
        
        let newSettings = NotificationSettings(
            isEnabled: enabledCheckbox.state == .on,
            threshold: threshold,
            notificationTypes: notificationTypes,
            quietHours: quietHours,
            soundEnabled: soundEnabledCheckbox.state == .on
        )
        
        notificationManager.updateSettings(newSettings)
        updateUIState()
    }
    
    private func updateUIState() {
        let enabled = enabledCheckbox.state == .on
        
        thresholdTextField.isEnabled = enabled
        systemNotificationCheckbox.isEnabled = enabled
        popupNotificationCheckbox.isEnabled = enabled
        menuBarNotificationCheckbox.isEnabled = enabled
        soundEnabledCheckbox.isEnabled = enabled
        quietHoursCheckbox.isEnabled = enabled
        
        let quietHoursEnabled = enabled && quietHoursCheckbox.state == .on
        startHourPopup.isEnabled = quietHoursEnabled
        endHourPopup.isEnabled = quietHoursEnabled
        
    }
    
}