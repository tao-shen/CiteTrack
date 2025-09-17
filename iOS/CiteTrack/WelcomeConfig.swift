import SwiftUI
import WSOnBoarding

// 扩展 WSOnBoarding 库中的 WSWelcomeConfig
extension WSWelcomeConfig {
    /// CiteTrack 应用的欢迎页配置
    static var citeTrackWelcome: WSWelcomeConfig {
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
            iconSymbol: "doc.text.magnifyingglass",
            // 注意：应用图标集不会作为可运行时加载的图片暴露在资产目录中
            // 这里不再指定 iconName，避免运行时查找失败
            iconName: nil,
            backgroundImageName: nil,
            primaryColor: .blue,
            continueButtonText: "开始使用",
            disclaimerText: "您的学术数据将安全存储在本地设备上，并通过 iCloud 进行加密同步。我们重视您的隐私，不会收集或分享您的个人信息。"
        )
    }
}
