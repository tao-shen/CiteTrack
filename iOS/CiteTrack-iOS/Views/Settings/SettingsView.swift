import SwiftUI

struct SettingsView: View {
    
    // MARK: - Environment Objects
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var dataSyncService: DataSyncService
    
    // MARK: - State
    @State private var showingLanguageSheet = false
    @State private var showingExportSheet = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            List {
                // 应用设置
                appSettingsSection
                
                // 同步和通知
                syncNotificationSection
                
                // 外观设置
                appearanceSection
                
                // 数据管理
                dataManagementSection
                
                // 关于和帮助
                aboutSection
            }
            .navigationTitle("settings".localized)
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingLanguageSheet) {
                LanguageSelectionView()
            }
            .sheet(isPresented: $showingExportSheet) {
                DataExportView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }
    
    // MARK: - App Settings Section
    
    private var appSettingsSection: some View {
        Section("general_settings".localized) {
            // 更新间隔
            NavigationLink {
                UpdateIntervalView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("update_interval".localized)
                        Text(formatUpdateInterval(settingsManager.updateInterval))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                }
            }
            
            // 启动时打开
            Toggle(isOn: $settingsManager.launchAtLogin) {
                Label("launch_at_login".localized, systemImage: "power")
            }
            .tint(.green)
        }
    }
    
    // MARK: - Sync and Notification Section
    
    private var syncNotificationSection: some View {
        Section("sync_and_notifications".localized) {
            // iCloud同步
            Toggle(isOn: $settingsManager.iCloudSyncEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("icloud_sync".localized)
                        if dataSyncService.isSyncing {
                            Text("syncing".localized)
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else if let lastSync = dataSyncService.lastSyncDate {
                            Text("last_sync".localized + ": " + lastSync.timeAgoString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: dataSyncService.isSyncing ? "icloud.and.arrow.up" : "icloud")
                        .foregroundColor(.blue)
                }
            }
            .tint(.blue)
            .onChange(of: settingsManager.iCloudSyncEnabled) { enabled in
                if enabled {
                    dataSyncService.startAutoSync(interval: settingsManager.updateInterval)
                } else {
                    dataSyncService.stopAutoSync()
                }
            }
            
            // 通知设置
            Toggle(isOn: $settingsManager.notificationsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("notifications".localized)
                        Text(notificationAuthorizationStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "bell")
                        .foregroundColor(.orange)
                }
            }
            .tint(.orange)
            .onChange(of: settingsManager.notificationsEnabled) { enabled in
                if enabled {
                    notificationService.requestAuthorization { _ in }
                }
            }
        }
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        Section("appearance".localized) {
            // 语言设置
            Button {
                showingLanguageSheet = true
            } label: {
                Label {
                    HStack {
                        Text("language".localized)
                        Spacer()
                        Text(localizationManager.currentLanguage.displayName)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.tertiary)
                    }
                } icon: {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                }
            }
            .foregroundColor(.primary)
            
            // 主题设置
            Picker(selection: $settingsManager.theme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            } label: {
                Label("theme".localized, systemImage: "paintbrush")
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        Section("data_management".localized) {
            // 导出数据
            Button {
                showingExportSheet = true
            } label: {
                Label("export_data".localized, systemImage: "square.and.arrow.up")
            }
            
            // 数据统计
            NavigationLink {
                DataStatisticsView()
            } label: {
                Label("data_statistics".localized, systemImage: "chart.bar.doc.horizontal")
            }
            
            // 清除缓存
            Button {
                clearCache()
            } label: {
                Label("clear_cache".localized, systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section("about_and_help".localized) {
            Button {
                showingAbout = true
            } label: {
                Label("about_citetrack".localized, systemImage: "info.circle")
            }
            
            Button {
                openURL("https://github.com/tao-shen/CiteTrack")
            } label: {
                Label("view_on_github".localized, systemImage: "link")
            }
            
            Button {
                openURL("mailto:support@citetrack.app")
            } label: {
                Label("contact_support".localized, systemImage: "envelope")
            }
            
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Label("privacy_policy".localized, systemImage: "hand.raised")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var notificationAuthorizationStatusText: String {
        switch notificationService.authorizationStatus {
        case .authorized:
            return "authorized".localized
        case .denied:
            return "denied".localized
        case .notDetermined:
            return "not_determined".localized
        case .provisional:
            return "provisional".localized
        case .ephemeral:
            return "ephemeral".localized
        @unknown default:
            return "unknown".localized
        }
    }
    
    // MARK: - Methods
    
    private func formatUpdateInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours) " + "hours".localized + (minutes > 0 ? " \(minutes) " + "minutes".localized : "")
        } else if minutes > 0 {
            return "\(minutes) " + "minutes".localized
        } else {
            return "manual".localized
        }
    }
    
    private func clearCache() {
        // 实现清除缓存逻辑
        URLCache.shared.removeAllCachedResponses()
        
        // 显示成功提示
        let notification = UNMutableNotificationContent()
        notification.title = "cache_cleared".localized
        notification.body = "cache_cleared_successfully".localized
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: notification,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Update Interval View
struct UpdateIntervalView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    
    private let intervals: [(TimeInterval, String)] = [
        (300, "5 " + "minutes".localized),      // 5分钟
        (600, "10 " + "minutes".localized),     // 10分钟
        (1800, "30 " + "minutes".localized),    // 30分钟
        (3600, "1 " + "hour".localized),        // 1小时
        (7200, "2 " + "hours".localized),       // 2小时
        (21600, "6 " + "hours".localized),      // 6小时
        (43200, "12 " + "hours".localized),     // 12小时
        (86400, "24 " + "hours".localized),     // 24小时
    ]
    
    var body: some View {
        List {
            Section {
                ForEach(intervals, id: \.0) { interval, name in
                    HStack {
                        Text(name)
                        Spacer()
                        if settingsManager.updateInterval == interval {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        settingsManager.updateInterval = interval
                        dismiss()
                    }
                }
            } header: {
                Text("select_update_interval".localized)
            } footer: {
                Text("shorter_intervals_consume_more_battery".localized)
            }
        }
        .navigationTitle("update_interval".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Language Selection View
struct LanguageSelectionView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(LocalizationManager.Language.allCases, id: \.self) { language in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(language.displayName)
                                .font(.headline)
                            Text(language.nativeName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if localizationManager.currentLanguage == language {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        localizationManager.switchLanguage(to: language) {
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("select_language".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Placeholder Views
struct DataExportView: View {
    var body: some View {
        Text("Data Export - Coming Soon")
    }
}

struct AboutView: View {
    var body: some View {
        Text("About CiteTrack - Coming Soon")
    }
}

struct DataStatisticsView: View {
    var body: some View {
        Text("Data Statistics - Coming Soon")
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        Text("Privacy Policy - Coming Soon")
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SettingsManager.shared)
            .environmentObject(LocalizationManager.shared)
            .environmentObject(NotificationService.shared)
            .environmentObject(DataSyncService.shared)
    }
}