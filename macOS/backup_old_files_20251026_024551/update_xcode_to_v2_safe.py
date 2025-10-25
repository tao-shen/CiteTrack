#!/usr/bin/env python3
"""
安全地将 Xcode 项目更新到 v2.0.0
使用精确的字符串替换，避免破坏项目结构
"""

import sys
import os
import re

def generate_uuid():
    """生成24位十六进制UUID（Xcode格式）"""
    return ''.join([format(x, '02X') for x in os.urandom(12)])

def safe_update_project(pbxproj_path):
    """安全地更新项目文件"""
    
    print("📝 读取项目文件...")
    with open(pbxproj_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # v2.0.0 需要添加的源文件（除了已有的 Localization.swift）
    new_files = [
        'main.swift',
        'SettingsWindow.swift',
        'CoreDataManager.swift',
        'CitationHistoryEntity.swift',
        'CitationHistory.swift',
        'CitationHistoryManager.swift',
        'GoogleScholarService+History.swift',
        'ChartDataService.swift',
        'ChartView.swift',
        'ChartsViewController.swift',
        'ChartsWindowController.swift',
        'DataRepairViewController.swift',
        'iCloudSyncManager.swift',
        'NotificationManager.swift',
        'DashboardComponents.swift',
        'EnhancedChartTypes.swift',
        'ModernCardView.swift',
    ]
    
    # 步骤 1: 移除 v1.1.3 文件的 PBXBuildFile 引用
    print("\n🗑️  步骤 1: 移除 v1.1.3 文件...")
    
    # 移除 main_v1.1.3.swift 的 PBXBuildFile
    content = re.sub(
        r'\t\tA5BD548B628D460385C8519A /\* main_v1\.1\.3\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = CE0A86B0D7AB4098B766157C /\* main_v1\.1\.3\.swift \*/; \};\n',
        '',
        content
    )
    
    # 移除 SettingsWindow_v1.1.3.swift 的 PBXBuildFile
    content = re.sub(
        r'\t\t4DBA82E261094BBC94768B81 /\* SettingsWindow_v1\.1\.3\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = 0CC1AB33A9B14C1983488F5E /\* SettingsWindow_v1\.1\.3\.swift \*/; \};\n',
        '',
        content
    )
    
    # 移除 v1.1.3 文件的 PBXFileReference
    content = re.sub(
        r'\t\t0CC1AB33A9B14C1983488F5E /\* SettingsWindow_v1\.1\.3\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = SettingsWindow_v1\.1\.3\.swift; sourceTree = "<group>"; \};\n',
        '',
        content
    )
    
    content = re.sub(
        r'\t\tCE0A86B0D7AB4098B766157C /\* main_v1\.1\.3\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = main_v1\.1\.3\.swift; sourceTree = "<group>"; \};\n',
        '',
        content
    )
    
    # 从 Sources 组中移除
    content = re.sub(
        r'\t\t\t\tCE0A86B0D7AB4098B766157C /\* main_v1\.1\.3\.swift \*/,\n',
        '',
        content
    )
    
    content = re.sub(
        r'\t\t\t\t0CC1AB33A9B14C1983488F5E /\* SettingsWindow_v1\.1\.3\.swift \*/,\n',
        '',
        content
    )
    
    # 从 Sources Build Phase 中移除
    content = re.sub(
        r'\t\t\t\tA5BD548B628D460385C8519A /\* main_v1\.1\.3\.swift in Sources \*/,\n',
        '',
        content
    )
    
    content = re.sub(
        r'\t\t\t\t4DBA82E261094BBC94768B81 /\* SettingsWindow_v1\.1\.3\.swift in Sources \*/,\n',
        '',
        content
    )
    
    print("  ✅ 已移除 main_v1.1.3.swift 和 SettingsWindow_v1.1.3.swift")
    
    # 步骤 2: 为新文件生成 UUID
    print("\n📝 步骤 2: 生成新文件的 UUID...")
    file_uuids = {}
    build_uuids = {}
    for f in new_files:
        file_uuids[f] = generate_uuid()
        build_uuids[f] = generate_uuid()
        print(f"  ✅ {f}")
    
    # 步骤 3: 添加 PBXBuildFile 条目
    print("\n➕ 步骤 3: 添加 PBXBuildFile 条目...")
    build_file_section = "/* Begin PBXBuildFile section */"
    build_file_pos = content.find(build_file_section) + len(build_file_section) + 1
    
    new_build_files = ""
    for f in new_files:
        new_build_files += f"\t\t{build_uuids[f]} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuids[f]} /* {f} */; }};\n"
    
    content = content[:build_file_pos] + new_build_files + content[build_file_pos:]
    print(f"  ✅ 添加了 {len(new_files)} 个 PBXBuildFile 条目")
    
    # 步骤 4: 添加 PBXFileReference 条目
    print("\n➕ 步骤 4: 添加 PBXFileReference 条目...")
    file_ref_section = "/* Begin PBXFileReference section */"
    file_ref_pos = content.find(file_ref_section) + len(file_ref_section) + 1
    
    new_file_refs = ""
    for f in new_files:
        new_file_refs += f"\t\t{file_uuids[f]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = \"<group>\"; }};\n"
    
    content = content[:file_ref_pos] + new_file_refs + content[file_ref_pos:]
    print(f"  ✅ 添加了 {len(new_files)} 个 PBXFileReference 条目")
    
    # 步骤 5: 添加到 Sources 组
    print("\n➕ 步骤 5: 添加到 Sources 组...")
    # 找到 Sources 组的 children 部分
    sources_pattern = r'(10868796DF6E478EBB8857C3 /\* Sources \*/ = \{[^}]+children = \(\n)'
    match = re.search(sources_pattern, content)
    if match:
        insert_pos = match.end()
        new_sources = ""
        for f in new_files:
            new_sources += f"\t\t\t\t{file_uuids[f]} /* {f} */,\n"
        content = content[:insert_pos] + new_sources + content[insert_pos:]
        print(f"  ✅ 添加了 {len(new_files)} 个文件到 Sources 组")
    
    # 步骤 6: 添加到 Sources Build Phase
    print("\n➕ 步骤 6: 添加到 Sources Build Phase...")
    # 找到 Sources Build Phase
    sources_build_pattern = r'(B0AD46090196463BBC57C24E /\* Sources \*/ = \{[^}]+files = \(\n)'
    match = re.search(sources_build_pattern, content)
    if match:
        insert_pos = match.end()
        new_build_phase = ""
        for f in new_files:
            new_build_phase += f"\t\t\t\t{build_uuids[f]} /* {f} in Sources */,\n"
        content = content[:insert_pos] + new_build_phase + content[insert_pos:]
        print(f"  ✅ 添加了 {len(new_files)} 个文件到 Sources Build Phase")
    
    # 步骤 7: 添加 CoreData 和 UserNotifications 框架
    print("\n📦 步骤 7: 添加系统框架...")
    
    # 生成框架 UUID
    coredata_uuid = generate_uuid()
    coredata_build_uuid = generate_uuid()
    usernotif_uuid = generate_uuid()
    usernotif_build_uuid = generate_uuid()
    
    # 添加框架的 PBXBuildFile
    build_file_pos = content.find("/* Begin PBXBuildFile section */") + len("/* Begin PBXBuildFile section */") + 1
    framework_build_files = f"\t\t{coredata_build_uuid} /* CoreData.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {coredata_uuid} /* CoreData.framework */; }};\n"
    framework_build_files += f"\t\t{usernotif_build_uuid} /* UserNotifications.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {usernotif_uuid} /* UserNotifications.framework */; }};\n"
    content = content[:build_file_pos] + framework_build_files + content[build_file_pos:]
    
    # 添加框架的 PBXFileReference
    file_ref_pos = content.find("/* Begin PBXFileReference section */") + len("/* Begin PBXFileReference section */") + 1
    framework_refs = f"\t\t{coredata_uuid} /* CoreData.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = CoreData.framework; path = System/Library/Frameworks/CoreData.framework; sourceTree = SDKROOT; }};\n"
    framework_refs += f"\t\t{usernotif_uuid} /* UserNotifications.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = UserNotifications.framework; path = System/Library/Frameworks/UserNotifications.framework; sourceTree = SDKROOT; }};\n"
    content = content[:file_ref_pos] + framework_refs + content[file_ref_pos:]
    
    # 添加到 Frameworks 组
    frameworks_pattern = r'(A327CF1C6E194DC6AFD79525 /\* Frameworks \*/ = \{[^}]+children = \(\n)'
    match = re.search(frameworks_pattern, content)
    if match:
        insert_pos = match.end()
        framework_group = f"\t\t\t\t{coredata_uuid} /* CoreData.framework */,\n"
        framework_group += f"\t\t\t\t{usernotif_uuid} /* UserNotifications.framework */,\n"
        content = content[:insert_pos] + framework_group + content[insert_pos:]
    
    # 添加到 Frameworks Build Phase
    frameworks_build_pattern = r'(A175C7E927F949C496D4E55B /\* Frameworks \*/ = \{[^}]+files = \(\n)'
    match = re.search(frameworks_build_pattern, content)
    if match:
        insert_pos = match.end()
        framework_build = f"\t\t\t\t{coredata_build_uuid} /* CoreData.framework in Frameworks */,\n"
        framework_build += f"\t\t\t\t{usernotif_build_uuid} /* UserNotifications.framework in Frameworks */,\n"
        content = content[:insert_pos] + framework_build + content[insert_pos:]
    
    print("  ✅ 添加了 CoreData.framework")
    print("  ✅ 添加了 UserNotifications.framework")
    
    # 步骤 8: 更新版本号
    print("\n🔢 步骤 8: 更新版本号到 2.0.0...")
    content = re.sub(
        r'MARKETING_VERSION = [^;]+;',
        'MARKETING_VERSION = 2.0.0;',
        content
    )
    content = re.sub(
        r'CURRENT_PROJECT_VERSION = [^;]+;',
        'CURRENT_PROJECT_VERSION = 2.0.0;',
        content
    )
    print("  ✅ 版本号已更新为 2.0.0")
    
    # 验证修改
    if content == original_content:
        print("\n⚠️  警告：项目文件没有改变")
        return False
    
    # 写入文件
    print("\n💾 保存项目文件...")
    with open(pbxproj_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ 项目文件更新完成！")
    return True

def main():
    pbxproj_path = 'CiteTrack_macOS.xcodeproj/project.pbxproj'
    
    if not os.path.exists(pbxproj_path):
        print(f"❌ 找不到项目文件: {pbxproj_path}")
        return 1
    
    print("=" * 70)
    print("🚀 CiteTrack v2.0.0 Xcode 项目安全更新")
    print("=" * 70)
    print()
    
    if safe_update_project(pbxproj_path):
        print("\n" + "=" * 70)
        print("🎉 项目更新成功！")
        print("=" * 70)
        print("\n📊 v2.0.0 包含:")
        print("  • 18 个新源文件（图表、Core Data、通知等）")
        print("  • CoreData.framework")
        print("  • UserNotifications.framework")
        print("\n🔨 下一步：使用 Xcode 编译")
        print("  xcodebuild -project CiteTrack_macOS.xcodeproj -scheme CiteTrack -configuration Debug build")
        return 0
    else:
        print("\n❌ 项目更新失败")
        return 1

if __name__ == '__main__':
    sys.exit(main())

