#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'CiteTrack_iOS.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 需要移除的文件
files_to_remove = [
  'CitationTrackingModel.xcdatamodeld',
  'CitingPaperEntity+Extensions.swift',
  'CitingAuthorEntity+Extensions.swift'
]

puts "Removing CoreData related files..."

files_to_remove.each do |filename|
  matching_files = project.files.select { |f| f.path && f.path.include?(filename) }
  matching_files.each do |f|
    puts "  Removing #{f.path}"
    f.remove_from_project
  end
end

# 保存项目
project.save

puts "\n✅ Done! Removed CoreData files."

