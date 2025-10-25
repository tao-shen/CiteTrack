#!/usr/bin/env python3
"""
为 CiteTrack v2.0.0 专业图表版本创建完整的 Xcode 项目
包含所有图表功能、Core Data 和 iCloud 支持
"""

import os
import sys
import uuid

def generate_uuid():
    """生成24位十六进制UUID（Xcode格式）"""
    return ''.join([format(x, '02X') for x in os.urandom(12)])

def create_v2_xcode_project():
    """创建 v2.0.0 Xcode 项目"""
    
    project_name = "CiteTrack_v2"
    
    # v2.0.0 所有源文件
    source_files = [
        'main.swift',
        'Localization.swift',
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
    
    # 生成所有 UUID
    uuids = {}
    for item in ['project', 'target', 'buildconfig_debug', 'buildconfig_release',
                 'sources_group', 'frameworks_group', 'products_group',
                 'build_phase_sources', 'build_phase_frameworks', 'build_phase_resources',
                 'sparkle_framework', 'sparkle_build', 'coredata_framework', 'coredata_build',
                 'usernotifications_framework', 'usernotifications_build',
                 'product_reference', 'entitlements', 'coredata_model']:
        uuids[item] = generate_uuid()
    
    # 为每个源文件生成 UUID
    file_uuids = {}
    build_uuids = {}
    for f in source_files:
        file_uuids[f] = generate_uuid()
        build_uuids[f] = generate_uuid()
    
    # 创建项目文件内容
    project_content = f'''// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 77;
\tobjects = {{

/* Begin PBXBuildFile section */
\t\t{uuids['sparkle_build']} /* Sparkle.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {uuids['sparkle_framework']} /* Sparkle.framework */; }};
\t\t{uuids['coredata_build']} /* CoreData.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {uuids['coredata_framework']} /* CoreData.framework */; }};
\t\t{uuids['usernotifications_build']} /* UserNotifications.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {uuids['usernotifications_framework']} /* UserNotifications.framework */; }};
'''
    
    # 添加所有源文件的 PBXBuildFile
    for f in source_files:
        project_content += f'\t\t{build_uuids[f]} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuids[f]} /* {f} */; }};\n'
    
    project_content += '''/* End PBXBuildFile section */

/* Begin PBXFileReference section */
'''
    
    project_content += f'''\t\t{uuids['product_reference']} /* CiteTrack.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = CiteTrack.app; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{uuids['sparkle_framework']} /* Sparkle.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = Sparkle.framework; path = Frameworks/Sparkle.framework; sourceTree = "<group>"; }};
\t\t{uuids['coredata_framework']} /* CoreData.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = CoreData.framework; path = System/Library/Frameworks/CoreData.framework; sourceTree = SDKROOT; }};
\t\t{uuids['usernotifications_framework']} /* UserNotifications.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = UserNotifications.framework; path = System/Library/Frameworks/UserNotifications.framework; sourceTree = SDKROOT; }};
\t\t{uuids['entitlements']} /* CiteTrack.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = CiteTrack.entitlements; sourceTree = "<group>"; }};
'''
    
    # 添加所有源文件的 PBXFileReference
    for f in source_files:
        project_content += f'\t\t{file_uuids[f]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = "<group>"; }};\n'
    
    project_content += '''/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
'''
    
    project_content += f'''\t\t{uuids['build_phase_frameworks']} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{uuids['sparkle_build']} /* Sparkle.framework in Frameworks */,
\t\t\t\t{uuids['coredata_build']} /* CoreData.framework in Frameworks */,
\t\t\t\t{uuids['usernotifications_build']} /* UserNotifications.framework in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{uuids['project']} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{uuids['sources_group']} /* Sources */,
\t\t\t\t{uuids['frameworks_group']} /* Frameworks */,
\t\t\t\t{uuids['products_group']} /* Products */,
\t\t\t\t{uuids['entitlements']} /* CiteTrack.entitlements */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{uuids['sources_group']} /* Sources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
'''
    
    # 添加所有源文件到 Sources 组
    for f in source_files:
        project_content += f'\t\t\t\t{file_uuids[f]} /* {f} */,\n'
    
    project_content += f'''\t\t\t);
\t\t\tpath = Sources;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{uuids['frameworks_group']} /* Frameworks */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{uuids['sparkle_framework']} /* Sparkle.framework */,
\t\t\t\t{uuids['coredata_framework']} /* CoreData.framework */,
\t\t\t\t{uuids['usernotifications_framework']} /* UserNotifications.framework */,
\t\t\t);
\t\t\tname = Frameworks;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{uuids['products_group']} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{uuids['product_reference']} /* CiteTrack.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{uuids['target']} /* CiteTrack */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {generate_uuid()} /* Build configuration list for PBXNativeTarget "CiteTrack" */;
\t\t\tbuildPhases = (
\t\t\t\t{uuids['build_phase_sources']} /* Sources */,
\t\t\t\t{uuids['build_phase_frameworks']} /* Frameworks */,
\t\t\t\t{uuids['build_phase_resources']} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = CiteTrack;
\t\t\tproductName = CiteTrack;
\t\t\tproductReference = {uuids['product_reference']} /* CiteTrack.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{generate_uuid()} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{uuids['target']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {generate_uuid()} /* Build configuration list for PBXProject "{project_name}" */;
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t\t"zh-Hans",
\t\t\t\tja,
\t\t\t\tko,
\t\t\t\tes,
\t\t\t\tfr,
\t\t\t\tde,
\t\t\t);
\t\t\tmainGroup = {uuids['project']};
\t\t\tproductRefGroup = {uuids['products_group']} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{uuids['target']} /* CiteTrack */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{uuids['build_phase_resources']} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{uuids['build_phase_sources']} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
'''
    
    # 添加所有源文件到 Sources Build Phase
    for f in source_files:
        project_content += f'\t\t\t\t{build_uuids[f]} /* {f} in Sources */,\n'
    
    project_content += f'''\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{uuids['buildconfig_debug']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASS SETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = CiteTrack.entitlements;
\t\t\t\tCODE_SIGN_IDENTITY = "Apple Development";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tCURRENT_PROJECT_VERSION = 2.0.0;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tDEVELOPMENT_TEAM = HNU7NA3S7L;
\t\t\t\tENABLE_HARDENED_RUNTIME = YES;
\t\t\t\tFRAMEWORK_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"$(PROJECT_DIR)/Frameworks",
\t\t\t\t);
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tINFOPLIST_FILE = "";
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = CiteTrack;
\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
\t\t\t\tINFOPLIST_KEY_LSUIElement = YES;
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "© 2024 CiteTrack. All rights reserved.";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t);
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 11.0;
\t\t\t\tMARKETING_VERSION = 2.0.0;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.citetrack.CiteTrack;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited) SPARKLE_ENABLED";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{uuids['buildconfig_release']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = CiteTrack.entitlements;
\t\t\t\tCODE_SIGN_IDENTITY = "Apple Development";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tCURRENT_PROJECT_VERSION = 2.0.0;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tDEVELOPMENT_TEAM = HNU7NA3S7L;
\t\t\t\tENABLE_HARDENED_RUNTIME = YES;
\t\t\t\tFRAMEWORK_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"$(PROJECT_DIR)/Frameworks",
\t\t\t\t);
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tINFOPLIST_FILE = "";
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = CiteTrack;
\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
\t\t\t\tINFOPLIST_KEY_LSUIElement = YES;
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "© 2024 CiteTrack. All rights reserved.";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t);
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 11.0;
\t\t\t\tMARKETING_VERSION = 2.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.citetrack.CiteTrack;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "SPARKLE_ENABLED";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
/* End XCConfigurationList section */
\t}};
\trootObject = {generate_uuid()} /* Project object */;
}}
'''
    
    # 创建项目目录
    project_dir = f"{project_name}.xcodeproj"
    os.makedirs(project_dir, exist_ok=True)
    
    # 写入项目文件
    with open(f"{project_dir}/project.pbxproj", "w") as f:
        f.write(project_content)
    
    print(f"✅ 创建了新的 Xcode 项目: {project_dir}")
    print(f"\n📊 包含 {len(source_files)} 个源文件")
    print("\n🚀 下一步:")
    print(f"   open {project_dir}")
    
    return True

if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    print("=" * 60)
    print("CiteTrack v2.0.0 专业图表版本 Xcode 项目创建")
    print("=" * 60)
    print()
    
    create_v2_xcode_project()

