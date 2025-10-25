import re

# 读取项目文件
with open('CiteTrack_macOS.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# 修复重复的路径 (Sources/Sources/ -> Sources/)
content = re.sub(r'Sources/Sources/', 'Sources/', content)

# 写回文件
with open('CiteTrack_macOS.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("✅ 修复了pbxproj文件中的路径")
