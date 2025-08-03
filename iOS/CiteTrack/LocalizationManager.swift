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
            case .english: return "English"
            case .chinese: return "简体中文"
            case .japanese: return "日本語"
            case .korean: return "한국어"
            case .spanish: return "Español"
            case .french: return "Français"
            case .german: return "Deutsch"
            }
        }
        
        public var nativeName: String {
            return displayName
        }
        
        public var code: String {
            return rawValue
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // 检测系统语言
        let systemLanguage = Locale.current.languageCode ?? "en"
        let savedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage")
        
        if let saved = savedLanguage, let language = Language(rawValue: saved) {
            self.currentLanguage = language
        } else {
            // 根据系统语言选择默认语言
            switch systemLanguage {
            case "zh":
                self.currentLanguage = .chinese
            case "ja":
                self.currentLanguage = .japanese
            case "ko":
                self.currentLanguage = .korean
            case "es":
                self.currentLanguage = .spanish
            case "fr":
                self.currentLanguage = .french
            case "de":
                self.currentLanguage = .german
            default:
                self.currentLanguage = .english
            }
        }
        
        loadLocalizations()
    }
    
    // MARK: - Public Methods
    
    public func localized(_ key: String) -> String {
        guard let languageDict = localizations[currentLanguage] else {
            return key
        }
        
        return languageDict[key] ?? key
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
            
            // 设置相关
            "general_settings": "General Settings",
            "update_interval": "Update Interval",
            "show_in_dock": "Show in Dock",
            "show_in_menu_bar": "Show in Menu Bar",
            "launch_at_login": "Launch at Login",
            "icloud_sync": "iCloud Sync",
            "notifications": "Notifications",
            "language": "Language",
            "theme": "Theme",
            
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
            "add_scholar": "Add Scholar",
            "scholar_id": "Scholar ID",
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
            "example_url": "Example: scholar.google.com/citations?user=XXXXXXXX",
            "help": "Help",
            "invalid_scholar_id_format": "Invalid Scholar ID format",
            "scholar_not_found": "Scholar not found",
            "rate_limited_error": "Too many requests, please try again later",
            "network_error": "Network error",
            "validation_error": "Validation error",
            "scholar_already_exists": "Scholar already exists",
            "scholar_id_empty": "Scholar ID cannot be empty"
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
            
            // 设置相关
            "general_settings": "常规设置",
            "update_interval": "更新间隔",
            "show_in_dock": "在Dock中显示",
            "show_in_menu_bar": "在菜单栏显示",
            "launch_at_login": "开机启动",
            "icloud_sync": "iCloud同步",
            "notifications": "通知",
            "language": "语言",
            "theme": "主题",
            
            // 通知相关
            "citation_change": "引用量变化",
            "data_update_complete": "数据更新完成",
            "sync_complete": "同步完成",
            
            // 错误信息
            "network_error": "网络错误",
            "parsing_error": "解析错误",
            "scholar_not_found": "未找到学者",
            "invalid_scholar_id": "无效的学者ID",
            "rate_limited": "请求过于频繁",
            
            // 时间范围
            "1week": "1周",
            "1month": "1个月",
            "3months": "3个月",
            "6months": "6个月",
            "1year": "1年",
            "all_time": "全部时间",
            "custom_range": "自定义范围",
            
            // 额外的UI字符串
            "dashboard": "仪表板",
            "add_scholar": "添加学者",
            "scholar_id": "学者ID",
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
            "example_url": "示例: scholar.google.com/citations?user=XXXXXXXX",
            "help": "帮助",
            "invalid_scholar_id_format": "学者ID格式无效",
            "scholar_not_found": "未找到学者",
            "rate_limited_error": "请求过于频繁，请稍后再试",
            "network_error": "网络错误",
            "validation_error": "验证错误",
            "scholar_already_exists": "学者已存在",
            "scholar_id_empty": "学者ID不能为空"
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
            "scholar": "研究者",
            "citations": "引用数",
            "charts": "チャート",
            "settings": "設定",
            "loading": "読み込み中...",
            "error": "エラー",
            "unknown": "不明"
        ]
    }
    
    private func loadKoreanLocalizations() {
        localizations[.korean] = [
            // 基础韩语本地化
            "app_name": "CiteTrack",
            "ok": "확인",
            "cancel": "취소",
            "save": "저장",
            "delete": "삭제",
            "scholar": "학자",
            "citations": "인용수",
            "charts": "차트",
            "settings": "설정",
            "loading": "로딩 중...",
            "error": "오류",
            "unknown": "알 수 없음"
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
            "scholar": "Académico",
            "citations": "Citas",
            "charts": "Gráficos",
            "settings": "Configuración",
            "loading": "Cargando...",
            "error": "Error",
            "unknown": "Desconocido"
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
            "scholar": "Chercheur",
            "citations": "Citations",
            "charts": "Graphiques",
            "settings": "Paramètres",
            "loading": "Chargement...",
            "error": "Erreur",
            "unknown": "Inconnu"
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
            "scholar": "Forscher",
            "citations": "Zitationen",
            "charts": "Diagramme",
            "settings": "Einstellungen",
            "loading": "Laden...",
            "error": "Fehler",
            "unknown": "Unbekannt"
        ]
    }
}

// MARK: - Convenience Extensions
public extension String {
    var localized: String {
        return LocalizationManager.shared.localized(self)
    }
}