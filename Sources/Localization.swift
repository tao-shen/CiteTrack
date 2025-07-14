import Foundation

// MARK: - Localization Manager
class LocalizationManager {
    static let shared = LocalizationManager()
    
    enum Language: String, CaseIterable {
        case english = "en"
        case chinese = "zh-Hans"
        case japanese = "ja"
        case korean = "ko"
        case spanish = "es"
        case french = "fr"
        case german = "de"
        
        var displayName: String {
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
        
        var nativeName: String {
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
    }
    
    private var currentLanguage: Language
    private var localizations: [Language: [String: String]] = [:]
    
    private init() {
        // 检测系统语言
        let systemLanguage = Locale.current.languageCode ?? "en"
        self.currentLanguage = Language(rawValue: systemLanguage) ?? .english
        
        // 检查用户设置
        if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage"),
           let language = Language(rawValue: savedLanguage) {
            self.currentLanguage = language
        }
        
        loadLocalizations()
    }
    
    func setLanguage(_ language: Language) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "AppLanguage")
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
    
    func localized(_ key: String) -> String {
        return localizations[currentLanguage]?[key] ?? localizations[.english]?[key] ?? key
    }
    
    var currentLanguageCode: String {
        return currentLanguage.rawValue
    }
    
    var availableLanguages: [Language] {
        return Language.allCases
    }
    
    private func loadLocalizations() {
        // English (Default)
        localizations[.english] = [
            // App Info
            "app_name": "CiteTrack",
            "app_description": "Google Scholar Citation Monitor",
            "app_version": "Version 1.0",
            "app_about": "A professional macOS menu bar app\nReal-time Google Scholar citation monitoring\n\nSmall but powerful, professional and reliable\nSupports multi-scholar monitoring with smart updates\n\n© 2024",
            
            // Menu Items
            "menu_no_scholars": "No scholar data",
            "menu_manual_update": "Manual Update",
            "menu_preferences": "Preferences...",
            "menu_about": "About CiteTrack",
            "menu_quit": "Quit",
            
            // Settings Window
            "settings_title": "CiteTrack - Settings",
            "tab_general": "General",
            "tab_scholars": "Scholars",
            "section_app_settings": "Application Settings",
            "section_display_options": "Display Options",
            "section_startup_options": "Startup Options",
            "section_scholar_management": "Scholar Management",
            
            // Scholar Management
            "scholar_name": "Name",
            "scholar_id": "Scholar ID",
            "scholar_citations": "Citations",
            "scholar_last_updated": "Last Updated",
            "button_add_scholar": "Add Scholar",
            "button_remove": "Remove",
            "button_refresh": "Refresh Data",
            
            // Settings Options
            "setting_update_interval": "Auto Update Interval:",
            "setting_show_in_dock": "Show in Dock:",
            "setting_show_in_menubar": "Show in Menu Bar:",
            "setting_launch_at_login": "Launch at Login:",
            "setting_language": "Language:",
            
            // Time Intervals
            "interval_30min": "30 minutes",
            "interval_1hour": "1 hour",
            "interval_2hours": "2 hours",
            "interval_6hours": "6 hours",
            "interval_12hours": "12 hours",
            "interval_1day": "1 day",
            "interval_3days": "3 days",
            "interval_1week": "1 week",
            
            // Add Scholar Dialog
            "add_scholar_title": "Add Scholar",
            "add_scholar_message": "Please enter Google Scholar user ID or complete link",
            "add_scholar_id_placeholder": "e.g., USER_ID or complete link",
            "add_scholar_name_placeholder": "Scholar name (optional)",
            "add_scholar_id_label": "Scholar ID or Link:",
            "add_scholar_name_label": "Name (optional):",
            "button_add": "Add",
            "button_cancel": "Cancel",
            
            // Error Messages
            "error_empty_input": "Empty Input",
            "error_empty_input_message": "Please enter a valid Google Scholar user ID or link",
            "error_scholar_exists": "Scholar Already Exists",
            "error_scholar_exists_message": "This scholar is already in the list",
            "error_invalid_format": "Invalid Input Format",
            "error_invalid_format_message": "Please enter a valid Google Scholar user ID or complete link\n\nSupported formats:\n• Direct user ID\n• https://scholar.google.com/citations?user=USER_ID",
            "error_fetch_failed": "Failed to Fetch Scholar Info",
            "error_fetch_failed_message": "Scholar added as %@, but unable to get detailed info: %@",
            "error_no_selection": "Please select a scholar to remove",
            
            // Success Messages
            "success_scholar_added": "Scholar Added Successfully",
            "success_scholar_added_message": "Scholar %@ added with %d citations",
            
            // Welcome Dialog
            "welcome_title": "Welcome to CiteTrack",
            "welcome_message": "This is a professional macOS menu bar app for real-time monitoring of your Google Scholar citations.\n\nSmall but powerful, professional and reliable.\n\nPlease add scholar information to get started.",
            "button_open_settings": "Open Settings",
            "button_later": "Later",
            
            // Scholar Service Errors
            "error_invalid_url": "Invalid Google Scholar URL",
            "error_no_data": "Unable to fetch data",
            "error_parsing_error": "Failed to parse data",
            "error_network_error": "Network error: %@",
            
            // Default Names
            "default_scholar_name": "Scholar %@",
            "unknown_scholar": "Unknown Scholar",
            
            // Time
            "never": "Never",
            
            // Tooltip
            "tooltip_citetrack": "CiteTrack - Google Scholar Citation Monitor",
            
            // Update Status
            "status_updating": "Updating...",
            "status_updating_progress": "Updating... (%d/%d)",
            "update_completed": "Update Completed",
            "update_progress_title": "Updating Citations",
            "update_result_message": "%d of %d scholars updated successfully. %d failed.",
            
            // Refresh Status
            "refresh_completed": "Refresh Completed",
            "refresh_success_message": "All %d scholars updated successfully.",
            "refresh_partial_message": "%d of %d scholars updated successfully. %d failed."
        ]
        
        // Chinese Simplified
        localizations[.chinese] = [
            // App Info
            "app_name": "CiteTrack",
            "app_description": "Google Scholar 引用量监控",
            "app_version": "版本 1.0",
            "app_about": "一个精美专业的macOS菜单栏应用\n实时监控Google Scholar引用量\n\n小而精，专业可靠\n支持多学者监控，智能更新\n\n© 2024",
            
            // Menu Items
            "menu_no_scholars": "暂无学者数据",
            "menu_manual_update": "手动更新",
            "menu_preferences": "偏好设置...",
            "menu_about": "关于 CiteTrack",
            "menu_quit": "退出",
            
            // Settings Window
            "settings_title": "CiteTrack - 设置",
            "tab_general": "通用",
            "tab_scholars": "学者",
            "section_app_settings": "应用设置",
            "section_display_options": "显示选项",
            "section_startup_options": "启动选项",
            "section_scholar_management": "学者管理",
            
            // Scholar Management
            "scholar_name": "姓名",
            "scholar_id": "学者ID",
            "scholar_citations": "引用量",
            "scholar_last_updated": "最后更新",
            "button_add_scholar": "添加学者",
            "button_remove": "删除",
            "button_refresh": "刷新数据",
            
            // Settings Options
            "setting_update_interval": "自动更新间隔:",
            "setting_show_in_dock": "在Dock中显示:",
            "setting_show_in_menubar": "在菜单栏中显示:",
            "setting_launch_at_login": "随系统启动:",
            "setting_language": "语言:",
            
            // Time Intervals
            "interval_30min": "30分钟",
            "interval_1hour": "1小时",
            "interval_2hours": "2小时",
            "interval_6hours": "6小时",
            "interval_12hours": "12小时",
            "interval_1day": "1天",
            "interval_3days": "3天",
            "interval_1week": "1周",
            
            // Add Scholar Dialog
            "add_scholar_title": "添加学者",
            "add_scholar_message": "请输入Google Scholar用户ID或完整链接",
            "add_scholar_id_placeholder": "例如：USER_ID 或完整链接",
            "add_scholar_name_placeholder": "学者姓名（可选）",
            "add_scholar_id_label": "Scholar ID或链接:",
            "add_scholar_name_label": "姓名（可选）:",
            "button_add": "添加",
            "button_cancel": "取消",
            
            // Error Messages
            "error_empty_input": "输入为空",
            "error_empty_input_message": "请输入有效的Google Scholar用户ID或链接",
            "error_scholar_exists": "学者已存在",
            "error_scholar_exists_message": "该学者已在列表中",
            "error_invalid_format": "输入格式错误",
            "error_invalid_format_message": "请输入有效的Google Scholar用户ID或完整链接\n\n支持格式：\n• 直接输入用户ID\n• https://scholar.google.com/citations?user=USER_ID",
            "error_fetch_failed": "获取学者信息失败",
            "error_fetch_failed_message": "学者已添加为 %@，但无法获取详细信息：%@",
            "error_no_selection": "请选择要删除的学者",
            
            // Success Messages
            "success_scholar_added": "添加成功",
            "success_scholar_added_message": "学者 %@ 已添加，引用量：%d",
            
            // Welcome Dialog
            "welcome_title": "欢迎使用 CiteTrack",
            "welcome_message": "这是一个精美专业的macOS菜单栏应用，用于实时监控您的Google Scholar引用量。\n\n小而精，专业可靠。\n\n请先添加学者信息来开始使用。",
            "button_open_settings": "打开设置",
            "button_later": "稍后",
            
            // Scholar Service Errors
            "error_invalid_url": "无效的Google Scholar URL",
            "error_no_data": "无法获取数据",
            "error_parsing_error": "解析数据失败",
            "error_network_error": "网络错误: %@",
            
            // Default Names
            "default_scholar_name": "学者 %@",
            "unknown_scholar": "未知学者",
            
            // Time
            "never": "从未",
            
            // Tooltip
            "tooltip_citetrack": "CiteTrack - Google Scholar引用量监控",
            
            // Update Status
            "status_updating": "更新中...",
            "status_updating_progress": "更新中... (%d/%d)",
            "update_completed": "更新完成",
            "update_progress_title": "更新引用量",
            "update_result_message": "%d 个学者中的 %d 个更新成功，%d 个失败。",
            
            // Refresh Status
            "refresh_completed": "刷新完成",
            "refresh_success_message": "所有 %d 个学者更新成功。",
            "refresh_partial_message": "%d 个学者更新成功，%d 个失败。"
        ]
        
        // Japanese
        localizations[.japanese] = [
            // App Info
            "app_name": "CiteTrack",
            "app_description": "Google Scholar 引用数モニター",
            "app_version": "バージョン 1.0",
            "app_about": "プロフェッショナルなmacOSメニューバーアプリ\nGoogle Scholar引用数のリアルタイム監視\n\n小さくても強力、プロフェッショナルで信頼性が高い\n複数研究者の監視とスマート更新をサポート\n\n© 2024",
            
            // Menu Items
            "menu_no_scholars": "研究者データなし",
            "menu_manual_update": "手動更新",
            "menu_preferences": "環境設定...",
            "menu_about": "CiteTrackについて",
            "menu_quit": "終了",
            
            // Settings Window
            "settings_title": "CiteTrack - 設定",
            "tab_general": "一般",
            "tab_scholars": "研究者",
            "section_app_settings": "アプリケーション設定",
            "section_display_options": "表示オプション",
            "section_startup_options": "起動オプション",
            "section_scholar_management": "研究者管理",
            
            // Scholar Management
            "scholar_name": "名前",
            "scholar_id": "研究者ID",
            "scholar_citations": "引用数",
            "scholar_last_updated": "最終更新",
            "button_add_scholar": "研究者を追加",
            "button_remove": "削除",
            "button_refresh": "データを更新",
            
            // Settings Options
            "setting_update_interval": "自動更新間隔:",
            "setting_show_in_dock": "Dockに表示:",
            "setting_show_in_menubar": "メニューバーに表示:",
            "setting_launch_at_login": "ログイン時に起動:",
            "setting_language": "言語:",
            
            // Time Intervals
            "interval_30min": "30分",
            "interval_1hour": "1時間",
            "interval_2hours": "2時間",
            "interval_6hours": "6時間",
            "interval_12hours": "12時間",
            "interval_1day": "1日",
            "interval_3days": "3日",
            "interval_1week": "1週間",
            
            // Add Scholar Dialog
            "add_scholar_title": "研究者を追加",
            "add_scholar_message": "Google ScholarのユーザーIDまたは完全なリンクを入力してください",
            "add_scholar_id_placeholder": "例：USER_ID または完全なリンク",
            "add_scholar_name_placeholder": "研究者名（オプション）",
            "add_scholar_id_label": "研究者IDまたはリンク:",
            "add_scholar_name_label": "名前（オプション）:",
            "button_add": "追加",
            "button_cancel": "キャンセル",
            
            // Error Messages
            "error_empty_input": "入力が空です",
            "error_empty_input_message": "有効なGoogle ScholarユーザーIDまたはリンクを入力してください",
            "error_scholar_exists": "研究者は既に存在します",
            "error_scholar_exists_message": "この研究者は既にリストにあります",
            "error_invalid_format": "無効な入力形式",
            "error_invalid_format_message": "有効なGoogle ScholarユーザーIDまたは完全なリンクを入力してください\n\nサポートされる形式：\n• 直接ユーザーID\n• https://scholar.google.com/citations?user=USER_ID",
            "error_fetch_failed": "研究者情報の取得に失敗",
            "error_fetch_failed_message": "研究者は %@ として追加されましたが、詳細情報を取得できませんでした：%@",
            "error_no_selection": "削除する研究者を選択してください",
            
            // Success Messages
            "success_scholar_added": "研究者が正常に追加されました",
            "success_scholar_added_message": "研究者 %@ が追加されました（引用数：%d）",
            
            // Welcome Dialog
            "welcome_title": "CiteTrackへようこそ",
            "welcome_message": "これはGoogle Scholar引用数をリアルタイムで監視するプロフェッショナルなmacOSメニューバーアプリです。\n\n小さくても強力、プロフェッショナルで信頼性が高い。\n\n開始するには研究者情報を追加してください。",
            "button_open_settings": "設定を開く",
            "button_later": "後で",
            
            // Scholar Service Errors
            "error_invalid_url": "無効なGoogle Scholar URL",
            "error_no_data": "データを取得できません",
            "error_parsing_error": "データの解析に失敗",
            "error_network_error": "ネットワークエラー: %@",
            
            // Default Names
            "default_scholar_name": "研究者 %@",
            "unknown_scholar": "不明な研究者",
            
            // Time
            "never": "なし",
            
            // Tooltip
            "tooltip_citetrack": "CiteTrack - Google Scholar引用数モニター",
            
            // Update Status
            "status_updating": "更新中...",
            "status_updating_progress": "更新中... (%d/%d)",
            "update_completed": "更新完了",
            "update_progress_title": "引用数更新中",
            "update_result_message": "%d人の研究者のうち%d人が正常に更新されました。%d人が失敗しました。",
            
            // Refresh Status
            "refresh_completed": "更新完了",
            "refresh_success_message": "%d人の研究者全員が正常に更新されました。",
            "refresh_partial_message": "%d人の研究者のうち%d人が正常に更新されました。%d人が失敗しました。"
        ]
        
        // Add more languages as needed...
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let languageChanged = Notification.Name("LanguageChanged")
    static let scholarsDataUpdated = Notification.Name("ScholarsDataUpdated")
}

// MARK: - Convenience Functions
func L(_ key: String) -> String {
    return LocalizationManager.shared.localized(key)
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let format = LocalizationManager.shared.localized(key)
    return String(format: format, arguments: args)
} 