import Foundation
import Combine
import BackgroundTasks
import WidgetKit

// MARK: - Auto Update Manager
public class AutoUpdateManager: ObservableObject {
    public static let shared = AutoUpdateManager()
    
    @Published public var isUpdating = false
    @Published public var lastUpdateDate: Date?
    @Published public var nextUpdateDate: Date?
    
    private let settingsManager = SettingsManager.shared
    private let dataManager = DataManager.shared
    private let googleScholarService = GoogleScholarService.shared
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
        scheduleNextUpdate()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // 监听自动更新设置变化
        settingsManager.$autoUpdateEnabled
            .sink { [weak self] enabled in
                // 避免在视图更新周期内直接发布 @Published 变更
                DispatchQueue.main.async {
                    if enabled {
                        self?.startAutoUpdate()
                    } else {
                        self?.stopAutoUpdate()
                    }
                }
            }
            .store(in: &cancellables)
        
        settingsManager.$autoUpdateFrequency
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    if self?.settingsManager.autoUpdateEnabled == true {
                        self?.scheduleNextUpdate()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Auto Update Control
    
    public func startAutoUpdate() {
        guard settingsManager.autoUpdateEnabled else { return }
        
        stopAutoUpdate() // 停止现有的定时器
        
        // 先计算下次更新时间
        scheduleNextUpdate()
        
        // 根据下次更新时间设置定时器
        if let nextUpdate = nextUpdateDate {
            let timeInterval = nextUpdate.timeIntervalSinceNow
            if timeInterval > 0 {
                updateTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                    Task {
                        await self?.performAutoUpdate()
                    }
                }
                print("🔄 [AutoUpdateManager] \(String(format: "debug_auto_update_started".localized, nextUpdate.description))")
            } else {
                // 如果设置的时间已过期，立即执行更新
                Task {
                    await performAutoUpdate()
                }
            }
        }
    }
    
    public func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
        print("⏹️ [AutoUpdateManager] \("debug_auto_update_stopped".localized)")
    }
    
    // MARK: - Update Scheduling
    
    private func scheduleNextUpdate() {
        guard settingsManager.autoUpdateEnabled else {
            DispatchQueue.main.async { [weak self] in
                self?.nextUpdateDate = nil
                self?.settingsManager.nextUpdateDate = nil
            }
            return
        }
        
        // 如果用户手动设置了下次更新时间，使用用户设置的时间
        if let userSetTime = settingsManager.nextUpdateDate, userSetTime > Date() {
            DispatchQueue.main.async { [weak self] in
                self?.nextUpdateDate = userSetTime
            }
            print("📅 [AutoUpdateManager] 使用用户设置的下次更新时间: \(userSetTime)")
            return
        }
        
        // 否则按照频率计算下次更新时间
        let now = Date()
        let interval = settingsManager.autoUpdateFrequency.timeInterval
        let nextUpdate = now.addingTimeInterval(interval)
        
        DispatchQueue.main.async { [weak self] in
            self?.nextUpdateDate = nextUpdate
            self?.settingsManager.nextUpdateDate = nextUpdate
        }
        
        print("📅 [AutoUpdateManager] 按频率计算的下次更新时间: \(nextUpdate)")
    }
    
    // MARK: - Update Execution
    
    @MainActor
    public func performAutoUpdate() async {
        guard !isUpdating else {
            print("⚠️ [AutoUpdateManager] 更新正在进行中，跳过本次更新")
            return
        }
        
        isUpdating = true
        lastUpdateDate = Date()
        
        print("🔄 [AutoUpdateManager] 开始自动更新所有学者数据")
        
        let scholars = dataManager.scholars
        guard !scholars.isEmpty else {
            print("ℹ️ [AutoUpdateManager] 没有学者需要更新")
            isUpdating = false
            scheduleNextUpdate()
            return
        }
        
        var successCount = 0
        let totalCount = scholars.count
        
        for scholar in scholars {
            let result = await withCheckedContinuation { continuation in
                googleScholarService.fetchScholarInfo(for: scholar.id) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch result {
            case .success(let (name, citations)):
                var updatedScholar = Scholar(id: scholar.id, name: name)
                updatedScholar.citations = citations
                updatedScholar.lastUpdated = Date()
                
                dataManager.updateScholar(updatedScholar)
                dataManager.saveHistoryIfChanged(
                    scholarId: scholar.id,
                    citationCount: citations
                )
                
                successCount += 1
                print("✅ [AutoUpdateManager] 成功更新学者: \(name) - \(citations) citations")
                
            case .failure(let error):
                print("❌ [AutoUpdateManager] 更新学者失败 \(scholar.id): \(error.localizedDescription)")
            }
            
            // 添加延迟避免请求过于频繁
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        print("✅ [AutoUpdateManager] 自动更新完成: \(successCount)/\(totalCount) 位学者")
        
        // 通知小组件更新
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        
        isUpdating = false
        scheduleNextUpdate()
    }
    
    // MARK: - Manual Update
    
    @MainActor
    public func performManualUpdate() async {
        print("🔄 [AutoUpdateManager] 开始手动更新所有学者数据")
        await performAutoUpdate()
    }
    
    // MARK: - Background Task Support
    
    public func scheduleBackgroundUpdate() {
        let request = BGAppRefreshTaskRequest(identifier: "com.citetrack.autoUpdate")
        request.earliestBeginDate = nextUpdateDate ?? Date().addingTimeInterval(3600) // 默认1小时后
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📱 [AutoUpdateManager] 后台更新任务已安排")
        } catch {
            print("❌ [AutoUpdateManager] 安排后台更新任务失败: \(error)")
        }
    }
    
    // MARK: - Public Helpers
    
    public func getNextUpdateTimeString() -> String {
        guard let nextUpdate = nextUpdateDate else {
            return "未设置"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        
        return formatter.string(from: nextUpdate)
    }
    
    public func isAutoUpdateEnabled() -> Bool {
        return settingsManager.autoUpdateEnabled
    }
    
    public func getUpdateFrequency() -> AutoUpdateFrequency {
        return settingsManager.autoUpdateFrequency
    }
}
