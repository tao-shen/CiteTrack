require 'xcodeproj'

project_path = 'CiteTrack_macOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 获取主target
target = project.targets.first

# 添加Info.plist到项目
info_plist_ref = project.main_group.new_file('Info.plist')

# 更新build settings以使用Info.plist
target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'Info.plist'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.citetrack.CiteTrack'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CODE_SIGN_IDENTITY'] = '-'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  puts "✅ 配置 #{config.name} build settings"
end

project.save
puts "✅ Info.plist已添加到项目"
