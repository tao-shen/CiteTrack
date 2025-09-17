//
//  UserDataManager.swift
//  CiteTrack
//
//  Created by Local Integration on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

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

// MARK: - 用户数据管理器
class UserDataManager: ObservableObject {
    static let shared = UserDataManager()
    
    @Published private var userData: UserData?
    private let fileName = "user_data.json"
    
    private init() {
        loadUserData()
    }
    
    // MARK: - 数据加载
    private func loadUserData() {
        guard let url = getFileURL() else { return }
        
        do {
            let data = try Data(contentsOf: url)
            userData = try JSONDecoder().decode(UserData.self, from: data)
        } catch {
            print("Failed to load user data: \(error)")
            // 如果加载失败，创建默认数据
            createDefaultUserData()
        }
    }
    
    private func createDefaultUserData() {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        userData = UserData(
            userId: "default_user",
            data: [formatter.string(from: today): 0],
            lastUpdated: ISO8601DateFormatter().string(from: today)
        )
    }
    
    // MARK: - 数据保存
    private func saveUserData() {
        guard let userData = userData,
              let url = getFileURL() else { return }
        
        do {
            let data = try JSONEncoder().encode(userData)
            try data.write(to: url)
            // 通知UI数据已变更
            NotificationCenter.default.post(name: .userDataChanged, object: nil)
        } catch {
            print("Failed to save user data: \(error)")
        }
    }
    
    // MARK: - 文件路径
    private func getFileURL() -> URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsPath.appendingPathComponent(fileName)
    }
    
    // MARK: - 公共接口
    
    /// 记录一次刷新
    func recordRefresh() {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: today)
        
        if userData == nil {
            createDefaultUserData()
        }
        
        guard var data = userData else { return }
        
        // 增加当天的刷新次数
        let currentCount = data.data[dateString] ?? 0
        data.data[dateString] = currentCount + 1
        
        // 更新最后更新时间
        data.lastUpdated = ISO8601DateFormatter().string(from: today)
        
        userData = data
        saveUserData()
    }
    
    /// 获取指定日期的刷新次数
    func getRefreshCount(for date: Date) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        return userData?.data[dateString] ?? 0
    }
    
    /// 获取热力图数据（最近365天）
    func getHeatmapData() -> [Double] {
        guard let data = userData else { return [] }
        
        let calendar = Calendar.current
        let today = Date()
        var heatmapData: [Double] = []
        
        // 生成最近365天的数据
        for i in 0..<365 {
            let targetDate = calendar.date(byAdding: .day, value: -364 + i, to: today) ?? today
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: targetDate)
            
            let refreshCount = data.data[dateString] ?? 0
            let intensity = calculateIntensity(for: refreshCount)
            heatmapData.append(intensity)
        }
        
        return heatmapData
    }
    
    /// 获取指定位置的日期
    func getDateForPosition(index: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        return calendar.date(byAdding: .day, value: -364 + index, to: today) ?? today
    }
    
    /// 根据刷新次数计算热力图强度
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
    
    /// 获取总刷新次数
    func getTotalRefreshCount() -> Int {
        return userData?.data.values.reduce(0, +) ?? 0
    }
    
    /// 导出刷新数据为字典（用于 iCloud ios_data.json）
    func exportRefreshData() -> [String: Any] {
        guard let userData = userData else {
            return [
                "user_id": "default_user",
                "data": [:],
                "last_updated": ISO8601DateFormatter().string(from: Date())
            ]
        }
        return [
            "user_id": userData.userId,
            "data": userData.data,
            "last_updated": userData.lastUpdated
        ]
    }

    /// 从字典导入刷新数据并合并（同日求和策略）
    func importRefreshData(from dict: [String: Any]) {
        guard let importedData = dict["data"] as? [String: Int] else { return }
        var current = userData
        if current == nil { createDefaultUserData(); current = userData }
        guard var data = current else { return }
        var merged = data.data
        for (day, count) in importedData {
            let local = merged[day] ?? 0
            merged[day] = max(0, local + count)
        }
        data = UserData(
            userId: (dict["user_id"] as? String) ?? data.userId,
            data: merged,
            lastUpdated: dict["last_updated"] as? String ?? ISO8601DateFormatter().string(from: Date())
        )
        userData = data
        saveUserData()
    }
    
    /// 获取最活跃的日期
    func getMostActiveDate() -> (date: String, count: Int)? {
        guard let data = userData,
              let maxEntry = data.data.max(by: { $0.value < $1.value }) else {
            return nil
        }
        return (date: maxEntry.key, count: maxEntry.value)
    }
}

extension Notification.Name {
    static let userDataChanged = Notification.Name("userDataChanged")
}
