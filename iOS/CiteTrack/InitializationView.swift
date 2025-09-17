import SwiftUI

// MARK: - 初始化界面
/// 显示应用初始化进度的界面
struct InitializationView: View {
    @EnvironmentObject private var initializationService: AppInitializationService
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    var body: some View {
        ZStack {
            // 背景
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // 应用图标
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                // 标题
                Text(localizationManager.localized("welcome_to_citetrack"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // 副标题
                Text(localizationManager.localized("initializing_service"))
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // 进度指示器
                VStack(spacing: 20) {
                    if initializationService.isInitializing {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text(initializationService.initializationProgress)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut, value: initializationService.initializationProgress)
                    } else {
                        // 显示学者数量
                        if !dataManager.scholars.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.green)
                                
                                Text(localizationManager.localized("initialization_complete"))
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text(String(format: localizationManager.localized("imported_scholars_data"), dataManager.scholars.count))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(minHeight: 100)
                
                // 功能说明
                VStack(spacing: 15) {
                    FeatureRow(
                        icon: "network",
                        title: localizationManager.localized("real_time_data_update"),
                        description: localizationManager.localized("real_time_data_description")
                    )
                    
                    FeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: localizationManager.localized("trend_analysis"),
                        description: localizationManager.localized("trend_analysis_description")
                    )
                    
                    FeatureRow(
                        icon: "bell",
                        title: localizationManager.localized("smart_notifications"),
                        description: localizationManager.localized("smart_notifications_description")
                    )
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - 功能行组件
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 预览
struct InitializationView_Previews: PreviewProvider {
    static var previews: some View {
        InitializationView()
            .environmentObject(AppInitializationService.shared)
            .environmentObject(DataManager.shared)
            .environmentObject(LocalizationManager.shared)
    }
}
