import re

# 读取项目文件
with open('CiteTrack_macOS.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# 检查是否已有main.swift引用
if 'main.swift' not in content:
    # 添加main.swift文件引用
    file_ref = '''		862C869A3E62AB78FFEECAA1 /* main.swift */ = {isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; path = main.swift; sourceTree = "<group>"; };'''
    
    # 在End PBXFileReference section前添加
    content = re.sub(r'(/\* End PBXFileReference section \*/)', f'{file_ref}\n\t\t\\1', content)
    
    # 添加build file引用
    build_file = '''		C7ECE6BE327C41D741E11BC8 /* main.swift in Sources */ = {isa = PBXBuildFile; fileRef = 862C869A3E62AB78FFEECAA1 /* main.swift */; };'''
    content = re.sub(r'(/\* End PBXBuildFile section \*/)', f'{build_file}\n\t\t\\1', content)
    
    # 添加到Sources组
    sources_group = r'(Sources.*=.*{.*children.*=.*\()'
    main_file = '862C869A3E62AB78FFEECAA1 /* main.swift */,'
    content = re.sub(sources_group, f'\\1\n\t\t\t\t{main_file}', content)
    
    # 添加到Sources build phase
    sources_phase = r'(Sources.*=.*{.*files.*=.*\()'
    main_build = 'C7ECE6BE327C41D741E11BC8 /* main.swift in Sources */,'
    content = re.sub(sources_phase, f'\\1\n\t\t\t\t{main_build}', content)
    
    print("✅ 已添加main.swift到项目")
else:
    print("ℹ️ main.swift已存在于项目中")

# 写回文件
with open('CiteTrack_macOS.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)
