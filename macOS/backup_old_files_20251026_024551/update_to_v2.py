import re

# 读取项目文件
with open('CiteTrack_macOS.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# 1. 更新版本号到2.0.0
content = re.sub(r'MARKETING_VERSION = 1\.1\.3;', 'MARKETING_VERSION = 2.0.0;', content)

# 2. 移除所有v1.1.3文件引用
old_files = [
    'SettingsWindow_v1.1.3.swift',
    'main_v1.1.3.swift'
]

for file in old_files:
    # 移除PBXBuildFile引用
    content = re.sub(f'.*{re.escape(file)}.*\\n', '', content)
    # 移除PBXFileReference
    content = re.sub(f'.*{re.escape(file)}.*\\n', '', content)

# 3. 添加v2.0.0文件到Sources组
sources_group_pattern = r'(Sources.*=.*{.*children.*=.*\()'
new_files = [
    'F8201E229AB25E04F07582CB /* Scholar.swift */,',
    '15B99F1810AD9CC6545FB2DE /* DataManager.swift */,',
    'DB1E4DA445D1C7DA6249F353 /* MainAppDelegate.swift */,'
]

for file in new_files:
    if file not in content:
        content = re.sub(sources_group_pattern, f'\\1\n\t\t\t\t{file}', content)

# 4. 添加文件引用
file_refs = '''
		15B99F1810AD9CC6545FB2DE /* DataManager.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = DataManager.swift; path = Sources/DataManager.swift; sourceTree = "<group>"; };
		DB1E4DA445D1C7DA6249F353 /* MainAppDelegate.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = MainAppDelegate.swift; path = Sources/MainAppDelegate.swift; sourceTree = "<group>"; };
		F8201E229AB25E04F07582CB /* Scholar.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; name = Scholar.swift; path = Sources/Scholar.swift; sourceTree = "<group>"; };
		Info.plist /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = Info.plist; path = Info.plist; sourceTree = "<group>"; };
		Assets.xcassets /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = Assets.xcassets; path = Assets.xcassets; sourceTree = "<group>"; };'''

# 在End PBXFileReference section前添加
content = re.sub(r'(/\* End PBXFileReference section \*/)', f'{file_refs}\n\t\t\\1', content)

# 5. 添加build file引用
build_files = '''
		0D6E0EDF9EDE2B27774DC96B /* Scholar.swift in Sources */ = {isa = PBXBuildFile; fileRef = F8201E229AB25E04F07582CB /* Scholar.swift */; };
		AA799A143AD35C235C00A0D9 /* DataManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = 15B99F1810AD9CC6545FB2DE /* DataManager.swift */; };
		7BB72E3C648EAD62B1373B9A /* MainAppDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = DB1E4DA445D1C7DA6249F353 /* MainAppDelegate.swift */; };'''

content = re.sub(r'(/\* End PBXBuildFile section \*/)', f'{build_files}\n\t\t\\1', content)

# 6. 更新build settings
content = re.sub(r'GENERATE_INFOPLIST_FILE = NO;', 'GENERATE_INFOPLIST_FILE = NO;\n\t\t\t\tINFOPLIST_FILE = Info.plist;', content)

# 写回文件
with open('CiteTrack_macOS.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("✅ 项目已更新到v2.0.0")
print("✅ 移除了v1.1.3文件")
print("✅ 添加了v2.0.0文件")
