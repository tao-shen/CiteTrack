import SwiftUI
import UserNotifications
import Foundation

@main
struct CiteTrackApp: App {
    
    // MARK: - State Objects
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsManager)
                .environmentObject(localizationManager)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("通知权限: \(granted ? "已授权" : "被拒绝")")
        }
        
        print("📱 CiteTrack iOS 应用启动")
    }
}

