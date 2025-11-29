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
    private var isLanguageSwitching = false
    private var languageSwitchQueue = DispatchQueue(label: "com.citetrack.languageswitch", qos: .userInitiated)
    
    private init() {
        // 检测系统语言
        let systemLanguageCode = (Locale.current.languageCode ?? "en").lowercased()
        self.currentLanguage = Language(rawValue: systemLanguageCode) ?? .english
        
        // 一次性迁移：若曾保存为中文而系统并非中文，则清除保存的偏好，回归系统语言
        if !UserDefaults.standard.bool(forKey: "MacLanguageMigration20250922Done") {
            if let saved = UserDefaults.standard.string(forKey: "AppLanguage"),
               let savedEnum = Language(rawValue: saved),
               !(systemLanguageCode.hasPrefix("zh") ? savedEnum == .chinese : true),
               !systemLanguageCode.hasPrefix(savedEnum.rawValue.lowercased()) {
                UserDefaults.standard.removeObject(forKey: "AppLanguage")
            }
            UserDefaults.standard.set(true, forKey: "MacLanguageMigration20250922Done")
        }
        
        // 再次检查用户设置（如仍存在则优先）
        if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage"),
           let language = Language(rawValue: savedLanguage) {
            self.currentLanguage = language
        }
        
        loadLocalizations()
    }
    
    func setLanguage(_ language: Language) {
        // 防止并发语言切换
        languageSwitchQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 检查是否正在切换
            guard !self.isLanguageSwitching else {
                print("⚠️ 语言切换正在进行中，忽略新的切换请求")
                return
            }
            
            // 检查是否是相同语言
            guard language != self.currentLanguage else {
                print("ℹ️ 已经是当前语言: \(language.displayName)")
                return
            }
            
            self.isLanguageSwitching = true
            let previousLanguage = self.currentLanguage
            
            do {
                // 先更新内存中的语言设置
                self.currentLanguage = language
                
                // 保存到UserDefaults
                UserDefaults.standard.set(language.rawValue, forKey: "AppLanguage")
                
                // 验证设置是否成功保存
                guard UserDefaults.standard.string(forKey: "AppLanguage") == language.rawValue else {
                    print("❌ 语言设置保存失败，回滚到之前的语言")
                    self.currentLanguage = previousLanguage
                    self.isLanguageSwitching = false
                    throw LanguageError.settingSaveFailed
                }
                
                print("✅ 语言已切换到: \(language.displayName)")
                
                // 在主线程发送通知，确保UI更新的一致性
                DispatchQueue.main.async(qos: .userInitiated) {
                    NotificationCenter.default.post(
                        name: .languageChanged, 
                        object: self, 
                        userInfo: [
                            "previousLanguage": previousLanguage.rawValue,
                            "newLanguage": language.rawValue,
                            "previousDisplayName": previousLanguage.displayName,
                            "newDisplayName": language.displayName
                        ]
                    )
                    
                    // 等待UI更新完成后再重置状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isLanguageSwitching = false
                    }
                }
                
            } catch {
                print("❌ 语言切换失败: \(error)")
                self.currentLanguage = previousLanguage
                self.isLanguageSwitching = false
                
                // 发送错误通知
                DispatchQueue.main.async(qos: .userInitiated) {
                    NotificationCenter.default.post(
                        name: .languageChangeFailed,
                        object: self,
                        userInfo: [
                            "error": error,
                            "previousLanguage": previousLanguage.rawValue,
                            "failedLanguage": language.rawValue
                        ]
                    )
                }
            }
        }
    }
    
    enum LanguageError: Error {
        case settingSaveFailed
        case invalidLanguage
        
        var localizedDescription: String {
            switch self {
            case .settingSaveFailed:
                return "语言设置保存失败"
            case .invalidLanguage:
                return "无效的语言选择"
            }
        }
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
            "menu_charts": "Charts Analysis...",
            "menu_check_updates": "Check for Updates...",
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
            "sidebar_general": "General",
            "sidebar_scholars": "Scholars",
            "sidebar_data": "Data",
            "section_data_export": "Export",
            "section_data_import": "Import",
            "label_export_citation_data": "Export citation data",
            "label_import_citation_data": "Import citation data from file",
            
            // Scholar Management
            "scholar_name": "Name",
            "scholar_id": "Scholar ID",
            "scholar_citations": "Citations",
            "scholar_last_updated": "Last Updated",
            "button_add_scholar": "Add Scholar",
            "button_remove": "Remove",
            "button_refresh_data": "Refresh Data",
            "remove_scholar_title": "Remove Scholar",
            "remove_scholar_message": "Are you sure you want to remove this scholar?",
            "remove_scholars_title": "Remove Scholars",
            "remove_scholars_message": "Are you sure you want to remove the selected scholars?",
            
            // Settings Options
            "setting_update_interval": "Auto Update Interval:",
            "setting_show_in_dock": "Show in Dock:",
            "setting_show_in_menubar": "Show in Menu Bar:",
            "setting_launch_at_login": "Launch at Login:",
            "setting_language": "Language:",
            "setting_open_charts": "Charts Window:",
            
            // Language Names
            "language_english": "English",
            "language_chinese": "Simplified Chinese",
            "language_japanese": "Japanese",
            "language_korean": "Korean",
            "language_spanish": "Spanish",
            "language_french": "French",
            "language_german": "German",
            
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
            "button_open_charts": "Open Charts",
            
            // Data Repair
            "button_edit_entry": "Edit Entry",
            "button_delete_entries": "Delete Selected",
            "button_restore_to_point": "Restore to Point",
            "button_refresh_from_point": "Refresh from Point",
            "button_export_data": "Export Data",
            "button_data_management": "Data Management",
            "button_save": "Save",
            "button_delete": "Delete",
            "button_restore": "Restore",
            "button_refresh": "Refresh",
            
            "window_data_management": "Citation Data Management",
            "charts_window_title": "CiteTrack - Citation Charts",
            
            // iCloud Sync
            "section_icloud_sync": "iCloud Sync",
            "setting_icloud_sync_enabled": "Automatic Sync:",
            "setting_icloud_sync_description": "Automatically sync your citation data with iCloud Drive",
            "setting_icloud_status": "Status:",
            "setting_open_icloud_folder": "iCloud Folder:",
            "setting_open_icloud_folder_description": "Open CiteTrack folder in iCloud Drive",
            
            "button_export_to_icloud": "Export to iCloud",
            "button_import_from_icloud": "Import from iCloud",
            "button_open_folder": "Open Folder",
            "button_import": "Import",
            
            "label_export_to_icloud": "Export to iCloud Folder:",
            "label_import_from_icloud": "Import from iCloud Folder:",
            
            "show_in_icloud_drive": "Show in iCloud Drive",
            "sync_now": "Sync Now",
            "syncing": "Syncing...",
            "manual_import_file": "Import from File",
            "export_to_device": "Export to File",
            
            "exporting_to_icloud": "Exporting to iCloud",
            "importing_from_icloud": "Importing from iCloud", 
            "please_wait_exporting": "Please wait while your data is being exported to iCloud Drive...",
            "please_wait_importing": "Please wait while your data is being imported from iCloud Drive...",
            
            "export_to_icloud_success": "Your citation data has been successfully saved to iCloud Drive in the CiteTrack folder.",
            "export_to_icloud_success_message": "Data has been successfully exported to iCloud Drive. You can access it from the Files app on iOS or Finder on macOS.",
            "import_from_icloud_title": "Import from iCloud",
            "import_from_icloud_warning": "This will replace your current data with the data from iCloud. Are you sure you want to continue?",
            "import_from_icloud_success": "Data successfully imported from iCloud:",
            "citation_data_imported": "Citation data imported",
            "config_imported": "App configuration imported",
            "no_data_found": "No Data Found",
            "no_icloud_data_found": "No CiteTrack data found in iCloud Drive.",
            
            "import_file_panel_message": "Select the data file exported from iOS (citation_data.json or ios_data.json)",
            "import_success_title": "Import Successful",
            "import_success_message": "Successfully imported %d scholars and %d history entries",
            "import_failed_title": "Import Failed",
            "sync_success_title": "Sync Successful",
            "sync_failed_title": "Sync Failed",
            "sync_export_success_message": "Data exported to iCloud successfully",
            "sync_import_success_message": "Data imported from iCloud successfully",
            "language_change_failed_title": "Language Change Failed",
            "language_change_failed_message": "Unable to switch to the selected language. The previous setting has been restored.",
            "icloud_status_not_available": "iCloud Drive not available",
            "icloud_status_found_backup_with_date": "Found previous backup - %@",
            "icloud_status_found_backup_unknown": "Found previous backup - Unknown date",
            "icloud_status_ready_to_sync": "iCloud Drive available - Ready to sync",
            "icloud_status_enabled_last_sync": "Syncing enabled - Last sync: %@",
            "icloud_status_enabled_ready": "Syncing enabled - Ready",
            "icloud_status_enabled_setting_up": "Syncing enabled - Setting up...",
            "icloud_error_not_available": "iCloud Drive is not available. Please check your iCloud settings.",
            "icloud_error_invalid_url": "Invalid iCloud URL",
            "icloud_error_invalid_file_format": "Invalid file format",
            "icloud_error_folder_creation_failed": "Failed to create CiteTrack folder in iCloud",
            "icloud_error_file_not_found": "No data file found in iCloud. Please export data first.",
            "icloud_error_export_failed": "Export failed: %@",
            "icloud_error_import_failed": "Import failed: %@",
            "icloud_cloudkit_unavailable": "CloudKit import not available, please use iCloud Drive sync",
            
            "icloud_sync_enabled_title": "iCloud Sync Enabled",
            "icloud_sync_enabled_message": "Your citation data will now be automatically synced with iCloud Drive. An initial sync is being performed.",
            "icloud_sync_disabled_title": "iCloud Sync Disabled", 
            "icloud_sync_disabled_message": "Automatic syncing with iCloud Drive has been disabled. Your local data remains unchanged.",
            
            "column_timestamp": "Date & Time",
            "column_citations": "Citations",
            "column_change": "Change",
            "column_source": "Source",
            "column_actions": "Actions",
            
            "edit_entry_title": "Edit Citation Entry",
            "edit_entry_message": "Modify the citation count for this entry:",
            "delete_entries_title": "Delete Entries",
            "delete_entries_message": "Are you sure you want to delete %d selected entries? This action cannot be undone.",
            "restore_data_title": "Restore Data",
            "restore_data_message": "This will delete all data after %@ and restore the citation count to that point. Continue?",
            "refresh_from_point_title": "Refresh Data",
            "refresh_from_point_message": "This will fetch current citation data and update from %@. Continue?",
            
            // Error Messages
            "error_empty_input": "Empty Input",
            "error_empty_input_message": "Please enter a valid Google Scholar user ID or link",
            "error_scholar_exists": "Scholar Already Exists",
            "error_scholar_exists_message": "This scholar is already in the list",
            "error_invalid_scholar_id": "Invalid Scholar ID",
            "error_invalid_scholar_id_message": "Please enter a valid Google Scholar user ID or complete link",
            "add_scholar_hint": "%@",
            "error_invalid_format": "Invalid Input Format",
            "error_no_scholars_for_charts": "No Scholar Data",
            "error_no_scholars_for_charts_message": "Please add scholar information in Preferences first, then you can view chart analysis.",
            "error_invalid_format_message": "Please enter a valid Google Scholar user ID or complete link\n\nSupported formats:\n• Direct user ID\n• https://scholar.google.com/citations?user=USER_ID",
            "error_fetch_failed": "Failed to Fetch Scholar Info",
            "error_fetch_failed_message": "Scholar added as %@, but unable to get detailed info: %@",
            "error_no_selection": "Please select a scholar to remove",
            "error_no_scholars_to_update": "No scholars to update",
            "network_timeout_message": "Request timed out. Please check your network connection.",
            "rate_limit_message": "Too many requests. Please try again later.",
            "server_error_message": "Server error: %d",
            
            // Success Messages
            "success_scholar_added": "Scholar Added Successfully",
            "success_scholar_added_message": "Scholar %@ added with %d citations",
            
            // Welcome Dialog
            "welcome_title": "Welcome to CiteTrack",
            "welcome_message": "This is a professional macOS menu bar app for real-time monitoring of your Google Scholar citations.\n\nSmall but powerful, professional and reliable.\n\nPlease add scholar information to get started.",
            "button_open_settings": "Open Settings",
            "button_later": "Later",
            
            // Update Results
            "update_result_with_changes": "Successfully updated %d of %d scholars",
            "update_result_no_changes": "Successfully updated %d of %d scholars\n\nNo citation count changes",
            "change_details": "Change Details",
            
            // Chart Messages
            "refresh_failed": "Refresh Failed",
            "refresh_failed_message": "Failed to refresh data: %@",
            "no_data_to_export": "No Data to Export",
            "no_data_to_export_message": "No citation history found for %@ in the selected time range.",
            "export_successful": "Export Successful",
            "export_successful_message": "Data exported to %@\nSize: %d bytes",
            "export_failed": "Export Failed",
            "export_failed_message": "Failed to save file: %@",
            "charts_error_title": "Charts Error",
            "charts_error_message": "Failed to create charts window. Please try again.",
            
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
            "update_completed_message": "%d of %d scholars updated successfully.",
            "update_progress_title": "Updating Citations",
            "update_result_message": "%d of %d scholars updated successfully. %d failed.",
            "updating_all_scholars": "Updating All Scholars",
            "updating_selected_scholars": "Updating Selected Scholars",
            "please_wait_updating": "Please wait while updating scholar information...",
            "button_update": "Update",
            "error_no_scholars": "No Scholars",
            "error_no_scholars_message": "Please add scholars first.",
            
            // Refresh Status
            "refresh_completed": "Refresh Completed",
            "refresh_success_message": "All %d scholars updated successfully.",
            "refresh_partial_message": "%d of %d scholars updated successfully. %d failed.",
            
            // Core Data Errors
            "error_database_title": "Database Error",
            "error_database_message": "A database error occurred: %@\n\nThe application will continue to work, but some data may not be saved properly.",
            "button_ok": "OK",
            
            // Citation History
            "data_source_automatic": "Automatic",
            "data_source_manual": "Manual",
            "trend_increasing": "Increasing",
            "trend_decreasing": "Decreasing",
            "trend_stable": "Stable",
            "trend_unknown": "Unknown",
            "time_range_last_week": "Last Week",
            "time_range_last_month": "Last Month",
            "time_range_last_quarter": "Last Quarter",
            "time_range_last_year": "Last Year",
            "time_range_custom": "Custom Range",
            "time_range_custom_title": "Custom Time Range",
            "time_range_custom_message": "Select a start and end date to filter citation history.",
            "citation_change_increase": "Increased by %d citations",
            "citation_change_decrease": "Decreased by %d citations",
            "citation_change_no_change": "No change in citations",
            "button_apply": "Apply",
            "label_start_date": "Start",
            "label_end_date": "End",
            "label_scholar": "Scholar:",
            "label_time_range_short": "Time:",
            "label_chart_type": "Type:",
            
            // Additional Error Messages
            "data_load_failed": "Data Load Failed",
            
            // Notifications
            "notification_type_system": "System Notification",
            "notification_type_popup": "Popup Alert",
            "notification_type_menu_bar": "Menu Bar Badge",
            "notification_title_single": "Citation Update - %@",
            "notification_popup_title": "Citation Update",
            "notification_popup_body": "%@: %@",
            "notification_multiple_updates_header": "Multiple citation updates:",
            "notification_multiple_updates_increase": "+%d citations",
            "notification_multiple_updates_decrease": "-%d citations",
            "notification_title_multiple": "Citation Updates",
            "notification_affected_scholars": "Affected scholars: %@",
            "notification_enable_checkbox": "Enable citation change notifications",
            "notification_threshold_label": "Notification threshold:",
            "notification_threshold_placeholder": "5",
            "notification_types_label": "Notification types:",
            "notification_type_system_checkbox": "System notifications",
            "notification_type_popup_checkbox": "Popup alerts",
            "notification_type_menu_bar_checkbox": "Menu bar indicators",
            "notification_sound_checkbox": "Play notification sound",
            "notification_quiet_hours_checkbox": "Enable quiet hours",
            "notification_quiet_hours_from": "From:",
            "notification_quiet_hours_to": "To:",
            
            // Statistics
            "data_points": "Data Points",
            "total_change": "Total Change",
            "citations_label": "Citations",
            "overall_label": "Overall",
            "trend_label": "Trend",
            "no_statistics_available": "No statistics available",
            "growth_rate": "Growth Rate",
            "label_total": "Total",
            "label_overall": "Overall",
            "total_citations": "Total Citations",
            "monthly_change": "Monthly Change",
            "dashboard_subtitle_all_time": "All time",
            "dashboard_subtitle_this_period": "This period",
            "dashboard_subtitle_percentage": "Percentage",
            "dashboard_title_insights": "📊 Insights",
            
            // Data Repair
            "data_repair_title": "Data Repair",
            "data_repair_load_failed_title": "Failed to load history",
            "data_repair_select_entry_edit": "Please select an entry to edit",
            "data_repair_select_entries_delete": "Please select entries to delete",
            "data_repair_select_restore_point": "Please select a restore point",
            "data_repair_select_start_point": "Please select a starting point",
            "data_repair_update_success": "Entry updated successfully",
            "data_repair_update_failed_title": "Update failed",
            "data_repair_delete_success": "Entries deleted successfully",
            "data_repair_delete_failed_title": "Delete failed",
            "data_repair_restore_success": "Data restored successfully",
            "data_repair_restore_failed_title": "Restore failed",
            "data_repair_refresh_success": "Data refreshed successfully",
            "data_repair_refresh_failed_title": "Refresh failed",
            "button_edit": "Edit"
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
            "menu_charts": "图表分析...",
            "menu_check_updates": "检查更新...",
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
            "sidebar_general": "通用",
            "sidebar_scholars": "学者",
            "sidebar_data": "数据",
            "section_data_export": "导出",
            "section_data_import": "导入",
            "label_export_citation_data": "导出引用数据",
            "label_import_citation_data": "从文件导入引用数据",
            
            // Scholar Management
            "scholar_name": "姓名",
            "scholar_id": "学者ID",
            "scholar_citations": "引用量",
            "scholar_last_updated": "最后更新",
            "button_add_scholar": "添加学者",
            "button_remove": "删除",
            "button_refresh_data": "刷新数据",
            "remove_scholar_title": "删除学者",
            "remove_scholar_message": "确定要删除该学者吗？",
            "remove_scholars_title": "删除学者",
            "remove_scholars_message": "确定要删除选中的学者吗？",
            
            // Settings Options
            "setting_update_interval": "自动更新间隔:",
            "setting_show_in_dock": "在Dock中显示:",
            "setting_show_in_menubar": "在菜单栏中显示:",
            "setting_launch_at_login": "随系统启动:",
            "setting_language": "语言:",
            "setting_open_charts": "图表窗口:",
            
            // Language Names
            "language_english": "英语",
            "language_chinese": "简体中文",
            "language_japanese": "日语",
            "language_korean": "韩语",
            "language_spanish": "西班牙语",
            "language_french": "法语",
            "language_german": "德语",
            
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
            "add_scholar_hint": "%@",
            "button_add": "添加",
            "button_cancel": "取消",
            "button_open_charts": "打开图表",
            "error_invalid_scholar_id": "无效的Scholar ID",
            "error_invalid_scholar_id_message": "请输入有效的Google Scholar用户ID或完整链接",
            
            // Data Repair
            "button_edit_entry": "编辑条目",
            "button_delete_entries": "删除选中",
            "button_restore_to_point": "恢复到此点",
            "button_refresh_from_point": "从此点刷新",
            "button_export_data": "导出数据",
            "button_data_management": "数据管理",
            "button_save": "保存",
            "button_delete": "删除",
            "button_restore": "恢复",
            "button_refresh": "刷新",
            
            "window_data_management": "引用数据管理",
            "charts_window_title": "CiteTrack - 引用图表",
            
            // iCloud Sync
            "section_icloud_sync": "iCloud同步",
            "setting_icloud_sync_enabled": "自动同步:",
            "setting_icloud_sync_description": "自动将您的引用数据与iCloud Drive同步",
            "setting_icloud_status": "状态:",
            "setting_open_icloud_folder": "iCloud文件夹:",
            "setting_open_icloud_folder_description": "在iCloud Drive中打开CiteTrack文件夹",
            
            "button_export_to_icloud": "导出到iCloud",
            "button_import_from_icloud": "从iCloud导入",
            "button_open_folder": "打开文件夹",
            "button_import": "导入",
            
            "label_export_to_icloud": "导出到iCloud文件夹：",
            "label_import_from_icloud": "从iCloud文件夹导入：",
            
            "show_in_icloud_drive": "在iCloud Drive中显示",
            "sync_now": "立即同步",
            "syncing": "正在同步...",
            "manual_import_file": "从文件导入",
            "export_to_device": "导出到文件",
            
            "exporting_to_icloud": "正在导出到iCloud",
            "importing_from_icloud": "正在从iCloud导入",
            "please_wait_exporting": "请等待，正在将您的数据导出到iCloud Drive...",
            "please_wait_importing": "请等待，正在从iCloud Drive导入您的数据...",
            
            "export_to_icloud_success": "您的引用数据已成功保存到iCloud Drive的CiteTrack文件夹中。",
            "export_to_icloud_success_message": "数据已成功导出到iCloud Drive。您可以在iOS的文件应用或macOS的访达中访问它。",
            "import_from_icloud_title": "从iCloud导入",
            "import_from_icloud_warning": "这将用iCloud中的数据替换您当前的数据。您确定要继续吗？",
            "import_from_icloud_success": "数据已成功从iCloud导入:",
            "citation_data_imported": "引用数据已导入",
            "config_imported": "应用配置已导入",
            "no_data_found": "未找到数据",
            "no_icloud_data_found": "在iCloud Drive中未找到CiteTrack数据。",
            
            "import_file_panel_message": "选择从iOS导出的数据文件（citation_data.json 或 ios_data.json）",
            "import_success_title": "导入成功",
            "import_success_message": "成功导入 %d 位学者和 %d 条历史记录",
            "import_failed_title": "导入失败",
            "sync_success_title": "同步成功",
            "sync_failed_title": "同步失败",
            "sync_export_success_message": "数据已成功导出到 iCloud",
            "sync_import_success_message": "数据已成功从 iCloud 导入",
            "language_change_failed_title": "语言切换失败",
            "language_change_failed_message": "无法切换到所选语言，已恢复到之前的设置。",
            "icloud_status_not_available": "iCloud Drive 不可用",
            "icloud_status_found_backup_with_date": "找到之前的备份 - %@",
            "icloud_status_found_backup_unknown": "找到之前的备份 - 未知时间",
            "icloud_status_ready_to_sync": "iCloud Drive 可用 - 可开始同步",
            "icloud_status_enabled_last_sync": "已启用同步 - 上次同步：%@",
            "icloud_status_enabled_ready": "已启用同步 - 准备就绪",
            "icloud_status_enabled_setting_up": "已启用同步 - 正在设置...",
            "icloud_error_not_available": "iCloud Drive 不可用。请检查您的 iCloud 设置。",
            "icloud_error_invalid_url": "无效的 iCloud URL",
            "icloud_error_invalid_file_format": "无效的文件格式",
            "icloud_error_folder_creation_failed": "无法在 iCloud 中创建 CiteTrack 文件夹",
            "icloud_error_file_not_found": "在iCloud中未找到数据文件。请先导出数据。",
            "icloud_error_export_failed": "导出失败：%@",
            "icloud_error_import_failed": "导入失败：%@",
            "icloud_cloudkit_unavailable": "CloudKit 导入不可用，请使用 iCloud Drive 同步",
            
            "icloud_sync_enabled_title": "已启用iCloud同步",
            "icloud_sync_enabled_message": "您的引用数据现在将自动与iCloud Drive同步。正在执行初始同步。",
            "icloud_sync_disabled_title": "已禁用iCloud同步",
            "icloud_sync_disabled_message": "已禁用与iCloud Drive的自动同步。您的本地数据保持不变。",
            
            "column_timestamp": "日期时间",
            "column_citations": "引用数",
            "column_change": "变化",
            "column_source": "来源",
            "column_actions": "操作",
            
            "edit_entry_title": "编辑引用条目",
            "edit_entry_message": "修改此条目的引用数:",
            "delete_entries_title": "删除条目",
            "delete_entries_message": "确定要删除 %d 个选中的条目吗? 此操作无法撤销。",
            "restore_data_title": "恢复数据",
            "restore_data_message": "这将删除 %@ 之后的所有数据并恢复到该时间点的引用数。继续?",
            "refresh_from_point_title": "刷新数据",
            "refresh_from_point_message": "这将获取当前引用数据并从 %@ 开始更新。继续?",
            
            // Error Messages
            "error_empty_input": "输入为空",
            "error_empty_input_message": "请输入有效的Google Scholar用户ID或链接",
            "error_scholar_exists": "学者已存在",
            "error_scholar_exists_message": "该学者已在列表中",
            "error_invalid_format": "输入格式错误",
            "error_invalid_format_message": "请输入有效的Google Scholar用户ID或完整链接\n\n支持格式：\n• 直接输入用户ID\n• https://scholar.google.com/citations?user=USER_ID",
            "error_no_scholars_for_charts": "无学者数据",
            "error_no_scholars_for_charts_message": "请先在偏好设置中添加学者信息，然后才能查看图表分析。",
            "error_fetch_failed": "获取学者信息失败",
            "error_fetch_failed_message": "学者已添加为 %@，但无法获取详细信息：%@",
            "error_no_selection": "请选择要删除的学者",
            "error_no_scholars_to_update": "没有可更新的学者",
            "network_timeout_message": "请求超时，请检查网络连接",
            "rate_limit_message": "访问过于频繁，请稍后再试",
            "server_error_message": "服务器错误: %d",
            
            // Success Messages
            "success_scholar_added": "添加成功",
            "success_scholar_added_message": "学者 %@ 已添加，引用量：%d",
            
            // Welcome Dialog
            "welcome_title": "欢迎使用 CiteTrack",
            "welcome_message": "这是一个精美专业的macOS菜单栏应用，用于实时监控您的Google Scholar引用量。\n\n小而精，专业可靠。\n\n请先添加学者信息来开始使用。",
            "button_open_settings": "打开设置",
            "button_later": "稍后",
            
            // Update Results
            "update_result_with_changes": "成功更新 %d/%d 位学者的数据",
            "update_result_no_changes": "成功更新 %d/%d 位学者的数据\n\n暂无引用量变化",
            "change_details": "变化详情",
            
            // Chart Messages
            "refresh_failed": "刷新失败",
            "refresh_failed_message": "刷新数据失败: %@",
            "no_data_to_export": "无可导出数据",
            "no_data_to_export_message": "在选定的时间范围内未找到 %@ 的引用历史。",
            "export_successful": "导出成功",
            "export_successful_message": "数据已导出到 %@\n大小: %d 字节",
            "export_failed": "导出失败",
            "export_failed_message": "保存文件失败: %@",
            "button_apply": "应用",
            "label_start_date": "开始",
            "label_end_date": "结束",
            "label_scholar": "学者：",
            "label_time_range_short": "时间：",
            "label_chart_type": "类型：",
            "charts_error_title": "图表错误",
            "charts_error_message": "无法创建图表窗口，请重试。",
            
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
            "update_completed_message": "已成功更新 %d 个学者（共 %d 个）。",
            "update_progress_title": "更新引用量",
            "update_result_message": "%d 个学者中的 %d 个更新成功，%d 个失败。",
            "updating_all_scholars": "更新所有学者",
            "updating_selected_scholars": "更新选中的学者",
            "please_wait_updating": "正在更新学者信息，请稍候...",
            "button_update": "更新",
            "error_no_scholars": "无学者",
            "error_no_scholars_message": "请先添加学者。",
            
            // Refresh Status
            "refresh_completed": "刷新完成",
            "refresh_success_message": "所有 %d 个学者更新成功。",
            "refresh_partial_message": "%d 个学者更新成功，%d 个失败。",
            
            // Core Data Errors
            "error_database_title": "数据库错误",
            "error_database_message": "发生数据库错误：%@\n\n应用程序将继续工作，但某些数据可能无法正确保存。",
            "button_ok": "确定",
            
            // Citation History
            "data_source_automatic": "自动",
            "data_source_manual": "手动",
            "trend_increasing": "上升",
            "trend_decreasing": "下降",
            "trend_stable": "稳定",
            "trend_unknown": "未知",
            "time_range_last_week": "最近一周",
            "time_range_last_month": "最近一月",
            "time_range_last_quarter": "最近三月",
            "time_range_last_year": "最近一年",
            "time_range_custom": "自定义范围",
            "citation_change_increase": "增加了 %d 次引用",
            "citation_change_decrease": "减少了 %d 次引用",
            "citation_change_no_change": "引用量无变化",
            
            // Additional Error Messages
            "data_load_failed": "数据加载失败",
            
            // Notifications
            "notification_type_system": "系统通知",
            "notification_type_popup": "弹窗提醒",
            "notification_type_menu_bar": "菜单栏徽标",
            "notification_title_single": "引用更新 - %@",
            "notification_popup_title": "引用更新",
            "notification_popup_body": "%@: %@",
            "notification_multiple_updates_header": "多个引用量更新：",
            "notification_multiple_updates_increase": "+%d 次引用",
            "notification_multiple_updates_decrease": "-%d 次引用",
            "notification_title_multiple": "引用量更新",
            "notification_affected_scholars": "受影响的学者：%@",
            "notification_enable_checkbox": "启用引用量变化通知",
            "notification_threshold_label": "通知阈值：",
            "notification_threshold_placeholder": "5",
            "notification_types_label": "通知类型：",
            "notification_type_system_checkbox": "系统通知",
            "notification_type_popup_checkbox": "弹窗提醒",
            "notification_type_menu_bar_checkbox": "菜单栏指示",
            "notification_sound_checkbox": "播放通知提示音",
            "notification_quiet_hours_checkbox": "启用安静时段",
            "notification_quiet_hours_from": "开始：",
            "notification_quiet_hours_to": "结束：",
            
            // Statistics
            "data_points": "数据点",
            "total_change": "总变化",
            "citations_label": "引用量",
            "overall_label": "总体",
            "trend_label": "趋势",
            "no_statistics_available": "暂无统计数据",
            "growth_rate": "增长率",
            "label_total": "总计",
            "label_overall": "总体",
            "total_citations": "总引用量",
            "monthly_change": "月度变化",
            "dashboard_subtitle_all_time": "全部时间",
            "dashboard_subtitle_this_period": "当前周期",
            "dashboard_subtitle_percentage": "百分比",
            "dashboard_title_insights": "📊 洞察",
            
            // Data Repair
            "data_repair_title": "数据修复",
            "data_repair_load_failed_title": "历史记录加载失败",
            "data_repair_select_entry_edit": "请选择要编辑的条目",
            "data_repair_select_entries_delete": "请选择要删除的条目",
            "data_repair_select_restore_point": "请选择一个恢复点",
            "data_repair_select_start_point": "请选择一个起始点",
            "data_repair_update_success": "条目更新成功",
            "data_repair_update_failed_title": "更新失败",
            "data_repair_delete_success": "条目删除成功",
            "data_repair_delete_failed_title": "删除失败",
            "data_repair_restore_success": "数据恢复成功",
            "data_repair_restore_failed_title": "恢复失败",
            "data_repair_refresh_success": "数据刷新成功",
            "data_repair_refresh_failed_title": "刷新失败",
            "button_edit": "编辑"
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
            "menu_check_updates": "アップデートを確認...",
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
            "window_data_management": "引用データ管理",
            "charts_window_title": "CiteTrack - 引用チャート",
            "sidebar_general": "一般",
            "sidebar_scholars": "研究者",
            "sidebar_data": "データ",
            "section_data_export": "エクスポート",
            "section_data_import": "インポート",
            "label_export_citation_data": "引用データをエクスポート",
            "label_import_citation_data": "ファイルから引用データをインポート",
            
            // Scholar Management
            "scholar_name": "名前",
            "scholar_id": "研究者ID",
            "scholar_citations": "引用数",
            "scholar_last_updated": "最終更新",
            "button_add_scholar": "研究者を追加",
            "button_remove": "削除",
            "button_refresh": "データを更新",
            "remove_scholar_title": "研究者を削除",
            "remove_scholar_message": "この研究者を削除してもよろしいですか？",
            "remove_scholars_title": "研究者を削除",
            "remove_scholars_message": "選択した研究者を削除してもよろしいですか？",
            
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
            "button_export_to_icloud": "iCloudにエクスポート",
            "button_import_from_icloud": "iCloudからインポート",
            "button_open_folder": "フォルダを開く",
            "button_import": "インポート",
            
            "label_export_to_icloud": "iCloudフォルダにエクスポート:",
            "label_import_from_icloud": "iCloudフォルダからインポート:",
            
            "show_in_icloud_drive": "iCloud Driveに表示",
            "sync_now": "今すぐ同期",
            "syncing": "同期中...",
            "manual_import_file": "ファイルからインポート",
            "export_to_device": "ファイルにエクスポート",
            
            "export_to_icloud_success_message": "データがiCloud Driveに正常にエクスポートされました。iOSのファイルアプリまたはmacOSのFinderからアクセスできます。",
            
            "import_file_panel_message": "iOSからエクスポートしたデータファイル（citation_data.json または ios_data.json）を選択してください",
            "import_success_title": "インポート成功",
            "import_success_message": "研究者を %d 人、履歴を %d 件インポートしました",
            "import_failed_title": "インポート失敗",
            "sync_success_title": "同期成功",
            "sync_failed_title": "同期失敗",
            "sync_export_success_message": "データをiCloudに正常にエクスポートしました",
            "sync_import_success_message": "データをiCloudから正常にインポートしました",
            "language_change_failed_title": "言語の切り替えに失敗しました",
            "language_change_failed_message": "選択した言語に切り替えられませんでした。以前の設定に戻しました。",
            "icloud_status_not_available": "iCloud Driveは利用できません",
            "icloud_status_found_backup_with_date": "以前のバックアップを検出 - %@",
            "icloud_status_found_backup_unknown": "以前のバックアップを検出 - 日時不明",
            "icloud_status_ready_to_sync": "iCloud Driveは利用可能 - 同期の準備完了",
            "icloud_status_enabled_last_sync": "同期が有効 - 最終同期: %@",
            "icloud_status_enabled_ready": "同期が有効 - 準備完了",
            "icloud_status_enabled_setting_up": "同期が有効 - 設定中...",
            "icloud_error_not_available": "iCloud Driveが利用できません。iCloud設定を確認してください。",
            "icloud_error_invalid_url": "無効なiCloud URL",
            "icloud_error_invalid_file_format": "無効なファイル形式",
            "icloud_error_folder_creation_failed": "iCloudにCiteTrackフォルダを作成できませんでした",
            "icloud_error_file_not_found": "iCloudにデータファイルが見つかりません。まずデータをエクスポートしてください。",
            "icloud_error_export_failed": "エクスポートに失敗しました: %@",
            "icloud_error_import_failed": "インポートに失敗しました: %@",
            "icloud_cloudkit_unavailable": "CloudKitのインポートは利用できません。iCloud Drive同期を使用してください",
            
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
            "error_no_scholars_to_update": "更新する研究者がありません",
            "network_timeout_message": "タイムアウトしました。ネットワーク接続を確認してください。",
            "rate_limit_message": "リクエストが多すぎます。しばらくしてから再試行してください。",
            "server_error_message": "サーバーエラー: %d",
            
            // Success Messages
            "success_scholar_added": "研究者が正常に追加されました",
            "success_scholar_added_message": "研究者 %@ が追加されました（引用数：%d）",
            
            // Welcome Dialog
            "welcome_title": "CiteTrackへようこそ",
            "welcome_message": "これはGoogle Scholar引用数をリアルタイムで監視するプロフェッショナルなmacOSメニューバーアプリです。\n\n小さくても強力、プロフェッショナルで信頼性が高い。\n\n開始するには研究者情報を追加してください。",
            "button_open_settings": "設定を開く",
            "button_later": "後で",
            
            // Update Results
            "update_result_with_changes": "%d/%d 人の研究者の更新が成功しました",
            "update_result_no_changes": "%d/%d 人の研究者の更新が成功しました\n\n引用数の変化はありません",
            "change_details": "変更詳細",
            
            // Chart Messages
            "refresh_failed": "更新失敗",
            "refresh_failed_message": "データの更新に失敗しました: %@",
            "no_data_to_export": "エクスポートするデータがありません",
            "no_data_to_export_message": "%@ の選択された期間に引用数の履歴が見つかりませんでした。",
            "export_successful": "エクスポート成功",
            "export_successful_message": "データは %@ にエクスポートされました\nサイズ: %d バイト",
            "export_failed": "エクスポート失敗",
            "export_failed_message": "ファイルの保存に失敗しました: %@",
            "charts_error_title": "チャートエラー",
            "charts_error_message": "チャートウィンドウを作成できませんでした。再度お試しください。",
            
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
            "update_completed_message": "%d人の研究者が正常に更新されました（合計%d人）。",
            "update_progress_title": "引用数更新中",
            "update_result_message": "%d人の研究者のうち%d人が正常に更新されました。%d人が失敗しました。",
            "updating_all_scholars": "すべての研究者を更新中",
            "updating_selected_scholars": "選択した研究者を更新中",
            "please_wait_updating": "研究者情報を更新しています。しばらくお待ちください...",
            "button_update": "更新",
            "error_no_scholars": "研究者なし",
            "error_no_scholars_message": "まず研究者を追加してください。",
            
            // Refresh Status
            "refresh_completed": "更新完了",
            "refresh_success_message": "%d人の研究者全員が正常に更新されました。",
            "refresh_partial_message": "%d人の研究者のうち%d人が正常に更新されました。%d人が失敗しました。",
            
            // Core Data Errors
            "error_database_title": "データベースエラー",
            "error_database_message": "データベースエラーが発生しました：%@\n\nアプリケーションは動作を続けますが、一部のデータが正しく保存されない可能性があります。",
            "button_ok": "OK",
            
            // Citation History
            "data_source_automatic": "自動",
            "data_source_manual": "手動",
            "trend_increasing": "上昇",
            "trend_decreasing": "下降",
            "trend_stable": "安定",
            "trend_unknown": "不明",
            "time_range_last_week": "過去1週間",
            "time_range_last_month": "過去1ヶ月",
            "time_range_last_quarter": "過去3ヶ月",
            "time_range_last_year": "過去1年",
            "time_range_custom": "カスタム範囲",
            "time_range_custom_title": "カスタム期間の選択",
            "time_range_custom_message": "引用データを絞り込む開始日と終了日を選択してください。",
            "citation_change_increase": "%d件の引用が増加",
            "citation_change_decrease": "%d件の引用が減少",
            "citation_change_no_change": "引用数に変化なし",
            "button_apply": "適用",
            "label_start_date": "開始",
            "label_end_date": "終了",
            "label_scholar": "研究者:",
            "label_time_range_short": "期間:",
            "label_chart_type": "種類:",
            
            // Additional Error Messages
            "data_load_failed": "データの読み込みに失敗しました",
            
            // Notifications
            "notification_type_system": "システム通知",
            "notification_type_popup": "ポップアップ通知",
            "notification_type_menu_bar": "メニューバーバッジ",
            "notification_title_single": "引用数更新 - %@",
            "notification_popup_title": "引用数の更新",
            "notification_popup_body": "%@: %@",
            "notification_multiple_updates_header": "複数の引用数更新:",
            "notification_multiple_updates_increase": "+%d 件の引用",
            "notification_multiple_updates_decrease": "-%d 件の引用",
            "notification_title_multiple": "引用数の更新",
            "notification_affected_scholars": "影響を受けた研究者: %@",
            "notification_enable_checkbox": "引用数変化の通知を有効にする",
            "notification_threshold_label": "通知の閾値:",
            "notification_threshold_placeholder": "5",
            "notification_types_label": "通知の種類:",
            "notification_type_system_checkbox": "システム通知",
            "notification_type_popup_checkbox": "ポップアップ通知",
            "notification_type_menu_bar_checkbox": "メニューバーインジケータ",
            "notification_sound_checkbox": "通知音を再生",
            "notification_quiet_hours_checkbox": "サイレント時間を有効にする",
            "notification_quiet_hours_from": "開始:",
            "notification_quiet_hours_to": "終了:",
            
            // Statistics
            "data_points": "データポイント",
            "total_change": "総変化",
            "citations_label": "引用数",
            "overall_label": "全体",
            "trend_label": "トレンド",
            "no_statistics_available": "統計データがありません",
            "growth_rate": "成長率",
            "label_total": "合計",
            "label_overall": "全体",
            "total_citations": "総引用数",
            "monthly_change": "月間変化",
            "dashboard_subtitle_all_time": "全期間",
            "dashboard_subtitle_this_period": "この期間",
            "dashboard_subtitle_percentage": "割合",
            "dashboard_title_insights": "📊 インサイト",
            
            // Data Repair
            "data_repair_title": "データ修復",
            "data_repair_load_failed_title": "履歴の読み込みに失敗しました",
            "data_repair_select_entry_edit": "編集する項目を選択してください",
            "data_repair_select_entries_delete": "削除する項目を選択してください",
            "data_repair_select_restore_point": "復元ポイントを選択してください",
            "data_repair_select_start_point": "開始ポイントを選択してください",
            "data_repair_update_success": "項目を更新しました",
            "data_repair_update_failed_title": "更新に失敗しました",
            "data_repair_delete_success": "項目を削除しました",
            "data_repair_delete_failed_title": "削除に失敗しました",
            "data_repair_restore_success": "データを復元しました",
            "data_repair_restore_failed_title": "復元に失敗しました",
            "data_repair_refresh_success": "データを更新しました",
            "data_repair_refresh_failed_title": "更新に失敗しました",
            "button_edit": "編集"
        ]
        
        // Add more languages as needed...
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let languageChanged = Notification.Name("LanguageChanged")
    static let languageChangeFailed = Notification.Name("LanguageChangeFailed")
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

// MARK: - String Extension for Localization
extension String {
    var localized: String {
        return LocalizationManager.shared.localized(self)
    }
} 