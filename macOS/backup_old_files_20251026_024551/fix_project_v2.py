import re

# 读取项目文件
with open('CiteTrack_macOS.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# 1. 更新版本号
content = re.sub(r'MARKETING_VERSION = 1\.1\.3;', 'MARKETING_VERSION = 2.0.0;', content)
content = re.sub(r'CURRENT_PROJECT_VERSION = 1;', 'CURRENT_PROJECT_VERSION = 1;', content)

# 2. 替换v1.1.3文件为v2.0.0文件
# 移除v1.1.3文件引用
content = re.sub(r'.*SettingsWindow_v1\.1\.3\.swift.*\n', '', content)
content = re.sub(r'.*main_v1\.1\.3\.swift.*\n', '', content)

# 3. 添加v2.0.0文件
# 添加Scholar.swift
if 'Scholar.swift' not in content:
    # 在PBXFileReference section添加
    file_ref_pattern = r'(/\* End PBXFileReference section \*/)'
    scholar_ref = '''		15B99F1810AD9CC6545FB2DE /* Scholar.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = Scholar.swift; path = Sources/Scholar.swift; sourceTree = "<group>"; };
		DB1E4DA445D1C7DA6249F353 /* MainAppDelegate.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = MainAppDelegate.swift; path = Sources/MainAppDelegate.swift; sourceTree = "<group>"; };
		F8201E229AB25E04F07582CB /* Scholar.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = Scholar.swift; path = Sources/Scholar.swift; sourceTree = "<group>"; };
		DataManager.swift /* DataManager.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = DataManager.swift; path = Sources/DataManager.swift; sourceTree = "<group>"; };
		Info.plist /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = Info.plist; path = Info.plist; sourceTree = "<group>"; };
		Assets.xcassets /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = Assets.xcassets; path = Assets.xcassets; sourceTree = "<group>"; };
		\\1'''
    content = re.sub(file_ref_pattern, scholar_ref, content)

# 4. 更新build settings
content = re.sub(r'GENERATE_INFOPLIST_FILE = NO;', 'GENERATE_INFOPLIST_FILE = NO;\n\t\t\t\tINFOPLIST_FILE = Info.plist;', content)
content = re.sub(r'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;', 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;', content)

# 写回文件
with open('CiteTrack_macOS.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("✅ 项目版本已更新到2.0.0")
print("✅ 已移除v1.1.3文件引用")
print("✅ 已添加v2.0.0文件引用")
