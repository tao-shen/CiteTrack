import SwiftUI
import UIKit
import WSOnBoarding

// 扩展 WSOnBoarding 库中的 WSWelcomeConfig
extension WSWelcomeConfig {
    /// CiteTrack 应用的欢迎页配置
    static var citeTrackWelcome: WSWelcomeConfig {
        // 优先使用我们在 Assets 中提供的 WelcomeIcon 资源；不存在则回退 SF Symbol
        let resolvedIconName: String? = {
            #if os(iOS)
            return UIImage(named: "WelcomeIcon") != nil ? "WelcomeIcon" : nil
            #else
            return nil
            #endif
        }()

        return WSWelcomeConfig(
            appName: "CiteTrack",
            introText: "app_description".localized,
            features: [
                FeatureItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "smart_tracking".localized,
                    description: "smart_tracking_description".localized,
                    color: .blue
                ),
                FeatureItem(
                    icon: "icloud.and.arrow.up",
                    title: "icloud_sync".localized,
                    description: "icloud_sync_description".localized,
                    color: .green
                ),
                FeatureItem(
                    icon: "chart.bar.fill",
                    title: "trend_analysis".localized,
                    description: "trend_analysis_description".localized,
                    color: .orange
                ),
                FeatureItem(
                    icon: "bell.fill",
                    title: "smart_notifications".localized,
                    description: "smart_notifications_description".localized,
                    color: .purple
                )
            ],
            iconSymbol: resolvedIconName == nil ? "app" : nil,
            // 若能解析到可用的 App 图标，则使用；否则由 iconSymbol 兜底
            iconName: resolvedIconName,
            backgroundImageName: nil,
            primaryColor: .blue,
            continueButtonText: "continue".localized,
            disclaimerText: "privacy_disclaimer".localized,
            customTitle: "welcome_to_citetrack".localized
        )
    }
}

// MARK: - Helpers
private extension WSWelcomeConfig {
    /// 从 Info.plist 中解析主 App Icon 的基础文件名
    /// 返回如 "AppIcon60x60" 这类基础名（系统会自动匹配倍率与后缀）
    static func primaryAppIconBaseName() -> String? {
        guard let info = Bundle.main.infoDictionary else { return nil }
        // iOS 使用 CFBundleIcons → CFBundlePrimaryIcon → CFBundleIconFiles
        if let icons = info["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let last = files.last, !last.isEmpty {
            return last
        }
        // 兼容旧键或简化键
        if let icons = info["CFBundleIcons~iphone"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let last = files.last, !last.isEmpty {
            return last
        }
        // 兜底：若存在 CFBundleIconFile，尝试返回
        if let name = info["CFBundleIconFile"] as? String, !name.isEmpty {
            return name
        }
        return nil
    }
}
