#!/usr/bin/env python3

import re
import sys

def add_files_to_xcode_project():
    """
    添加FileProviderManager.swift和FileProviderSettingsView.swift到Xcode项目
    """
    
    project_file = "/Users/tao.shen/google_scholar_plugin/iOS/CiteTrack_tauon.xcodeproj/project.pbxproj"
    
    # 读取项目文件
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 生成唯一的文件引用ID (模仿现有格式)
    file_provider_manager_id = "FileProviderMgr123456789012345678901234"
    file_provider_settings_id = "FileProviderView123456789012345678901234"
    
    # 生成BuildFile ID
    build_file_manager_id = "FileProviderMgrBuild123456789012345678901234"
    build_file_settings_id = "FileProviderViewBuild123456789012345678901234"
    
    # 1. 添加BuildFile entries (在PBXBuildFile section)
    build_file_pattern = r'(BackupServiceBuild123456789012345678901234 /\* BackupService\.swift in Sources \*/;)'
    build_file_replacement = r'\1\n\t\t' + build_file_manager_id + r' /* FileProviderManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = ' + file_provider_manager_id + r' /* FileProviderManager.swift */; };\n\t\t' + build_file_settings_id + r' /* FileProviderSettingsView.swift in Sources */ = {isa = PBXBuildFile; fileRef = ' + file_provider_settings_id + r' /* FileProviderSettingsView.swift */; };'
    
    content = re.sub(build_file_pattern, build_file_replacement, content)
    
    # 2. 添加FileReference entries (在PBXFileReference section)
    file_ref_pattern = r'(InitView123456789012345678901234 /\* InitializationView\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = InitializationView\.swift; sourceTree = "<group>"; \};)'
    file_ref_replacement = r'\1\n\t\t' + file_provider_manager_id + r' /* FileProviderManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = FileProviderManager.swift; sourceTree = "<group>"; };\n\t\t' + file_provider_settings_id + r' /* FileProviderSettingsView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = FileProviderSettingsView.swift; sourceTree = "<group>"; };'
    
    content = re.sub(file_ref_pattern, file_ref_replacement, content)
    
    # 3. 添加到CiteTrack组 (在PBXGroup section的CiteTrack组中)
    group_pattern = r'(InitView123456789012345678901234 /\* InitializationView\.swift \*/,\n\t\t\t\t2B820DC36C0D60590FD97C20 /\* citetrack_init\.json \*/,)'
    group_replacement = r'\1\n\t\t\t\t' + file_provider_manager_id + r' /* FileProviderManager.swift */,\n\t\t\t\t' + file_provider_settings_id + r' /* FileProviderSettingsView.swift */,'
    
    content = re.sub(group_pattern, group_replacement, content)
    
    # 4. 添加到主应用的Sources build phase
    sources_pattern = r'(InitViewBuild123456789012345678901234 /\* InitializationView\.swift in Sources \*/,)'
    sources_replacement = r'\1\n\t\t\t\t' + build_file_manager_id + r' /* FileProviderManager.swift in Sources */,\n\t\t\t\t' + build_file_settings_id + r' /* FileProviderSettingsView.swift in Sources */,'
    
    content = re.sub(sources_pattern, sources_replacement, content)
    
    # 写回文件
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ 已将FileProviderManager.swift和FileProviderSettingsView.swift添加到项目中")
    print("📋 已添加的文件:")
    print("   - FileProviderManager.swift")
    print("   - FileProviderSettingsView.swift")
    print("🔧 已更新的配置:")
    print("   - PBXBuildFile entries")
    print("   - PBXFileReference entries")
    print("   - CiteTrack group membership")
    print("   - Sources build phase")

if __name__ == "__main__":
    add_files_to_xcode_project()
