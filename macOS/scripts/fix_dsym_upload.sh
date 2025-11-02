#!/bin/bash

# 修复dSYM符号上传问题的脚本
# 这个脚本确保在Archive时生成dSYM文件

echo "🔧 修复dSYM符号上传问题..."

# 检查是否在Xcode项目中
if [ ! -f "CiteTrack_macOS.xcodeproj/project.pbxproj" ]; then
    echo "❌ 错误：请在Xcode项目根目录下运行此脚本"
    exit 1
fi

# 备份原始项目文件
cp CiteTrack_macOS.xcodeproj/project.pbxproj CiteTrack_macOS.xcodeproj/project.pbxproj.backup

echo "✅ 已备份项目文件"

# 使用sed命令修改项目设置以启用dSYM生成
# 这需要手动在Xcode中设置，但我们可以提供指导

echo "📋 请在Xcode中执行以下步骤来修复dSYM问题："
echo ""
echo "1. 打开 CiteTrack_macOS.xcodeproj"
echo "2. 选择项目根节点"
echo "3. 选择 CiteTrack target"
echo "4. 进入 Build Settings 标签"
echo "5. 搜索 'Debug Information Format'"
echo "6. 将 Debug 和 Release 都设置为 'DWARF with dSYM File'"
echo "7. 搜索 'Strip Debug Symbols During Copy'"
echo "8. 将 Release 设置为 'NO'"
echo ""
echo "或者运行以下命令来自动设置："

# 创建自动修复脚本
cat > fix_dsym_settings.py << 'EOF'
#!/usr/bin/env python3
import re
import sys

def fix_dsym_settings(project_file):
    """修复项目文件中的dSYM设置"""
    
    with open(project_file, 'r') as f:
        content = f.read()
    
    # 备份原文件
    with open(project_file + '.backup', 'w') as f:
        f.write(content)
    
    # 查找并修改Debug Information Format设置
    # 将DWARF改为DWARF with dSYM File
    content = re.sub(
        r'DEBUG_INFORMATION_FORMAT = dwarf;',
        'DEBUG_INFORMATION_FORMAT = dwarf-with-dsym;',
        content
    )
    
    # 确保Release配置也使用dSYM
    content = re.sub(
        r'DEBUG_INFORMATION_FORMAT = dwarf;',
        'DEBUG_INFORMATION_FORMAT = dwarf-with-dsym;',
        content
    )
    
    # 禁用Release时的符号剥离
    content = re.sub(
        r'STRIP_INSTALLED_PRODUCT = YES;',
        'STRIP_INSTALLED_PRODUCT = NO;',
        content
    )
    
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ 已修复dSYM设置")

if __name__ == "__main__":
    fix_dsym_settings("CiteTrack_macOS.xcodeproj/project.pbxproj")
EOF

chmod +x fix_dsym_settings.py

echo "🐍 运行Python脚本修复dSYM设置..."
python3 fix_dsym_settings.py

echo ""
echo "✅ dSYM设置修复完成！"
echo ""
echo "📝 接下来的步骤："
echo "1. 在Xcode中Clean Build Folder (Cmd+Shift+K)"
echo "2. 重新Archive项目"
echo "3. 上传到App Store Connect"
echo ""
echo "如果仍有问题，请检查："
echo "- 确保所有第三方框架都有对应的dSYM文件"
echo "- 检查Sparkle框架的dSYM文件是否存在"
