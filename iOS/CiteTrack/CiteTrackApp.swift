import SwiftUI
import UniformTypeIdentifiers

@main
struct CiteTrackApp: App {
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(colorScheme)
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
        case chart(ScholarInfo)
        case edit(ScholarInfo)
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
            ForEach(dataManager.scholars, id: \.id) { scholar in
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
                .swipeActions(edge: .trailing) {
                    Button(localizationManager.localized("delete"), role: .destructive) {
                        deleteScholar(scholar)
                    }
                    
                    Button(localizationManager.localized("edit")) {
                        editScholar(scholar)
                    }
                    .tint(.orange)
                }
            }
            .onDelete(perform: deleteScholars)
        }
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

    private func fetchScholarInfo(for scholar: ScholarInfo) {
        isLoading = true
        loadingScholarId = scholar.id
        
        googleScholarService.fetchScholarInfo(for: scholar.id) { result in
            DispatchQueue.main.async {
                isLoading = false
                loadingScholarId = nil
                
                switch result {
                case .success(let info):
                    let updatedScholar = ScholarInfo(
                        id: scholar.id,
                        name: info.name,
                        citations: info.citations,
                        lastUpdated: Date()
                    )
                    
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
                            let updatedScholar = ScholarInfo(
                                id: scholar.id,
                                name: info.name,
                                citations: info.citations,
                                lastUpdated: Date()
                            )
                            
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
                                    let updatedScholar = ScholarInfo(
                                        id: scholar.id,
                                        name: info.name,
                                        citations: info.citations,
                                        lastUpdated: Date()
                                    )
                                    
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

    private func deleteScholar(_ scholar: ScholarInfo) {
        dataManager.removeScholar(id: scholar.id)
    }

    private func deleteAllScholars() {
        dataManager.removeAllScholars()
    }
    
    private func editScholar(_ scholar: ScholarInfo) {
        activeSheet = .edit(scholar)
    }
}

private struct ScholarChartRowView: View {
    let scholar: ScholarInfo
    let onTap: () -> Void

    var body: some View {
        ScholarChartRow(scholar: scholar, onTap: onTap)
    }
}

// 引用排名图表
struct CitationRankingChart: View {
    let scholars: [ScholarInfo]
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var sortedScholars: [ScholarInfo] {
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
    let scholar: ScholarInfo
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
    let scholars: [ScholarInfo]
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
    let scholars: [ScholarInfo]
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
    let onAdd: (ScholarInfo) -> Void
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
            var newScholar = ScholarInfo(id: scholarId, name: name)
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
    let scholar: ScholarInfo
    let onSave: (ScholarInfo) -> Void
    @StateObject private var localizationManager = LocalizationManager.shared
    
    @State private var scholarName: String
    @State private var hasChanges = false
    
    init(scholar: ScholarInfo, onSave: @escaping (ScholarInfo) -> Void) {
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
        let updatedScholar = ScholarInfo(
            id: scholar.id,
            name: scholarName.trimmingCharacters(in: .whitespacesAndNewlines),
            citations: scholar.citations,
            lastUpdated: scholar.lastUpdated
        )
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
    let scholar: ScholarInfo
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
    let scholar: ScholarInfo
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
                    Text(localizationManager.localized("last_updated") + " \(DateFormatter.relative.string(from: lastUpdated))")
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
    let scholar: ScholarInfo
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
                        Text(localizationManager.localized("updated_at") + " \(DateFormatter.relative.string(from: lastUpdated))")
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
    let scholar: ScholarInfo
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
                        HStack(spacing: 4) { // 进一步减少间距
                            VStack(alignment: .leading, spacing: 2) { // 进一步减少Y轴标签间距
                                ForEach(chartData.reversed(), id: \.id) { point in
                                    Text(formatNumber(point.value))
                                        .font(.caption2) // 使用更小字体
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                        .frame(width: 35, alignment: .trailing) // 进一步减少宽度
                                }
                            }
                            .frame(width: 35) // 进一步减少Y轴宽度
                            
                            VStack {
                                ZStack {
                                    // 网格线
                                    Path { path in
                                        for i in 0...4 {
                                            let y = CGFloat(i) * 40
                                            path.move(to: CGPoint(x: 0, y: y))
                                            path.addLine(to: CGPoint(x: geometry.size.width - 80, y: y)) // 增加右边距
                                        }
                                    }
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    
                                    // 折线图
                                    Path { path in
                                        if !chartData.isEmpty {
                                            let maxValue = chartData.map(\.value).max() ?? 1
                                            let minValue = chartData.map(\.value).min() ?? 0
                                            let range = max(maxValue - minValue, 1)
                                            let chartWidth = geometry.size.width - 80 // 增加右边距
                                            
                                            for (index, point) in chartData.enumerated() {
                                                let x = CGFloat(index) * (chartWidth / CGFloat(chartData.count - 1))
                                                let normalizedValue = CGFloat(point.value - minValue) / CGFloat(range)
                                                let y = 160 - (normalizedValue * 160)
                                                
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
                                        let chartWidth = geometry.size.width - 80 // 增加右边距
                                        let x = CGFloat(index) * (chartWidth / CGFloat(chartData.count - 1))
                                        let normalizedValue = CGFloat(point.value - minValue) / CGFloat(range)
                                        let y = 160 - (normalizedValue * 160)
                                        
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
                                
                                // X轴标签 - 优化显示
                                HStack(spacing: 2) { // 进一步减少标签间距
                                    ForEach(Array(chartData.enumerated()), id: \.element.id) { index, point in
                                        if index % 2 == 0 { // 只显示偶数位置的标签
                                            Text(DateFormatter.shortDate.string(from: point.date))
                                                .font(.caption) // 使用更大的字体
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                                .frame(maxWidth: .infinity) // 平均分布
                                        } else {
                                            Text("")
                                                .font(.caption)
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                }
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
                let previousValue = chartData.count > 1 ? chartData[chartData.count - 2].value : 0
                let change = currentValue - previousValue
                let growth = previousValue > 0 ? Double(change) / Double(previousValue) * 100 : 0
                
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
        let chartWidth = geometry.size.width - 80 // 增加右边距
        let chartHeight: CGFloat = 160 // 图表高度
        
        let x = point.x
        let y = chartHeight - point.y // 将Y坐标反转，使其与图表坐标系一致
        
        // 找到最近的点
        var closestPoint: ChartDataPoint? = nil
        var minDistance: CGFloat = CGFloat.infinity
        
        for (index, dataPoint) in chartData.enumerated() {
            let dataPointX = CGFloat(index) * (chartWidth / CGFloat(chartData.count - 1))
            let dataPointY = 160 - (CGFloat(dataPoint.value - minValue) / CGFloat(range) * 160)
            
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