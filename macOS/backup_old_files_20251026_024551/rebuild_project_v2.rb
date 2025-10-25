require 'xcodeproj'

project_path = 'CiteTrack_macOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 获取主target
target = project.targets.first
sources_group = project.main_group['Sources']

# 清理所有文件引用
target.source_build_phase.files.clear

# 重新添加所有Swift文件
swift_files = [
  'main.swift',
  'Scholar.swift', 
  'DataManager.swift',
  'MainAppDelegate.swift',
  'SettingsWindow.swift',
  'Localization.swift',
  'CoreDataManager.swift',
  'CitationHistory.swift',
  'CitationHistoryManager.swift',
  'GoogleScholarService+History.swift',
  'ChartDataService.swift',
  'ChartView.swift',
  'ChartTheme.swift',
  'ChartsViewController.swift',
  'ChartsWindowController.swift',
  'DataRepairViewController.swift',
  'iCloudSyncManager.swift',
  'NotificationManager.swift',
  'DashboardComponents.swift',
  'EnhancedChartTypes.swift',
  'ModernCardView.swift'
]

swift_files.each do |filename|
  filepath = "Sources/#{filename}"
  if File.exist?(filepath)
    # 检查是否已存在文件引用
    existing_ref = sources_group.files.find { |f| f.display_name == filename }
    if existing_ref
      target.source_build_phase.add_file_reference(existing_ref)
      puts "✅ 添加现有文件: #{filename}"
    else
      file_ref = sources_group.new_file(filepath)
      target.source_build_phase.add_file_reference(file_ref)
      puts "✅ 添加新文件: #{filename}"
    end
  else
    puts "⚠️ 文件不存在: #{filepath}"
  end
end

# 更新版本号
target.build_configurations.each do |config|
  config.build_settings['MARKETING_VERSION'] = '2.0.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.citetrack.CiteTrack'
  config.build_settings['INFOPLIST_FILE'] = 'Info.plist'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  puts "✅ 配置 #{config.name} build settings"
end

project.save
puts "✅ 项目已重建为v2.0.0"
