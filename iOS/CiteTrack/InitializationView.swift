import SwiftUI

// MARK: - 初始化界面
/// 显示应用初始化进度的界面
struct InitializationView: View {
    @EnvironmentObject private var initializationService: AppInitializationService
    @EnvironmentObject private var dataManager: DataManager
    
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
                Text("欢迎使用 CiteTrack")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // 副标题
                Text("正在为您初始化学术追踪服务...")
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
                                
                                Text("初始化完成！")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("已导入 \(dataManager.scholars.count) 位学者的数据")
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
                        title: "实时数据更新",
                        description: "自动获取学者的最新引用数据"
                    )
                    
                    FeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "趋势分析",
                        description: "可视化展示学术影响力变化"
                    )
                    
                    FeatureRow(
                        icon: "bell",
                        title: "智能提醒",
                        description: "重要变化及时通知"
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
    }
}
