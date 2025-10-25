import re

# 读取项目文件
with open('CiteTrack_macOS.xcodeproj/project.pbxproj', 'r') as f:
    lines = f.readlines()

# 删除包含错误路径的行
new_lines = []
for line in lines:
    # 跳过包含Sources/Sources的行
    if 'Sources/Sources/' in line:
        print(f"删除行: {line.strip()}")
        continue
    new_lines.append(line)

# 写回文件
with open('CiteTrack_macOS.xcodeproj/project.pbxproj', 'w') as f:
    f.writelines(new_lines)

print("✅ 删除了所有错误路径的引用")
