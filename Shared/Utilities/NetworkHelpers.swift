import Foundation
import Network
import Combine

// MARK: - Network Monitor
public class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()
    
    @Published public var isConnected: Bool = false
    @Published public var connectionType: ConnectionType = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    public enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.updateConnectionType(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func stopMonitoring() {
        monitor.cancel()
    }
    
    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
}

// MARK: - Network Request Helper
public class NetworkHelper {
    public static let shared = NetworkHelper()
    
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.allowsCellularAccess = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        // 添加用户代理
        config.httpAdditionalHeaders = [
            "User-Agent": "CiteTrack/2.0 (iOS; Scholar Citation Tracker)"
        ]
        
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Generic Request Methods
    
    public func request<T: Codable>(
        url: URL,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        headers: [String: String]? = nil,
        responseType: T.Type
    ) -> AnyPublisher<T, NetworkError> {
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        // 添加头部信息
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw NetworkError.httpError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: responseType, decoder: decoder)
            .mapError { error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                } else if error is DecodingError {
                    return NetworkError.decodingError
                } else {
                    return NetworkError.unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    public func downloadData(from url: URL) -> AnyPublisher<Data, NetworkError> {
        return session.dataTaskPublisher(for: url)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw NetworkError.httpError(httpResponse.statusCode)
                }
                
                return data
            }
            .mapError { error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                } else {
                    return NetworkError.unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Scholar-specific Methods
    
    public func fetchScholarHTML(scholarId: String) -> AnyPublisher<String, NetworkError> {
        guard let url = URL(string: "https://scholar.google.com/citations?user=\(scholarId)&hl=en") else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> String in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                if httpResponse.statusCode == 429 {
                    throw NetworkError.rateLimited
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw NetworkError.httpError(httpResponse.statusCode)
                }
                
                guard let htmlString = String(data: data, encoding: .utf8) else {
                    throw NetworkError.invalidData
                }
                
                return htmlString
            }
            .mapError { error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                } else {
                    return NetworkError.unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Retry Logic
    
    public func requestWithRetry<T: Codable>(
        url: URL,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        headers: [String: String]? = nil,
        responseType: T.Type,
        maxRetries: Int = 3
    ) -> AnyPublisher<T, NetworkError> {
        
        return request(url: url, method: method, body: body, headers: headers, responseType: responseType)
            .retry(maxRetries)
            .eraseToAnyPublisher()
    }
}

// MARK: - HTTP Method
public enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - Network Error
public enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData
    case httpError(Int)
    case rateLimited
    case decodingError
    case noInternetConnection
    case timeout
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .invalidData:
            return "无效的数据"
        case .httpError(let code):
            return "HTTP错误: \(code)"
        case .rateLimited:
            return "请求过于频繁，请稍后再试"
        case .decodingError:
            return "数据解析失败"
        case .noInternetConnection:
            return "无网络连接"
        case .timeout:
            return "请求超时"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .rateLimited:
            return "请等待几分钟后重试"
        case .noInternetConnection:
            return "请检查网络连接"
        case .timeout:
            return "请检查网络连接并重试"
        case .httpError(let code) where code >= 500:
            return "服务器错误，请稍后重试"
        case .httpError(404):
            return "请检查学者ID是否正确"
        default:
            return "请重试或联系技术支持"
        }
    }
}

// MARK: - Request Builder
public class RequestBuilder {
    private var url: URL?
    private var method: HTTPMethod = .GET
    private var headers: [String: String] = [:]
    private var body: Data?
    
    public init() {}
    
    public func url(_ url: URL) -> RequestBuilder {
        self.url = url
        return self
    }
    
    public func method(_ method: HTTPMethod) -> RequestBuilder {
        self.method = method
        return self
    }
    
    public func header(_ key: String, _ value: String) -> RequestBuilder {
        headers[key] = value
        return self
    }
    
    public func body<T: Codable>(_ object: T) -> RequestBuilder {
        let encoder = JSONEncoder()
        self.body = try? encoder.encode(object)
        header("Content-Type", "application/json")
        return self
    }
    
    public func bodyData(_ data: Data) -> RequestBuilder {
        self.body = data
        return self
    }
    
    public func build() throws -> URLRequest {
        guard let url = url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return request
    }
}