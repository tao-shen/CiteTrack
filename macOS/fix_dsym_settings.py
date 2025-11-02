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
