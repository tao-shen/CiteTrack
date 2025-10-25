import re

# 读取项目文件
with open('CiteTrack_macOS.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# 彻底修复所有路径问题
content = re.sub(r'Sources/Sources/', 'Sources/', content)
content = re.sub(r'path = Sources/Sources/', 'path = Sources/', content)

# 写回文件
with open('CiteTrack_macOS.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("✅ 彻底修复了所有路径问题")
