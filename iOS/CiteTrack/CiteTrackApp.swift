import SwiftUI
import UniformTypeIdentifiers

@main
struct CiteTrackApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

struct MainView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("仪表板")
                }
                .tag(0)
            
            ScholarListView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("学者")
                }
                .tag(1)
            
            ChartsView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("图表")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("设置")
                }
                .tag(3)
        }
    }
}

// 仪表板视图
struct DashboardView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 统计卡片
                    HStack(spacing: 12) {
                        StatisticsCard(
                            title: "总引用数",
                            value: "\(settingsManager.getScholars().reduce(0) { $0 + ($1.citations ?? 0) })",
                            icon: "quote.bubble.fill",
                            color: .blue
                        )
                        
                        StatisticsCard(
                            title: "学者数量",
                            value: "\(settingsManager.getScholars().count)",
                            icon: "person.2.fill",
                            color: .green
                        )
                    }
                    
                    // 学者列表
                    if !settingsManager.getScholars().isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("学者列表")
                                .font(.headline)
                            
                            ForEach(settingsManager.getScholars(), id: \.id) { scholar in
                                ScholarRow(scholar: scholar)
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "person.2.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("暂无学者数据")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text("在\"学者\"标签页中添加您的第一个学者")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("CiteTrack 仪表板")
        }
    }
}

// 学者列表视图
struct ScholarListView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var googleScholarService = GoogleScholarService.shared
    @State private var showingAddScholar = false
    @State private var isLoading = false
    @State private var loadingScholarId: String?
    @State private var errorMessage = ""
    @State private var showingErrorAlert = false
    @State private var isRefreshing = false
    @State private var refreshProgress = 0
    @State private var totalScholars = 0
    
    var body: some View {
        NavigationView {
            List {
                ForEach(settingsManager.getScholars(), id: \.id) { scholar in
                    ScholarRow(scholar: scholar)
                        .swipeActions(edge: .trailing) {
                            Button("获取信息") {
                                fetchScholarInfo(for: scholar)
                            }
                            .tint(.blue)
                        }
                }
                .onDelete(perform: deleteScholars)
            }
            .navigationTitle("学者管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        showingAddScholar = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("刷新全部") {
                        refreshAllScholars()
                    }
                    .disabled(isRefreshing)
                }
            }
            .refreshable {
                await refreshAllScholarsAsync()
            }
            .sheet(isPresented: $showingAddScholar) {
                AddScholarView { newScholar in
                    settingsManager.addScholar(newScholar)
                }
            }
            .alert("获取失败", isPresented: $showingErrorAlert) {
                Button("确定") { }
            } message: {
                Text(errorMessage)
            }
            .overlay(
                Group {
                    if isLoading {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("正在获取学者信息...")
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
                    }
                    
                    if isRefreshing {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("正在更新所有学者信息...")
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
            )
        }
    }
    
    private func fetchScholarInfo(for scholar: Scholar) {
        isLoading = true
        loadingScholarId = scholar.id
        
        googleScholarService.fetchScholarInfo(for: scholar.id) { result in
            DispatchQueue.main.async {
                isLoading = false
                loadingScholarId = nil
                
                switch result {
                case .success(let info):
                    // 更新学者信息
                    var updatedScholar = scholar
                    updatedScholar.name = info.name
                    updatedScholar.citations = info.citations
                    updatedScholar.lastUpdated = Date()
                    
                    settingsManager.updateScholar(updatedScholar)
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
        let scholars = settingsManager.getScholars()
        guard !scholars.isEmpty else { return }
        
        isRefreshing = true
        totalScholars = scholars.count
        refreshProgress = 0
        
        // 使用DispatchGroup来管理并发请求
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        for (index, scholar) in scholars.enumerated() {
            group.enter()
            
            queue.async {
                googleScholarService.fetchScholarInfo(for: scholar.id) { result in
                    DispatchQueue.main.async {
                        refreshProgress += 1
                        
                        switch result {
                        case .success(let info):
                            // 更新学者信息
                            var updatedScholar = scholar
                            updatedScholar.name = info.name
                            updatedScholar.citations = info.citations
                            updatedScholar.lastUpdated = Date()
                            
                            settingsManager.updateScholar(updatedScholar)
                            print("✅ [批量更新] 成功更新学者信息: \(info.name) - \(info.citations) citations")
                            
                        case .failure(let error):
                            print("❌ [批量更新] 获取学者信息失败 \(scholar.id): \(error.localizedDescription)")
                        }
                        
                        group.leave()
                    }
                }
            }
            
            // 添加延迟避免请求过于频繁
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        group.notify(queue: .main) {
            isRefreshing = false
            print("✅ [批量更新] 完成更新 \(refreshProgress)/\(totalScholars) 位学者")
        }
    }
    
    private func refreshAllScholarsAsync() async {
        let scholars = settingsManager.getScholars()
        guard !scholars.isEmpty else { return }
        
        await MainActor.run {
            isRefreshing = true
            totalScholars = scholars.count
            refreshProgress = 0
        }
        
        // 使用TaskGroup来管理并发请求
        await withTaskGroup(of: Void.self) { group in
            for (index, scholar) in scholars.enumerated() {
                group.addTask {
                    // 添加延迟避免请求过于频繁
                    try? await Task.sleep(nanoseconds: UInt64(index * 500_000_000)) // 0.5秒间隔
                    
                    await withCheckedContinuation { continuation in
                        googleScholarService.fetchScholarInfo(for: scholar.id) { result in
                            Task { @MainActor in
                                refreshProgress += 1
                                
                                switch result {
                                case .success(let info):
                                    // 更新学者信息
                                    var updatedScholar = scholar
                                    updatedScholar.name = info.name
                                    updatedScholar.citations = info.citations
                                    updatedScholar.lastUpdated = Date()
                                    
                                    settingsManager.updateScholar(updatedScholar)
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
            let scholarToDelete = settingsManager.getScholars()[index]
            settingsManager.removeScholar(id: scholarToDelete.id)
        }
    }
}

// 图表视图
struct ChartsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var selectedChartType = 0
    
    var body: some View {
        NavigationView {
            VStack {
                if settingsManager.getScholars().isEmpty {
                    // 空状态
                    VStack(spacing: 20) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("暂无图表数据")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("导入学者数据后，这里将显示引用趋势图表")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    // 图表内容
                    VStack(spacing: 20) {
                        // 图表类型选择器
                        Picker("图表类型", selection: $selectedChartType) {
                            Text("引用排名").tag(0)
                            Text("引用分布").tag(1)
                            Text("学者统计").tag(2)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        // 图表内容
                        ScrollView {
                            VStack(spacing: 20) {
                                switch selectedChartType {
                                case 0:
                                    CitationRankingChart(scholars: settingsManager.getScholars())
                                case 1:
                                    CitationDistributionChart(scholars: settingsManager.getScholars())
                                case 2:
                                    ScholarStatisticsChart(scholars: settingsManager.getScholars())
                                default:
                                    CitationRankingChart(scholars: settingsManager.getScholars())
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("图表分析")
        }
    }
}

// 引用排名图表
struct CitationRankingChart: View {
    let scholars: [Scholar]
    
    var sortedScholars: [Scholar] {
        scholars.sorted { ($0.citations ?? 0) > ($1.citations ?? 0) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("引用排名")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(Array(sortedScholars.enumerated()), id: \.element.id) { index, scholar in
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
        }
    }
}

// 引用分布图表
struct CitationDistributionChart: View {
    let scholars: [Scholar]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("引用分布")
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("学者统计")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                StatCard(title: "总学者数", value: "\(scholars.count)", icon: "person.2.fill", color: .blue)
                StatCard(title: "总引用数", value: "\(totalCitations)", icon: "quote.bubble.fill", color: .green)
                StatCard(title: "平均引用", value: "\(averageCitations)", icon: "chart.bar.fill", color: .orange)
                StatCard(title: "最高引用", value: "\(maxCitations)", icon: "star.fill", color: .red)
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

// 设置视图
struct SettingsView: View {
    @StateObject private var iCloudManager = iCloudSyncManager.shared
    @State private var showingImportAlert = false
    @State private var showingExportAlert = false
    @State private var showingImportResult = false
    @State private var importResult: ImportResult?
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("应用设置") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("构建版本")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("iCloud同步") {
                    HStack {
                        Text("状态")
                        Spacer()
                        Text(iCloudManager.syncStatus)
                            .foregroundColor(.secondary)
                    }
                    
                    if iCloudManager.lastSyncDate != nil {
                        HStack {
                            Text("上次同步")
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
                            Text("检查同步状态")
                        }
                    }
                    .disabled(iCloudManager.isImporting || iCloudManager.isExporting)
                }
                
                Section("数据管理") {
                    Button(action: {
                        showingImportAlert = true
                    }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down")
                            Text("从iCloud导入")
                        }
                    }
                    .disabled(iCloudManager.isImporting || iCloudManager.isExporting)
                    
                    Button(action: {
                        iCloudManager.showFilePicker()
                    }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("手动导入文件")
                        }
                    }
                    .disabled(iCloudManager.isImporting || iCloudManager.isExporting)
                    
                    Button(action: {
                        if let defaultDataURL = iCloudManager.createDefaultMacOSData() {
                            iCloudManager.importFromFile(url: defaultDataURL)
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("导入默认macOS数据")
                        }
                    }
                    .disabled(iCloudManager.isImporting || iCloudManager.isExporting)
                    
                    Button(action: {
                        showingExportAlert = true
                    }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                            Text("导出到iCloud")
                        }
                    }
                    .disabled(iCloudManager.isImporting || iCloudManager.isExporting)
                }
                
                Section("关于") {
                    Text("CiteTrack - 学术引用追踪工具")
                        .font(.headline)
                    
                    Text("帮助学者追踪和管理Google Scholar引用数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .onAppear {
                iCloudManager.checkSyncStatus()
            }
            .alert("从iCloud导入", isPresented: $showingImportAlert) {
                Button("取消", role: .cancel) { }
                Button("导入") {
                    importFromiCloud()
                }
            } message: {
                Text("这将从iCloud Drive的CiteTrack文件夹导入数据。当前数据将被替换。")
            }
            .alert("导出到iCloud", isPresented: $showingExportAlert) {
                Button("取消", role: .cancel) { }
                Button("导出") {
                    exportToiCloud()
                }
            } message: {
                Text("这将把当前数据导出到iCloud Drive的CiteTrack文件夹。")
            }
            .alert("导入结果", isPresented: $showingImportResult) {
                Button("确定") { }
            } message: {
                if let result = importResult {
                    Text(result.description)
                } else {
                    Text("导入完成")
                }
            }
            .alert("操作失败", isPresented: $showingErrorAlert) {
                Button("确定") { }
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
                // 显示成功提示
                self.errorMessage = "导出成功！数据已保存到iCloud Drive的CiteTrack文件夹。"
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
    
    @State private var scholarId = ""
    @State private var scholarName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("学者信息") {
                    TextField("Google Scholar ID", text: $scholarId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("学者姓名（可选）", text: $scholarName)
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
                            Text("添加学者")
                        }
                    }
                    .disabled(scholarId.isEmpty || isLoading)
                }
            }
            .navigationTitle("添加学者")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
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
            
            let name = scholarName.isEmpty ? "学者 \(scholarId.prefix(8))" : scholarName
            var newScholar = Scholar(id: scholarId, name: name)
            newScholar.citations = Int.random(in: 100...1000)
            newScholar.lastUpdated = Date()
            
            onAdd(newScholar)
            dismiss()
        }
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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(scholar.displayName)
                    .font(.headline)
                
                if let citations = scholar.citations {
                    Text("引用数: \(citations)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("暂无数据")
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

// 时间扩展
extension Date {
    var timeAgoString: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else if interval < 86400 * 7 {
            let days = Int(interval / 86400)
            return "\(days)天前"
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