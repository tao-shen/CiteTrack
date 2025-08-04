import SwiftUI

struct DashboardView: View {
    
    // MARK: - Properties
    @Binding var scholars: [Scholar]
    
    // MARK: - Environment Objects
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var dataSyncService: DataSyncService
    
    // MARK: - State
    @State private var isRefreshing = false
    @State private var showingAddScholar = false
    @State private var totalCitations = 0
    @State private var recentChanges: [CitationChange] = []
    
    // MARK: - Computed Properties
    private var activeCitationsToday: Int {
        // 这里可以计算今天的新增引用数
        recentChanges.filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.change }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 顶部统计卡片
                    statisticsSection
                    
                    // 同步状态
                    syncStatusSection
                    
                    // 最近变化
                    recentChangesSection
                    
                    // 学者概览
                    scholarOverviewSection
                    
                    // 快速操作
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("dashboard".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshData) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatWhile(isRefreshing), value: isRefreshing)
                    }
                    .disabled(isRefreshing)
                }
            }
            .refreshable {
                await performRefresh()
            }
            .onAppear {
                updateStatistics()
                loadRecentChanges()
            }
            .onChange(of: scholars) { _ in
                updateStatistics()
            }
        }
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatisticsCard(
                    title: "total_citations".localized,
                    value: "\(totalCitations)",
                    icon: "quote.bubble.fill",
                    color: .blue
                )
                
                StatisticsCard(
                    title: "scholars".localized,
                    value: "\(scholars.count)",
                    icon: "person.2.fill",
                    color: .green
                )
            }
            
            HStack(spacing: 12) {
                StatisticsCard(
                    title: "today_changes".localized,
                    value: activeCitationsToday >= 0 ? "+\(activeCitationsToday)" : "\(activeCitationsToday)",
                    icon: "chart.line.uptrend.xyaxis",
                    color: activeCitationsToday >= 0 ? .green : .red
                )
                
                StatisticsCard(
                    title: "last_update".localized,
                    value: settingsManager.lastUpdateDate?.timeAgoString ?? "never_updated".localized,
                    icon: "clock.fill",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - Sync Status Section
    
    private var syncStatusSection: some View {
        Group {
            if dataSyncService.isSyncing {
                SyncStatusCard(
                    title: "syncing".localized,
                    subtitle: "sync_in_progress".localized,
                    icon: "icloud.and.arrow.up",
                    isAnimating: true
                )
            } else if let lastSyncDate = dataSyncService.lastSyncDate {
                SyncStatusCard(
                    title: "sync_complete".localized,
                    subtitle: "last_sync".localized + ": " + lastSyncDate.timeAgoString,
                    icon: "checkmark.icloud",
                    isAnimating: false
                )
            } else if settingsManager.iCloudSyncEnabled {
                SyncStatusCard(
                    title: "sync_pending".localized,
                    subtitle: "waiting_for_sync".localized,
                    icon: "icloud",
                    isAnimating: false
                )
            }
        }
    }
    
    // MARK: - Recent Changes Section
    
    private var recentChangesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("recent_changes".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("view_all".localized) {
                    // 跳转到详细的变化历史页面
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if recentChanges.isEmpty {
                EmptyStateView(
                    icon: "chart.bar",
                    title: "no_recent_changes".localized,
                    subtitle: "changes_will_appear_here".localized
                )
                .frame(height: 120)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recentChanges.prefix(5), id: \.id) { change in
                        CitationChangeRow(change: change)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Scholar Overview Section
    
    private var scholarOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("scholar_overview".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("manage_scholars".localized) {
                    // 跳转到学者管理页面
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if scholars.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "no_scholars".localized,
                    subtitle: "add_first_scholar".localized
                )
                .frame(height: 120)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(scholars.prefix(3), id: \.id) { scholar in
                        ScholarSummaryRow(scholar: scholar)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("quick_actions".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "add_scholar".localized,
                    icon: "person.badge.plus",
                    color: .blue
                ) {
                    showingAddScholar = true
                }
                
                QuickActionButton(
                    title: "refresh_all".localized,
                    icon: "arrow.clockwise",
                    color: .green
                ) {
                    refreshData()
                }
                
                QuickActionButton(
                    title: "view_charts".localized,
                    icon: "chart.bar",
                    color: .purple
                ) {
                    // 跳转到图表页面
                }
                
                QuickActionButton(
                    title: "settings".localized,
                    icon: "gear",
                    color: .gray
                ) {
                    // 跳转到设置页面
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Methods
    
    private func updateStatistics() {
        totalCitations = scholars.compactMap { $0.citations }.reduce(0, +)
    }
    
    private func loadRecentChanges() {
        // 这里应该从Core Data加载最近的引用变化
        // 暂时使用模拟数据
        recentChanges = []
    }
    
    private func refreshData() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        
        Task {
            await performRefresh()
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
    
    @MainActor
    private func performRefresh() async {
        // 更新学者数据
        await withTaskGroup(of: Void.self) { group in
            for scholar in scholars {
                group.addTask {
                    await updateScholar(scholar)
                }
            }
        }
        
        // 更新统计信息
        updateStatistics()
        settingsManager.lastUpdateDate = Date()
    }
    
    private func updateScholar(_ scholar: Scholar) async {
        await withCheckedContinuation { continuation in
            GoogleScholarService.shared.fetchAndSaveScholarInfo(for: scholar.id) { result in
                switch result {
                case .success(let info):
                    var updatedScholar = scholar
                    updatedScholar.citations = info.citations
                    updatedScholar.lastUpdated = Date()
                    settingsManager.updateScholar(updatedScholar)
                    
                case .failure(let error):
                    print("❌ 更新学者 \(scholar.displayName) 失败: \(error)")
                }
                continuation.resume()
            }
        }
    }
}

// MARK: - Citation Change Model
struct CitationChange: Identifiable {
    let id = UUID()
    let scholarName: String
    let change: Int
    let date: Date
    let oldCount: Int
    let newCount: Int
}

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    @State static var mockScholars = [
        Scholar.mock(id: "abc123", name: "张三教授", citations: 1500),
        Scholar.mock(id: "def456", name: "李四博士", citations: 800),
        Scholar.mock(id: "ghi789", name: "王五研究员", citations: 2200)
    ]
    
    static var previews: some View {
        DashboardView(scholars: $mockScholars)
            .environmentObject(SettingsManager.shared)
            .environmentObject(LocalizationManager.shared)
            .environmentObject(DataSyncService.shared)
    }
}