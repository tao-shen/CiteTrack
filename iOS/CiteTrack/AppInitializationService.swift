import Foundation
import SwiftUI
import Network

// MARK: - 应用初始化服务
/// 负责处理应用第一次启动时的初始化任务
class AppInitializationService: ObservableObject {
    static let shared = AppInitializationService()
    
    @Published var isInitializing = false
    @Published var initializationProgress: String = ""
    @Published var isFirstLaunch: Bool = false
    
    private let dataManager = DataManager.shared
    private let googleScholarService = GoogleScholarService()
    
    private init() {
        checkFirstLaunch()
    }
    
    // MARK: - 首次启动检查
    
    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        isFirstLaunch = !hasLaunchedBefore
        
        if isFirstLaunch {
            print("🚀 [AppInitialization] 检测到首次启动")
        } else {
            print("ℹ️ [AppInitialization] 非首次启动")
        }
    }
    
    // MARK: - 初始化流程
    
    /// 执行完整的初始化流程
    func performInitialization() async {
        guard isFirstLaunch else {
            print("ℹ️ [AppInitialization] 非首次启动，跳过初始化")
            return
        }
        
        await MainActor.run {
            isInitializing = true
            initializationProgress = "开始初始化..."
        }
        
        // 1. 等待网络连接
        await waitForNetworkConnection()
        
        // 2. 导入初始化数据
        await importInitialData()
        
        // 3. 更新所有学者数据
        await updateAllScholars()
        
        // 4. 标记初始化完成
        await markInitializationComplete()
        
        await MainActor.run {
            isInitializing = false
            initializationProgress = "初始化完成！"
        }
        
        print("✅ [AppInitialization] 初始化流程完成")
    }
    
    // MARK: - 网络连接检查
    
    private func waitForNetworkConnection() async {
        await MainActor.run {
            initializationProgress = "检查网络连接..."
        }
        
        // 简单的网络检查，尝试连接Google Scholar
        let url = URL(string: "https://scholar.google.com")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("✅ [AppInitialization] 网络连接正常")
            } else {
                print("⚠️ [AppInitialization] 网络连接异常，继续执行初始化")
            }
        } catch {
            print("⚠️ [AppInitialization] 网络连接失败，继续执行初始化: \(error)")
        }
    }
    
    // MARK: - 数据导入
    
    private func importInitialData() async {
        await MainActor.run {
            initializationProgress = "导入初始化数据..."
        }
        
        guard let jsonURL = Bundle.main.url(forResource: "citetrack_init", withExtension: "json") else {
            print("❌ [AppInitialization] 找不到 citetrack_init.json 文件")
            return
        }
        
        do {
            let jsonData = try Data(contentsOf: jsonURL)
            let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] ?? []
            
            print("📊 [AppInitialization] 找到 \(jsonArray.count) 条初始化数据")
            
            // 解析并导入数据
            var scholars: [Scholar] = []
            var historyEntries: [CitationHistory] = []
            
            for entry in jsonArray {
                guard let scholarId = entry["scholarId"] as? String,
                      let scholarName = entry["scholarName"] as? String,
                      let citationCount = entry["citationCount"] as? Int,
                      let timestampString = entry["timestamp"] as? String else {
                    continue
                }
                
                // 解析时间戳
                let formatter = ISO8601DateFormatter()
                guard let timestamp = formatter.date(from: timestampString) else {
                    continue
                }
                
                // 创建学者对象
                var scholar = Scholar(id: scholarId, name: scholarName)
                scholar.citations = citationCount
                scholar.lastUpdated = timestamp
                
                // 避免重复添加学者
                if !scholars.contains(where: { $0.id == scholarId }) {
                    scholars.append(scholar)
                }
                
                // 创建历史记录
                let history = CitationHistory(
                    scholarId: scholarId,
                    citationCount: citationCount,
                    timestamp: timestamp
                )
                historyEntries.append(history)
            }
            
            // 导入学者数据
            for scholar in scholars {
                dataManager.addScholar(scholar)
            }
            
            // 导入历史数据
            dataManager.importHistoryData(historyEntries)
            
            print("✅ [AppInitialization] 成功导入 \(scholars.count) 个学者和 \(historyEntries.count) 条历史记录")
            
        } catch {
            print("❌ [AppInitialization] 导入初始化数据失败: \(error)")
            // 不抛出错误，继续执行
        }
    }
    
    // MARK: - 学者数据更新
    
    private func updateAllScholars() async {
        await MainActor.run {
            initializationProgress = "更新学者数据..."
        }
        
        let scholars = dataManager.scholars
        guard !scholars.isEmpty else {
            print("ℹ️ [AppInitialization] 没有学者需要更新")
            return
        }
        
        print("🔄 [AppInitialization] 开始更新 \(scholars.count) 个学者的数据")
        
        var successCount = 0
        
        for scholar in scholars {
            await MainActor.run {
                initializationProgress = "更新学者: \(scholar.name)..."
            }
            
            // 使用GoogleScholarService更新学者数据
            let result = await withCheckedContinuation { continuation in
                googleScholarService.fetchScholarInfo(for: scholar.id) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch result {
            case .success(let (name, citations)):
                // 更新学者信息
                var updatedScholar = scholar
                updatedScholar.name = name
                updatedScholar.citations = citations
                updatedScholar.lastUpdated = Date()
                
                // 在主线程更新数据管理器
                await MainActor.run {
                    dataManager.updateScholar(updatedScholar)
                    
                    // 添加引用历史记录
                    let history = CitationHistory(scholarId: scholar.id, citationCount: citations)
                    dataManager.addHistory(history)
                }
                
                successCount += 1
                print("✅ [AppInitialization] 更新学者成功: \(name) - \(citations)引用")
                
            case .failure(let error):
                print("❌ [AppInitialization] 更新学者失败: \(scholar.name) - \(error)")
            }
            
            // 添加延迟以避免请求过于频繁
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒延迟
        }
        
        print("✅ [AppInitialization] 成功更新 \(successCount)/\(scholars.count) 个学者")
    }
    
    // MARK: - 完成初始化
    
    private func markInitializationComplete() async {
        await MainActor.run {
            initializationProgress = "完成初始化..."
        }
        
        UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        isFirstLaunch = false
        
        print("✅ [AppInitialization] 初始化标记完成")
    }
}

