#!/bin/bash

# CiteTrack 多语言版本 DMG 创建脚本
# 创建包含多语言支持的专业安装包

APP_NAME="CiteTrack"
VERSION="1.1.2"
DMG_NAME="CiteTrack-Multilingual-v${VERSION}"
TEMP_DIR="dmg_temp"

echo "🌍 创建 CiteTrack 多语言版本 DMG 安装包..."

# 检查应用是否存在
if [ ! -d "${APP_NAME}.app" ]; then
    echo "❌ 错误: 找不到 ${APP_NAME}.app"
    echo "请先运行 ./build_multilingual.sh 构建应用"
    exit 1
fi

# 清理旧文件
echo "🧹 清理旧文件..."
rm -rf "${TEMP_DIR}"
rm -f "${DMG_NAME}.dmg"
mkdir -p "${TEMP_DIR}"

echo "📦 准备 DMG 内容..."

# 复制应用到临时目录
cp -R "${APP_NAME}.app" "${TEMP_DIR}/"

# 创建 Applications 文件夹的符号链接
ln -s /Applications "${TEMP_DIR}/Applications"

# 不再添加安装指南、脚本或其他文件 - 保持DMG简洁
# 只包含APP和Applications快捷方式

echo "🎨 设置 DMG 外观..."

# 创建 DMG
hdiutil create -volname "CiteTrack Multilingual v${VERSION}" \
    -srcfolder "${TEMP_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}.dmg"

if [ $? -eq 0 ]; then
    # 清理临时文件
    rm -rf "${TEMP_DIR}"
    
    # 获取 DMG 大小
    DMG_SIZE=$(du -sh "${DMG_NAME}.dmg" | cut -f1)
    
    echo ""
    echo "🎉 简洁版 DMG 创建完成！"
    echo "📁 文件名: ${DMG_NAME}.dmg"
    echo "📏 文件大小: ${DMG_SIZE}"
    echo ""
    echo "📦 DMG 内容:"
    echo "  • CiteTrack.app (多语言版本)"
    echo "  • Applications 文件夹快捷方式"
    echo ""
    echo "🌍 支持的语言:"
    echo "  • English (英语)"
    echo "  • 简体中文 (Simplified Chinese)"
    echo "  • 日本語 (Japanese)"
    echo "  • 한국어 (Korean)"
    echo "  • Español (Spanish)"
    echo "  • Français (French)"
    echo "  • Deutsch (German)"
    echo ""
    echo "🚀 可以分发 DMG 文件："
    echo "   open ${DMG_NAME}.dmg"
else
    echo "❌ DMG 创建失败"
    rm -rf "${TEMP_DIR}"
    exit 1
fi 