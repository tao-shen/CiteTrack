import Foundation
import SwiftUI
import Combine

@MainActor
class ScholarViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var scholars: [Scholar] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var lastUpdateDate: Date?
    
    // MARK: - Private Properties
    private let settingsManager = SettingsManager.shared
    private let googleScholarService = GoogleScholarService.shared
    private let notificationService = NotificationService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadScholars()
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func loadScholars() {
        scholars = settingsManager.getScholars()
        lastUpdateDate = settingsManager.lastUpdateDate
    }
    
    func addScholar(_ scholar: Scholar) {
        scholars.append(scholar)
        settingsManager.addScholar(scholar)
        
        // 立即获取数据
        Task {
            await refreshScholar(scholar)
        }
    }
    
    func updateScholar(_ scholar: Scholar) {
        if let index = scholars.firstIndex(where: { $0.id == scholar.id }) {
            scholars[index] = scholar
            settingsManager.updateScholar(scholar)
        }
    }
    
    func removeScholar(_ scholar: Scholar) {
        scholars.removeAll { $0.id == scholar.id }
        settingsManager.removeScholar(id: scholar.id)
    }
    
    func refreshAllScholars() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        await withTaskGroup(of: Void.self) { group in
            for scholar in scholars {
                group.addTask {
                    await self.refreshScholar(scholar)
                }
            }
        }
        
        settingsManager.lastUpdateDate = Date()
        lastUpdateDate = Date()
        isLoading = false
    }
    
    func refreshScholar(_ scholar: Scholar) async {
        await withCheckedContinuation { continuation in
            googleScholarService.fetchAndSaveScholarInfo(for: scholar.id) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let info):
                        var updatedScholar = scholar
                        
                        // 检查引用数是否有变化
                        let oldCount = scholar.citations ?? 0
                        let newCount = info.citations
                        
                        updatedScholar.name = info.name
                        updatedScholar.citations = newCount
                        updatedScholar.lastUpdated = Date()
                        
                        // 更新学者数据
                        self.updateScholar(updatedScholar)
                        
                        // 如果引用数有变化，发送通知
                        if oldCount != newCount && oldCount > 0 {
                            self.notificationService.scheduleCitationChangeNotification(
                                scholarName: updatedScholar.displayName,
                                oldCount: oldCount,
                                newCount: newCount
                            )
                        }
                        
                    case .failure(let error):
                        self.error = error.localizedDescription
                        print("❌ 刷新学者 \(scholar.displayName) 失败: \(error)")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    func moveScholars(from source: IndexSet, to destination: Int) {
        scholars.move(fromOffsets: source, toOffset: destination)
        settingsManager.saveScholars(scholars)
    }
    
    func validateScholarId(_ scholarId: String) async -> ValidationResult {
        guard !scholarId.isEmpty else {
            return .invalid("scholar_id_empty".localized)
        }
        
        guard scholarId.isValidScholarId else {
            return .invalid("invalid_scholar_id_format".localized)
        }
        
        // 检查是否已存在
        if scholars.contains(where: { $0.id == scholarId }) {
            return .invalid("scholar_already_exists".localized)
        }
        
        return await withCheckedContinuation { continuation in
            googleScholarService.fetchScholarInfo(for: scholarId) { result in
                let validationResult: ValidationResult
                
                switch result {
                case .success(let info):
                    let scholar = Scholar(id: scholarId, name: info.name)
                    validationResult = .valid(scholar, info.citations)
                    
                case .failure(let error):
                    switch error {
                    case .scholarNotFound:
                        validationResult = .invalid("scholar_not_found".localized)
                    case .rateLimited:
                        validationResult = .invalid("rate_limited_error".localized)
                    case .networkError:
                        validationResult = .invalid("network_error".localized)
                    default:
                        validationResult = .invalid("validation_error".localized)
                    }
                }
                
                continuation.resume(returning: validationResult)
            }
        }
    }
    
    // MARK: - Statistics
    
    var totalCitations: Int {
        scholars.compactMap { $0.citations }.reduce(0, +)
    }
    
    var averageCitations: Double {
        let citationCounts = scholars.compactMap { $0.citations }
        guard !citationCounts.isEmpty else { return 0 }
        return Double(citationCounts.reduce(0, +)) / Double(citationCounts.count)
    }
    
    var topScholar: Scholar? {
        scholars.max { ($0.citations ?? 0) < ($1.citations ?? 0) }
    }
    
    var scholarsWithData: [Scholar] {
        scholars.filter { $0.citations != nil }
    }
    
    var scholarsNeedingUpdate: [Scholar] {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return scholars.filter { scholar in
            guard let lastUpdated = scholar.lastUpdated else { return true }
            return lastUpdated < oneHourAgo
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 监听设置变化
        settingsManager.$updateInterval
            .sink { [weak self] _ in
                // 可以根据更新间隔调整自动刷新逻辑
            }
            .store(in: &cancellables)
    }
}

// MARK: - Validation Result
enum ValidationResult {
    case valid(Scholar, Int) // Scholar and citation count
    case invalid(String)    // Error message
    
    var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .invalid(let message):
            return message
        }
    }
    
    var scholar: Scholar? {
        switch self {
        case .valid(let scholar, _):
            return scholar
        case .invalid:
            return nil
        }
    }
    
    var citationCount: Int? {
        switch self {
        case .valid(_, let count):
            return count
        case .invalid:
            return nil
        }
    }
}