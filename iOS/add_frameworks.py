#!/usr/bin/env python3

import re

def add_file_provider_framework():
    """
    为主应用添加FileProvider.framework依赖
    """
    
    project_file = "/Users/tao.shen/google_scholar_plugin/iOS/CiteTrack_tauon.xcodeproj/project.pbxproj"
    
    # 读取项目文件
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 生成唯一的framework引用ID
    file_provider_framework_id = "FileProviderFramework123456789012345678901234"
    file_provider_build_id = "FileProviderFrameworkBuild123456789012345678901234"
    
    # 1. 检查是否已经存在FileProvider.framework引用
    if "FileProvider.framework" in content:
        print("⚠️ FileProvider.framework 已存在于项目中")
        return
    
    # 2. 添加BuildFile entry (在PBXBuildFile section)
    build_file_pattern = r'(E2DC0E1C2E71D8310022A244 /\* UniformTypeIdentifiers\.framework in Frameworks \*/ = \{isa = PBXBuildFile; fileRef = E2DC0E1B2E71D8300022A244 /\* UniformTypeIdentifiers\.framework \*/; \};)'
    build_file_replacement = r'\1\n\t\t' + file_provider_build_id + r' /* FileProvider.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = ' + file_provider_framework_id + r' /* FileProvider.framework */; };'
    
    content = re.sub(build_file_pattern, build_file_replacement, content)
    
    # 3. 添加FileReference entry (在PBXFileReference section)
    file_ref_pattern = r'(E2DC0E1B2E71D8300022A244 /\* UniformTypeIdentifiers\.framework \*/ = \{isa = PBXFileReference; lastKnownFileType = wrapper\.framework; name = UniformTypeIdentifiers\.framework; path = System/Library/Frameworks/UniformTypeIdentifiers\.framework; sourceTree = SDKROOT; \};)'
    file_ref_replacement = r'\1\n\t\t' + file_provider_framework_id + r' /* FileProvider.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = FileProvider.framework; path = System/Library/Frameworks/FileProvider.framework; sourceTree = SDKROOT; };'
    
    content = re.sub(file_ref_pattern, file_ref_replacement, content)
    
    # 4. 添加到主应用的Frameworks build phase (找到主应用的frameworks section)
    # 主应用当前没有框架依赖，所以需要在主应用的Frameworks section添加
    main_app_frameworks_pattern = r'(13D6E9FA13D6E9FA13D6E9FA13D6E /\* Frameworks \*/ = \{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = \(\n\t\t\t\);)'
    main_app_frameworks_replacement = r'13D6E9FA13D6E9FA13D6E9FA13D6E /* Frameworks */ = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\t' + file_provider_build_id + r' /* FileProvider.framework in Frameworks */,\n\t\t\t);'
    
    content = re.sub(main_app_frameworks_pattern, main_app_frameworks_replacement, content)
    
    # 5. 添加到Frameworks组
    frameworks_group_pattern = r'(E2DC0E1B2E71D8300022A244 /\* UniformTypeIdentifiers\.framework \*/,)'
    frameworks_group_replacement = r'\1\n\t\t\t\t' + file_provider_framework_id + r' /* FileProvider.framework */,'
    
    content = re.sub(frameworks_group_pattern, frameworks_group_replacement, content)
    
    # 写回文件
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ 已将FileProvider.framework添加到主应用")
    print("🔧 已更新的配置:")
    print("   - PBXBuildFile entry")
    print("   - PBXFileReference entry") 
    print("   - 主应用Frameworks build phase")
    print("   - Frameworks group")

if __name__ == "__main__":
    add_file_provider_framework()
