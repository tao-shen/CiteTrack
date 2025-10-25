#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'CiteTrack_macOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first
sources_group = project.main_group['Sources']

# V2.0.0 新文件
new_files = [
  'main.swift',
  'SettingsWindow.swift',
  'CoreDataManager.swift',
  'CitationHistoryEntity.swift',
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
  'ModernCardView.swift',
]

# 移除旧文件
['main_v1.1.3.swift', 'SettingsWindow_v1.1.3.swift'].each do |old_file|
  file_ref = sources_group.files.find { |f| f.path == old_file }
  if file_ref
    file_ref.remove_from_project
    puts "✅ 移除 #{old_file}"
  end
end

# 添加新文件
new_files.each do |file|
  file_path = "Sources/#{file}"
  if File.exist?(file_path)
    file_ref = sources_group.new_file(file)
    target.add_file_references([file_ref])
    puts "✅ 添加 #{file}"
  else
    puts "⚠️  文件不存在: #{file_path}"
  end
end

# 添加框架
['CoreData.framework', 'UserNotifications.framework'].each do |framework|
  unless target.frameworks_build_phase.files.any? { |f| f.display_name == framework }
    framework_ref = project.frameworks_group.new_file("System/Library/Frameworks/#{framework}")
    target.frameworks_build_phase.add_file_reference(framework_ref)
    puts "✅ 添加 #{framework}"
  end
end

# 更新版本号
project.targets.each do |t|
  t.build_configurations.each do |config|
    config.build_settings['MARKETING_VERSION'] = '2.0.0'
    config.build_settings['CURRENT_PROJECT_VERSION'] = '2.0.0'
  end
end
puts "✅ 更新版本号到 2.0.0"

project.save
puts "\n🎉 项目更新完成！"

