import Foundation
import Combine

// MARK: - Google Scholar Service
public class GoogleScholarService: ObservableObject {
    public static let shared = GoogleScholarService()
    
    // 共享的URLSession配置，包含合理的超时设置
    private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0  // 单个请求超时30秒
        config.timeoutIntervalForResource = 60.0  // 总资源获取超时60秒
        config.allowsCellularAccess = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData  // 总是获取最新数据
        return URLSession(configuration: config)
    }()
    
    public init() {}
    
    // MARK: - Error Types
    public enum ScholarError: Error, LocalizedError {
        case invalidURL
        case noData
        case parsingError
        case networkError(Error)
        case rateLimited
        case scholarNotFound
        case invalidScholarId
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的URL"
            case .noData:
                return "没有数据返回"
            case .parsingError:
                return "数据解析失败"
            case .networkError(let error):
                return "网络错误: \(error.localizedDescription)"
            case .rateLimited:
                return "请求过于频繁，请稍后再试"
            case .scholarNotFound:
                return "未找到该学者"
            case .invalidScholarId:
                return "无效的学者ID"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetch scholar information (name and citations)
    public func fetchScholarInfo(for scholarId: String, completion: @escaping (Result<(name: String, citations: Int), ScholarError>) -> Void) {
        guard !scholarId.isEmpty else {
            completion(.failure(.invalidScholarId))
            return
        }
        
        guard let url = URL(string: "https://scholar.google.com/citations?user=\(scholarId)&hl=en") else {
            completion(.failure(.invalidURL))
            return
        }
        
        print("📡 开始获取学者信息: \(scholarId)")
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        
        Self.urlSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 网络请求失败: \(error.localizedDescription)")
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let data = data else {
                    print("❌ 没有接收到数据")
                    completion(.failure(.noData))
                    return
                }
                
                // 检查HTTP状态码
                if let httpResponse = response as? HTTPURLResponse {
                    print("📊 HTTP状态码: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 429 {
                        completion(.failure(.rateLimited))
                        return
                    }
                    
                    if httpResponse.statusCode >= 400 {
                        completion(.failure(.scholarNotFound))
                        return
                    }
                }
                
                let htmlString = String(data: data, encoding: .utf8) ?? ""
                
                // 解析学者姓名和引用数
                let name = self.extractScholarName(from: htmlString)
                let citations = self.extractCitationCount(from: htmlString)
                
                if name.isEmpty {
                    print("❌ 未能解析到学者姓名")
                    completion(.failure(.scholarNotFound))
                    return
                }
                
                print("✅ 成功获取学者信息: \(name), 引用数: \(citations)")
                completion(.success((name: name, citations: citations)))
            }
        }.resume()
    }
    
    /// Fetch citation count only
    public func fetchCitationCount(for scholarId: String, completion: @escaping (Result<Int, ScholarError>) -> Void) {
        fetchScholarInfo(for: scholarId) { result in
            switch result {
            case .success(let info):
                completion(.success(info.citations))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Combine Support
    
    public func fetchScholarInfoPublisher(for scholarId: String) -> AnyPublisher<(name: String, citations: Int), ScholarError> {
        return Future { promise in
            self.fetchScholarInfo(for: scholarId) { result in
                promise(result)
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func fetchCitationCountPublisher(for scholarId: String) -> AnyPublisher<Int, ScholarError> {
        return fetchScholarInfoPublisher(for: scholarId)
            .map { $0.citations }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Parsing Methods
    
    private func extractScholarName(from html: String) -> String {
        // 尝试多种模式来提取学者姓名
        let patterns = [
            #"<div id="gsc_prf_in">([^<]+)</div>"#,
            #"<div class="gsc_prf_in">([^<]+)</div>"#,
            #"<h3[^>]*>([^<]+)</h3>"#
        ]
        
        for pattern in patterns {
            if let name = extractFirstMatch(from: html, pattern: pattern) {
                return name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return ""
    }
    
    private func extractCitationCount(from html: String) -> Int {
        // 尝试多种模式来提取引用数
        let patterns = [
            #"<td class="gsc_rsb_std">(\d+)</td>"#,
            #"<a[^>]*>(\d+)</a>"#,
            #">(\d+)<"#
        ]
        
        for pattern in patterns {
            if let citationString = extractFirstMatch(from: html, pattern: pattern),
               let count = Int(citationString) {
                return count
            }
        }
        
        return 0
    }
    
    private func extractFirstMatch(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1 else {
            return nil
        }
        
        let matchRange = match.range(at: 1)
        guard let range = Range(matchRange, in: text) else {
            return nil
        }
        
        return String(text[range])
    }
}