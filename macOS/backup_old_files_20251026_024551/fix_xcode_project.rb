require 'xcodeproj'

project_path = 'CiteTrack_macOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 获取主target
target = project.targets.first
sources_group = project.main_group['Sources']

# 移除错误路径的文件引用
project.main_group.recursive_children.each do |item|
  if item.is_a?(Xcodeproj::Project::Object::PBXFileReference)
    path = item.real_path.to_s
    if path.include?('Sources/Sources/')
      puts "移除错误引用: #{item.path}"
      item.remove_from_project
    end
  end
end

# 正确添加新文件
['Scholar.swift', 'DataManager.swift', 'MainAppDelegate.swift'].each do |filename|
  filepath = "Sources/#{filename}"
  if File.exist?(filepath)
    # 检查是否已存在
    existing = sources_group.files.find { |f| f.display_name == filename }
    if existing
      puts "跳过已存在的文件: #{filename}"
      next
    end
    
    file_ref = sources_group.new_reference(filepath)
    target.source_build_phase.add_file_reference(file_ref)
    puts "✅ 正确添加文件: #{filename}"
  else
    puts "⚠️ 文件不存在: #{filepath}"
  end
end

project.save
puts "✅ Xcode项目路径已修复"
