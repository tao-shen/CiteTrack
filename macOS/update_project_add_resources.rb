#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'CiteTrack_macOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first

# 添加资源文件（图标）
resources_group = project.main_group.find_subpath('Resources', true)

icon_file = 'assets/app_icon.icns'
if File.exist?(icon_file)
  file_ref = resources_group.new_file(icon_file)
  target.resources_build_phase.add_file_reference(file_ref)
  puts "✅ 添加图标文件: #{icon_file}"
else
  puts "⚠️  图标文件不存在: #{icon_file}"
end

# 更新 Info.plist 配置
target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_KEY_CFBundleIconFile'] = 'app_icon'
  config.build_settings['INFOPLIST_KEY_CFBundleIconName'] = 'app_icon'
end
puts "✅ 更新 Info.plist 图标配置"

project.save
puts "\n🎉 项目资源更新完成！"

