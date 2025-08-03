import Foundation
import UserNotifications
import Combine

// MARK: - Notification Service
public class NotificationService: NSObject, ObservableObject {
    public static let shared = NotificationService()
    
    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public var notificationsEnabled: Bool = false
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    public override init() {
        super.init()
        notificationCenter.delegate = self
        updateAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.authorizationStatus = granted ? .authorized : .denied
                self.notificationsEnabled = granted
                completion(granted)
            }
            
            if let error = error {
                print("❌ 通知授权失败: \(error.localizedDescription)")
            }
        }
    }
    
    public func updateAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Citation Change Notifications
    
    public func scheduleCitationChangeNotification(
        scholarName: String,
        oldCount: Int,
        newCount: Int,
        identifier: String = UUID().uuidString
    ) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "引用数变化"
        
        let change = newCount - oldCount
        let changeText = change > 0 ? "+\(change)" : "\(change)"
        content.body = "\(scholarName)的引用数发生变化：\(oldCount) → \(newCount) (\(changeText))"
        
        content.sound = .default
        content.badge = 1
        
        // 设置用户信息，用于点击通知时的处理
        content.userInfo = [
            "type": "citation_change",
            "scholar_name": scholarName,
            "old_count": oldCount,
            "new_count": newCount,
            "change": change
        ]
        
        // 立即显示通知
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ 添加通知失败: \(error.localizedDescription)")
            } else {
                print("✅ 成功添加引用变化通知: \(scholarName)")
            }
        }
    }
    
    public func scheduleDataUpdateNotification(
        scholarCount: Int,
        updatedCount: Int,
        identifier: String = "data_update"
    ) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "数据更新完成"
        content.body = "已更新 \(updatedCount)/\(scholarCount) 位学者的引用数据"
        content.sound = .default
        
        content.userInfo = [
            "type": "data_update",
            "scholar_count": scholarCount,
            "updated_count": updatedCount
        ]
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ 添加数据更新通知失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Reminder Notifications
    
    public func scheduleReminderNotification(
        title: String,
        body: String,
        date: Date,
        identifier: String = UUID().uuidString
    ) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        content.userInfo = [
            "type": "reminder",
            "scheduled_date": date.timeIntervalSince1970
        ]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ 添加提醒通知失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Badge Management
    
    public func updateBadgeCount(_ count: Int) {
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
        #endif
    }
    
    public func clearBadge() {
        updateBadgeCount(0)
    }
    
    // MARK: - Notification Management
    
    public func removeAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        clearBadge()
    }
    
    public func removeNotifications(withIdentifiers identifiers: [String]) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    
    public func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        notificationCenter.getPendingNotificationRequests(completionHandler: completion)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 在应用前台时也显示通知
        completionHandler([.alert, .badge, .sound])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // 处理不同类型的通知响应
        if let type = userInfo["type"] as? String {
            switch type {
            case "citation_change":
                handleCitationChangeNotificationResponse(userInfo: userInfo)
            case "data_update":
                handleDataUpdateNotificationResponse(userInfo: userInfo)
            case "reminder":
                handleReminderNotificationResponse(userInfo: userInfo)
            default:
                break
            }
        }
        
        completionHandler()
    }
    
    private func handleCitationChangeNotificationResponse(userInfo: [AnyHashable: Any]) {
        // 处理引用变化通知的点击
        if let scholarName = userInfo["scholar_name"] as? String {
            print("📱 用户点击了引用变化通知: \(scholarName)")
            // 这里可以发送通知给UI层，跳转到对应学者的详情页面
            NotificationCenter.default.post(
                name: .scholarNotificationTapped,
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    private func handleDataUpdateNotificationResponse(userInfo: [AnyHashable: Any]) {
        // 处理数据更新通知的点击
        print("📱 用户点击了数据更新通知")
        NotificationCenter.default.post(
            name: .dataUpdateNotificationTapped,
            object: nil,
            userInfo: userInfo
        )
    }
    
    private func handleReminderNotificationResponse(userInfo: [AnyHashable: Any]) {
        // 处理提醒通知的点击
        print("📱 用户点击了提醒通知")
        NotificationCenter.default.post(
            name: .reminderNotificationTapped,
            object: nil,
            userInfo: userInfo
        )
    }
}

// MARK: - Notification Names
public extension Notification.Name {
    static let scholarNotificationTapped = Notification.Name("scholarNotificationTapped")
    static let dataUpdateNotificationTapped = Notification.Name("dataUpdateNotificationTapped")
    static let reminderNotificationTapped = Notification.Name("reminderNotificationTapped")
}