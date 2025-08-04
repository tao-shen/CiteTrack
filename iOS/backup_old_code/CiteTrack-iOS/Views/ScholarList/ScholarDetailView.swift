import SwiftUI

struct ScholarDetailView: View {
    
    // MARK: - Properties
    let scholar: Scholar
    let onScholarUpdated: (Scholar) -> Void
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    // MARK: - State
    @State private var isRefreshing = false
    @State private var showingEditSheet = false
    @State private var refreshError: String?
    @State private var currentScholar: Scholar
    
    init(scholar: Scholar, onScholarUpdated: @escaping (Scholar) -> Void) {
        self.scholar = scholar
        self.onScholarUpdated = onScholarUpdated
        self._currentScholar = State(initialValue: scholar)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 学者头部信息
                    scholarHeaderView
                    
                    // 引用统计卡片
                    citationStatsView
                    
                    // 最近更新信息
                    updateInfoView
                    
                    // 操作按钮
                    actionButtonsView
                    
                    // 错误信息显示
                    if let error = refreshError {
                        errorView(error)
                    }
                }
                .padding()
            }
            .navigationTitle("scholar_details".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("edit".localized) {
                        showingEditSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditScholarView(scholar: currentScholar) { updatedScholar in
                    currentScholar = updatedScholar
                    onScholarUpdated(updatedScholar)
                }
            }
            .refreshable {
                await refreshScholarData()
            }
        }
    }
    
    // MARK: - Scholar Header View
    
    private var scholarHeaderView: some View {
        VStack(spacing: 16) {
            // 头像
            Circle()
                .fill(Color(currentScholar.id.hashColor))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(currentScholar.name.initials())
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // 基本信息
            VStack(spacing: 8) {
                Text(currentScholar.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Scholar ID: \(currentScholar.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                
                // Google Scholar链接
                Button {
                    if let url = URL(string: "https://scholar.google.com/citations?user=\(currentScholar.id)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("view_on_google_scholar".localized, systemImage: "link")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Citation Stats View
    
    private var citationStatsView: some View {
        VStack(spacing: 12) {
            Text("citation_statistics".localized)
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let citations = currentScholar.citations {
                VStack(spacing: 16) {
                    // 主要引用数
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("total_citations".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("\(citations)")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }
                    
                    // 格式化显示
                    if citations >= 1000 {
                        Text(String.formatCitationCount(citations))
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("no_citation_data".localized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("refresh_to_get_data".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Update Info View
    
    private var updateInfoView: some View {
        VStack(spacing: 12) {
            Text("update_information".localized)
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                    
                    Text("last_updated".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let lastUpdated = currentScholar.lastUpdated {
                        Text(lastUpdated.timeAgoString)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    } else {
                        Text("never_updated".localized)
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
                
                if let lastUpdated = currentScholar.lastUpdated {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        
                        Text("exact_time".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(lastUpdated.displayString)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons View
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            // 刷新按钮
            Button {
                refreshScholarData()
            } label: {
                HStack {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    
                    Text(isRefreshing ? "refreshing".localized : "refresh_data".localized)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isRefreshing)
            
            HStack(spacing: 12) {
                // 复制ID按钮
                Button {
                    UIPasteboard.general.string = currentScholar.id
                    
                    // 显示复制成功的反馈
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                } label: {
                    Label("copy_id".localized, systemImage: "doc.on.doc")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                }
                
                // 分享按钮
                Button {
                    shareScholar()
                } label: {
                    Label("share".localized, systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.red)
            
            Text("refresh_failed".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("try_again".localized) {
                refreshScholarData()
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Methods
    
    private func refreshScholarData() {
        Task {
            await refreshScholarDataAsync()
        }
    }
    
    @MainActor
    private func refreshScholarDataAsync() async {
        isRefreshing = true
        refreshError = nil
        
        await withCheckedContinuation { continuation in
            GoogleScholarService.shared.fetchScholarInfo(for: currentScholar.id) { result in
                DispatchQueue.main.async {
                    self.isRefreshing = false
                    
                    switch result {
                    case .success(let info):
                        var updatedScholar = self.currentScholar
                        updatedScholar.name = info.name
                        updatedScholar.citations = info.citations
                        updatedScholar.lastUpdated = Date()
                        
                        self.currentScholar = updatedScholar
                        self.onScholarUpdated(updatedScholar)
                        self.refreshError = nil
                        
                    case .failure(let error):
                        self.refreshError = error.localizedDescription
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func shareScholar() {
        let text = """
        \(currentScholar.displayName)
        Google Scholar Profile: https://scholar.google.com/citations?user=\(currentScholar.id)
        \(currentScholar.citations != nil ? "Citations: \(currentScholar.citations!)" : "")
        
        Shared from CiteTrack
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Edit Scholar View
struct EditScholarView: View {
    let scholar: Scholar
    let onScholarUpdated: (Scholar) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    
    init(scholar: Scholar, onScholarUpdated: @escaping (Scholar) -> Void) {
        self.scholar = scholar
        self.onScholarUpdated = onScholarUpdated
        self._name = State(initialValue: scholar.name)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("scholar_information".localized) {
                    HStack {
                        Text("scholar_id".localized)
                        Spacer()
                        Text(scholar.id)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("scholar_name".localized)
                        TextField("enter_name".localized, text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("edit_scholar".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        var updatedScholar = scholar
                        updatedScholar.name = name.isEmpty ? scholar.name : name
                        onScholarUpdated(updatedScholar)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview
struct ScholarDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ScholarDetailView(
            scholar: Scholar.mock(id: "abc123", name: "张三教授", citations: 1500)
        ) { _ in }
        .environmentObject(LocalizationManager.shared)
    }
}