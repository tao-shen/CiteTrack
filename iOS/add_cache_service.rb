#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'CiteTrack_iOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到主target
target = project.targets.find { |t| t.name == 'CiteTrack' }

if target.nil?
  puts "Error: CiteTrack target not found"
  exit 1
end

file_path = '../Shared/Services/CitationCacheService.swift'
file_name = 'CitationCacheService.swift'

# 检查文件是否已存在
existing_ref = project.files.find { |f| f.path && f.path.end_with?(file_name) }

if existing_ref
  puts "CitationCacheService already exists in project"
else
  # 找到或创建Shared/Services group
  shared_group = project.main_group['Shared']
  if shared_group.nil?
    shared_group = project.main_group.new_group('Shared')
    shared_group.path = '../Shared'
    shared_group.source_tree = '<group>'
  end
  
  services_group = shared_group['Services']
  if services_group.nil?
    services_group = shared_group.new_group('Services')
    services_group.path = 'Services'
    services_group.source_tree = '<group>'
  end
  
  # 添加文件
  file_ref = services_group.new_file(file_path)
  target.add_file_references([file_ref])
  
  puts "Added CitationCacheService.swift to project"
end

# 保存项目
project.save

puts "✅ Done!"

