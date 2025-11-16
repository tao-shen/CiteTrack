#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'CiteTrack_iOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Cleaning up all CoreData model references..."

# 找到所有包含CitationTrackingModel的对象
objects_to_remove = []

project.objects.each do |obj|
  next unless obj.respond_to?(:path)
  if obj.path && obj.path.include?('CitationTrackingModel')
    objects_to_remove << obj
    puts "Found CoreData reference: #{obj.isa} - #{obj.path}"
  end
end

# 移除这些对象
objects_to_remove.each do |obj|
  begin
    obj.remove_from_project
    puts "Removed: #{obj.path}"
  rescue => e
    puts "Failed to remove #{obj.path}: #{e.message}"
  end
end

# 清理XCVersionGroup对象
version_groups = project.objects.select { |o| o.isa == 'XCVersionGroup' }
version_groups.each do |vg|
  if vg.respond_to?(:path) && vg.path && vg.path.include?('CitationTrackingModel')
    begin
      vg.remove_from_project
      puts "Removed version group: #{vg.path}"
    rescue => e
      puts "Failed to remove version group: #{e.message}"
    end
  end
end

# 保存项目
project.save

puts "\n✅ Done! All CoreData references have been removed."

