import Foundation
import Combine

// MARK: - Localization Manager
public class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()
    
    @Published public var currentLanguage: Language {
        didSet {
            saveLanguagePreference()
            loadLocalizations()
        }
    }
    
    private var localizations: [Language: [String: String]] = [:]
    private var isLanguageSwitching = false
    private let languageSwitchQueue = DispatchQueue(label: "com.citetrack.languageswitch", qos: .userInitiated)
    
    // MARK: - Language Enum
    
    public enum Language: String, CaseIterable {
        case english = "en"
        case chinese = "zh-Hans"
        case japanese = "ja"
        case korean = "ko"
        case spanish = "es"
        case french = "fr"
        case german = "de"
        
        public var displayName: String {
            switch self {
            case .english: return "🇺🇸 English"
            case .chinese: return "🇨🇳 简体中文"
            case .japanese: return "🇯🇵 日本語"
            case .korean: return "🇰🇷 한국어"
            case .spanish: return "🇪🇸 Español"
            case .french: return "🇫🇷 Français"
            case .german: return "🇩🇪 Deutsch"
            }
        }
        
        public var nativeName: String {
            switch self {
            case .english: return "English"
            case .chinese: return "简体中文"
            case .japanese: return "日本語"
            case .korean: return "한국어"
            case .spanish: return "Español"
            case .french: return "Français"
            case .german: return "Deutsch"
            }
        }
        
        public var code: String {
            return rawValue
        }
        
        public var flag: String {
            switch self {
            case .english: return "🇺🇸"
            case .chinese: return "🇨🇳"
            case .japanese: return "🇯🇵"
            case .korean: return "🇰🇷"
            case .spanish: return "🇪🇸"
            case .french: return "🇫🇷"
            case .german: return "🇩🇪"
            }
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage")
        var userExplicit = UserDefaults.standard.bool(forKey: "UserExplicitLanguage")
        // 一次性迁移：若曾意外保留中文为显式语言，但系统语言非中文，则回归系统语言
        if !UserDefaults.standard.bool(forKey: "LanguageMigration20250922Done") {
            let systemLangCode: String = {
                if #available(iOS 16.0, *) { return Locale.current.language.languageCode?.identifier ?? "en" }
                else { return Locale.current.languageCode ?? "en" }
            }().lowercased()
            if userExplicit,
               let saved = savedLanguage,
               let savedEnum = Language(rawValue: saved),
               !(systemLangCode.hasPrefix("zh") ? savedEnum == .chinese : true),
               !systemLangCode.hasPrefix(savedEnum.rawValue.lowercased()) {
                // 清除显式标记，后续按系统语言初始化
                userExplicit = false
                UserDefaults.standard.set(false, forKey: "UserExplicitLanguage")
            }
            UserDefaults.standard.set(true, forKey: "LanguageMigration20250922Done")
        }
        
        if userExplicit, let saved = savedLanguage, let language = Language(rawValue: saved) {
            // 用户在设置中明确选择过语言，则优先采用用户选择
            self.currentLanguage = language
        } else {
            // 默认严格跟随系统语言；无法识别时回退英文
            let systemLanguageCode: String = {
                if #available(iOS 16.0, *) {
                    return Locale.current.language.languageCode?.identifier ?? "en"
                } else {
                    return Locale.current.languageCode ?? "en"
                }
            }()
            let code = systemLanguageCode.lowercased()
            if code.hasPrefix("zh") { // zh, zh-Hans, zh-Hant, zh_CN, etc.
                self.currentLanguage = .chinese
            } else if code.hasPrefix("ja") {
                self.currentLanguage = .japanese
            } else if code.hasPrefix("ko") {
                self.currentLanguage = .korean
            } else if code.hasPrefix("es") {
                self.currentLanguage = .spanish
            } else if code.hasPrefix("fr") {
                self.currentLanguage = .french
            } else if code.hasPrefix("de") {
                self.currentLanguage = .german
            } else {
                self.currentLanguage = .english
            }
        }
        
        loadLocalizations()
    }
    
    // MARK: - Public Methods
    
    public func localized(_ key: String) -> String {
        // 优先当前语言 → 英文回退 → 返回 key
        if let value = localizations[currentLanguage]?[key] {
            return value
        }
        if let fallback = localizations[.english]?[key] {
            return fallback
        }
        return key
    }
    
    public func switchLanguage(to language: Language, completion: @escaping () -> Void = {}) {
        guard !isLanguageSwitching else {
            completion()
            return
        }
        
        isLanguageSwitching = true
        
        languageSwitchQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.currentLanguage = language
                // 标记为用户明确选择语言，避免下次因系统语言与已存语言不一致而出现混合语言
                UserDefaults.standard.set(true, forKey: "UserExplicitLanguage")
                self?.isLanguageSwitching = false
                completion()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: "SelectedLanguage")
    }
    
    private func loadLocalizations() {
        // 加载所有语言的本地化字符串
        loadEnglishLocalizations()
        loadChineseLocalizations()
        loadJapaneseLocalizations()
        loadKoreanLocalizations()
        loadSpanishLocalizations()
        loadFrenchLocalizations()
        loadGermanLocalizations()
        // 统一补充缺失键，避免个别语言未覆盖导致的显示问题
        addSupplementalKeys()
    }

    // 额外补充键：集中在此处为各语言注入新增加且可能缺失的键
    private func addSupplementalKeys() {
        // English
        var en = localizations[.english] ?? [:]
        en["sort_by"] = en["sort_by"] ?? "Sort By"
        en["icloud_backup_found"] = en["icloud_backup_found"] ?? (en["icloud_data_found"] ?? "iCloud data found")
        en["notice"] = en["notice"] ?? "Notice"
        en["app_usage"] = en["app_usage"] ?? "App Usage"
        en["its_me"] = en["its_me"] ?? "It's me"
        en["not_me"] = en["not_me"] ?? "Not me"
        en["unknown_error"] = en["unknown_error"] ?? "Unknown error"
        // File Provider settings related
        en["fp_status_title"] = en["fp_status_title"] ?? "File Provider Status"
        en["fp_status_enabled"] = en["fp_status_enabled"] ?? "Enabled - Visible in Files app"
        en["fp_status_disabled"] = en["fp_status_disabled"] ?? "Disabled"
        en["fp_integration_section"] = en["fp_integration_section"] ?? "System Integration Status"
        en["fp_integration_footer"] = en["fp_integration_footer"] ?? "File Provider Extension allows CiteTrack to appear as a separate file source in the Files app, providing deeper system integration."
        en["fp_control_section"] = en["fp_control_section"] ?? "File Provider Control"
        en["fp_control_footer"] = en["fp_control_footer"] ?? "After enabling, CiteTrack will appear as 'CiteTrack Documents' in the Files app sidebar."
        en["fp_disable_button"] = en["fp_disable_button"] ?? "Disable File Provider"
        en["fp_enable_button"] = en["fp_enable_button"] ?? "Enable File Provider"
        en["fp_export_button"] = en["fp_export_button"] ?? "Export scholar data to File Provider"
        en["fp_open_in_files_button"] = en["fp_open_in_files_button"] ?? "Open in Files app"
        en["fp_data_footer"] = en["fp_data_footer"] ?? "Export will create a .citetrack file containing all scholar data. You can access and share it from the Files app."
        en["fp_features_section"] = en["fp_features_section"] ?? "File Provider Features"
        en["fp_feature_sidebar_title"] = en["fp_feature_sidebar_title"] ?? "Sidebar Display"
        en["fp_feature_sidebar_desc"] = en["fp_feature_sidebar_desc"] ?? "Show 'CiteTrack Documents' in the Files app sidebar"
        en["fp_feature_icon_title"] = en["fp_feature_icon_title"] ?? "Custom Icon"
        en["fp_feature_icon_desc"] = en["fp_feature_icon_desc"] ?? "Use the CiteTrack app icon to identify the file source"
        en["fp_feature_export_title"] = en["fp_feature_export_title"] ?? "Data Export"
        en["fp_feature_export_desc"] = en["fp_feature_export_desc"] ?? "Export scholar data to a standard file format"
        en["fp_feature_sync_title"] = en["fp_feature_sync_title"] ?? "Cloud Sync"
        en["fp_feature_sync_desc"] = en["fp_feature_sync_desc"] ?? "Share data with the main app via App Group"
        en["fp_tech_info_section"] = en["fp_tech_info_section"] ?? "Technical Information"
        en["fp_tech_method_label"] = en["fp_tech_method_label"] ?? "Implementation Method:"
        en["fp_tech_method_value"] = en["fp_tech_method_value"] ?? "Method 2 - File Provider Extension"
        en["fp_domain_identifier_label"] = en["fp_domain_identifier_label"] ?? "Domain Identifier:"
        en["fp_app_group_label"] = en["fp_app_group_label"] ?? "App Group:"
        en["fp_system_requirements_label"] = en["fp_system_requirements_label"] ?? "System Requirements:"
        en["fp_nav_title"] = en["fp_nav_title"] ?? "File Provider Settings"
        en["fp_export_success_title"] = en["fp_export_success_title"] ?? "Export Successful"
        en["fp_export_success_message"] = en["fp_export_success_message"] ?? "Scholar data has been successfully exported to File Provider. You can view it in the Files app."
        en["fp_error_title"] = en["fp_error_title"] ?? "Error"
        en["fp_ext_title"] = en["fp_ext_title"] ?? "File Provider Extension"
        en["fp_ext_requirement"] = en["fp_ext_requirement"] ?? "This feature requires iOS 16.0 or later"
        en["fp_ext_description"] = en["fp_ext_description"] ?? "File Provider Extension provides deep system integration, allowing the app to appear as a separate file source in the Files app."
        en["fp_nav_title_compat"] = en["fp_nav_title_compat"] ?? "File Provider"
        // WelcomeConfig supplemental keys
        en["continue"] = en["continue"] ?? "Continue"
        en["privacy_disclaimer"] = en["privacy_disclaimer"] ?? "Your academic data is securely stored on your device and synced via iCloud with encryption. We value your privacy and do not collect or share your personal information."
        localizations[.english] = en

        // Chinese (Simplified)
        var zh = localizations[.chinese] ?? [:]
        zh["sort_by"] = zh["sort_by"] ?? "排序方式"
        zh["icloud_backup_found"] = zh["icloud_backup_found"] ?? (zh["icloud_data_found"] ?? "已找到iCloud数据")
        zh["notice"] = zh["notice"] ?? "通知"
        zh["app_usage"] = zh["app_usage"] ?? "应用使用"
        zh["its_me"] = zh["its_me"] ?? "是我"
        zh["not_me"] = zh["not_me"] ?? "不是我"
        zh["unknown_error"] = zh["unknown_error"] ?? "未知错误"
        // File Provider settings related (Chinese)
        zh["fp_status_title"] = zh["fp_status_title"] ?? "File Provider 状态"
        zh["fp_status_enabled"] = zh["fp_status_enabled"] ?? "已启用 - 在文件应用中可见"
        zh["fp_status_disabled"] = zh["fp_status_disabled"] ?? "未启用"
        zh["fp_integration_section"] = zh["fp_integration_section"] ?? "系统集成状态"
        zh["fp_integration_footer"] = zh["fp_integration_footer"] ?? "File Provider Extension 允许 CiteTrack 在「文件」应用中显示为独立的文件源，提供更深度的系统集成。"
        zh["fp_control_section"] = zh["fp_control_section"] ?? "File Provider 控制"
        zh["fp_control_footer"] = zh["fp_control_footer"] ?? "启用后，CiteTrack 将在「文件」应用的侧边栏中显示为 'CiteTrack Documents'。"
        zh["fp_disable_button"] = zh["fp_disable_button"] ?? "禁用 File Provider"
        zh["fp_enable_button"] = zh["fp_enable_button"] ?? "启用 File Provider"
        zh["fp_export_button"] = zh["fp_export_button"] ?? "导出学者数据到 File Provider"
        zh["fp_open_in_files_button"] = zh["fp_open_in_files_button"] ?? "在文件应用中打开"
        zh["fp_data_footer"] = zh["fp_data_footer"] ?? "导出功能将创建包含所有学者数据的 .citetrack 文件，可在文件应用中访问和分享。"
        zh["fp_features_section"] = zh["fp_features_section"] ?? "File Provider 功能特性"
        zh["fp_feature_sidebar_title"] = zh["fp_feature_sidebar_title"] ?? "侧边栏显示"
        zh["fp_feature_sidebar_desc"] = zh["fp_feature_sidebar_desc"] ?? "在文件应用侧边栏中显示 'CiteTrack Documents'"
        zh["fp_feature_icon_title"] = zh["fp_feature_icon_title"] ?? "自定义图标"
        zh["fp_feature_icon_desc"] = zh["fp_feature_icon_desc"] ?? "使用 CiteTrack 应用图标标识文件源"
        zh["fp_feature_export_title"] = zh["fp_feature_export_title"] ?? "数据导出"
        zh["fp_feature_export_desc"] = zh["fp_feature_export_desc"] ?? "将学者数据导出为标准文件格式"
        zh["fp_feature_sync_title"] = zh["fp_feature_sync_title"] ?? "云端同步"
        zh["fp_feature_sync_desc"] = zh["fp_feature_sync_desc"] ?? "通过 App Group 与主应用共享数据"
        zh["fp_tech_info_section"] = zh["fp_tech_info_section"] ?? "技术信息"
        zh["fp_tech_method_label"] = zh["fp_tech_method_label"] ?? "实现方法:"
        zh["fp_tech_method_value"] = zh["fp_tech_method_value"] ?? "方法2 - File Provider Extension"
        zh["fp_domain_identifier_label"] = zh["fp_domain_identifier_label"] ?? "域标识符:"
        zh["fp_app_group_label"] = zh["fp_app_group_label"] ?? "App Group:"
        zh["fp_system_requirements_label"] = zh["fp_system_requirements_label"] ?? "系统要求:"
        zh["fp_nav_title"] = zh["fp_nav_title"] ?? "File Provider 设置"
        zh["fp_export_success_title"] = zh["fp_export_success_title"] ?? "导出成功"
        zh["fp_export_success_message"] = zh["fp_export_success_message"] ?? "学者数据已成功导出到 File Provider。您可以在文件应用中查看。"
        zh["fp_error_title"] = zh["fp_error_title"] ?? "错误"
        zh["fp_ext_title"] = zh["fp_ext_title"] ?? "File Provider Extension"
        zh["fp_ext_requirement"] = zh["fp_ext_requirement"] ?? "此功能需要 iOS 16.0 或更高版本"
        zh["fp_ext_description"] = zh["fp_ext_description"] ?? "File Provider Extension 提供深度的系统集成，允许应用在文件应用中显示为独立的文件源。"
        zh["fp_nav_title_compat"] = zh["fp_nav_title_compat"] ?? "File Provider"
        // WelcomeConfig supplemental keys
        zh["continue"] = zh["continue"] ?? "继续"
        zh["privacy_disclaimer"] = zh["privacy_disclaimer"] ?? "您的学术数据将安全存储在本地设备上，并通过 iCloud 进行加密同步。我们重视您的隐私，不会收集或分享您的个人信息。"
        localizations[.chinese] = zh
    }
    
    private func loadEnglishLocalizations() {
        localizations[.english] = [
            // 通用
            "app_name": "CiteTrack",
            "ok": "OK",
            "cancel": "Cancel",
            "save": "Save",
            "delete": "Delete",
            "edit": "Edit",
            "add": "Add",
            "remove": "Remove",
            "close": "Close",
            "settings": "Settings",
            "about": "About",
            "help": "Help",
            "loading": "Loading...",
            "error": "Error",
            "success": "Success",
            
            // 学者相关
            "scholar": "Scholar",
            "scholars": "Scholars",
            "add_scholar": "Add Scholar",
            "scholar_id": "Scholar ID",
            "scholar_name": "Scholar Name",
            "citations": "Citations",
            "citation_count": "Citation Count",
            "last_updated": "Last Updated",
            "never_updated": "Never Updated",
            "unknown": "Unknown",
            
            // 图表相关
            "charts": "Charts",
            "chart_type": "Chart Type",
            "line_chart": "Line Chart",
            "bar_chart": "Bar Chart",
            "area_chart": "Area Chart",
            "time_range": "Time Range",
            "color_scheme": "Color Scheme",
            "show_trend_line": "Show Trend Line",
            "show_data_points": "Show Data Points",
            "show_grid": "Show Grid",
            "export_chart": "Export Chart",
            "citations_count": "%d citations",
            "chart_x_axis_date": "Date",
            "chart_y_axis_citations": "Citations",
            "no_data_to_chart": "No data to chart",
            "add_scholars_to_see_charts": "Add scholars to see charts",
            "citation_chart": "Citation Chart",
            "no_chart_data": "No chart data",
            "chart_data_will_appear": "Chart data will appear after adding scholars",
            "charts_require_ios16": "Charts require iOS 16 or later",
            "update_ios_for_charts": "Please update your iOS version to use charts",
            "no_citation_data": "No citation data",
            "period_7_days": "Last 7 Days",
            "period_30_days": "Last 30 Days",
            "period_90_days": "Last 90 Days",
            
            // 设置相关
            "general_settings": "General Settings",
            "update_interval": "Update Interval",
            "show_in_dock": "Show in Dock",
            "show_in_menu_bar": "Show in Menu Bar",
            "launch_at_login": "Launch at Login",
            "notifications": "Notifications",
            "auto_update": "Auto Update",
            "auto_update_enabled": "Enable Auto Update",
            "auto_update_frequency": "Update Frequency",
            "next_update_time": "Next Update Time",
            "hourly": "Hourly",
            "daily": "Daily",
            "weekly": "Weekly",
            "monthly": "Monthly",
            "language": "Language",
            "theme": "Theme",
            "widget_theme": "Widget Theme",
            "light_mode": "Light Mode",
            "dark_mode": "Dark Mode",
            "system_mode": "System",
            "select_language": "Select Language",
            "app_information": "App Information",
            "version": "Version",
            "build": "Build",
            "sync_status": "Status",
            "check_sync_status": "Check Sync Status",
            "data_management": "Data Management",
            "import_from_icloud": "Import from iCloud",
            "manual_import_file": "Import data to file",
            "export_to_device": "Export data to file",
            "export_to_icloud": "Export to iCloud",
            "app_description": "CiteTrack - Academic Citation Tracker",
            "app_help": "Help scholars track and manage Google Scholar citation data",
            
            // iCloud related
            "show_in_icloud_drive": "Show in iCloud Drive",
            "sync_now": "Sync Now",
            "create_icloud_folder_alert_title": "Show Folder in iCloud Drive",
            "create_icloud_folder_alert_message": "This will create a CiteTrack folder with app icon in iCloud Drive, making it easy for you to manage imported and exported data files.",
            "create_folder_success_title": "Success",
            "create_folder_success_message": "Successfully created CiteTrack folder in iCloud Drive! Now you can see the CiteTrack folder with icon in the Files app's iCloud Drive, and all imported/exported data will be saved there.",
            "create_folder_failed_message": "Failed to create iCloud Drive folder: %@",
            "create_folder_button": "Create",
            
            // Scholar add interface
            "google_scholar_id_placeholder": "Google Scholar ID or URL",
            "scan_scholar_id": "Scan Scholar ID",
            
            // Initialization interface
            "welcome_to_citetrack": "Welcome to CiteTrack",
            "initializing_service": "Initializing academic tracking service for you...",
            "initialization_complete": "Initialization complete!",
            "imported_scholars_data": "Imported data for %d scholars",
            "real_time_data_update": "Real-time Data Updates",
            "real_time_data_description": "Automatically fetch the latest citation data for scholars",
            "trend_analysis": "Trend Analysis",
            "trend_analysis_description": "Visualize changes in academic influence",
            "smart_notifications": "Smart Notifications",
            "smart_notifications_description": "Get timely notifications for important changes",
            "icloud_sync": "iCloud Sync",
            "icloud_sync_description": "Sync seamlessly across devices via iCloud",
            // Welcome features (missing keys added)
            "smart_tracking": "Smart Tracking",
            "smart_tracking_description": "Track citations automatically with intelligent updates",
            
            // Chart related
            "no_data_available": "No data available",
            "add_scholars_first": "Please add scholars and complete a data refresh first",
            
            // Scan related
            "scan_instructions": "Aim at a line containing citations?user=",
            
            // 通知相关
            "citation_change": "Citation Change",
            "data_update_complete": "Data Update Complete",
            "sync_complete": "Sync Complete",
            
            // 错误信息
            "network_error": "Network Error",
            "parsing_error": "Parsing Error",
            "scholar_not_found": "Scholar Not Found",
            "invalid_scholar_id": "Invalid Scholar ID",
            "rate_limited": "Rate Limited",
            "fetch_failed": "Fetch Failed",
            "operation_failed": "Operation Failed",
            "import_result": "Import Result",
            "export_success": "Export Successful! Data saved to iCloud Drive CiteTrack folder.",
            "export_file_success": "File exported successfully! You can now share it with other apps.",
            "export_to_icloud_alert_title": "Export to iCloud",
            "export_to_icloud_alert_message": "This will export current data to CiteTrack folder in iCloud Drive.",
            "import_from_icloud_alert_title": "Import from iCloud",
            "import_from_icloud_alert_message": "This will import data from CiteTrack folder in iCloud Drive. Current data will be replaced.",
            
            // UI文本
            "dashboard_title": "Dashboard",
            "scholar_management": "Scholars",
            "total_citations": "Total Citations",
            "my_citations": "My Citations",
            "debug_show_refresh_frequency": "Show Refresh Frequency",
            "total_citations_with_count": "Total Citations",
            "scholar_count": "Scholar Count",
            "scholar_list": "Scholar List",
            "no_scholar_data": "No Scholar Data",
            "add_first_scholar_tip": "Add your first scholar in the \"Scholars\" tab",
            "no_scholar_data_tap_tip": "Tap the menu in the top right corner to add your first scholar",
            "getting_scholar_info": "Getting scholar information...",
            "updating_all_scholars": "Updating all scholars...",
            "updating": "Updating...",
            "update_all": "Update All",
            "pull_to_refresh_all": "Pull to refresh all scholars",
            "delete_all": "Delete All",
            "confirm": "Confirm",
            "scholar_name_placeholder": "Scholar Name (Optional)",
            "add_scholar_button": "Add Scholar",
            "edit_scholar": "Edit Scholar",
            "current_citations": "Current Citations",
            "enter_scholar_name_placeholder": "Enter Scholar Name",
            "citations_display": "Citations",
            "no_data": "No Data",
            "just_now": "Just now",
            "minutes_ago": "minutes ago",
            "hours_ago": "hours ago",
            "days_ago": "days ago",
            "update": "Update",
            "pin_to_top": "Pin",
            "unpin": "Unpin",
            "chart": "Chart",
            "citation_trend": "Citation Trend",
            "recent_week": "Recent Week",
            "recent_month": "Recent Month",
            "recent_three_months": "Recent 3 Months",
            "loading_chart_data_message": "Loading chart data...",
            "no_historical_data": "No Historical Data",
            "no_historical_data_message": "No historical data available",
            "no_citation_data_available": "No citation data available",
            "total_citations_chart": "Total Citations",
            "statistics_info": "Statistics",
            "current_citations_stat": "Current Citations",
            "recent_change": "Recent Change",
            "growth_rate": "Growth Rate",
            "data_points": "Data Points",
            "selected_data_point": "Selected Data Point",
            "date_label": "Date",
            "citations_label": "Citations",
            "recent_update": "Recent Update",
            "citation_ranking": "Citation Ranking",
            "citation_distribution": "Citation Distribution",
            "scholar_statistics": "Scholar Statistics",
            "total_scholars": "Total Scholars",
            "average_citations": "Average Citations",
            "highest_citations": "Highest Citations",
            "delete_all_scholars_title": "Delete All Scholars",
            "delete_all_scholars_message": "Are you sure you want to delete all scholars? This action cannot be undone.",
            // Delete confirmations (single/multiple)
            "delete_scholar_title": "Delete Scholar",
            "delete_scholar_message": "This will delete the scholar and all related data. Are you sure?",
            "delete_scholar_message_with_name": "This will delete scholar '%@' and all related data. Are you sure?",
            "delete_scholars_message_with_count": "This will delete %d scholars and all related data. Are you sure?",
            "trend_suffix": "Trend",
            
            // 时间范围
            "1week": "1 Week",
            "1month": "1 Month",
            "3months": "3 Months",
            "6months": "6 Months",
            "1year": "1 Year",
            "all_time": "All Time",
            "custom_range": "Custom Range",
            
            // 额外的UI字符串
            "dashboard": "Dashboard",
            "enter_scholar_id": "Enter Scholar ID",
            "scholar_id_help": "Find this in the Google Scholar profile URL",
            "scholar_information": "Scholar Information",
            "scholar_name_optional": "Scholar Name (Optional)",
            "enter_scholar_name": "Enter Scholar Name",
            "name_auto_fetch": "Name will be auto-filled if left blank",
            "validating_scholar_id": "Validating Scholar ID...",
            "scholar_found": "Scholar Found",
            "preview": "Preview",
            "how_to_find_scholar_id": "How to Find Scholar ID",
            "visit_google_scholar": "Visit Google Scholar",
            "search_for_author": "Search for the author",
            "click_author_name": "Click on the author's name",
            "copy_from_url": "Copy the ID from the URL",
            
            // Scholar模型相关
            "scholar_default_name": "Scholar",
            "test_scholar": "Test Scholar",
            
            // 时间范围
            "past_week": "Past Week",
            "past_month": "Past Month",
            "past_3_months": "Past 3 Months",
            "past_6_months": "Past 6 Months",
            "past_year": "Past Year",
            "this_week": "This Week",
            "this_month": "This Month",
            "this_quarter": "This Quarter",
            "this_year": "This Year",
            
            // Growth statistics
            "growth_statistics": "Growth Statistics",
            "weekly_growth": "Weekly Growth",
            "monthly_growth": "Monthly Growth",
            "quarterly_growth": "Quarterly Growth",
            "loading_growth_data": "Loading growth data...",
            "example_url": "Example: scholar.google.com/citations?user=XXXXXXXX",
            "invalid_scholar_id_format": "Invalid Scholar ID format",
            "rate_limited_error": "Too many requests, please try again later",
            "validation_error": "Validation error",
            "scholar_already_exists": "Scholar already exists",
            "scholar_id_empty": "Scholar ID cannot be empty",
            
            // Google Scholar Service 错误信息
            "invalid_url": "Invalid URL",
            "invalid_scholar_id_or_url": "Invalid scholar ID or URL",
            "no_data_returned": "No data returned",
            
            // 缺失的翻译键
            "import": "Import",
            "export": "Export",
            "import_from_icloud_message": "This will import data from the CiteTrack folder in iCloud Drive. Current data will be replaced.",
            "export_to_icloud_message": "This will export current data to the CiteTrack folder in iCloud Drive.",
            "current_citations_label": "Current Citations",
            "last_updated_label": "Last Updated",
            "updated_at": "Updated at",
            "citation_information": "Citation Information",
            
            // iCloud Sync Status
            "importing_from_icloud": "Importing from iCloud...",
            "import_completed": "Import completed",
            "import_failed": "Import failed",
            "exporting_to_icloud": "Exporting to iCloud...",
            "export_completed": "Export completed",
            "export_failed": "Export failed",
            "icloud_not_available": "iCloud not available",
            "last_sync": "Last sync",
            "icloud_data_found": "iCloud data found",
            "icloud_available_no_sync": "iCloud available, not synced",
            
            // iCloud Import Result
            "imported_scholars_count": "Imported",
            "imported_history_count": "history entries",
            "imported_config": "Imported app configuration",
            "no_data_to_import": "No data found to import",
            "scholars_unit": "scholars",
            "history_entries_unit": "history entries",
            
            // iCloud Error Messages
            "icloud_drive_unavailable": "iCloud Drive is unavailable. Please check your iCloud settings.",
            "invalid_icloud_url": "Invalid iCloud URL - Please ensure iCloud Drive is enabled.",
            "no_citetrack_data_in_icloud": "No CiteTrack data found in iCloud.",
            "export_failed_with_message": "Export failed",
            "import_failed_with_message": "Import failed",
            "failed_with_colon": "Failed",
            
            // Widget specific strings
            "start_tracking": "Start Tracking",
            "add_scholar_to_track": "Add Scholar to Track",
            "tap_to_open_app": "Tap to Open App",
            "academic_influence": "Academic Influence",
            "top_scholars": "Top Scholars",
            "academic_ranking": "Academic Ranking",
            "add_scholars_to_track": "Add Scholars to Track",
            "tracking_scholars": "Tracking Scholars",
            "latest_data": "Latest Data",
            "data_insights": "Data Insights",
            "select_scholar": "Select Scholar",
            "select_scholar_description": "Select a scholar to display in the widget",
            "scholar_parameter": "Scholar",
            "scholar_parameter_description": "Select the scholar to display in the small widget",
            "force_refresh_widget": "Force Refresh Widget",
            "force_refresh_description": "Force refresh widget data",
            "debug_test": "Debug Test",
            "debug_test_description": "Debug test intent",
            "refresh_data": "Refresh Data",
            "refresh_data_description": "Refresh scholar citation data",
            "switch_scholar": "Switch Scholar",
            "switch_scholar_description": "Switch to next scholar",
            "citations_unit": "citations",
            
            // Contribution Chart
            "contribution_activity": "Contribution Activity",
            "contribution_chart_description": "Shows academic activity heatmap for the last 20 weeks",
            "refresh_count_display_print": "%d refreshes",
            
            // Debug and Logging Messages
            "debug_using_public_container": "Using public universal container method, no FileProvider extension needed",
            "debug_sync_last_refresh_time": "Syncing LastRefreshTime: old=%@ -> new=%@",
            "debug_deep_link_received": "Received deep link: %@",
            "debug_invalid_url_scheme": "Invalid URL scheme: %@",
            "debug_refresh_request_received": "Received refresh request",
            "debug_switch_scholar_request_received": "Received switch scholar request",
            "debug_unsupported_deep_link": "Unsupported deep link: %@",
            "debug_widget_refresh_start": "Starting to handle refresh request",
            "debug_widget_refresh_complete": "Refresh completed, updating widgets",
            "debug_widget_switch_start": "Starting to handle scholar switch request",
            "debug_widget_switch_success": "Switched to scholar %d: %@",
            "debug_widget_insufficient_scholars": "Insufficient scholars, cannot switch",
            "debug_cellular_restricted": "Cellular data restricted (user disabled or restricted)",
            "debug_cellular_available": "Cellular data available",
            "debug_cellular_unknown": "Cellular data status unknown",
            "debug_background_refresh_scheduled": "Background refresh scheduled: %@",
            "debug_background_refresh_failed": "Failed to schedule background refresh: %@",
            "debug_batch_update_complete": "Completed updating %d/%d scholars",
            "debug_batch_update_final": "Completed updating %d/%d scholars, totalDelta=%d",
            "debug_confetti_batch_finished": "Batch finished trigger: %@",
            "debug_single_update_success": "Successfully updated scholar info: %@ - %d citations",
            "debug_single_update_failed": "Failed to get scholar info: %@",
            "debug_chart_tap": "Tapped scholar chart: %@",
            "debug_update_tap": "Preparing to update scholar: id=%@, name=%@",
            "debug_accumulate_delta": "Accumulate delta id=%@ old=%d new=%d delta=%d",
            "debug_show_icloud_drive": "Show in iCloud Drive",
            "debug_create_icloud_folder": "Creating iCloud Drive folder",
            "debug_icloud_folder_created": "iCloud Drive folder created successfully",
            "debug_icloud_folder_failed": "Failed to create iCloud Drive folder: %@",
            "debug_export_to_icloud": "Exporting to iCloud Drive",
            "debug_export_success": "Export to iCloud Drive successful",
            "debug_export_failed": "Export to iCloud Drive failed: %@",
            "debug_import_from_icloud": "Importing from iCloud Drive",
            "debug_import_success": "Import from iCloud Drive successful",
            "debug_import_failed": "Import from iCloud Drive failed: %@",
            "debug_file_url_error": "Cannot get file URL, using mock data",
            "debug_read_user_data_failed": "Failed to read user_data.json: %@, using mock data",
            "debug_chart_description": "Chart Description",
            "debug_chart_explanation": "This chart shows the historical trend of scholar citation counts. You can select different time periods (7 days, 30 days, 90 days) to view data, and switch between different scholars through the scholar selector for comparative analysis.",
            "debug_data_source": "Data source: Google Scholar, automatically updated daily",
            "debug_congratulations": "🎉 Congrats!",
            "debug_citation_growth": "Your citations increased by +%d!",
            "debug_success": "🎉 Success!",
            "debug_new_scholar_added": "You have added a new scholar, current citation count is %d.",
            // Popup texts for refresh scenarios
            "single_update_title_growth": "🎉 Congrats!",
            "single_update_desc_growth": "This scholar's citations increased by +%d",
            "single_update_title_today_growth": "🎉 Congrats!",
            "single_update_desc_today_growth": "Citations have increased by +%d today",
            "single_update_title_no_growth": "No New Citations",
            "single_update_desc_no_growth": "No citation growth today",
            "batch_update_title_growth": "🎉 Congrats!",
            "batch_update_desc_growth": "Your followed scholars' citations increased by +%d",
            "batch_update_title_no_growth": "No New Citations",
            "batch_update_desc_no_growth": "No citation growth detected this time",
            "debug_appgroup_write": "AppGroup 写入 LastRefreshTime=%@",
        ]
    }
    
    private func loadChineseLocalizations() {
        localizations[.chinese] = [
            // 通用
            "app_name": "CiteTrack",
            "ok": "确定",
            "cancel": "取消",
            "save": "保存",
            "delete": "删除",
            "edit": "编辑",
            "add": "添加",
            "remove": "移除",
            "close": "关闭",
            "settings": "设置",
            "about": "关于",
            "help": "帮助",
            "loading": "加载中...",
            "error": "错误",
            "success": "成功",
            
            // 学者相关
            "scholar": "学者",
            "scholars": "学者列表",
            "add_scholar": "添加学者",
            "scholar_id": "学者ID",
            "scholar_name": "学者姓名",
            "citations": "引用量",
            "citation_count": "引用数量",
            "last_updated": "最后更新",
            "never_updated": "从未更新",
            "unknown": "未知",
            
            // 图表相关
            "charts": "图表",
            "chart_type": "图表类型",
            "line_chart": "折线图",
            "bar_chart": "柱状图",
            "area_chart": "面积图",
            "time_range": "时间范围",
            "color_scheme": "配色方案",
            "show_trend_line": "显示趋势线",
            "show_data_points": "显示数据点",
            "show_grid": "显示网格",
            "export_chart": "导出图表",
            "citations_count": "%d 引用",
            "chart_x_axis_date": "日期",
            "chart_y_axis_citations": "引用数",
            "no_data_to_chart": "暂无数据可显示图表",
            "add_scholars_to_see_charts": "添加学者以查看图表",
            "citation_chart": "引用图表",
            "no_chart_data": "暂无图表数据",
            "chart_data_will_appear": "添加学者后，图表数据将在此显示",
            "charts_require_ios16": "图表功能需要iOS 16或更高版本",
            "update_ios_for_charts": "请更新您的iOS版本以使用图表功能",
            "no_citation_data": "暂无引用数据",
            "refresh_count_display_print": "%d 次刷新",
            
            // 设置相关
            "general_settings": "常规设置",
            "update_interval": "更新间隔",
            "show_in_dock": "在Dock中显示",
            "show_in_menu_bar": "在菜单栏显示",
            "launch_at_login": "开机启动",
            "notifications": "通知",
            "auto_update": "自动更新",
            "auto_update_enabled": "启用自动更新",
            "auto_update_frequency": "更新频率",
            "next_update_time": "下次更新时间",
            "hourly": "每小时",
            "daily": "每天",
            "weekly": "每周",
            "monthly": "每月",
            "language": "语言",
            "theme": "主题",
            "widget_theme": "小组件主题",
            "light_mode": "浅色模式",
            "dark_mode": "深色模式",
            "system_mode": "跟随系统",
            "select_language": "选择语言",
            "app_information": "应用信息",
            "version": "版本",
            "build": "构建版本",
            "sync_status": "状态",
            "check_sync_status": "检查同步状态",
            "data_management": "数据管理",
            "import_from_icloud": "从iCloud导入",
            "manual_import_file": "导入数据到文件",
            "export_to_device": "导出数据到文件",
            "export_to_icloud": "导出到iCloud",
            "app_description": "CiteTrack - 学术引用追踪助手",
            "app_help": "帮助学者追踪和管理Google Scholar引用数据",
            
            // iCloud相关
            "show_in_icloud_drive": "在iCloud Drive中显示",
            "sync_now": "立即同步",
            "create_icloud_folder_alert_title": "在iCloud Drive中显示文件夹",
            "create_icloud_folder_alert_message": "这将在iCloud Drive中创建一个带应用图标的CiteTrack文件夹，方便您管理导入导出的数据文件。",
            "create_folder_success_title": "成功",
            "create_folder_success_message": "成功在iCloud Drive中创建了CiteTrack文件夹！现在您可以在「文件」应用的iCloud Drive中看到带图标的CiteTrack文件夹，所有导入导出的数据都将保存在这里。",
            "create_folder_failed_message": "创建iCloud Drive文件夹失败: %@",
            "create_folder_button": "创建",
            
            // 学者添加界面
            "google_scholar_id_placeholder": "Google Scholar ID 或 URL",
            "scan_scholar_id": "扫描学者ID",
            
            // 初始化界面
            "welcome_to_citetrack": "欢迎使用 CiteTrack",
            "initializing_service": "正在为您初始化学术追踪服务...",
            "initialization_complete": "初始化完成！",
            "imported_scholars_data": "已导入 %d 位学者的数据",
            "real_time_data_update": "实时数据更新",
            "real_time_data_description": "自动获取学者的最新引用数据",
            "trend_analysis": "趋势分析",
            "trend_analysis_description": "可视化展示学术影响力变化",
            "smart_notifications": "智能提醒",
            "smart_notifications_description": "重要变化及时通知",
            "icloud_sync": "云端同步",
            "icloud_sync_description": "支持 iCloud 同步，多设备间数据无缝共享",
            // 欢迎页功能（补充缺失键）
            "smart_tracking": "智能跟踪",
            "smart_tracking_description": "自动跟踪学术引用并智能更新",
            
            // 图表相关
            "no_data_available": "暂无可用的数据",
            "add_scholars_first": "请先添加学者并完成一次数据刷新",
            
            // 扫描相关
            "scan_instructions": "对准包含 citations?user= 的一行",
            
            // 通知相关
            "citation_change": "引用量变化",
            "data_update_complete": "数据更新完成",
            "sync_complete": "同步完成",
            
            // 错误信息
            "network_error": "网络错误",
            "parsing_error": "解析错误",
            "scholar_not_found": "未找到学者",
            "invalid_scholar_id": "无效的学者ID",
            "fetch_failed": "获取失败",
            "operation_failed": "操作失败",
            "import_result": "导入结果",
            "export_success": "导出成功！数据已保存到iCloud Drive的CiteTrack文件夹。",
            "export_file_success": "文件导出成功！现在可以与其他应用分享。",
            "export_to_icloud_alert_title": "导出到iCloud",
            "export_to_icloud_alert_message": "这将把当前数据导出到iCloud Drive的CiteTrack文件夹。",
            "import_from_icloud_alert_title": "从iCloud导入",
            "import_from_icloud_alert_message": "这将从iCloud Drive的CiteTrack文件夹导入数据。当前数据将被替换。",
            
            // UI文本
            "dashboard_title": "仪表板",
            "scholar_management": "学者",
            "total_citations": "总引用",
            "my_citations": "我的引用量",
            "debug_show_refresh_frequency": "显示刷新频率",
            "total_citations_with_count": "我的引用量",
            "scholar_count": "学者数量",
            "scholar_list": "学者列表",
            "no_scholar_data": "暂无学者数据",
            "add_first_scholar_tip": "在\"学者\"标签页中添加您的第一个学者",
            "no_scholar_data_tap_tip": "点击右上角菜单添加您的第一个学者",
            "getting_scholar_info": "正在获取学者信息...",
            "updating_all_scholars": "正在更新所有学者信息...",
            "updating": "更新中...",
            "update_all": "更新全部",
            "pull_to_refresh_all": "下拉刷新全部学者",
            "delete_all": "删除全部",
            "confirm": "确定",
            "scholar_name_placeholder": "学者姓名（可选）",
            "add_scholar_button": "添加学者",
            "edit_scholar": "编辑学者",
            "current_citations": "当前引用数",
            "enter_scholar_name_placeholder": "请输入学者姓名",
            "citations_display": "引用",
            "no_data": "暂无数据",
            "just_now": "刚刚",
            "minutes_ago": "分钟前",
            "hours_ago": "小时前",
            "days_ago": "天前",
            "update": "更新",
            "pin_to_top": "置顶",
            "unpin": "取消置顶",
            "chart": "图表",
            "citation_trend": "引用趋势",
            "recent_week": "近一周",
            "recent_month": "近一月",
            "recent_three_months": "近三月",
            "loading_chart_data_message": "正在加载图表数据...",
            "no_historical_data": "暂无历史数据",
            "no_historical_data_message": "暂无历史数据",
            "no_citation_data_available": "暂无引用数据",
            "total_citations_chart": "总引用",
            "statistics_info": "统计信息",
            "current_citations_stat": "当前引用",
            "recent_change": "近期变化",
            "growth_rate": "增长率",
            "data_points": "数据点",
            "selected_data_point": "选中数据点",
            "date_label": "日期",
            "citations_label": "引用数",
            "recent_update": "最近更新",
            "citation_ranking": "引用排名",
            "citation_distribution": "引用分布",
            "scholar_statistics": "学者统计",
            "total_scholars": "总学者数",
            "average_citations": "平均引用",
            "highest_citations": "最高引用",
            "delete_all_scholars_title": "删除全部学者",
            "delete_all_scholars_message": "确定要删除所有学者吗？此操作不可撤销。",
            // 删除确认（单个/多个）
            "delete_scholar_title": "删除学者",
            "delete_scholar_message": "将删除该学者及其所有相关数据，是否确认？",
            "delete_scholar_message_with_name": "将删除学者%@及其所有相关数据，是否确认？",
            "delete_scholars_message_with_count": "将删除 %d 位学者及其所有相关数据，是否确认？",
            "trend_suffix": "趋势",
            
            // 时间范围
            "1week": "1周",
            "1month": "1个月",
            "3months": "3个月",
            "6months": "6个月",
            "1year": "1年",
            "all_time": "全部时间",
            "custom_range": "自定义范围",
            "period_7_days": "近7天",
            "period_30_days": "近30天",
            "period_90_days": "近90天",
            
            // 额外的UI字符串
            "dashboard": "仪表板",
            "enter_scholar_id": "输入学者ID",
            "scholar_id_help": "在Google Scholar个人资料URL中查找",
            "scholar_information": "学者信息",
            "scholar_name_optional": "学者姓名（可选）",
            "enter_scholar_name": "输入学者姓名",
            "name_auto_fetch": "如果留空，姓名将自动填写",
            "validating_scholar_id": "正在验证学者ID...",
            "scholar_found": "找到学者",
            "preview": "预览",
            "how_to_find_scholar_id": "如何查找学者ID",
            "visit_google_scholar": "访问Google Scholar",
            "search_for_author": "搜索作者",
            "click_author_name": "点击作者姓名",
            "copy_from_url": "从URL中复制ID",
            
            // Scholar模型相关
            "scholar_default_name": "学者",
            "test_scholar": "测试学者",
            
            // 时间范围
            "past_week": "过去一周",
            "past_month": "过去一个月",
            "past_3_months": "过去三个月",
            "past_6_months": "过去六个月",
            "past_year": "过去一年",
            "this_week": "本周",
            "this_month": "本月",
            "this_quarter": "本季度",
            "this_year": "今年",
            
            // Growth statistics
            "growth_statistics": "增长统计",
            "weekly_growth": "周增长",
            "monthly_growth": "月增长", 
            "quarterly_growth": "季度增长",
            "loading_growth_data": "正在加载增长数据...",
            
            "example_url": "示例: scholar.google.com/citations?user=XXXXXXXX",
            "invalid_scholar_id_format": "学者ID格式无效",
            "rate_limited_error": "请求过于频繁，请稍后再试",
            "validation_error": "验证错误",
            "scholar_already_exists": "学者已存在",
            "scholar_id_empty": "学者ID不能为空",
            
            // Google Scholar Service 错误信息
            "invalid_url": "无效的URL",
            "invalid_scholar_id_or_url": "无效的学者ID或URL",
            
            // 缺失的翻译键
            "import": "导入",
            "export": "导出",
            "import_from_icloud_message": "这将从iCloud Drive的CiteTrack文件夹导入数据。当前数据将被替换。",
            "export_to_icloud_message": "这将把当前数据导出到iCloud Drive的CiteTrack文件夹。",
            "current_citations_label": "当前引用",
            "last_updated_label": "最后更新",
            "updated_at": "更新于",
            "citation_information": "引用信息",
            "no_data_returned": "没有数据返回",
            
            // iCloud同步状态
            "importing_from_icloud": "正在从iCloud导入...",
            "import_completed": "导入完成",
            "import_failed": "导入失败",
            "exporting_to_icloud": "正在导出到iCloud...",
            "export_completed": "导出完成",
            "export_failed": "导出失败",
            "icloud_not_available": "iCloud不可用",
            "last_sync": "上次同步",
            "icloud_data_found": "已找到iCloud数据",
            "icloud_available_no_sync": "iCloud可用，未同步",
            
            // iCloud导入结果
            "imported_scholars_count": "导入了",
            "imported_history_count": "条历史记录",
            "imported_config": "导入了应用配置",
            "no_data_to_import": "没有找到可导入的数据",
            "scholars_unit": "位学者",
            "history_entries_unit": "条历史记录",
            
            // iCloud错误信息
            "icloud_drive_unavailable": "iCloud Drive不可用，请检查您的iCloud设置",
            "invalid_icloud_url": "无效的iCloud URL - 请确保iCloud Drive已启用",
            "no_citetrack_data_in_icloud": "在iCloud中未找到CiteTrack数据",
            "export_failed_with_message": "导出失败",
            "import_failed_with_message": "导入失败",
            "failed_with_colon": "失败",
            
            // Widget specific strings
            "start_tracking": "开始追踪",
            "add_scholar_to_track": "添加学者开始追踪",
            "tap_to_open_app": "轻触打开App添加学者",
            "academic_influence": "学术影响力",
            "top_scholars": "学者",
            "academic_ranking": "学术排行榜",
            "add_scholars_to_track": "添加学者开始追踪\n他们的学术影响力",
            "tracking_scholars": "追踪学者",
            "latest_data": "最新数据",
            "data_insights": "数据洞察",
            "select_scholar": "选择学者",
            "select_scholar_description": "从已添加的学者中选择要显示的学者",
            "scholar_parameter": "学者",
            "scholar_parameter_description": "选择要在小组件中显示的学者",
            "force_refresh_widget": "强制刷新小组件",
            "force_refresh_description": "强制刷新小组件数据",
            "debug_test": "调试测试",
            "debug_test_description": "调试用的测试Intent",
            "refresh_data": "刷新数据",
            "refresh_data_description": "刷新学者的引用数据",
            "switch_scholar": "切换学者",
            "switch_scholar_description": "切换到下一个学者",
            "citations_unit": "引用",
            
            // Contribution Chart
            "contribution_activity": "贡献活动",
            "contribution_chart_description": "显示最近20周的学术活动热力图",
            
            // Debug and Logging Messages
            "debug_using_public_container": "使用公共普遍性容器方法，无需FileProvider扩展",
            "debug_sync_last_refresh_time": "同步 LastRefreshTime: old=%@ -> new=%@",
            "debug_deep_link_received": "接收到深度链接: %@",
            "debug_invalid_url_scheme": "无效的URL scheme: %@",
            "debug_refresh_request_received": "收到刷新请求",
            "debug_switch_scholar_request_received": "收到切换学者请求",
            "debug_unsupported_deep_link": "不支持的深度链接: %@",
            "debug_widget_refresh_start": "开始处理刷新请求",
            "debug_widget_refresh_complete": "刷新完成，更新小组件",
            "debug_widget_switch_start": "开始处理学者切换请求",
            "debug_widget_switch_success": "切换到学者 %d: %@",
            "debug_widget_insufficient_scholars": "学者数量不足，无法切换",
            "debug_cellular_restricted": "蜂窝数据受限（用户关闭或受限）",
            "debug_cellular_available": "蜂窝数据可用",
            "debug_cellular_unknown": "蜂窝数据状态未知",
            "debug_batch_update_complete": "完成更新 %d/%d 位学者",
            "debug_batch_update_final": "完成更新 %d/%d 位学者，totalDelta=%d",
            "debug_confetti_batch_finished": "批量完成触发: %@",
            "debug_single_update_success": "成功更新学者信息: %@ - %d citations",
            "debug_single_update_failed": "获取学者信息失败: %@",
            "debug_chart_tap": "点击了学者图表: %@",
            "debug_accumulate_delta": "累积增量 id=%@ old=%d new=%d delta=%d",
            "debug_show_icloud_drive": "在iCloud Drive中显示",
            "debug_create_icloud_folder": "创建iCloud Drive文件夹",
            "debug_icloud_folder_created": "iCloud Drive文件夹创建成功",
            "debug_icloud_folder_failed": "Failed to create iCloud Drive folder: %@",
            "debug_export_to_icloud": "导出到iCloud Drive",
            "debug_export_success": "导出到iCloud Drive成功",
            "debug_export_failed": "导出到iCloud Drive失败: %@",
            "debug_import_from_icloud": "从iCloud Drive导入",
            "debug_import_success": "从iCloud Drive导入成功",
            "debug_import_failed": "从iCloud Drive导入失败: %@",
            "debug_file_url_error": "无法获取文件URL，使用模拟数据",
            "debug_read_user_data_failed": "读取user_data.json失败: %@，使用模拟数据",
            "debug_chart_description": "📊 图表说明",
            "debug_chart_explanation": "此图表显示学者引用量的历史变化趋势。您可以选择不同的时间周期（7天、30天、90天）来查看数据，并通过学者选择器切换不同的学者进行对比分析。",
            "debug_data_source": "数据来源于Google Scholar，每日自动更新",
            "debug_congratulations": "🎉 恭喜！",
            "debug_citation_growth": "你的引用量增长了 +%d！",
            "debug_success": "🎉 成功！",
            "debug_new_scholar_added": "您已添加新的学者，当前引用量为%d。",
            // 刷新场景弹窗文案
            "single_update_title_growth": "🎉 恭喜！",
            "single_update_desc_growth": "该学者引用量增长了 +%d",
            "single_update_title_today_growth": "🎉 恭喜！",
            "single_update_desc_today_growth": "今天的引用量已经增长了 +%d",
            "single_update_title_no_growth": "暂无新增引用",
            "single_update_desc_no_growth": "今天的引用量没有增长",
            "batch_update_title_growth": "🎉 恭喜！",
            "batch_update_desc_growth": "您关注的学者引用量增长了 +%d",
            "batch_update_title_no_growth": "暂无新增引用",
            "batch_update_desc_no_growth": "本次未检测到引用量增长"
        ]
    }
    
    private func loadJapaneseLocalizations() {
        localizations[.japanese] = [
            // 基础日语本地化
            "app_name": "CiteTrack",
            "ok": "OK",
            "cancel": "キャンセル",
            "save": "保存",
            "delete": "削除",
            "edit": "編集",
            "add": "追加",
            "remove": "削除",
            "close": "閉じる",
            "settings": "設定",
            "about": "について",
            "help": "ヘルプ",
            "loading": "読み込み中...",
            "error": "エラー",
            "success": "成功",
            
            // 学者相关
            "scholar": "研究者",
            "scholars": "研究者",
            "add_scholar": "研究者を追加",
            "scholar_id": "研究者ID",
            "scholar_name": "研究者名",
            "citations": "引用数",
            "citation_count": "引用数",
            "last_updated": "最終更新",
            "never_updated": "更新されていません",
            "unknown": "不明",
            
            // 图表相关
            "charts": "チャート",
            "chart_type": "チャートタイプ",
            "line_chart": "折れ線グラフ",
            "bar_chart": "棒グラフ",
            "area_chart": "エリアチャート",
            "time_range": "時間範囲",
            "color_scheme": "カラースキーム",
            "show_trend_line": "トレンドラインを表示",
            "show_data_points": "データポイントを表示",
            "show_grid": "グリッドを表示",
            "export_chart": "チャートをエクスポート",
            "citations_count": "%d 引用",
            "chart_x_axis_date": "日付",
            "chart_y_axis_citations": "引用数",
            "no_data_to_chart": "チャートに表示するデータがありません",
            "add_scholars_to_see_charts": "チャートを表示するには学者を追加してください",
            "contribution_activity": "貢献アクティビティ",
            "contribution_chart_description": "過去140日間のアクティビティパターンを表示",
            "citation_chart": "引用チャート",
            "no_chart_data": "チャートデータがありません",
            "chart_data_will_appear": "学者を追加すると、チャートデータがここに表示されます",
            "charts_require_ios16": "チャート機能にはiOS 16以上が必要です",
            "update_ios_for_charts": "チャート機能を使用するにはiOSバージョンを更新してください",
            "no_citation_data": "引用データがありません",
            
            // 设置相关
            "general_settings": "一般設定",
            "update_interval": "更新間隔",
            "show_in_dock": "Dockに表示",
            "show_in_menu_bar": "メニューバーに表示",
            "launch_at_login": "ログイン時に起動",
            "icloud_sync": "iCloud同期",
            "notifications": "通知",
            "auto_update": "自動更新",
            "auto_update_enabled": "自動更新を有効にする",
            "auto_update_frequency": "更新頻度",
            "next_update_time": "次回更新時刻",
            "hourly": "毎時",
            "daily": "毎日",
            "weekly": "毎週",
            "monthly": "毎月",
            "language": "言語",
            "theme": "テーマ",
            "widget_theme": "ウィジェットのテーマ",
            "light_mode": "ライトモード",
            "dark_mode": "ダークモード",
            "system_mode": "システム",
            "select_language": "言語を選択",
            "app_information": "アプリ情報",
            "version": "バージョン",
            "build": "ビルド",
            "sync_status": "ステータス",
            "check_sync_status": "同期ステータスを確認",
            "data_management": "データ管理",
            "import_from_icloud": "iCloudからインポート",
            "manual_import_file": "データをファイルにインポート",
            "export_to_device": "データをファイルにエクスポート",
            "export_to_icloud": "iCloudにエクスポート",
            "app_description": "CiteTrack - 学術引用追跡ツール",
            "app_help": "研究者がGoogle Scholarの引用データを追跡・管理するのを支援",
            "icloud_sync_description": "iCloudでデバイス間をシームレスに同期",
            // ようこそページ（不足キーの追加）
            "smart_tracking": "スマートトラッキング",
            "smart_tracking_description": "引用を自動で追跡し、賢く最新状態に保ちます",
            
            // 通知相关
            "citation_change": "引用数変更",
            "data_update_complete": "データ更新完了",
            "sync_complete": "同期完了",
            
            // 错误信息
            "rate_limited": "リクエストが多すぎます",
            "fetch_failed": "取得に失敗しました",
            "operation_failed": "操作に失敗しました",
            "import_result": "インポート結果",
            "export_success": "エクスポート成功！データがiCloud DriveのCiteTrackフォルダに保存されました。",
            "export_file_success": "ファイルのエクスポートが成功しました！他のアプリと共有できます。",
            "export_to_icloud_alert_title": "iCloudにエクスポート",
            "export_to_icloud_alert_message": "現在のデータをiCloud DriveのCiteTrackフォルダにエクスポートします。",
            "import_from_icloud_alert_title": "iCloudからインポート",
            "import_from_icloud_alert_message": "iCloud DriveのCiteTrackフォルダからデータをインポートします。現在のデータは置き換えられます。",
            
            // UI文本
            "dashboard_title": "ダッシュボード",
            "scholar_management": "研究者",
            "total_citations": "総引用数",
            "debug_show_refresh_frequency": "更新頻度を表示",
            "total_citations_with_count": "総引用数",
            "scholar_count": "研究者数",
            "scholar_list": "研究者リスト",
            "no_scholar_data": "研究者データがありません",
            "add_first_scholar_tip": "「研究者」タブで最初の研究者を追加してください",
            "no_scholar_data_tap_tip": "右上のメニューをタップして最初の研究者を追加してください",
            "getting_scholar_info": "研究者情報を取得中...",
            "updating_all_scholars": "すべての研究者を更新中...",
            "updating": "更新中...",
            "update_all": "すべて更新",
            "pull_to_refresh_all": "下拉刷新全部学者",
            "delete_all": "すべて削除",
            "confirm": "確認",
            "scholar_name_placeholder": "研究者名（オプション）",
            "google_scholar_id_placeholder": "Google Scholar ID",
            "add_scholar_button": "研究者を追加",
            "edit_scholar": "研究者を編集",
            "current_citations": "現在の引用数",
            "enter_scholar_name_placeholder": "研究者名を入力",
            "citations_display": "引用",
            "no_data": "データなし",
            "just_now": "今",
            "minutes_ago": "分前",
            "hours_ago": "時間前",
            "days_ago": "日前",
            "update": "更新",
            "pin_to_top": "固定",
            "unpin": "解除",
            "chart": "チャート",
            "citation_trend": "引用トレンド",
            "recent_week": "最近1週間",
            "recent_month": "最近1ヶ月",
            "recent_three_months": "最近3ヶ月",
            "loading_chart_data_message": "チャートデータを読み込み中...",
            "no_historical_data": "履歴データがありません",
            "no_historical_data_message": "履歴データがありません",
            "no_citation_data_available": "引用データがありません",
            "total_citations_chart": "総引用数",
            "statistics_info": "統計",
            "current_citations_stat": "現在の引用数",
            "recent_change": "最近の変更",
            "growth_rate": "成長率",
            "data_points": "データポイント",
            "selected_data_point": "選択されたデータポイント",
            "date_label": "日付",
            "citations_label": "引用数",
            "recent_update": "最近の更新",
            "citation_ranking": "引用ランキング",
            "citation_distribution": "引用分布",
            "scholar_statistics": "研究者統計",
            "total_scholars": "総研究者数",
            "average_citations": "平均引用数",
            "highest_citations": "最高引用数",
            "delete_all_scholars_title": "すべての研究者を削除",
            "delete_all_scholars_message": "すべての研究者を削除してもよろしいですか？この操作は元に戻せません。",
            "trend_suffix": "トレンド",
            
            // 时间范围
            "1week": "1週間",
            "1month": "1ヶ月",
            "3months": "3ヶ月",
            "6months": "6ヶ月",
            "1year": "1年",
            "all_time": "すべての時間",
            "custom_range": "カスタム範囲",
            
            // 额外的UI字符串
            "dashboard": "ダッシュボード",
            "enter_scholar_id": "研究者IDを入力",
            "scholar_id_help": "Google ScholarプロフィールURLで見つけてください",
            "scholar_information": "研究者情報",
            "scholar_name_optional": "研究者名（オプション）",
            "enter_scholar_name": "研究者名を入力",
            "name_auto_fetch": "空白のままにすると名前が自動入力されます",
            "validating_scholar_id": "研究者IDを検証中...",
            "scholar_found": "研究者が見つかりました",
            "preview": "プレビュー",
            "how_to_find_scholar_id": "研究者IDの見つけ方",
            "visit_google_scholar": "Google Scholarを訪問",
            "search_for_author": "著者を検索",
            "click_author_name": "著者名をクリック",
            "copy_from_url": "URLからIDをコピー",
            "example_url": "例: scholar.google.com/citations?user=XXXXXXXX",
            "invalid_scholar_id_format": "無効な研究者ID形式",
            "rate_limited_error": "リクエストが多すぎます。後でもう一度お試しください",
            "validation_error": "検証エラー",
            "scholar_already_exists": "研究者は既に存在します",
            "scholar_id_empty": "研究者IDは空にできません",
            
            // Scholar模型相关
            "scholar_default_name": "研究者",
            "test_scholar": "テスト研究者",
            
            // 时间范围
            "past_week": "過去1週間",
            "past_month": "過去1ヶ月",
            "past_3_months": "過去3ヶ月",
            "past_6_months": "過去6ヶ月",
            "past_year": "過去1年",
            "this_week": "今週",
            "this_month": "今月",
            "this_quarter": "今四半期",
            "this_year": "今年",
            
            // Growth statistics
            "growth_statistics": "成長統計",
            "weekly_growth": "週間成長",
            "monthly_growth": "月間成長",
            "quarterly_growth": "四半期成長",
            "trend_analysis": "トレンド分析", 
            "loading_growth_data": "成長データを読み込み中...",
            
            // Google Scholar Service 错误信息
            "invalid_url": "無効なURL",
            
            // 缺失的翻译键
            "import": "インポート",
            "export": "エクスポート",
            "import_from_icloud_message": "iCloud DriveのCiteTrackフォルダからデータをインポートします。現在のデータは置き換えられます。",
            "export_to_icloud_message": "現在のデータをiCloud DriveのCiteTrackフォルダにエクスポートします。",
            "no_data_available": "利用可能なデータなし",
            "current_citations_label": "現在の引用",
            "last_updated_label": "最終更新",
            "updated_at": "更新日時",
            "citation_information": "引用情報",
            "no_data_returned": "データが返されませんでした",
            "network_error": "ネットワークエラー",
            "scholar_not_found": "研究者が見つかりません",
            
            // iCloud 동기화 상태
            "importing_from_icloud": "iCloudからインポート中...",
            "import_completed": "インポート完了",
            "import_failed": "インポート失敗",
            "exporting_to_icloud": "iCloudにエクスポート中...",
            "export_completed": "エクスポート完了",
            "export_failed": "エクスポート失敗",
            "icloud_not_available": "iCloud利用不可",
            "last_sync": "最終同期",
            "icloud_data_found": "iCloudデータ発見",
            "icloud_available_no_sync": "iCloud利用可能、同期されていません",
            
            // iCloud 가져오기 결과
            "imported_scholars_count": "インポートしました",
            "imported_history_count": "履歴エントリ",
            "imported_config": "アプリ設定をインポートしました",
            "no_data_to_import": "インポートするデータが見つかりません",
            "scholars_unit": "名の研究者",
            "history_entries_unit": "履歴エントリ",
            
            // iCloud 오류 메시지
            "icloud_drive_unavailable": "iCloud Driveが利用できません。iCloud設定を確認してください。",
            "invalid_icloud_url": "無効なiCloud URL - iCloud Driveが有効になっていることを確認してください。",
            "no_citetrack_data_in_icloud": "iCloudでCiteTrackデータが見つかりません。",
            "export_failed_with_message": "エクスポート失敗",
            "import_failed_with_message": "インポート失敗",
            "failed_with_colon": "失敗",
            
            // Widget specific strings
            "start_tracking": "追跡開始",
            "add_scholar_to_track": "研究者を追加して追跡開始",
            "tap_to_open_app": "アプリをタップして研究者を追加",
            "academic_influence": "学術的影響力",
            "top_scholars": "研究者",
            "academic_ranking": "学術ランキング",
            "add_scholars_to_track": "研究者を追加して追跡開始\n그들의 학술적 영향력",
            "tracking_scholars": "研究者を追跡中",
            "latest_data": "最新データ",
            "data_insights": "データインサイト",
            "select_scholar": "研究者を選択",
            "select_scholar_description": "ウィジェットに表示する研究者を選択",
            "scholar_parameter": "研究者",
            "scholar_parameter_description": "小さなウィジェットに表示する研究者を選択",
            "force_refresh_widget": "ウィジェットを強制更新",
            "force_refresh_description": "ウィジェットデータを強制更新",
            "debug_test": "デバッグテスト",
            "debug_test_description": "デバッグ用テストIntent",
            "refresh_data": "データを更新",
            "refresh_data_description": "研究者の引用データを更新",
            "switch_scholar": "研究者を切り替え",
            "switch_scholar_description": "次の研究者に切り替え",
            "citations_unit": "引用"
        ]
    }
    
    private func loadKoreanLocalizations() {
        localizations[.korean] = [
            // 基础韩语本地화
            "app_name": "CiteTrack",
            "ok": "확인",
            "cancel": "취소",
            "save": "저장",
            "delete": "삭제",
            "edit": "편집",
            "add": "추가",
            "remove": "제거",
            "close": "닫기",
            "settings": "설정",
            "about": "정보",
            "help": "도움말",
            "loading": "로딩 중...",
            "error": "오류",
            "success": "성공",
            
            // 学者相关
            "scholar": "학자",
            "scholars": "학자",
            "add_scholar": "학자 추가",
            "scholar_id": "학자 ID",
            "scholar_name": "학자 이름",
            "citations": "인용수",
            "citation_count": "인용 수",
            "last_updated": "마지막 업데이트",
            "never_updated": "업데이트되지 않음",
            "unknown": "알 수 없음",
            
            // 图表相关
            "charts": "차트",
            "chart_type": "차트 유형",
            "line_chart": "선 그래프",
            "bar_chart": "막대 그래프",
            "area_chart": "영역 차트",
            "time_range": "시간 범위",
            "color_scheme": "색상 구성",
            "show_trend_line": "추세선 표시",
            "show_data_points": "데이터 포인트 표시",
            "show_grid": "그리드 표시",
            "export_chart": "차트 내보내기",
            "citations_count": "%d 인용",
            "chart_x_axis_date": "날짜",
            "chart_y_axis_citations": "인용수",
            "no_data_to_chart": "차트에 표시할 데이터가 없습니다",
            "add_scholars_to_see_charts": "차트를 보려면 학자를 추가하세요",
            "contribution_activity": "기여 활동",
            "contribution_chart_description": "지난 140일간의 활동 패턴을 보여줍니다",
            "citation_chart": "인용 차트",
            "no_chart_data": "차트 데이터가 없습니다",
            "chart_data_will_appear": "학자를 추가하면 차트 데이터가 여기에 표시됩니다",
            "charts_require_ios16": "차트 기능은 iOS 16 이상이 필요합니다",
            "update_ios_for_charts": "차트 기능을 사용하려면 iOS 버전을 업데이트하세요",
            "no_citation_data": "인용 데이터가 없습니다",
            
            // 设置相关
            "general_settings": "일반 설정",
            "update_interval": "업데이트 간격",
            "show_in_dock": "Dock에 표시",
            "show_in_menu_bar": "메뉴 바에 표시",
            "launch_at_login": "로그인 시 시작",
            "icloud_sync": "iCloud 동기화",
            "notifications": "알림",
            "auto_update": "자동 업데이트",
            "auto_update_enabled": "자동 업데이트 활성화",
            "auto_update_frequency": "업데이트 빈도",
            "next_update_time": "다음 업데이트 시간",
            "hourly": "매시간",
            "daily": "매일",
            "weekly": "매주",
            "monthly": "매월",
            "language": "언어",
            "theme": "테마",
            "widget_theme": "위젯 테마",
            "light_mode": "라이트 모드",
            "dark_mode": "다크 모드",
            "system_mode": "시스템",
            "select_language": "언어 선택",
            "app_information": "앱 정보",
            "version": "버전",
            "build": "빌드",
            "sync_status": "상태",
            "check_sync_status": "동기화 상태 확인",
            "data_management": "데이터 관리",
            "import_from_icloud": "iCloud에서 가져오기",
            "manual_import_file": "데이터를 파일로 가져오기",
            "export_to_device": "데이터를 파일로 내보내기",
            "export_to_icloud": "iCloud로 내보내기",
            "app_description": "CiteTrack - 학술 인용 추적 도구",
            "app_help": "학자들이 Google Scholar 인용 데이터를 추적하고 관리하는 것을 돕습니다",
            "icloud_sync_description": "iCloud로 기기 간 데이터를 매끄럽게 동기화",
            // 환영 페이지(누락 키 추가)
            "smart_tracking": "스마트 추적",
            "smart_tracking_description": "인용을 자동으로 추적하고 지능적으로 최신 상태로 유지",
            
            // 通知相关
            "citation_change": "인용 변경",
            "data_update_complete": "데이터 업데이트 완료",
            "sync_complete": "동기화 완료",
            
            // 错误信息
            "rate_limited": "요청이 너무 많습니다",
            "fetch_failed": "가져오기 실패",
            "operation_failed": "작업 실패",
            "import_result": "가져오기 결과",
            "export_success": "내보내기 성공! 데이터가 iCloud Drive의 CiteTrack 폴더에 저장되었습니다.",
            "export_file_success": "파일 내보내기 성공! 이제 다른 앱과 공유할 수 있습니다.",
            "export_to_icloud_alert_title": "iCloud로 내보내기",
            "export_to_icloud_alert_message": "현재 데이터를 iCloud Drive의 CiteTrack 폴더로 내보냅니다.",
            "import_from_icloud_alert_title": "iCloud에서 가져오기",
            "import_from_icloud_alert_message": "iCloud Drive의 CiteTrack 폴더에서 데이터를 가져옵니다. 현재 데이터는 교체됩니다.",
            
            // UI文本
            "dashboard_title": "대시보드",
            "scholar_management": "학자",
            "total_citations": "총 인용수",
            "debug_show_refresh_frequency": "새로고침 빈도 표시",
            "total_citations_with_count": "총 인용수",
            "scholar_count": "학자 수",
            "scholar_list": "학자 목록",
            "no_scholar_data": "학자 데이터 없음",
            "add_first_scholar_tip": "\"학자\" 탭에서 첫 번째 학자를 추가하세요",
            "no_scholar_data_tap_tip": "오른쪽 상단 메뉴를 탭하여 첫 번째 학자를 추가하세요",
            "getting_scholar_info": "학자 정보 가져오는 중...",
            "updating_all_scholars": "모든 학자 업데이트 중...",
            "updating": "업데이트 중...",
            "update_all": "모두 업데이트",
            "pull_to_refresh_all": "下拉刷新全部学者",
            "delete_all": "모두 삭제",
            "confirm": "확인",
            "scholar_name_placeholder": "학자 이름 (선택사항)",
            "google_scholar_id_placeholder": "Google Scholar ID",
            "add_scholar_button": "학자 추가",
            "edit_scholar": "학자 편집",
            "current_citations": "현재 인용수",
            "enter_scholar_name_placeholder": "학자 이름 입력",
            "citations_display": "인용",
            "no_data": "데이터 없음",
            "just_now": "방금",
            "minutes_ago": "분 전",
            "hours_ago": "시간 전",
            "days_ago": "일 전",
            "update": "업데이트",
            "pin_to_top": "固定",
            "unpin": "解除",
            "chart": "차트",
            "citation_trend": "인용 추세",
            "recent_week": "최근 1주",
            "recent_month": "최근 1개월",
            "recent_three_months": "최근 3개월",
            "loading_chart_data_message": "차트 데이터 로딩 중...",
            "no_historical_data": "과거 데이터 없음",
            "no_historical_data_message": "과거 데이터 없음",
            "no_citation_data_available": "인용 데이터 없음",
            "total_citations_chart": "총 인용수",
            "statistics_info": "통계",
            "current_citations_stat": "현재 인용수",
            "recent_change": "최근 변경",
            "growth_rate": "성장률",
            "data_points": "데이터 포인트",
            "selected_data_point": "선택된 데이터 포인트",
            "date_label": "날짜",
            "citations_label": "인용수",
            "recent_update": "최근 업데이트",
            "citation_ranking": "인용 순위",
            "citation_distribution": "인용 분포",
            "scholar_statistics": "학자 통계",
            "total_scholars": "총 학자 수",
            "average_citations": "평균 인용수",
            "highest_citations": "최고 인용수",
            "delete_all_scholars_title": "모든 학자 삭제",
            "delete_all_scholars_message": "모든 학자를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.",
            "trend_suffix": "추세",
            
            // 时间范围
            "1week": "1주",
            "1month": "1개월",
            "3months": "3개월",
            "6months": "6개월",
            "1year": "1년",
            "all_time": "전체 시간",
            "custom_range": "사용자 정의 범위",
            
            // 额外的UI字符串
            "dashboard": "대시보드",
            "enter_scholar_id": "학자 ID 입력",
            "scholar_id_help": "Google Scholar 프로필 URL에서 찾으세요",
            "scholar_information": "학자 정보",
            "scholar_name_optional": "학자 이름 (선택사항)",
            "enter_scholar_name": "학자 이름 입력",
            "name_auto_fetch": "비워두면 이름이 자동으로 채워집니다",
            "validating_scholar_id": "학자 ID 확인 중...",
            "scholar_found": "학자를 찾았습니다",
            "preview": "미리보기",
            "how_to_find_scholar_id": "학자 ID 찾는 방법",
            "visit_google_scholar": "Google Scholar 방문",
            "search_for_author": "저자 검색",
            "click_author_name": "저자 이름 클릭",
            "copy_from_url": "URL에서 ID 복사",
            "example_url": "예: scholar.google.com/citations?user=XXXXXXXX",
            "invalid_scholar_id_format": "잘못된 학자 ID 형식",
            "rate_limited_error": "요청이 너무 많습니다. 나중에 다시 시도하세요",
            "validation_error": "검증 오류",
            "scholar_already_exists": "학자가 이미 존재합니다",
            "scholar_id_empty": "학자 ID는 비워둘 수 없습니다",
            
            // Scholar模型相关
            "scholar_default_name": "학자",
            "test_scholar": "테스트 학자",
            
            // 时间范围
            "past_week": "지난 1주",
            "past_month": "지난 1개월",
            "past_3_months": "지난 3개월",
            "past_6_months": "지난 6개월",
            "past_year": "지난 1년",
            "this_week": "이번 주",
            "this_month": "이번 달",
            "this_quarter": "이번 분기",
            "this_year": "올해",
            
            // Growth statistics
            "growth_statistics": "성장 통계",
            "weekly_growth": "주간 성장",
            "monthly_growth": "월간 성장",
            "quarterly_growth": "분기별 성장",
            "trend_analysis": "동향 분석", 
            "loading_growth_data": "성장 데이터 로딩 중...",
            
            // Google Scholar Service 错误信息
            "invalid_url": "잘못된 URL",
            "invalid_scholar_id_or_url": "잘못된 학자 ID 또는 URL",
            
            // 缺失的翻译键
            "import": "가져오기",
            "export": "내보내기",
            "import_from_icloud_message": "iCloud Drive의 CiteTrack 폴더에서 데이터를 가져옵니다. 현재 데이터는 교체됩니다.",
            "export_to_icloud_message": "현재 데이터를 iCloud Drive의 CiteTrack 폴더로 내보냅니다.",
            "no_data_available": "사용 가능한 데이터 없음",
            "current_citations_label": "현재 인용",
            "last_updated_label": "마지막 업데이트",
            "updated_at": "업데이트 시간",
            "citation_information": "인용 정보",
            "no_data_returned": "데이터가 반환되지 않았습니다",
            "network_error": "네트워크 오류",
            "scholar_not_found": "학자를 찾을 수 없습니다",
            
            // iCloud 동기화 상태
            "importing_from_icloud": "iCloud에서 가져오는 중...",
            "import_completed": "가져오기 완료",
            "import_failed": "가져오기 실패",
            "exporting_to_icloud": "iCloud로 내보내는 중...",
            "export_completed": "내보내기 완료",
            "export_failed": "내보내기 실패",
            "icloud_not_available": "iCloud 사용 불가",
            "last_sync": "마지막 동기화",
            "icloud_data_found": "iCloud 데이터 발견",
            "icloud_available_no_sync": "iCloud 사용 가능, 동기화되지 않음",
            
            // iCloud 가져오기 결과
            "imported_scholars_count": "가져왔습니다",
            "imported_history_count": "개 기록",
            "imported_config": "앱 설정을 가져왔습니다",
            "no_data_to_import": "가져올 데이터가 없습니다",
            "scholars_unit": "명 학자",
            "history_entries_unit": "개 기록",
            
            // iCloud 오류 메시지
            "icloud_drive_unavailable": "iCloud Drive를 사용할 수 없습니다. iCloud 설정을 확인하세요.",
            "invalid_icloud_url": "잘못된 iCloud URL - iCloud Drive가 활성화되어 있는지 확인하세요.",
            "no_citetrack_data_in_icloud": "iCloud에서 CiteTrack 데이터를 찾을 수 없습니다.",
            "export_failed_with_message": "내보내기 실패",
            "import_failed_with_message": "가져오기 실패",
            "failed_with_colon": "실패",
            
            // Widget specific strings
            "start_tracking": "추적 시작",
            "add_scholar_to_track": "학자를 추가하여 추적 시작",
            "tap_to_open_app": "앱을 탭하여 학자 추가",
            "academic_influence": "학술적 영향력",
            "top_scholars": "학자",
            "academic_ranking": "학술 순위",
            "add_scholars_to_track": "학자를 추가하여 추적 시작\n그들의 학술적 영향력",
            "tracking_scholars": "학자 추적 중",
            "latest_data": "최신 데이터",
            "data_insights": "데이터 인사이트",
            "select_scholar": "학자 선택",
            "select_scholar_description": "위젯에 표시할 학자 선택",
            "scholar_parameter": "학자",
            "scholar_parameter_description": "작은 위젯에 표시할 학자 선택",
            "force_refresh_widget": "위젯 강제 새로고침",
            "force_refresh_description": "위젯 데이터 강제 새로고침",
            "debug_test": "디버그 테스트",
            "debug_test_description": "디버그용 테스트 Intent",
            "refresh_data": "데이터 새로고침",
            "refresh_data_description": "학자 인용 데이터 새로고침",
            "switch_scholar": "학자 전환",
            "switch_scholar_description": "다음 학자로 전환",
            "citations_unit": "인용"
        ]
    }
    
    private func loadSpanishLocalizations() {
        localizations[.spanish] = [
            // 基础西班牙语本地化
            "app_name": "CiteTrack",
            "ok": "OK",
            "cancel": "Cancelar",
            "save": "Guardar",
            "delete": "Eliminar",
            "edit": "Editar",
            "add": "Agregar",
            "remove": "Eliminar",
            "close": "Cerrar",
            "settings": "Configuración",
            "about": "Acerca de",
            "help": "Ayuda",
            "loading": "Cargando...",
            "error": "Error",
            "success": "Éxito",
            
            // 学者相关
            "scholar": "Académico",
            "scholars": "Académicos",
            "add_scholar": "Agregar Académico",
            "scholar_id": "ID del Académico",
            "scholar_name": "Nombre del Académico",
            "citations": "Citas",
            "citation_count": "Número de Citas",
            "last_updated": "Última Actualización",
            "never_updated": "Nunca Actualizado",
            "unknown": "Desconocido",
            
            // 图表相关
            "charts": "Gráficos",
            "chart_type": "Tipo de Gráfico",
            "line_chart": "Gráfico de Líneas",
            "bar_chart": "Gráfico de Barras",
            "area_chart": "Gráfico de Área",
            "time_range": "Rango de Tiempo",
            "color_scheme": "Esquema de Colores",
            "show_trend_line": "Mostrar Línea de Tendencia",
            "show_data_points": "Mostrar Puntos de Datos",
            "show_grid": "Mostrar Cuadrícula",
            "export_chart": "Exportar Gráfico",
            "citations_count": "%d citas",
            "chart_x_axis_date": "Fecha",
            "chart_y_axis_citations": "Citas",
            "no_data_to_chart": "No hay datos para mostrar en el gráfico",
            "add_scholars_to_see_charts": "Añade académicos para ver gráficos",
            "contribution_activity": "Actividad de Contribución",
            "contribution_chart_description": "Muestra el patrón de actividad de los últimos 140 días",
            "citation_chart": "Gráfico de Citas",
            "no_chart_data": "No hay datos del gráfico",
            "chart_data_will_appear": "Los datos del gráfico aparecerán después de añadir académicos",
            "charts_require_ios16": "Los gráficos requieren iOS 16 o posterior",
            "update_ios_for_charts": "Por favor actualiza tu versión de iOS para usar gráficos",
            "no_citation_data": "No hay datos de citas",
            
            // 设置相关
            "general_settings": "Configuración General",
            "update_interval": "Intervalo de Actualización",
            "show_in_dock": "Mostrar en Dock",
            "show_in_menu_bar": "Mostrar en Barra de Menú",
            "launch_at_login": "Iniciar al Iniciar Sesión",
            "icloud_sync": "Sincronización iCloud",
            "notifications": "Notificaciones",
            "auto_update": "Actualización Automática",
            "auto_update_enabled": "Habilitar Actualización Automática",
            "auto_update_frequency": "Frecuencia de Actualización",
            "next_update_time": "Próxima Actualización",
            "hourly": "Cada Hora",
            "daily": "Diario",
            "weekly": "Semanal",
            "monthly": "Mensual",
            "language": "Idioma",
            "theme": "Tema",
            "widget_theme": "Tema del Widget",
            "light_mode": "Modo Claro",
            "dark_mode": "Modo Oscuro",
            "system_mode": "Sistema",
            "select_language": "Seleccionar Idioma",
            "app_information": "Información de la Aplicación",
            "version": "Versión",
            "build": "Compilación",
            "sync_status": "Estado",
            "check_sync_status": "Verificar Estado de Sincronización",
            "data_management": "Gestión de Datos",
            "import_from_icloud": "Importar desde iCloud",
            "manual_import_file": "Importar datos a archivo",
            "export_to_device": "Exportar datos a archivo",
            "export_to_icloud": "Exportar a iCloud",
            "app_description": "CiteTrack - Herramienta de Seguimiento de Citas Académicas",
            "app_help": "Ayuda a los académicos a rastrear y gestionar datos de citas de Google Scholar",
            "icloud_sync_description": "Sincroniza sin problemas entre dispositivos vía iCloud",
            // Página de bienvenida (agregar claves faltantes)
            "smart_tracking": "Seguimiento Inteligente",
            "smart_tracking_description": "Rastreo automático de citas con actualizaciones inteligentes",
            
            // 通知相关
            "citation_change": "Cambio de Citas",
            "data_update_complete": "Actualización de Datos Completada",
            "sync_complete": "Sincronización Completada",
            
            // 错误信息
            "rate_limited": "Demasiadas Solicitudes",
            "fetch_failed": "Error al Obtener",
            "operation_failed": "Operación Fallida",
            "import_result": "Resultado de Importación",
            "export_success": "¡Exportación Exitosa! Los datos se guardaron en la carpeta CiteTrack de iCloud Drive.",
            "export_file_success": "¡Archivo exportado exitosamente! Ahora puedes compartirlo con otras aplicaciones.",
            "export_to_icloud_alert_title": "Exportar a iCloud",
            "export_to_icloud_alert_message": "Esto exportará los datos actuales a la carpeta CiteTrack en iCloud Drive.",
            "import_from_icloud_alert_title": "Importar desde iCloud",
            "import_from_icloud_alert_message": "Esto importará datos desde la carpeta CiteTrack en iCloud Drive. Los datos actuales serán reemplazados.",
            
            // UI文本
            "dashboard_title": "Panel de Control",
            "scholar_management": "Académicos",
            "total_citations": "Total de Citas",
            "debug_show_refresh_frequency": "Mostrar frecuencia de actualización",
            "total_citations_with_count": "Total de Citas",
            "scholar_count": "Número de Académicos",
            "scholar_list": "Lista de Académicos",
            "no_scholar_data": "Sin Datos de Académicos",
            "add_first_scholar_tip": "Agrega tu primer académico en la pestaña \"Académicos\"",
            "no_scholar_data_tap_tip": "Toca el menú en la esquina superior derecha para agregar tu primer académico",
            "getting_scholar_info": "Obteniendo información del académico...",
            "updating_all_scholars": "Actualizando todos los académicos...",
            "updating": "Actualizando...",
            "update_all": "Actualizar Todo",
            "pull_to_refresh_all": "下拉刷新全部学者",
            "delete_all": "Eliminar Todo",
            "confirm": "Confirmar",
            "scholar_name_placeholder": "Nombre del Académico (Opcional)",
            "google_scholar_id_placeholder": "ID de Google Scholar",
            "add_scholar_button": "Agregar Académico",
            "edit_scholar": "Editar Académico",
            "current_citations": "Citas Actuales",
            "enter_scholar_name_placeholder": "Ingresa el Nombre del Académico",
            "citations_display": "Citas",
            "no_data": "Sin Datos",
            "just_now": "Ahora mismo",
            "minutes_ago": "minutos atrás",
            "hours_ago": "horas atrás",
            "days_ago": "días atrás",
            "update": "Actualizar",
            "pin_to_top": "Fijar",
            "unpin": "Desfijar",
            "chart": "Gráfico",
            "citation_trend": "Tendencia de Citas",
            "recent_week": "Semana Reciente",
            "recent_month": "Mes Reciente",
            "recent_three_months": "3 Meses Recientes",
            "loading_chart_data_message": "Cargando datos del gráfico...",
            "no_historical_data": "Sin Datos Históricos",
            "no_historical_data_message": "Sin datos históricos disponibles",
            "no_citation_data_available": "Sin datos de citas disponibles",
            "total_citations_chart": "Total de Citas",
            "statistics_info": "Estadísticas",
            "current_citations_stat": "Citas Actuales",
            "recent_change": "Cambio Reciente",
            "growth_rate": "Tasa de Crecimiento",
            "data_points": "Puntos de Datos",
            "selected_data_point": "Punto de Dato Seleccionado",
            "date_label": "Fecha",
            "citations_label": "Citas",
            "recent_update": "Actualización Reciente",
            "citation_ranking": "Ranking de Citas",
            "citation_distribution": "Distribución de Citas",
            "scholar_statistics": "Estadísticas de Académicos",
            "total_scholars": "Total de Académicos",
            "average_citations": "Promedio de Citas",
            "highest_citations": "Mayor Número de Citas",
            "delete_all_scholars_title": "Eliminar Todos los Académicos",
            "delete_all_scholars_message": "¿Estás seguro de que quieres eliminar todos los académicos? Esta acción no se puede deshacer.",
            "trend_suffix": "Tendencia",
            
            // 时间范围
            "1week": "1 Semana",
            "1month": "1 Mes",
            "3months": "3 Meses",
            "6months": "6 Meses",
            "1year": "1 Año",
            "all_time": "Todo el Tiempo",
            "custom_range": "Rango Personalizado",
            
            // 额外的UI字符串
            "dashboard": "Panel de Control",
            "enter_scholar_id": "Ingresa ID del Académico",
            "scholar_id_help": "Encuéntralo en la URL del perfil de Google Scholar",
            "scholar_information": "Información del Académico",
            "scholar_name_optional": "Nombre del Académico (Opcional)",
            "enter_scholar_name": "Ingresa el Nombre del Académico",
            "name_auto_fetch": "El nombre se completará automáticamente si se deja en blanco",
            "validating_scholar_id": "Validando ID del académico...",
            "scholar_found": "Académico Encontrado",
            "preview": "Vista Previa",
            "how_to_find_scholar_id": "Cómo Encontrar el ID del Académico",
            "visit_google_scholar": "Visitar Google Scholar",
            "search_for_author": "Buscar el autor",
            "click_author_name": "Hacer clic en el nombre del autor",
            "copy_from_url": "Copiar el ID de la URL",
            "example_url": "Ejemplo: scholar.google.com/citations?user=XXXXXXXX",
            "invalid_scholar_id_format": "Formato de ID de académico inválido",
            "rate_limited_error": "Demasiadas solicitudes, intenta más tarde",
            "validation_error": "Error de validación",
            "scholar_already_exists": "El académico ya existe",
            "scholar_id_empty": "El ID del académico no puede estar vacío",
            
            // Scholar模型相关
            "scholar_default_name": "Académico",
            "test_scholar": "Académico de Prueba",
            
            // 时间范围
            "past_week": "Semana Pasada",
            "past_month": "Mes Pasado",
            "past_3_months": "3 Meses Pasados",
            "past_6_months": "6 Meses Pasados",
            "past_year": "Año Pasado",
            "this_week": "Esta Semana",
            "this_month": "Este Mes",
            "this_quarter": "Este Trimestre",
            "this_year": "Este Año",
            
            // Growth statistics
            "growth_statistics": "Estadísticas de Crecimiento",
            "weekly_growth": "Crecimiento Semanal",
            "monthly_growth": "Crecimiento Mensual",
            "quarterly_growth": "Crecimiento Trimestral",
            "trend_analysis": "Análisis de Tendencias",
            "loading_growth_data": "Cargando datos de crecimiento...",
            
            // Google Scholar Service 错误信息
            "invalid_url": "URL Inválida",
            "invalid_scholar_id_or_url": "ID de académico o URL inválida",
            
            // 缺失的翻译键
            "import": "Importar",
            "export": "Exportar",
            "import_from_icloud_message": "Esto importará datos desde la carpeta CiteTrack en iCloud Drive. Los datos actuales serán reemplazados.",
            "export_to_icloud_message": "Esto exportará los datos actuales a la carpeta CiteTrack en iCloud Drive.",
            "no_data_available": "No Hay Datos Disponibles",
            "current_citations_label": "Citas Actuales",
            "last_updated_label": "Última Actualización",
            "updated_at": "Actualizado en",
            "citation_information": "Información de Citas",
            "no_data_returned": "No se devolvieron datos",
            "network_error": "Error de red",
            "scholar_not_found": "Académico no encontrado",
            
            // Estado de sincronización de iCloud
            "importing_from_icloud": "Importando desde iCloud...",
            "import_completed": "Importación completada",
            "import_failed": "Importación fallida",
            "exporting_to_icloud": "Exportando a iCloud...",
            "export_completed": "Exportación completada",
            "export_failed": "Exportación fallida",
            "icloud_not_available": "iCloud no disponible",
            "last_sync": "Última sincronización",
            "icloud_data_found": "Datos de iCloud encontrados",
            "icloud_available_no_sync": "iCloud disponible, no sincronizado",
            
            // Resultado de importación de iCloud
            "imported_scholars_count": "Importados",
            "imported_history_count": "entradas de historial",
            "imported_config": "Configuración de la aplicación importada",
            "no_data_to_import": "No se encontraron datos para importar",
            "scholars_unit": "académicos",
            "history_entries_unit": "entradas de historial",
            
            // Mensajes de error de iCloud
            "icloud_drive_unavailable": "iCloud Drive no está disponible. Verifica tu configuración de iCloud.",
            "invalid_icloud_url": "URL de iCloud inválida - Asegúrate de que iCloud Drive esté habilitado.",
            "no_citetrack_data_in_icloud": "No se encontraron datos de CiteTrack en iCloud.",
            "export_failed_with_message": "Exportación fallida",
            "import_failed_with_message": "Importación fallida",
            "failed_with_colon": "Fallida",
            
            // Widget specific strings
            "start_tracking": "Iniciar Seguimiento",
            "add_scholar_to_track": "Agregar Académico para Seguir",
            "tap_to_open_app": "Toca para Abrir App y Agregar Académico",
            "academic_influence": "Influencia Académica",
            "top_scholars": "Académicos",
            "academic_ranking": "Ranking Académico",
            "add_scholars_to_track": "Agregar Académicos para Seguir\nSu Influencia Académica",
            "tracking_scholars": "Siguiendo Académicos",
            "latest_data": "Datos Más Recientes",
            "data_insights": "Perspectivas de Datos",
            "select_scholar": "Seleccionar Académico",
            "select_scholar_description": "Selecciona un académico para mostrar en el widget",
            "scholar_parameter": "Académico",
            "scholar_parameter_description": "Selecciona el académico para mostrar en el widget pequeño",
            "force_refresh_widget": "Forzar Actualización del Widget",
            "force_refresh_description": "Forzar actualización de datos del widget",
            "debug_test": "Prueba de Depuración",
            "debug_test_description": "Intent de prueba para depuración",
            "refresh_data": "Actualizar Datos",
            "refresh_data_description": "Actualizar datos de citas del académico",
            "switch_scholar": "Cambiar Académico",
            "switch_scholar_description": "Cambiar al siguiente académico",
            "citations_unit": "citas"
        ]
    }
    
    private func loadFrenchLocalizations() {
        localizations[.french] = [
            // 基础法语本地化
            "app_name": "CiteTrack",
            "ok": "OK",
            "cancel": "Annuler",
            "save": "Enregistrer",
            "delete": "Supprimer",
            "edit": "Modifier",
            "add": "Ajouter",
            "remove": "Supprimer",
            "close": "Fermer",
            "settings": "Paramètres",
            "about": "À propos",
            "help": "Aide",
            "loading": "Chargement...",
            "error": "Erreur",
            "success": "Succès",
            
            // 学者相关
            "scholar": "Chercheur",
            "scholars": "Chercheurs",
            "add_scholar": "Ajouter un Chercheur",
            "scholar_id": "ID du Chercheur",
            "scholar_name": "Nom du Chercheur",
            "citations": "Citations",
            "citation_count": "Nombre de Citations",
            "last_updated": "Dernière Mise à Jour",
            "never_updated": "Jamais Mis à Jour",
            "unknown": "Inconnu",
            
            // 图表相关
            "charts": "Graphiques",
            "chart_type": "Type de Graphique",
            "line_chart": "Graphique en Ligne",
            "bar_chart": "Graphique en Barres",
            "area_chart": "Graphique en Aire",
            "time_range": "Plage de Temps",
            "color_scheme": "Schéma de Couleurs",
            "show_trend_line": "Afficher la Ligne de Tendance",
            "show_data_points": "Afficher les Points de Données",
            "show_grid": "Afficher la Grille",
            "export_chart": "Exporter le Graphique",
            "citations_count": "%d citations",
            "chart_x_axis_date": "Date",
            "chart_y_axis_citations": "Citations",
            "no_data_to_chart": "Aucune donnée à afficher sur le graphique",
            "add_scholars_to_see_charts": "Ajoutez des chercheurs pour voir les graphiques",
            "contribution_activity": "Activité de Contribution",
            "contribution_chart_description": "Affiche le modèle d'activité des 140 derniers jours",
            "citation_chart": "Graphique des Citations",
            "no_chart_data": "Aucune donnée de graphique",
            "chart_data_will_appear": "Les données du graphique apparaîtront après l'ajout de chercheurs",
            "charts_require_ios16": "Les graphiques nécessitent iOS 16 ou ultérieur",
            "update_ios_for_charts": "Veuillez mettre à jour votre version iOS pour utiliser les graphiques",
            "no_citation_data": "Aucune donnée de citation",
            
            // 设置相关
            "general_settings": "Paramètres Généraux",
            "update_interval": "Intervalle de Mise à Jour",
            "show_in_dock": "Afficher dans le Dock",
            "show_in_menu_bar": "Afficher dans la Barre de Menu",
            "launch_at_login": "Lancer au Démarrage",
            "icloud_sync": "Synchronisation iCloud",
            "notifications": "Notifications",
            "auto_update": "Mise à Jour Automatique",
            "auto_update_enabled": "Activer la Mise à Jour Automatique",
            "auto_update_frequency": "Fréquence de Mise à Jour",
            "next_update_time": "Prochaine Mise à Jour",
            "hourly": "Horaire",
            "daily": "Quotidien",
            "weekly": "Hebdomadaire",
            "monthly": "Mensuel",
            "language": "Langue",
            "theme": "Thème",
            "widget_theme": "Thème du widget",
            "light_mode": "Mode Clair",
            "dark_mode": "Mode Sombre",
            "system_mode": "Système",
            "select_language": "Sélectionner la Langue",
            "app_information": "Informations sur l'Application",
            "version": "Version",
            "build": "Build",
            "sync_status": "Statut",
            "check_sync_status": "Vérifier le Statut de Synchronisation",
            "data_management": "Gestion des Données",
            "import_from_icloud": "Importer depuis iCloud",
            "manual_import_file": "Importer des données vers un fichier",
            "export_to_device": "Exporter des données vers un fichier",
            "export_to_icloud": "Exporter vers iCloud",
            "app_description": "CiteTrack - Outil de Suivi des Citations Académiques",
            "app_help": "Aide les chercheurs à suivre et gérer les données de citations Google Scholar",
            "icloud_sync_description": "Synchronisation transparente entre appareils via iCloud",
            // Page d'accueil (ajout des clés manquantes)
            "smart_tracking": "Suivi intelligent",
            "smart_tracking_description": "Suivi automatique des citations avec mises à jour intelligentes",
            
            // 通知相关
            "citation_change": "Changement de Citations",
            "data_update_complete": "Mise à Jour des Données Terminée",
            "sync_complete": "Synchronisation Terminée",
            
            // 错误信息
            "rate_limited": "Trop de Demandes",
            "fetch_failed": "Échec de Récupération",
            "operation_failed": "Opération Échouée",
            "import_result": "Résultat d'Importation",
            "export_success": "Exportation Réussie ! Les données ont été sauvegardées dans le dossier CiteTrack d'iCloud Drive.",
            "export_file_success": "Fichier exporté avec succès ! Vous pouvez maintenant le partager avec d'autres applications.",
            "export_to_icloud_alert_title": "Exporter vers iCloud",
            "export_to_icloud_alert_message": "Cela exportera les données actuelles vers le dossier CiteTrack dans iCloud Drive.",
            "import_from_icloud_alert_title": "Importer depuis iCloud",
            "import_from_icloud_alert_message": "Cela importera des données depuis le dossier CiteTrack dans iCloud Drive. Les données actuelles seront remplacées.",
            
            // UI文本
            "dashboard_title": "Tableau de Bord",
            "scholar_management": "Chercheurs",
            "total_citations": "Total des Citations",
            "debug_show_refresh_frequency": "Afficher la fréquence d'actualisation",
            "total_citations_with_count": "Total des Citations",
            "scholar_count": "Nombre de Chercheurs",
            "scholar_list": "Liste des Chercheurs",
            "no_scholar_data": "Aucune Donnée de Chercheur",
            "add_first_scholar_tip": "Ajoutez votre premier chercheur dans l'onglet \"Chercheurs\"",
            "no_scholar_data_tap_tip": "Touchez le menu dans le coin supérieur droit pour ajouter votre premier chercheur",
            "getting_scholar_info": "Récupération des informations du chercheur...",
            "updating_all_scholars": "Mise à jour de tous les chercheurs...",
            "updating": "Mise à jour...",
            "update_all": "Tout Mettre à Jour",
            "pull_to_refresh_all": "下拉刷新全部学者",
            "delete_all": "Tout Supprimer",
            "confirm": "Confirmer",
            "scholar_name_placeholder": "Nom du Chercheur (Optionnel)",
            "google_scholar_id_placeholder": "ID Google Scholar",
            "add_scholar_button": "Ajouter un Chercheur",
            "edit_scholar": "Modifier le Chercheur",
            "current_citations": "Citations Actuelles",
            "enter_scholar_name_placeholder": "Entrez le Nom du Chercheur",
            "citations_display": "Citations",
            "no_data": "Aucune Donnée",
            "just_now": "À l'instant",
            "minutes_ago": "minutes auparavant",
            "hours_ago": "heures auparavant",
            "days_ago": "jours auparavant",
            "update": "Mettre à Jour",
            "pin_to_top": "Épingler",
            "unpin": "Désépingler",
            "chart": "Graphique",
            "citation_trend": "Tendance des Citations",
            "recent_week": "Semaine Récente",
            "recent_month": "Mois Récent",
            "recent_three_months": "3 Mois Récents",
            "loading_chart_data_message": "Chargement des données du graphique...",
            "no_historical_data": "Aucune Donnée Historique",
            "no_historical_data_message": "Aucune donnée historique disponible",
            "no_citation_data_available": "Aucune donnée de citation disponible",
            "total_citations_chart": "Total des Citations",
            "statistics_info": "Statistiques",
            "current_citations_stat": "Citations Actuelles",
            "recent_change": "Changement Récent",
            "growth_rate": "Taux de Croissance",
            "data_points": "Points de Données",
            "selected_data_point": "Point de Donnée Sélectionné",
            "date_label": "Date",
            "citations_label": "Citations",
            "recent_update": "Mise à Jour Récente",
            "citation_ranking": "Classement des Citations",
            "citation_distribution": "Distribution des Citations",
            "scholar_statistics": "Statistiques des Chercheurs",
            "total_scholars": "Total des Chercheurs",
            "average_citations": "Moyenne des Citations",
            "highest_citations": "Plus Grand Nombre de Citations",
            "delete_all_scholars_title": "Supprimer Tous les Chercheurs",
            "delete_all_scholars_message": "Êtes-vous sûr de vouloir supprimer tous les chercheurs ? Cette action ne peut pas être annulée.",
            "trend_suffix": "Tendance",
            
            // 时间范围
            "1week": "1 Semaine",
            "1month": "1 Mois",
            "3months": "3 Mois",
            "6months": "6 Mois",
            "1year": "1 An",
            "all_time": "Tout le Temps",
            "custom_range": "Plage Personnalisée",
            
            // 额外的UI字符串
            "dashboard": "Tableau de Bord",
            "enter_scholar_id": "Entrez l'ID du Chercheur",
            "scholar_id_help": "Trouvez-le dans l'URL du profil Google Scholar",
            "scholar_information": "Informations du Chercheur",
            "scholar_name_optional": "Nom du Chercheur (Optionnel)",
            "enter_scholar_name": "Entrez le Nom du Chercheur",
            "name_auto_fetch": "Le nom sera automatiquement rempli si laissé vide",
            "validating_scholar_id": "Validation de l'ID du chercheur...",
            "scholar_found": "Chercheur Trouvé",
            "preview": "Aperçu",
            "how_to_find_scholar_id": "Comment Trouver l'ID du Chercheur",
            "visit_google_scholar": "Visiter Google Scholar",
            "search_for_author": "Rechercher l'auteur",
            "click_author_name": "Cliquer sur le nom de l'auteur",
            "copy_from_url": "Copier l'ID de l'URL",
            "example_url": "Exemple: scholar.google.com/citations?user=XXXXXXXX",
            "invalid_scholar_id_format": "Format d'ID de chercheur invalide",
            "rate_limited_error": "Trop de demandes, réessayez plus tard",
            "validation_error": "Erreur de validation",
            "scholar_already_exists": "Le chercheur existe déjà",
            "scholar_id_empty": "L'ID du chercheur ne peut pas être vide",
            
            // Scholar模型相关
            "scholar_default_name": "Chercheur",
            "test_scholar": "Chercheur de Test",
            
            // 时间范围
            "past_week": "Semaine Passée",
            "past_month": "Mois Passé",
            "past_3_months": "3 Mois Passés",
            "past_6_months": "6 Mois Passés",
            "past_year": "An Passé",
            "this_week": "Cette Semaine",
            "this_month": "Ce Mois",
            "this_quarter": "Ce Trimestre",
            "this_year": "Cette Année",
            
            // Growth statistics
            "growth_statistics": "Statistiques de Croissance",
            "weekly_growth": "Croissance Hebdomadaire",
            "monthly_growth": "Croissance Mensuelle",
            "quarterly_growth": "Croissance Trimestrielle",
            "trend_analysis": "Analyse des Tendances",
            "loading_growth_data": "Chargement des données de croissance...",
            
            // Google Scholar Service 错误信息
            "invalid_url": "URL Invalide",
            
            // 缺失的翻译键
            "import": "Importer",
            "export": "Exporter",
            "import_from_icloud_message": "Cela importera les données depuis le dossier CiteTrack dans iCloud Drive. Les données actuelles seront remplacées.",
            "export_to_icloud_message": "Cela exportera les données actuelles vers le dossier CiteTrack dans iCloud Drive.",
            "no_data_available": "Aucune Donnée Disponible",
            "current_citations_label": "Citations Actuelles",
            "last_updated_label": "Dernière Mise à Jour",
            "updated_at": "Mis à jour le",
            "citation_information": "Informations de Citation",
            "no_data_returned": "Aucune donnée retournée",
            "network_error": "Erreur réseau",
            "scholar_not_found": "Chercheur non trouvé",
            
            // État de synchronisation iCloud
            "importing_from_icloud": "Importation depuis iCloud...",
            "import_completed": "Importation terminée",
            "import_failed": "Importation échouée",
            "exporting_to_icloud": "Exportation vers iCloud...",
            "export_completed": "Exportation terminée",
            "export_failed": "Exportation échouée",
            "icloud_not_available": "iCloud non disponible",
            "last_sync": "Dernière synchronisation",
            "icloud_data_found": "Données iCloud trouvées",
            "icloud_available_no_sync": "iCloud disponible, non synchronisé",
            
            // Résultat d'importation iCloud
            "imported_scholars_count": "Importés",
            "imported_history_count": "entrées d'historique",
            "imported_config": "Configuration de l'application importée",
            "no_data_to_import": "Aucune donnée trouvée à importer",
            "scholars_unit": "chercheurs",
            "history_entries_unit": "entrées d'historique",
            
            // Messages d'erreur iCloud
            "icloud_drive_unavailable": "iCloud Drive n'est pas disponible. Vérifiez vos paramètres iCloud.",
            "invalid_icloud_url": "URL iCloud invalide - Assurez-vous qu'iCloud Drive est activé.",
            "no_citetrack_data_in_icloud": "Aucune donnée CiteTrack trouvée dans iCloud.",
            "export_failed_with_message": "Exportation échouée",
            "import_failed_with_message": "Importation échouée",
            "failed_with_colon": "Échouée",
            
            // Widget specific strings
            "start_tracking": "Commencer le Suivi",
            "add_scholar_to_track": "Ajouter un Chercheur à Suivre",
            "tap_to_open_app": "Touchez pour Ouvrir l'App et Ajouter un Chercheur",
            "academic_influence": "Influence Académique",
            "top_scholars": "Chercheurs",
            "academic_ranking": "Classement Académique",
            "add_scholars_to_track": "Ajouter des Chercheurs à Suivre\nLeur Influence Académique",
            "tracking_scholars": "Suivi des Chercheurs",
            "latest_data": "Dernières Données",
            "data_insights": "Perspectives de Données",
            "select_scholar": "Sélectionner un Chercheur",
            "select_scholar_description": "Sélectionnez un chercheur à afficher dans le widget",
            "scholar_parameter": "Chercheur",
            "scholar_parameter_description": "Sélectionnez le chercheur à afficher dans le petit widget",
            "force_refresh_widget": "Forcer la Mise à Jour du Widget",
            "force_refresh_description": "Forcer la mise à jour des données du widget",
            "debug_test": "Test de Débogage",
            "debug_test_description": "Intent de test pour le débogage",
            "refresh_data": "Actualiser les Données",
            "refresh_data_description": "Actualiser les données de citations du chercheur",
            "switch_scholar": "Changer de Chercheur",
            "switch_scholar_description": "Passer au chercheur suivant",
            "citations_unit": "citations"
        ]
    }
    
    private func loadGermanLocalizations() {
        localizations[.german] = [
            // 基础德语本地化
            "app_name": "CiteTrack",
            "ok": "OK",
            "cancel": "Abbrechen",
            "save": "Speichern",
            "delete": "Löschen",
            "edit": "Bearbeiten",
            "add": "Hinzufügen",
            "remove": "Entfernen",
            "close": "Schließen",
            "settings": "Einstellungen",
            "about": "Über",
            "help": "Hilfe",
            "loading": "Laden...",
            "error": "Fehler",
            "success": "Erfolg",
            
            // 学者相关
            "scholar": "Forscher",
            "scholars": "Forscher",
            "add_scholar": "Forscher Hinzufügen",
            "scholar_id": "Forscher-ID",
            "scholar_name": "Forscher-Name",
            "citations": "Zitationen",
            "citation_count": "Anzahl der Zitationen",
            "last_updated": "Zuletzt Aktualisiert",
            "never_updated": "Nie Aktualisiert",
            "unknown": "Unbekannt",
            
            // 图表相关
            "charts": "Diagramme",
            "chart_type": "Diagrammtyp",
            "line_chart": "Liniendiagramm",
            "bar_chart": "Balkendiagramm",
            "area_chart": "Flächendiagramm",
            "time_range": "Zeitbereich",
            "color_scheme": "Farbschema",
            "show_trend_line": "Trendlinie Anzeigen",
            "show_data_points": "Datenpunkte Anzeigen",
            "show_grid": "Raster Anzeigen",
            "export_chart": "Diagramm Exportieren",
            "citations_count": "%d Zitate",
            "chart_x_axis_date": "Datum",
            "chart_y_axis_citations": "Zitate",
            "no_data_to_chart": "Keine Daten für das Diagramm verfügbar",
            "add_scholars_to_see_charts": "Fügen Sie Forscher hinzu, um Diagramme zu sehen",
            "contribution_activity": "Beitragsaktivität",
            "contribution_chart_description": "Zeigt das Aktivitätsmuster der letzten 140 Tage",
            "citation_chart": "Zitationsdiagramm",
            "no_chart_data": "Keine Diagrammdaten",
            "chart_data_will_appear": "Diagrammdaten erscheinen nach dem Hinzufügen von Forschern",
            "charts_require_ios16": "Diagramme erfordern iOS 16 oder höher",
            "update_ios_for_charts": "Bitte aktualisieren Sie Ihre iOS-Version, um Diagramme zu verwenden",
            "no_citation_data": "Keine Zitationsdaten",
            
            // 设置相关
            "general_settings": "Allgemeine Einstellungen",
            "update_interval": "Aktualisierungsintervall",
            "show_in_dock": "Im Dock Anzeigen",
            "show_in_menu_bar": "In Menüleiste Anzeigen",
            "launch_at_login": "Beim Anmelden Starten",
            "icloud_sync": "iCloud-Synchronisation",
            "notifications": "Benachrichtigungen",
            "auto_update": "Automatische Aktualisierung",
            "auto_update_enabled": "Automatische Aktualisierung Aktivieren",
            "auto_update_frequency": "Aktualisierungsfrequenz",
            "next_update_time": "Nächste Aktualisierung",
            "hourly": "Stündlich",
            "daily": "Täglich",
            "weekly": "Wöchentlich",
            "monthly": "Monatlich",
            "language": "Sprache",
            "theme": "Design",
            "widget_theme": "Widget-Design",
            "light_mode": "Heller Modus",
            "dark_mode": "Dunkler Modus",
            "system_mode": "System",
            "select_language": "Sprache Auswählen",
            "app_information": "App-Informationen",
            "version": "Version",
            "build": "Build",
            "sync_status": "Status",
            "check_sync_status": "Synchronisationsstatus Prüfen",
            "data_management": "Datenverwaltung",
            "import_from_icloud": "Von iCloud Importieren",
            "manual_import_file": "Daten in Datei importieren",
            "export_to_device": "Daten in Datei exportieren",
            "export_to_icloud": "Nach iCloud Exportieren",
            "app_description": "CiteTrack - Akademisches Zitations-Tracking-Tool",
            "app_help": "Hilft Forschern beim Verfolgen und Verwalten von Google Scholar-Zitationsdaten",
            "icloud_sync_description": "Nahtlose Synchronisierung zwischen Geräten über iCloud",
            // Willkommensseite (fehlende Schlüssel hinzufügen)
            "smart_tracking": "Intelligentes Tracking",
            "smart_tracking_description": "Automatisches Zitaten-Tracking mit intelligenten Aktualisierungen",
            
            // 通知相关
            "citation_change": "Zitationsänderung",
            "data_update_complete": "Datenaktualisierung Abgeschlossen",
            "sync_complete": "Synchronisation Abgeschlossen",
            
            // 错误信息
            "rate_limited": "Zu Viele Anfragen",
            "fetch_failed": "Abruf Fehlgeschlagen",
            "operation_failed": "Operation Fehlgeschlagen",
            "import_result": "Import-Ergebnis",
            "export_success": "Export Erfolgreich! Daten wurden im CiteTrack-Ordner in iCloud Drive gespeichert.",
            "export_file_success": "Datei erfolgreich exportiert! Sie können sie jetzt mit anderen Apps teilen.",
            "export_to_icloud_alert_title": "Nach iCloud Exportieren",
            "export_to_icloud_alert_message": "Dies exportiert die aktuellen Daten in den CiteTrack-Ordner in iCloud Drive.",
            "import_from_icloud_alert_title": "Von iCloud Importieren",
            "import_from_icloud_alert_message": "Dies importiert Daten aus dem CiteTrack-Ordner in iCloud Drive. Aktuelle Daten werden ersetzt.",
            
            // UI文本
            "dashboard_title": "Dashboard",
            "scholar_management": "Forscher",
            "total_citations": "Gesamtzitationen",
            "debug_show_refresh_frequency": "Aktualisierungshäufigkeit anzeigen",
            "total_citations_with_count": "Gesamtzitationen",
            "scholar_count": "Anzahl der Forscher",
            "scholar_list": "Forscher-Liste",
            "no_scholar_data": "Keine Forscher-Daten",
            "add_first_scholar_tip": "Fügen Sie Ihren ersten Forscher im \"Forscher\"-Tab hinzu",
            "no_scholar_data_tap_tip": "Tippen Sie auf das Menü in der oberen rechten Ecke, um Ihren ersten Forscher hinzuzufügen",
            "getting_scholar_info": "Forscher-Informationen werden abgerufen...",
            "updating_all_scholars": "Alle Forscher werden aktualisiert...",
            "updating": "Aktualisierung...",
            "update_all": "Alle Aktualisieren",
            "pull_to_refresh_all": "下拉刷新全部学者",
            "delete_all": "Alle Löschen",
            "confirm": "Bestätigen",
            "scholar_name_placeholder": "Forscher-Name (Optional)",
            "google_scholar_id_placeholder": "Google Scholar ID",
            "add_scholar_button": "Forscher Hinzufügen",
            "edit_scholar": "Forscher Bearbeiten",
            "current_citations": "Aktuelle Zitationen",
            "enter_scholar_name_placeholder": "Forscher-Name Eingeben",
            "citations_display": "Zitationen",
            "no_data": "Keine Daten",
            "just_now": "Gerade eben",
            "minutes_ago": "Minuten her",
            "hours_ago": "Stunden her",
            "days_ago": "Tage her",
            "update": "Aktualisieren",
            "pin_to_top": "Fixieren",
            "unpin": "Lösen",
            "chart": "Diagramm",
            "citation_trend": "Zitations-Trend",
            "recent_week": "Letzte Woche",
            "recent_month": "Letzter Monat",
            "recent_three_months": "Letzte 3 Monate",
            "loading_chart_data_message": "Diagrammdaten werden geladen...",
            "no_historical_data": "Keine Historischen Daten",
            "no_historical_data_message": "Keine historischen Daten verfügbar",
            "no_citation_data_available": "Keine Zitationsdaten verfügbar",
            "total_citations_chart": "Gesamtzitationen",
            "statistics_info": "Statistiken",
            "current_citations_stat": "Aktuelle Zitationen",
            "recent_change": "Letzte Änderung",
            "growth_rate": "Wachstumsrate",
            "data_points": "Datenpunkte",
            "selected_data_point": "Ausgewählter Datenpunkt",
            "date_label": "Datum",
            "citations_label": "Zitationen",
            "recent_update": "Letzte Aktualisierung",
            "citation_ranking": "Zitations-Ranking",
            "citation_distribution": "Zitations-Verteilung",
            "scholar_statistics": "Forscher-Statistiken",
            "total_scholars": "Gesamtzahl der Forscher",
            "average_citations": "Durchschnittliche Zitationen",
            "highest_citations": "Höchste Zitationen",
            "delete_all_scholars_title": "Alle Forscher Löschen",
            "delete_all_scholars_message": "Sind Sie sicher, dass Sie alle Forscher löschen möchten? Diese Aktion kann nicht rückgängig gemacht werden.",
            "trend_suffix": "Trend",
            
            // 时间范围
            "1week": "1 Woche",
            "1month": "1 Monat",
            "3months": "3 Monate",
            "6months": "6 Monate",
            "1year": "1 Jahr",
            "all_time": "Gesamte Zeit",
            "custom_range": "Benutzerdefinierter Bereich",
            
            // 额外的UI字符串
            "dashboard": "Dashboard",
            "enter_scholar_id": "Forscher-ID Eingeben",
            "scholar_id_help": "Finden Sie es in der Google Scholar-Profil-URL",
            "scholar_information": "Forscher-Informationen",
            "scholar_name_optional": "Forscher-Name (Optional)",
            "enter_scholar_name": "Forscher-Name Eingeben",
            "name_auto_fetch": "Name wird automatisch ausgefüllt, wenn leer gelassen",
            "validating_scholar_id": "Forscher-ID wird validiert...",
            "scholar_found": "Forscher Gefunden",
            "preview": "Vorschau",
            "how_to_find_scholar_id": "Wie Man Die Forscher-ID Findet",
            "visit_google_scholar": "Google Scholar Besuchen",
            "search_for_author": "Nach dem Autor suchen",
            "click_author_name": "Auf den Autorennamen klicken",
            "copy_from_url": "ID aus der URL kopieren",
            "example_url": "Beispiel: scholar.google.com/citations?user=XXXXXXXX",
            "invalid_scholar_id_format": "Ungültiges Forscher-ID-Format",
            "rate_limited_error": "Zu viele Anfragen, versuchen Sie es später erneut",
            "validation_error": "Validierungsfehler",
            "scholar_already_exists": "Forscher existiert bereits",
            "scholar_id_empty": "Forscher-ID kann nicht leer sein",
            
            // Scholar模型相关
            "scholar_default_name": "Forscher",
            "test_scholar": "Test-Forscher",
            
            // 时间范围
            "past_week": "Letzte Woche",
            "past_month": "Letzter Monat",
            "past_3_months": "Letzte 3 Monate",
            "past_6_months": "Letzte 6 Monate",
            "past_year": "Letztes Jahr",
            "this_week": "Diese Woche",
            "this_month": "Dieser Monat",
            "this_quarter": "Dieses Quartal",
            "this_year": "Dieses Jahr",
            
            // Growth statistics
            "growth_statistics": "Wachstumsstatistiken",
            "weekly_growth": "Wöchentliches Wachstum",
            "monthly_growth": "Monatliches Wachstum",
            "quarterly_growth": "Quartalsweises Wachstum",
            "trend_analysis": "Trendanalyse",
            "loading_growth_data": "Lade Wachstumsdaten...",
            
            // Google Scholar Service 错误信息
            "invalid_url": "Ungültige URL",
            "invalid_scholar_id_or_url": "Ungültige Forscher-ID oder URL",
            
            // 缺失的翻译键
            "import": "Importieren",
            "export": "Exportieren",
            "import_from_icloud_message": "Dies importiert Daten aus dem CiteTrack-Ordner in iCloud Drive. Aktuelle Daten werden ersetzt.",
            "export_to_icloud_message": "Dies exportiert aktuelle Daten in den CiteTrack-Ordner in iCloud Drive.",
            "no_data_available": "Keine Daten Verfügbar",
            "current_citations_label": "Aktuelle Zitationen",
            "last_updated_label": "Letzte Aktualisierung",
            "updated_at": "Aktualisiert am",
            "citation_information": "Zitationsinformationen",
            "no_data_returned": "Keine Daten zurückgegeben",
            
            // iCloud-Synchronisationsstatus
            "importing_from_icloud": "Von iCloud importieren...",
            "import_completed": "Import abgeschlossen",
            "import_failed": "Import fehlgeschlagen",
            "exporting_to_icloud": "Nach iCloud exportieren...",
            "export_completed": "Export abgeschlossen",
            "export_failed": "Export fehlgeschlagen",
            "icloud_not_available": "iCloud nicht verfügbar",
            "last_sync": "Letzte Synchronisation",
            "icloud_data_found": "iCloud-Daten gefunden",
            "icloud_available_no_sync": "iCloud verfügbar, nicht synchronisiert",
            
            // iCloud-Import-Ergebnis
            "imported_scholars_count": "Importiert",
            "imported_history_count": "Historieinträge",
            "imported_config": "App-Konfiguration importiert",
            "no_data_to_import": "Keine Daten zum Importieren gefunden",
            "scholars_unit": "Forscher",
            "history_entries_unit": "Historieinträge",
            
            // iCloud-Fehlermeldungen
            "icloud_drive_unavailable": "iCloud Drive ist nicht verfügbar. Überprüfen Sie Ihre iCloud-Einstellungen.",
            "invalid_icloud_url": "Ungültige iCloud-URL - Stellen Sie sicher, dass iCloud Drive aktiviert ist.",
            "no_citetrack_data_in_icloud": "Keine CiteTrack-Daten in iCloud gefunden.",
            "export_failed_with_message": "Export fehlgeschlagen",
            "import_failed_with_message": "Import fehlgeschlagen",
            "failed_with_colon": "Fehlgeschlagen",
            
            // Widget specific strings
            "start_tracking": "Verfolgung Starten",
            "add_scholar_to_track": "Forscher Hinzufügen zum Verfolgen",
            "tap_to_open_app": "Tippen um App zu Öffnen und Forscher Hinzuzufügen",
            "academic_influence": "Akademischer Einfluss",
            "top_scholars": "Forscher",
            "academic_ranking": "Akademisches Ranking",
            "add_scholars_to_track": "Forscher Hinzufügen zum Verfolgen\nIhr Akademischer Einfluss",
            "tracking_scholars": "Forscher Verfolgen",
            "latest_data": "Neueste Daten",
            "data_insights": "Daten-Einblicke",
            "select_scholar": "Forscher Auswählen",
            "select_scholar_description": "Wählen Sie einen Forscher aus, der im Widget angezeigt werden soll",
            "scholar_parameter": "Forscher",
            "scholar_parameter_description": "Wählen Sie den Forscher aus, der im kleinen Widget angezeigt werden soll",
            "force_refresh_widget": "Widget Erzwingen Aktualisieren",
            "force_refresh_description": "Widget-Daten erzwingen aktualisieren",
            "debug_test": "Debug-Test",
            "debug_test_description": "Test-Intent für Debugging",
            "refresh_data": "Daten Aktualisieren",
            "refresh_data_description": "Forscher-Zitationsdaten aktualisieren",
            "switch_scholar": "Forscher Wechseln",
            "switch_scholar_description": "Zum nächsten Forscher wechseln",
            "citations_unit": "Zitationen"
        ]
    }
}

// MARK: - Convenience Extensions
public extension String {
    var localized: String {
        return LocalizationManager.shared.localized(self)
    }
}