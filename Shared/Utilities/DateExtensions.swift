import Foundation

// MARK: - Date Extensions
public extension Date {
    
    // MARK: - Display Formatting
    
    var displayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    var shortDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: self)
    }
    
    var timeAgoString: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)
        
        // 使用本地化字符串
        let localizationManager = LocalizationManager.shared
        
        if interval < 60 {
            return localizationManager.localized("just_now")
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) " + localizationManager.localized("minutes_ago")
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) " + localizationManager.localized("hours_ago")
        } else if interval < 86400 * 7 {
            let days = Int(interval / 86400)
            return "\(days) " + localizationManager.localized("days_ago")
        } else {
            return shortDisplayString
        }
    }
    
    // MARK: - Calendar Operations
    
    func startOfDay() -> Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    func endOfDay() -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay()) ?? self
    }
    
    func startOfWeek() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
    
    func startOfYear() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self)
        return calendar.date(from: components) ?? self
    }
    
    // MARK: - Date Ranges
    
    func adding(days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    func adding(weeks: Int) -> Date {
        return Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: self) ?? self
    }
    
    func adding(months: Int) -> Date {
        return Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    func adding(years: Int) -> Date {
        return Calendar.current.date(byAdding: .year, value: years, to: self) ?? self
    }
    
    // MARK: - Predefined Date Ranges
    
    static func dateRange(for period: DatePeriod) -> (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        
        switch period {
        case .lastWeek:
            let start = now.adding(days: -7).startOfDay()
            return (start: start, end: now)
            
        case .lastMonth:
            let start = now.adding(months: -1).startOfDay()
            return (start: start, end: now)
            
        case .last3Months:
            let start = now.adding(months: -3).startOfDay()
            return (start: start, end: now)
            
        case .last6Months:
            let start = now.adding(months: -6).startOfDay()
            return (start: start, end: now)
            
        case .lastYear:
            let start = now.adding(years: -1).startOfDay()
            return (start: start, end: now)
            
        case .thisWeek:
            let start = now.startOfWeek()
            return (start: start, end: now)
            
        case .thisMonth:
            let start = now.startOfMonth()
            return (start: start, end: now)
            
        case .thisYear:
            let start = now.startOfYear()
            return (start: start, end: now)
            
        case .allTime:
            // 使用一个很早的日期作为开始
            let start = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? now.adding(years: -20)
            return (start: start, end: now)
        }
    }
    
    // MARK: - Comparison
    
    func isSameDay(as date: Date) -> Bool {
        return Calendar.current.isDate(self, inSameDayAs: date)
    }
    
    func isSameWeek(as date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, equalTo: date, toGranularity: .weekOfYear)
    }
    
    func isSameMonth(as date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, equalTo: date, toGranularity: .month)
    }
    
    func isSameYear(as date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, equalTo: date, toGranularity: .year)
    }
}

// MARK: - Date Period Enum
public enum DatePeriod: String, CaseIterable {
    case lastWeek = "lastWeek"
    case lastMonth = "lastMonth"
    case last3Months = "last3Months"
    case last6Months = "last6Months"
    case lastYear = "lastYear"
    case thisWeek = "thisWeek"
    case thisMonth = "thisMonth"
    case thisYear = "thisYear"
    case allTime = "allTime"
    
    public var displayName: String {
        let localizationManager = LocalizationManager.shared
        
        switch self {
        case .lastWeek:
            return localizationManager.localized("past_week")
        case .lastMonth:
            return localizationManager.localized("past_month")
        case .last3Months:
            return localizationManager.localized("past_3_months")
        case .last6Months:
            return localizationManager.localized("past_6_months")
        case .lastYear:
            return localizationManager.localized("past_year")
        case .thisWeek:
            return localizationManager.localized("this_week")
        case .thisMonth:
            return localizationManager.localized("this_month")
        case .thisYear:
            return localizationManager.localized("this_year")
        case .allTime:
            return localizationManager.localized("all_time")
        }
    }
    
    public var localizedKey: String {
        switch self {
        case .lastWeek:
            return "1week"
        case .lastMonth:
            return "1month"
        case .last3Months:
            return "3months"
        case .last6Months:
            return "6months"
        case .lastYear:
            return "1year"
        case .thisWeek:
            return "this_week"
        case .thisMonth:
            return "this_month"
        case .thisYear:
            return "this_year"
        case .allTime:
            return "all_time"
        }
    }
}

// MARK: - Date Formatter Helpers
public extension DateFormatter {
    
    static let display: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    static let chartAxis: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }()
    
    static let export: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}