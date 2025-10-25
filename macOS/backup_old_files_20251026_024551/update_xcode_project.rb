require 'xcodeproj'

project_path = 'CiteTrack_macOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 获取主target
target = project.targets.first
sources_group = project.main_group['Sources']
assets_group = project.main_group.find_subpath('Assets', true)

# 添加新文件到Sources组
['Scholar.swift', 'DataManager.swift', 'MainAppDelegate.swift'].each do |filename|
  filepath = "Sources/#{filename}"
  if File.exist?(filepath)
    file_ref = sources_group.new_file(filepath)
    target.add_file_references([file_ref])
    puts "✅ 添加文件: #{filename}"
  end
end

# 添加Assets.xcassets
assets_path = 'Assets.xcassets'
if File.exist?(assets_path)
  assets_ref = assets_group.new_file(assets_path)
  target.resources_build_phase.add_file_reference(assets_ref)
  puts "✅ 添加资源: Assets.xcassets"
end

# 更新build settings以使用Assets.xcassets中的AppIcon
target.build_configurations.each do |config|
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['PRODUCT_NAME'] = 'CiteTrack'
  config.build_settings['MARKETING_VERSION'] = '2.0.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_FILE'] = ''
  puts "✅ 配置 #{config.name} build settings"
end

project.save
puts "✅ Xcode项目已更新"
