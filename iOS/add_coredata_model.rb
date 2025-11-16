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

# CoreData模型文件路径
model_path = '../Shared/CoreData/CitationTrackingModel.xcdatamodeld'
model_name = 'CitationTrackingModel.xcdatamodeld'

# 检查文件是否已存在
existing_ref = project.files.find { |f| f.path && f.path.include?(model_name) }

if existing_ref
  puts "CoreData model already exists in project"
  
  # 确保在resources build phase中
  unless target.resources_build_phase.files_references.include?(existing_ref)
    target.resources_build_phase.add_file_reference(existing_ref)
    puts "Added to resources build phase"
  end
else
  # 找到或创建Shared/CoreData group
  shared_group = project.main_group['Shared']
  if shared_group.nil?
    shared_group = project.main_group.new_group('Shared')
    shared_group.path = '../Shared'
    shared_group.source_tree = '<group>'
  end
  
  coredata_group = shared_group['CoreData']
  if coredata_group.nil?
    coredata_group = shared_group.new_group('CoreData')
    coredata_group.path = 'CoreData'
    coredata_group.source_tree = '<group>'
  end
  
  # 创建XCVersionGroup对象（用于xcdatamodeld文件）
  file_ref = project.new(Xcodeproj::Project::Object::XCVersionGroup)
  file_ref.path = model_name
  file_ref.source_tree = '<group>'
  file_ref.version_group_type = 'wrapper.xcdatamodel'
  
  # 添加当前版本的引用
  current_version = project.new(Xcodeproj::Project::Object::PBXFileReference)
  current_version.path = 'CitationTrackingModel.xcdatamodel'
  current_version.source_tree = '<group>'
  file_ref.children << current_version
  file_ref.current_version = current_version
  
  # 添加到group
  coredata_group.children << file_ref
  
  # 添加到resources build phase
  target.resources_build_phase.add_file_reference(file_ref)
  
  puts "Added CoreData model to project"
end

# 保存项目
project.save

puts "✅ Done!"

