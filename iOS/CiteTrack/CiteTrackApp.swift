import SwiftUI
import BackgroundTasks
import WidgetKit
import UniformTypeIdentifiers
import AppIntents

@main
struct CiteTrackApp: App {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var dataManager = DataManager.shared
    @Environment(\.scenePhase) private var scenePhase
    private static let refreshTaskIdentifier = "com.citetrack.citationRefresh"
    
    init() {
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
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(colorScheme)
                .environmentObject(dataManager)
                .onOpenURL { url in
                    handleDeepLink(url: url)
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
                print("🧪 [CiteTrackApp] scenePhase.active 同步 LastRefreshTime: old=\(old?.description ?? "nil") -> new=\(t?.description ?? "nil")")
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
        print("🔗 [DeepLink] 接收到深度链接: \(url)")
        
        guard url.scheme == "citetrack" else {
            print("❌ [DeepLink] 无效的URL scheme: \(url.scheme ?? "nil")")
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
            print("🔄 [DeepLink] 收到刷新请求")
            handleWidgetRefresh()
        case "switch":
            // Widget切换按钮点击
            print("🎯 [DeepLink] 收到切换学者请求")
            handleWidgetScholarSwitch()
        default:
            print("❌ [DeepLink] 不支持的深度链接: \(url)")
        }
    }
    
    // MARK: - Widget Action Handlers
    private func handleWidgetRefresh() {
        print("🔄 [Widget] 开始处理刷新请求")
        
        // 设置刷新时间戳，Widget会检测到这个时间戳并播放动画
        let now = Date()
        UserDefaults.standard.set(now, forKey: "LastRefreshTime")
        if let appGroup = UserDefaults(suiteName: appGroupIdentifier) {
            appGroup.set(now, forKey: "LastRefreshTime")
            appGroup.synchronize()
            print("🧪 [CiteTrackApp] AppGroup 写入 LastRefreshTime=\(now)")
        }
        print("🧪 [CiteTrackApp] Standard 写入 LastRefreshTime=\(now)")
        // 发送Darwin通知，提示主应用各管理器同步
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName("com.citetrack.lastRefreshTimeUpdated" as CFString), nil, nil, true)
        print("🧪 [CiteTrackApp] 已发送 Darwin 通知: com.citetrack.lastRefreshTimeUpdated")
        
        // 如果有学者数据，触发实际的数据刷新
        let scholars = dataManager.scholars
        
        if !scholars.isEmpty {
            print("🔄 [Widget] 刷新 \(scholars.count) 位学者数据")
            
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
                            print("❌ Widget刷新失败: \(scholar.id) - \(error.localizedDescription)")
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                // 🎯 使用DataManager的refreshWidgets来计算并保存变化数据
                self.dataManager.refreshWidgets()
                print("✅ [Widget] 刷新完成，更新小组件")
            }
        } else {
            // 没有学者数据，直接更新小组件
            dataManager.refreshWidgets()
        }
    }
    
    private func handleWidgetScholarSwitch() {
        print("🎯 [Widget] 开始处理学者切换请求")
        
        // 设置切换时间戳，Widget会检测到这个时间戳并播放动画
        UserDefaults.standard.set(Date(), forKey: "LastScholarSwitchTime")
        
        let scholars = dataManager.scholars
        
        if scholars.count > 1 {
            // 获取当前显示的学者索引
            let currentIndex = UserDefaults.standard.integer(forKey: "CurrentScholarIndex")
            let nextIndex = (currentIndex + 1) % scholars.count
            
            // 保存新的索引
            UserDefaults.standard.set(nextIndex, forKey: "CurrentScholarIndex")
            
            print("🎯 [Widget] 切换到学者 \(nextIndex): \(scholars[nextIndex].displayName)")
            
            // 更新小组件
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            print("🎯 [Widget] 学者数量不足，无法切换")
            // 仍然更新小组件以提供反馈
            WidgetCenter.shared.reloadAllTimelines()
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
            print("📅 已安排后台刷新: \(request.earliestBeginDate?.description ?? "unknown")")
        } catch {
            print("❌ 安排后台刷新失败: \(error)")
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
                        DataManager.shared.saveHistoryIfChanged(scholarId: scholar.id, citationCount: info.citations)
                    case .failure(let error):
                        print("❌ 后台更新失败: \(scholar.id) - \(error.localizedDescription)")
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            // 🎯 使用DataManager的refreshWidgets来刷新已计算好的数据
            DataManager.shared.refreshWidgets()
            task.setTaskCompleted(success: true)
        }
    }
}

struct MainView: View {
    @State private var selectedTab = 0
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text(localizationManager.localized("dashboard"))
                }
                .tag(0)
            
            NewScholarView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text(localizationManager.localized("scholars"))
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text(localizationManager.localized("settings"))
                }
                .tag(2)
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

// 仪表板视图
struct DashboardView: View {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 统计卡片
                    HStack(spacing: 12) {
                        StatisticsCard(
                            title: localizationManager.localized("total_citations"),
                            value: "\(dataManager.scholars.reduce(0) { $0 + ($1.citations ?? 0) })",
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
                    
                    // 学者列表
                    if !dataManager.scholars.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localizationManager.localized("scholar_list"))
                                .font(.headline)
                            
                            ForEach(dataManager.scholars, id: \.id) { scholar in
                                ScholarRow(scholar: scholar)
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
                }
                .padding()
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
    @State private var showingDeleteAllAlert = false
    
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
            .navigationTitle(localizationManager.localized("scholar_management"))
            .toolbar { toolbarContent }
            .refreshable { await refreshAllScholarsAsync() }
            .sheet(item: $activeSheet) { sheetType in
                switch sheetType {
                case .addScholar:
                    AddScholarView { newScholar in
                        dataManager.addScholar(newScholar)
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
            .overlay(loadingOverlay)
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
                        print("🔍 [NewScholar Debug] 点击了学者图表: \(scholar.displayName)")
                        activeSheet = .chart(scholar)
                    },
                    onUpdateTap: {
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
                        deleteScholar(scholar)
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
                }
            }
            .onDelete(perform: deleteScholars)
            .onMove { indices, newOffset in
                dataManager.applyMove(from: indices, to: newOffset)
            }
        }
        .coordinateSpace(name: "pullSpace")
        .toolbar { EditButton() }
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
        
        googleScholarService.fetchScholarInfo(for: scholar.id) { result in
            DispatchQueue.main.async {
                isLoading = false
                loadingScholarId = nil
                
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
                    
                    print("✅ 成功更新学者信息: \(info.name) - \(info.citations) citations")
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                    print("❌ 获取学者信息失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func refreshAllScholars() {
        let scholars = dataManager.scholars
        guard !scholars.isEmpty else { return }
        
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
                            
                            print("✅ [批量更新] 成功更新学者信息: \(info.name) - \(info.citations) citations")
                            
                        case .failure(let error):
                            print("❌ [批量更新] 获取学者信息失败 \(scholar.id): \(error.localizedDescription)")
                        }
                        
                        group.leave()
                    }
                }
            }
            
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        group.notify(queue: .main) {
            isRefreshing = false
            print("✅ [批量更新] 完成更新 \(refreshProgress)/\(totalScholars) 位学者")
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
                                    var updatedScholar = Scholar(id: scholar.id, name: info.name)
                                    updatedScholar.citations = info.citations
                                    updatedScholar.lastUpdated = Date()
                                    
                                    dataManager.updateScholar(updatedScholar)
                                    dataManager.saveHistoryIfChanged(
                                        scholarId: updatedScholar.id,
                                        citationCount: info.citations
                                    )
                                    
                                    print("✅ [批量更新] 成功更新学者信息: \(info.name) - \(info.citations) citations")
                                    
                                case .failure(let error):
                                    print("❌ [批量更新] 获取学者信息失败 \(scholar.id): \(error.localizedDescription)")
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
            print("✅ [批量更新] 完成更新 \(refreshProgress)/\(totalScholars) 位学者")
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
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
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
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
                
                Section(localizationManager.localized("app_information")) {
                    HStack {
                        Text(localizationManager.localized("version"))
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(localizationManager.localized("build"))
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(localizationManager.localized("icloud_sync")) {
                    HStack {
                        Text(localizationManager.localized("sync_status"))
                        Spacer()
                        Text(iCloudManager.syncStatus)
                            .foregroundColor(.secondary)
                    }
                    
                    if iCloudManager.lastSyncDate != nil {
                        HStack {
                            Text(localizationManager.localized("last_sync"))
                            Spacer()
                            Text(iCloudManager.lastSyncDate!.timeAgoString)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        iCloudManager.checkSyncStatus()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(localizationManager.localized("check_sync_status"))
                        }
                    }
                    .disabled(iCloudManager.isImporting || iCloudManager.isExporting)
                }
                
                Section(localizationManager.localized("data_management")) {
                    Button(action: {
                        showingImportAlert = true
                    }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down")
                            Text(localizationManager.localized("import_from_icloud"))
                        }
                    }
                    .disabled(iCloudManager.isImporting || iCloudManager.isExporting)
                    
                    Button(action: {
                        iCloudManager.showFilePicker()
                    }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text(localizationManager.localized("manual_import_file"))
                        }
                    }
                    .disabled(iCloudManager.isImporting || iCloudManager.isExporting)
                    
                    Button(action: {
                        showingExportAlert = true
                    }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                            Text(localizationManager.localized("export_to_icloud"))
                        }
                    }
                    .disabled(iCloudManager.isImporting || iCloudManager.isExporting)
                }
                
                Section(localizationManager.localized("about")) {
                    Text(localizationManager.localized("app_description"))
                        .font(.headline)
                    
                    Text(localizationManager.localized("app_help"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(localizationManager.localized("settings"))
            .onAppear {
                iCloudManager.checkSyncStatus()
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
            .sheet(isPresented: $iCloudManager.showingFilePicker) {
                FilePickerView(isPresented: $iCloudManager.showingFilePicker) { url in
                    iCloudManager.importFromFile(url: url)
                }
            }
        }
    }
    
    private func importFromiCloud() {
        iCloudManager.importFromiCloud { result in
            switch result {
            case .success(let importResult):
                self.importResult = importResult
                self.showingImportResult = true
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.showingErrorAlert = true
            }
        }
    }

    private func exportToiCloud() {
        iCloudManager.exportToiCloud { result in
            switch result {
            case .success:
                self.errorMessage = localizationManager.localized("export_success")
                self.showingErrorAlert = true
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.showingErrorAlert = true
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
                    TextField("Google Scholar ID", text: $scholarId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField(localizationManager.localized("scholar_name_placeholder"), text: $scholarName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
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
        }
    }
    
    private func addScholar() {
        guard !scholarId.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        // 模拟网络请求延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoading = false
            
            let name = scholarName.isEmpty ? "\(localizationManager.localized("scholar")) \(scholarId.prefix(8))" : scholarName
            var newScholar = Scholar(id: scholarId, name: name)
            newScholar.citations = Int.random(in: 100...1000)
            newScholar.lastUpdated = Date()
            
            onAdd(newScholar)
            dismiss()
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
                        Text("Scholar ID")
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
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(scholar.displayName)
                    .font(.headline)
                
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
                    print("🔍 [Management Debug] 点击了更新按钮: \(scholar.displayName)")
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
                    print("🔍 [Chart Debug] 点击了图表按钮: \(scholar.displayName)")
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
                                        .frame(width: 40, alignment: .trailing)
                                        .frame(height: 32) // 固定每个标签高度为32，总高度160/5=32
                                }
                            }
                            .frame(width: 40) // 增加Y轴宽度以避免文字被截断
                            
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
                                                print("🔍 [Chart Debug] 拖动吸附到数据点: \(closest.value)")
                                            }
                                        }
                                        .onEnded { value in
                                            isDragging = false
                                            dragLocation = nil
                                            
                                            // 触觉反馈
                                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                            impactFeedback.impactOccurred()
                                            
                                            print("🔍 [Chart Debug] 拖动结束，选中数据点: \(selectedDataPoint?.value ?? 0)")
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
        
        print("🔍 [Chart Debug] 加载学者 \(scholar.displayName) 的历史数据")
        print("🔍 [Chart Debug] 时间范围: \(startDate) 到 \(endDate)")
        
        // 从DataManager获取真实历史数据
        let histories = DataManager.shared.getHistory(for: scholar.id, from: startDate, to: endDate)
        
        print("🔍 [Chart Debug] 获取到 \(histories.count) 条历史记录")
        
        DispatchQueue.main.async {
            // 转换为图表数据格式
            self.chartData = histories.map { history in
                ChartDataPoint(
                    date: history.timestamp,
                    value: history.citationCount
                )
            }.sorted { $0.date < $1.date }
            
            print("🔍 [Chart Debug] 转换后图表数据: \(self.chartData.count) 条")
            
            // 如果没有历史数据，显示当前引用数作为单个数据点
            if self.chartData.isEmpty, let currentCitations = self.scholar.citations {
                print("🔍 [Chart Debug] 没有历史数据，使用当前引用数: \(currentCitations)")
                self.chartData = [ChartDataPoint(
                    date: Date(),
                    value: currentCitations
                )]
            }
            
            // 结束加载状态
            self.isLoading = false
            
            print("✅ 加载学者 \(self.scholar.displayName) 的历史数据: \(self.chartData.count) 条记录")
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
        
        print("🔍 [Chart Debug] 点击了数据点: \(point.value) at \(point.date)")
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedDataPoint?.id == point.id {
                selectedDataPoint = nil // 取消选中
                print("🔍 [Chart Debug] 取消选中数据点")
            } else {
                selectedDataPoint = point // 选中新点
                print("🔍 [Chart Debug] 选中数据点: \(point.value)")
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

// 数字格式化函数
func formatNumber(_ number: Int) -> String {
    if number >= 1_000_000_000 {
        return String(format: "%.1fB", Double(number) / 1_000_000_000)
    } else if number >= 1_000_000 {
        return String(format: "%.1fM", Double(number) / 1_000_000)
    } else if number >= 1_000 {
        return String(format: "%.1fK", Double(number) / 1_000)
    } else {
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

// MARK: - Simple History Manager

// 简化的引用历史结构
struct SimpleCitationHistory: Codable {
    let scholarId: String
    let citationCount: Int
    let timestamp: Date
}

// 简化的历史数据管理器（使用UserDefaults）
class SimpleHistoryManager {
    static let shared = SimpleHistoryManager()
    private let userDefaults = UserDefaults.standard
    private let historyKey = "CitationHistoryData"
    
    private init() {}
    
    // 保存历史记录
    func saveHistory(_ history: SimpleCitationHistory) {
        var histories = getAllHistories()
        histories.append(history)
        saveAllHistories(histories)
        print("✅ 保存历史记录: \(history.scholarId) - \(history.citationCount)")
    }
    
    // 如果引用数有变化才保存
    func saveHistoryIfChanged(scholarId: String, citationCount: Int) {
        let recent = getRecentHistory(for: scholarId, days: 1)
        
        // 检查最近的记录是否有相同的引用数
        if let latestHistory = recent.last,
           latestHistory.citationCount == citationCount {
            print("📝 引用数未变化，跳过保存: \(scholarId)")
            return
        }
        
        let newHistory = SimpleCitationHistory(
            scholarId: scholarId,
            citationCount: citationCount,
            timestamp: Date()
        )
        saveHistory(newHistory)
    }
    
    // 获取指定学者在时间范围内的历史记录
    func getHistory(for scholarId: String, from startDate: Date, to endDate: Date, completion: @escaping ([SimpleCitationHistory]) -> Void) {
        let allHistories = getAllHistories()
        let filtered = allHistories.filter { history in
            history.scholarId == scholarId &&
            history.timestamp >= startDate &&
            history.timestamp <= endDate
        }.sorted { $0.timestamp < $1.timestamp }
        
        completion(filtered)
    }
    
    // 获取最近几天的历史记录
    func getRecentHistory(for scholarId: String, days: Int) -> [SimpleCitationHistory] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        let allHistories = getAllHistories()
        return allHistories.filter { history in
            history.scholarId == scholarId &&
            history.timestamp >= startDate &&
            history.timestamp <= endDate
        }.sorted { $0.timestamp < $1.timestamp }
    }
    
    // 获取所有历史记录
    private func getAllHistories() -> [SimpleCitationHistory] {
        guard let data = userDefaults.data(forKey: historyKey),
              let histories = try? JSONDecoder().decode([SimpleCitationHistory].self, from: data) else {
            return []
        }
        return histories
    }
    
    // 保存所有历史记录
    private func saveAllHistories(_ histories: [SimpleCitationHistory]) {
        if let data = try? JSONEncoder().encode(histories) {
            userDefaults.set(data, forKey: historyKey)
        }
    }
    
    // 清理旧数据（可选，保留最近90天的数据）
    func cleanOldData() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let allHistories = getAllHistories()
        let filteredHistories = allHistories.filter { $0.timestamp >= cutoffDate }
        saveAllHistories(filteredHistories)
        print("🧹 清理旧历史数据，保留 \(filteredHistories.count) 条记录")
    }
}

// MARK: - Deep Link Notifications
extension Notification.Name {
    static let deepLinkAddScholar = Notification.Name("deepLinkAddScholar")
    static let deepLinkScholars = Notification.Name("deepLinkScholars")
    static let deepLinkDashboard = Notification.Name("deepLinkDashboard")
    static let deepLinkScholarDetail = Notification.Name("deepLinkScholarDetail")
    static let widgetRefreshTriggered = Notification.Name("widgetRefreshTriggered")
    static let widgetScholarSwitched = Notification.Name("widgetScholarSwitched")
}