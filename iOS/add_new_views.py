#!/usr/bin/env python3
"""
添加新的视图文件到 Xcode 项目中
"""

import sys
import uuid
from pathlib import Path

def generate_uuid():
    """生成一个24位的16进制UUID（用于Xcode项目文件）"""
    return uuid.uuid4().hex[:24].upper()

def add_files_to_project(project_path: str, files: list):
    """添加文件到 Xcode 项目"""
    
    with open(project_path, 'r') as f:
        lines = f.readlines()
    
    # 为每个文件生成UUID
    file_info = []
    for file_path in files:
        filename = Path(file_path).name
        file_ref = generate_uuid()
        build_ref = generate_uuid()
        file_info.append({
            'name': filename,
            'path': file_path,
            'file_ref': file_ref,
            'build_ref': build_ref
        })
    
    # 1. 添加 PBXBuildFile 条目
    pbx_build_file_index = None
    for i, line in enumerate(lines):
        if '/* Begin PBXBuildFile section */' in line:
            pbx_build_file_index = i + 1
            break
    
    if pbx_build_file_index:
        for info in file_info:
            build_entry = f"\t\t{info['build_ref']} /* {info['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {info['file_ref']} /* {info['name']} */; }};\n"
            lines.insert(pbx_build_file_index, build_entry)
            pbx_build_file_index += 1
    
    # 2. 添加 PBXFileReference 条目
    pbx_file_ref_index = None
    for i, line in enumerate(lines):
        if '/* Begin PBXFileReference section */' in line:
            pbx_file_ref_index = i + 1
            break
    
    if pbx_file_ref_index:
        for info in file_info:
            file_entry = f"\t\t{info['file_ref']} /* {info['name']} */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = {info['name']}; sourceTree = \"<group>\"; }};\n"
            lines.insert(pbx_file_ref_index, file_entry)
            pbx_file_ref_index += 1
    
    # 3. 添加到 Views 组（查找 Views 文件夹组）
    views_group_index = None
    for i, line in enumerate(lines):
        if 'name = Views;' in line or '/* Views */ = {' in line:
            # 找到 Views 组，向后查找 children 数组
            for j in range(i, min(i + 20, len(lines))):
                if 'children = (' in lines[j]:
                    views_group_index = j + 1
                    break
            break
    
    if views_group_index:
        for info in file_info:
            child_entry = f"\t\t\t\t{info['file_ref']} /* {info['name']} */,\n"
            lines.insert(views_group_index, child_entry)
            views_group_index += 1
    
    # 4. 添加到编译源文件（PBXSourcesBuildPhase）
    sources_build_phase_index = None
    main_target_found = False
    
    for i, line in enumerate(lines):
        if '/* Begin PBXSourcesBuildPhase section */' in line:
            # 查找主目标的 Sources Build Phase
            for j in range(i, min(i + 100, len(lines))):
                if 'files = (' in lines[j]:
                    # 确保这是主target，不是widget
                    context = ''.join(lines[max(0, j-10):j])
                    if 'Widget' not in context:
                        sources_build_phase_index = j + 1
                        main_target_found = True
                        break
            if main_target_found:
                break
    
    if sources_build_phase_index:
        for info in file_info:
            source_entry = f"\t\t\t\t{info['build_ref']} /* {info['name']} in Sources */,\n"
            lines.insert(sources_build_phase_index, source_entry)
            sources_build_phase_index += 1
    
    # 写回文件
    with open(project_path, 'w') as f:
        f.writelines(lines)
    
    print(f"✅ Successfully added {len(files)} files to project")
    for info in file_info:
        print(f"   - {info['name']}")

def main():
    project_path = '/Users/tao.shen/google_scholar_plugin/iOS/CiteTrack_iOS.xcodeproj/project.pbxproj'
    
    new_files = [
        'InfoBanner.swift',
        'PublicationListView.swift',
        'PublicationStatisticsView.swift'
    ]
    
    print("Adding new view files to Xcode project...")
    add_files_to_project(project_path, new_files)
    print("Done!")

if __name__ == '__main__':
    main()

