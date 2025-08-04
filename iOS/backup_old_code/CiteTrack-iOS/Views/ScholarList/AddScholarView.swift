import SwiftUI

struct AddScholarView: View {
    
    // MARK: - Properties
    let onScholarAdded: (Scholar) -> Void
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    // MARK: - State
    @State private var scholarId = ""
    @State private var scholarName = ""
    @State private var isValidating = false
    @State private var validationError: String?
    @State private var isValid = false
    @State private var previewScholar: Scholar?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("scholar_id".localized)
                            .font(.headline)
                        
                        TextField("enter_scholar_id".localized, text: $scholarId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: scholarId) { _ in
                                validateScholarId()
                            }
                        
                        Text("scholar_id_help".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("scholar_information".localized)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("scholar_name_optional".localized)
                            .font(.headline)
                        
                        TextField("enter_scholar_name".localized, text: $scholarName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("name_auto_fetch".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 验证状态
                if isValidating {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("validating_scholar_id".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let error = validationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                } else if isValid, let preview = previewScholar {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("scholar_found".localized, systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.subheadline)
                            
                            ScholarPreviewCard(scholar: preview)
                        }
                    } header: {
                        Text("preview".localized)
                    }
                }
                
                // 示例部分
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("how_to_find_scholar_id".localized)
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. " + "visit_google_scholar".localized)
                            Text("2. " + "search_for_author".localized)
                            Text("3. " + "click_author_name".localized)
                            Text("4. " + "copy_from_url".localized)
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        Text("example_url".localized)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.top, 4)
                    }
                } header: {
                    Text("help".localized)
                }
            }
            .navigationTitle("add_scholar".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("add".localized) {
                        addScholar()
                    }
                    .disabled(!canAddScholar)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canAddScholar: Bool {
        return !scholarId.isEmpty && 
               scholarId.isValidScholarId && 
               !isValidating &&
               validationError == nil
    }
    
    // MARK: - Methods
    
    private func validateScholarId() {
        guard !scholarId.isEmpty else {
            resetValidation()
            return
        }
        
        guard scholarId.isValidScholarId else {
            validationError = "invalid_scholar_id_format".localized
            isValid = false
            previewScholar = nil
            return
        }
        
        // 防抖验证
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒延迟
            
            guard !Task.isCancelled else { return }
            
            await performValidation()
        }
    }
    
    @MainActor
    private func performValidation() async {
        isValidating = true
        validationError = nil
        
        await withCheckedContinuation { continuation in
            GoogleScholarService.shared.fetchScholarInfo(for: scholarId) { result in
                DispatchQueue.main.async {
                    self.isValidating = false
                    
                    switch result {
                    case .success(let info):
                        self.isValid = true
                        self.validationError = nil
                        
                        // 如果用户没有输入名字，使用获取到的名字
                        if self.scholarName.isEmpty {
                            self.scholarName = info.name
                        }
                        
                        // 创建预览学者
                        var scholar = Scholar(id: self.scholarId, name: info.name)
                        scholar.citations = info.citations
                        scholar.lastUpdated = Date()
                        self.previewScholar = scholar
                        
                    case .failure(let error):
                        self.isValid = false
                        self.previewScholar = nil
                        
                        switch error {
                        case .scholarNotFound:
                            self.validationError = "scholar_not_found".localized
                        case .rateLimited:
                            self.validationError = "rate_limited_error".localized
                        case .networkError:
                            self.validationError = "network_error".localized
                        default:
                            self.validationError = "validation_error".localized
                        }
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func resetValidation() {
        isValidating = false
        validationError = nil
        isValid = false
        previewScholar = nil
    }
    
    private func addScholar() {
        let name = scholarName.isEmpty ? "学者 \(scholarId.prefix(8))" : scholarName
        let scholar = Scholar(id: scholarId, name: name)
        
        onScholarAdded(scholar)
        dismiss()
    }
}

// MARK: - Scholar Preview Card
struct ScholarPreviewCard: View {
    let scholar: Scholar
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(scholar.id.hashColor))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(scholar.name.initials())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(scholar.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let citations = scholar.citations {
                    Text("\(citations) " + "citations".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("ID: \(scholar.id)")
                    .font(.caption)
                    .foregroundColor(.tertiary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview
struct AddScholarView_Previews: PreviewProvider {
    static var previews: some View {
        AddScholarView { scholar in
            print("Added scholar: \(scholar)")
        }
        .environmentObject(LocalizationManager.shared)
    }
}