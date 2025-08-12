import SwiftUI
import WidgetKit

// MARK: - Import Constants for App Group Identifier
// Constants.swift 应当被添加到 Widget Extension target 的成员中
import Foundation

// MARK: - Widget配置和大小枚举
enum WidgetDisplayMode: String, CaseIterable, Codable {
    case featured = "featured"      // Small: 特色学者
    case comparison = "comparison"  // Medium: 学者对比
    case dashboard = "dashboard"    // Large: 完整仪表板
    
    var displayName: String {
        switch self {
        case .featured: return "特色学者"
        case .comparison: return "学者对比"
        case .dashboard: return "完整仪表板"
        }
    }
}

// MARK: - Widget配置数据
struct WidgetConfig: Codable {
    let selectedScholarId: String?
    let displayMode: WidgetDisplayMode
    let showTrend: Bool
    let lastUpdated: Date
    
    init(selectedScholarId: String? = nil, displayMode: WidgetDisplayMode = .featured, showTrend: Bool = true) {
        self.selectedScholarId = selectedScholarId
        self.displayMode = displayMode
        self.showTrend = showTrend
        self.lastUpdated = Date()
    }
    
    static let `default` = WidgetConfig()
}

// MARK: - Widget配置管理器
class WidgetConfigurationManager {
    static let shared = WidgetConfigurationManager()
    private let configKey = "WidgetConfiguration"
    
    private init() {}
    
    func getConfiguration() -> WidgetConfig {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: configKey),
              let config = try? JSONDecoder().decode(WidgetConfig.self, from: data) else {
            return .default
        }
        return config
    }
    
    func saveConfiguration(_ config: WidgetConfig) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? JSONEncoder().encode(config) else {
            return
        }
        defaults.set(data, forKey: configKey)
    }
    
    func updateSelectedScholar(_ scholarId: String) {
        let config = getConfiguration()
        let newConfig = WidgetConfig(
            selectedScholarId: scholarId,
            displayMode: config.displayMode,
            showTrend: config.showTrend
        )
        saveConfiguration(newConfig)
    }
}