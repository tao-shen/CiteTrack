import SwiftUI
import UserNotifications
import BackgroundTasks

@main
struct CiteTrackApp: App {
    
    // MARK: - State Objects
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var dataSyncService = DataSyncService.shared
    @StateObject private var coreDataManager = CoreDataManager.shared
    
    // MARK: - App State
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // 配置应用启动
        configureApp()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsManager)
                .environmentObject(localizationManager)
                .environmentObject(notificationService)
                .environmentObject(dataSyncService)
                .environmentObject(coreDataManager)
                .environment(\.managedObjectContext, coreDataManager.viewContext)
                .onAppear {
                    setupNotifications()
                    setupBackgroundTasks()
                }
                .onChange(of: scenePhase) { phase in
                    handleScenePhaseChange(phase)
                }
        }
        .backgroundTask(.appRefresh("citation_update")) {
            await performBackgroundUpdate()
        }
    }
    
    // MARK: - Configuration
    
    private func configureApp() {
        // 配置Core Data
        setupCoreData()
        
        // 配置外观
        setupAppearance()
        
        print("📱 CiteTrack iOS 应用启动")
    }
    
    private func setupCoreData() {
        // Core Data已经通过shared实例自动初始化
        print("📊 Core Data 配置完成")
    }
    
    private func setupAppearance() {
        // 配置应用主题
        switch settingsManager.theme {
        case .light:
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .light
        case .dark:
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .dark
        case .system:
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .unspecified
        }
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        if settingsManager.notificationsEnabled {
            notificationService.requestAuthorization { granted in
                print("📱 通知授权: \(granted ? "已授权" : "被拒绝")")
            }
        }
    }
    
    // MARK: - Background Tasks
    
    private func setupBackgroundTasks() {
        registerBackgroundTasks()
        scheduleBackgroundAppRefresh()
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "citation_update", using: nil) { task in
            handleBackgroundUpdate(task: task as! BGAppRefreshTask)
        }
    }
    
    private func scheduleBackgroundAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "citation_update")
        request.earliestBeginDate = Date(timeIntervalSinceNow: settingsManager.updateInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 后台刷新任务已安排")
        } catch {
            print("❌ 安排后台刷新任务失败: \(error)")
        }
    }
    
    private func handleBackgroundUpdate(task: BGAppRefreshTask) {
        // 安排下次后台刷新
        scheduleBackgroundAppRefresh()
        
        // 执行后台更新
        Task {
            await performBackgroundUpdate()
            task.setTaskCompleted(success: true)
        }
    }
    
    @MainActor
    private func performBackgroundUpdate() async {
        print("🔄 执行后台数据更新")
        
        // 获取所有学者
        let scholars = settingsManager.getScholars()
        guard !scholars.isEmpty else {
            print("ℹ️ 没有学者数据，跳过后台更新")
            return
        }
        
        // 限制后台更新的学者数量，避免超时
        let limitedScholars = Array(scholars.prefix(5))
        
        await withTaskGroup(of: Void.self) { group in
            for scholar in limitedScholars {
                group.addTask {
                    await updateScholarInBackground(scholar)
                }
            }
        }
        
        print("✅ 后台数据更新完成")
    }
    
    private func updateScholarInBackground(_ scholar: Scholar) async {
        await withCheckedContinuation { continuation in
            GoogleScholarService.shared.fetchAndSaveCitationCount(for: scholar.id) { result in
                switch result {
                case .success(let newCount):
                    if let oldCount = scholar.citations, oldCount != newCount {
                        // 发送通知
                        NotificationService.shared.scheduleCitationChangeNotification(
                            scholarName: scholar.displayName,
                            oldCount: oldCount,
                            newCount: newCount
                        )
                    }
                case .failure(let error):
                    print("❌ 后台更新学者 \(scholar.displayName) 失败: \(error)")
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Scene Phase Handling
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            print("📱 应用进入前台")
            // 清除通知角标
            notificationService.clearBadge()
            
        case .inactive:
            print("📱 应用变为非活跃状态")
            
        case .background:
            print("📱 应用进入后台")
            // 保存Core Data上下文
            coreDataManager.saveContext()
            
        @unknown default:
            break
        }
    }
}