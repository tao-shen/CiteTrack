import Foundation

// MARK: - String Extensions
public extension String {
    
    // MARK: - Validation
    
    var isValidScholarId: Bool {
        // Google Scholar ID 通常是字母数字组合，长度在8-20个字符之间
        let pattern = "^[a-zA-Z0-9_-]{8,20}$"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: self)
    }
    
    var isValidEmail: Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: self)
    }
    
    var isValidURL: Bool {
        return URL(string: self) != nil
    }
    
    var isNotEmpty: Bool {
        return !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Text Processing
    
    func truncated(to length: Int, trailing: String = "...") -> String {
        guard self.count > length else { return self }
        return String(self.prefix(length)) + trailing
    }
    
    func trimmed() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func normalized() -> String {
        return trimmed().lowercased()
    }
    
    // MARK: - Citation Count Formatting
    
    static func formatCitationCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000.0)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }
    
    // MARK: - Scholar Name Processing
    
    func normalizedScholarName() -> String {
        // 移除特殊字符，保留字母、数字、空格和常见符号
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: ".-_"))
        let filtered = self.components(separatedBy: allowedCharacters.inverted).joined()
        return filtered.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func initials() -> String {
        let words = self.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return words.compactMap { $0.first }.map { String($0).uppercased() }.joined()
    }
    
    // MARK: - HTML Processing
    
    func strippingHTML() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return self
        }
        
        return attributedString.string
    }
    
    func decodingHTMLEntities() -> String {
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&nbsp;": " "
        ]
        
        var result = self
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        return result
    }
    
    // MARK: - File Name Safety
    
    func safeFileName() -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?<>|*\"")
        let components = self.components(separatedBy: invalidCharacters)
        let safe = components.joined(separator: "_")
        return safe.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Localization Support
    
    var localized: String {
        return LocalizationManager.shared.localized(self)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        let format = LocalizationManager.shared.localized(self)
        return String(format: format, arguments: arguments)
    }
    
    // MARK: - Color from String
    
    var hashColor: String {
        var hash: UInt32 = 0
        for char in self.utf8 {
            hash = hash &* 31 &+ UInt32(char)
        }
        
        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F"]
        return colors[Int(hash) % colors.count]
    }
    
    // MARK: - Search and Filtering
    
    func fuzzyMatch(_ query: String) -> Bool {
        let normalizedSelf = self.lowercased().replacingOccurrences(of: " ", with: "")
        let normalizedQuery = query.lowercased().replacingOccurrences(of: " ", with: "")
        
        if normalizedSelf.contains(normalizedQuery) {
            return true
        }
        
        // 检查首字母匹配
        let selfInitials = self.components(separatedBy: .whitespaces).compactMap { $0.first?.lowercased() }.joined()
        return selfInitials.contains(normalizedQuery)
    }
}

// MARK: - Attributed String Extensions
public extension NSAttributedString {
    
    convenience init(htmlString: String, font: String = "system", size: CGFloat = 14) {
        let html = """
        <style>
        body { font-family: \(font); font-size: \(size)px; }
        </style>
        \(htmlString)
        """
        
        guard let data = html.data(using: .utf8),
              let attributedString = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
              ) else {
            self.init(string: htmlString)
            return
        }
        
        self.init(attributedString: attributedString)
    }
}

// MARK: - Number Formatting Extensions
public extension Int {
    
    var citationDisplay: String {
        return String.formatCitationCount(self)
    }
    
    var ordinalString: String {
        let suffix: String
        let ones = self % 10
        let tens = (self / 10) % 10
        
        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        
        return "\(self)\(suffix)"
    }
}

public extension Double {
    
    var citationDisplay: String {
        return String.formatCitationCount(Int(self))
    }
    
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    var percentageString: String {
        return String(format: "%.1f%%", self * 100)
    }
}