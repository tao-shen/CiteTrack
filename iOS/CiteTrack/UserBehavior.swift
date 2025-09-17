//
//  UserBehavior.swift
//  CiteTrack
//
//  Created by Local Integration on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - 用户行为数据模型
struct UserBehavior: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let refreshCount: Int
    let scholarSwitchCount: Int
    let appOpenCount: Int
    let lastUpdated: Date
    
    init(id: UUID = UUID(), 
         date: Date, 
         refreshCount: Int = 0, 
         scholarSwitchCount: Int = 0, 
         appOpenCount: Int = 0, 
         lastUpdated: Date = Date()) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date) // 标准化为当天开始时间
        self.refreshCount = refreshCount
        self.scholarSwitchCount = scholarSwitchCount
        self.appOpenCount = appOpenCount
        self.lastUpdated = lastUpdated
    }
    
    // MARK: - 验证
    func isValid() -> Bool {
        return refreshCount >= 0 && scholarSwitchCount >= 0 && appOpenCount >= 0
    }
    
    // MARK: - 获取总活动分数（用于热力图显示）
    var activityScore: Double {
        // 刷新次数权重最高，学者切换次之，应用打开次数最低
        let refreshWeight = 1.0
        let switchWeight = 0.5
        let openWeight = 0.2
        
        let totalScore = Double(refreshCount) * refreshWeight + 
                        Double(scholarSwitchCount) * switchWeight + 
                        Double(appOpenCount) * openWeight
        
        // 将分数标准化到 0-1 范围，使用对数缩放来更好地分布数据
        if totalScore == 0 {
            return 0.0
        } else if totalScore <= 1 {
            return 0.25
        } else if totalScore <= 3 {
            return 0.5
        } else if totalScore <= 6 {
            return 0.75
        } else {
            return 1.0
        }
    }
}

// MARK: - 用户行为管理器
class UserBehaviorManager: ObservableObject {
    static let shared = UserBehaviorManager()
    
    @Published private var behaviors: [UserBehavior] = []
    private let userDefaults = UserDefaults.standard
    private let appGroupDefaults = UserDefaults(suiteName: "group.com.citetrack.CiteTrack")
    private let behaviorsKey = "UserBehaviors"
    private let installDateKey = "AppInstallDate"
    
    // 应用安装日期
    private var installDate: Date {
        get {
            if let savedDate = userDefaults.object(forKey: installDateKey) as? Date {
                return savedDate
            } else {
                // 如果是第一次启动，记录当前日期为安装日期
                let today = Date()
                userDefaults.set(today, forKey: installDateKey)
                appGroupDefaults?.set(today, forKey: installDateKey)
                return today
            }
        }
    }
    
    private init() {
        loadBehaviors()
    }
    
    // MARK: - 数据持久化
    private func loadBehaviors() {
        if let data = appGroupDefaults?.data(forKey: behaviorsKey) ?? userDefaults.data(forKey: behaviorsKey),
           let decoded = try? JSONDecoder().decode([UserBehavior].self, from: data) {
            behaviors = decoded
        }
    }
    
    private func saveBehaviors() {
        if let data = try? JSONEncoder().encode(behaviors) {
            appGroupDefaults?.set(data, forKey: behaviorsKey)
            appGroupDefaults?.synchronize()
            userDefaults.set(data, forKey: behaviorsKey)
            // 通知UI数据已变更（热力图刷新）
            if Thread.isMainThread {
                NotificationCenter.default.post(name: Notification.Name("userDataChanged"), object: nil)
            } else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("userDataChanged"), object: nil)
                }
            }
        }
    }
    
    // MARK: - 行为记录
    func recordRefresh() {
        let today = Date()
        updateOrCreateBehavior(for: today) { behavior in
            UserBehavior(
                id: behavior.id,
                date: behavior.date,
                refreshCount: behavior.refreshCount + 1,
                scholarSwitchCount: behavior.scholarSwitchCount,
                appOpenCount: behavior.appOpenCount,
                lastUpdated: today
            )
        }
    }
    
    func recordScholarSwitch() {
        let today = Date()
        updateOrCreateBehavior(for: today) { behavior in
            UserBehavior(
                id: behavior.id,
                date: behavior.date,
                refreshCount: behavior.refreshCount,
                scholarSwitchCount: behavior.scholarSwitchCount + 1,
                appOpenCount: behavior.appOpenCount,
                lastUpdated: today
            )
        }
    }
    
    func recordAppOpen() {
        let today = Date()
        updateOrCreateBehavior(for: today) { behavior in
            UserBehavior(
                id: behavior.id,
                date: behavior.date,
                refreshCount: behavior.refreshCount,
                scholarSwitchCount: behavior.scholarSwitchCount,
                appOpenCount: behavior.appOpenCount + 1,
                lastUpdated: today
            )
        }
    }
    
    // MARK: - 辅助方法
    private func updateOrCreateBehavior(for date: Date, update: (UserBehavior) -> UserBehavior) {
        let today = Calendar.current.startOfDay(for: date)
        
        if let index = behaviors.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            behaviors[index] = update(behaviors[index])
        } else {
            let newBehavior = UserBehavior(date: today)
            behaviors.append(update(newBehavior))
        }
        
        // 清理旧数据（保留最近140天的数据）
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -140, to: today) ?? today
        behaviors = behaviors.filter { $0.date >= cutoffDate }
        
        saveBehaviors()
    }
    
    // MARK: - 数据查询
    func getBehaviorsForLastDays(_ days: Int) -> [UserBehavior] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        return behaviors.filter { behavior in
            behavior.date >= startDate && behavior.date <= endDate
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - 批量导入刷新数据（按天覆盖）
    /// 以 yyyy-MM-dd: count 的字典形式导入每日手动刷新次数。
    /// 会直接设置当天的 refreshCount（覆盖），然后保存。
    func importRefreshData(_ map: [String: Int]) {
        // 确保在主线程更新 @Published 状态与通知
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.importRefreshData(map)
            }
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var updated: [UserBehavior] = behaviors
        let cal = Calendar.current
        for (day, count) in map {
            guard let date = formatter.date(from: day) else { continue }
            let dayStart = cal.startOfDay(for: date)
            if let idx = updated.firstIndex(where: { cal.isDate($0.date, inSameDayAs: dayStart) }) {
                updated[idx] = UserBehavior(
                    id: updated[idx].id,
                    date: dayStart,
                    refreshCount: max(0, count),
                    scholarSwitchCount: updated[idx].scholarSwitchCount,
                    appOpenCount: updated[idx].appOpenCount,
                    lastUpdated: Date()
                )
            } else {
                updated.append(UserBehavior(date: dayStart, refreshCount: max(0, count)))
            }
        }
        behaviors = updated.sorted { $0.date < $1.date }
        saveBehaviors()
    }
    
    /// 获取某一天的手动刷新次数
    func refreshCount(on date: Date) -> Int {
        let dayStart = Calendar.current.startOfDay(for: date)
        return behaviors.first(where: { Calendar.current.isDate($0.date, inSameDayAs: dayStart) })?.refreshCount ?? 0
    }
    
    func getActivityScoresForLastDays(_ days: Int) -> [Double] {
        let behaviors = getBehaviorsForLastDays(days)
        return behaviors.map { $0.activityScore }
    }
    
    // MARK: - 统计信息
    func getTotalRefreshCount() -> Int {
        return behaviors.reduce(0) { $0 + $1.refreshCount }
    }
    
    func getAverageDailyRefreshCount() -> Double {
        guard !behaviors.isEmpty else { return 0.0 }
        let totalRefresh = behaviors.reduce(0) { $0 + $1.refreshCount }
        return Double(totalRefresh) / Double(behaviors.count)
    }
    
    func getMostActiveDay() -> UserBehavior? {
        return behaviors.max { $0.refreshCount < $1.refreshCount }
    }
    
    // MARK: - 热力图数据
    func getHeatmapData() -> [Double] {
        let calendar = Calendar.current
        let install = installDate
        
        // 热力图显示最近364天（52周 x 7天）
        let maxDays = 364
        
        var data: [Double] = []
        
        // 从安装当天开始，左到右每列一周、上到下加一天
        // 列数固定 20（20周），行数 7（周一到周日）
        let startDate = Calendar.current.startOfDay(for: install)
        for i in 0..<maxDays {
            let targetDate = calendar.date(byAdding: .day, value: i, to: startDate) ?? startDate
            let dayStart = calendar.startOfDay(for: targetDate)
            
            // 查找当天的行为数据
            if let behavior = behaviors.first(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) {
                // 根据手动刷新次数计算热力图强度
                let refreshCount = behavior.refreshCount
                let intensity: Double
                
                if refreshCount == 0 {
                    intensity = 0.0
                } else if refreshCount == 1 {
                    intensity = 0.25
                } else if refreshCount <= 3 {
                    intensity = 0.5
                } else if refreshCount <= 6 {
                    intensity = 0.75
                } else {
                    intensity = 1.0
                }
                
                data.append(intensity)
            } else {
                // 没有数据的天数显示为0
                data.append(0.0)
            }
        }
        
        return data
    }
    
    // 获取热力图中指定位置的日期
    func getDateForHeatmapPosition(row: Int, column: Int) -> Date {
        let calendar = Calendar.current
        let install = installDate
        // 旧逻辑保留注释，现不再使用本段 startDate 变量
        
        // 计算目标日期：左上角为安装当日，向下+1天，向右+1周
        let startDate = calendar.startOfDay(for: install)
        let daysFromTop = row
        let weeksFromLeft = column
        let offset = weeksFromLeft * 7 + daysFromTop
        return calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
    }
}
 
