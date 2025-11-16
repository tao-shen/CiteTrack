import SwiftUI

// MARK: - Publication Display Model
struct PublicationDisplay: Identifiable {
    let id: String
    let title: String
    let clusterId: String?
    let citationCount: Int?
    let year: Int?
}

// MARK: - Publication Display for Sheet (exposed)
struct PublicationDisplayForSheet: Identifiable {
    let id: String
    let title: String
    let clusterId: String?
    let citationCount: Int?
    let year: Int?
    
    init(id: String, title: String, clusterId: String?, citationCount: Int?, year: Int?) {
        self.id = id
        self.title = title
        self.clusterId = clusterId
        self.citationCount = citationCount
        self.year = year
    }
}

// MARK: - Sort Option
enum PublicationSortOption: String, CaseIterable {
    case title = "标题"
    case citations = "引用次数"
    case year = "年份"
    
    var icon: String {
        switch self {
        case .title: return "textformat"
        case .citations: return "quote.bubble"
        case .year: return "calendar"
        }
    }
    
    var title: String {
        switch self {
        case .title: return "sort_by_title".localized
        case .citations: return "sort_by_citations".localized
        case .year: return "sort_by_year".localized
        }
    }
    
    /// 转换为 Google Scholar 的 sortby 参数值
    var googleScholarParam: String? {
        switch self {
        case .title: return "title"
        case .citations: return "total"  // 按引用总数排序
        case .year: return "pubdate"     // 按发表日期排序
        }
    }
}

// MARK: - Who Cite Me View
struct WhoCiteMeView: View {
    @StateObject private var citationManager = CitationManager.shared
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    @State private var selectedScholar: Scholar?
    @State private var showingFilterSheet = false
    @State private var showingExportSheet = false
    @State private var currentFilter = CitationFilter()
    @State private var filteredPapers: [CitingPaper] = []
    @State private var selectedPublication: PublicationDisplay?
    @State private var showingCitingPapersSheet = false
    @State private var citingPapers: [CitingPaper] = []
    @State private var isLoadingCitingPapers = false
    @State private var isLoadingMoreCitingPapers = false
    @State private var hasMoreCitingPapers = false
    @State private var citingPapersError: String?
    @State private var citingPapersSortByDate: Bool = true  // 默认按日期排序
    @State private var sortOption: PublicationSortOption = .citations
    @State private var sortAscending: Bool = false  // 注意：Google Scholar 的排序方向由参数决定，这里保留用于UI显示
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if dataManager.scholars.isEmpty {
                    emptyStateView
                } else {
                    // 学者选择器
                    scholarPicker
                    
                    if let scholar = selectedScholar {
                        // 内容区域
                        contentView(for: scholar)
                    } else {
                        selectScholarPrompt
                    }
                }
            }
            .navigationTitle("who_cite_me".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 只保留排序按钮
                    if selectedScholar != nil {
                        sortButtonToolbar(for: selectedScholar!.id)
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                CitationFilterView(filter: $currentFilter)
            }
            .sheet(isPresented: $showingExportSheet) {
                exportOptionsView
            }
        }
        .onAppear {
            if selectedScholar == nil, let firstScholar = dataManager.scholars.first {
                selectedScholar = firstScholar
                loadData(for: firstScholar)
            }
        }
        .onChange(of: currentFilter) { _, newFilter in
            applyFilter(newFilter)
        }
    }
    
    // MARK: - Scholar Picker
    
    private var scholarPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
            ForEach(dataManager.scholars) { scholar in
                    scholarChip(scholar)
            }
        }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    private func scholarChip(_ scholar: Scholar) -> some View {
        let isSelected = selectedScholar?.id == scholar.id
        
        return Button(action: {
            selectedScholar = scholar
                loadData(for: scholar)
        }) {
            HStack(spacing: 8) {
                // 学者头像占位符
                Circle()
                    .fill(isSelected ? Color.blue : Color(.systemGray5))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(scholar.name.prefix(1)).uppercased())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : .secondary)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(scholar.displayName)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? .blue : .primary)
                        .lineLimit(1)
                    
                    if let stats = citationManager.statistics[scholar.id] {
                        Text("\(stats.totalCitingPapers) \("citations".localized)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Content View
    
    private func contentView(for scholar: Scholar) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // 论文列表（显示引用数量）
                publicationListView(for: scholar.id)
            }
            .padding()
        }
        .refreshable {
            await refreshData(for: scholar)
        }
    }
    
    
    // MARK: - Publication List View
    
    private func publicationListView(for scholarId: String) -> some View {
        // 直接使用从 Google Scholar 获取的已排序数据
        let publications = (citationManager.scholarPublications[scholarId] ?? []).map { pub in
            PublicationDisplay(
                id: pub.id,
                title: pub.title,
                clusterId: pub.clusterId,
                citationCount: pub.citationCount,
                year: pub.year
            )
        }
        
        let changes = citationManager.publicationChanges[scholarId]
        
        return VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Text("publication_list".localized)
                    .font(.headline)
                
                Spacer()
                
                if let changes = changes, changes.hasChanges {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("+\(changes.totalNewCitations)")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Text("\(publications.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if citationManager.isLoading {
                publicationLoadingView
            } else if publications.isEmpty {
                publicationEmptyView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(publications) { pub in
                        VStack(spacing: 0) {
                            publicationRow(pub, changes: changes)
                                .id(pub.id)
                            Divider()
                                .padding(.leading, 4)
                        }
                    }
                    
                    // 加载更多指示器（当滚动到底部时自动触发）
                    if citationManager.hasMorePublications[scholarId] == true {
                        loadMoreView(for: scholarId)
                            .onAppear {
                                // 当加载更多视图出现时，触发加载（模拟点击"Show more"）
                                loadMorePublications(for: scholarId)
                            }
                    } else if citationManager.isLoadingMore {
                        loadMoreView(for: scholarId)
                    }
                }
            }
        }
        .sheet(item: $selectedPublication) { publication in
            citingPapersSheetView(for: publication)
        }
    }
    
    private func publicationRow(_ publication: PublicationDisplay, changes: CitationCacheService.PublicationChanges?) -> some View {
        // 检查这篇论文的引用数是否有变化（使用 clusterId 或 title+year 匹配）
        let change = changes?.increased.first { changePub in
            // 优先使用 clusterId 匹配
            if let pubClusterId = publication.clusterId,
               let changeClusterId = changePub.publication.clusterId,
               !pubClusterId.isEmpty, !changeClusterId.isEmpty {
                return pubClusterId == changeClusterId
            }
            // 后备：使用 title + year 匹配
            return changePub.publication.title == publication.title &&
                   changePub.publication.year == publication.year
        }
        
        return HStack(spacing: 8) {
            // 左侧主要内容
            VStack(alignment: .leading, spacing: 6) {
                // 标题
                Text(publication.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // 元数据 - 左对齐
                HStack(spacing: 16) {
                    if let year = publication.year {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(year))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                if let citationCount = publication.citationCount, let _ = publication.clusterId {
                    // 可点击的引用数
                    Button(action: {
                        selectedPublication = publication
                        showingCitingPapersSheet = true
                    }) {
                            HStack(spacing: 4) {
                                Image(systemName: "quote.bubble")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text("\(citationCount)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                        }
                        .disabled(citationCount == 0)
                    } else if let citationCount = publication.citationCount {
                        HStack(spacing: 4) {
                            Image(systemName: "quote.bubble")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(citationCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            // 右侧变化标记
            if let change = change, change.delta > 0 {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("+\(change.delta)")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
    
    private var publicationLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("loading".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var publicationEmptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("no_publications_found".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    /// 加载更多视图
    private func loadMoreView(for scholarId: String) -> some View {
        VStack(spacing: 12) {
            if citationManager.isLoadingMore {
                ProgressView()
                    .scaleEffect(0.8)
                Text("loading_more".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("load_more".localized)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    // MARK: - Summary Stats Card
    
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("no_scholars_added".localized)
                .font(.headline)
            
            Text("add_scholar_first".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var selectScholarPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.up")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("select_scholar_above".localized)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Toolbar Buttons
    
    // Toolbar 排序按钮（显示在导航栏右上角）
    private func sortButtonToolbar(for scholarId: String) -> some View {
        Menu {
            ForEach(PublicationSortOption.allCases, id: \.self) { option in
                Button(action: {
                    // 切换排序选项
                    sortOption = option
                    
                    // 重新请求数据（使用 Google Scholar 的排序参数）
                    let sortParam = option.googleScholarParam
                    citationManager.fetchScholarPublications(
                        for: scholarId,
                        sortBy: sortParam,
                        forceRefresh: true
                    )
                }) {
                    HStack {
                        Image(systemName: option.icon)
                        Text(option.title)
                        
                        if sortOption == option {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .disabled(citationManager.isLoading)
    }
    
    // 内联排序按钮（显示在列表标题右侧）- 已废弃，保留以防需要
    private func sortButtonInline(for scholarId: String) -> some View {
        Menu {
            ForEach(PublicationSortOption.allCases, id: \.self) { option in
                Button(action: {
                    // 切换排序选项
                    sortOption = option
                    
                    // 重新请求数据（使用 Google Scholar 的排序参数）
                    let sortParam = option.googleScholarParam
                    citationManager.fetchScholarPublications(
                        for: scholarId,
                        sortBy: sortParam,
                        forceRefresh: true
                    )
                }) {
                    HStack {
                        Image(systemName: option.icon)
                        Text(option.title)
                        
                        if sortOption == option {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .disabled(citationManager.isLoading)
    }
    
    private var filterButton: some View {
        Button(action: {
            showingFilterSheet = true
        }) {
            Image(systemName: currentFilter.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .disabled(selectedScholar == nil)
    }
    
    private var exportButton: some View {
        Button(action: {
            showingExportSheet = true
        }) {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(selectedScholar == nil || filteredPapers.isEmpty)
    }
    
    private var refreshButton: some View {
        Button(action: {
            if let scholar = selectedScholar {
                citationManager.refreshAllData(for: scholar.id)
            }
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(selectedScholar == nil || citationManager.isLoading)
    }
    
    // MARK: - Export Options
    
    private var exportOptionsView: some View {
        NavigationView {
            List {
                ForEach(CitationExportService.ExportFormat.allCases, id: \.self) { format in
                    Button(action: {
                        exportData(format: format)
                    }) {
                        HStack {
                            Text("export_\(format.rawValue.lowercased())".localized)
                            Spacer()
                            Image(systemName: "doc.text")
                        }
                    }
                }
            }
            .navigationTitle("export_format".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("cancel".localized) {
                        showingExportSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData(for scholar: Scholar) {
        // 使用当前选择的排序选项
        let sortParam = sortOption.googleScholarParam
        citationManager.fetchScholarPublications(for: scholar.id, sortBy: sortParam, forceRefresh: true)
    }
    
    /// 加载更多论文
    private func loadMorePublications(for scholarId: String) {
        let sortParam = sortOption.googleScholarParam
        citationManager.loadMorePublications(for: scholarId, sortBy: sortParam)
    }
    
    private func refreshData(for scholar: Scholar) async {
        citationManager.fetchScholarPublications(for: scholar.id, forceRefresh: true)
        
        // 等待数据加载
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }
    
    private func updateFilteredPapers(for scholarId: String) {
        let papers = citationManager.citingPapers[scholarId] ?? []
        filteredPapers = citationManager.applyFilter(currentFilter, to: papers)
    }
    
    private func applyFilter(_ filter: CitationFilter) {
        if let scholar = selectedScholar {
            updateFilteredPapers(for: scholar.id)
        }
    }
    
    // MARK: - Sorting
    // 注意：排序现在由 Google Scholar 服务器端完成，我们只需要传递 sortby 参数
    
    // MARK: - Export
    
    private func exportData(format: CitationExportService.ExportFormat) {
        guard let scholar = selectedScholar else { return }
        
        if let result = citationManager.exportData(
            for: scholar.id,
            papers: filteredPapers,
            format: format
        ) {
            shareData(result)
        }
        
        showingExportSheet = false
    }
    
    private func shareData(_ result: ExportResult) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(result.fileName)
        
        do {
            try result.data.write(to: tempURL)
            
            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("Failed to export: \(error)")
        }
    }
    
    // MARK: - Citing Papers Sheet View
    
    @ViewBuilder
    func citingPapersSheetView(for publication: PublicationDisplay) -> some View {
        CitingPapersSheetContent(
            publication: publication,
            citingPapers: $citingPapers,
            isLoadingCitingPapers: $isLoadingCitingPapers,
            isLoadingMoreCitingPapers: $isLoadingMoreCitingPapers,
            hasMoreCitingPapers: $hasMoreCitingPapers,
            citingPapersError: $citingPapersError,
            sortByDate: $citingPapersSortByDate,
            onDismiss: {
                selectedPublication = nil
                citingPapers = []
                citingPapersError = nil
                hasMoreCitingPapers = false
            },
            onLoadCitingPapers: { loadCitingPapers(for: publication) },
            onLoadMoreCitingPapers: { loadMoreCitingPapers(for: publication) }
        )
    }
    
    // MARK: - Load Citing Papers
    
    private func loadCitingPapers(for publication: PublicationDisplay) {
        guard let clusterId = publication.clusterId else {
            citingPapersError = "无法获取引用数据：缺少 Cluster ID"
            return
        }
        
        isLoadingCitingPapers = true
        citingPapersError = nil
        citingPapers = []
        hasMoreCitingPapers = false
        
        // 先检查缓存
        let cacheService = CitationCacheService.shared
        if let cachedPapers = cacheService.getCachedCitingPapersList(for: clusterId, sortByDate: citingPapersSortByDate, startIndex: 0) {
            // 使用缓存数据
            citingPapers = cachedPapers
            hasMoreCitingPapers = cachedPapers.count >= 10
            isLoadingCitingPapers = false
            
            // 在后台静默更新
            DispatchQueue.global(qos: .utility).async { [self] in
                CitationFetchService.shared.fetchCitingPapersForClusterId(clusterId, startIndex: 0, sortByDate: citingPapersSortByDate) { result in
                    if case .success(let papers) = result {
                        // 更新缓存
                        cacheService.cacheCitingPapersList(papers, for: clusterId, sortByDate: citingPapersSortByDate, startIndex: 0)
                        // 如果数据有变化，更新UI
                        DispatchQueue.main.async {
                            if papers.count != cachedPapers.count || papers != cachedPapers {
                                self.citingPapers = papers
                                self.hasMoreCitingPapers = papers.count >= 10
                            }
                        }
                    }
                }
            }
            return
        }
        
        // 调用服务获取引用文章（第一页）
        CitationFetchService.shared.fetchCitingPapersForClusterId(clusterId, startIndex: 0, sortByDate: citingPapersSortByDate) { [self] result in
            DispatchQueue.main.async {
                isLoadingCitingPapers = false
                
                switch result {
                case .success(let papers):
                    citingPapers = papers
                    // 缓存数据
                    cacheService.cacheCitingPapersList(papers, for: clusterId, sortByDate: citingPapersSortByDate, startIndex: 0)
                    // 如果返回的文章数等于10，说明可能还有更多（Google Scholar每页显示10篇）
                    hasMoreCitingPapers = papers.count >= 10
                    if papers.isEmpty {
                        citingPapersError = "anti_bot_restriction_fetch".localized
                    }
                case .failure(_):
                    // 统一错误信息，明确说明是反爬虫机制
                    citingPapersError = "由于 Google Scholar 的反爬虫机制，无法获取引用文章。"
                }
            }
        }
    }
    
    private func loadMoreCitingPapers(for publication: PublicationDisplay) {
        guard let clusterId = publication.clusterId else { return }
        guard !isLoadingMoreCitingPapers && hasMoreCitingPapers else { return }
        
        isLoadingMoreCitingPapers = true
        let startIndex = citingPapers.count
        
        // 先检查缓存
        let cacheService = CitationCacheService.shared
        if let cachedPapers = cacheService.getCachedCitingPapersList(for: clusterId, sortByDate: citingPapersSortByDate, startIndex: startIndex) {
            // 使用缓存数据
            citingPapers.append(contentsOf: cachedPapers)
            hasMoreCitingPapers = cachedPapers.count >= 10
            isLoadingMoreCitingPapers = false
            
            // 在后台静默更新
            DispatchQueue.global(qos: .utility).async { [self] in
                CitationFetchService.shared.fetchCitingPapersForClusterId(clusterId, startIndex: startIndex, sortByDate: citingPapersSortByDate) { result in
                    if case .success(let papers) = result {
                        // 更新缓存
                        cacheService.cacheCitingPapersList(papers, for: clusterId, sortByDate: citingPapersSortByDate, startIndex: startIndex)
                        // 如果数据有变化，更新UI
                        DispatchQueue.main.async {
                            if papers != cachedPapers {
                                // 移除旧的缓存数据，添加新数据
                                let oldCount = self.citingPapers.count - cachedPapers.count
                                self.citingPapers = Array(self.citingPapers.prefix(oldCount))
                                self.citingPapers.append(contentsOf: papers)
                                self.hasMoreCitingPapers = papers.count >= 10
                            }
                        }
                    }
                }
            }
            return
        }
        
        // 调用服务获取更多引用文章
        CitationFetchService.shared.fetchCitingPapersForClusterId(clusterId, startIndex: startIndex, sortByDate: citingPapersSortByDate) { [self] result in
            DispatchQueue.main.async {
                isLoadingMoreCitingPapers = false
                
                switch result {
                case .success(let papers):
                    if !papers.isEmpty {
                        citingPapers.append(contentsOf: papers)
                        // 缓存数据
                        cacheService.cacheCitingPapersList(papers, for: clusterId, sortByDate: citingPapersSortByDate, startIndex: startIndex)
                        // 如果返回的文章数少于10，说明没有更多了
                        hasMoreCitingPapers = papers.count >= 10
                    } else {
                        hasMoreCitingPapers = false
                    }
                case .failure(_):
                    // 统一错误信息，明确说明是反爬虫机制
                    citingPapersError = "anti_bot_restriction_message".localized
                    hasMoreCitingPapers = false
                }
            }
        }
    }
    
}

// MARK: - Citing Papers Sheet Content
struct CitingPapersSheetContent: View {
    let publication: PublicationDisplay
    @Binding var citingPapers: [CitingPaper]
    @Binding var isLoadingCitingPapers: Bool
    @Binding var isLoadingMoreCitingPapers: Bool
    @Binding var hasMoreCitingPapers: Bool
    @Binding var citingPapersError: String?
    @Binding var sortByDate: Bool
    let onDismiss: () -> Void
    let onLoadCitingPapers: () -> Void
    let onLoadMoreCitingPapers: () -> Void
    
    @State private var selectedCitingPaper: CitingPaper?
    
    var body: some View {
        NavigationView {
            Group {
                if let selectedPaper = selectedCitingPaper {
                    // 显示文章详情
                    citingPaperDetailView(for: selectedPaper)
                } else {
                    // 显示引用文章列表
                    VStack(spacing: 0) {
                        // 论文信息头部
                        publicationHeaderView(for: publication)
                        
                        Divider()
                        
                        // 引用文章内容
                        if isLoadingCitingPapers && citingPapers.isEmpty {
                            // 只在初始加载且没有数据时显示加载视图
                            citingPapersLoadingView
                        } else if citingPapers.isEmpty && citingPapersError == nil {
                            // 没有数据且没有错误时显示空视图
                            citingPapersEmptyView
                        } else {
                            // 有数据或错误时，显示列表（错误会在列表下方显示）
                            citingPapersListViewWithError
                        }
                    }
                }
            }
            .navigationTitle(selectedCitingPaper == nil ? "引用文章 (\(citingPapers.count))" : "文章详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedCitingPaper != nil {
                        Button("返回") {
                            selectedCitingPaper = nil
                        }
                    } else {
                        // 排序按钮
                        Menu {
                            Button(action: {
                                sortByDate = true
                                onLoadCitingPapers()
                            }) {
                                HStack {
                                    Text("sort_by_date".localized)
                                    if sortByDate {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            
                            Button(action: {
                                sortByDate = false
                                onLoadCitingPapers()
                            }) {
                                HStack {
                                    Text("sort_by_relevance".localized)
                                    if !sortByDate {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        selectedCitingPaper = nil
                        onDismiss()
                    }
                }
            }
            .onAppear {
                if selectedCitingPaper == nil {
                    onLoadCitingPapers()
                }
            }
        }
    }
    
    // MARK: - Publication Header
    
    private func publicationHeaderView(for publication: PublicationDisplay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(publication.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                if let year = publication.year {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(String(year))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let citationCount = publication.citationCount {
                    HStack(spacing: 4) {
                        Image(systemName: "quote.bubble")
                            .font(.caption2)
                        Text(String(format: "citations_count".localized, citationCount))
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Citing Papers List
    
    private var citingPapersListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(citingPapers) { paper in
                    VStack(spacing: 0) {
                        citingPaperRowView(paper)
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                
                // 加载更多视图
                if hasMoreCitingPapers {
                    loadMoreCitingPapersView
                        .onAppear {
                            onLoadMoreCitingPapers()
                        }
                }
            }
        }
    }
    
    // 带错误提示的列表视图（在已有内容下方显示错误）
    private var citingPapersListViewWithError: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 已加载的文章列表
                ForEach(citingPapers) { paper in
                    VStack(spacing: 0) {
                        citingPaperRowView(paper)
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                
                // 加载更多视图
                if hasMoreCitingPapers && citingPapersError == nil {
                    loadMoreCitingPapersView
                        .onAppear {
                            onLoadMoreCitingPapers()
                        }
                }
                
                // 错误提示（在已有内容下方显示）
                if let error = citingPapersError {
                    citingPapersInlineErrorView(error)
                }
            }
        }
    }
    
    private var loadMoreCitingPapersView: some View {
        VStack(spacing: 12) {
            if isLoadingMoreCitingPapers {
                ProgressView()
                    .scaleEffect(1.0)
                Text("loading_more".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button(action: {
                    onLoadMoreCitingPapers()
                }) {
                    Text("load_more".localized)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    private func citingPaperRowView(_ paper: CitingPaper) -> some View {
        Button(action: {
            selectedCitingPaper = paper
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // 标题
                Text(paper.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                
                // 作者
                if !paper.authors.isEmpty {
                    Text(paper.authors.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // 元数据
                HStack(spacing: 12) {
                    if let year = paper.year {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(String(year))
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let venue = paper.venue, !venue.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2")
                                .font(.caption2)
                            Text(venue)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let citationCount = paper.citationCount {
                        HStack(spacing: 4) {
                            Image(systemName: "quote.bubble")
                                .font(.caption2)
                            Text("\(citationCount)")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Loading/Error/Empty Views
    
    private var citingPapersLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("fetching_citing_papers".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("this_may_take_a_few_seconds".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // 全屏错误视图（用于初始加载失败且没有数据时）
    private func citingPapersErrorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("load_failed".localized)
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // 按钮组
            VStack(spacing: 12) {
                Button(action: {
                    onLoadCitingPapers()
                }) {
                    Label("重试", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                
                // 在浏览器中打开按钮
                if let clusterId = publication.clusterId {
                    Button(action: {
                        let urlString = "https://scholar.google.com/scholar?hl=en&cites=\(clusterId)"
                        guard let url = URL(string: urlString) else { return }
                        #if os(iOS)
                        UIApplication.shared.open(url)
                        #endif
                    }) {
                        Label("在浏览器中打开", systemImage: "safari")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // 内联错误视图（在已有内容下方显示）
    private func citingPapersInlineErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("load_failed".localized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("anti_bot_restriction_message".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            
            // 操作按钮
            HStack(spacing: 12) {
                Button(action: {
                    // 清除错误，重试加载
                    DispatchQueue.main.async {
                        citingPapersError = nil
                        if citingPapers.isEmpty {
                            onLoadCitingPapers()
                        } else {
                            onLoadMoreCitingPapers()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("retry".localized)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                // 在浏览器中打开按钮
                if let clusterId = publication.clusterId {
                    Button(action: {
                        let urlString = "https://scholar.google.com/scholar?hl=en&cites=\(clusterId)"
                        guard let url = URL(string: urlString) else { return }
                        #if os(iOS)
                        UIApplication.shared.open(url)
                        #endif
                    }) {
                        HStack {
                            Image(systemName: "safari")
                            Text("open_in_browser".localized)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    private var citingPapersEmptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("no_citing_papers_found".localized)
                .font(.headline)
            
            Text("no_citing_papers_reasons".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Citing Paper Detail View
    
    @ViewBuilder
    func citingPaperDetailView(for paper: CitingPaper) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题
                Text(paper.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // 作者
                if !paper.authors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("author".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Text(paper.authors.joined(separator: ", "))
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
                
                // 元数据
                VStack(alignment: .leading, spacing: 12) {
                    if let year = paper.year {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            Text("year".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(year))
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if let venue = paper.venue, !venue.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "building.2")
                                .foregroundColor(.secondary)
                            Text("venue".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(venue)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if let citationCount = paper.citationCount {
                        HStack(spacing: 8) {
                            Image(systemName: "quote.bubble")
                                .foregroundColor(.blue)
                            Text("citation_count".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(citationCount)")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Divider()
                
                // 摘要
                if let abstract = paper.abstract, !abstract.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("abstract".localized)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(abstract)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Divider()
                
                // 操作按钮
                VStack(spacing: 12) {
                    if let scholarUrl = paper.scholarUrl, let url = URL(string: scholarUrl) {
                        Button(action: {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #endif
                        }) {
                            HStack {
                                Image(systemName: "safari")
                                Text("view_on_google_scholar".localized)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    
                    if let pdfUrl = paper.pdfUrl, let url = URL(string: pdfUrl) {
                        Button(action: {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #endif
                        }) {
                            HStack {
                                Image(systemName: "doc.fill")
                                Text("view_pdf".localized)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview
struct WhoCiteMeView_Previews: PreviewProvider {
    static var previews: some View {
        WhoCiteMeView()
            .environmentObject(DataManager.shared)
            .environmentObject(LocalizationManager.shared)
    }
}
