import SwiftUI
import WidgetKit
import AppIntents
import os.log

// 导入共享模块
import Foundation



// MARK: - 数字格式化扩展（从共享模块导入）

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

// 观察切换按钮缩放动画的辅助修饰器
private struct SwitchScaleObserver: AnimatableModifier {
    var scale: CGFloat
    var onUpdate: (Double) -> Void

    var animatableData: CGFloat {
        get { scale }
        set {
            scale = newValue
            onUpdate(Double(newValue))
        }
    }

    func body(content: Content) -> some View {
        content
    }
}
// MARK: - 使用共享的数据模型
// WidgetScholarInfo和CitationTrend现在从共享模块导入
// appGroupIdentifier也从共享常量导入

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
        print("🚨🚨🚨 WIDGET EXTENSION 启动 - 这是修改后的代码！🚨🚨🚨")
        return CiteTrackWidgetEntry(
            date: Date(),
            scholars: [],
            primaryScholar: nil,
            totalCitations: 0,
            lastRefreshTime: nil
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CiteTrackWidgetEntry) -> ()) {
        print("🔄 [Widget] getSnapshot 被调用 - 强制刷新触发")
        
        // 检查是否是强制刷新触发的
        if let forceRefreshTime = UserDefaults.standard.object(forKey: "ForceRefreshTriggered") as? Date {
            print("🔄 [Widget] 检测到强制刷新标记，时间: \(forceRefreshTime)")
            // 清除标记
            UserDefaults.standard.removeObject(forKey: "ForceRefreshTriggered")
            UserDefaults.standard.synchronize()
        }
        
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
        print("🔄 [Widget] getTimeline 被调用 - 强制刷新触发")
        
        // 检查是否是强制刷新触发的
        if let forceRefreshTime = UserDefaults.standard.object(forKey: "ForceRefreshTriggered") as? Date {
            print("🔄 [Widget] 检测到强制刷新标记，时间: \(forceRefreshTime)")
            // 清除标记
            UserDefaults.standard.removeObject(forKey: "ForceRefreshTriggered")
            UserDefaults.standard.synchronize()
        }
        
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

        // 尝试对当前学者进行刷新状态对齐：若全局 LastRefreshTime 晚于该学者的 RefreshStartTime，则视为完成
        if let currentId = primary?.id {
            reconcilePerScholarRefreshCompletion(for: currentId)
        }
        
        // 根据数据更新频率调整刷新策略
        let nextUpdate: Date
        if context.isPreview {
            // 预览模式下不需要频繁更新
            nextUpdate = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date()
        } else {
            // 正常模式下每15分钟检查一次数据更新
            nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        }
        
        let timeline = Timeline(entries: [entryWithRefreshTime], policy: .after(nextUpdate))
        completion(timeline)
    }

    /// 若检测到"全局完成时间"晚于该学者的开始时间，则写入该学者 LastRefreshTime_<id> 并清除进行中标记
    private func reconcilePerScholarRefreshCompletion(for scholarId: String) {
        let groupID = appGroupIdentifier
        let startKey = "RefreshStartTime_\(scholarId)"
        let lastKey = "LastRefreshTime_\(scholarId)"
        let inKey = "RefreshInProgress_\(scholarId)"

        // 读取学者开始时间
        var startTime: Date?
        if let appGroupDefaults = UserDefaults(suiteName: groupID) {
            startTime = appGroupDefaults.object(forKey: startKey) as? Date
        }
        if startTime == nil {
            startTime = UserDefaults.standard.object(forKey: startKey) as? Date
        }

        guard let s = startTime else { return }

        // 读取全局 LastRefreshTime 作为回落
        let globalLast = getLastRefreshTime()
        guard let g = globalLast, g > s else { return }

        // 写入该学者的 LastRefreshTime_<id> 并清除进行中
        if let appGroupDefaults = UserDefaults(suiteName: groupID) {
            appGroupDefaults.set(g, forKey: lastKey)
            appGroupDefaults.set(false, forKey: inKey)
            appGroupDefaults.synchronize()
        }
        UserDefaults.standard.set(g, forKey: lastKey)
        UserDefaults.standard.set(false, forKey: inKey)
    }
    
    /// 获取用户选择的学者
    private func getSelectedScholar(from scholars: [WidgetScholarInfo]) -> WidgetScholarInfo? {
        let groupID = appGroupIdentifier
        
        // 首先尝试从App Group读取选择的学者ID
        var selectedId: String?
        if let appGroupDefaults = UserDefaults(suiteName: groupID) {
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
        print("🔍 [Widget] 开始加载学者数据...")
        
        let groupID = appGroupIdentifier
        print("🔍 [Widget] 使用App Group ID: \(groupID)")
        
        // 首先尝试从App Group读取
        if let appGroupDefaults = UserDefaults(suiteName: groupID) {
            print("🔍 [Widget] App Group UserDefaults创建成功")
            
            // 列出App Group中的所有键
            let allKeys = appGroupDefaults.dictionaryRepresentation().keys
            print("🔍 [Widget] App Group中的所有键: \(Array(allKeys))")
            
            if let data = appGroupDefaults.data(forKey: "WidgetScholars") {
                print("🔍 [Widget] 从App Group找到数据，大小: \(data.count) bytes")
                if let scholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
                    print("✅ [Widget] 从App Group加载了 \(scholars.count) 位学者")
                    return scholars
                } else {
                    print("❌ [Widget] App Group数据解码失败")
                }
            } else {
                print("⚠️ [Widget] App Group中没有WidgetScholars数据")
            }
        } else {
            print("❌ [Widget] 无法创建App Group UserDefaults")
        }
        
        // 回退到标准UserDefaults
        print("🔍 [Widget] 尝试标准UserDefaults...")
        let standardKeys = UserDefaults.standard.dictionaryRepresentation().keys
        print("🔍 [Widget] 标准UserDefaults中的所有键: \(Array(standardKeys))")
        
        if let data = UserDefaults.standard.data(forKey: "WidgetScholars") {
            print("🔍 [Widget] 从标准存储找到数据，大小: \(data.count) bytes")
            if let scholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
                print("✅ [Widget] 从标准存储加载了 \(scholars.count) 位学者")
                return scholars
            } else {
                print("❌ [Widget] 标准存储数据解码失败")
            }
        } else {
            print("⚠️ [Widget] 标准存储中也没有WidgetScholars数据")
        }
        
        print("📱 [Widget] 暂无学者数据（已检查App Group和标准存储）")
        return []
    }
    
    /// 获取最后刷新时间
    private func getLastRefreshTime() -> Date? {
        let groupID = appGroupIdentifier
        
        // 首先尝试从App Group读取
        if let appGroupDefaults = UserDefaults(suiteName: groupID),
           let lastRefresh = appGroupDefaults.object(forKey: "LastRefreshTime") as? Date {
            return lastRefresh
        }
        
        // 回退到标准UserDefaults
        return UserDefaults.standard.object(forKey: "LastRefreshTime") as? Date
    }
    
    /// 保存当前引用数作为月度历史数据
    private func saveCurrentCitationsAsHistory(scholars: [WidgetScholarInfo]) {
        let groupID = appGroupIdentifier
        
        for scholar in scholars {
            if let citations = scholar.citations {
                // 保存到 App Group
                if let appGroupDefaults = UserDefaults(suiteName: groupID) {
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
            return .result()
        }
        
        print("✅ [Intent] 用户选择了学者: \(scholar.displayName)")
        
        let groupID = appGroupIdentifier
        
        // 保存到App Group UserDefaults
        if let appGroupDefaults = UserDefaults(suiteName: groupID) {
            appGroupDefaults.set(scholar.id, forKey: "SelectedWidgetScholarId")
            appGroupDefaults.set(scholar.displayName, forKey: "SelectedWidgetScholarName")
            print("✅ [Intent] 已保存到App Group: \(scholar.displayName)")
        }
        
        // 同时保存到标准UserDefaults作为备份
        UserDefaults.standard.set(scholar.id, forKey: "SelectedWidgetScholarId")
        UserDefaults.standard.set(scholar.displayName, forKey: "SelectedWidgetScholarName")
        
        // 触发小组件刷新
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
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
        // 使用全局定义的 appGroupIdentifier
        
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



/// 🔄 强制刷新Intent - 用于调试
@available(iOS 17.0, *)
struct ForceRefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "强制刷新小组件"
    static var description: IntentDescription = "强制刷新小组件数据"
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        print("🔄 [ForceRefreshIntent] 用户点击了强制刷新按钮")
        print("🔄 [ForceRefreshIntent] 开始强制刷新流程...")
        
        // 设置一个标记，让数据提供者知道这是强制刷新
        UserDefaults.standard.set(Date(), forKey: "ForceRefreshTriggered")
        UserDefaults.standard.synchronize()
        print("🔄 [ForceRefreshIntent] 已设置强制刷新标记")
        
        // 强制触发小组件刷新
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 [ForceRefreshIntent] WidgetCenter.reloadAllTimelines() 已调用")
        
        // 等待一小段时间让系统处理
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // 再次强制刷新
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 [ForceRefreshIntent] 第二次刷新已触发")
        
        return .result()
    }
}

/// 🧪 调试测试Intent - 验证AppIntents系统
@available(iOS 17.0, *)
struct DebugTestIntent: AppIntent {
    static var title: LocalizedStringResource = "调试测试"
    static var description: IntentDescription = "调试用的测试Intent"
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        print("🧪 [DebugTestIntent] 调试测试Intent被触发！")
        return .result()
    }
}

/// 🔄 快速刷新Intent - 修复动画触发
@available(iOS 17.0, *)
struct QuickRefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "刷新数据"
    static var description: IntentDescription = "刷新学者的引用数据"
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        NSLog("🚨🚨🚨 QuickRefreshIntent 被触发！！！")
        print("🚨🚨🚨 [Intent] QuickRefreshIntent 被触发！！！")
        print("🔄 [Intent] ===== 新版本代码 - 用户触发小组件刷新 =====")
        
        let groupIdentifier = appGroupIdentifier
        let timestamp = Date()
        // 配置：最短 InProg 可见时长（秒），可通过 App Group/Standard 键 `WidgetMinInProgSeconds` 配置（0.3~3.0）
        func minInProgSeconds() -> TimeInterval {
            let key = "WidgetMinInProgSeconds"
            var v: TimeInterval = 0.8
            if let ag = UserDefaults(suiteName: groupIdentifier), ag.object(forKey: key) != nil {
                v = TimeInterval(ag.double(forKey: key))
            } else if UserDefaults.standard.object(forKey: key) != nil {
                v = TimeInterval(UserDefaults.standard.double(forKey: key))
            }
            if v < 0.3 { return 0.3 }
            if v > 3.0 { return 3.0 }
            return v
        }

        
        print("🔄 [Intent] 使用 groupIdentifier: \(groupIdentifier)")
        
        // 标记刷新开始：记录开始时间与进行中（按当前选中学者与通用键），不写入 LastRefreshTime（由数据写入方更新）
        var selectedScholarId: String?
        if let appGroupDefaults = UserDefaults(suiteName: groupIdentifier) {
            print("🔄 [Intent] App Group UserDefaults 创建成功")
            // 读取当前选中学者ID
            selectedScholarId = appGroupDefaults.string(forKey: "SelectedWidgetScholarId")
            // 写通用键（兜底）
            let startKey = "RefreshStartTime"
            let inKey = "RefreshInProgress"
            let trigKey = "RefreshTriggered"
            let trigTimeKey = "RefreshTriggerTime"
            appGroupDefaults.set(timestamp, forKey: startKey)
            appGroupDefaults.set(true, forKey: trigKey)
            appGroupDefaults.set(timestamp, forKey: trigTimeKey)
            appGroupDefaults.set(true, forKey: inKey)
            appGroupDefaults.synchronize()
            print("🔄 [Intent] App Group 刷新开始标记完成")
            // 立即刷新时间线以呈现 InProg
            WidgetCenter.shared.reloadAllTimelines()
            // 若拿到具体学者，再补写按学者键，提升小组件检测成功率
            if let sidAG = selectedScholarId, !sidAG.isEmpty {
                appGroupDefaults.set(timestamp, forKey: "RefreshStartTime_\(sidAG)")
                appGroupDefaults.set(true, forKey: "RefreshInProgress_\(sidAG)")
                appGroupDefaults.set(timestamp, forKey: "RefreshTriggerTime_\(sidAG)")
                appGroupDefaults.synchronize()
                WidgetCenter.shared.reloadAllTimelines()
                print("🔄 [Intent] App Group 已补写学者专属标记: sid=\(sidAG)")
            }
        } else {
            print("🔄 [Intent] ❌ App Group UserDefaults 创建失败")
        }
        
        if selectedScholarId == nil {
            selectedScholarId = UserDefaults.standard.string(forKey: "SelectedWidgetScholarId")
        }
        
        print("🔄 [Intent] 设置 Standard UserDefaults（后备）")
        let sidStd = UserDefaults.standard.string(forKey: "SelectedWidgetScholarId")
        // 先写通用键
        UserDefaults.standard.set(timestamp, forKey: "RefreshStartTime")
        UserDefaults.standard.set(true, forKey: "RefreshTriggered")
        UserDefaults.standard.set(timestamp, forKey: "RefreshTriggerTime")
        UserDefaults.standard.set(true, forKey: "RefreshInProgress")
        // 若拿到具体学者，再写专属键
        let effectiveSid = selectedScholarId ?? sidStd
        if let esid = effectiveSid, !esid.isEmpty {
            UserDefaults.standard.set(timestamp, forKey: "RefreshStartTime_\(esid)")
            UserDefaults.standard.set(true, forKey: "RefreshInProgress_\(esid)")
            UserDefaults.standard.set(timestamp, forKey: "RefreshTriggerTime_\(esid)")
        }
        UserDefaults.standard.synchronize()
        print("🔄 [Intent] Standard 刷新开始标记完成")
        // 立即刷新时间线以呈现 InProg
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 [Intent] 小组件已立即刷新以显示 InProg 态（标准兜底）")
        
        print("✅ [Intent] 🔄 刷新标记已设置: RefreshTriggered = true")
        
        // 在 Intent 内直接后台拉取并写回数据（使用 async/await，确保返回前完成并清理标记）
        if let sid = selectedScholarId, !sid.isEmpty {
            print("📡 [Intent] 开始后台拉取学者数据: sid=\(sid)")
            func fetchScholarInfoInlineAsync(for scholarId: String) async throws -> (name: String, citations: Int) {
                guard let url = URL(string: "https://scholar.google.com/citations?user=\(scholarId)&hl=en") else {
                    throw NSError(domain: "InvalidURL", code: -1)
                }
                var request = URLRequest(url: url)
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
                request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
                request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
                request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    throw NSError(domain: "HTTP", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
                }
                let html = String(data: data, encoding: .utf8) ?? ""
                func firstMatch(_ pattern: String, _ text: String) -> String? {
                    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
                    let range = NSRange(text.startIndex..., in: text)
                    guard let m = regex.firstMatch(in: text, options: [], range: range), m.numberOfRanges > 1 else { return nil }
                    let r = m.range(at: 1)
                    guard let rr = Range(r, in: text) else { return nil }
                    return String(text[rr])
                }
                let namePatterns = [
                    #"<div id=\"gsc_prf_in\">([^<]+)</div>"#,
                    #"<div class=\"gsc_prf_in\">([^<]+)</div>"#,
                    #"<h3[^>]*>([^<]+)</h3>"#
                ]
                var name = ""
                for p in namePatterns { if let v = firstMatch(p, html) { name = v.trimmingCharacters(in: .whitespacesAndNewlines); break } }
                let citationPatterns = [
                    #"<td class=\"gsc_rsb_std\">(\d+)</td>"#,
                    #"<a[^>]*>(\d+)</a>"#,
                    #">(\d+)<"#
                ]
                var citations = 0
                for p in citationPatterns { if let v = firstMatch(p, html), let c = Int(v) { citations = c; break } }
                if name.isEmpty { name = scholarId }
                return (name: name, citations: citations)
            }
            do {
                let info = try await fetchScholarInfoInlineAsync(for: sid)
                let now = Date()
                var scholars: [WidgetScholarInfo] = []
                if let appGroup = UserDefaults(suiteName: groupIdentifier),
                   let data = appGroup.data(forKey: "WidgetScholars"),
                   let loaded = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
                    scholars = loaded
                } else if let data = UserDefaults.standard.data(forKey: "WidgetScholars"),
                          let loaded = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
                    scholars = loaded
                }
                if let idx = scholars.firstIndex(where: { $0.id == sid }) {
                    let old = scholars[idx]
                    let updated = WidgetScholarInfo(
                        id: old.id,
                        displayName: info.name.isEmpty ? old.displayName : info.name,
                        institution: old.institution,
                        citations: info.citations,
                        hIndex: old.hIndex,
                        lastUpdated: now,
                        weeklyGrowth: old.weeklyGrowth,
                        monthlyGrowth: old.monthlyGrowth,
                        quarterlyGrowth: old.quarterlyGrowth
                    )
                    scholars[idx] = updated
                }
                if let encoded = try? JSONEncoder().encode(scholars) {
                    if let appGroup = UserDefaults(suiteName: groupIdentifier) {
                        appGroup.set(encoded, forKey: "WidgetScholars")
                        appGroup.set(now, forKey: "LastRefreshTime_\(sid)")
                        appGroup.synchronize()
                    }
                    UserDefaults.standard.set(encoded, forKey: "WidgetScholars")
                    UserDefaults.standard.set(now, forKey: "LastRefreshTime_\(sid)")
                    UserDefaults.standard.synchronize()
                }
                WidgetCenter.shared.reloadAllTimelines()
                print("✅ [Intent] 后台刷新完成并写回: sid=\(sid), citations=\(info.citations)")

                // 保证最短 InProg 可见时长后再清理进行中标记
                let startKey = "RefreshStartTime_\(sid)"
                var startAt: Date? = nil
                if let ag = UserDefaults(suiteName: groupIdentifier) { startAt = ag.object(forKey: startKey) as? Date }
                if startAt == nil { startAt = UserDefaults.standard.object(forKey: startKey) as? Date }
                let hold = minInProgSeconds()
                if let sAt = startAt {
                    let elapsed = Date().timeIntervalSince(sAt)
                    if elapsed < hold {
                        let remain = hold - elapsed
                        try? await Task.sleep(nanoseconds: UInt64(remain * 1_000_000_000))
                    }
                }
                if let ag = UserDefaults(suiteName: groupIdentifier) {
                    ag.removeObject(forKey: "RefreshInProgress_\(sid)")
                    ag.removeObject(forKey: "RefreshStartTime_\(sid)")
                    ag.synchronize()
                }
                UserDefaults.standard.removeObject(forKey: "RefreshInProgress_\(sid)")
                UserDefaults.standard.removeObject(forKey: "RefreshStartTime_\(sid)")
                UserDefaults.standard.synchronize()
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                let now = Date()
                // 失败也要写入完成时间并清理进行中标记，避免卡死
                if let ag = UserDefaults(suiteName: groupIdentifier) { ag.set(now, forKey: "LastRefreshTime_\(sid)"); ag.synchronize() }
                UserDefaults.standard.set(now, forKey: "LastRefreshTime_\(sid)")
                UserDefaults.standard.synchronize()

                // 同样保证最短 InProg 可见后再清理
                let startKey = "RefreshStartTime_\(sid)"
                var startAt: Date? = nil
                if let ag = UserDefaults(suiteName: groupIdentifier) { startAt = ag.object(forKey: startKey) as? Date }
                if startAt == nil { startAt = UserDefaults.standard.object(forKey: startKey) as? Date }
                let hold = minInProgSeconds()
                if let sAt = startAt {
                    let elapsed = Date().timeIntervalSince(sAt)
                    if elapsed < hold {
                        let remain = hold - elapsed
                        try? await Task.sleep(nanoseconds: UInt64(remain * 1_000_000_000))
                    }
                }
                if let ag = UserDefaults(suiteName: groupIdentifier) {
                    ag.removeObject(forKey: "RefreshInProgress_\(sid)")
                    ag.removeObject(forKey: "RefreshStartTime_\(sid)")
                    ag.synchronize()
                }
                UserDefaults.standard.removeObject(forKey: "RefreshInProgress_\(sid)")
                UserDefaults.standard.removeObject(forKey: "RefreshStartTime_\(sid)")
                UserDefaults.standard.synchronize()
                WidgetCenter.shared.reloadAllTimelines()
                print("❌ [Intent] 后台拉取失败: sid=\(sid), error=\(error.localizedDescription)")
            }
        } else {
            print("⚠️ [Intent] 未找到 SelectedWidgetScholarId，跳过后台拉取")
        }
        
        // 立即触发小组件刷新（展示 InProg 态）
        print("🔄 [Intent] 触发小组件刷新...")
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 [Intent] 小组件刷新触发完成")
        
        print("🚨🚨🚨 [Intent] QuickRefreshIntent 执行完成！！！")
        return .result()
    }
}

/// 🎯 简化的学者切换Intent - 修复动画触发
@available(iOS 17.0, *)
struct ToggleScholarIntent: AppIntent {
    static var title: LocalizedStringResource = "切换学者"
    static var description: IntentDescription = "切换到下一个学者"
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        print("🎯 [Intent] ===== 新版本代码 - 用户触发学者切换 =====")
        
        let groupIdentifier = appGroupIdentifier
        
        // 获取所有学者
        var scholars: [WidgetScholarInfo] = []
        if let appGroupDefaults = UserDefaults(suiteName: groupIdentifier),
           let data = appGroupDefaults.data(forKey: "WidgetScholars"),
           let loadedScholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
            scholars = loadedScholars
        } else if let data = UserDefaults.standard.data(forKey: "WidgetScholars"),
                  let loadedScholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
            scholars = loadedScholars
        }
        
        guard !scholars.isEmpty else {
            print("⚠️ [Intent] 没有可用的学者")
            return .result()
        }
        
        // 获取当前选择的学者
        var currentSelectedId: String?
        if let appGroupDefaults = UserDefaults(suiteName: groupIdentifier) {
            currentSelectedId = appGroupDefaults.string(forKey: "SelectedWidgetScholarId")
        }
        if currentSelectedId == nil {
            currentSelectedId = UserDefaults.standard.string(forKey: "SelectedWidgetScholarId")
        }
        
        // 找到下一个学者
        var nextScholar: WidgetScholarInfo
        if let currentId = currentSelectedId,
           let currentIndex = scholars.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = (currentIndex + 1) % scholars.count
            nextScholar = scholars[nextIndex]
        } else {
            nextScholar = scholars[0]
        }
        
        // 设置切换标记，不清除其他标记
        if let appGroupDefaults = UserDefaults(suiteName: groupIdentifier) {
            appGroupDefaults.set(nextScholar.id, forKey: "SelectedWidgetScholarId")
            appGroupDefaults.set(nextScholar.displayName, forKey: "SelectedWidgetScholarName")
            appGroupDefaults.set(true, forKey: "ScholarSwitched")
            appGroupDefaults.synchronize()
        }
        UserDefaults.standard.set(nextScholar.id, forKey: "SelectedWidgetScholarId")
        UserDefaults.standard.set(nextScholar.displayName, forKey: "SelectedWidgetScholarName")
        UserDefaults.standard.set(true, forKey: "ScholarSwitched")
        UserDefaults.standard.synchronize()
        
        print("✅ [Intent] 🎯 切换标记已设置: ScholarSwitched = true")
        
        // 立即触发小组件刷新
        WidgetCenter.shared.reloadAllTimelines()
        
        print("✅ [Intent] 已切换到学者: \(nextScholar.displayName)")
        return .result()
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
    @State private var refreshAngle: Double = 0
    // 使用 isSwitching 驱动缩放，避免在 WidgetKit 重建视图时丢失回弹
    @State private var animationTrigger: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var isSwitching: Bool = false
    @State private var showRefreshAck: Bool = false
    @State private var refreshInProgress: Bool = false
    @State private var refreshBlinkOn: Bool = false
    // 刷新时主体内容转场：淡出+轻微缩放，再淡入
    @State private var contentScale: Double = 1.0
    @State private var contentOpacity: Double = 1.0
    // 切换按钮仅高亮，不替换为勾号
    @State private var observedSwitchScale: Double = 1.0
    // 切换按钮脉冲反馈所需状态（不改变按钮本体大小）
    @State private var showSwitchPulse: Bool = false
    @State private var switchPulseScale: Double = 1.0
    @State private var switchPulseOpacity: Double = 0.0
    // 切换按钮背景高亮独立状态，避免长时间停留
    @State private var switchHighlight: Bool = false
    
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
                    
                    // 中心：大引用数显示（刷新转场：淡出淡入 + 轻缩放）
                    ZStack {
                    VStack(spacing: 6) {
                        Text((scholar.citations ?? 0).formattedNumber)
                            .font(.system(size: 42, weight: .heavy)) // 再次放大字体
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.5) // 允许更大缩放范围
                            .lineLimit(1)
                            .blur(radius: (isRefreshVisuallyActive(for: scholar.id)) ? 3.5 : 0)
                        
                        Text("引用数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .blur(radius: (isRefreshVisuallyActive(for: scholar.id)) ? 2.2 : 0)
                        }
                        .padding(.horizontal, 6)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .scaleEffect(contentScale)
                        .opacity(contentOpacity)
                        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: contentScale)
                        .animation(.easeInOut(duration: 0.18), value: contentOpacity)
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
                        // 左下角：切换按钮 - 使用AppIntent
                        if #available(iOS 17.0, *) {
                            Button(intent: ToggleScholarIntent()) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(switchHighlight ? Color.blue.opacity(0.35) : Color.blue.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "arrow.left.arrow.right")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                }
                                .modifier(SwitchScaleObserver(scale: isSwitching ? 0.88 : 1.0) { current in
                                    if abs(current - observedSwitchScale) > 0.0001 {
                                        observedSwitchScale = current
                                        print("🎯 [Widget] 切换按钮实时缩放: \(String(format: "%.3f", current))  isSwitching=\(isSwitching)")
                                    }
                                })
                            }
                            .buttonStyle(EnhancedWidgetButtonStyle())
                        } else {
                            // iOS 17以下使用Link作为后备
                        Link(destination: URL(string: "citetrack://switch")!) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(16)
                            }
                        }
                        
                        Spacer()
                        
                        // 中间：趋势指示器（固定宽度，包含箭头）
                        HStack {
                            Spacer()
                            HStack(spacing: 3) {
                                Text(scholar.citationTrend.symbol)
                                    .font(.caption2) // 缩小箭头字体
                                Text(scholar.citationTrend.text)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(scholar.citationTrend.color)
                            .lineLimit(1)
                            Spacer()
                        }
                        .blur(radius: (isRefreshVisuallyActive(for: scholar.id)) ? 2.2 : 0)
                        .frame(minWidth: 80) // 增加中间区域宽度以避免省略号
                        
                        Spacer()
                        
                        // 右下角：刷新按钮 - 使用AppIntent
                        if #available(iOS 17.0, *) {
                            Button(intent: QuickRefreshIntent()) {
                                ZStack {
                                    // 背景根据刷新状态高亮
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.green)
                                        .opacity(isValidInProgress(for: entry.primaryScholar?.id) ? (refreshBlinkOn ? 0.7 : 0.35) : 0.15)
                                        .frame(width: 32, height: 32)

                                    // 刷新中：转圈图标；完成：对勾
                                    Group {
                                        if showRefreshAck {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.green)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.title3)
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(EnhancedWidgetButtonStyle())
                        } else {
                            // iOS 17以下使用Link作为后备
                        Link(destination: URL(string: "citetrack://refresh")!) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                                .foregroundColor(.green)
                                .frame(width: 32, height: 32)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal, 2) // 更少的padding让按钮更靠近角落
                    .padding(.bottom, 2) // 恢复按钮原来的位置
                }

                // 右上角调试状态角标（按当前学者显示）
                if debugOverlayEnabled() {
                    let currentId = entry.primaryScholar?.id
                    let debug = refreshDebugStatus(for: currentId)
                    VStack {
                        HStack {
                            Spacer()
                            Text(debug.text)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(debug.color.opacity(0.9))
                                .cornerRadius(6)
                                .padding(.top, 4)
                                .padding(.trailing, 4)
                        }
                        Spacer()
                    }
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
            // .overlay(调试信息已移除)
            .onAppear {
                print("📱 [Widget] ===== SmallWidgetView onAppear =====")
                print("📱 [Widget] 当前 refreshAngle: \(refreshAngle)")
                print("📱 [Widget] 当前 isRefreshing: \(isRefreshing)")
                // 确保切换按钮初始为原始大小
                // 复位脉冲与高亮状态
                showSwitchPulse = false
                switchPulseScale = 1.0
                switchPulseOpacity = 0.0
                switchHighlight = false
                // 检查动画触发标记（按学者）
                checkRefreshAnimationOnly(for: entry.primaryScholar?.id)
                checkSwitchAnimationOnly()
                // 启动时校正进行中状态（若已完成则复位）
                checkRefreshCompletion(for: entry.primaryScholar?.id)
            }
            .onChange(of: entry.date) {
                print("📱 [Widget] ===== Entry date changed =====")
                print("📱 [Widget] 当前 refreshAngle: \(refreshAngle)")
                print("📱 [Widget] 当前 isRefreshing: \(isRefreshing)")
                // 条目更新时再次检查动画（按学者）
                checkRefreshAnimationOnly(for: entry.primaryScholar?.id)
                checkSwitchAnimationOnly()
                checkRefreshCompletion(for: entry.primaryScholar?.id)
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
                
                // 添加测试按钮
                Button(intent: DebugTestIntent()) {
                    Text("调试测试")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
                
                // 添加强制刷新按钮
                Button(intent: ForceRefreshIntent()) {
                    Text("强制刷新")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Spacer()
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
    
    /// 检查是否今天更新过
    private func isUpdatedToday(_ lastRefreshTime: Date?) -> Bool {
        guard let lastRefresh = lastRefreshTime else { return false }
        
        let calendar = Calendar.current
        let today = Date()
        
        return calendar.isDate(lastRefresh, inSameDayAs: today)
    }
    

    
    /// 基于时间戳检查刷新动画
    private func checkForRefreshAnimation() {
        let lastRefreshKey = "LastRefreshAnimationTime"
        let currentTime = Date().timeIntervalSince1970
        
        // 从UserDefaults获取上次动画时间
        let lastAnimationTime = UserDefaults.standard.double(forKey: lastRefreshKey)
        
        // 如果距离上次动画超过2秒，且有新的刷新时间戳，则播放动画
        if let lastRefreshTime = UserDefaults.standard.object(forKey: "LastRefreshTime") as? Date {
            let refreshTimeStamp = lastRefreshTime.timeIntervalSince1970
            
            // 如果刷新时间比上次动画时间新，则播放动画
            if refreshTimeStamp > lastAnimationTime {
                print("🔄 [Widget] 检测到新的刷新时间戳，播放动画")
                performRefreshAnimation()
                
                // 更新动画时间戳
                UserDefaults.standard.set(currentTime, forKey: lastRefreshKey)
            }
        }
    }
    
    /// 基于时间戳检查切换动画
    private func checkForSwitchAnimation() {
        let lastSwitchKey = "LastSwitchAnimationTime"
        let currentTime = Date().timeIntervalSince1970
        
        let lastAnimationTime = UserDefaults.standard.double(forKey: lastSwitchKey)
        
        // 检查学者切换时间戳
        if let lastSwitchTime = UserDefaults.standard.object(forKey: "LastScholarSwitchTime") as? Date {
            let switchTimeStamp = lastSwitchTime.timeIntervalSince1970
            
            if switchTimeStamp > lastAnimationTime {
                print("🎯 [Widget] 检测到新的切换时间戳，播放动画")
                performSwitchAnimation()
                
                UserDefaults.standard.set(currentTime, forKey: lastSwitchKey)
            }
        }
    }
    
    /// 只检查切换动画 - 使用独立管理器
    private func checkSwitchAnimationOnly() {
        let switchManager = SwitchButtonManager.shared
        let shouldSwitch = switchManager.shouldPlayAnimation()
        
        print("🔍 [Widget] 独立检查切换动画: \(shouldSwitch), 当前状态: \(isSwitching)")
        
        if shouldSwitch && !isSwitching {
            print("🎯 [Widget] ✅ 独立触发切换动画")
            performSwitchAnimation()
        }
    }
    
    /// 只检查刷新动画 - 使用独立管理器（按学者隔离）
    private func checkRefreshAnimationOnly(for scholarId: String?) {
        print("🔍 [Widget] ===== 开始检查刷新动画 =====")
        let refreshManager = RefreshButtonManager.shared
        var shouldRefresh = refreshManager.shouldPlayAnimation()
        // 同时读取"进行中"状态与开始时间，驱动按钮常亮和模糊（按学者）
        let groupID = appGroupIdentifier
        var inProgress = false
        var startTime: Date? = nil
        let sid = scholarId ?? (entry.primaryScholar?.id)
        let inProgressKey = sid != nil ? "RefreshInProgress_\(sid!)" : "RefreshInProgress"
        let startKey = sid != nil ? "RefreshStartTime_\(sid!)" : "RefreshStartTime"
        let triggerKey = sid != nil ? "RefreshTriggerTime_\(sid!)" : "RefreshTriggerTime"
        let forceWindow: TimeInterval = 2.5
        var recentTriggered = false
        print("🔎 [Widget] checkRefreshAnimationOnly for sid=\(sid ?? "nil") inKey=\(inProgressKey) startKey=\(startKey)")
        if let appGroupDefaults = UserDefaults(suiteName: groupID) {
            inProgress = appGroupDefaults.bool(forKey: inProgressKey)
            startTime = appGroupDefaults.object(forKey: startKey) as? Date
            if let trig = appGroupDefaults.object(forKey: triggerKey) as? Date {
                recentTriggered = Date().timeIntervalSince(trig) <= forceWindow
            }
        } else {
            inProgress = UserDefaults.standard.bool(forKey: inProgressKey)
            startTime = UserDefaults.standard.object(forKey: startKey) as? Date
            if let trig = UserDefaults.standard.object(forKey: triggerKey) as? Date {
                recentTriggered = Date().timeIntervalSince(trig) <= forceWindow
            }
        }
        print("🔎 [Widget] read inProgress=\(inProgress) startTime=\(String(describing: startTime))")
        if !shouldRefresh && recentTriggered {
            print("🔄 [Widget] 兜底：检测到最近触发时间戳，强制 shouldRefresh = true")
            shouldRefresh = true
        }
        // 兜底：最近触发则立即进入本地 InProg 视觉态（即刻闪烁+模糊）
        if recentTriggered && !refreshInProgress {
            refreshInProgress = true
            startRefreshBlink()
            if !isRefreshing {
                print("🔄 [Widget] 兜底：recentTriggered 命中，立即启动 performRefreshAnimation")
                performRefreshAnimation()
            }
        }
        // 若没有开始时间，则不应处于进行中，强制复位
        if startTime == nil && inProgress {
            print("🔄 [Widget] 检测到无开始时间但处于进行中，强制复位")
            inProgress = false
            refreshInProgress = false
            if let appGroupDefaults = UserDefaults(suiteName: groupID) {
                appGroupDefaults.set(false, forKey: inProgressKey)
                appGroupDefaults.synchronize()
            } else {
                UserDefaults.standard.set(false, forKey: inProgressKey)
            }
            stopRefreshBlink()
        }
        if refreshInProgress != inProgress {
            refreshInProgress = inProgress
            print("🔄 [Widget] 刷新进行中状态更新: \(inProgress)")
            if inProgress {
                // 开始按钮闪烁
                startRefreshBlink()
            } else {
                // 停止闪烁
                stopRefreshBlink()
            }
        }
        
        print("🔍 [Widget] 独立检查刷新动画: \(shouldRefresh), 当前状态: \(isRefreshing)")
        
        if shouldRefresh && !isRefreshing {
            print("🔄 [Widget] ✅ 独立触发刷新动画 - 即将调用performRefreshAnimation")
            performRefreshAnimation()
            print("🔄 [Widget] ✅ performRefreshAnimation调用完成")
        } else {
            print("🔄 [Widget] ❌ 不触发刷新动画 - shouldRefresh: \(shouldRefresh), isRefreshing: \(isRefreshing)")
        }
        print("🔍 [Widget] ===== 刷新动画检查结束 =====")
    }
    
    /// 检查刷新完成（按学者）：若 LastRefreshTime_<id> > RefreshStartTime_<id>，则视为完成
    private func checkRefreshCompletion(for scholarId: String?) {
        let groupID = appGroupIdentifier
        var startTime: Date? = nil
        var lastTime: Date? = nil
        let sid = scholarId ?? (entry.primaryScholar?.id)
        let startKey = sid != nil ? "RefreshStartTime_\(sid!)" : "RefreshStartTime"
        let lastKey = sid != nil ? "LastRefreshTime_\(sid!)" : "LastRefreshTime"
        let inProgressKey = sid != nil ? "RefreshInProgress_\(sid!)" : "RefreshInProgress"
        print("🔎 [Widget] checkRefreshCompletion for sid=\(sid ?? "nil") startKey=\(startKey) lastKey=\(lastKey)")
        if let appGroupDefaults = UserDefaults(suiteName: groupID) {
            startTime = appGroupDefaults.object(forKey: startKey) as? Date
            lastTime = appGroupDefaults.object(forKey: lastKey) as? Date
        } else {
            startTime = UserDefaults.standard.object(forKey: startKey) as? Date
            lastTime = UserDefaults.standard.object(forKey: lastKey) as? Date
        }
        // 回落逻辑：若该学者无 lastTime，但全局 last 比 start 新，也视为完成
        let sOpt = startTime
        var lOpt = lastTime
        if lOpt == nil, let sid = sid {
            let global = (UserDefaults(suiteName: groupID)?.object(forKey: "LastRefreshTime") as? Date) ?? (UserDefaults.standard.object(forKey: "LastRefreshTime") as? Date)
            print("🔎 [Widget] fallback check: globalLast=\(String(describing: global)) start=\(String(describing: sOpt))")
            if let g = global, let s = sOpt, g > s {
                lOpt = global
                // 回写学者 last，并清 inProgress
                if let appGroupDefaults = UserDefaults(suiteName: groupID) {
                    appGroupDefaults.set(g, forKey: "LastRefreshTime_\(sid)")
                    appGroupDefaults.set(false, forKey: "RefreshInProgress_\(sid)")
                    appGroupDefaults.synchronize()
                }
                UserDefaults.standard.set(g, forKey: "LastRefreshTime_\(sid)")
                UserDefaults.standard.set(false, forKey: "RefreshInProgress_\(sid)")
                print("✅ [Widget] 使用全局Last回写完成: sid=\(sid) last=\(g)")
            }
        }
        print("🔎 [Widget] completion compare: start=\(String(describing: sOpt)) last=\(String(describing: lOpt))")
        // A. 标准路径：存在 start 并且 last > start
        if let s = sOpt, let l = lOpt, l > s {
            // 刷新完成：复位进行中与闪烁
            refreshInProgress = false
            stopRefreshBlink()
            isRefreshing = false
            // 显示对勾反馈一小段时间
            showRefreshAck = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showRefreshAck = false
            }
            print("✅ [Widget] 检测到刷新完成，已复位进行中状态")
            // 清理标记（尽量在 App Group），同时清除触发时间键以避免兜底窗口继续判定进行中，并强制刷新时间线
            if let appGroupDefaults = UserDefaults(suiteName: groupID) {
                appGroupDefaults.removeObject(forKey: inProgressKey)
                if let sid = sid {
                    appGroupDefaults.removeObject(forKey: "RefreshStartTime_\(sid)")
                    appGroupDefaults.removeObject(forKey: "RefreshTriggerTime_\(sid)")
                }
                appGroupDefaults.removeObject(forKey: "RefreshTriggerTime")
                appGroupDefaults.synchronize()
                WidgetCenter.shared.reloadAllTimelines()
            } else {
                UserDefaults.standard.removeObject(forKey: inProgressKey)
                if let sid = sid {
                    UserDefaults.standard.removeObject(forKey: "RefreshStartTime_\(sid)")
                    UserDefaults.standard.removeObject(forKey: "RefreshTriggerTime_\(sid)")
                }
                UserDefaults.standard.removeObject(forKey: "RefreshTriggerTime")
                WidgetCenter.shared.reloadAllTimelines()
            }
            return
        }
        // B. 兜底路径：无 start 但最近有 last（3s 内），也判定完成
        if let l = lOpt {
            if Date().timeIntervalSince(l) <= 1.5 {
                refreshInProgress = false
                stopRefreshBlink()
                isRefreshing = false
                showRefreshAck = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    showRefreshAck = false
                }
                if let appGroupDefaults = UserDefaults(suiteName: groupID) {
                    if let sid = sid {
                        appGroupDefaults.removeObject(forKey: "RefreshInProgress_\(sid)")
                        appGroupDefaults.removeObject(forKey: "RefreshStartTime_\(sid)")
                        appGroupDefaults.removeObject(forKey: "RefreshTriggerTime_\(sid)")
                    }
                    appGroupDefaults.removeObject(forKey: "RefreshTriggerTime")
                    appGroupDefaults.synchronize()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                if let sid = sid {
                    UserDefaults.standard.removeObject(forKey: "RefreshInProgress_\(sid)")
                    UserDefaults.standard.removeObject(forKey: "RefreshStartTime_\(sid)")
                    UserDefaults.standard.removeObject(forKey: "RefreshTriggerTime_\(sid)")
                }
                UserDefaults.standard.removeObject(forKey: "RefreshTriggerTime")
                WidgetCenter.shared.reloadAllTimelines()
                print("✅ [Widget] 兜底完成：last 新近写入，显示对勾并清理进行中标记")
            }
        }
    }

    private func startRefreshBlink() {
        // 简单闪烁：切换布尔，依赖 WidgetKit 触发多次渲染可能受限，但尽量呈现
        refreshBlinkOn = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            refreshBlinkOn.toggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if refreshInProgress {
                startRefreshBlink()
            }
        }
    }

    private func stopRefreshBlink() {
        refreshBlinkOn = false
    }

    /// 读取可配置的超时时长（秒）。默认 90，可通过 App Group 或标准存储中的 `WidgetRefreshTimeoutSeconds` 覆盖（范围30~600）。
    private func refreshTimeoutSeconds() -> TimeInterval {
        let key = "WidgetRefreshTimeoutSeconds"
        let minV: TimeInterval = 30
        let maxV: TimeInterval = 600
        var value: TimeInterval = 90
        if let appGroup = UserDefaults(suiteName: appGroupIdentifier), appGroup.object(forKey: key) != nil {
            value = TimeInterval(appGroup.integer(forKey: key))
        } else if UserDefaults.standard.object(forKey: key) != nil {
            value = TimeInterval(UserDefaults.standard.integer(forKey: key))
        }
        if value < minV { return minV }
        if value > maxV { return maxV }
        return value
    }

    /// 校验进行中是否有效：需有开始时间，且未超时
    private func isValidInProgress(for scholarId: String?) -> Bool {
        let groupID = appGroupIdentifier
        let now = Date()
        let timeout: TimeInterval = refreshTimeoutSeconds()
        // 兜底：触发后短时间内强制认为 InProg，避免未及时读到开始键（窗口不要过长，避免完成后仍被判定进行中）
        let forceWindow: TimeInterval = 0.7
        var inProgress = false
        var startTime: Date? = nil
        let sid = scholarId ?? (entry.primaryScholar?.id)
        let inProgressKey = sid != nil ? "RefreshInProgress_\(sid!)" : "RefreshInProgress"
        let startKey = sid != nil ? "RefreshStartTime_\(sid!)" : "RefreshStartTime"
        let triggerKey = sid != nil ? "RefreshTriggerTime_\(sid!)" : "RefreshTriggerTime"
        let triggerKeyGlobal = "RefreshTriggerTime"
        if let appGroupDefaults = UserDefaults(suiteName: groupID) {
            inProgress = appGroupDefaults.bool(forKey: inProgressKey)
            startTime = appGroupDefaults.object(forKey: startKey) as? Date
            // 兜底：最近触发时间命中窗口也视为进行中
            if !inProgress && startTime == nil {
                if let trig = appGroupDefaults.object(forKey: triggerKey) as? Date, now.timeIntervalSince(trig) <= forceWindow {
                    inProgress = true
                } else if let gtrig = appGroupDefaults.object(forKey: triggerKeyGlobal) as? Date, now.timeIntervalSince(gtrig) <= forceWindow {
                    inProgress = true
                }
            }
        } else {
            inProgress = UserDefaults.standard.bool(forKey: inProgressKey)
            startTime = UserDefaults.standard.object(forKey: startKey) as? Date
            if !inProgress && startTime == nil {
                if let trig = UserDefaults.standard.object(forKey: triggerKey) as? Date, now.timeIntervalSince(trig) <= forceWindow {
                    inProgress = true
                } else if let gtrig = UserDefaults.standard.object(forKey: triggerKeyGlobal) as? Date, now.timeIntervalSince(gtrig) <= forceWindow {
                    inProgress = true
                }
            }
        }
        // 若因兜底进入进行中但 start 仍未写入，也要让UI显示模糊
        if inProgress && startTime == nil { return true }
        guard inProgress, let s = startTime else { return false }
        if now.timeIntervalSince(s) > timeout {
            let sidText = sid ?? "nil"
            print("⏱️ [Widget] 刷新超时: sid=\(sidText) start=\(s) timeout=\(Int(timeout))s, 自动清理标记")
            // 超时清理放到异步，避免在视图更新周期直接改状态
            DispatchQueue.main.async {
                if let appGroupDefaults = UserDefaults(suiteName: groupID) {
                    appGroupDefaults.removeObject(forKey: inProgressKey)
                    appGroupDefaults.removeObject(forKey: startKey)
                    appGroupDefaults.synchronize()
                }
                UserDefaults.standard.removeObject(forKey: inProgressKey)
                UserDefaults.standard.removeObject(forKey: startKey)
                // 停止本地动画状态
                refreshInProgress = false
                stopRefreshBlink()
                isRefreshing = false
            }
            return false
        }
        return true
    }

    /// 读取 App Group 与标准存储的刷新时间戳信息
    private func getRefreshTimestamps(for scholarId: String?) -> (inProgress: Bool, start: Date?, last: Date?) {
        let groupID = appGroupIdentifier
        var inProgress = false
        var startTime: Date? = nil
        var lastTime: Date? = nil
        let sid = scholarId ?? (entry.primaryScholar?.id)
        let inProgressKey = sid != nil ? "RefreshInProgress_\(sid!)" : "RefreshInProgress"
        let startKey = sid != nil ? "RefreshStartTime_\(sid!)" : "RefreshStartTime"
        let lastKey = sid != nil ? "LastRefreshTime_\(sid!)" : "LastRefreshTime"
        if let appGroupDefaults = UserDefaults(suiteName: groupID) {
            inProgress = appGroupDefaults.bool(forKey: inProgressKey)
            startTime = appGroupDefaults.object(forKey: startKey) as? Date
            lastTime = appGroupDefaults.object(forKey: lastKey) as? Date
        } else {
            inProgress = UserDefaults.standard.bool(forKey: inProgressKey)
            startTime = UserDefaults.standard.object(forKey: startKey) as? Date
            lastTime = UserDefaults.standard.object(forKey: lastKey) as? Date
        }
        print("🔎 [Widget] getTS sid=\(sid ?? "nil") in=\(inProgress) start=\(String(describing: startTime)) last=\(String(describing: lastTime))")
        return (inProgress, startTime, lastTime)
    }

    /// 计算当前是否应当显示“刷新进行中”的视觉态（用于模糊等），完全基于持久化时间戳，避免依赖本地 @State。
    private func isRefreshVisuallyActive(for scholarId: String?) -> Bool {
        let groupID = appGroupIdentifier
        let now = Date()
        let timeout: TimeInterval = refreshTimeoutSeconds()
        let sid = scholarId ?? (entry.primaryScholar?.id)
        let startKey = sid != nil ? "RefreshStartTime_\(sid!)" : "RefreshStartTime"
        let lastKey = sid != nil ? "LastRefreshTime_\(sid!)" : "LastRefreshTime"
        let trigKey = sid != nil ? "RefreshTriggerTime_\(sid!)" : "RefreshTriggerTime"
        var startTime: Date? = nil
        var lastTime: Date? = nil
        var trigTime: Date? = nil
        if let app = UserDefaults(suiteName: groupID) {
            startTime = app.object(forKey: startKey) as? Date
            lastTime = app.object(forKey: lastKey) as? Date
            trigTime = app.object(forKey: trigKey) as? Date
        } else {
            startTime = UserDefaults.standard.object(forKey: startKey) as? Date
            lastTime = UserDefaults.standard.object(forKey: lastKey) as? Date
            trigTime = UserDefaults.standard.object(forKey: trigKey) as? Date
        }
        // 若刚触发（短窗口内），直接显示进行中视觉态
        if let t = trigTime, now.timeIntervalSince(t) <= 0.9 { return true }
        // 若存在 start 且未超时，并且尚未检测到完成（last <= start 或 last 为 nil），则显示进行中
        if let s = startTime {
            if now.timeIntervalSince(s) <= timeout {
                if let l = lastTime {
                    return l <= s
                }
                return true
            }
        }
        return false
    }

    /// 刷新调试状态文本与颜色（Idle/InProg/Done/Timeout）
    private func refreshDebugStatus(for scholarId: String?) -> (text: String, color: Color) {
        let (inProgress, startOpt, lastOpt) = getRefreshTimestamps(for: scholarId)
        let now = Date()
        let timeout: TimeInterval = refreshTimeoutSeconds()
        if let s = startOpt, let l = lastOpt, l > s {
            return ("Done", .green)
        }
        if inProgress, let s = startOpt {
            if now.timeIntervalSince(s) > timeout {
                return ("Timeout", .orange)
            }
            return ("InProg", .yellow)
        }
        return ("Idle", .secondary)
    }

    /// 是否显示调试状态角标（默认开启，可通过 App Group 键关闭）
    private func debugOverlayEnabled() -> Bool {
        let key = "WidgetDebugOverlayEnabled"
        if let appGroup = UserDefaults(suiteName: appGroupIdentifier) {
            if appGroup.object(forKey: key) != nil {
                return appGroup.bool(forKey: key)
            }
        }
        if UserDefaults.standard.object(forKey: key) != nil {
            return UserDefaults.standard.bool(forKey: key)
        }
        return true
    }
    
    /// 执行切换视觉反馈（高亮+脉冲光环）
    private func performSwitchAnimation() {
        guard !isSwitching else { return }

        isSwitching = true
        print("🎯 [Widget] 切换反馈开始（高亮+脉冲） isSwitching=true")
        // 背景高亮开启
        self.switchHighlight = true
        // 启动脉冲光环动画
        self.showSwitchPulse = true
        self.switchPulseScale = 0.7
        self.switchPulseOpacity = 0.6
        withAnimation(.easeOut(duration: 0.4)) {
            self.switchPulseScale = 1.25
            self.switchPulseOpacity = 0.0
        }
        // 结束脉冲与高亮（无条件复位，避免亮度残留）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.isSwitching = false
            self.showSwitchPulse = false
            self.switchPulseScale = 1.0
            self.switchPulseOpacity = 0.0
            self.switchHighlight = false
            print("🎯 [Widget] 结束高亮 isSwitching=false（脉冲停止, 背景复位）")
        }
    }
    

    
    /// 执行刷新动画 - 简化版本
    private func performRefreshAnimation() {
        print("🔄 [Widget] ===== performRefreshAnimation 开始执行 =====")
        print("🔄 [Widget] 当前 isRefreshing 状态: \(isRefreshing)")
        
        guard !isRefreshing else { 
            print("🔄 [Widget] ⚠️ 刷新动画已在进行，跳过")
            return 
        }
        
        isRefreshing = true
        print("🔄 [Widget] 设置 isRefreshing = true")
        print("🔄 [Widget] 进入刷新进行中：按钮闪烁 + 中心模糊")
        showRefreshAck = false
        refreshInProgress = true
        startRefreshBlink()

        // 不触发切换式效果
        
        // 不在此处复位，由数据到达后复位
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

// MARK: - 独立的按钮管理器
class SwitchButtonManager {
    static let shared = SwitchButtonManager()
    // 使用全局定义的 appGroupIdentifier
    private init() {}
    
    func shouldPlayAnimation() -> Bool {
        // 优先检查App Group
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            let shouldPlay = appGroupDefaults.bool(forKey: "ScholarSwitched")
            if shouldPlay {
                appGroupDefaults.removeObject(forKey: "ScholarSwitched")
                appGroupDefaults.synchronize()
                print("🎯 [SwitchManager] App Group 检测到切换标记，已清除")
                return true
            }
        }
        
        // 回退检查Standard
        let shouldPlay = UserDefaults.standard.bool(forKey: "ScholarSwitched")
        if shouldPlay {
            UserDefaults.standard.removeObject(forKey: "ScholarSwitched")
            print("🎯 [SwitchManager] Standard 检测到切换标记，已清除")
            return true
        }
        
        return false
    }
}

class RefreshButtonManager {
    static let shared = RefreshButtonManager()
    // 使用全局定义的 appGroupIdentifier
    private init() {}
    
    func shouldPlayAnimation() -> Bool {
        print("🔄 [RefreshManager] ===== 开始检查刷新标记 =====")
        
        // 优先检查App Group
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            print("🔄 [RefreshManager] App Group UserDefaults 创建成功")
            let shouldPlay = appGroupDefaults.bool(forKey: "RefreshTriggered")
            print("🔄 [RefreshManager] App Group RefreshTriggered 值: \(shouldPlay)")
            if shouldPlay {
                appGroupDefaults.removeObject(forKey: "RefreshTriggered")
                appGroupDefaults.synchronize()
                print("🔄 [RefreshManager] ✅ App Group 检测到刷新标记，已清除")
                return true
            }
        } else {
            print("🔄 [RefreshManager] ❌ App Group UserDefaults 创建失败")
        }
        
        // 回退检查Standard
        print("🔄 [RefreshManager] 检查 Standard UserDefaults")
        let shouldPlay = UserDefaults.standard.bool(forKey: "RefreshTriggered")
        print("🔄 [RefreshManager] Standard RefreshTriggered 值: \(shouldPlay)")
        if shouldPlay {
            UserDefaults.standard.removeObject(forKey: "RefreshTriggered")
            print("🔄 [RefreshManager] ✅ Standard 检测到刷新标记，已清除")
            return true
        }
        
        print("🔄 [RefreshManager] ❌ 未发现刷新标记")
        print("🔄 [RefreshManager] ===== 刷新标记检查结束 =====")
        return false
    }
}

// MARK: - 小组件按钮管理器（保留兼容性）
class WidgetButtonManager {
    static let shared = WidgetButtonManager()
    // 使用全局定义的 appGroupIdentifier
    
    private init() {}
    
    /// 触发切换动画标记
    func triggerSwitchAnimation() {
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            appGroupDefaults.set(true, forKey: "ScholarSwitched")
        }
        UserDefaults.standard.set(true, forKey: "ScholarSwitched")
    }
    
    /// 触发刷新动画标记
    func triggerRefreshAnimation() {
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            appGroupDefaults.set(true, forKey: "RefreshTriggered")
        }
        UserDefaults.standard.set(true, forKey: "RefreshTriggered")
    }
    
    /// 清除动画标记
    func clearAnimationFlags() {
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            appGroupDefaults.removeObject(forKey: "ScholarSwitched")
            appGroupDefaults.removeObject(forKey: "RefreshTriggered")
        }
        UserDefaults.standard.removeObject(forKey: "ScholarSwitched")
        UserDefaults.standard.removeObject(forKey: "RefreshTriggered")
    }
    
    /// 检查是否需要播放切换动画 - 完全独立版本
    func shouldPlaySwitchAnimation() -> Bool {
        // 优先检查App Group
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            let shouldPlay = appGroupDefaults.bool(forKey: "ScholarSwitched")
            if shouldPlay {
                // 只清除自己的标记，不读取其他标记
                appGroupDefaults.removeObject(forKey: "ScholarSwitched")
                appGroupDefaults.synchronize()
                print("🎯 [ButtonManager] App Group 检测到切换标记，已清除")
                return true
            }
        }
        
        // 回退检查Standard
        let shouldPlay = UserDefaults.standard.bool(forKey: "ScholarSwitched")
        if shouldPlay {
            UserDefaults.standard.removeObject(forKey: "ScholarSwitched")
            print("🎯 [ButtonManager] Standard 检测到切换标记，已清除")
            return true
        }
        
        return false
    }
    
    /// 检查是否需要播放刷新动画 - 完全独立版本
    func shouldPlayRefreshAnimation() -> Bool {
        // 优先检查App Group
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            let shouldPlay = appGroupDefaults.bool(forKey: "RefreshTriggered")
            if shouldPlay {
                // 只清除自己的标记，不读取其他标记
                appGroupDefaults.removeObject(forKey: "RefreshTriggered")
                appGroupDefaults.synchronize()
                print("🔄 [ButtonManager] App Group 检测到刷新标记，已清除")
                return true
            }
        }
        
        // 回退检查Standard
        let shouldPlay = UserDefaults.standard.bool(forKey: "RefreshTriggered")
        if shouldPlay {
            UserDefaults.standard.removeObject(forKey: "RefreshTriggered")
            print("🔄 [ButtonManager] Standard 检测到刷新标记，已清除")
            return true
        }
        
        return false
    }
}

// MARK: - 自定义按钮样式，提供视觉反馈
struct WidgetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 增强版按钮样式 - 更丰富的视觉反馈
struct EnhancedWidgetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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