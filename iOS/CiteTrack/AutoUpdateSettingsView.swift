import SwiftUI

// MARK: - Auto Update Settings View
struct AutoUpdateSettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var autoUpdateManager = AutoUpdateManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var showingFrequencyPicker = false
    @State private var showingNextUpdatePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 自动更新开关
            Toggle(isOn: $settingsManager.autoUpdateEnabled) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundColor(.blue)
                    Text(localizationManager.localized("auto_update_enabled"))
                }
            }
            .onChange(of: settingsManager.autoUpdateEnabled) { _, enabled in
                if enabled {
                    autoUpdateManager.startAutoUpdate()
                } else {
                    autoUpdateManager.stopAutoUpdate()
                }
            }
            
            if settingsManager.autoUpdateEnabled {
                Divider()
                    .padding(.vertical, 8)
                
                // 更新频率选择
                Button(action: {
                    showingFrequencyPicker = true
                }) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                        Text(localizationManager.localized("auto_update_frequency"))
                        Spacer()
                        Text(settingsManager.autoUpdateFrequency.displayName)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .padding(.vertical, 8)
                
                // 下次更新时间显示和选择
                Button(action: {
                    showingNextUpdatePicker = true
                }) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.green)
                        Text(localizationManager.localized("next_update_time"))
                        Spacer()
                        Text(autoUpdateManager.getNextUpdateTimeString())
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
            }
        }
        .sheet(isPresented: $showingFrequencyPicker) {
            FrequencySelectionView()
        }
        .sheet(isPresented: $showingNextUpdatePicker) {
            NextUpdateTimeSelectionView()
        }
    }
}

// MARK: - Frequency Selection View
struct FrequencySelectionView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var autoUpdateManager = AutoUpdateManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AutoUpdateFrequency.allCases, id: \.self) { frequency in
                    HStack {
                        Text(frequency.displayName)
                        Spacer()
                        if settingsManager.autoUpdateFrequency == frequency {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        settingsManager.autoUpdateFrequency = frequency
                        // 如果自动更新已启用，重新启动以应用新频率
                        if settingsManager.autoUpdateEnabled {
                            autoUpdateManager.startAutoUpdate()
                        }
                        dismiss()
                    }
                }
            }
            .navigationTitle(localizationManager.localized("auto_update_frequency"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localized("done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Next Update Time Selection View
struct NextUpdateTimeSelectionView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var autoUpdateManager = AutoUpdateManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    localizationManager.localized("next_update_time"),
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(WheelDatePickerStyle())
                .padding()
                
                Spacer()
            }
            .navigationTitle(localizationManager.localized("next_update_time"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localized("done")) {
                        settingsManager.nextUpdateDate = selectedDate
                        autoUpdateManager.nextUpdateDate = selectedDate
                        // 重新启动自动更新以应用新的时间
                        if settingsManager.autoUpdateEnabled {
                            autoUpdateManager.startAutoUpdate()
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedDate = settingsManager.nextUpdateDate ?? Date().addingTimeInterval(3600)
            }
        }
    }
}
