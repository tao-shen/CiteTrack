#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'CiteTrack_iOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到主 target
target = project.targets.find { |t| t.name == 'CiteTrack' }

# 找到 Shared/Services 组
shared_group = project.main_group.find_subpath('Shared/Services', true)

# 要添加的文件
files_to_add = [
  '../Shared/Services/UnifiedCacheManager.swift',
  '../Shared/Services/CitationFetchService+ScholarInfo.swift'
]

files_to_add.each do |file_path|
  file_name = File.basename(file_path)
  
  # 检查文件是否已存在
  existing_file = shared_group.files.find { |f| f.path == file_path }
  
  if existing_file
    puts "File already exists in project: #{file_name}"
    next
  end
  
  # 添加文件引用
  file_ref = shared_group.new_reference(file_path)
  
  # 添加到 target 的编译阶段
  target.add_file_references([file_ref])
  
  puts "✅ Added: #{file_name}"
end

# 保存项目
project.save

puts "\n✅ Done!"
