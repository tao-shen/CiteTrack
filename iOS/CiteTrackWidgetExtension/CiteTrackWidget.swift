import SwiftUI
import WidgetKit
import AppIntents

// MARK: - 数字格式化扩展
extension Int {
    var formattedNumber: String {
        if self >= 1000000 {
            return String(format: "%.1fm", Double(self) / 1000000.0)
        } else if self >= 1000 {
            return String(format: "%.1fk", Double(self) / 1000.0)
        } else {
            return String(self)
        }
    }
}

// MARK: - 字符串智能缩写扩展
extension String {
    var smartAbbreviated: String {
        let components = self.split(separator: " ").map(String.init)
        guard components.count > 1 else { return self }
        
        // 如果只有两个词，保持原样
        if components.count == 2 {
            return self
        }
        
        // 多个词的情况：缩写除了最后一个词之外的所有词
        let abbreviatedComponents = components.dropLast().map { word in
            String(word.prefix(1)) + "."
        }
        
        let lastName = components.last ?? ""
        return (abbreviatedComponents + [lastName]).joined(separator: " ")
    }
    
    var adaptiveAbbreviated: String {
        let components = self.split(separator: " ").map(String.init)
        guard components.count > 1 else { return self }
        
        // 如果总长度较短，直接返回
        if self.count <= 12 {
            return self
        }
        
        // 如果只有两个词且较长，缩写第一个词
        if components.count == 2 {
            let firstName = components[0]
            let lastName = components[1]
            return "\(firstName.prefix(1)). \(lastName)"
        }
        
        // 多个词的情况：缩写除了最后一个词之外的所有词
        let abbreviatedComponents = components.dropLast().map { word in
            String(word.prefix(1)) + "."
        }
        
        let lastName = components.last ?? ""
        return (abbreviatedComponents + [lastName]).joined(separator: " ")
    }
}

// MARK: - 乔布斯式极简数据模型
struct WidgetScholarInfo: Codable {
    let id: String
    let displayName: String
    let institution: String?
    let citations: Int?
    let hIndex: Int?
    let lastUpdated: Date?
    let weeklyGrowth: Int?
    let monthlyGrowth: Int?
    let quarterlyGrowth: Int?
    
    /// 计算引用数变化趋势（基于最近一个月的历史数据）
    var citationTrend: CitationTrend {
        // 直接使用从 DataManager 计算的月度增长数据
        guard let monthlyGrowthValue = monthlyGrowth else { return .unchanged }
        
        if monthlyGrowthValue > 0 {
            return .up(monthlyGrowthValue)
        } else if monthlyGrowthValue < 0 {
            return .down(abs(monthlyGrowthValue))
        } else {
            return .unchanged
        }
    }
}

/// 引用数趋势
enum CitationTrend {
    case up(Int)
    case down(Int)
    case unchanged
    
    var symbol: String {
        switch self {
        case .up: return "↗"
        case .down: return "↘"
        case .unchanged: return "—"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .unchanged: return .secondary
        }
    }
    
    var text: String {
        switch self {
        case .up(let count): return "+\(count.formattedNumber)"
        case .down(let count): return "-\(count.formattedNumber)"
        case .unchanged: return "0"
        }
    }
}

struct CiteTrackWidgetEntry: TimelineEntry {
    let date: Date
    let scholars: [WidgetScholarInfo]
    let primaryScholar: WidgetScholarInfo?
    let totalCitations: Int
    var lastRefreshTime: Date?
}

// MARK: - 数据提供者：专注数据，无杂音
struct CiteTrackWidgetProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> CiteTrackWidgetEntry {
        CiteTrackWidgetEntry(
            date: Date(),
            scholars: [],
            primaryScholar: nil,
            totalCitations: 0,
            lastRefreshTime: nil
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CiteTrackWidgetEntry) -> ()) {
        let scholars = loadScholars()
        let primary = scholars.max(by: { ($0.citations ?? 0) < ($1.citations ?? 0) })
        let total = scholars.compactMap { $0.citations }.reduce(0, +)
        
        completion(CiteTrackWidgetEntry(
            date: Date(),
            scholars: Array(scholars.prefix(4)),
            primaryScholar: primary,
            totalCitations: total,
            lastRefreshTime: getLastRefreshTime()
        ))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CiteTrackWidgetEntry>) -> ()) {
        let scholars = loadScholars()
        
        // 优先使用用户选择的学者，否则使用引用数最多的学者
        let primary = getSelectedScholar(from: scholars) ?? scholars.max(by: { ($0.citations ?? 0) < ($1.citations ?? 0) })
        let total = scholars.compactMap { $0.citations }.reduce(0, +)
        
        // 创建带有刷新时间的条目
        let entryWithRefreshTime = CiteTrackWidgetEntry(
            date: Date(),
            scholars: Array(scholars.prefix(4)),
            primaryScholar: primary,
            totalCitations: total,
            lastRefreshTime: getLastRefreshTime()
        )
        
        // 每小时更新一次
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entryWithRefreshTime], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    /// 获取用户选择的学者
    private func getSelectedScholar(from scholars: [WidgetScholarInfo]) -> WidgetScholarInfo? {
        let appGroupIdentifier = "group.com.example.CiteTrack"
        
        // 首先尝试从App Group读取选择的学者ID
        var selectedId: String?
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            selectedId = appGroupDefaults.string(forKey: "SelectedWidgetScholarId")
        }
        
        // 回退到标准UserDefaults
        if selectedId == nil {
            selectedId = UserDefaults.standard.string(forKey: "SelectedWidgetScholarId")
        }
        
        guard let scholarId = selectedId else { return nil }
        
        let selected = scholars.first { $0.id == scholarId }
        if selected != nil {
            print("✅ [Widget] 使用用户选择的学者: \(selected!.displayName)")
        }
        
        return selected
    }
    
    /// 🎯 简化数据加载：优先从App Group读取，回退到标准位置
    private func loadScholars() -> [WidgetScholarInfo] {
        let appGroupIdentifier = "group.com.example.CiteTrack"
        
        // 首先尝试从App Group读取
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let data = appGroupDefaults.data(forKey: "WidgetScholars"),
           let scholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
            print("✅ [Widget] 从App Group加载了 \(scholars.count) 位学者")
            return scholars
        }
        
        // 回退到标准UserDefaults
        if let data = UserDefaults.standard.data(forKey: "WidgetScholars"),
           let scholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
            print("✅ [Widget] 从标准存储加载了 \(scholars.count) 位学者")
            return scholars
        }
        
        print("📱 [Widget] 暂无学者数据（已检查App Group和标准存储）")
        return []
    }
    
    /// 获取最后刷新时间
    private func getLastRefreshTime() -> Date? {
        let appGroupIdentifier = "group.com.example.CiteTrack"
        
        // 首先尝试从App Group读取
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let lastRefresh = appGroupDefaults.object(forKey: "LastRefreshTime") as? Date {
            return lastRefresh
        }
        
        // 回退到标准UserDefaults
        return UserDefaults.standard.object(forKey: "LastRefreshTime") as? Date
    }
    
    /// 保存当前引用数作为月度历史数据
    private func saveCurrentCitationsAsHistory(scholars: [WidgetScholarInfo]) {
        let appGroupIdentifier = "group.com.example.CiteTrack"
        
        for scholar in scholars {
            if let citations = scholar.citations {
                // 保存到 App Group
                if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
                    appGroupDefaults.set(citations, forKey: "MonthlyPreviousCitations_\(scholar.id)")
                }
                // 同时保存到标准存储
                UserDefaults.standard.set(citations, forKey: "MonthlyPreviousCitations_\(scholar.id)")
            }
        }
    }
}

// MARK: - App Intents：让小组件具备交互能力

/// 🎯 学者选择Intent - 核心交互功能
@available(iOS 17.0, *)
struct SelectScholarIntent: AppIntent {
    static var title: LocalizedStringResource = "选择学者"
    static var description: IntentDescription = "从已添加的学者中选择要显示的学者"
    static var openAppWhenRun: Bool = false  // 不需要打开App
    
    @Parameter(title: "学者", description: "选择要在小组件中显示的学者")
    var selectedScholar: ScholarEntity?
    
    func perform() async throws -> some IntentResult {
        print("🎯 [Intent] 学者选择Intent被触发")
        
        guard let scholar = selectedScholar else {
            // 如果没有提供学者，只是触发刷新
            print("⚠️ [Intent] 未提供学者参数，仅触发刷新")
            WidgetCenter.shared.reloadAllTimelines()
            return .result(dialog: "请选择一个学者")
        }
        
        print("✅ [Intent] 用户选择了学者: \(scholar.displayName)")
        
        let appGroupIdentifier = "group.com.example.CiteTrack"
        
        // 保存到App Group UserDefaults
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            appGroupDefaults.set(scholar.id, forKey: "SelectedWidgetScholarId")
            appGroupDefaults.set(scholar.displayName, forKey: "SelectedWidgetScholarName")
            print("✅ [Intent] 已保存到App Group: \(scholar.displayName)")
        }
        
        // 同时保存到标准UserDefaults作为备份
        UserDefaults.standard.set(scholar.id, forKey: "SelectedWidgetScholarId")
        UserDefaults.standard.set(scholar.displayName, forKey: "SelectedWidgetScholarName")
        
        // 触发小组件刷新
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result(dialog: "已设置 \(scholar.displayName) 为小组件显示学者")
    }
    
    static var parameterSummary: some ParameterSummary {
        Summary("选择学者 \(\.$selectedScholar)")
    }
}

/// 🎯 学者实体 - 用于Intent参数
@available(iOS 17.0, *)
struct ScholarEntity: AppEntity {
    let id: String
    let displayName: String
    let citations: Int?
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayName)",
            subtitle: citations.map { "\($0) 引用" } ?? "暂无数据"
        )
    }
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "学者"
    
    static var defaultQuery = ScholarEntityQuery()
}

/// 🎯 学者查询 - 提供可选择的学者列表
@available(iOS 17.0, *)
struct ScholarEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ScholarEntity] {
        let scholars = loadAllScholars()
        return scholars.filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [ScholarEntity] {
        return loadAllScholars()
    }
    
    private func loadAllScholars() -> [ScholarEntity] {
        let appGroupIdentifier = "group.com.example.CiteTrack"
        
        // 首先尝试从App Group读取
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let data = appGroupDefaults.data(forKey: "WidgetScholars"),
           let widgetScholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
            let scholars = widgetScholars.map { scholar in
                ScholarEntity(
                    id: scholar.id,
                    displayName: scholar.displayName,
                    citations: scholar.citations
                )
            }
            print("✅ [Intent] 从App Group加载了 \(scholars.count) 位学者供选择")
            return scholars
        }
        
        // 回退到标准UserDefaults
        if let data = UserDefaults.standard.data(forKey: "WidgetScholars"),
           let widgetScholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
            let scholars = widgetScholars.map { scholar in
                ScholarEntity(
                    id: scholar.id,
                    displayName: scholar.displayName,
                    citations: scholar.citations
                )
            }
            print("✅ [Intent] 从标准存储加载了 \(scholars.count) 位学者供选择")
            return scholars
        }
        
        print("📱 [Intent] 无法加载学者数据（已检查App Group和标准存储）")
        return []
    }
}

/// 🔄 快速刷新Intent - 带触觉反馈
@available(iOS 17.0, *)
struct QuickRefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "刷新数据"
    static var description: IntentDescription = "刷新学者的引用数据"
    static var openAppWhenRun: Bool = false  // 不需要打开App
    
    func perform() async throws -> some IntentResult {
        print("🔄 [Intent] 用户触发小组件刷新 - 将从主应用同步数据")
        
        let appGroupIdentifier = "group.com.example.CiteTrack"
        let timestamp = Date()
        
        // 记录刷新时间戳，用于触发动效
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            appGroupDefaults.set(timestamp, forKey: "LastRefreshTime")
        }
        UserDefaults.standard.set(timestamp, forKey: "LastRefreshTime")
        
        // 获取当前的学者数据并保存为月度历史数据
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let data = appGroupDefaults.data(forKey: "WidgetScholars"),
           let scholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
            // 保存每个学者的当前引用数作为月度历史数据
            for scholar in scholars {
                if let citations = scholar.citations {
                    appGroupDefaults.set(citations, forKey: "MonthlyPreviousCitations_\(scholar.id)")
                    UserDefaults.standard.set(citations, forKey: "MonthlyPreviousCitations_\(scholar.id)")
                }
            }
        }
        
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            appGroupDefaults.set(timestamp, forKey: "LastRefreshTime")
        }
        UserDefaults.standard.set(timestamp, forKey: "LastRefreshTime")
        
        // 触发小组件数据刷新
        WidgetCenter.shared.reloadAllTimelines()
        print("✅ [Intent] 小组件时间线已刷新，触发时间: \(timestamp)")
        
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return .result(dialog: "数据已刷新 \(formatter.string(from: timestamp)) - 将同步最新引用数")
    }
}

/// 🎯 简化的学者切换Intent - 带触觉反馈
@available(iOS 17.0, *)
struct ToggleScholarIntent: AppIntent {
    static var title: LocalizedStringResource = "切换学者"
    static var description: IntentDescription = "切换到下一个学者"
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        print("🔄 [Intent] 用户触发学者切换")
        
        let appGroupIdentifier = "group.com.example.CiteTrack"
        let timestamp = Date()
        
        // 记录切换时间戳，用于触发动效
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            appGroupDefaults.set(timestamp, forKey: "LastScholarSwitchTime")
        }
        UserDefaults.standard.set(timestamp, forKey: "LastScholarSwitchTime")
        
        // 获取所有学者
        var scholars: [WidgetScholarInfo] = []
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let data = appGroupDefaults.data(forKey: "WidgetScholars"),
           let loadedScholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
            scholars = loadedScholars
        } else if let data = UserDefaults.standard.data(forKey: "WidgetScholars"),
                  let loadedScholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
            scholars = loadedScholars
        }
        
        guard !scholars.isEmpty else {
            print("⚠️ [Intent] 没有可用的学者")
            return .result(dialog: "没有可用的学者")
        }
        
        // 获取当前选择的学者
        var currentSelectedId: String?
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            currentSelectedId = appGroupDefaults.string(forKey: "SelectedWidgetScholarId")
        }
        if currentSelectedId == nil {
            currentSelectedId = UserDefaults.standard.string(forKey: "SelectedWidgetScholarId")
        }
        
        // 找到下一个学者
        var nextScholar: WidgetScholarInfo
        if let currentId = currentSelectedId,
           let currentIndex = scholars.firstIndex(where: { $0.id == currentId }) {
            // 选择下一个学者（循环）
            let nextIndex = (currentIndex + 1) % scholars.count
            nextScholar = scholars[nextIndex]
        } else {
            // 如果没有当前选择，选择第一个
            nextScholar = scholars[0]
        }
        
        // 保存新的选择和切换时间戳
        let switchTimestamp = Date()
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            appGroupDefaults.set(nextScholar.id, forKey: "SelectedWidgetScholarId")
            appGroupDefaults.set(nextScholar.displayName, forKey: "SelectedWidgetScholarName")
            appGroupDefaults.set(switchTimestamp, forKey: "LastScholarSwitchTime")
        }
        UserDefaults.standard.set(nextScholar.id, forKey: "SelectedWidgetScholarId")
        UserDefaults.standard.set(nextScholar.displayName, forKey: "SelectedWidgetScholarName")
        UserDefaults.standard.set(switchTimestamp, forKey: "LastScholarSwitchTime")
        
        // 触发小组件刷新
        WidgetCenter.shared.reloadAllTimelines()
        
        print("✅ [Intent] 已切换到学者: \(nextScholar.displayName)")
        return .result(dialog: "已切换到 \(nextScholar.displayName)")
    }
}

// MARK: - 小组件视图：一个组件，三种尺寸，完美适配

struct CiteTrackWidgetView: View {
    let entry: CiteTrackWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

/// 🎯 小尺寸：单一学者，极简聚焦 - 乔布斯式设计
struct SmallWidgetView: View {
    let entry: CiteTrackWidgetEntry
    @State private var refreshRotation: Double = 0
    @State private var switchScale: Double = 1.0
    
    var body: some View {
        if let scholar = entry.primaryScholar {
            ZStack {
                VStack(spacing: 0) {
                    // 顶部：学者信息和状态（固定高度）
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(scholar.displayName.adaptiveAbbreviated)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            Spacer()
                            
                            // 状态指示器：默认灰色，今天更新则绿色
                            Circle()
                                .fill(isUpdatedToday(entry.lastRefreshTime) ? Color.green : Color.gray)
                                .frame(width: 6, height: 6)
                        }
                        
                        // 机构信息占位，确保固定高度
                        HStack {
                            if let institution = scholar.institution {
                                Text(institution)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            } else {
                                Text(" ")
                                    .font(.caption2)
                                    .foregroundColor(.clear)
                            }
                            Spacer()
                        }
                    }
                    .frame(height: 44) // 固定顶部区域高度
                    .padding(.top, 12) // 减少顶部padding让整体上移
                    .padding(.horizontal, 12)
                    
                    Spacer()
                    
                    // 中心：大引用数显示
                    VStack(spacing: 6) {
                        Text((scholar.citations ?? 0).formattedNumber)
                            .font(.system(size: 42, weight: .heavy)) // 再次放大字体
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.5) // 允许更大缩放范围
                            .lineLimit(1)
                        
                        Text("引用数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 为按钮留出空间
                    Color.clear
                        .frame(height: 35) // 进一步减少底部空间，让引用数字位置提高
                }
                
                // 底部：引用数趋势和按钮
                VStack {
                    Spacer()
                    
                    // 引用数趋势显示在按钮区域
                    HStack {
                        // 左下角：切换按钮 - 固定位置
                        if #available(iOS 17.0, *) {
                            Button(intent: ToggleScholarIntent()) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                    .frame(width: 32, height: 32)
                                    .background(Color.blue.opacity(0.15))
                                    .cornerRadius(16)
                                    .scaleEffect(switchScale)
                                    .animation(.easeInOut(duration: 0.2), value: switchScale)
                            }
                            .buttonStyle(EnhancedWidgetButtonStyle())
                        } else {
                            Color.clear.frame(width: 32, height: 32)
                        }
                        
                        Spacer()
                        
                        // 中间：趋势指示器（固定宽度，包含箭头）
                        HStack {
                            Spacer()
                            HStack(spacing: 3) {
                                Text(scholar.citationTrend.symbol)
                                    .font(.caption) // 缩小箭头字体
                                Text(scholar.citationTrend.text)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(scholar.citationTrend.color)
                            .lineLimit(1)
                            Spacer()
                        }
                        .frame(minWidth: 80) // 增加中间区域宽度以避免省略号
                        
                        Spacer()
                        
                        // 右下角：刷新按钮 - 固定位置
                        if #available(iOS 17.0, *) {
                            Button(intent: QuickRefreshIntent()) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title3)
                                    .foregroundColor(.green)
                                    .frame(width: 32, height: 32)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(16)
                                    .rotationEffect(.degrees(refreshRotation))
                                    .animation(.linear(duration: 1.0), value: refreshRotation)
                            }
                            .buttonStyle(EnhancedWidgetButtonStyle())
                        } else {
                            Color.clear.frame(width: 32, height: 32)
                        }
                    }
                    .padding(.horizontal, 2) // 更少的padding让按钮更靠近角落
                    .padding(.bottom, 2) // 恢复按钮原来的位置
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "citetrack://scholar/\(scholar.id)"))
            .onAppear {
                checkForRecentActions()
            }
            
        } else {
            // 空状态：优雅的引导设计
            VStack(spacing: 12) {
                Spacer()
                
                VStack(spacing: 8) {
                    Image(systemName: "graduationcap.circle")
                        .font(.title)
                        .foregroundColor(.blue.opacity(0.6))
                    
                    VStack(spacing: 4) {
                        Text("开始追踪")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("在主App中添加学者")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "citetrack://add-scholar"))
        }
    }
    
    /// 检查是否今天更新过
    private func isUpdatedToday(_ lastRefreshTime: Date?) -> Bool {
        guard let lastRefresh = lastRefreshTime else { return false }
        
        let calendar = Calendar.current
        let today = Date()
        
        return calendar.isDate(lastRefresh, inSameDayAs: today)
    }
    
    /// 检查最近的操作并触发对应的动效
    private func checkForRecentActions() {
        let appGroupIdentifier = "group.com.example.CiteTrack"
        
        // 检查切换动效
        var lastSwitchTime: Date?
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            lastSwitchTime = appGroupDefaults.object(forKey: "LastScholarSwitchTime") as? Date
        }
        if lastSwitchTime == nil {
            lastSwitchTime = UserDefaults.standard.object(forKey: "LastScholarSwitchTime") as? Date
        }
        
        if let switchTime = lastSwitchTime {
            let timeSinceSwitch = Date().timeIntervalSince(switchTime)
            if timeSinceSwitch < 1 { // 1秒内认为是刚切换
                switchScale = 1.1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    switchScale = 1.0
                }
            }
        }
        
        // 检查刷新动效
        var lastRefreshTime: Date?
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            lastRefreshTime = appGroupDefaults.object(forKey: "LastRefreshTime") as? Date
        }
        if lastRefreshTime == nil {
            lastRefreshTime = UserDefaults.standard.object(forKey: "LastRefreshTime") as? Date
        }
        
        if let refreshTime = lastRefreshTime {
            let timeSinceRefresh = Date().timeIntervalSince(refreshTime)
            if timeSinceRefresh < 1 { // 1秒内认为是刚刷新
                refreshRotation = 360
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    refreshRotation = 0
                }
            }
        }
    }
}

/// 🎯 中尺寸：学者影响力榜单 - 乔布斯式简洁对比
struct MediumWidgetView: View {
    let entry: CiteTrackWidgetEntry
    
    var body: some View {
        if !entry.scholars.isEmpty {
            VStack(spacing: 2) {
                // 顶部：标题和总览 - 优化布局
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("学术影响力")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        
                        Text("Top \(min(entry.scholars.count, 3)) 学者")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 8)
                    
                    // 总引用数显示 - 优化大小
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(entry.totalCitations)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text("总引用")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 6)
                .padding(.horizontal, 10)
                
                // 中心：排行榜 - 紧凑设计
                VStack(spacing: 2) {
                    ForEach(Array(entry.scholars.prefix(3).enumerated()), id: \.element.id) { index, scholar in
                        HStack(spacing: 10) {
                            // 排名徽章 - 缩小尺寸
                            ZStack {
                                Circle()
                                    .fill(rankColor(index))
                                    .frame(width: 20, height: 20)
                                Text("\(index + 1)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            // 学者信息 - 优化布局
                            VStack(alignment: .leading, spacing: 1) {
                                Text(scholar.displayName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                if let institution = scholar.institution {
                                    Text(institution)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                            }
                            
                            Spacer(minLength: 4)
                            
                            // 引用数和趋势 - 紧凑设计
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(scholar.citations ?? 0)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(1)
                                
                                // 趋势指示器 - 缩小尺寸
                                HStack(spacing: 1) {
                                    Text(scholar.citationTrend.symbol)
                                        .font(.caption2)
                                    Text(scholar.citationTrend.text)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(scholar.citationTrend.color)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 0)
                        
                        // 分隔线（除了最后一个） - 缩小间距
                        if index < min(entry.scholars.count, 3) - 1 {
                            Divider()
                                .padding(.horizontal, 10)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                // 底部：时间戳 - 优化布局
                if let lastRefresh = entry.lastRefreshTime {
                    Text("更新于 \(formatTime(lastRefresh))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.bottom, 4)
                        .padding(.horizontal, 10)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "citetrack://scholars"))
            
        } else {
            // 空状态：引导添加学者 - 优化布局
            VStack(spacing: 12) {
                Spacer()
                
                VStack(spacing: 10) {
                    Image(systemName: "trophy.circle")
                        .font(.title)
                        .foregroundColor(.orange.opacity(0.6))
                    
                    VStack(spacing: 3) {
                        Text("学术排行榜")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.8)
                        Text("添加学者开始追踪\n他们的学术影响力")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .minimumScaleFactor(0.8)
                    }
                }
                
                Spacer()
            }
            .padding(6)
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "citetrack://add-scholar"))
        }
    }
    
    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .orange  // 金牌
        case 1: return .gray    // 银牌
        case 2: return .brown   // 铜牌
        default: return .blue
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// 🎯 大尺寸：学术影响力仪表板 - 乔布斯式完整洞察
struct LargeWidgetView: View {
    let entry: CiteTrackWidgetEntry
    
    var body: some View {
        if !entry.scholars.isEmpty {
            VStack(spacing: 6) {
                // 顶部：仪表板标题和关键指标 - 紧凑设计
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("学术影响力仪表板")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            
                            Text("追踪 \(entry.scholars.count) 位学者")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 8)
                        
                        // 时间指示器 - 优化尺寸
                        if let lastRefresh = entry.lastRefreshTime {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("最新数据")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Text(formatTime(lastRefresh))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    // 核心指标卡片 - 缩小尺寸
                    HStack(spacing: 8) {
                        // 总引用数卡片
                        VStack(spacing: 2) {
                            Text("\(entry.totalCitations)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text("总引用数")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                        
                        // 平均引用数卡片
                        VStack(spacing: 2) {
                            Text("\(entry.totalCitations / max(entry.scholars.count, 1))")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text("平均引用")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                        
                        // 顶尖学者指标
                        if let topScholar = entry.scholars.first {
                            VStack(spacing: 2) {
                                Text("\(topScholar.citations ?? 0)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(1)
                                Text("最高引用")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 12)
                
                // 中心：学者卡片网格 - 紧凑设计
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                    ForEach(Array(entry.scholars.prefix(4).enumerated()), id: \.element.id) { index, scholar in
                        VStack(alignment: .leading, spacing: 4) {
                            // 学者头部信息 - 缩小尺寸
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(scholar.displayName)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    
                                    if let institution = scholar.institution {
                                        Text(institution)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                }
                                
                                Spacer(minLength: 4)
                                
                                // 排名徽章 - 缩小尺寸
                                Text("#\(index + 1)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(rankColor(index))
                                    .cornerRadius(3)
                            }
                            
                            // 核心数据 - 缩小尺寸
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(scholar.citations ?? 0)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                        .minimumScaleFactor(0.8)
                                        .lineLimit(1)
                                    
                                    Text("引用数")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer(minLength: 4)
                                
                                // 趋势指示器 - 缩小尺寸
                                VStack(alignment: .trailing, spacing: 1) {
                                    HStack(spacing: 1) {
                                        Text(scholar.citationTrend.symbol)
                                            .font(.caption2)
                                        Text(scholar.citationTrend.text)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(scholar.citationTrend.color)
                                    
                                    Text("本月")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(6)
                        .background(Color.secondary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 12)
                
                // 底部：数据洞察 - 缩小尺寸
                VStack(spacing: 4) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("数据洞察")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            let growingScholars = entry.scholars.filter { scholar in
                                switch scholar.citationTrend {
                                case .up: return true
                                default: return false
                                }
                            }.count
                            
                            Text("\(growingScholars) 位学者引用数上升")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        
                        Spacer(minLength: 8)
                        
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("团队表现")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            let performance = entry.totalCitations > 1000 ? "优秀" : entry.totalCitations > 500 ? "良好" : "起步"
                            Text(performance)
                                .font(.caption2)
                                .foregroundColor(entry.totalCitations > 1000 ? .green : entry.totalCitations > 500 ? .orange : .blue)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "citetrack://dashboard"))
            
        } else {
            // 空状态：完整的引导界面 - 优化布局
            VStack(spacing: 12) {
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle")
                        .font(.system(size: 36))
                        .foregroundColor(.blue.opacity(0.6))
                    
                    VStack(spacing: 6) {
                        Text("学术影响力仪表板")
                            .font(.headline)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                        
                        Text("添加学者开始构建您的\n学术影响力追踪仪表板")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .minimumScaleFactor(0.8)
                    }
                    
                    // 功能预览 - 缩小尺寸
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption2)
                            Text("实时引用数追踪")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .minimumScaleFactor(0.8)
                            Spacer()
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption2)
                            Text("学者排名对比")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .minimumScaleFactor(0.8)
                            Spacer()
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption2)
                            Text("趋势变化分析")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .minimumScaleFactor(0.8)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .padding(10)
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "citetrack://add-scholar"))
        }
    }
    
    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .orange  // 金色
        case 1: return .gray    // 银色
        case 2: return .brown   // 铜色
        default: return .blue
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 自定义按钮样式，提供视觉反馈
struct WidgetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 增强版按钮样式 - 更丰富的视觉反馈
struct EnhancedWidgetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Widget Configuration
struct CiteTrackWidget: Widget {
    let kind: String = "CiteTrackWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CiteTrackWidgetProvider()) { entry in
            CiteTrackWidgetView(entry: entry)
        }
        .configurationDisplayName("CiteTrack")
        .description("跟踪学者的引用数据和学术影响力")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview
struct CiteTrackWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEntry = CiteTrackWidgetEntry(
            date: Date(),
            scholars: [
                WidgetScholarInfo(id: "1", displayName: "Geoffrey Edward Hinton", institution: "University of Toronto", citations: 234567, hIndex: 145, lastUpdated: Date(), weeklyGrowth: 5, monthlyGrowth: 523, quarterlyGrowth: 1278),
                WidgetScholarInfo(id: "2", displayName: "Yann Andre LeCun", institution: "New York University", citations: 187654, hIndex: 128, lastUpdated: Date(), weeklyGrowth: 3, monthlyGrowth: 415, quarterlyGrowth: 942)
            ],
            primaryScholar: WidgetScholarInfo(id: "1", displayName: "Geoffrey Edward Hinton", institution: "University of Toronto", citations: 234567, hIndex: 145, lastUpdated: Date(), weeklyGrowth: 5, monthlyGrowth: 523, quarterlyGrowth: 1278),
            totalCitations: 422221,
            lastRefreshTime: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) // 2小时前刷新（今天）
        )
        
        Group {
            CiteTrackWidgetView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            CiteTrackWidgetView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            
            CiteTrackWidgetView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}

@main
struct CiteTrackWidgets: WidgetBundle {
    var body: some Widget {
        CiteTrackWidget()
    }
}