import Foundation

// MARK: - Scholar Info Extraction
/// 从 Google Scholar 主页 HTML 中提取学者的完整信息
extension CitationFetchService {
    
    /// 从 HTML 中提取学者的完整信息
    /// - Parameter html: Google Scholar 学者主页的 HTML
    /// - Returns: 学者的完整信息，如果解析失败返回 nil
    func extractScholarFullInfo(from html: String) -> ScholarFullInfo? {
        let name = extractScholarName(from: html)
        let citations = extractTotalCitations(from: html)
        let hIndex = extractHIndex(from: html)
        let i10Index = extractI10Index(from: html)
        
        // 至少需要名字
        guard !name.isEmpty else {
            return nil
        }
        
        return ScholarFullInfo(
            name: name,
            totalCitations: citations ?? 0,
            hIndex: hIndex,
            i10Index: i10Index
        )
    }
    
    /// 提取学者姓名
    private func extractScholarName(from html: String) -> String {
        let patterns = [
            #"<div id="gsc_prf_in">([^<]+)</div>"#,
            #"<div class="gsc_prf_in">([^<]+)</div>"#,
        ]
        
        for pattern in patterns {
            if let name = extractFirstMatch(from: html, pattern: pattern) {
                return name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
        }
        
        return ""
    }
    
    /// 提取总引用数
    private func extractTotalCitations(from html: String) -> Int? {
        // 引用统计表格的结构：
        // <table id="gsc_rsb_st">
        //   <tr>
        //     <td>Citations</td>
        //     <td>All</td>
        //     <td>Since 2020</td>
        //   </tr>
        //   <tr>
        //     <td>All</td>
        //     <td class="gsc_rsb_std">12345</td>  <- 这是总引用数
        //     ...
        //   </tr>
        // </table>
        
        // 查找第一个 gsc_rsb_std 单元格（通常是总引用数）
        let pattern = #"<td[^>]*class="gsc_rsb_std"[^>]*>(\d+)</td>"#
        guard let citationStr = extractFirstMatch(from: html, pattern: pattern),
              let citations = Int(citationStr) else {
            return nil
        }
        
        return citations
    }
    
    /// 提取 h-index
    private func extractHIndex(from html: String) -> Int? {
        // h-index 通常在第3行第2列
        // 需要找到包含 "h-index" 的行，然后获取对应的数值
        
        // 简化方法：提取所有 gsc_rsb_std 单元格，h-index 通常是第3个
        let pattern = #"<td[^>]*class="gsc_rsb_std"[^>]*>(\d+)</td>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // h-index 通常是第3个匹配（索引2）
        guard matches.count >= 3 else {
            return nil
        }
        
        let match = matches[2]
        guard match.numberOfRanges > 1 else {
            return nil
        }
        
        let valueRange = match.range(at: 1)
        let valueString = nsString.substring(with: valueRange)
        
        return Int(valueString)
    }
    
    /// 提取 i10-index
    private func extractI10Index(from html: String) -> Int? {
        // i10-index 通常在第4行第2列
        
        let pattern = #"<td[^>]*class="gsc_rsb_std"[^>]*>(\d+)</td>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // i10-index 通常是第4个匹配（索引3）
        guard matches.count >= 4 else {
            return nil
        }
        
        let match = matches[3]
        guard match.numberOfRanges > 1 else {
            return nil
        }
        
        let valueRange = match.range(at: 1)
        let valueString = nsString.substring(with: valueRange)
        
        return Int(valueString)
    }
}

// MARK: - Scholar Full Info Model
/// 从 Google Scholar 主页提取的学者完整信息
public struct ScholarFullInfo {
    public let name: String
    public let totalCitations: Int
    public let hIndex: Int?
    public let i10Index: Int?
    
    public init(name: String, totalCitations: Int, hIndex: Int?, i10Index: Int?) {
        self.name = name
        self.totalCitations = totalCitations
        self.hIndex = hIndex
        self.i10Index = i10Index
    }
}

