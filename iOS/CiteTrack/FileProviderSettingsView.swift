import SwiftUI
import FileProvider

/// File Provider Extension 设置视图
/// 让用户控制和管理 File Provider 功能
@available(iOS 16.0, *)
struct FileProviderSettingsView: View {
    @StateObject private var fileProviderManager = FileProviderManager.shared
    @EnvironmentObject private var dataManager: DataManager
    @State private var showingExportSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - 状态部分
                Section {
                    HStack {
                        Image(systemName: fileProviderManager.isFileProviderEnabled ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(fileProviderManager.isFileProviderEnabled ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("File Provider 状态")
                                .font(.headline)
                            Text(fileProviderManager.isFileProviderEnabled ? "已启用 - 在文件应用中可见" : "未启用")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("系统集成状态")
                } footer: {
                    Text("File Provider Extension 允许 CiteTrack 在「文件」应用中显示为独立的文件源，提供更深度的系统集成。")
                }
                
                // MARK: - 控制部分
                Section {
                    if fileProviderManager.isFileProviderEnabled {
                        Button(action: {
                            fileProviderManager.removeFileProvider()
                        }) {
                            HStack {
                                Image(systemName: "minus.circle")
                                Text("禁用 File Provider")
                            }
                        }
                        .foregroundColor(.red)
                    } else {
                        Button(action: {
                            fileProviderManager.initializeFileProvider()
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("启用 File Provider")
                            }
                        }
                        .foregroundColor(.blue)
                    }
                } header: {
                    Text("File Provider 控制")
                } footer: {
                    Text("启用后，CiteTrack 将在「文件」应用的侧边栏中显示为 'CiteTrack Documents'。")
                }
                
                // MARK: - 数据操作部分
                Section {
                    Button(action: {
                        exportScholarData()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("导出学者数据到 File Provider")
                        }
                    }
                    .disabled(!fileProviderManager.isFileProviderEnabled || dataManager.scholars.isEmpty)
                    
                    Button(action: {
                        openFilesApp()
                    }) {
                        HStack {
                            Image(systemName: "folder")
                            Text("在文件应用中打开")
                        }
                    }
                    .disabled(!fileProviderManager.isFileProviderEnabled)
                } header: {
                    Text("数据管理")
                } footer: {
                    Text("导出功能将创建包含所有学者数据的 .citetrack 文件，可在文件应用中访问和分享。")
                }
                
                // MARK: - 功能说明部分
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(
                            icon: "sidebar.left",
                            title: "侧边栏显示",
                            description: "在文件应用侧边栏中显示 'CiteTrack Documents'"
                        )
                        
                        FeatureRow(
                            icon: "doc.badge.gearshape",
                            title: "自定义图标",
                            description: "使用 CiteTrack 应用图标标识文件源"
                        )
                        
                        FeatureRow(
                            icon: "square.and.arrow.up",
                            title: "数据导出",
                            description: "将学者数据导出为标准文件格式"
                        )
                        
                        FeatureRow(
                            icon: "icloud.and.arrow.up",
                            title: "云端同步",
                            description: "通过 App Group 与主应用共享数据"
                        )
                    }
                } header: {
                    Text("File Provider 功能特性")
                }
                
                // MARK: - 技术信息部分
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("实现方法:")
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text("方法2 - File Provider Extension")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("域标识符:")
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text("com.citetrack.fileprovider")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("App Group:")
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text("group.com.citetrack.CiteTrack")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("系统要求:")
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text("iOS 16.0+")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("技术信息")
                }
            }
            .navigationTitle("File Provider 设置")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("导出成功", isPresented: $showingExportSuccess) {
            Button("好的", role: .cancel) { }
        } message: {
            Text("学者数据已成功导出到 File Provider。您可以在文件应用中查看。")
        }
        .alert("错误", isPresented: $showingError) {
            Button("好的", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // 检查最新状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                fileProviderManager.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func exportScholarData() {
        fileProviderManager.exportScholarData(dataManager.scholars)
        
        // 监听导出结果
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if fileProviderManager.lastError == nil {
                showingExportSuccess = true
            } else {
                errorMessage = fileProviderManager.lastError?.localizedDescription ?? "未知错误"
                showingError = true
            }
        }
    }
    
    private func openFilesApp() {
        // 尝试打开文件应用
        if let url = URL(string: "shareddocuments://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - Feature Row View
private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - iOS 15 兼容性视图
struct FileProviderSettingsViewCompat: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("File Provider Extension")
                    .font(.title2.weight(.semibold))
                
                Text("此功能需要 iOS 16.0 或更高版本")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("File Provider Extension 提供深度的系统集成，允许应用在文件应用中显示为独立的文件源。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("File Provider")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Preview
struct FileProviderSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            if #available(iOS 16.0, *) {
                FileProviderSettingsView()
                    .environmentObject(DataManager.shared)
            } else {
                FileProviderSettingsViewCompat()
            }
        }
    }
}
