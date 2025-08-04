import SwiftUI

struct ContentView: View {
    
    // MARK: - Environment Objects
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var dataSyncService: DataSyncService
    
    // MARK: - State
    @State private var selectedTab: Tab = .dashboard
    @State private var scholars: [Scholar] = []
    @State private var isLoading: Bool = false
    @State private var showingAddScholar: Bool = false
    
    // MARK: - Tab Enum
    enum Tab: String, CaseIterable {
        case dashboard = "dashboard"
        case scholars = "scholars"
        case charts = "charts"
        case settings = "settings"
        
        var title: String {
            switch self {
            case .dashboard:
                return "dashboard".localized
            case .scholars:
                return "scholars".localized
            case .charts:
                return "charts".localized
            case .settings:
                return "settings".localized
            }
        }
        
        var icon: String {
            switch self {
            case .dashboard:
                return "house.fill"
            case .scholars:
                return "person.2.fill"
            case .charts:
                return "chart.bar.fill"
            case .settings:
                return "gear"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            DashboardView(scholars: $scholars)
                .tabItem {
                    Image(systemName: Tab.dashboard.icon)
                    Text(Tab.dashboard.title)
                }
                .tag(Tab.dashboard)
            
            // Scholars Tab
            ScholarListView(scholars: $scholars)
                .tabItem {
                    Image(systemName: Tab.scholars.icon)
                    Text(Tab.scholars.title)
                }
                .tag(Tab.scholars)
            
            // Charts Tab
            ChartsView(scholars: scholars)
                .tabItem {
                    Image(systemName: Tab.charts.icon)
                    Text(Tab.charts.title)
                }
                .tag(Tab.charts)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: Tab.settings.icon)
                    Text(Tab.settings.title)
                }
                .tag(Tab.settings)
        }
        .accentColor(.blue)
        .onAppear {
            loadScholars()
            setupDataSync()
        }
        .onChange(of: localizationManager.currentLanguage) { _ in
            // 语言变化时刷新界面
        }
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadScholars() {
        scholars = settingsManager.getScholars()
    }
    
    private func setupDataSync() {
        if settingsManager.iCloudSyncEnabled {
            dataSyncService.startAutoSync(interval: settingsManager.updateInterval)
        }
    }
    
    @MainActor
    private func refreshData() async {
        isLoading = true
        defer { isLoading = false }
        
        await withTaskGroup(of: Void.self) { group in
            for scholar in scholars {
                group.addTask {
                    await updateScholar(scholar)
                }
            }
        }
        
        // 重新加载学者数据
        loadScholars()
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

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SettingsManager.shared)
            .environmentObject(LocalizationManager.shared)
            .environmentObject(DataSyncService.shared)
            .preferredColorScheme(.light)
    }
}