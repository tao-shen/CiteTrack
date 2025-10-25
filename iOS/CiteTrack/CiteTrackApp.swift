import SwiftUI
#if canImport(SwiftEntryKit)
import SwiftEntryKit
#endif

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 用户数据结构
struct UserData: Codable {
    let userId: String
    let data: [String: Int]  // 日期字符串 -> 刷新次数
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case data
        case lastUpdated = "last_updated"
    }
}
import ConfettiSwiftUI
import WSOnBoarding
import UIKit
import BackgroundTasks
import WidgetKit
import UniformTypeIdentifiers
import AppIntents
import CoreTelephony

#if canImport(ContributionChart)
import ContributionChart
#endif

// MARK: - Global Helpers (visible across this file)
@inline(__always)
func CT_FirstInstallDate() -> Date {
    let key = "FirstInstallDate"
    let calendar = Calendar.current
    if let saved = UserDefaults.standard.object(forKey: key) as? Date {
        return calendar.startOfDay(for: saved)
    } else {
        let today = calendar.startOfDay(for: Date())
        UserDefaults.standard.set(today, forKey: key)
        if let ag = UserDefaults(suiteName: appGroupIdentifier) {
            ag.set(today, forKey: key)
            ag.synchronize()
        }
        return today
    }
}

// 简化：使用单一全局方法进行手动计数，避免跨文件依赖
func CT_RecordManualRefresh() {
    // 轻量防抖：同一时间窗口内的重复触发只计一次
    let defaults = UserDefaults.standard
    let now = Date()
    if let last = defaults.object(forKey: "LastManualRefreshAt") as? Date {
        // 阈值：2秒内重复触发视为同一次手动动作
        if now.timeIntervalSince(last) < 2.0 {
            return
        }
    }
    defaults.set(now, forKey: "LastManualRefreshAt")

    // 统一通过用户行为管理器记录刷新次数
    UserBehaviorManager.shared.recordRefresh()
}

// MARK: - Seeded Random Number Generator
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 1103515245 &+ 12345
        return state
    }
}

// MARK: - Haptics Prewarm Helper
enum HapticsManager {
    static func prewarm() {
        // Prepare commonly used haptic generators to avoid first-use jank
        let light = UIImpactFeedbackGenerator(style: .light)
        light.prepare()
        let medium = UIImpactFeedbackGenerator(style: .medium)
        medium.prepare()
        let selection = UISelectionFeedbackGenerator()
        selection.prepare()
    }
}

@main
struct CiteTrackApp: App {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var initializationService = AppInitializationService.shared
    @StateObject private var autoUpdateManager = AutoUpdateManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var cloudSyncManager = iCloudSyncManager.shared
    @Environment(\.scenePhase) private var scenePhase
    private static let refreshTaskIdentifier = "com.citetrack.citationRefresh"
    
    init() {
        NSLog("🧪 [CiteTrackApp] init called - app is starting up")
        // 注册后台刷新任务
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskIdentifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            CiteTrackApp.handleAppRefresh(task: task)
        }
        // 预先安排一次刷新
        CiteTrackApp.scheduleAppRefresh()
        
        // 方法2实现：使用公共普遍性容器，无需FileProvider扩展
        NSLog("🔧 [CiteTrackApp] \("debug_using_public_container".localized)")

        // 🚀 优化：延迟启动 iCloud 导入，避免阻塞 App 启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if iCloudSyncManager.shared.isiCloudAvailable {
                // 优先读取容器 Documents 下两个文件（ios_data.json 与 citation_data.json）
                iCloudSyncManager.shared.importConfigOnFirstLaunch()
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(colorScheme)
                .environmentObject(dataManager)
                .environmentObject(iCloudSyncManager.shared)
                .environmentObject(initializationService)
                .environmentObject(autoUpdateManager)
                .environmentObject(localizationManager)
                .wsWelcomeView(
                    config: WSWelcomeConfig.citeTrackWelcome,
                    style: .standard
                )
                .id(localizationManager.currentLanguage.rawValue)
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
                .onAppear {
                    NSLog("🧪 [CiteTrackApp] WindowGroup.onAppear")
                    
                    // 🚀 优化：立即预热触觉反馈（非常快，不会卡顿）
                    HapticsManager.prewarm()
                    
                    // 🚀 优化：后台异步执行权限检查，完全不阻塞 UI
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
                        // 启动时检查蜂窝数据可用性
                        CellularDataPermission.shared.triggerCheck()
                        // 启动即触发一次轻量的网络访问以申请网络权限（非阻塞、短超时）
                        NetworkPermissionTrigger.trigger()
                    }
                    
                    // 🚀 优化：延迟执行初始化流程（仅首次启动需要）
                    Task {
                        // 延迟 0.3 秒，确保 UI 先渲染并可交互
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        await initializationService.performInitialization()
                    }
                    
                    // 🚀 优化：延迟并后台执行 iCloud 检查
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) {
                        let icloud = iCloudSyncManager.shared
                        print("🧪 [CiteTrackApp] Trigger initial iCloud checks on launch")
                        NSLog("🧪 [CiteTrackApp] Trigger initial iCloud checks on launch (NSLog)")
                        icloud.checkSyncStatus()
                        icloud.bootstrapContainerIfPossible()
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // 应用激活时尝试安排下一次刷新
                CiteTrackApp.scheduleAppRefresh()
                // 前台激活时，立即同步全局 LastRefreshTime
                let ag = UserDefaults(suiteName: appGroupIdentifier)
                let t = (ag?.object(forKey: "LastRefreshTime") as? Date) ?? (UserDefaults.standard.object(forKey: "LastRefreshTime") as? Date)
                let old = DataManager.shared.lastRefreshTime
                DataManager.shared.lastRefreshTime = t
                print("🧪 [CiteTrackApp] \(String(format: "debug_sync_last_refresh_time".localized, old?.description ?? "nil", t?.description ?? "nil"))")
            }
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch settingsManager.theme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
    
    private func handleDeepLink(url: URL) {
        print("🔗 [DeepLink] \(String(format: "debug_deep_link_received".localized, url.description))")
        
        guard url.scheme == "citetrack" else {
            print("❌ [DeepLink] \(String(format: "debug_invalid_url_scheme".localized, url.scheme ?? "nil"))")
            return
        }
        
        let host = url.host
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        print("🔗 [DeepLink] Host: \(host ?? "nil"), Path: \(pathComponents)")
        
        switch host {
        case "add-scholar":
            // 切换到添加学者页面
            NotificationCenter.default.post(name: .deepLinkAddScholar, object: nil)
        case "scholars":
            // 切换到学者管理页面
            NotificationCenter.default.post(name: .deepLinkScholars, object: nil)
        case "dashboard":
            // 切换到仪表板页面
            NotificationCenter.default.post(name: .deepLinkDashboard, object: nil)
        case "scholar":
            // 查看特定学者详情
            if let scholarId = pathComponents.first {
                NotificationCenter.default.post(name: .deepLinkScholarDetail, object: scholarId)
            }
        case "refresh":
            // Widget刷新按钮点击
            print("🔄 [DeepLink] \("debug_refresh_request_received".localized)")
            handleWidgetRefresh()
        case "switch":
            // Widget切换按钮点击
            print("🎯 [DeepLink] \("debug_switch_scholar_request_received".localized)")
            handleWidgetScholarSwitch()
        default:
            print("❌ [DeepLink] \(String(format: "debug_unsupported_deep_link".localized, url.description))")
        }
    }
    
    // MARK: - Widget Action Handlers
    private func handleWidgetRefresh() {
        print("🔄 [Widget] \("debug_widget_refresh_start".localized)")
        
        // 设置刷新时间戳，Widget会检测到这个时间戳并播放动画
        let now = Date()
        UserDefaults.standard.set(now, forKey: "LastRefreshTime")
        if let appGroup = UserDefaults(suiteName: appGroupIdentifier) {
            appGroup.set(now, forKey: "LastRefreshTime")
            appGroup.synchronize()
            print("🧪 [CiteTrackApp] \(String(format: "debug_appgroup_write_direct".localized, "\(now)"))")
        }
        print("🧪 [CiteTrackApp] \(String(format: "debug_standard_write_direct".localized, "\(now)"))")
        // 发送Darwin通知，提示主应用各管理器同步
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName("com.citetrack.lastRefreshTimeUpdated" as CFString), nil, nil, true)
        print("🧪 [CiteTrackApp] \(String(format: "debug_darwin_notification_sent".localized, "com.citetrack.lastRefreshTimeUpdated"))")
        
        // 如果有学者数据，触发实际的数据刷新
        let scholars = dataManager.scholars
        
        if !scholars.isEmpty {
            print("🔄 [Widget] \(String(format: "debug_refresh_scholars_count".localized, scholars.count))")
            
            let group = DispatchGroup()
            for scholar in scholars {
                group.enter()
                GoogleScholarService.shared.fetchScholarInfo(for: scholar.id) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let info):
                            var updated = Scholar(id: scholar.id, name: info.name)
                            updated.citations = info.citations
                            updated.lastUpdated = Date()
                            self.dataManager.updateScholar(updated)
                            self.dataManager.saveHistoryIfChanged(scholarId: scholar.id, citationCount: info.citations)
                        case .failure(let error):
                            print("❌ \(String(format: "debug_widget_refresh_failed".localized, scholar.id, error.localizedDescription))")
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                // 🎯 使用DataManager的refreshWidgets来计算并保存变化数据
                self.dataManager.refreshWidgets()
                print("✅ [Widget] \("debug_widget_refresh_complete".localized)")
            }
        } else {
            // 没有学者数据，直接更新小组件
            dataManager.refreshWidgets()
        }
    }
    
    private func handleWidgetScholarSwitch() {
        print("🎯 [Widget] \("debug_widget_switch_start".localized)")
        
        // 记录用户学者切换行为
        // UserBehaviorManager.shared.recordScholarSwitch()
        
        // 设置切换时间戳，Widget会检测到这个时间戳并播放动画
        UserDefaults.standard.set(Date(), forKey: "LastScholarSwitchTime")
        
        let scholars = dataManager.scholars
        
        if scholars.count > 1 {
            // 获取当前显示的学者索引
            let currentIndex = UserDefaults.standard.integer(forKey: "CurrentScholarIndex")
            let nextIndex = (currentIndex + 1) % scholars.count
            
            // 保存新的索引
            UserDefaults.standard.set(nextIndex, forKey: "CurrentScholarIndex")
            
            print("🎯 [Widget] \(String(format: "debug_widget_switch_success".localized, nextIndex, scholars[nextIndex].displayName))")
            
            // 更新小组件
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            print("🎯 [Widget] \("debug_widget_insufficient_scholars".localized)")
            // 仍然更新小组件以提供反馈
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

// MARK: - Network Permission Trigger
enum NetworkPermissionTrigger {
    static func trigger() {
        // 🚀 优化：在后台异步执行，避免阻塞主线程
        DispatchQueue.global(qos: .utility).async {
            guard let url = URL(string: "https://www.apple.com/library/test/success.html") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 1.0  // 减少超时时间到1秒
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("⚠️ [NetworkPermission] Network probe completed with error (expected): \(error.localizedDescription)")
                } else {
                    print("✅ [NetworkPermission] Network probe successful")
                }
            }
            task.resume()
        }
    }
}

// MARK: - Cellular Data Permission Helper
final class CellularDataPermission {
    static let shared = CellularDataPermission()
    private let cellularData = CTCellularData()
    private init() {}
    
    func triggerCheck() {
        cellularData.cellularDataRestrictionDidUpdateNotifier = { state in
            switch state {
            case .restricted:
                print("📶 \("debug_cellular_restricted".localized)")
            case .notRestricted:
                print("📶 \("debug_cellular_available".localized)")
            case .restrictedStateUnknown:
                fallthrough
            @unknown default:
                print("📶 \("debug_cellular_unknown".localized)")
            }
        }
        let state = cellularData.restrictedState
        switch state {
        case .restricted: print("📶[Init] \("debug_cellular_restricted".localized)")
        case .notRestricted: print("📶[Init] \("debug_cellular_available".localized)")
        case .restrictedStateUnknown: print("📶[Init] \("debug_cellular_unknown".localized)")
        @unknown default: print("📶[Init] \("debug_cellular_unknown".localized)")
        }
    }
}

// MARK: - Background Refresh Helpers
extension CiteTrackApp {
    private static func nextRefreshDate() -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 0) + 1
        comps.hour = 3
        comps.minute = 0
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date().addingTimeInterval(24 * 60 * 60)
    }

    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: CiteTrackApp.refreshTaskIdentifier)
        request.earliestBeginDate = nextRefreshDate()
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 \(String(format: "debug_background_refresh_scheduled".localized, request.earliestBeginDate?.description ?? "unknown"))")
        } catch {
            print("❌ \(String(format: "debug_background_refresh_failed".localized, error.localizedDescription))")
        }
    }

    static func handleAppRefresh(task: BGAppRefreshTask) {
        // 安排下一次
        scheduleAppRefresh()

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 2

        task.expirationHandler = {
            operationQueue.cancelAllOperations()
        }

        let scholars = DataManager.shared.scholars
        if scholars.isEmpty {
            WidgetCenter.shared.reloadAllTimelines()
            task.setTaskCompleted(success: true)
            return
        }

        let limited = Array(scholars.prefix(5))

        let group = DispatchGroup()
        for scholar in limited {
            group.enter()
            GoogleScholarService.shared.fetchScholarInfo(for: scholar.id) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let info):
                        var updated = Scholar(id: scholar.id, name: info.name)
                        updated.citations = info.citations
                        updated.lastUpdated = Date()
                        
                        DataManager.shared.updateScholar(updated)
                        DataManager.shared.saveHistoryIfChanged(
                            scholarId: scholar.id,
                            citationCount: info.citations
                        )
                        
                        print("✅ [批量更新] \(String(format: "debug_batch_update_success".localized, info.name, info.citations))")
                        
                    case .failure(let error):
                        print("❌ [批量更新] \(String(format: "debug_batch_update_failed".localized, scholar.id, error.localizedDescription))")
                    }
                    
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            // 完成本地抓取后，保存一次 CloudKit 长期同步
            iCloudSyncManager.shared.exportUsingCloudKit { _ in
                // 🎯 使用DataManager的refreshWidgets来刷新已计算好的数据
                DataManager.shared.refreshWidgets()
                task.setTaskCompleted(success: true)
            }
        }
    }
}

struct MainView: View {
    @State private var selectedTab = 0
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @EnvironmentObject private var initializationService: AppInitializationService
    @State private var contributionData: [Double] = []
    
    init() {
        // 记录应用打开行为
        // UserBehaviorManager.shared.recordAppOpen()
    }
    
    // 🟣 紫色区域：底部文字说明区域 - 图表说明文字
    private var bottomTextSection: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.top, 4) // 减少上方间距
            
            // Contribution Chart Section
            contributionChartSection
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Contribution Chart Section
    private var contributionChartSection: some View {
        #if canImport(ContributionChart)
        ZStack {
            // 背景点击区域 - 覆盖整个图表区域
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    // 点击任何空白区域时淡出弹窗
                    NotificationCenter.default.post(name: .dismissTooltip, object: nil)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                
                Text("app_usage".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture {
                        // 点击标题区域时淡出弹窗
                        NotificationCenter.default.post(name: .dismissTooltip, object: nil)
                    }
                
                CustomContributionChart(
                    data: contributionData,
                    rows: 7,
                    columns: 52
                )
                .frame(height: 250) // 增加高度以适应30像素的方块
                .frame(maxWidth: .infinity, alignment: .leading)
                .onReceive(NotificationCenter.default.publisher(for: .userDataChanged)) { _ in
                    // 用户数据变更后刷新热力图
                    contributionData = generateContributionData()
                }
                .onAppear {
                    contributionData = generateContributionData()
                }
                
                Text("debug_show_refresh_frequency".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .onTapGesture {
                        // 点击描述文字区域时淡出弹窗
                        NotificationCenter.default.post(name: .dismissTooltip, object: nil)
                    }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        #else
        VStack(alignment: .leading, spacing: 8) {
            Text("debug_chart_description".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("debug_chart_explanation".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        #endif
    }
    
    // MARK: - Contribution Data Generation
    
    // 展示模式开关：0=真实用户数据，1=随机演示数据（仅代码内赋值）
    private let heatmapDemoMode: Int = 0
    
    /// 生成随机热力图数据（52列 x 7行 = 364 个单元，列优先）
    private func generateRandomHeatmapData() -> [Double] {
        var data: [Double] = []
        data.reserveCapacity(52 * 7)
        
        // 简单权重分布，让随机结果更接近真实：
        // 0.0:55%  0.25:15%  0.5:15%  0.75:10%  1.0:5%
        func randomIntensity() -> Double {
            let roll = Double.random(in: 0..<1)
            if roll < 0.55 { return 0.0 }
            if roll < 0.70 { return 0.25 }
            if roll < 0.85 { return 0.5 }
            if roll < 0.95 { return 0.75 }
            return 1.0
        }
        
        for _ in 0..<52 { // 列（周）
            for _ in 0..<7 { // 行（周内天）
                data.append(randomIntensity())
            }
        }
        return data
    }
    private func generateContributionData() -> [Double] {
        // 根据展示模式切换数据源
        if heatmapDemoMode == 1 {
            return generateRandomHeatmapData()
        } else {
            // 统一从用户行为层获取热力图数据
            return UserBehaviorManager.shared.getHeatmapData()
        }
    }

    // 获取或初始化应用安装日期（与 UserBehavior.installDateKey 保持一致）
    private func getInstallDate() -> Date {
        let key = "AppInstallDate"
        let defaults = UserDefaults.standard
        if let saved = defaults.object(forKey: key) as? Date {
            return saved
        } else {
            let today = Calendar.current.startOfDay(for: Date())
            defaults.set(today, forKey: key)
            if let ag = UserDefaults(suiteName: appGroupIdentifier) {
                ag.set(today, forKey: key)
                ag.synchronize()
            }
            return today
        }
    }

    // 获取或初始化"首次安装日期"，用于跨重装的起点（会通过 iCloud 同步）
    private func CT_FirstInstallDate() -> Date {
        let key = "FirstInstallDate"
        let defaults = UserDefaults.standard
        if let saved = defaults.object(forKey: key) as? Date {
            return Calendar.current.startOfDay(for: saved)
        } else {
            let today = Calendar.current.startOfDay(for: Date())
            defaults.set(today, forKey: key)
            if let ag = UserDefaults(suiteName: appGroupIdentifier) {
                ag.set(today, forKey: key)
                ag.synchronize()
            }
            return today
        }
    }
    
    private func calculateIntensity(for refreshCount: Int) -> Double {
        switch refreshCount {
        case 0:
            return 0.0
        case 1:
            return 0.25
        case 2...3:
            return 0.5
        case 4...6:
            return 0.75
        default:
            return 1.0
        }
    }
    
    // 不再使用热力图测试的初始化模拟数据
    
    var body: some View {
        Group {
            if initializationService.isFirstLaunch && initializationService.isInitializing {
                InitializationView()
            } else {
                TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text(localizationManager.localized("dashboard"))
                }
                .tag(0)
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("iCloudImportPromptAvailable"))) { _ in
                    if iCloudSyncManager.shared.showImportPrompt == true {
                        // 强制切到 Dashboard 时也能弹出（showImportPrompt 已经绑定 alert）
                        iCloudSyncManager.shared.showImportPrompt = true
                    }
                }
            
            NewScholarView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text(localizationManager.localized("scholars"))
                }
                .tag(1)
            
            // 新增：学者增长折线图（使用 SwiftUICharts 多学者对比）
            NavigationView {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 12) {
                        // 🟠 橙色区域：外层ScholarsGrowthLineChartView - 图表组件容器
                        ScholarsGrowthLineChartView()
                            .environmentObject(DataManager.shared)
                            .environmentObject(localizationManager)
                            // .background(Color.orange.opacity(0.3)) // 调试：外层ScholarsGrowthLineChartView背景
                            .frame(maxHeight: 450) // 设置最大高度，让图表有足够空间但不会过高
                            .frame(minHeight: 440) // 设置最小高度，确保图表有基本显示空间
                        
                        // 🟢 绿色区域：贡献活动热力图区域
                        contributionChartSection
                            // .background(Color.purple.opacity(0.3)) // 调试：bottomTextSection背景
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom)
                }
                .navigationTitle(localizationManager.localized("charts"))
                .navigationBarTitleDisplayMode(.large)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "chart.xyaxis.line")
                Text(localizationManager.localized("charts"))
            }
            .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text(localizationManager.localized("settings"))
                }
                .tag(3)
        }
                .onReceive(NotificationCenter.default.publisher(for: .deepLinkAddScholar)) { _ in
                    selectedTab = 1 // 切换到学者管理页面
                }
                .onReceive(NotificationCenter.default.publisher(for: .deepLinkScholars)) { _ in
                    selectedTab = 1 // 切换到学者管理页面
                }
                .onReceive(NotificationCenter.default.publisher(for: .deepLinkDashboard)) { _ in
                    selectedTab = 0 // 切换到仪表板页面
                }
            }
        }
    }
}

// 仪表板视图
struct DashboardView: View {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var sortOption: SortOption = .total
    @AppStorage("ConfirmedMyScholarId") private var confirmedMyScholarId: String?
    
    enum SortOption: String, CaseIterable {
        case total
        case week
        case month
        case quarter
        
        func title(_ lm: LocalizationManager) -> String {
            switch self {
            case .total: return lm.localized("total_citations")
            case .week: return lm.localized("recent_week")
            case .month: return lm.localized("recent_month")
            case .quarter: return lm.localized("recent_three_months")
            }
        }
    }
    
    private var sortedScholars: [Scholar] {
        switch sortOption {
        case .total:
            return dataManager.scholars.sorted { ($0.citations ?? 0) > ($1.citations ?? 0) }
        case .week:
            return dataManager.scholars.sorted {
                let a = dataManager.getStoredGrowth(for: $0.id, days: 7) ?? 0
                let b = dataManager.getStoredGrowth(for: $1.id, days: 7) ?? 0
                return a > b
            }
        case .month:
            return dataManager.scholars.sorted {
                let a = dataManager.getStoredGrowth(for: $0.id, days: 30) ?? 0
                let b = dataManager.getStoredGrowth(for: $1.id, days: 30) ?? 0
                return a > b
            }
        case .quarter:
            return dataManager.scholars.sorted {
                let a = dataManager.getStoredGrowth(for: $0.id, days: 90) ?? 0
                let b = dataManager.getStoredGrowth(for: $1.id, days: 90) ?? 0
                return a > b
            }
        }
    }
    
    private func subtitle(for scholar: Scholar) -> String {
        switch sortOption {
        case .total:
            let total = scholar.citations ?? 0
            return localizationManager.localized("total_citations") + ": \(total)"
        case .week:
            let delta = dataManager.getStoredGrowth(for: scholar.id, days: 7) ?? 0
            let sign = delta >= 0 ? "+" : ""
            return localizationManager.localized("recent_week") + ": \(sign)\(delta)"
        case .month:
            let delta = dataManager.getStoredGrowth(for: scholar.id, days: 30) ?? 0
            let sign = delta >= 0 ? "+" : ""
            return localizationManager.localized("recent_month") + ": \(sign)\(delta)"
        case .quarter:
            let delta = dataManager.getStoredGrowth(for: scholar.id, days: 90) ?? 0
            let sign = delta >= 0 ? "+" : ""
            return localizationManager.localized("recent_three_months") + ": \(sign)\(delta)"
        }
    }
    
    private func moveSortSelection(offset: Int) {
        let all = SortOption.allCases
        guard let currentIndex = all.firstIndex(of: sortOption) else { return }
        let newIndex = min(max(currentIndex + offset, 0), all.count - 1)
        if newIndex != currentIndex {
            withAnimation { sortOption = all[newIndex] }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                LazyVStack(spacing: 20) {
                    // 头部区域：统计卡片 + 排序控件
                    VStack(spacing: 12) {
                        // 统计卡片
                        HStack(spacing: 12) {
                        StatisticsCard(
                            title: localizationManager.localized("my_citations"),
                            value: {
                                if let sid = confirmedMyScholarId, let me = dataManager.getScholar(id: sid) {
                                    return "\(me.citations ?? 0)"
                                } else {
                                    return "0"
                                }
                            }(),
                            icon: "quote.bubble.fill",
                            color: .blue
                        )
                        
                        StatisticsCard(
                            title: localizationManager.localized("scholar_count"),
                            value: "\(dataManager.scholars.count)",
                            icon: "person.2.fill",
                            color: .green
                        )
                        }
                        
                        // 排序控件
                        if !dataManager.scholars.isEmpty {
                            Picker(localizationManager.localized("sort_by"), selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.title(localizationManager)).tag(option)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                    
                    // 学者列表（支持排序与前三名勋章）
                    if !dataManager.scholars.isEmpty {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            Text(localizationManager.localized("citation_ranking"))
                                .font(.headline)
                            
                            ForEach(Array(sortedScholars.enumerated()), id: \.element.id) { index, scholar in
                                HStack(spacing: 8) {
                                    if index < 3 {
                                        Image(systemName: "medal.fill")
                                            .foregroundColor(index == 0 ? .yellow : (index == 1 ? .gray : .orange))
                                    }
                                    ScholarRow(scholar: scholar, subtitle: subtitle(for: scholar))
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "person.2.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text(localizationManager.localized("no_scholar_data"))
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text(localizationManager.localized("add_first_scholar_tip"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                    }
                    // 移除额外空白，让滚动长度严格由内容决定
                }
                .padding()
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            // 若垂直位移更大，交给 ScrollView 处理
                            let dx = value.translation.width
                            let dy = value.translation.height
                            guard abs(dx) > abs(dy) * 1.5 else { return }
                        }
                        .onEnded { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            // 仅识别明显的水平滑动，避免拦截纵向滚动
                            guard abs(dx) > abs(dy) * 1.5, abs(dx) > 60 else { return }
                            moveSortSelection(offset: dx < 0 ? 1 : -1)
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        }
                )
            }
            .navigationTitle(localizationManager.localized("dashboard_title"))
        }
    }
}


// 新的学者视图（合并了原图表功能和学者管理功能）
struct NewScholarView: View {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var googleScholarService = GoogleScholarService.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var isLoading = false
    @State private var loadingScholarId: String?
    @State private var errorMessage = ""
    @State private var showingErrorAlert = false
    @State private var isRefreshing = false
    @State private var refreshProgress = 0
    @State private var totalScholars = 0
    @State private var isEditing = false
    @State private var showingDeleteScholarAlert = false
    @State private var pendingDeleteScholars: [Scholar] = []
    @State private var showingDeleteAllAlert = false
    @AppStorage("ConfirmedMyScholarId") private var confirmedMyScholarId: String?
    // Confetti & message state
    @State private var confettiTrigger: Int = 0
    @State private var lastConfettiReason: String = ""
    @State private var batchDelta: Int = 0

    private func showEntryKitPopup(titleKey: String, descKey: String, value: Int, context: String) {
        #if canImport(SwiftEntryKit)
        var attributes = EKAttributes.centerFloat
        attributes.displayDuration = 2.0
        attributes.entryBackground = .visualEffect(style: .dark)
        attributes.shadow = .active(with: .init(color: .black, opacity: 0.2, radius: 10))
        attributes.roundCorners = .all(radius: 16)
        attributes.entranceAnimation = .init( 
            translate: .init(duration: 0.45, spring: .init(damping: 0.8, initialVelocity: 0.6)),
            scale: .init(from: 0.85, to: 1.0, duration: 0.45),
            fade: .init(from: 0.0, to: 1.0, duration: 0.2)
        )
        attributes.exitAnimation = .init(
            translate: .init(duration: 0.3),
            scale: .init(from: 1.0, to: 0.96, duration: 0.25),
            fade: .init(from: 1.0, to: 0.0, duration: 0.25)
        )
        attributes.positionConstraints.size = .init(width: .intrinsic, height: .intrinsic)
        attributes.positionConstraints.maxSize = .init(width: .constant(value: min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) - 40), height: .intrinsic)
        attributes.hapticFeedbackType = .success

        let title = EKProperty.LabelContent(text: titleKey.localized, style: .init(font: .boldSystemFont(ofSize: 22), color: .white))
        let descText = String(format: descKey.localized, max(value, 0))
        let desc = EKProperty.LabelContent(text: descText, style: .init(font: .systemFont(ofSize: 18, weight: .semibold), color: .white))
        let image = EKProperty.ImageContent(image: UIImage(systemName: "sparkles") ?? UIImage(), size: CGSize(width: 30, height: 30))
        let simple = EKSimpleMessage(image: image, title: title, description: desc)
        let note = EKNotificationMessage(simpleMessage: simple)
        let view = EKNotificationMessageView(with: note)
        SwiftEntryKit.display(entry: view, using: attributes)
        print("🎯 [EntryKit] popup shown: context=\(context), value=\(value)")
        #else
        print("⚠️ [EntryKit] SwiftEntryKit not integrated, skip popup. context=\(context), value=\(value)")
        #endif
    }

    private func showSingleRefreshPopupAndConfetti(scholarId: String, delta: Int, currentCitations: Int) {
        // 计算今日累计增长
        let todayStart = Calendar.current.startOfDay(for: Date())
        let todayHistory = dataManager.getHistory(for: scholarId, days: 1).filter { $0.timestamp >= todayStart }
        let earliestTodayCount = todayHistory.min(by: { $0.timestamp < $1.timestamp })?.citationCount
        let todayGrowth = earliestTodayCount != nil ? (currentCitations - earliestTodayCount!) : 0

        if delta > 0 {
            // 有本次增长：标题🎉 恭喜！ 描述：该学者引用量增长了 +%d，礼花：显示
            lastConfettiReason = "single_update delta=\(delta)"
            confettiTrigger += 1
            print("🎆 [Confetti] Single update trigger: \(lastConfettiReason)")
            showEntryKitPopup(titleKey: "single_update_title_growth", descKey: "single_update_desc_growth", value: delta, context: "single_update_delta_positive")
        } else if todayGrowth > 0 {
            // 本次0，但今日累计>0：也需放礼花
            lastConfettiReason = "single_update todayGrowth=\(todayGrowth)"
            confettiTrigger += 1
            print("🎆 [Confetti] Single update trigger: \(lastConfettiReason)")
            showEntryKitPopup(titleKey: "single_update_title_today_growth", descKey: "single_update_desc_today_growth", value: todayGrowth, context: "single_update_today_growth_positive")
        } else {
            // 今日累计=0：标题暂无新增引用 描述今天的引用量没有增长，礼花：不显示
            #if canImport(SwiftEntryKit)
            var attributes = EKAttributes.centerFloat
            attributes.displayDuration = 2.0
            attributes.entryBackground = .visualEffect(style: .dark)
            attributes.shadow = .active(with: .init(color: .black, opacity: 0.2, radius: 10))
            attributes.roundCorners = .all(radius: 16)
            attributes.entranceAnimation = .init(
                translate: .init(duration: 0.45, spring: .init(damping: 0.8, initialVelocity: 0.6)),
                scale: .init(from: 0.85, to: 1.0, duration: 0.45),
                fade: .init(from: 0.0, to: 1.0, duration: 0.2)
            )
            attributes.exitAnimation = .init(
                translate: .init(duration: 0.3),
                scale: .init(from: 1.0, to: 0.96, duration: 0.25),
                fade: .init(from: 1.0, to: 0.0, duration: 0.25)
            )
            attributes.positionConstraints.size = .init(width: .intrinsic, height: .intrinsic)
            attributes.positionConstraints.maxSize = .init(width: .constant(value: min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) - 40), height: .intrinsic)
            attributes.hapticFeedbackType = .success

            let title = EKProperty.LabelContent(text: "single_update_title_no_growth".localized, style: .init(font: .boldSystemFont(ofSize: 22), color: .white))
            let desc = EKProperty.LabelContent(text: "single_update_desc_no_growth".localized, style: .init(font: .systemFont(ofSize: 18, weight: .semibold), color: .white))
            let image = EKProperty.ImageContent(image: UIImage(systemName: "info.circle") ?? UIImage(), size: CGSize(width: 30, height: 30))
            let simple = EKSimpleMessage(image: image, title: title, description: desc)
            let note = EKNotificationMessage(simpleMessage: simple)
            let view = EKNotificationMessageView(with: note)
            SwiftEntryKit.display(entry: view, using: attributes)
            print("🎯 [EntryKit] popup shown: context=single_update_no_growth, value=0")
            #else
            print("⚠️ [EntryKit] SwiftEntryKit not integrated, skip popup. context=single_update_no_growth, value=0")
            #endif
        }
    }

    private func showBatchRefreshPopupAndConfetti(totalDelta: Int) {
        if totalDelta > 0 {
            lastConfettiReason = "batch_done totalDelta=\(totalDelta)"
            confettiTrigger += 1
            print("🎉 [Confetti] Batch finished trigger: \(lastConfettiReason)")
            // 延迟以避免与礼花重叠
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showEntryKitPopup(titleKey: "batch_update_title_growth", descKey: "batch_update_desc_growth", value: totalDelta, context: "batch_finished_growth")
            }
        } else {
            // 无增长，不放礼花
            showEntryKitPopup(titleKey: "batch_update_title_no_growth", descKey: "batch_update_desc_no_growth", value: 0, context: "batch_finished_no_growth")
        }
    }
    
    /// 新增学者后的提示弹窗（与刷新弹窗风格一致，定制文案）
    private func showAddedScholarPopup(currentCitations: Int?) {
        #if canImport(SwiftEntryKit)
        var attributes = EKAttributes.centerFloat
        attributes.displayDuration = 2.0
        attributes.entryBackground = .visualEffect(style: .dark)
        attributes.shadow = .active(with: .init(color: .black, opacity: 0.2, radius: 10))
        attributes.roundCorners = .all(radius: 16)
        attributes.entranceAnimation = .init(
            translate: .init(duration: 0.45, spring: .init(damping: 0.8, initialVelocity: 0.6)),
            scale: .init(from: 0.85, to: 1.0, duration: 0.45),
            fade: .init(from: 0.0, to: 1.0, duration: 0.2)
        )
        attributes.exitAnimation = .init(
            translate: .init(duration: 0.3),
            scale: .init(from: 1.0, to: 0.96, duration: 0.25),
            fade: .init(from: 1.0, to: 0.0, duration: 0.25)
        )
        attributes.positionConstraints.size = .init(width: .intrinsic, height: .intrinsic)
        attributes.positionConstraints.maxSize = .init(width: .constant(value: min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) - 40), height: .intrinsic)
        attributes.hapticFeedbackType = .success

        let title = EKProperty.LabelContent(text: "single_update_title_growth".localized, style: .init(font: .boldSystemFont(ofSize: 22), color: .white))
        let count = currentCitations ?? 0
        let descText = String(format: "debug_new_scholar_added".localized, count)
        let desc = EKProperty.LabelContent(text: descText, style: .init(font: .systemFont(ofSize: 18, weight: .semibold), color: .white))
        let image = EKProperty.ImageContent(image: UIImage(systemName: "sparkles") ?? UIImage(), size: CGSize(width: 30, height: 30))
        let simple = EKSimpleMessage(image: image, title: title, description: desc)
        let note = EKNotificationMessage(simpleMessage: simple)
        let view = EKNotificationMessageView(with: note)
        SwiftEntryKit.display(entry: view, using: attributes)
        print("🎯 [EntryKit] popup shown: context=added_scholar, citations=\(count)")
        #else
        print("⚠️ [EntryKit] SwiftEntryKit not integrated, skip added scholar popup.")
        #endif
    }
    
    // 统一的sheet类型管理
    enum SheetType: Identifiable {
        case chart(Scholar)
        case edit(Scholar)
        case addScholar
        
        var id: String {
            switch self {
            case .chart(let scholar): return "chart_\(scholar.id)"
            case .edit(let scholar): return "edit_\(scholar.id)"
            case .addScholar: return "add_scholar"
            }
        }
    }
    
    @State private var activeSheet: SheetType?

    var body: some View {
        NavigationView {
            VStack {
                if dataManager.scholars.isEmpty {
                    emptyStateView
                } else {
                    scholarListView
                }
            }
            .alert(iCloudSyncManager.shared.importPromptMessage.isEmpty ? localizationManager.localized("icloud_backup_found") : iCloudSyncManager.shared.importPromptMessage, isPresented: Binding(get: { iCloudSyncManager.shared.showImportPrompt }, set: { iCloudSyncManager.shared.showImportPrompt = $0 })) {
                Button(localizationManager.localized("cancel")) {
                    iCloudSyncManager.shared.declineImportFromPrompt()
                }
                Button(localizationManager.localized("import")) {
                    iCloudSyncManager.shared.confirmImportFromPrompt()
                }
            }
            .navigationTitle(localizationManager.localized("scholar_management"))
            .toolbar { toolbarContent }
            .refreshable { CT_RecordManualRefresh(); await refreshAllScholarsAsync() }
            .sheet(item: $activeSheet) { sheetType in
                switch sheetType {
                case .addScholar:
                    AddScholarView { newScholar in
                        // 若尚未确认本人学者，则自动将首次手动添加的学者标记为 It's me（不依赖当前列表为空）
                        if confirmedMyScholarId == nil || confirmedMyScholarId?.isEmpty == true {
                            confirmedMyScholarId = newScholar.id
                        }
                        dataManager.addScholar(newScholar)
                        // 新增学者：触发礼花并弹窗（统一风格）
                        lastConfettiReason = "added_scholar id=\(newScholar.id)"
                        confettiTrigger += 1
                        print("🎉 [Confetti] Added scholar trigger: \(lastConfettiReason)")
                        showAddedScholarPopup(currentCitations: newScholar.citations)
                        // 取消紧接着的二次更新抓取，避免出现"+0" 动效
                        // 如需强制刷新，可由用户手动触发更新
                    }
                case .chart(let scholar):
                    ScholarChartDetailView(scholar: scholar)
                        .onAppear {
                            print("🔍 [Sheet Debug] ScholarChartDetailView appeared for: \(scholar.displayName)")
                        }
                case .edit(let scholar):
                    EditScholarView(scholar: scholar) { updatedScholar in
                        dataManager.updateScholar(updatedScholar)
                    }
                }
            }
            .alert(localizationManager.localized("fetch_failed"), isPresented: $showingErrorAlert) {
                Button(localizationManager.localized("confirm")) { }
            } message: {
                Text(errorMessage)
            }
            .alert(localizationManager.localized("delete_all_scholars_title"), isPresented: $showingDeleteAllAlert) {
                Button(localizationManager.localized("cancel"), role: .cancel) { }
                Button(localizationManager.localized("delete"), role: .destructive) { deleteAllScholars() }
            } message: {
                Text(localizationManager.localized("delete_all_scholars_message"))
            }
            .alert(localizationManager.localized("delete_scholar_title"), isPresented: $showingDeleteScholarAlert) {
                Button(localizationManager.localized("cancel"), role: .cancel) {
                    pendingDeleteScholars.removeAll()
                }
                Button(localizationManager.localized("delete"), role: .destructive) {
                    for s in pendingDeleteScholars { deleteScholar(s) }
                    pendingDeleteScholars.removeAll()
                }
            } message: {
                if pendingDeleteScholars.count == 1, let name = pendingDeleteScholars.first?.displayName, !name.isEmpty {
                    Text(String(format: localizationManager.localized("delete_scholar_message_with_name"), name))
                } else if pendingDeleteScholars.count > 1 {
                    Text(String(format: localizationManager.localized("delete_scholars_message_with_count"), pendingDeleteScholars.count))
                } else {
                    Text(localizationManager.localized("delete_scholar_message"))
                }
            }
            .overlay(loadingOverlay)
            .overlay(
                ZStack {
                    // Confetti layer
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                        .confettiCannon(
                            trigger: $confettiTrigger,
                            num: 50,
                            openingAngle: Angle(degrees: 0),
                            closingAngle: Angle(degrees: 360),
                            radius: 200
                        )
                        .allowsHitTesting(false)

                }
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(localizationManager.localized("no_scholar_data"))
                .font(.title2)
                .foregroundColor(.secondary)
            Text(localizationManager.localized("no_scholar_data_tap_tip"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var scholarListView: some View {
        List {

            ForEach(dataManager.scholarsForList, id: \.id) { scholar in
                ScholarRowWithChartAndManagement(
                    scholar: scholar,
                    onChartTap: {
                        print("🔍 [NewScholar Debug] \(String(format: "debug_scholar_chart_tap_print".localized, scholar.displayName))")
                        activeSheet = .chart(scholar)
                    },
                    onUpdateTap: {
                        print("🟡 [Update Tap] \(String(format: "debug_update_tap_print".localized, scholar.id, scholar.displayName))")
                        // 单个学者的手动刷新也应计数
                        CT_RecordManualRefresh()
                        fetchScholarInfo(for: scholar)
                    },
                    isLoading: loadingScholarId == scholar.id
                )
                .overlay(alignment: .topLeading) {
                    if dataManager.isPinned(scholar.id) {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.leading, 2)
                            .padding(.top, 2)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(localizationManager.localized("delete"), role: .destructive) {
                        pendingDeleteScholars = [scholar]
                        showingDeleteScholarAlert = true
                    }
                    
                    Button(localizationManager.localized("edit")) {
                        editScholar(scholar)
                    }
                    .tint(.orange)
                    
                    Button {
                        dataManager.togglePin(id: scholar.id)
                    } label: {
                        Label(dataManager.isPinned(scholar.id) ? localizationManager.localized("unpin") : localizationManager.localized("pin_to_top"), systemImage: dataManager.isPinned(scholar.id) ? "pin.slash" : "pin")
                    }
                    .tint(.blue)

                    // It's me / Not me
                    if confirmedMyScholarId == nil {
                        Button("its_me".localized) {
                            confirmedMyScholarId = scholar.id
                        }
                        .tint(.green)
                    } else if confirmedMyScholarId == scholar.id {
                        Button("not_me".localized) {
                            confirmedMyScholarId = nil
                        }
                        .tint(.gray)
                    }
                }
            }
            .onDelete { offsets in
                var targets: [Scholar] = []
                for index in offsets {
                    let s = dataManager.scholarsForList[index]
                    targets.append(s)
                }
                pendingDeleteScholars = targets
                showingDeleteScholarAlert = true
            }
            .onMove { indices, newOffset in
                dataManager.applyMove(from: indices, to: newOffset)
            }
        }
        .coordinateSpace(name: "pullSpace")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    activeSheet = .addScholar
                } label: {
                    Label(localizationManager.localized("add_scholar"), systemImage: "plus")
                }
                
                Divider()
                
                Button {
                    Task {
                        CT_RecordManualRefresh()
                        await refreshAllScholarsAsync()
                    }
                } label: {
                    Label(isRefreshing ? localizationManager.localized("updating") : localizationManager.localized("update_all"), systemImage: isRefreshing ? "hourglass" : "arrow.clockwise")
                }
                .disabled(isRefreshing)
                
                if !dataManager.scholars.isEmpty {
                    Button(role: .destructive) {
                        showingDeleteAllAlert = true
                    } label: {
                        Label(localizationManager.localized("delete_all"), systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        
        ToolbarItem(placement: .navigationBarLeading) {
            EditButton()
        }
    }


    private var loadingOverlay: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(localizationManager.localized("getting_scholar_info"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 4)
                )
            } else if isRefreshing {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(localizationManager.localized("updating_all_scholars"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(refreshProgress)/\(totalScholars)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 4)
                )
            }
        }
    }

    // MARK: - 学者管理功能

    private func fetchScholarInfo(for scholar: Scholar) {
        isLoading = true
        loadingScholarId = scholar.id
        
        // 仅在显式的用户动作入口加1，此处不再重复计数
        
        googleScholarService.fetchScholarInfo(for: scholar.id) { result in
            DispatchQueue.main.async {
                isLoading = false
                loadingScholarId = nil
                
                switch result {
                case .success(let info):
                    // 计算增量（用于文案显示），但无条件触发庆祝
                    let oldCitations = dataManager.getScholar(id: scholar.id)?.citations ?? info.citations
                    var updatedScholar = Scholar(id: scholar.id, name: info.name)
                    updatedScholar.citations = info.citations
                    updatedScholar.lastUpdated = Date()
                    
                    dataManager.updateScholar(updatedScholar)
                    dataManager.saveHistoryIfChanged(
                        scholarId: scholar.id,
                        citationCount: info.citations
                    )
                    // Popup & confetti for single update (per rules)
                    let delta = info.citations - oldCitations
                    showSingleRefreshPopupAndConfetti(scholarId: scholar.id, delta: delta, currentCitations: info.citations)
                    
                    print("✅ \(String(format: "debug_batch_update_success_direct_print".localized, info.name, info.citations))")
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                    print("❌ \(String(format: "debug_batch_update_failed_direct_print".localized, error.localizedDescription))")
                }
            }
        }
    }

    private func refreshAllScholars() {
        let scholars = dataManager.scholars
        guard !scholars.isEmpty else { return }
        
        // 仅在显式的用户动作入口加1，此处不再重复计数
        
        isRefreshing = true
        totalScholars = scholars.count
        refreshProgress = 0
        
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        for (_, scholar) in scholars.enumerated() {
            group.enter()
            
            queue.async {
                googleScholarService.fetchScholarInfo(for: scholar.id) { result in
                    DispatchQueue.main.async {
                        refreshProgress += 1
                        
                        switch result {
                        case .success(let info):
                            var updatedScholar = Scholar(id: scholar.id, name: info.name)
                            updatedScholar.citations = info.citations
                            updatedScholar.lastUpdated = Date()
                            
                            dataManager.updateScholar(updatedScholar)
                            dataManager.saveHistoryIfChanged(
                                scholarId: scholar.id,
                                citationCount: info.citations
                            )
                            
                            print("✅ [批量更新] \(String(format: "debug_batch_update_success_direct_print".localized, info.name, info.citations))")
                            
                        case .failure(let error):
                            print("❌ [批量更新] \(String(format: "debug_batch_update_failed".localized, scholar.id, error.localizedDescription))")
                        }
                        
                        group.leave()
                    }
                }
            }
            
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        group.notify(queue: .main) {
            isRefreshing = false
            print("✅ [批量更新] \(String(format: "debug_batch_update_complete_direct_print".localized, refreshProgress, totalScholars))")
        }
    }

    private func refreshAllScholarsAsync() async {
        let scholars = dataManager.scholars
        guard !scholars.isEmpty else { return }
        
        let scholarService = googleScholarService // Capture service reference in main actor context
        
        await MainActor.run {
            isRefreshing = true
            totalScholars = scholars.count
            refreshProgress = 0
            
        }
        
        var totalDeltaLocal: Int = 0
        await withTaskGroup(of: Void.self) { group in
            for (index, scholar) in scholars.enumerated() {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(index * 500_000_000))
                    
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        scholarService.fetchScholarInfo(for: scholar.id) { result in
                            Task { @MainActor in
                                refreshProgress += 1
                                
                                switch result {
                                case .success(let info):
                                    let oldCitations = dataManager.getScholar(id: scholar.id)?.citations ?? info.citations
                                    var updatedScholar = Scholar(id: scholar.id, name: info.name)
                                    updatedScholar.citations = info.citations
                                    updatedScholar.lastUpdated = Date()
                                    
                                    dataManager.updateScholar(updatedScholar)
                                    dataManager.saveHistoryIfChanged(
                                        scholarId: updatedScholar.id,
                                        citationCount: info.citations
                                    )
                                    // Accumulate delta only (MainActor safe)
                                    let delta = info.citations - oldCitations
                                    totalDeltaLocal += delta
                                    print("📈 [Batch] Accumulate delta id=\(scholar.id) old=\(oldCitations) new=\(info.citations) delta=\(delta)")
                                    
                                    print("✅ [批量更新] \(String(format: "debug_batch_update_success_direct_print".localized, info.name, info.citations))")
                                    
                                case .failure(let error):
                                    print("❌ [批量更新] \(String(format: "debug_batch_update_failed".localized, scholar.id, error.localizedDescription))")
                                }
                                
                                continuation.resume()
                            }
                        }
                    }
                }
            }
        }
        
        await MainActor.run {
            isRefreshing = false
            print("✅ [批量更新] \(String(format: "debug_batch_update_final_direct_print".localized, refreshProgress, totalScholars, totalDeltaLocal))")
            showBatchRefreshPopupAndConfetti(totalDelta: totalDeltaLocal)
            // 批量刷新完成后，触发一次 iCloud 同步（与自动刷新保持一致）
            let f = DateFormatter(); f.locale = .current; f.timeZone = .current; f.dateStyle = .medium; f.timeStyle = .medium
            print("🚀 [CiteTrackApp] Batch finished at: \(f.string(from: Date())) → bootstrap + performImmediateSync + delayed check")
            iCloudSyncManager.shared.bootstrapContainerIfPossible()
            iCloudSyncManager.shared.performImmediateSync()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("🔍 [CiteTrackApp] Post-batch checkSyncStatus() …")
                iCloudSyncManager.shared.checkSyncStatus()
            }
        }
    }

    

    private func deleteScholars(offsets: IndexSet) {
        for index in offsets {
            let scholarToDelete = dataManager.scholars[index]
            dataManager.removeScholar(id: scholarToDelete.id)
        }
    }

    private func deleteScholar(_ scholar: Scholar) {
        dataManager.removeScholar(id: scholar.id)
    }

    private func deleteAllScholars() {
        dataManager.removeAllScholars()
    }
    
    private func editScholar(_ scholar: Scholar) {
        activeSheet = .edit(scholar)
    }
}

private struct ScholarChartRowView: View {
    let scholar: Scholar
    let onTap: () -> Void

    var body: some View {
        ScholarChartRow(scholar: scholar, onTap: onTap)
    }
}

// 引用排名图表
struct CitationRankingChart: View {
    let scholars: [Scholar]
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var sortedScholars: [Scholar] {
        scholars.sorted { ($0.citations ?? 0) > ($1.citations ?? 0) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(localizationManager.localized("citation_ranking"))
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(Array(sortedScholars.enumerated()), id: \.element.id) { index, scholar in
                    ScholarRankingRowView(index: index, scholar: scholar)
                }
            }
        }
    }
}

private struct ScholarRankingRowView: View {
    let index: Int
    let scholar: Scholar
    var body: some View {
        HStack {
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
            Text(scholar.displayName)
                .font(.body)
                .lineLimit(1)
            Spacer()
            Text("\(scholar.citationDisplay)")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// 引用分布图表
struct CitationDistributionChart: View {
    let scholars: [Scholar]
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(localizationManager.localized("citation_distribution"))
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(scholars, id: \.id) { scholar in
                    if let citations = scholar.citations {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(scholar.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(citations)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            // 进度条
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 8)
                                        .cornerRadius(4)
                                    
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: geometry.size.width * CGFloat(citations) / CGFloat(maxCitationCount), height: 8)
                                        .cornerRadius(4)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
    }
    
    private var maxCitationCount: Int {
        scholars.compactMap { $0.citations }.max() ?? 1
    }
}

// 学者统计图表
struct ScholarStatisticsChart: View {
    let scholars: [Scholar]
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(localizationManager.localized("scholar_statistics"))
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                StatCard(title: localizationManager.localized("total_scholars"), value: "\(scholars.count)", icon: "person.2.fill", color: .blue)
                StatCard(title: localizationManager.localized("total_citations"), value: "\(totalCitations)", icon: "quote.bubble.fill", color: .green)
                StatCard(title: localizationManager.localized("average_citations"), value: "\(averageCitations)", icon: "chart.bar.fill", color: .orange)
                StatCard(title: localizationManager.localized("highest_citations"), value: "\(maxCitations)", icon: "star.fill", color: .red)
            }
        }
    }
    
    private var totalCitations: Int {
        scholars.reduce(0) { $0 + ($1.citations ?? 0) }
    }
    
    private var averageCitations: String {
        let avg = scholars.isEmpty ? 0 : totalCitations / scholars.count
        return "\(avg)"
    }
    
    private var maxCitations: Int {
        scholars.compactMap { $0.citations }.max() ?? 0
    }
}

// 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// 主题选择视图
struct ThemeSelectionView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                HStack(spacing: 12) {
                    Image(systemName: theme == .light ? "sun.max.fill" : theme == .dark ? "moon.fill" : "gear")
                        .font(.title2)
                        .foregroundColor(theme == .light ? .orange : theme == .dark ? .purple : .blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizationManager.localized(theme == .light ? "light_mode" : theme == .dark ? "dark_mode" : "system_mode"))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    if settingsManager.theme == theme {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    settingsManager.theme = theme
                    // 添加小延迟确保主题切换生效
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(localizationManager.localized("theme"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Widget 主题选择视图
struct WidgetThemeSelectionView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                HStack(spacing: 12) {
                    Image(systemName: theme == .light ? "sun.max.fill" : theme == .dark ? "moon.fill" : "gear")
                        .font(.title2)
                        .foregroundColor(theme == .light ? .orange : theme == .dark ? .purple : .blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizationManager.localized(theme == .light ? "light_mode" : theme == .dark ? "dark_mode" : "system_mode"))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    if settingsManager.widgetTheme == theme {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    settingsManager.widgetTheme = theme
                    // 略延时，确保写入完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(localizationManager.localized("widget_theme"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 语言选择视图
struct LanguageSelectionView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            ForEach(LocalizationManager.Language.allCases, id: \.self) { language in
                HStack(spacing: 12) {
                    Text(language.flag)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(language.nativeName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(language.displayName.replacingOccurrences(of: language.flag, with: "").trimmingCharacters(in: .whitespaces))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if localizationManager.currentLanguage == language {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    localizationManager.switchLanguage(to: language) {
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(localizationManager.localized("select_language"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 设置视图
struct SettingsView: View {
    @StateObject private var iCloudManager = iCloudSyncManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showingImportAlert = false
    @State private var showingExportAlert = false
    @State private var showingImportResult = false
    @State private var importResult: ImportResult?
    // 兼容 iCloudSyncManager 内部触发的结果弹窗
    @State private var showingManagerImportResult = false
    @State private var managerImportMessage = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingExportSuccessAlert = false
    @State private var exportSuccessMessage = ""
    @State private var showingExportPicker = false
    @State private var exportTempURLs: [URL] = []
    @State private var exportPickerInitialDirectory: URL? = nil
    @State private var showingImportPicker = false
    @State private var importPickerInitialDirectory: URL? = nil
    @State private var showingDriveFolderPicker = false
    @State private var showingShareSheet = false // 兼容旧路径（保留）
    @State private var shareItems: [Any] = [] // 兼容旧路径（保留）
    struct ShareItem: Identifiable { let id = UUID(); let url: URL }
    @State private var shareURL: ShareItem? = nil
    struct ShareDataItem: Identifiable { let id = UUID(); let data: Data; let fileName: String }
    @State private var shareDataItem: ShareDataItem? = nil
    @State private var showingExportLocalResult = false
    @State private var exportLocalMessage = ""
    @State private var showingCreateFolderAlert = false
    @State private var showingCreateFolderSuccessAlert = false
    @State private var createFolderMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(localizationManager.localized("language")) {
                    NavigationLink(destination: LanguageSelectionView()) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                            Text(localizationManager.localized("language"))
                            Spacer()
                            Text(localizationManager.currentLanguage.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(localizationManager.localized("theme")) {
                    NavigationLink(destination: ThemeSelectionView()) {
                        HStack {
                            Image(systemName: "paintbrush")
                                .foregroundColor(.purple)
                            Text(localizationManager.localized("theme"))
                            Spacer()
                            Text(settingsManager.theme.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                    NavigationLink(destination: WidgetThemeSelectionView()) {
                        HStack {
                            Image(systemName: "square.grid.2x2")
                                .foregroundColor(.teal)
                            Text(localizationManager.localized("widget_theme"))
                            Spacer()
                            Text(settingsManager.widgetTheme.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 自动更新设置
                Section(localizationManager.localized("auto_update")) {
                    AutoUpdateSettingsView()
                }
                
                Section(localizationManager.localized("icloud_sync")) {
                    // iCloud Drive 显示开关（使用标准行样式，保持与其他项一致）
                    Toggle(isOn: $settingsManager.iCloudDriveFolderEnabled) {
                        HStack {
                            Image(systemName: "icloud")
                                .foregroundColor(.blue)
                            Text(localizationManager.localized("show_in_icloud_drive"))
                        }
                    }
                    .onChange(of: settingsManager.iCloudDriveFolderEnabled) { _, enabled in
                        if enabled {
                            // 用户开启时创建文件夹
                            let success = iCloudManager.createiCloudDriveFolder()
                            if success {
                                print("✅ [Settings] \("debug_icloud_folder_success_print".localized)")
                            } else {
                                print("❌ [Settings] \("debug_icloud_folder_failed_print".localized)")
                                // 如果创建失败，将开关重置为关闭状态
                                DispatchQueue.main.async {
                                    settingsManager.iCloudDriveFolderEnabled = false
                                }
                            }
                        }
                    }
                    
                    // 立即同步按钮（左侧）和状态（右侧）
                    HStack {
                        Button(action: {
                            // 若用户未开启在 iCloud Drive 中显示，则点击"立即同步"时自动开启
                            if !settingsManager.iCloudDriveFolderEnabled {
                                settingsManager.iCloudDriveFolderEnabled = true
                                // 尝试创建文件夹，确保 Files 可见
                                _ = iCloudManager.createiCloudDriveFolder()
                            }
                            iCloudManager.performImmediateSync()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.blue)
                                Text(localizationManager.localized("sync_now"))
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        Text(iCloudManager.syncStatus)
                            .foregroundColor(.secondary)
                    }
                    

                    // 从 iCloud 导入（暂时隐藏）
                    // 导出到 iCloud（暂时隐藏）
                }
                
                Section(localizationManager.localized("data_management")) {
                    // 本地导入（文件）
                    Button(action: {
                        iCloudManager.showFilePicker()
                    }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                                .foregroundColor(.green)
                            Text(localizationManager.localized("manual_import_file"))
                        }
                    }
                    .disabled(iCloudManager.isImporting || iCloudManager.isExporting)

                    // 导出到本地（分享）
                    Button(action: exportToLocalDevice) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.orange)
                            Text(localizationManager.localized("export_to_device"))
                        }
                    }
                    .disabled(iCloudManager.isImporting || iCloudManager.isExporting)
                }
                
                Section(localizationManager.localized("about")) {
                    Text(localizationManager.localized("app_description"))
                        .font(.headline)
                    // 仅保留版本号
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.gray)
                        Text(localizationManager.localized("version"))
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(localizationManager.localized("settings"))
            .onAppear {
                // 🚀 优化：后台异步执行 iCloud 检查，避免阻塞 UI
                DispatchQueue.global(qos: .utility).async {
                    iCloudManager.checkSyncStatus()
                    iCloudManager.bootstrapContainerIfPossible()
                    iCloudManager.runDeepDiagnostics()
                }
            }
            .alert(localizationManager.localized("import_from_icloud_alert_title"), isPresented: $showingImportAlert) {
                Button(localizationManager.localized("cancel"), role: .cancel) { }
                Button(localizationManager.localized("import"), action: importFromiCloud)
            } message: {
                Text(localizationManager.localized("import_from_icloud_message"))
            }
            .alert(localizationManager.localized("export_to_icloud_alert_title"), isPresented: $showingExportAlert) {
                Button(localizationManager.localized("cancel"), role: .cancel) { }
                Button(localizationManager.localized("export"), action: exportToiCloud)
            } message: {
                Text(localizationManager.localized("export_to_icloud_message"))
            }
            .alert(localizationManager.localized("import_result"), isPresented: $showingImportResult) {
                Button(localizationManager.localized("confirm"), action: { })
            } message: {
                if let result = importResult {
                    Text(result.description)
                } else {
                    Text(localizationManager.localized("import_completed"))
                }
            }
            .alert(localizationManager.localized("operation_failed"), isPresented: $showingErrorAlert) {
                Button(localizationManager.localized("confirm"), action: { })
            } message: {
                Text(errorMessage)
            }
            .alert(localizationManager.localized("export_to_icloud_alert_title"), isPresented: $showingExportSuccessAlert) {
                Button(localizationManager.localized("confirm"), action: { })
            } message: {
                Text(exportSuccessMessage)
            }
            .alert(localizationManager.localized("create_icloud_folder_alert_title"), isPresented: $showingCreateFolderAlert) {
                Button(localizationManager.localized("cancel"), role: .cancel) { }
                Button(localizationManager.localized("create_folder_button"), action: createiCloudDriveFolder)
            } message: {
                Text(localizationManager.localized("create_icloud_folder_alert_message"))
            }
            .alert(localizationManager.localized("create_folder_success_title"), isPresented: $showingCreateFolderSuccessAlert) {
                Button(localizationManager.localized("confirm"), action: { })
            } message: {
                Text(createFolderMessage)
            }
            .sheet(isPresented: $showingExportPicker) {
                ExportPickerView(isPresented: $showingExportPicker, urls: exportTempURLs, initialDirectory: exportPickerInitialDirectory) { success in
                    print("✅ [iCloud Debug] Export picker finished, success=\(success)")
                    if success {
                        let exportedScholars = DataManager.shared.scholars.count
                        exportSuccessMessage = String(format: localizationManager.localized("export_success")) + " (" + String(format: localizationManager.localized("imported_scholars_count")) + " \(exportedScholars) " + localizationManager.localized("scholars_unit") + ")"
                        showingExportSuccessAlert = true
                    }
                }
            }
            .sheet(isPresented: $showingImportPicker) {
                ImportPickerView(isPresented: $showingImportPicker, initialDirectory: importPickerInitialDirectory) { url in
                    print("🚀 [iCloud Debug] Start import from user selected file: \(url.path)")
                    iCloudManager.importFromFile(url: url)
                }
            }
            .sheet(isPresented: $showingDriveFolderPicker) {
                DriveFolderPickerView(isPresented: $showingDriveFolderPicker) { folderURL in
                    print("🗂️ [CloudDocs] Picked folder: \(folderURL.path)")
                    iCloudManager.savePreferredDriveDirectoryBookmark(from: folderURL)
                }
            }
            .sheet(isPresented: $iCloudManager.showingFilePicker) {
                FilePickerView(isPresented: $iCloudManager.showingFilePicker) { url in
                    iCloudManager.importFromFile(url: url)
                }
            }
            // 移除阻断式覆盖层，仅用 status 文案提示同步进度
            // 优先使用基于 URL 的 sheet(item:)，避免首帧为空
            .sheet(item: $shareURL, onDismiss: {
                shareURL = nil
            }) { item in
                ActivityView(activityItems: [ExportURLItemSource(url: item.url, fileName: item.url.lastPathComponent)]) { activityType, completed, _, error in
                    if let error = error {
                        exportLocalMessage = localizationManager.localized("export_failed_with_message") + ": " + error.localizedDescription
                        showingExportLocalResult = true
                    } else if completed {
                        exportLocalMessage = localizationManager.localized("export_file_success")
                        showingExportLocalResult = true
                    } else {
                        // 用户取消：不提示
                    }
                }
            }
            // 兼容旧的布尔开关路径（防御性保留）
            .sheet(isPresented: $showingShareSheet, onDismiss: {
                shareItems = []
            }) {
                ActivityView(activityItems: shareItems) { activityType, completed, _, error in
                    if let error = error {
                        exportLocalMessage = localizationManager.localized("export_failed_with_message") + ": " + error.localizedDescription
                        showingExportLocalResult = true
                    } else if completed {
                        exportLocalMessage = localizationManager.localized("export_file_success")
                        showingExportLocalResult = true
                    } else {
                        // 用户取消：不提示
                    }
                }
            }
            // 基于 Data 的分享（保留备用；当前主路径为 URL 文件分享）
            .sheet(item: $shareDataItem, onDismiss: { shareDataItem = nil }) { item in
                let jsonUTI: String = {
                    if #available(iOS 14.0, *) { return UTType.json.identifier } else { return "public.json" }
                }()
                let jsonItem = ExportDataItemSource(data: item.data, fileName: item.fileName, utiIdentifier: jsonUTI)
                ActivityView(activityItems: [jsonItem]) { activityType, completed, _, error in
                    if let error = error {
                        exportLocalMessage = localizationManager.localized("export_failed_with_message") + ": " + error.localizedDescription
                        showingExportLocalResult = true
                    } else if completed {
                        exportLocalMessage = localizationManager.localized("export_file_success")
                        showingExportLocalResult = true
                    } else {
                        // 用户取消：不提示
                    }
                }
            }
            .alert(localizationManager.localized("notice"), isPresented: $showingExportLocalResult) {
                Button(localizationManager.localized("confirm")) { }
            } message: {
                Text(exportLocalMessage)
            }
            // 兼容手动文件导入完成后的结果提示（由 iCloudSyncManager 产生）
            .alert(localizationManager.localized("import_result"), isPresented: $showingManagerImportResult) {
                Button(localizationManager.localized("confirm")) { }
            } message: {
                Text(managerImportMessage)
            }
            .onReceive(iCloudManager.$showingImportResult) { show in
                guard show else { return }
                let result = iCloudManager.importResult
                let msg = result?.description ?? localizationManager.localized("import_completed")
                managerImportMessage = msg
                showingManagerImportResult = true
                // 复位 manager 的提示开关，避免下次不触发
                iCloudManager.showingImportResult = false
            }
        }
    }
    
    private func importFromiCloud() {
        print("🚀 [iCloud Debug] Import with file picker; default folder = iCloud app folder")
        importPickerInitialDirectory = iCloudManager.preferredExportDirectory()
        showingImportPicker = true
    }

    private func exportToiCloud() {
        print("🚀 [iCloud Debug] Export with folder picker; default = iCloud app folder, data only")
        do {
            // 1) 只构建数据文件（使用统一命名规则）
            let tempURL = try writeExportToTemporaryFile()
            exportTempURLs = [tempURL]
            // 2) 设定初始目录为应用 iCloud Documents（带图标的文件夹）
            exportPickerInitialDirectory = iCloudManager.preferredExportDirectory()
            showingExportPicker = true
        } catch {
            self.errorMessage = localizationManager.localized("export_failed_with_message") + ": " + error.localizedDescription
            self.showingErrorAlert = true
        }
    }
    
    private func createiCloudDriveFolder() {
        print("🚀 [iCloud Drive] \("debug_icloud_folder_creating_print".localized)")
        iCloudManager.createiCloudDriveFolder { result in
            switch result {
            case .success():
                self.createFolderMessage = localizationManager.localized("create_folder_success_message")
                self.showingCreateFolderSuccessAlert = true
            case .failure(let error):
                self.errorMessage = String(format: localizationManager.localized("create_folder_failed_message"), error.localizedDescription)
                self.showingErrorAlert = true
            }
        }
    }

    struct ExportPickerView: UIViewControllerRepresentable {
        @Binding var isPresented: Bool
        let urls: [URL]
        let initialDirectory: URL?
        let onCompleted: (Bool) -> Void

        func makeCoordinator() -> Coordinator { Coordinator(self) }

        func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
            print("🔍 [iCloud Debug] Presenting picker forExporting = true, count=\(urls.count)")
            let picker = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
            // 优先引导到用户 iCloud Drive/CiteTrack；否则退回到传入初始目录
            if let userDir = iCloudSyncManager.shared.preferredUserDriveDirectory() {
                picker.directoryURL = userDir
                print("🔍 [iCloud Debug] picker.directoryURL(userDrive)=\(userDir.path)")
            } else if let dir = initialDirectory {
                picker.directoryURL = dir
                print("🔍 [iCloud Debug] picker.directoryURL(initial)=\(dir.path)")
            }
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

        class Coordinator: NSObject, UIDocumentPickerDelegate {
            let parent: ExportPickerView
            init(_ parent: ExportPickerView) { self.parent = parent }

            func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
                print("📝 [iCloud Debug] Export picker cancelled")
                parent.isPresented = false
                parent.onCompleted(false)
            }

            func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
                print("✅ [iCloud Debug] Exported to: \(urls.map { $0.path })")
                parent.isPresented = false
                parent.onCompleted(true)
            }
        }
    }

    private func exportToLocalDevice() {
        do {
            // 仅生成临时文件并分享；不持久化到应用 Documents
            let temp = try writeExportToTemporaryFile()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { self.shareURL = ShareItem(url: temp) }
        } catch {
            self.errorMessage = localizationManager.localized("export_failed_with_message") + ": " + error.localizedDescription
            self.showingErrorAlert = true
        }
    }

    // 生成导出数据并写入临时文件
    private func writeExportToTemporaryFile(filename: String = "") throws -> URL {
        let data = try makeExportJSONData()
        let date = Date()
        // 命名：CiteTrack_yyyyMMdd-HHmmss_v<appVersion>_<device>.json（本地时区）
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        df.locale = Locale(identifier: "en_US_POSIX")
        let ts = df.string(from: date)
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
        let device: String = {
            #if targetEnvironment(macCatalyst)
            return "macOS"
            #else
            switch UIDevice.current.userInterfaceIdiom {
            case .pad: return "iPad"
            case .phone: return "iPhone"
            default: return UIDevice.current.model.replacingOccurrences(of: " ", with: "")
            }
            #endif
        }()
        let defaultName = "CiteTrack_\(ts)_v\(appVersion)_\(device).json"
        let name = filename.isEmpty ? defaultName : filename
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: tempURL, options: [.atomic])
        return tempURL
    }

    // 从 DataManager 构建导出用 JSON（与导入格式兼容）
    private func makeExportJSONData() throws -> Data {
        let formatter = ISO8601DateFormatter()
        let scholars = DataManager.shared.scholars
        var exportEntries: [[String: Any]] = []

        for scholar in scholars {
            let histories = DataManager.shared.getHistory(for: scholar.id)
            if histories.isEmpty {
                if let citations = scholar.citations {
                    let ts = scholar.lastUpdated ?? Date()
                    exportEntries.append([
                        "scholarId": scholar.id,
                        "scholarName": scholar.displayName,
                        "timestamp": formatter.string(from: ts),
                        "citationCount": citations
                    ])
                }
            } else {
                for h in histories {
                    exportEntries.append([
                        "scholarId": scholar.id,
                        "scholarName": scholar.displayName,
                        "timestamp": formatter.string(from: h.timestamp),
                        "citationCount": h.citationCount
                    ])
                }
            }
        }
        return try JSONSerialization.data(withJSONObject: exportEntries, options: .prettyPrinted)
    }

    // 不再将导出文件持久化到 Documents/Exports，改为直接分享临时文件
    // 保留占位实现以兼容旧调用路径（若有），直接返回传入临时URL
    private func persistExportFile(fromTempURL tempURL: URL) throws -> URL { return tempURL }

    // 不再预热 Exports 目录
    private func prewarmExportsDirectory() { }

    struct ImportPickerView: UIViewControllerRepresentable {
        @Binding var isPresented: Bool
        let initialDirectory: URL?
        let onPicked: (URL) -> Void

        func makeCoordinator() -> Coordinator { Coordinator(self) }

        func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
            print("🔍 [iCloud Debug] Presenting picker forOpening (json), initialDir=\(initialDirectory?.path ?? "nil")")
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
            if let userDir = iCloudSyncManager.shared.preferredUserDriveDirectory() {
                picker.directoryURL = userDir
            } else if let dir = initialDirectory {
                picker.directoryURL = dir
            }
            picker.allowsMultipleSelection = false
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

        class Coordinator: NSObject, UIDocumentPickerDelegate {
            let parent: ImportPickerView
            init(_ parent: ImportPickerView) { self.parent = parent }

            func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
                print("📝 [iCloud Debug] Import picker cancelled")
                parent.isPresented = false
            }

            func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
                guard let url = urls.first else { return }
                parent.isPresented = false
                parent.onPicked(url)
            }
        }
    }

    private func chooseAndBookmarkDriveFolder() {
        print("🗂️ [CloudDocs] User choosing folder to bookmark …")
        showingDriveFolderPicker = true
    }

    private func clearBookmarkedDriveFolder() {
        print("🧹 [CloudDocs] Clear bookmarked folder")
        iCloudManager.clearPreferredDriveDirectoryBookmark()
    }

    struct DriveFolderPickerView: UIViewControllerRepresentable {
        @Binding var isPresented: Bool
        let onPickedFolder: (URL) -> Void

        func makeCoordinator() -> Coordinator { Coordinator(self) }

        func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
            // 通过 forOpening + 目录选择，选择器顶部有"选择"按钮可选中当前目录
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            // 将初始目录指向 iCloud Drive 根（com~apple~CloudDocs）
            if let root = iCloudSyncManager.shared.cloudDocsRootURL() {
                picker.directoryURL = root
            }
            picker.allowsMultipleSelection = false
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

        class Coordinator: NSObject, UIDocumentPickerDelegate {
            let parent: DriveFolderPickerView
            init(_ parent: DriveFolderPickerView) { self.parent = parent }

            func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
                print("📝 [CloudDocs] Folder picker cancelled")
                parent.isPresented = false
            }

            func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
                guard let url = urls.first else { return }
                print("✅ [CloudDocs] Picked folder: \(url.path)")
                parent.isPresented = false
                parent.onPickedFolder(url)
            }
        }
    }
}

// 添加学者视图
struct AddScholarView: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: (Scholar) -> Void
    @StateObject private var localizationManager = LocalizationManager.shared
    
    @State private var scholarId = ""
    @State private var scholarName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(localizationManager.localized("scholar_information")) {
                    HStack(spacing: 8) {
                        TextField(localizationManager.localized("google_scholar_id_placeholder"), text: $scholarId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.asciiCapable)
                        Button {
                            activeScannerPresented = true
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 20, weight: .medium))
                        }
                        .accessibilityLabel(localizationManager.localized("scan_scholar_id"))
                    }
                    
                    TextField(localizationManager.localized("scholar_name_placeholder"), text: $scholarName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(action: addScholar) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text(localizationManager.localized("add_scholar"))
                        }
                    }
                    .disabled(scholarId.isEmpty || isLoading)
                }
            }
            .navigationTitle(localizationManager.localized("add_scholar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $activeScannerPresented) {
                VisionTextScannerView { token in
                    // 尝试从识别文本中提取学者ID
                    if let extracted = GoogleScholarService.shared.extractScholarId(from: token) {
                        scholarId = extracted
                    } else {
                        scholarId = token
                    }
                    activeScannerPresented = false
                } onCancel: {
                    activeScannerPresented = false
                }
            }
        }
    }
    
    @State private var activeScannerPresented = false

    private func addScholar() {
        guard !scholarId.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        // 尝试从输入中提取学者ID（支持URL和纯ID）
        let extractedId = GoogleScholarService.shared.extractScholarId(from: scholarId)
        
        guard let finalScholarId = extractedId, !finalScholarId.isEmpty else {
            isLoading = false
            errorMessage = localizationManager.localized("invalid_scholar_id_or_url")
            return
        }
        
        // 使用Google Scholar Service获取真实的学者信息
        GoogleScholarService.shared.fetchScholarInfo(for: finalScholarId) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let info):
                    let name = self.scholarName.isEmpty ? info.name : self.scholarName
                    var newScholar = Scholar(id: finalScholarId, name: name)
                    newScholar.citations = info.citations
                    newScholar.lastUpdated = Date()
                    
                    self.onAdd(newScholar)
                    self.dismiss()
                    
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// 编辑学者视图
struct EditScholarView: View {
    @Environment(\.dismiss) var dismiss
    let scholar: Scholar
    let onSave: (Scholar) -> Void
    @StateObject private var localizationManager = LocalizationManager.shared
    
    @State private var scholarName: String
    @State private var hasChanges = false
    
    init(scholar: Scholar, onSave: @escaping (Scholar) -> Void) {
        self.scholar = scholar
        self.onSave = onSave
        self._scholarName = State(initialValue: scholar.name)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(localizationManager.localized("scholar_information")) {
                    HStack {
                        Text(localizationManager.localized("scholar_id"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(scholar.id)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizationManager.localized("scholar_name"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(localizationManager.localized("enter_scholar_name_placeholder"), text: $scholarName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: scholarName) {
                                hasChanges = scholarName != scholar.name
                            }
                    }
                }
                
                if let citations = scholar.citations {
                    Section(localizationManager.localized("citation_information")) {
                        HStack {
                            Text(localizationManager.localized("current_citations_label"))
                            Spacer()
                            Text("\(citations)")
                                .foregroundColor(.blue)
                        }
                        
                        if let lastUpdated = scholar.lastUpdated {
                            HStack {
                                Text(localizationManager.localized("last_updated_label"))
                                Spacer()
                                Text(lastUpdated.timeAgoString)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(localizationManager.localized("edit_scholar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localized("save")) {
                        saveScholar()
                    }
                    .disabled(!hasChanges || scholarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveScholar() {
        var updatedScholar = Scholar(id: scholar.id, name: scholarName.trimmingCharacters(in: .whitespacesAndNewlines))
        updatedScholar.citations = scholar.citations
        updatedScholar.lastUpdated = scholar.lastUpdated
        onSave(updatedScholar)
        dismiss()
    }
}

// 统计卡片组件
struct StatisticsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// 学者行组件
struct ScholarRow: View {
    let scholar: Scholar
    var subtitle: String? = nil
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(scholar.displayName)
                    .font(.headline)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    if let citations = scholar.citations {
                        Text("\(localizationManager.localized("citations_count")): \(citations)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(localizationManager.localized("no_data_available"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if let lastUpdated = scholar.lastUpdated {
                Text(lastUpdated.timeAgoString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// 新的学者行组件（合并图表和管理功能）
struct ScholarRowWithChartAndManagement: View {
    let scholar: Scholar
    let onChartTap: () -> Void
    let onUpdateTap: () -> Void
    let isLoading: Bool
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // 学者头像
            Circle()
                .fill(Color.blue)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(scholar.displayName.prefix(2)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // 学者信息
            VStack(alignment: .leading, spacing: 4) {
                Text(scholar.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                HStack {
                    Image(systemName: "quote.bubble.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    if let citations = scholar.citations {
                        Text("\(citations) " + localizationManager.localized("citations_display"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(localizationManager.localized("no_data"))
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
                
                if let lastUpdated = scholar.lastUpdated {
                    Text(localizationManager.localized("last_updated") + " \(lastUpdated.timeAgoString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 操作按钮组 - 靠近且右一点
            HStack(spacing: 0) {
                // 更新按钮
                Button(action: {
                    print("🔍 [Management Debug] \(String(format: "debug_management_update_tap_print".localized, scholar.displayName))")
                    onUpdateTap()
                }) {
                    VStack(spacing: 2) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(height: 16) // 固定高度确保对齐
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .frame(height: 16) // 固定高度确保对齐
                        }
                        
                        Text(localizationManager.localized("update"))
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoading)
                .frame(width: 50) // 固定宽度确保一致性
                
                // 图表按钮
                Button(action: {
                    print("🔍 [Chart Debug] \(String(format: "debug_chart_button_tap_print".localized, scholar.displayName))")
                    onChartTap()
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .frame(height: 16) // 固定高度确保对齐
                        
                        Text(localizationManager.localized("chart"))
                            .font(.caption2)
                            .foregroundColor(.green)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 50) // 固定宽度确保一致性
            }
            .padding(.trailing, 8) // 增加右侧内边距让按钮组更靠右
        }
        .padding(.vertical, 8)
    }
}

// 时间扩展
extension Date {
    var timeAgoString: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)
        let localizationManager = LocalizationManager.shared
        
        if interval < 60 {
            return localizationManager.localized("just_now")
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) " + localizationManager.localized("minutes_ago")
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) " + localizationManager.localized("hours_ago")
        } else if interval < 86400 * 7 {
            let days = Int(interval / 86400)
            return "\(days) " + localizationManager.localized("days_ago")
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: self)
        }
    }
}

// MARK: - File Picker View
struct FilePickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onFileSelected: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FilePickerView
        
        init(_ parent: FilePickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Failed to access security-scoped resource")
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            parent.onFileSelected(url)
            parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

// 通用分享面板封装
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    var onComplete: ((UIActivity.ActivityType?, Bool, [Any]?, Error?) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        vc.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            onComplete?(activityType, completed, returnedItems, error)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// 以 Data 作为分享项，提供 UTI 与文件名，避免 URL 打开慢及 -10814
final class ExportDataItemSource: NSObject, UIActivityItemSource {
    private let data: Data
    private let fileName: String
    private let utiIdentifier: String
    init(data: Data, fileName: String, utiIdentifier: String) { self.data = data; self.fileName = fileName; self.utiIdentifier = utiIdentifier }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return data
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return data
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return utiIdentifier
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return fileName
    }
}

// 使用 URL 作为分享项，提供显式 UTI 与标题，减少 LS 判定错误
final class ExportURLItemSource: NSObject, UIActivityItemSource {
    private let url: URL
    private let fileName: String
    init(url: URL, fileName: String) { self.url = url; self.fileName = fileName }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        if #available(iOS 14.0, *) { return UTType.json.identifier } else { return "public.json" }
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return fileName
    }
}

// MARK: - Scholar Chart Components

// 学者图表行视图
struct ScholarChartRow: View {
    let scholar: Scholar
    let onTap: () -> Void
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 学者头像
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(scholar.displayName.prefix(2)))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                // 学者信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(scholar.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack {
                        Image(systemName: "quote.bubble.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        if let citations = scholar.citations {
                            Text("\(citations) " + localizationManager.localized("citations_display"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text(localizationManager.localized("no_data_available"))
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if let lastUpdated = scholar.lastUpdated {
                        Text(localizationManager.localized("updated_at") + " \(lastUpdated.timeAgoString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 图表图标和箭头
                VStack(spacing: 4) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 学者图表详情视图
struct ScholarChartDetailView: View {
    let scholar: Scholar
    @StateObject private var localizationManager = LocalizationManager.shared
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeRange = 1 // 0: 近一周, 1: 近一月, 2: 近三月 - 默认选择近一月
    @State private var chartData: [ChartDataPoint] = []
    @State private var isLoading = true
    @State private var selectedDataPoint: ChartDataPoint? = nil // 选中的数据点
    @State private var isDragging = false // 是否正在拖动
    @State private var dragLocation: CGPoint? = nil // 拖动位置
    @State private var outerDragStartLocation: CGPoint? = nil // 外层手势起点
    @State private var chartFrame: CGRect = .zero // 图表区域在本视图坐标空间内的frame
    
    var timeRanges: [String] {
        return [
            localizationManager.localized("recent_week"),
            localizationManager.localized("recent_month"), 
            localizationManager.localized("recent_three_months")
        ]
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 学者头部信息
                    scholarHeaderView
                    
                    // 时间范围选择
                    timeRangeSelector
                    
                    // 图表区域
                    chartView
                    
                    // 选中数据点信息
                    if let selectedPoint = selectedDataPoint {
                        selectedDataPointView(selectedPoint)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    // 统计信息
                    statisticsView
                }
                .padding()
                .coordinateSpace(name: "chartSpace")
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            if outerDragStartLocation == nil {
                                outerDragStartLocation = value.startLocation
                            }
                        }
                        .onEnded { value in
                            defer { outerDragStartLocation = nil }
                            // 仅在未选中数据点时处理左右切换，避免与图表手势冲突
                            let start = outerDragStartLocation ?? value.startLocation
                            let startedInsideChart = chartFrame.contains(start)
                            // 若在图表外开始滑动，则无论是否选中数据点都允许切换
                            if selectedDataPoint != nil && startedInsideChart {
                                return
                            }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            // 加强水平滑动判定，避免与纵向滚动冲突
                            guard abs(dx) > abs(dy) * 1.2, abs(dx) > 60 else { return }
                            if dx < 0 {
                                moveTimeRangeSelection(offset: 1)
                            } else {
                                moveTimeRangeSelection(offset: -1)
                            }
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        }
                )
            }
            .navigationTitle(localizationManager.localized("citation_trend"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localized("close")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 重置状态并加载数据
                isLoading = true
                chartData = []
                selectedDataPoint = nil // 重置选中状态
                isDragging = false
                dragLocation = nil
                print("🔍 [Chart Debug] ScholarChartDetailView onAppear for: \(scholar.displayName)")
                loadRealHistoryData()
            }
            .onDisappear {
                // 清理状态
                isLoading = false
                chartData = []
                selectedDataPoint = nil
                isDragging = false
                dragLocation = nil
                print("🔍 [Chart Debug] ScholarChartDetailView onDisappear for: \(scholar.displayName)")
            }
        }
    }

    private func moveTimeRangeSelection(offset: Int) {
        let all = Array(0..<timeRanges.count)
        let currentIndex = selectedTimeRange
        let newIndex = min(max(currentIndex + offset, all.first ?? 0), (all.last ?? 0))
        if newIndex != currentIndex {
            withAnimation { selectedTimeRange = newIndex }
            // 选择变化后加载数据
            loadRealHistoryData()
        }
    }
    
    private var scholarHeaderView: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 60, height: 60)
                .overlay(
                    Text(String(scholar.displayName.prefix(2)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(spacing: 4) {
                Text(scholar.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let citations = scholar.citations {
                                            Text("\(citations) " + localizationManager.localized("total_citations_with_count"))
                        .font(.subheadline)
                        .foregroundColor(.blue)
                } else {
                                            Text(localizationManager.localized("no_citation_data_available"))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var timeRangeSelector: some View {
        Picker(localizationManager.localized("time_range"), selection: $selectedTimeRange) {
            ForEach(0..<timeRanges.count, id: \.self) { index in
                Text(timeRanges[index]).tag(index)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .onChange(of: selectedTimeRange) {
            loadRealHistoryData()
        }
    }
    
    private var chartView: some View {
        VStack(alignment: .leading, spacing: 8) {
                                    Text("\(scholar.displayName) - \(timeRanges[selectedTimeRange])" + localizationManager.localized("trend_suffix"))
                .font(.headline)
                .foregroundColor(.primary)
            
            if isLoading {
                // 加载状态
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(localizationManager.localized("loading_chart_data_message"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 160)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else if chartData.isEmpty {
                // 空数据状态
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text(localizationManager.localized("no_historical_data_message"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 160)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                // 实际图表
                GeometryReader { geometry in
                    VStack {
                        HStack(spacing: 8) { // 增加Y轴与图表间距
                            VStack(alignment: .trailing, spacing: 0) { // 改为垂直对齐Y轴标签
                                let maxValue = chartData.map(\.value).max() ?? 1
                                let minValue = chartData.map(\.value).min() ?? 0
                                let range = max(maxValue - minValue, 1)
                                
                                // 生成5个均匀分布的Y轴标签值
                                ForEach(0..<5, id: \.self) { i in
                                    let normalizedPosition = CGFloat(4 - i) / 4.0 // 从上到下
                                    let value = minValue + Int(normalizedPosition * Double(range))
                                    
                                    Text(formatNumber(value))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                        .frame(width: 55, alignment: .trailing)
                                        .frame(height: 32) // 固定每个标签高度为32，总高度160/5=32
                                }
                            }
                            .frame(width: 55) // 增加Y轴宽度以容纳4位有效数字（例如 1.081k）
                            
                            VStack {
                                ZStack {
                                    // 网格线
                                    Path { path in
                                        for i in 0...4 {
                                            let y = CGFloat(i) * 32 + 32 // 网格线往下移一格半，微调对齐位置
                                            path.move(to: CGPoint(x: 0, y: y))
                                            path.addLine(to: CGPoint(x: geometry.size.width - 90, y: y)) // 调整右边距匹配新Y轴宽度
                                        }
                                    }
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    
                                    // 折线图
                                    Path { path in
                                        if !chartData.isEmpty {
                                            let maxValue = chartData.map(\.value).max() ?? 1
                                            let minValue = chartData.map(\.value).min() ?? 0
                                            let range = max(maxValue - minValue, 1)
                                            let chartWidth = geometry.size.width - 90 // 调整宽度匹配新Y轴
                                            
                                            for (index, point) in chartData.enumerated() {
                                                let x = CGFloat(index) * (chartWidth / CGFloat(max(chartData.count - 1, 1)))
                                                let normalizedValue = CGFloat(point.value - minValue) / CGFloat(range)
                                                let y = 160 - (normalizedValue * 128) // 范围从32到160，与网格线精确匹配
                                                
                                                if index == 0 {
                                                    path.move(to: CGPoint(x: x, y: y))
                                                } else {
                                                    path.addLine(to: CGPoint(x: x, y: y))
                                                }
                                            }
                                        }
                                    }
                                    .stroke(Color.blue, lineWidth: 2)
                                    
                                    // 数据点
                                    ForEach(Array(chartData.enumerated()), id: \.element.id) { index, point in
                                        let maxValue = chartData.map(\.value).max() ?? 1
                                        let minValue = chartData.map(\.value).min() ?? 0
                                        let range = max(maxValue - minValue, 1)
                                        let chartWidth = geometry.size.width - 90 // 调整宽度匹配新Y轴
                                        let x = CGFloat(index) * (chartWidth / CGFloat(max(chartData.count - 1, 1)))
                                        let normalizedValue = CGFloat(point.value - minValue) / CGFloat(range)
                                        let y = 160 - (normalizedValue * 128) // 范围从32到160，与网格线精确匹配
                                        
                                        ZStack {
                                            // 选中时的外圈高亮
                                            if selectedDataPoint?.id == point.id {
                                                Circle()
                                                    .fill(Color.red.opacity(0.3))
                                                    .frame(width: 20, height: 20)
                                            }
                                            
                                            // 数据点
                                            Circle()
                                                .fill(selectedDataPoint?.id == point.id ? Color.red : Color.blue)
                                                .frame(width: selectedDataPoint?.id == point.id ? 12 : 10, height: selectedDataPoint?.id == point.id ? 12 : 10)
                                        }
                                        .position(x: x, y: y)
                                        .background(
                                            Circle()
                                                .fill(Color.clear)
                                                .frame(width: 30, height: 30)
                                        )
                                        .onTapGesture {
                                            selectDataPoint(point)
                                        }
                                    }
                                    
                                    // 拖动指示器
                                    if isDragging, let dragLoc = dragLocation {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 8, height: 8)
                                            .position(dragLoc)
                                    }
                                }
                                .frame(height: 160)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            isDragging = true
                                            dragLocation = value.location
                                            
                                            // 找到最近的数据点
                                            let closestPoint = findClosestDataPoint(to: value.location, in: geometry)
                                            if let closest = closestPoint {
                                                // 如果选中了新的数据点，提供震动反馈
                                                if selectedDataPoint?.id != closest.id {
                                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                                    impactFeedback.impactOccurred()
                                                }
                                                selectedDataPoint = closest
                                                print("🔍 [Chart Debug] \(String(format: "debug_drag_to_data_point_print".localized, "\(closest.value)"))")
                                            }
                                        }
                                        .onEnded { value in
                                            isDragging = false
                                            dragLocation = nil
                                            
                                            // 触觉反馈
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                            impactFeedback.impactOccurred()
                                            
                                            print("🔍 [Chart Debug] \(String(format: "debug_drag_end_print".localized, "\(selectedDataPoint?.value ?? 0)"))")
                                        }
                                )
                                
                                // X轴标签 - 优化显示减少省略号
                                HStack(spacing: 1) { // 减少标签间距
                                    ForEach(Array(chartData.enumerated()), id: \.element.id) { index, point in
                                        let shouldShow = chartData.count <= 8 ? (index % 2 == 0) : (index % 3 == 0) // 根据数据量动态调整显示密度
                                        
                                        if shouldShow {
                                            Text(DateFormatter.ultraShortDate.string(from: point.date))
                                                .font(.caption) // 使用适合的字体大小，避免省略号
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(1.0) // 不允许压缩，避免省略号
                                                .frame(maxWidth: .infinity) // 平均分布
                                                .multilineTextAlignment(.center)
                                        }
                                        // 移除隐藏标签的占位，让显示的标签有足够空间
                                    }
                                }
                                .offset(x: -20) // 整体往左移一格，调整横坐标位置
                                .padding(.top, 4) // 增加与图表的间距
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .onAppear {
                        chartFrame = geometry.frame(in: .named("chartSpace"))
                    }
                    .onChange(of: geometry.size) {
                        chartFrame = geometry.frame(in: .named("chartSpace"))
                    }
                }
                .frame(height: 200) // 固定高度
            }
        }
    }
    
    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizationManager.localized("statistics_info"))
                .font(.headline)
                .foregroundColor(.primary)
            
            if !chartData.isEmpty {
                let currentValue = chartData.last?.value ?? 0
                // 根据时间段计算对应的变化：近一周/近一月/近三月
                let periodDays = [7, 30, 90][selectedTimeRange]
                let (change, growth) = calculatePeriodChange(periodDays: periodDays)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatisticsCard(
                        title: localizationManager.localized("current_citations_stat"),
                        value: "\(currentValue)",
                        icon: "quote.bubble.fill",
                        color: .blue
                    )
                    
                    StatisticsCard(
                        title: localizationManager.localized("recent_change"),
                        value: change >= 0 ? "+\(change)" : "\(change)",
                        icon: change >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                        color: change >= 0 ? .green : .red
                    )
                    
                    StatisticsCard(
                        title: localizationManager.localized("growth_rate"),
                        value: String(format: "%.1f%%", growth),
                        icon: "percent",
                        color: growth >= 0 ? .green : .red
                    )
                    
                    StatisticsCard(
                        title: localizationManager.localized("data_points"),
                        value: "\(chartData.count)",
                        icon: "chart.dots.scatter",
                        color: .purple
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func calculatePeriodChange(periodDays: Int) -> (change: Int, growth: Double) {
        guard !chartData.isEmpty else { return (0, 0) }
        
        let currentValue = chartData.last?.value ?? 0
        
        // 找到对应时间段前的数据点
        let targetDate = Calendar.current.date(byAdding: .day, value: -periodDays, to: Date()) ?? Date()
        
        // 在chartData中找到最接近目标日期的数据点
        var previousValue = currentValue
        var minTimeDiff = TimeInterval.greatestFiniteMagnitude
        
        for dataPoint in chartData {
            let timeDiff = abs(dataPoint.date.timeIntervalSince(targetDate))
            if timeDiff < minTimeDiff {
                minTimeDiff = timeDiff
                previousValue = dataPoint.value
            }
        }
        
        // 如果没有找到合适的历史数据点，使用第一个数据点
        if minTimeDiff == TimeInterval.greatestFiniteMagnitude && !chartData.isEmpty {
            previousValue = chartData.first?.value ?? currentValue
        }
        
        let change = currentValue - previousValue
        let growth = previousValue > 0 ? Double(change) / Double(previousValue) * 100 : 0
        
        return (change, growth)
    }
    
    private func loadRealHistoryData() {
        // 设置加载状态
        isLoading = true
        
        // 计算时间范围
        let endDate = Date()
        let startDate: Date
        
        switch selectedTimeRange {
        case 0: // 近一周
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case 1: // 近一月
            startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        case 2: // 近三月
            startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate
        default:
            startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        }
        
        print("🔍 [Chart Debug] \(String(format: "debug_load_scholar_data_print".localized, scholar.displayName))")
        print("🔍 [Chart Debug] \(String(format: "debug_time_range_print".localized, "\(startDate)", "\(endDate)"))")
        
        // 从DataManager获取真实历史数据
        let histories = DataManager.shared.getHistory(for: scholar.id, from: startDate, to: endDate)
        
        print("🔍 [Chart Debug] \(String(format: "debug_histories_count_print".localized, histories.count))")
        
        DispatchQueue.main.async {
            // 转换为图表数据格式
            self.chartData = histories.map { history in
                ChartDataPoint(
                    date: history.timestamp,
                    value: history.citationCount
                )
            }.sorted { $0.date < $1.date }
            
            print("🔍 [Chart Debug] \(String(format: "debug_chart_data_count_print".localized, self.chartData.count))")
            
            // 如果没有历史数据，显示当前引用数作为单个数据点
            if self.chartData.isEmpty, let currentCitations = self.scholar.citations {
                print("🔍 [Chart Debug] \(String(format: "debug_no_history_data_print".localized, currentCitations))")
                self.chartData = [ChartDataPoint(
                    date: Date(),
                    value: currentCitations
                )]
            }
            
            // 结束加载状态
            self.isLoading = false
            
            print("✅ \(String(format: "debug_load_scholar_success_print".localized, self.scholar.displayName, self.chartData.count))")
        }
    }
    
    private func selectedDataPointView(_ point: ChartDataPoint) -> some View {
        VStack(alignment: .leading, spacing: 10) {
                            Text(localizationManager.localized("selected_data_point"))
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Text("\(localizationManager.localized("date_label")): \(DateFormatter.detailedDate.string(from: point.date))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(localizationManager.localized("citations_label")): \(point.value)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            if let lastUpdated = DataManager.shared.getHistory(for: scholar.id, days: 1).last?.timestamp {
                Text("\(localizationManager.localized("recent_update")): \(lastUpdated.timeAgoString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func findClosestDataPoint(to point: CGPoint, in geometry: GeometryProxy) -> ChartDataPoint? {
        let chartWidth = geometry.size.width - 90 // 调整宽度匹配新Y轴
        let chartHeight: CGFloat = 160 // 图表高度
        
        let x = point.x
        let y = chartHeight - point.y // 将Y坐标反转，使其与图表坐标系一致
        
        // 找到最近的点
        var closestPoint: ChartDataPoint? = nil
        var minDistance: CGFloat = CGFloat.infinity
        
        for (index, dataPoint) in chartData.enumerated() {
            let dataPointX = CGFloat(index) * (chartWidth / CGFloat(max(chartData.count - 1, 1)))
            let dataPointY = 160 - (CGFloat(dataPoint.value - minValue) / CGFloat(range) * 128) // 范围从32到160，与网格线精确匹配
            
            let distance = hypot(x - dataPointX, y - dataPointY)
            
            if distance < minDistance {
                minDistance = distance
                closestPoint = dataPoint
            }
        }
        
        return closestPoint
    }
    
    private var minValue: Int {
        chartData.map(\.value).min() ?? 0
    }
    
    private var range: Int {
        chartData.map(\.value).max() ?? 1
    }
    
    private func selectDataPoint(_ point: ChartDataPoint) {
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        print("🔍 [Chart Debug] \(String(format: "debug_data_point_tap_print".localized, "\(point.value)", "\(point.date)"))")
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedDataPoint?.id == point.id {
                selectedDataPoint = nil // 取消选中
                print("🔍 [Chart Debug] \("debug_deselect_data_point_print".localized)")
            } else {
                selectedDataPoint = point // 选中新点
                print("🔍 [Chart Debug] \(String(format: "debug_select_data_point_print".localized, "\(point.value)"))")
            }
        }
    }
}

// 图表数据点结构
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
}

// 数字格式化函数，显示4位有效数字
func formatNumber(_ number: Int) -> String {
    let absNumber = abs(number)
    
    // 根据数值大小选择单位和计算小数位数
    if absNumber >= 1_000_000_000 {
        // 十亿级别
        let value = Double(number) / 1_000_000_000
        let integerDigits = String(Int(abs(value))).count
        let decimalPlaces = max(0, 4 - integerDigits)
        return String(format: "%.\(decimalPlaces)fb", value)
    } else if absNumber >= 1_000_000 {
        // 百万级别
        let value = Double(number) / 1_000_000
        let integerDigits = String(Int(abs(value))).count
        let decimalPlaces = max(0, 4 - integerDigits)
        return String(format: "%.\(decimalPlaces)fm", value)
    } else if absNumber >= 1_000 {
        // 千级别：1.081k (1位整数+3位小数) 或 987.9k (3位整数+1位小数)
        let value = Double(number) / 1_000
        let integerDigits = String(Int(abs(value))).count
        let decimalPlaces = max(0, 4 - integerDigits)
        return String(format: "%.\(decimalPlaces)fk", value)
    } else {
        // 小于1000：直接显示整数
        return "\(number)"
    }
}

// 日期格式化器扩展
extension DateFormatter {
    static let relative: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }()
    
    static let ultraShortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d" // 更简洁的日期格式，减少字符数
        return formatter
    }()
    
    static let detailedDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

// (已移除) Simple 历史数据管理实现，统一由 DataManager 维护

// MARK: - Deep Link Notifications
extension Notification.Name {
    static let deepLinkAddScholar = Notification.Name("deepLinkAddScholar")
    static let deepLinkScholars = Notification.Name("deepLinkScholars")
    static let deepLinkDashboard = Notification.Name("deepLinkDashboard")
    static let deepLinkScholarDetail = Notification.Name("deepLinkScholarDetail")
    static let widgetRefreshTriggered = Notification.Name("widgetRefreshTriggered")
    static let widgetScholarSwitched = Notification.Name("widgetScholarSwitched")
    static let dismissTooltip = Notification.Name("dismissTooltip")
    static let userDataChanged = Notification.Name("userDataChanged")
}

// MARK: - Custom Contribution Chart
    struct CustomContributionChart: View {
        let data: [Double]
        let rows: Int
        let columns: Int
        
        @State private var availableWidth: CGFloat = 0
    @State private var selectedBlock: (row: Int, column: Int)? = nil
    @State private var showTooltip: Bool = false
     @State private var tooltipPosition: CGPoint = .zero
     @State private var displayTooltipPosition: CGPoint = .zero
     @State private var tooltipId: UUID = UUID()
     @State private var autoFadeTimer: Timer?
     @State private var scrollOffset: CGFloat = 0
        
        private let baseSpacing: CGFloat = 2.0
        
        private var blockSize: CGFloat {
            let totalSpacing = CGFloat(columns - 1) * baseSpacing
            let availableSpace = availableWidth - totalSpacing
            let calculatedSize = availableSpace / CGFloat(columns)
            
            // 计算最大允许的方块大小，确保7行不会超过250像素高度
            let maxHeight = 250.0
            let maxBlockSize = (maxHeight - CGFloat(rows - 1) * baseSpacing) / CGFloat(rows)
            
            // 进一步放大方块，但不超过高度限制
            return max(30, min(calculatedSize, min(45, maxBlockSize)))
        }
        
        var body: some View {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                    ZStack {
                        // 空白处点击区域
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if showTooltip {
                                    // 取消自动淡出定时器
                                    autoFadeTimer?.invalidate()
                                    autoFadeTimer = nil
                                    
                                    // 淡出弹窗
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                                        showTooltip = false
                                    }
                                    
                                    // 延迟取消选中状态，让淡出动画完成
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                                            selectedBlock = nil
                                        }
                                    }
                                }
                            }
                        
                VStack(spacing: baseSpacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        heatmapRow(row: row, geometry: geometry)
                    }
                }
                .frame(width: {
                    let cols = max(1, data.count / rows)
                    let width = CGFloat(cols) * blockSize + CGFloat(cols - 1) * baseSpacing
                    return width.isFinite && width > 0 ? width : 1
                }())
                    
                     // 工具提示
                    if showTooltip, let selected = selectedBlock {
                        tooltipView(for: selected)
                            .position(displayTooltipPosition)
                            .opacity(showTooltip ? 1 : 0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: showTooltip)
                            .id(tooltipId)
                    }
                    
                    // 调试信息显示 - 已注释
                    /*
                    if showTooltip, let selected = selectedBlock {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("debug_info_title_print".localized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            let blockX = CGFloat(selected.column) * (blockSize + baseSpacing) + blockSize / 2
                            let blockY = CGFloat(selected.row) * (blockSize + baseSpacing) + blockSize / 2
                            
                            Text(String(format: "debug_block_position_print".localized, String(format: "%.1f", blockX), String(format: "%.1f", blockY)))
                                .font(.caption2)
                                .foregroundColor(.white)
                            
                            Text(String(format: "debug_tooltip_position_print".localized, String(format: "%.1f", displayTooltipPosition.x), String(format: "%.1f", displayTooltipPosition.y)))
                                .font(.caption2)
                                .foregroundColor(.white)
                            
                            Text(String(format: "debug_column_row_print".localized, selected.column, selected.row))
                                .font(.caption2)
                                .foregroundColor(.white)
                            
                            Text(String(format: "debug_block_size_print".localized, String(format: "%.1f", blockSize)))
                                .font(.caption2)
                                .foregroundColor(.white)
                            
                            let index = selected.row * (data.count / rows) + selected.column
                                let value = index < data.count ? data[index] : 0.0
                            let refreshCount = Int(value * 10)
                            
                            Text(String(format: "debug_data_index_print".localized, index))
                                .font(.caption2)
                                .foregroundColor(.white)
                            
                            Text(String(format: "debug_refresh_count_print".localized, refreshCount))
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .position(x: geometry.size.width - 100, y: 50)
                    }
                    */
                     
                 }
                .frame(width: {
                    let cols = max(1, data.count / rows)
                    let width = CGFloat(cols) * blockSize + CGFloat(cols - 1) * baseSpacing
                    return width.isFinite && width > 0 ? width : 1
                }())
                }
                .background(
                    GeometryReader { contentGeometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, 
                                      value: contentGeometry.frame(in: .named("scrollContainer")).minX)
                    }
                )
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
                .onAppear {
                    availableWidth = geometry.size.width
                }
                .onChange(of: geometry.size.width) { _, newWidth in
                    availableWidth = newWidth
                }
            }
            .coordinateSpace(name: "scrollContainer")
            }
            .frame(height: min(CGFloat(rows) * blockSize + CGFloat(rows - 1) * baseSpacing, 250))
            .onReceive(NotificationCenter.default.publisher(for: .dismissTooltip)) { _ in
                // 接收到淡出通知时，立即淡出弹窗
                if showTooltip {
                    // 取消自动淡出定时器
                    autoFadeTimer?.invalidate()
                    autoFadeTimer = nil
                    
                    // 淡出弹窗
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                        showTooltip = false
                    }
                    
                    // 延迟取消选中状态，让淡出动画完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                            selectedBlock = nil
                        }
                    }
                }
            }
        }
    
    private func colorForValue(_ value: Double, isSelected: Bool = false) -> Color {
        let baseColor: Color
        let opacity: Double
        
        if value <= 0.0 {
            baseColor = Color(.systemGray5)
            opacity = 1.0
        } else if value <= 0.25 {
            baseColor = Color(.systemBlue)
            opacity = 0.4
        } else if value <= 0.5 {
            baseColor = Color(.systemBlue)
            opacity = 0.6
        } else if value <= 0.75 {
            baseColor = Color(.systemBlue)
            opacity = 0.8
        } else {
            baseColor = Color(.systemBlue)
            opacity = 1.0
        }
        
        // 选中时增加亮度和对比度
        if isSelected {
            return baseColor.opacity(min(opacity + 0.2, 1.0))
        } else {
            return baseColor.opacity(opacity)
        }
    }
    
    // MARK: - 交互处理方法
    private func handleBlockTap(row: Int, column: Int, geometry: GeometryProxy) {
        // 取消自动淡出定时器
        autoFadeTimer?.invalidate()
        autoFadeTimer = nil
        
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if selectedBlock?.row == row && selectedBlock?.column == column {
            // 取消选中 - 淡出动画
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                showTooltip = false
            }
            
            // 延迟取消选中状态，让淡出动画完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                    selectedBlock = nil
                }
            }
        } else {
            // 选中新方块 - 先淡出再弹出
            if selectedBlock != nil {
                // 先淡出当前弹窗
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                    showTooltip = false
                }
                
                // 延迟更新选中状态和位置，然后弹出新弹窗
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // 先更新选中状态和位置（不显示，无动画）
                    selectedBlock = (row: row, column: column)
                    updateTooltipPosition(geometry: geometry)
                    
                    // 更新显示位置和ID（无动画）
                    displayTooltipPosition = tooltipPosition
                    tooltipId = UUID()
                    
                    // 然后弹出新弹窗
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                        showTooltip = true
                    }
                    
                    // 启动自动淡出定时器
                    startAutoFadeTimer()
                }
            } else {
                // 直接弹出新弹窗
                selectedBlock = (row: row, column: column)
                updateTooltipPosition(geometry: geometry)
                displayTooltipPosition = tooltipPosition
                tooltipId = UUID()
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                    showTooltip = true
                }
                
                // 启动自动淡出定时器
                startAutoFadeTimer()
            }
        }
    }
    
    private func handleBlockLongPress(row: Int, column: Int, geometry: GeometryProxy) {
        // 取消自动淡出定时器
        autoFadeTimer?.invalidate()
        autoFadeTimer = nil
        
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if selectedBlock?.row == row && selectedBlock?.column == column {
            // 长按已选中的方块，不做任何操作
            return
        }
        
        // 选中新方块 - 先淡出再弹出
        if selectedBlock != nil {
            // 先淡出当前弹窗
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                showTooltip = false
            }
            
            // 延迟更新选中状态和位置，然后弹出新弹窗
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // 先更新选中状态和位置（不显示，无动画）
                selectedBlock = (row: row, column: column)
                updateTooltipPosition(geometry: geometry)
                
                // 更新显示位置和ID（无动画）
                displayTooltipPosition = tooltipPosition
                tooltipId = UUID()
                
                // 然后弹出新弹窗
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                    showTooltip = true
                }
                
                // 启动自动淡出定时器
                startAutoFadeTimer()
            }
        } else {
            // 直接弹出新弹窗
            selectedBlock = (row: row, column: column)
            updateTooltipPosition(geometry: geometry)
            displayTooltipPosition = tooltipPosition
            tooltipId = UUID()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                showTooltip = true
            }
            
            // 启动自动淡出定时器
            startAutoFadeTimer()
        }
    }
    
    private func updateTooltipPosition(geometry: GeometryProxy) {
        guard let selected = selectedBlock else { return }
        
        // 计算方块在屏幕上的位置
        let blockX = CGFloat(selected.column) * (blockSize + baseSpacing) + blockSize / 2
        let blockY = CGFloat(selected.row) * (blockSize + baseSpacing) + blockSize / 2
        
        // 智能弹窗位置判断，考虑左右边缘和上下边缘
        let totalColumns = data.count / rows
        
        var finalX = blockX
        var finalY = blockY
        
        // 左边缘判断：如果方块太靠左，弹窗往右移一格
        if selected.column <= 1 {
            finalX = blockX + (blockSize + baseSpacing) // 往右移一格
        }
        
        // 右边缘判断：如果方块太靠右，弹窗往左移一格
        if selected.column >= totalColumns - 2 {
            finalX = blockX - (blockSize + baseSpacing) // 往左移一格
        }
        
        // 上边缘判断：如果方块太靠上，弹窗往下移一格
        if selected.row <= 1 {
            finalY = blockY + (blockSize + baseSpacing) // 往下移一格
        }
        
        // 下边缘判断：如果方块太靠下，弹窗往上移一格
        if selected.row >= rows - 2 {
            finalY = blockY - (blockSize + baseSpacing) // 往上移一格
        }
        
        tooltipPosition = CGPoint(x: finalX, y: finalY)
        
        print("🔍 Debug: \(String(format: "debug_detailed_info_print".localized, "\(blockX)", "\(blockY)", "\(finalX)", "\(finalY)", "\(selected.column)", "\(totalColumns)", "\(selected.row)", "\(rows)"))")
    }
    
    // 处理空白处点击
    private func handleBackgroundTap() {
        if showTooltip {
            // 取消自动淡出定时器
            autoFadeTimer?.invalidate()
            autoFadeTimer = nil
            
            // 淡出弹窗
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                showTooltip = false
            }
            
            // 延迟取消选中状态，让淡出动画完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                    selectedBlock = nil
                }
            }
        }
    }
    
    // 启动自动淡出定时器
    private func startAutoFadeTimer() {
        autoFadeTimer?.invalidate()
        autoFadeTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                showTooltip = false
            }
            
            // 延迟取消选中状态，让淡出动画完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                    selectedBlock = nil
                }
            }
        }
    }
    
    // MARK: - 辅助函数
    private func calculateRefreshCount(for value: Double) -> Int {
        if value == 0.0 {
            return 0
        } else if value == 0.25 {
            return 1
        } else if value == 0.5 {
            return Int.random(in: 2...3)
        } else if value == 0.75 {
            return Int.random(in: 4...6)
        } else {
            return Int.random(in: 7...10)
        }
    }
    
    // MARK: - 工具提示视图
    // 计算热力图中指定位置的日期
    // 从上到下+1天，从左到右+1周
    private func getDateForHeatmapPosition(row: Int, column: Int) -> Date {
        return UserBehaviorManager.shared.getDateForHeatmapPosition(row: row, column: column)
    }
    
    private func getDataStartDate() -> Date { UserBehaviorManager.shared.getDateForHeatmapPosition(row: 0, column: 0) }
    
    @ViewBuilder
    private func tooltipView(for selected: (row: Int, column: Int)) -> some View {
        // 获取日期与刷新次数（来自行为管理器）
        let targetDate = getDateForHeatmapPosition(row: selected.row, column: selected.column)
        let refreshCount: Int = UserBehaviorManager.shared.refreshCount(on: targetDate)
        
        let dateString = formatDateForTooltip(targetDate)
        
        VStack(spacing: 6) {
            // 刷新次数显示
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                Text(String(format: "refresh_count_display_print".localized, refreshCount))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // 日期显示
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(dateString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // 主背景 - 更亮的白色
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.9))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.8), Color.white.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                
                // 白色发光效果
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 2)
            }
        )
        .scaleEffect(showTooltip ? 1.0 : 0.3)
        .opacity(showTooltip ? 1.0 : 0.0)
        .offset(y: showTooltip ? 0 : 20)
        .shadow(color: Color.gray.opacity(0.15), radius: 2, x: 0, y: 1)
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: showTooltip)
    }
    
    private func formatDateForTooltip(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Heatmap Row Helper
    @ViewBuilder
    private func heatmapRow(row: Int, geometry: GeometryProxy) -> some View {
        HStack(spacing: baseSpacing) {
            ForEach(0..<(data.count / rows), id: \.self) { column in
                // 列优先索引：列=周，行为天
                let index = column * rows + row
                let value = index < data.count ? data[index] : 0.0
                let isSelected = selectedBlock?.row == row && selectedBlock?.column == column
                
                Rectangle()
                    .fill(colorForValue(value, isSelected: isSelected))
                    .frame(width: blockSize, height: blockSize)
                    .cornerRadius(max(1, blockSize * 0.15))
                    .overlay(
                        // 选中时的发光边框
                        RoundedRectangle(cornerRadius: max(1, blockSize * 0.15))
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.9), Color.white.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2 : 0
                            )
                    )
                    .shadow(
                        color: isSelected ? Color.white.opacity(0.8) : Color.clear,
                        radius: isSelected ? 8 : 0,
                        x: 0,
                        y: isSelected ? 4 : 0
                    )
                    .shadow(
                        color: isSelected ? Color.white.opacity(0.6) : Color.clear,
                        radius: isSelected ? 12 : 0,
                        x: 0,
                        y: isSelected ? 6 : 0
                    )
                    .shadow(
                        color: isSelected ? Color.white.opacity(0.4) : Color.clear,
                        radius: isSelected ? 16 : 0,
                        x: 0,
                        y: isSelected ? 8 : 0
                    )
                    .scaleEffect(isSelected ? 1.15 : 1.0)
                    .offset(y: isSelected ? -2 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0), value: isSelected)
                    .onTapGesture {
                        handleBlockTap(row: row, column: column, geometry: geometry)
                    }
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                // 阻止事件传播到父级
                            }
                    )
                    .onLongPressGesture(minimumDuration: 0.1) {
                        handleBlockLongPress(row: row, column: column, geometry: geometry)
                    }
            }
        }
    }
}