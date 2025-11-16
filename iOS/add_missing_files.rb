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

# 定义需要添加的文件
files_to_add = [
  # Shared/Managers
  '../Shared/Managers/CitationManager.swift',
  
  # Shared/Models
  '../Shared/Models/CitationFilter.swift',
  '../Shared/Models/CitationStatistics.swift',
  '../Shared/Models/CitingAuthor.swift',
  '../Shared/Models/CitingPaper.swift',
  
  # Shared/Services
  '../Shared/Services/CitationCacheService.swift',
  '../Shared/Services/CitationExportService.swift',
  '../Shared/Services/CitationFetchService.swift',
  
  # Shared/CoreData - 暂时不添加，因为依赖不存在的CoreData实体
  # '../Shared/CoreData/CitingAuthorEntity+Extensions.swift',
  # '../Shared/CoreData/CitingPaperEntity+Extensions.swift',
  
  # Views (located in CiteTrack/Views directory)
  './CiteTrack/Views/CitationFilterView.swift',
  './CiteTrack/Views/CitationStatisticsView.swift',
  './CiteTrack/Views/CitingPaperDetailView.swift',
  './CiteTrack/Views/CitingPaperListView.swift',
  './CiteTrack/Views/WhoCiteMeView.swift'
]

added_count = 0
already_exist_count = 0

files_to_add.each do |file_path|
  # 检查文件是否存在
  full_path = File.join(File.dirname(project_path), file_path)
  unless File.exist?(full_path)
    puts "Warning: File not found: #{full_path}"
    next
  end
  
  # 检查文件是否已经在项目中
  file_ref = project.files.find { |f| f.path && f.path.end_with?(File.basename(file_path)) }
  
  if file_ref
    puts "File already exists in project: #{File.basename(file_path)}"
    already_exist_count += 1
    
    # 确保文件在target的sources中
    unless target.source_build_phase.files_references.include?(file_ref)
      target.add_file_references([file_ref])
      puts "  -> Added to target build phase"
      added_count += 1
    end
  else
    # 添加文件引用到项目
    group_path = File.dirname(file_path)
    
    # 找到或创建对应的group
    group = project.main_group
    group_path.split('/').each do |dir|
      next if dir == '..'
      subgroup = group[dir] || group.new_group(dir)
      group = subgroup
    end
    
    # 添加文件到group
    file_ref = group.new_file(file_path)
    
    # 添加到target的sources build phase
    target.add_file_references([file_ref])
    
    puts "Added file: #{File.basename(file_path)}"
    added_count += 1
  end
end

# 保存项目
project.save

puts "\n✅ Done!"
puts "Added #{added_count} files to the project"
puts "#{already_exist_count} files already existed"

