import Foundation

// MARK: - Widget Localization Helper
class WidgetLocalization {
    static let shared = WidgetLocalization()
    
    private init() {}
    
    func localized(_ key: String) -> String {
        // Simple localization for widget extension
        // This uses the system language to determine the appropriate translation
        let language = Locale.current.languageCode ?? "en"
        
        switch language {
        case "zh":
            return chineseLocalizations[key] ?? key
        case "ja":
            return japaneseLocalizations[key] ?? key
        case "ko":
            return koreanLocalizations[key] ?? key
        case "es":
            return spanishLocalizations[key] ?? key
        case "fr":
            return frenchLocalizations[key] ?? key
        case "de":
            return germanLocalizations[key] ?? key
        default:
            return englishLocalizations[key] ?? key
        }
    }
    
    private let englishLocalizations: [String: String] = [
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
        "failed_with_colon": "Failed",
        "dashboard": "Dashboard",
        // Added keys for headlines & badges
        "team_performance": "Team Performance",
        "performance_excellent": "Excellent",
        "performance_good": "Good",
        "performance_starting": "Starting",
        "realtime_citation_tracking": "Real-time Citation Tracking",
        "scholar_ranking_comparison": "Scholar Ranking Comparison",
        "trend_change_analysis": "Trend Change Analysis"
    ]
    
    private let chineseLocalizations: [String: String] = [
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
        "failed_with_colon": "失败",
        "dashboard": "仪表板",
        // Added keys for headlines & badges
        "team_performance": "团队表现",
        "performance_excellent": "优秀",
        "performance_good": "良好",
        "performance_starting": "起步",
        "realtime_citation_tracking": "实时引用数追踪",
        "scholar_ranking_comparison": "学者排名对比",
        "trend_change_analysis": "趋势变化分析"
    ]
    
    private let japaneseLocalizations: [String: String] = [
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
        "failed_with_colon": "失敗",
        "dashboard": "ダッシュボード"
    ]
    
    private let koreanLocalizations: [String: String] = [
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
        "failed_with_colon": "실패",
        "dashboard": "대시보드"
    ]
    
    private let spanishLocalizations: [String: String] = [
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
        "failed_with_colon": "Fallida",
        "dashboard": "Panel de Control"
    ]
    
    private let frenchLocalizations: [String: String] = [
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
        "failed_with_colon": "Échouée",
        "dashboard": "Tableau de Bord"
    ]
    
    private let germanLocalizations: [String: String] = [
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
        "failed_with_colon": "Fehlgeschlagen",
        "dashboard": "Dashboard"
    ]
}

// MARK: - String Extension for Widget
extension String {
    var widgetLocalized: String {
        return WidgetLocalization.shared.localized(self)
    }
}
