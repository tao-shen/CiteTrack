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
                            Text("fp_status_title".localized)
                                .font(.headline)
                            Text(fileProviderManager.isFileProviderEnabled ? "fp_status_enabled".localized : "fp_status_disabled".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("fp_integration_section".localized)
                } footer: {
                    Text("fp_integration_footer".localized)
                }
                
                // MARK: - 控制部分
                Section {
                    if fileProviderManager.isFileProviderEnabled {
                        Button(action: {
                            fileProviderManager.removeFileProvider()
                        }) {
                            HStack {
                                Image(systemName: "minus.circle")
                                Text("fp_disable_button".localized)
                            }
                        }
                        .foregroundColor(.red)
                    } else {
                        Button(action: {
                            fileProviderManager.initializeFileProvider()
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("fp_enable_button".localized)
                            }
                        }
                        .foregroundColor(.blue)
                    }
                } header: {
                    Text("fp_control_section".localized)
                } footer: {
                    Text("fp_control_footer".localized)
                }
                
                // MARK: - 数据操作部分
                Section {
                    Button(action: {
                        exportScholarData()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("fp_export_button".localized)
                        }
                    }
                    .disabled(!fileProviderManager.isFileProviderEnabled || dataManager.scholars.isEmpty)
                    
                    Button(action: {
                        openFilesApp()
                    }) {
                        HStack {
                            Image(systemName: "folder")
                            Text("fp_open_in_files_button".localized)
                        }
                    }
                    .disabled(!fileProviderManager.isFileProviderEnabled)
                } header: {
                    Text("data_management".localized)
                } footer: {
                    Text("fp_data_footer".localized)
                }
                
                // MARK: - 功能说明部分
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(
                            icon: "sidebar.left",
                            title: "fp_feature_sidebar_title".localized,
                            description: "fp_feature_sidebar_desc".localized
                        )
                        
                        FeatureRow(
                            icon: "doc.badge.gearshape",
                            title: "fp_feature_icon_title".localized,
                            description: "fp_feature_icon_desc".localized
                        )
                        
                        FeatureRow(
                            icon: "square.and.arrow.up",
                            title: "fp_feature_export_title".localized,
                            description: "fp_feature_export_desc".localized
                        )
                        
                        FeatureRow(
                            icon: "icloud.and.arrow.up",
                            title: "fp_feature_sync_title".localized,
                            description: "fp_feature_sync_desc".localized
                        )
                    }
                } header: {
                    Text("fp_features_section".localized)
                }
                
                // MARK: - 技术信息部分
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("fp_tech_method_label".localized)
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text("fp_tech_method_value".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("fp_domain_identifier_label".localized)
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text("com.citetrack.fileprovider")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("fp_app_group_label".localized)
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text("group.com.citetrack.CiteTrack")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("fp_system_requirements_label".localized)
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text("iOS 16.0+")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("fp_tech_info_section".localized)
                }
            }
            .navigationTitle("fp_nav_title".localized)
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("fp_export_success_title".localized, isPresented: $showingExportSuccess) {
            Button("ok".localized, role: .cancel) { }
        } message: {
            Text("fp_export_success_message".localized)
        }
        .alert("fp_error_title".localized, isPresented: $showingError) {
            Button("ok".localized, role: .cancel) { }
        } message: {
            Text(errorMessage.isEmpty ? "unknown_error".localized : errorMessage)
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
                
                Text("fp_ext_title".localized)
                    .font(.title2.weight(.semibold))
                
                Text("fp_ext_requirement".localized)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("fp_ext_description".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("fp_nav_title_compat".localized)
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
