import SwiftUI

struct ScholarListView: View {
    
    // MARK: - Properties
    @Binding var scholars: [Scholar]
    
    // MARK: - Environment Objects
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    // MARK: - State
    @State private var showingAddScholar = false
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var selectedScholar: Scholar?
    @State private var showingScholarDetail = false
    @State private var showingScholarChart = false
    
    // MARK: - Computed Properties
    private var filteredScholars: [Scholar] {
        if searchText.isEmpty {
            return scholars
        } else {
            return scholars.filter { scholar in
                scholar.name.lowercased().contains(searchText.lowercased()) ||
                scholar.id.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if scholars.isEmpty {
                    emptyStateView
                } else {
                    scholarsList
                }
            }
            .navigationTitle("scholars".localized)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "search_scholars".localized)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingAddScholar = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                    
                    Menu {
                        Button("refresh_all".localized) {
                            refreshAllScholars()
                        }
                        
                        Button("sort_by_name".localized) {
                            sortScholarsByName()
                        }
                        
                        Button("sort_by_citations".localized) {
                            sortScholarsByCitations()
                        }
                        
                        Button("export_data".localized) {
                            exportScholarData()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddScholar) {
                AddScholarView { newScholar in
                    addScholar(newScholar)
                }
            }
            .sheet(isPresented: $showingScholarDetail) {
                if let scholar = selectedScholar {
                    ScholarDetailView(scholar: scholar) { updatedScholar in
                        updateScholar(updatedScholar)
                    }
                }
            }
            .sheet(isPresented: $showingScholarChart) {
                if let scholar = selectedScholar {
                    if #available(iOS 16.0, *) {
                        ScholarChartDetailView(scholar: scholar)
                    } else {
                        Text("charts_require_ios16".localized)
                            .padding()
                    }
                }
            }
            .refreshable {
                await refreshAllScholarsAsync()
            }
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("no_scholars_added".localized)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("add_scholars_to_track".localized)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showingAddScholar = true }) {
                Label("add_first_scholar".localized, systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Scholars List
    
    private var scholarsList: some View {
        List {
            ForEach(filteredScholars, id: \.id) { scholar in
                ScholarRow(
                    scholar: scholar,
                    onTap: {
                        selectedScholar = scholar
                        showingScholarDetail = true
                    },
                    onChartTap: {
                        selectedScholar = scholar
                        showingScholarChart = true
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("delete".localized, role: .destructive) {
                        deleteScholar(scholar)
                    }
                    
                    Button("refresh".localized) {
                        refreshScholar(scholar)
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Button("view_details".localized) {
                        selectedScholar = scholar
                        showingScholarDetail = true
                    }
                    
                    Button("refresh_data".localized) {
                        refreshScholar(scholar)
                    }
                    
                    Button("copy_scholar_id".localized) {
                        UIPasteboard.general.string = scholar.id
                    }
                    
                    Divider()
                    
                    Button("delete_scholar".localized, role: .destructive) {
                        deleteScholar(scholar)
                    }
                }
            }
            .onMove(perform: moveScholars)
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Methods
    
    private func addScholar(_ scholar: Scholar) {
        scholars.append(scholar)
        settingsManager.addScholar(scholar)
        
        // 立即获取数据
        refreshScholar(scholar)
    }
    
    private func updateScholar(_ scholar: Scholar) {
        if let index = scholars.firstIndex(where: { $0.id == scholar.id }) {
            scholars[index] = scholar
            settingsManager.updateScholar(scholar)
        }
    }
    
    private func deleteScholar(_ scholar: Scholar) {
        scholars.removeAll { $0.id == scholar.id }
        settingsManager.removeScholar(id: scholar.id)
    }
    
    private func moveScholars(from source: IndexSet, to destination: Int) {
        scholars.move(fromOffsets: source, toOffset: destination)
        settingsManager.saveScholars(scholars)
    }
    
    private func refreshScholar(_ scholar: Scholar) {
        Task {
            await refreshScholarAsync(scholar)
        }
    }
    
    private func refreshAllScholars() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        
        Task {
            await refreshAllScholarsAsync()
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
    
    @MainActor
    private func refreshScholarAsync(_ scholar: Scholar) async {
        await withCheckedContinuation { continuation in
            GoogleScholarService.shared.fetchAndSaveScholarInfo(for: scholar.id) { result in
                switch result {
                case .success(let info):
                    var updatedScholar = scholar
                    updatedScholar.name = info.name
                    updatedScholar.citations = info.citations
                    updatedScholar.lastUpdated = Date()
                    
                    // 更新本地数组
                    if let index = self.scholars.firstIndex(where: { $0.id == scholar.id }) {
                        self.scholars[index] = updatedScholar
                    }
                    
                    // 保存到设置
                    self.settingsManager.updateScholar(updatedScholar)
                    
                case .failure(let error):
                    print("❌ 刷新学者 \(scholar.displayName) 失败: \(error)")
                }
                continuation.resume()
            }
        }
    }
    
    @MainActor
    private func refreshAllScholarsAsync() async {
        await withTaskGroup(of: Void.self) { group in
            for scholar in scholars {
                group.addTask {
                    await refreshScholarAsync(scholar)
                }
            }
        }
    }
    
    private func sortScholarsByName() {
        scholars.sort { $0.name < $1.name }
        settingsManager.saveScholars(scholars)
    }
    
    private func sortScholarsByCitations() {
        scholars.sort { ($0.citations ?? 0) > ($1.citations ?? 0) }
        settingsManager.saveScholars(scholars)
    }
    
    private func exportScholarData() {
        // 实现数据导出功能
        let exportData = ExportData(scholars: scholars, history: [])
        
        if let jsonData = try? JSONEncoder().encode(exportData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            let activityVC = UIActivityViewController(
                activityItems: [jsonString],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - Scholar Row Component
struct ScholarRow: View {
    let scholar: Scholar
    let onTap: () -> Void
    let onChartTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            Circle()
                .fill(Color(scholar.id.hashColor))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(scholar.name.initials())
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                )
            
            // 学者信息 - 点击查看详情
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scholar.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Label(scholar.citationDisplay, systemImage: "quote.bubble")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        if let lastUpdated = scholar.lastUpdated {
                            Label(lastUpdated.timeAgoString, systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Label("never_updated".localized, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // 图表按钮
            Button(action: onChartTap) {
                VStack(spacing: 4) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("图表")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 详情按钮
            Button(action: onTap) {
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
struct ScholarListView_Previews: PreviewProvider {
    @State static var mockScholars = [
        Scholar.mock(id: "abc123", name: "张三教授", citations: 1500),
        Scholar.mock(id: "def456", name: "李四博士", citations: 800),
        Scholar.mock(id: "ghi789", name: "王五研究员", citations: 2200)
    ]
    
    static var previews: some View {
        ScholarListView(scholars: $mockScholars)
            .environmentObject(SettingsManager.shared)
            .environmentObject(LocalizationManager.shared)
    }
}