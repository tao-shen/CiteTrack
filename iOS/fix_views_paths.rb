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

# 需要修复的Views文件
view_files = [
  'CitationFilterView.swift',
  'CitationStatisticsView.swift',
  'CitingPaperDetailView.swift',
  'CitingPaperListView.swift',
  'WhoCiteMeView.swift'
]

# 首先移除这些文件的旧引用
puts "Removing old references..."
view_files.each do |filename|
  file_ref = project.files.find { |f| f.path && f.path.end_with?(filename) }
  if file_ref
    puts "  Removing #{filename}"
    file_ref.remove_from_project
  end
end

# 找到或创建CiteTrack group
citetrack_group = project.main_group['CiteTrack']
if citetrack_group.nil?
  puts "Error: CiteTrack group not found"
  exit 1
end

# 找到或创建Views group
views_group = citetrack_group['Views']
if views_group.nil?
  views_group = citetrack_group.new_group('Views', 'Views')
  puts "Created Views group"
end

# 设置Views group的路径
views_group.path = 'Views'
views_group.source_tree = '<group>'

# 重新添加文件
puts "\nAdding files with correct paths..."
view_files.each do |filename|
  file_path = "CiteTrack/Views/#{filename}"
  full_path = File.join(File.dirname(project_path), file_path)
  
  unless File.exist?(full_path)
    puts "  Warning: File not found: #{full_path}"
    next
  end
  
  # 添加文件到Views group，只使用文件名（因为group已经有路径了）
  file_ref = views_group.new_reference(filename)
  file_ref.source_tree = '<group>'
  
  # 添加到target的sources build phase
  target.add_file_references([file_ref])
  
  puts "  Added #{filename}"
end

# 保存项目
project.save

puts "\n✅ Done! Views files have been fixed."

