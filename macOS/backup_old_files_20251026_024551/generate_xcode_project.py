#!/usr/bin/env python3
"""
生成 CiteTrack macOS Xcode 项目文件
"""

import os
import uuid
from pathlib import Path

def generate_uuid():
    """生成 24 位的 UUID (Xcode 格式)"""
    return uuid.uuid4().hex[:24].upper()

def get_source_files():
    """获取所有源文件"""
    sources_dir = Path("Sources")
    swift_files = list(sources_dir.glob("*.swift"))
    return sorted([f.name for f in swift_files])

def create_project_structure():
    """创建项目结构"""
    project_dir = Path("CiteTrack_macOS.xcodeproj")
    project_dir.mkdir(exist_ok=True)
    
    workspace_dir = project_dir / "project.xcworkspace"
    workspace_dir.mkdir(exist_ok=True)
    
    xcshared_dir = project_dir / "xcshareddata" / "xcschemes"
    xcshared_dir.mkdir(parents=True, exist_ok=True)
    
    return project_dir, workspace_dir, xcshared_dir

def generate_project_file(source_files):
    """生成 project.pbxproj 文件"""
    
    # 生成所有需要的 UUID
    uuids = {
        'project': generate_uuid(),
        'main_group': generate_uuid(),
        'products_group': generate_uuid(),
        'sources_group': generate_uuid(),
        'frameworks_group': generate_uuid(),
        'resources_group': generate_uuid(),
        'assets_group': generate_uuid(),
        'target': generate_uuid(),
        'config_list_project': generate_uuid(),
        'config_list_target': generate_uuid(),
        'build_config_debug': generate_uuid(),
        'build_config_release': generate_uuid(),
        'build_config_target_debug': generate_uuid(),
        'build_config_target_release': generate_uuid(),
        'source_build_phase': generate_uuid(),
        'frameworks_build_phase': generate_uuid(),
        'resources_build_phase': generate_uuid(),
        'copy_frameworks_phase': generate_uuid(),
        'product_ref': generate_uuid(),
        'entitlements': generate_uuid(),
        'sparkle_framework': generate_uuid(),
        'sparkle_build': generate_uuid(),
        'sparkle_embed': generate_uuid(),
        'icon': generate_uuid(),
        'icon_build': generate_uuid(),
        'appcast': generate_uuid(),
        'coredata_model': generate_uuid(),
        'coredata_build': generate_uuid(),
        'shared_constants': generate_uuid(),
        'shared_constants_build': generate_uuid(),
    }
    
    # 为每个源文件生成 UUID
    file_refs = {}
    build_files = {}
    for filename in source_files:
        file_refs[filename] = generate_uuid()
        build_files[filename] = generate_uuid()
    
    # 开始生成项目文件内容
    content = """// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
"""
    
    # 添加所有源文件的 PBXBuildFile
    for filename in source_files:
        content += f"\t\t{build_files[filename]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[filename]} /* {filename} */; }};\n"
    
    # 添加其他文件的 PBXBuildFile
    content += f"\t\t{uuids['coredata_build']} /* CitationTrackingModel.xcdatamodeld in Sources */ = {{isa = PBXBuildFile; fileRef = {uuids['coredata_model']} /* CitationTrackingModel.xcdatamodeld */; }};\n"
    content += f"\t\t{uuids['shared_constants_build']} /* Constants.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {uuids['shared_constants']} /* Constants.swift */; }};\n"
    content += f"\t\t{uuids['sparkle_build']} /* Sparkle.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {uuids['sparkle_framework']} /* Sparkle.framework */; }};\n"
    content += f"\t\t{uuids['sparkle_embed']} /* Sparkle.framework in Embed Frameworks */ = {{isa = PBXBuildFile; fileRef = {uuids['sparkle_framework']} /* Sparkle.framework */; settings = {{ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }}; }};\n"
    content += f"\t\t{uuids['icon_build']} /* app_icon.icns in Resources */ = {{isa = PBXBuildFile; fileRef = {uuids['icon']} /* app_icon.icns */; }};\n"
    
    content += """/* End PBXBuildFile section */

/* Begin PBXCopyFilesBuildPhase section */
"""
    content += f"""\t\t{uuids['copy_frameworks_phase']} /* Embed Frameworks */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 10;
\t\t\tfiles = (
\t\t\t\t{uuids['sparkle_embed']} /* Sparkle.framework in Embed Frameworks */,
\t\t\t);
\t\t\tname = "Embed Frameworks";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
"""
    
    # 添加所有源文件的 PBXFileReference
    for filename in source_files:
        content += f"\t\t{file_refs[filename]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"
    
    # 添加其他文件引用
    content += f"""\t\t{uuids['coredata_model']} /* CitationTrackingModel.xcdatamodeld */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.xcdatamodeld; path = CitationTrackingModel.xcdatamodeld; sourceTree = "<group>"; }};
\t\t{uuids['shared_constants']} /* Constants.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = Constants.swift; path = ../Shared/Constants.swift; sourceTree = "<group>"; }};
\t\t{uuids['product_ref']} /* CiteTrack.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = CiteTrack.app; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{uuids['entitlements']} /* CiteTrack.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = CiteTrack.entitlements; sourceTree = "<group>"; }};
\t\t{uuids['icon']} /* app_icon.icns */ = {{isa = PBXFileReference; lastKnownFileType = image.icns; name = app_icon.icns; path = assets/app_icon.icns; sourceTree = "<group>"; }};
\t\t{uuids['sparkle_framework']} /* Sparkle.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = Sparkle.framework; path = Frameworks/Sparkle.framework; sourceTree = "<group>"; }};
\t\t{uuids['appcast']} /* appcast.xml */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = appcast.xml; sourceTree = "<group>"; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{uuids['frameworks_build_phase']} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{uuids['sparkle_build']} /* Sparkle.framework in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{uuids['main_group']} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{uuids['sources_group']} /* Sources */,
\t\t\t\t{uuids['frameworks_group']} /* Frameworks */,
\t\t\t\t{uuids['resources_group']} /* Resources */,
\t\t\t\t{uuids['products_group']} /* Products */,
\t\t\t\t{uuids['shared_constants']} /* Constants.swift */,
\t\t\t\t{uuids['entitlements']} /* CiteTrack.entitlements */,
\t\t\t\t{uuids['appcast']} /* appcast.xml */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{uuids['products_group']} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{uuids['product_ref']} /* CiteTrack.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{uuids['sources_group']} /* Sources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
"""
    
    # 添加所有源文件到 Sources 组
    for filename in source_files:
        content += f"\t\t\t\t{file_refs[filename]} /* {filename} */,\n"
    
    content += f"\t\t\t\t{uuids['coredata_model']} /* CitationTrackingModel.xcdatamodeld */,\n"
    
    content += f"""\t\t\t);
\t\t\tpath = Sources;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{uuids['frameworks_group']} /* Frameworks */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{uuids['sparkle_framework']} /* Sparkle.framework */,
\t\t\t);
\t\t\tname = Frameworks;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{uuids['resources_group']} /* Resources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{uuids['assets_group']} /* assets */,
\t\t\t);
\t\t\tname = Resources;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{uuids['assets_group']} /* assets */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{uuids['icon']} /* app_icon.icns */,
\t\t\t);
\t\t\tname = assets;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{uuids['target']} /* CiteTrack */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {uuids['config_list_target']} /* Build configuration list for PBXNativeTarget "CiteTrack" */;
\t\t\tbuildPhases = (
\t\t\t\t{uuids['source_build_phase']} /* Sources */,
\t\t\t\t{uuids['frameworks_build_phase']} /* Frameworks */,
\t\t\t\t{uuids['resources_build_phase']} /* Resources */,
\t\t\t\t{uuids['copy_frameworks_phase']} /* Embed Frameworks */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = CiteTrack;
\t\t\tproductName = CiteTrack;
\t\t\tproductReference = {uuids['product_ref']} /* CiteTrack.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{uuids['project']} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{uuids['target']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {uuids['config_list_project']} /* Build configuration list for PBXProject "CiteTrack_macOS" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
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
\t\t\tmainGroup = {uuids['main_group']};
\t\t\tproductRefGroup = {uuids['products_group']} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{uuids['target']} /* CiteTrack */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{uuids['resources_build_phase']} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{uuids['icon_build']} /* app_icon.icns in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{uuids['source_build_phase']} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
"""
    
    # 添加所有源文件到 Sources 构建阶段
    for filename in source_files:
        content += f"\t\t\t\t{build_files[filename]} /* {filename} in Sources */,\n"
    
    content += f"\t\t\t\t{uuids['coredata_build']} /* CitationTrackingModel.xcdatamodeld in Sources */,\n"
    content += f"\t\t\t\t{uuids['shared_constants_build']} /* Constants.swift in Sources */,\n"
    
    content += f"""\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{uuids['build_config_debug']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 10.15;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{uuids['build_config_release']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 10.15;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{uuids['build_config_target_debug']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = CiteTrack.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_HARDENED_RUNTIME = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = CiteTrack;
\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
\t\t\t\tINFOPLIST_KEY_LSUIElement = YES;
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "© 2024 CiteTrack. All rights reserved.";
\t\t\t\tINFOPLIST_KEY_NSMainStoryboardFile = "";
\t\t\t\tINFOPLIST_KEY_NSPrincipalClass = NSApplication;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.1.3;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.citetrack.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tFRAMEWORK_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"$(PROJECT_DIR)/Frameworks",
\t\t\t\t);
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{uuids['build_config_target_release']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = CiteTrack.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_HARDENED_RUNTIME = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = CiteTrack;
\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
\t\t\t\tINFOPLIST_KEY_LSUIElement = YES;
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "© 2024 CiteTrack. All rights reserved.";
\t\t\t\tINFOPLIST_KEY_NSMainStoryboardFile = "";
\t\t\t\tINFOPLIST_KEY_NSPrincipalClass = NSApplication;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.1.3;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.citetrack.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tFRAMEWORK_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"$(PROJECT_DIR)/Frameworks",
\t\t\t\t);
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{uuids['config_list_project']} /* Build configuration list for PBXProject "CiteTrack_macOS" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{uuids['build_config_debug']} /* Debug */,
\t\t\t\t{uuids['build_config_release']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{uuids['config_list_target']} /* Build configuration list for PBXNativeTarget "CiteTrack" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{uuids['build_config_target_debug']} /* Debug */,
\t\t\t\t{uuids['build_config_target_release']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
\t}};
\trootObject = {uuids['project']} /* Project object */;
}}
"""
    
    return content, uuids

def create_workspace_file():
    """创建 workspace 文件"""
    return """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""

def create_scheme_file(target_uuid):
    """创建 scheme 文件"""
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.3">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_uuid}"
               BuildableName = "CiteTrack.app"
               BlueprintName = "CiteTrack"
               ReferencedContainer = "container:CiteTrack_macOS.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_uuid}"
            BuildableName = "CiteTrack.app"
            BlueprintName = "CiteTrack"
            ReferencedContainer = "container:CiteTrack_macOS.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_uuid}"
            BuildableName = "CiteTrack.app"
            BlueprintName = "CiteTrack"
            ReferencedContainer = "container:CiteTrack_macOS.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""

def main():
    print("📦 生成 CiteTrack macOS Xcode 项目...")
    
    # 获取源文件列表
    source_files = get_source_files()
    print(f"✅ 找到 {len(source_files)} 个源文件")
    
    # 创建项目结构
    project_dir, workspace_dir, xcshared_dir = create_project_structure()
    print("✅ 创建项目目录结构")
    
    # 生成项目文件
    project_content, uuids = generate_project_file(source_files)
    project_file = project_dir / "project.pbxproj"
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(project_content)
    print("✅ 生成 project.pbxproj 文件")
    
    # 生成 workspace 文件
    workspace_content = create_workspace_file()
    workspace_file = workspace_dir / "contents.xcworkspacedata"
    with open(workspace_file, 'w', encoding='utf-8') as f:
        f.write(workspace_content)
    print("✅ 生成 workspace 文件")
    
    # 生成 scheme 文件
    scheme_content = create_scheme_file(uuids['target'])
    scheme_file = xcshared_dir / "CiteTrack.xcscheme"
    with open(scheme_file, 'w', encoding='utf-8') as f:
        f.write(scheme_content)
    print("✅ 生成 scheme 文件")
    
    print("\n🎉 CiteTrack_macOS.xcodeproj 创建成功！")
    print(f"📁 项目位置: {project_dir.absolute()}")
    print("\n✅ 项目包含:")
    print(f"  • {len(source_files)} 个 Swift 源文件")
    print("  • CoreData 模型")
    print("  • Sparkle 自动更新框架")
    print("  • 应用图标和资源")
    print("  • CiteTrack.entitlements（包含 iCloud 支持）")
    print("\n🚀 现在可以在 Xcode 中打开项目：")
    print(f"   open {project_dir}")

if __name__ == "__main__":
    main()

