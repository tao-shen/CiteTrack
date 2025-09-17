#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'

PROJECT_PATH = 'iOS/CiteTrack.xcodeproj'
APP_TARGET_NAME = 'CiteTrack'
WIDGET_TARGET_NAME = 'CiteTrackWidgetExtension'
APP_GROUP_ID = 'group.com.citetrack.CiteTrack'

# Ensure essential files exist
widget_dir = 'iOS/CiteTrackWidgetExtension'
constants_file = 'Shared/Constants.swift'
abort("Missing #{constants_file}. Please ensure it exists.") unless File.exist?(constants_file)
abort("Missing widget directory: #{widget_dir}") unless Dir.exist?(widget_dir)

project = Xcodeproj::Project.open(PROJECT_PATH)
app_target = project.targets.find { |t| t.name == APP_TARGET_NAME }
abort("App target '#{APP_TARGET_NAME}' not found") unless app_target

# Create Widget extension target if not exists
widget_target = project.targets.find { |t| t.name == WIDGET_TARGET_NAME }
if widget_target.nil?
  # Create app extension target in default Products group
  widget_target = project.new_target(:app_extension, WIDGET_TARGET_NAME, :ios, '17.0')
  widget_target.product_type = 'com.apple.product-type.app-extension'
  widget_target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.citetrack.CiteTrack.widget'
    config.build_settings['INFOPLIST_FILE'] = 'iOS/CiteTrackWidgetExtension/WidgetInfo.plist'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'iOS/CiteTrackWidgetExtension/CiteTrackWidgetExtension.entitlements'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  end

  # Create a new group for Widget files if not present
  widgets_group = project.main_group.find_subpath('iOS/CiteTrackWidgetExtension', true)
  widgets_group.set_source_tree('SOURCE_ROOT')

  # Create Info.plist if missing
  info_plist_path = 'iOS/CiteTrackWidgetExtension/WidgetInfo.plist'
  unless File.exist?(info_plist_path)
    plist_content = <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>NSExtension</key>
        <dict>
          <key>NSExtensionPointIdentifier</key>
          <string>com.apple.widgetkit-extension</string>
        </dict>
        <key>CFBundleDisplayName</key>
        <string>CiteTrack Widget</string>
      </dict>
      </plist>
    PLIST
    File.write(info_plist_path, plist_content)
  end
  widgets_group.new_file(info_plist_path)

  # Create Entitlements
  entitlements_path = 'iOS/CiteTrackWidgetExtension/CiteTrackWidgetExtension.entitlements'
  unless File.exist?(entitlements_path)
    ent_content = <<~ENT
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>com.apple.security.app-sandbox</key>
        <true/>
        <key>com.apple.security.application-groups</key>
        <array>
          <string>#{APP_GROUP_ID}</string>
        </array>
      </dict>
      </plist>
    ENT
    File.write(entitlements_path, ent_content)
  end
  widgets_group.new_file(entitlements_path)
end

# Add source files to targets
widget_files = [
  'iOS/CiteTrackWidgetExtension/CiteTrackWidget.swift',
  'iOS/CiteTrackWidgetExtension/Constants.swift',
  'Shared/Constants.swift'
]
widget_files.each do |path|
  file_ref = project.main_group.find_file_by_path(path) || project.main_group.new_file(path)
  build_file = widget_target.source_build_phase.files_references.find { |fr| fr.path == file_ref.path }
  if build_file.nil?
    widget_target.add_file_references([file_ref])
  end
end

# Ensure app target also includes Constants.swift
const_ref = project.main_group.find_file_by_path('Shared/Constants.swift') || project.main_group.new_file('Shared/Constants.swift')
app_has_const = app_target.source_build_phase.files_references.any? { |fr| fr.path == const_ref.path }
app_target.add_file_references([const_ref]) unless app_has_const

# Add App Group to app entitlements if exists or create one
app_entitlements_path = nil
app_target.build_configurations.each do |config|
  if config.build_settings['CODE_SIGN_ENTITLEMENTS']
    app_entitlements_path = config.build_settings['CODE_SIGN_ENTITLEMENTS']
  end
end

if app_entitlements_path.nil? || app_entitlements_path.empty?
  app_entitlements_path = 'iOS/CiteTrack/CiteTrack.entitlements'
  app_group = project.main_group.find_subpath('iOS/CiteTrack', true)
  app_group.set_source_tree('SOURCE_ROOT')
  unless File.exist?(app_entitlements_path)
    ent = <<~ENT
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>com.apple.security.application-groups</key>
        <array>
          <string>#{APP_GROUP_ID}</string>
        </array>
      </dict>
      </plist>
    ENT
    File.write(app_entitlements_path, ent)
  end
  app_target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = app_entitlements_path
  end
  project.main_group.new_file(app_entitlements_path)
else
  # Try reading entitlements relative to repo root and project dir
  content = nil
  if File.exist?(app_entitlements_path)
    content = File.read(app_entitlements_path)
  else
    candidate = File.join('iOS', app_entitlements_path)
    content = File.read(candidate) if File.exist?(candidate)
    app_entitlements_path = candidate if File.exist?(candidate)
  end
  unless content.nil? || content.include?(APP_GROUP_ID)
    content = content.sub(%r{</array>}, "  <string>#{APP_GROUP_ID}</string>\n    </array>")
    File.write(app_entitlements_path, content)
  end
end

# Embed the extension in the app
embed_phase = app_target.copy_files_build_phases.find { |bp| bp.symbol_dst_subfolder_spec == :plugins || bp.dst_subfolder_spec == '13' }
if embed_phase.nil?
  embed_phase = app_target.new_copy_files_build_phase('Embed App Extensions')
  # :plugins maps to numeric '13'. Set string to avoid symbol validation issues on current xcodeproj
  embed_phase.dst_subfolder_spec = '13'
end
product_ref = widget_target.product_reference
embed_phase.add_file_reference(product_ref) unless embed_phase.files_references.include?(product_ref)

# Ensure the app builds the widget extension by adding a target dependency
unless app_target.dependencies.any? { |d| d.target == widget_target }
  app_target.add_dependency(widget_target)
end

project.save
puts '✅ Widget extension configured. Open Xcode to finish signing if needed.'
