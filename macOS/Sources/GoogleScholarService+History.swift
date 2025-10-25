import Foundation

// MARK: - Google Scholar Service Extensions for Historical Data
extension GoogleScholarService {
    
    // MARK: - Automatic Data Collection
    
    /// Fetch citation info and automatically save to history
    func fetchAndSaveScholarInfo(for scholarId: String, completion: @escaping (Result<(name: String, citations: Int), ScholarError>) -> Void) {
        fetchScholarInfo(for: scholarId) { result in
            switch result {
            case .success(let info):
                // Check if data has changed before saving
                CitationHistoryManager.shared.saveHistoryIfChanged(scholarId: scholarId, citationCount: info.citations) { saved in
                    if saved {
                        print("✅ Citation data changed for scholar \(scholarId): \(info.citations) citations - saved to history")
                    } else {
                        print("ℹ️ Citation data unchanged for scholar \(scholarId): \(info.citations) citations - not saved")
                    }
                }
                
                completion(.success(info))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Fetch citation count and automatically save to history
    func fetchAndSaveCitationCount(for scholarId: String, completion: @escaping (Result<Int, ScholarError>) -> Void) {
        fetchAndSaveScholarInfo(for: scholarId) { result in
            switch result {
            case .success(let info):
                completion(.success(info.citations))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Batch fetch and save citation data for multiple scholars
    func fetchAndSaveMultipleScholars(_ scholars: [Scholar], completion: @escaping (Result<[String: Int], Error>) -> Void) {
        let dispatchGroup = DispatchGroup()
        var results: [String: Int] = [:]
        var errors: [Error] = []
        let resultsQueue = DispatchQueue(label: "com.citetrack.batchfetch", attributes: .concurrent)
        
        for scholar in scholars {
            dispatchGroup.enter()
            
            fetchAndSaveScholarInfo(for: scholar.id) { result in
                resultsQueue.async(flags: .barrier) {
                    switch result {
                    case .success(let info):
                        results[scholar.id] = info.citations
                    case .failure(let error):
                        errors.append(error)
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if errors.isEmpty {
                completion(.success(results))
            } else {
                // Return partial success if some scholars succeeded
                if !results.isEmpty {
                    completion(.success(results))
                } else {
                    completion(.failure(errors.first!))
                }
            }
        }
    }
    
    // MARK: - Retry Logic with Exponential Backoff
    
    /// Fetch scholar info with retry logic
    func fetchScholarInfoWithRetry(
        for scholarId: String,
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        completion: @escaping (Result<(name: String, citations: Int), ScholarError>) -> Void
    ) {
        fetchScholarInfoWithRetryInternal(
            scholarId: scholarId,
            attempt: 1,
            maxRetries: maxRetries,
            baseDelay: baseDelay,
            completion: completion
        )
    }
    
    private func fetchScholarInfoWithRetryInternal(
        scholarId: String,
        attempt: Int,
        maxRetries: Int,
        baseDelay: TimeInterval,
        completion: @escaping (Result<(name: String, citations: Int), ScholarError>) -> Void
    ) {
        fetchScholarInfo(for: scholarId) { [weak self] result in
            switch result {
            case .success(let info):
                completion(.success(info))
                
            case .failure(let error):
                // Check if we should retry
                if attempt < maxRetries && self?.shouldRetry(error: error) == true {
                    let delay = baseDelay * pow(2.0, Double(attempt - 1)) // Exponential backoff
                    
                    print("Attempt \(attempt) failed for scholar \(scholarId), retrying in \(delay) seconds...")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self?.fetchScholarInfoWithRetryInternal(
                            scholarId: scholarId,
                            attempt: attempt + 1,
                            maxRetries: maxRetries,
                            baseDelay: baseDelay,
                            completion: completion
                        )
                    }
                } else {
                    print("Failed to fetch scholar info for \(scholarId) after \(attempt) attempts: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Fetch and save scholar info with retry logic
    func fetchAndSaveScholarInfoWithRetry(
        for scholarId: String,
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        completion: @escaping (Result<(name: String, citations: Int), ScholarError>) -> Void
    ) {
        fetchScholarInfoWithRetry(
            for: scholarId,
            maxRetries: maxRetries,
            baseDelay: baseDelay
        ) { result in
            switch result {
            case .success(let info):
                // Check if data has changed before saving
                CitationHistoryManager.shared.saveHistoryIfChanged(scholarId: scholarId, citationCount: info.citations) { saved in
                    if saved {
                        print("✅ Citation data changed for scholar \(scholarId): \(info.citations) citations - saved to history (retry)")
                    } else {
                        print("ℹ️ Citation data unchanged for scholar \(scholarId): \(info.citations) citations - not saved (retry)")
                    }
                }
                
                completion(.success(info))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Error Handling Helpers
    
    private func shouldRetry(error: ScholarError) -> Bool {
        switch error {
        case .networkError:
            return true // Retry network errors
        case .noData:
            return true // Retry if no data received
        case .invalidURL:
            return false // Don't retry invalid URLs
        case .parsingError:
            return false // Don't retry parsing errors (likely permanent)
        }
    }
    
    // MARK: - Rate Limiting Support
    
    private static var lastRequestTime: Date = Date.distantPast
    private static let minimumRequestInterval: TimeInterval = 1.0 // 1 second between requests
    private static let requestQueue = DispatchQueue(label: "com.citetrack.ratelimit", qos: .utility)
    
    /// Fetch scholar info with rate limiting
    func fetchScholarInfoWithRateLimit(
        for scholarId: String,
        completion: @escaping (Result<(name: String, citations: Int), ScholarError>) -> Void
    ) {
        GoogleScholarService.requestQueue.async { [weak self] in
            let now = Date()
            let timeSinceLastRequest = now.timeIntervalSince(GoogleScholarService.lastRequestTime)
            
            if timeSinceLastRequest < GoogleScholarService.minimumRequestInterval {
                let delay = GoogleScholarService.minimumRequestInterval - timeSinceLastRequest
                Thread.sleep(forTimeInterval: delay)
            }
            
            GoogleScholarService.lastRequestTime = Date()
            
            DispatchQueue.main.async(qos: .userInitiated) {
                self?.fetchScholarInfo(for: scholarId, completion: completion)
            }
        }
    }
    
    /// Fetch and save scholar info with rate limiting and retry
    func fetchAndSaveScholarInfoSafely(
        for scholarId: String,
        completion: @escaping (Result<(name: String, citations: Int), ScholarError>) -> Void
    ) {
        fetchScholarInfoWithRateLimit(for: scholarId) { [weak self] result in
            switch result {
            case .success(let info):
                // Check if data has changed before saving
                CitationHistoryManager.shared.saveHistoryIfChanged(scholarId: scholarId, citationCount: info.citations) { saved in
                    if saved {
                        print("✅ Citation data changed for scholar \(scholarId): \(info.citations) citations - saved to history (safe)")
                    } else {
                        print("ℹ️ Citation data unchanged for scholar \(scholarId): \(info.citations) citations - not saved (safe)")
                    }
                }
                
                completion(.success(info))
                
            case .failure(let error):
                // If rate limited or network error, try with retry logic
                if self?.shouldRetry(error: error) == true {
                    self?.fetchAndSaveScholarInfoWithRetry(
                        for: scholarId,
                        maxRetries: 2,
                        baseDelay: 2.0,
                        completion: completion
                    )
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Change Detection
    
    /// Fetch citation count and detect significant changes
    func fetchAndDetectChanges(
        for scholar: Scholar,
        threshold: Int = 5,
        completion: @escaping (Result<CitationChange?, ScholarError>) -> Void
    ) {
        // Get the latest historical entry first
        CitationHistoryManager.shared.getLatestEntry(for: scholar.id) { [weak self] historyResult in
            switch historyResult {
            case .success(let latestEntry):
                // Fetch current citation count
                self?.fetchAndSaveCitationCount(for: scholar.id) { fetchResult in
                    switch fetchResult {
                    case .success(let newCount):
                        if let previous = latestEntry {
                            let change = newCount - previous.citationCount
                            let isSignificant = abs(change) >= threshold
                            
                            if change != 0 {
                                let citationChange = CitationChange(
                                    scholarId: scholar.id,
                                    scholarName: scholar.name,
                                    previousCount: previous.citationCount,
                                    newCount: newCount,
                                    change: change,
                                    timestamp: Date(),
                                    isSignificant: isSignificant
                                )
                                
                                // Send notification if significant
                                if isSignificant {
                                    NotificationManager.shared.sendNotification(for: citationChange)
                                    NotificationManager.shared.addToHistory(citationChange)
                                }
                                
                                completion(.success(citationChange))
                            } else {
                                completion(.success(nil)) // No change
                            }
                        } else {
                            // First time tracking this scholar
                            completion(.success(nil))
                        }
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                print("Failed to get latest entry for scholar \(scholar.id): \(error)")
                // Continue with fetch anyway
                self?.fetchAndSaveCitationCount(for: scholar.id) { fetchResult in
                    switch fetchResult {
                    case .success:
                        completion(.success(nil)) // No previous data to compare
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }
}

// MARK: - Background Data Collection Service
class BackgroundDataCollectionService {
    static let shared = BackgroundDataCollectionService()
    
    private var timer: Timer?
    private let googleScholarService = GoogleScholarService()
    private let preferencesManager = PreferencesManager.shared
    
    private init() {}
    
    // MARK: - Timer Management
    
    func startAutomaticCollection() {
        stopAutomaticCollection() // Stop any existing timer
        
        let interval = preferencesManager.updateInterval
        
        print("Starting automatic citation collection with interval: \(interval) seconds")
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performAutomaticCollection()
        }
        
        // Perform initial collection
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.performAutomaticCollection()
        }
    }
    
    func stopAutomaticCollection() {
        timer?.invalidate()
        timer = nil
        print("Stopped automatic citation collection")
    }
    
    func restartAutomaticCollection() {
        startAutomaticCollection()
    }
    
    // MARK: - Collection Logic
    
    private func performAutomaticCollection() {
        let scholars = preferencesManager.scholars
        guard !scholars.isEmpty else {
            print("No scholars to update")
            return
        }
        
        print("Performing automatic citation collection for \(scholars.count) scholars")
        
        googleScholarService.fetchAndSaveMultipleScholars(scholars) { result in
            switch result {
            case .success(let results):
                print("Successfully updated \(results.count) scholars")
                
                // Update PreferencesManager with new citation counts
                for (scholarId, citations) in results {
                    PreferencesManager.shared.updateScholar(withId: scholarId, citations: citations)
                }
                
                // Post notification for UI updates
                NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
                
            case .failure(let error):
                print("Failed to update scholars: \(error)")
            }
        }
    }
    
    // MARK: - Manual Collection
    
    func performManualCollection(completion: @escaping (Result<[String: Int], Error>) -> Void) {
        let scholars = preferencesManager.scholars
        guard !scholars.isEmpty else {
            completion(.failure(NSError(domain: "BackgroundDataCollectionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No scholars to update"])))
            return
        }
        
        print("Performing manual citation collection for \(scholars.count) scholars")
        
        googleScholarService.fetchAndSaveMultipleScholars(scholars) { result in
            switch result {
            case .success(let results):
                // Update PreferencesManager with new citation counts
                for (scholarId, citations) in results {
                    PreferencesManager.shared.updateScholar(withId: scholarId, citations: citations)
                }
                
                // Post notification for UI updates
                NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
                
                completion(.success(results))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}