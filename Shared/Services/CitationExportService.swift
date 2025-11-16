import Foundation

// MARK: - Citation Export Service
public class CitationExportService {
    public static let shared = CitationExportService()
    
    private init() {}
    
    // MARK: - Export Format
    
    public enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        case bibtex = "BibTeX"
        
        public var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .json: return "json"
            case .bibtex: return "bib"
            }
        }
        
        public var mimeType: String {
            switch self {
            case .csv: return "text/csv"
            case .json: return "application/json"
            case .bibtex: return "application/x-bibtex"
            }
        }
    }
    
    // MARK: - Export Methods
    
    /// 导出为CSV格式
    public func exportToCSV(papers: [CitingPaper]) -> Data? {
        var csvString = ""
        
        // CSV头部
        csvString += "ID,Title,Authors,Year,Venue,Citations,Abstract,Scholar URL,PDF URL\n"
        
        // 数据行
        for paper in papers {
            let row = [
                escapeCSV(paper.id),
                escapeCSV(paper.title),
                escapeCSV(paper.authors.joined(separator: "; ")),
                paper.year.map { String($0) } ?? "",
                escapeCSV(paper.venue ?? ""),
                paper.citationCount.map { String($0) } ?? "",
                escapeCSV(paper.abstract ?? ""),
                escapeCSV(paper.scholarUrl ?? ""),
                escapeCSV(paper.pdfUrl ?? "")
            ]
            csvString += row.joined(separator: ",") + "\n"
        }
        
        logSuccess("Exported \(papers.count) papers to CSV")
        return csvString.data(using: .utf8)
    }
    
    /// 导出为JSON格式
    public func exportToJSON(papers: [CitingPaper]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(papers)
            logSuccess("Exported \(papers.count) papers to JSON")
            return data
        } catch {
            logError("Failed to encode papers to JSON", error: error)
            return nil
        }
    }
    
    /// 导出为BibTeX格式
    public func exportToBibTeX(papers: [CitingPaper]) -> Data? {
        var bibtexString = ""
        
        for paper in papers {
            bibtexString += generateBibTeXEntry(for: paper)
            bibtexString += "\n\n"
        }
        
        logSuccess("Exported \(papers.count) papers to BibTeX")
        return bibtexString.data(using: .utf8)
    }
    
    // MARK: - File Name Generation
    
    /// 生成导出文件名
    public func generateFileName(for scholarId: String, format: ExportFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let sanitizedScholarId = scholarId.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
        
        return "citations_\(sanitizedScholarId)_\(dateString).\(format.fileExtension)"
    }
    
    /// 生成导出文件名（带论文数量）
    public func generateFileName(for scholarId: String, format: ExportFormat, paperCount: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let sanitizedScholarId = scholarId.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
        
        return "citations_\(sanitizedScholarId)_\(paperCount)papers_\(dateString).\(format.fileExtension)"
    }
    
    // MARK: - Private Helper Methods
    
    /// 转义CSV字段
    private func escapeCSV(_ field: String) -> String {
        var escaped = field
        
        // 如果包含逗号、引号或换行符，需要用引号包裹
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            // 转义引号
            escaped = escaped.replacingOccurrences(of: "\"", with: "\"\"")
            // 用引号包裹
            escaped = "\"\(escaped)\""
        }
        
        return escaped
    }
    
    /// 生成单个BibTeX条目
    private func generateBibTeXEntry(for paper: CitingPaper) -> String {
        var bibtex = ""
        
        // 确定条目类型（默认为article）
        let entryType = determineBibTeXType(for: paper)
        
        // 生成引用键
        let citeKey = generateCiteKey(for: paper)
        
        bibtex += "@\(entryType){\(citeKey),\n"
        
        // 标题
        bibtex += "  title = {\(escapeBibTeX(paper.title))},\n"
        
        // 作者
        if !paper.authors.isEmpty {
            let authorsString = paper.authors.joined(separator: " and ")
            bibtex += "  author = {\(escapeBibTeX(authorsString))},\n"
        }
        
        // 年份
        if let year = paper.year {
            bibtex += "  year = {\(year)},\n"
        }
        
        // 发表场所
        if let venue = paper.venue, !venue.isEmpty {
            if entryType == "article" {
                bibtex += "  journal = {\(escapeBibTeX(venue))},\n"
            } else if entryType == "inproceedings" {
                bibtex += "  booktitle = {\(escapeBibTeX(venue))},\n"
            }
        }
        
        // 摘要
        if let abstract = paper.abstract, !abstract.isEmpty {
            bibtex += "  abstract = {\(escapeBibTeX(abstract))},\n"
        }
        
        // URL
        if let url = paper.scholarUrl, !url.isEmpty {
            bibtex += "  url = {\(url)},\n"
        }
        
        // 移除最后的逗号
        if bibtex.hasSuffix(",\n") {
            bibtex.removeLast(2)
            bibtex += "\n"
        }
        
        bibtex += "}"
        
        return bibtex
    }
    
    /// 确定BibTeX条目类型
    private func determineBibTeXType(for paper: CitingPaper) -> String {
        guard let venue = paper.venue?.lowercased() else {
            return "article"
        }
        
        // 检查是否是会议论文
        let conferenceKeywords = ["conference", "proceedings", "workshop", "symposium", "meeting"]
        for keyword in conferenceKeywords {
            if venue.contains(keyword) {
                return "inproceedings"
            }
        }
        
        // 检查是否是书籍章节
        if venue.contains("book") || venue.contains("chapter") {
            return "inbook"
        }
        
        // 默认为期刊文章
        return "article"
    }
    
    /// 生成BibTeX引用键
    private func generateCiteKey(for paper: CitingPaper) -> String {
        var citeKey = ""
        
        // 使用第一作者的姓氏
        if let firstAuthor = paper.authors.first {
            let lastName = firstAuthor.components(separatedBy: " ").last ?? firstAuthor
            citeKey += lastName.lowercased().replacingOccurrences(of: "[^a-z]", with: "", options: .regularExpression)
        } else {
            citeKey += "unknown"
        }
        
        // 添加年份
        if let year = paper.year {
            citeKey += String(year)
        }
        
        // 添加标题的第一个单词
        let titleWords = paper.title.components(separatedBy: " ")
        if let firstWord = titleWords.first {
            let cleanWord = firstWord.lowercased().replacingOccurrences(of: "[^a-z]", with: "", options: .regularExpression)
            if !cleanWord.isEmpty {
                citeKey += cleanWord
            }
        }
        
        return citeKey
    }
    
    /// 转义BibTeX特殊字符
    private func escapeBibTeX(_ text: String) -> String {
        var escaped = text
        
        // BibTeX特殊字符
        let specialChars = ["&", "%", "$", "#", "_", "{", "}"]
        for char in specialChars {
            escaped = escaped.replacingOccurrences(of: char, with: "\\\(char)")
        }
        
        return escaped
    }
    
    // MARK: - Logging
    
    private func logSuccess(_ message: String) {
        print("✅ [CitationExport] \(message)")
    }
    
    private func logError(_ message: String, error: Error? = nil) {
        if let error = error {
            print("❌ [CitationExport] \(message): \(error.localizedDescription)")
        } else {
            print("❌ [CitationExport] \(message)")
        }
    }
}

// MARK: - Export Result
public struct ExportResult {
    public let data: Data
    public let fileName: String
    public let format: CitationExportService.ExportFormat
    
    public init(data: Data, fileName: String, format: CitationExportService.ExportFormat) {
        self.data = data
        self.fileName = fileName
        self.format = format
    }
}
