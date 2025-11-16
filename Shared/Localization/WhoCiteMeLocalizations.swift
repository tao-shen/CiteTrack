import Foundation

// MARK: - Who Cite Me Localizations
extension String {
    // MARK: - Tab and Navigation
    var whoCiteMeLocalizations: String {
        let localizations: [String: [String: String]] = [
            // Tab and Navigation
            "who_cite_me": [
                "en": "Who Cite Me",
                "zh-Hans": "谁引用了我"
            ],
            "citing_papers": [
                "en": "Citing Papers",
                "zh-Hans": "引用论文"
            ],
            "citing_authors": [
                "en": "Citing Authors",
                "zh-Hans": "引用作者"
            ],
            "paper_details": [
                "en": "Paper Details",
                "zh-Hans": "论文详情"
            ],
            
            // Statistics
            "total_citing_papers": [
                "en": "Total Citing Papers",
                "zh-Hans": "总引用论文数"
            ],
            "unique_authors": [
                "en": "Unique Authors",
                "zh-Hans": "唯一作者数"
            ],
            "citations_by_year": [
                "en": "Citations by Year",
                "zh-Hans": "按年份统计"
            ],
            "top_citing_authors": [
                "en": "Top Citing Authors",
                "zh-Hans": "最频繁引用作者"
            ],
            "recent_citations": [
                "en": "Recent Citations",
                "zh-Hans": "最近引用"
            ],
            "average_per_year": [
                "en": "Average per Year",
                "zh-Hans": "年均引用数"
            ],
            
            // Filter and Sort
            "filter_options": [
                "en": "Filter Options",
                "zh-Hans": "筛选选项"
            ],
            "sort_by": [
                "en": "Sort By",
                "zh-Hans": "排序方式"
            ],
            "sort_year_desc": [
                "en": "Year (Newest First)",
                "zh-Hans": "年份（最新优先）"
            ],
            "sort_year_asc": [
                "en": "Year (Oldest First)",
                "zh-Hans": "年份（最早优先）"
            ],
            "sort_citation_desc": [
                "en": "Citations (High to Low)",
                "zh-Hans": "引用数（高到低）"
            ],
            "sort_relevance": [
                "en": "Relevance",
                "zh-Hans": "相关性"
            ],
            "sort_title_asc": [
                "en": "Title (A-Z)",
                "zh-Hans": "标题（A-Z）"
            ],
            "year_range": [
                "en": "Year Range",
                "zh-Hans": "年份范围"
            ],
            "search": [
                "en": "Search",
                "zh-Hans": "搜索"
            ],
            "search_keyword": [
                "en": "Search Keyword",
                "zh-Hans": "搜索关键词"
            ],
            "author_filter": [
                "en": "Author Filter",
                "zh-Hans": "作者筛选"
            ],
            "author_name": [
                "en": "Author Name",
                "zh-Hans": "作者姓名"
            ],
            "apply": [
                "en": "Apply",
                "zh-Hans": "应用"
            ],
            "clear_filters": [
                "en": "Clear Filters",
                "zh-Hans": "清除筛选"
            ],
            
            // Paper Information
            "title": [
                "en": "Title",
                "zh-Hans": "标题"
            ],
            "authors": [
                "en": "Authors",
                "zh-Hans": "作者"
            ],
            "year": [
                "en": "Year",
                "zh-Hans": "年份"
            ],
            "venue": [
                "en": "Venue",
                "zh-Hans": "发表场所"
            ],
            "citations": [
                "en": "Citations",
                "zh-Hans": "引用数"
            ],
            "abstract": [
                "en": "Abstract",
                "zh-Hans": "摘要"
            ],
            "view_on_scholar": [
                "en": "View on Google Scholar",
                "zh-Hans": "在Google Scholar查看"
            ],
            "download_pdf": [
                "en": "Download PDF",
                "zh-Hans": "下载PDF"
            ],
            
            // Actions
            "refresh": [
                "en": "Refresh",
                "zh-Hans": "刷新"
            ],
            "export": [
                "en": "Export",
                "zh-Hans": "导出"
            ],
            "filter": [
                "en": "Filter",
                "zh-Hans": "筛选"
            ],
            "share": [
                "en": "Share",
                "zh-Hans": "分享"
            ],
            
            // Export
            "export_format": [
                "en": "Export Format",
                "zh-Hans": "导出格式"
            ],
            "export_csv": [
                "en": "Export as CSV",
                "zh-Hans": "导出为CSV"
            ],
            "export_json": [
                "en": "Export as JSON",
                "zh-Hans": "导出为JSON"
            ],
            "export_bibtex": [
                "en": "Export as BibTeX",
                "zh-Hans": "导出为BibTeX"
            ],
            
            // Status Messages
            "loading": [
                "en": "Loading...",
                "zh-Hans": "加载中..."
            ],
            "no_citations_found": [
                "en": "No citations found",
                "zh-Hans": "未找到引用"
            ],
            "no_data_available": [
                "en": "No data available",
                "zh-Hans": "暂无数据"
            ],
            "cache_expired": [
                "en": "Cache expired, refreshing...",
                "zh-Hans": "缓存已过期，正在刷新..."
            ],
            "last_updated": [
                "en": "Last Updated",
                "zh-Hans": "最后更新"
            ],
            "cached_data": [
                "en": "Cached Data",
                "zh-Hans": "缓存数据"
            ],
            
            // Error Messages
            "citation_error_invalid_url": [
                "en": "Invalid URL",
                "zh-Hans": "无效的URL"
            ],
            "citation_error_network": [
                "en": "Network Error: %@",
                "zh-Hans": "网络错误：%@"
            ],
            "citation_error_parsing": [
                "en": "Parsing Error: %@",
                "zh-Hans": "解析错误：%@"
            ],
            "citation_error_no_data": [
                "en": "No data returned",
                "zh-Hans": "未返回数据"
            ],
            "citation_error_rate_limited": [
                "en": "Rate limited. Please try again later.",
                "zh-Hans": "请求过于频繁，请稍后再试。"
            ],
            "citation_error_scholar_not_found": [
                "en": "Scholar not found",
                "zh-Hans": "未找到学者"
            ],
            "citation_error_invalid_scholar_id": [
                "en": "Invalid scholar ID",
                "zh-Hans": "无效的学者ID"
            ],
            "citation_error_timeout": [
                "en": "Request timeout",
                "zh-Hans": "请求超时"
            ],
            "citation_error_server": [
                "en": "Server Error: %d",
                "zh-Hans": "服务器错误：%d"
            ],
            
            // Recovery Suggestions
            "citation_recovery_invalid_url": [
                "en": "Please check the URL and try again",
                "zh-Hans": "请检查URL后重试"
            ],
            "citation_recovery_network": [
                "en": "Please check your internet connection",
                "zh-Hans": "请检查网络连接"
            ],
            "citation_recovery_parsing": [
                "en": "The data format may have changed. Please try again later.",
                "zh-Hans": "数据格式可能已更改，请稍后重试。"
            ],
            "citation_recovery_no_data": [
                "en": "No data was returned. Please try again.",
                "zh-Hans": "未返回数据，请重试。"
            ],
            "citation_recovery_rate_limited": [
                "en": "Please wait a few minutes before trying again",
                "zh-Hans": "请等待几分钟后再试"
            ],
            "citation_recovery_scholar_not_found": [
                "en": "Please verify the scholar ID",
                "zh-Hans": "请验证学者ID"
            ],
            "citation_recovery_invalid_scholar_id": [
                "en": "Please enter a valid scholar ID",
                "zh-Hans": "请输入有效的学者ID"
            ],
            "citation_recovery_timeout": [
                "en": "The request took too long. Please try again.",
                "zh-Hans": "请求超时，请重试。"
            ],
            "citation_recovery_server": [
                "en": "The server is experiencing issues. Please try again later.",
                "zh-Hans": "服务器出现问题，请稍后重试。"
            ],
            
            // Additional UI strings
            "no_scholars_added": [
                "en": "No Scholars Added",
                "zh-Hans": "未添加学者"
            ],
            "add_scholar_first": [
                "en": "Please add a scholar first to view citations",
                "zh-Hans": "请先添加学者以查看引用"
            ],
            "select_scholar_above": [
                "en": "Select a scholar above to view citations",
                "zh-Hans": "请在上方选择学者以查看引用"
            ],
            "cancel": [
                "en": "Cancel",
                "zh-Hans": "取消"
            ],
            "use_year_filter": [
                "en": "Use Year Filter",
                "zh-Hans": "使用年份筛选"
            ],
            "start_year": [
                "en": "Start Year",
                "zh-Hans": "起始年份"
            ],
            "end_year": [
                "en": "End Year",
                "zh-Hans": "结束年份"
            ],
            "sort_option": [
                "en": "Sort Option",
                "zh-Hans": "排序选项"
            ]
        ]
        
        let currentLanguage = LocalizationManager.shared.currentLanguage.rawValue
        return localizations[self]?[currentLanguage] ?? self
    }
}

// MARK: - String Extension for Localization
extension String {
    public var localized: String {
        // 首先尝试从Who Cite Me本地化获取
        let whoCiteMeLocalized = self.whoCiteMeLocalizations
        if whoCiteMeLocalized != self {
            return whoCiteMeLocalized
        }
        
        // 回退到默认本地化
        return LocalizationManager.shared.localized(self)
    }
}
