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

model_name = 'CitationTrackingModel.xcdatamodeld'

# 首先删除所有旧的引用
puts "Removing old CoreData model references..."
project.files.select { |f| f.path && f.path.include?(model_name) }.each do |f|
  puts "  Removing #{f.path}"
  f.remove_from_project
end

# 确保Shared和CoreData groups存在并有正确的路径
shared_group = project.main_group['Shared']
if shared_group.nil?
  puts "Creating Shared group..."
  shared_group = project.main_group.new_group('Shared')
  shared_group.path = '../Shared'
  shared_group.source_tree = '<group>'
end

coredata_group = shared_group['CoreData']
if coredata_group.nil?
  puts "Creating CoreData group..."
  coredata_group = shared_group.new_group('CoreData')
  coredata_group.path = 'CoreData'
  coredata_group.source_tree = '<group>'
end

puts "\nAdding CoreData model..."

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

# 添加到source code compile phase (不是resources!)
target.source_build_phase.add_file_reference(file_ref)

puts "Added CoreData model to source build phase"

# 保存项目
project.save

puts "\n✅ Done!"

