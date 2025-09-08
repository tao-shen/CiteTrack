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
            "widget_theme": "Widget Theme",
            
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
            "scholar_id_empty": "Scholar ID cannot be empty",
            "delete_scholar_title": "Delete Scholar",
            "delete_scholar_message": "This will delete the scholar and all related data. Are you sure?",
            "delete_scholar_message_with_name": "This will delete scholar '%@' and all related data. Are you sure?",
            "delete_scholars_message_with_count": "This will delete %d scholars and all related data. Are you sure?",
            "delete_all_scholars_title": "Delete All Scholars",
            "delete_all_scholars_message": "This will delete all scholars and all related data. Are you sure?",
            
            // Widget specific strings
            "citations_label": "Citations",
            "start_tracking": "Start Tracking",
            "add_scholar_to_track": "Add Scholar to Track",
            "tap_to_open_app": "Tap to Open App",
            "academic_influence": "Academic Influence",
            "top_scholars": "Top Scholars",
            "total_citations_label": "Total Citations",
            "updated_at": "Updated at",
            "academic_ranking": "Academic Ranking",
            "add_scholars_to_track": "Add Scholars to Track",
            "tracking_scholars": "Tracking Scholars",
            "latest_data": "Latest Data",
            "average_citations_label": "Average Citations",
            "highest_citations_label": "Highest Citations",
            "this_month": "This Month",
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
            "no_data_available": "No Data Available",
            "scholar_default_name": "Scholar",
            "icloud_available_no_sync": "Not Synced",
            "export_failed_with_message": "Export failed",
            "import_failed_with_message": "Import failed",
            "failed_with_colon": "Failed"
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
            "widget_theme": "小组件主题",
            
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
            "scholar_id_empty": "学者ID不能为空",
            "delete_scholar_title": "删除学者",
            "delete_scholar_message": "将删除该学者及其所有相关数据，是否确认？",
            "delete_scholar_message_with_name": "将删除学者"%@"及其所有相关数据，是否确认？",
            "delete_scholars_message_with_count": "将删除 %d 位学者及其所有相关数据，是否确认？",
            "delete_all_scholars_title": "删除所有学者",
            "delete_all_scholars_message": "将删除所有学者及其所有相关数据，是否确认？",
            
            // Widget specific strings
            "citations_label": "引用数",
            "start_tracking": "开始追踪",
            "add_scholar_to_track": "添加学者开始追踪",
            "tap_to_open_app": "轻触打开App添加学者",
            "academic_influence": "学术影响力",
            "top_scholars": "学者",
            "total_citations_label": "总引用",
            "updated_at": "更新于",
            "academic_ranking": "学术排行榜",
            "add_scholars_to_track": "添加学者开始追踪\n他们的学术影响力",
            "tracking_scholars": "追踪学者",
            "latest_data": "最新数据",
            "average_citations_label": "平均引用",
            "highest_citations_label": "最高引用",
            "this_month": "本月",
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
            "no_data_available": "暂无数据",
            "scholar_default_name": "学者",
            "icloud_available_no_sync": "未同步",
            "export_failed_with_message": "导出失败",
            "import_failed_with_message": "导入失败",
            "failed_with_colon": "失败"
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
            "unknown": "不明",
            // 删除确认新增
            "delete_scholar_title": "研究者を削除",
            "delete_scholar_message": "この研究者と関連データをすべて削除します。よろしいですか？",
            "delete_scholar_message_with_name": "研究者『%@』と関連データをすべて削除します。よろしいですか？",
            "delete_scholars_message_with_count": "%d 名の研究者と関連データをすべて削除します。よろしいですか？",
            "delete_all_scholars_title": "すべての研究者を削除",
            "delete_all_scholars_message": "すべての研究者と関連データを削除します。よろしいですか？",
            
            // Widget specific strings
            "citations_label": "引用数",
            "start_tracking": "追跡開始",
            "add_scholar_to_track": "研究者を追加して追跡開始",
            "tap_to_open_app": "アプリをタップして研究者を追加",
            "academic_influence": "学術的影響力",
            "top_scholars": "研究者",
            "total_citations_label": "総引用数",
            "updated_at": "更新日時",
            "academic_ranking": "学術ランキング",
            "add_scholars_to_track": "研究者を追加して追跡開始\n彼らの学術的影響力",
            "tracking_scholars": "研究者を追跡中",
            "latest_data": "最新データ",
            "average_citations_label": "平均引用数",
            "highest_citations_label": "最高引用数",
            "this_month": "今月",
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
            "citations_unit": "引用",
            "no_data_available": "データなし",
            "scholar_default_name": "研究者",
            "icloud_available_no_sync": "未同期",
            "export_failed_with_message": "エクスポート失敗",
            "import_failed_with_message": "インポート失敗",
            "failed_with_colon": "失敗"
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
            "unknown": "알 수 없음",
            // 삭제 확인 추가
            "delete_scholar_title": "학자 삭제",
            "delete_scholar_message": "이 학자와 모든 관련 데이터를 삭제합니다. 계속하시겠습니까?",
            "delete_scholar_message_with_name": "학자 '%@'와 모든 관련 데이터를 삭제합니다. 계속하시겠습니까?",
            "delete_scholars_message_with_count": "%d명의 학자와 모든 관련 데이터를 삭제합니다. 계속하시겠습니까?",
            "delete_all_scholars_title": "모든 학자 삭제",
            "delete_all_scholars_message": "모든 학자와 관련 데이터를 삭제합니다. 계속하시겠습니까?",
            
            // Widget specific strings
            "citations_label": "인용수",
            "start_tracking": "추적 시작",
            "add_scholar_to_track": "학자를 추가하여 추적 시작",
            "tap_to_open_app": "앱을 탭하여 학자 추가",
            "academic_influence": "학술적 영향력",
            "top_scholars": "학자",
            "total_citations_label": "총 인용수",
            "updated_at": "업데이트 시간",
            "academic_ranking": "학술 순위",
            "add_scholars_to_track": "학자를 추가하여 추적 시작\n그들의 학술적 영향력",
            "tracking_scholars": "학자 추적 중",
            "latest_data": "최신 데이터",
            "average_citations_label": "평균 인용수",
            "highest_citations_label": "최고 인용수",
            "this_month": "이번 달",
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
            "citations_unit": "인용",
            "no_data_available": "데이터 없음",
            "scholar_default_name": "학자",
            "icloud_available_no_sync": "동기화 안됨",
            "export_failed_with_message": "내보내기 실패",
            "import_failed_with_message": "가져오기 실패",
            "failed_with_colon": "실패"
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
            "unknown": "Desconocido",
            // Confirmación de borrado
            "delete_scholar_title": "Eliminar académico",
            "delete_scholar_message": "Se eliminará este académico y todos sus datos relacionados. ¿Continuar?",
            "delete_scholar_message_with_name": "Se eliminará el académico '%@' y todos sus datos relacionados. ¿Continuar?",
            "delete_scholars_message_with_count": "Se eliminarán %d académicos y todos sus datos relacionados. ¿Continuar?",
            "delete_all_scholars_title": "Eliminar todos los académicos",
            "delete_all_scholars_message": "Se eliminarán todos los académicos y todos sus datos relacionados. ¿Continuar?",
            
            // Widget specific strings
            "citations_label": "Citas",
            "start_tracking": "Iniciar Seguimiento",
            "add_scholar_to_track": "Agregar Académico para Seguir",
            "tap_to_open_app": "Toca para Abrir App y Agregar Académico",
            "academic_influence": "Influencia Académica",
            "top_scholars": "Académicos",
            "total_citations_label": "Total de Citas",
            "updated_at": "Actualizado en",
            "academic_ranking": "Ranking Académico",
            "add_scholars_to_track": "Agregar Académicos para Seguir\nSu Influencia Académica",
            "tracking_scholars": "Siguiendo Académicos",
            "latest_data": "Datos Más Recientes",
            "average_citations_label": "Promedio de Citas",
            "highest_citations_label": "Mayor Número de Citas",
            "this_month": "Este Mes",
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
            "citations_unit": "citas",
            "no_data_available": "Sin Datos Disponibles",
            "scholar_default_name": "Académico",
            "icloud_available_no_sync": "No Sincronizado",
            "export_failed_with_message": "Exportación fallida",
            "import_failed_with_message": "Importación fallida",
            "failed_with_colon": "Fallida"
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
            "unknown": "Inconnu",
            // Confirmation de suppression
            "delete_scholar_title": "Supprimer le chercheur",
            "delete_scholar_message": "Cela supprimera ce chercheur et toutes les données associées. Continuer ?",
            "delete_scholar_message_with_name": "Cela supprimera le chercheur '%@' et toutes les données associées. Continuer ?",
            "delete_scholars_message_with_count": "Cela supprimera %d chercheurs et toutes les données associées. Continuer ?",
            "delete_all_scholars_title": "Supprimer tous les chercheurs",
            "delete_all_scholars_message": "Cela supprimera tous les chercheurs et toutes les données associées. Continuer ?",
            
            // Widget specific strings
            "citations_label": "Citations",
            "start_tracking": "Commencer le Suivi",
            "add_scholar_to_track": "Ajouter un Chercheur à Suivre",
            "tap_to_open_app": "Touchez pour Ouvrir l'App et Ajouter un Chercheur",
            "academic_influence": "Influence Académique",
            "top_scholars": "Chercheurs",
            "total_citations_label": "Total des Citations",
            "updated_at": "Mis à jour le",
            "academic_ranking": "Classement Académique",
            "add_scholars_to_track": "Ajouter des Chercheurs à Suivre\nLeur Influence Académique",
            "tracking_scholars": "Suivi des Chercheurs",
            "latest_data": "Dernières Données",
            "average_citations_label": "Moyenne des Citations",
            "highest_citations_label": "Plus Grand Nombre de Citations",
            "this_month": "Ce Mois",
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
            "citations_unit": "citations",
            "no_data_available": "Aucune Donnée Disponible",
            "scholar_default_name": "Chercheur",
            "icloud_available_no_sync": "Non Synchronisé",
            "export_failed_with_message": "Exportation échouée",
            "import_failed_with_message": "Importation échouée",
            "failed_with_colon": "Échouée"
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
            "unknown": "Unbekannt",
            // Löschbestätigung
            "delete_scholar_title": "Forscher löschen",
            "delete_scholar_message": "Dieser Forscher und alle zugehörigen Daten werden gelöscht. Fortfahren?",
            "delete_scholar_message_with_name": "Forscher ‚%@' und alle zugehörigen Daten werden gelöscht. Fortfahren?",
            "delete_scholars_message_with_count": "%d Forscher und alle zugehörigen Daten werden gelöscht. Fortfahren?",
            "delete_all_scholars_title": "Alle Forscher löschen",
            "delete_all_scholars_message": "Alle Forscher und alle zugehörigen Daten werden gelöscht. Fortfahren?",
            
            // Widget specific strings
            "citations_label": "Zitationen",
            "start_tracking": "Verfolgung Starten",
            "add_scholar_to_track": "Forscher Hinzufügen zum Verfolgen",
            "tap_to_open_app": "Tippen um App zu Öffnen und Forscher Hinzuzufügen",
            "academic_influence": "Akademischer Einfluss",
            "top_scholars": "Forscher",
            "total_citations_label": "Gesamtzitationen",
            "updated_at": "Aktualisiert am",
            "academic_ranking": "Akademisches Ranking",
            "add_scholars_to_track": "Forscher Hinzufügen zum Verfolgen\nIhr Akademischer Einfluss",
            "tracking_scholars": "Forscher Verfolgen",
            "latest_data": "Neueste Daten",
            "average_citations_label": "Durchschnittliche Zitationen",
            "highest_citations_label": "Höchste Zitationen",
            "this_month": "Diesen Monat",
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
            "citations_unit": "Zitationen",
            "no_data_available": "Keine Daten Verfügbar",
            "scholar_default_name": "Forscher",
            "icloud_available_no_sync": "Nicht Synchronisiert",
            "export_failed_with_message": "Export fehlgeschlagen",
            "import_failed_with_message": "Import fehlgeschlagen",
            "failed_with_colon": "Fehlgeschlagen"
        ]
    }
}

// MARK: - Convenience Extensions
public extension String {
    var localized: String {
        return LocalizationManager.shared.localized(self)
    }
}