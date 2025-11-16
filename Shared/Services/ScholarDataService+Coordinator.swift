import Foundation

/// ScholarDataService 的扩展，集成 CitationFetchCoordinator
extension ScholarDataService {
    
    /// 使用协调器获取并更新学者数据（推荐方式）
    /// 这个方法会一次性获取学者的所有可用信息并缓存
    @MainActor
    public func fetchAndUpdateScholarWithCoordinator(id: String) async throws -> Scholar {
        print("🚀 [ScholarDataService] Using coordinator to fetch scholar: \(id)")
        
        // 使用协调器进行全面获取
        await CitationFetchCoordinator.shared.fetchScholarComprehensive(
            scholarId: id,
            priority: .high
        )
        
        // 从缓存读取数据
        if let publications = CitationCacheService.shared.getCachedScholarPublicationsList(
            for: id,
            sortBy: "total",
            startIndex: 0
        ), !publications.isEmpty {
            
            // 从论文列表推断引用总数
            let totalCitations = publications.reduce(0) { $0 + ($1.citationCount ?? 0) }
            
            // 获取学者名字（从第一篇论文的作者信息中提取，或者使用已有的Scholar对象）
            let existingScholar = await dataManager.scholars.first(where: { $0.id == id })
            let name = existingScholar?.name ?? publications.first?.title ?? "Unknown"
            
            // 创建更新后的学者对象
            var updatedScholar = Scholar(id: id, name: name)
            updatedScholar.citations = totalCitations
            updatedScholar.lastUpdated = Date()
            
            // 保存到数据管理器
            await dataManager.updateScholar(updatedScholar)
            
            // 添加引用历史记录
            let history = CitationHistory(scholarId: id, citationCount: totalCitations)
            await dataManager.addCitationHistory(history)
            
            print("✅ [ScholarDataService] Updated scholar via coordinator: \(name) - \(totalCitations) citations")
            
            return updatedScholar
        } else {
            // 如果缓存没有数据，回退到传统方法
            print("⚠️ [ScholarDataService] Coordinator fetch failed, falling back to legacy method")
            return try await fetchAndUpdateScholar(id: id)
        }
    }
    
    /// 使用协调器批量更新多个学者
    @MainActor
    public func fetchAndUpdateScholarsWithCoordinator(ids: [String]) async -> [Result<Scholar, Error>] {
        var results: [Result<Scholar, Error>] = []
        
        print("🚀 [ScholarDataService] Batch updating \(ids.count) scholars with coordinator")
        
        // 为所有学者创建全面获取任务
        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask {
                    await CitationFetchCoordinator.shared.fetchScholarComprehensive(
                        scholarId: id,
                        priority: .high
                    )
                }
            }
        }
        
        // 从缓存读取所有学者数据
        for id in ids {
            do {
                if let publications = CitationCacheService.shared.getCachedScholarPublicationsList(
                    for: id,
                    sortBy: "total",
                    startIndex: 0
                ), !publications.isEmpty {
                    
                    let totalCitations = publications.reduce(0) { $0 + ($1.citationCount ?? 0) }
                    let existingScholar = await dataManager.scholars.first(where: { $0.id == id })
                    let name = existingScholar?.name ?? "Unknown"
                    
                    var updatedScholar = Scholar(id: id, name: name)
                    updatedScholar.citations = totalCitations
                    updatedScholar.lastUpdated = Date()
                    
                    await dataManager.updateScholar(updatedScholar)
                    
                    let history = CitationHistory(scholarId: id, citationCount: totalCitations)
                    await dataManager.addCitationHistory(history)
                    
                    results.append(.success(updatedScholar))
                } else {
                    // 回退到传统方法
                    let scholar = try await fetchAndUpdateScholar(id: id)
                    results.append(.success(scholar))
                }
            } catch {
                results.append(.failure(error))
            }
        }
        
        print("✅ [ScholarDataService] Batch update completed: \(results.filter { if case .success = $0 { return true } else { return false } }.count)/\(ids.count) succeeded")
        
        return results
    }
}

