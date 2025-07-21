#!/bin/bash

# CiteTrack 图表功能版本 DMG 创建脚本
# 创建包含完整图表功能的专业安装包

# 切换到项目根目录
cd "$(dirname "$0")/.."

APP_NAME="CiteTrack"
VERSION="2.0.0"
DMG_NAME="CiteTrack-Charts-v${VERSION}"
TEMP_DIR="dmg_temp"

echo "📊 创建 CiteTrack 图表功能版本 DMG 安装包..."

# 检查应用是否存在
if [ ! -d "${APP_NAME}.app" ]; then
    echo "❌ 错误: 找不到 ${APP_NAME}.app"
    echo "请先运行 ./scripts/build_charts.sh 构建应用"
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

echo "🎨 设置 DMG 外观..."

# 创建 DMG
hdiutil create -volname "CiteTrack Charts v${VERSION}" \
    -srcfolder "${TEMP_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}.dmg"

if [ $? -eq 0 ]; then
    # 清理临时文件
    rm -rf "${TEMP_DIR}"
    
    # 获取 DMG 大小
    DMG_SIZE=$(du -sh "${DMG_NAME}.dmg" | cut -f1)
    
    echo ""
    echo "🎉 CiteTrack 图表功能版本 DMG 创建完成！"
    echo "📁 文件名: ${DMG_NAME}.dmg"
    echo "📏 文件大小: ${DMG_SIZE}"
    echo ""
    echo "📦 DMG 内容:"
    echo "  • CiteTrack.app (图表功能版本)"
    echo "  • Applications 文件夹快捷方式"
    echo ""
    echo "📊 主要功能:"
    echo "  • 📈 专业图表系统"
    echo "  • 📊 历史数据分析"
    echo "  • 🔔 智能通知"
    echo "  • 📤 数据导出"
    echo "  • 🌍 多语言支持"
    echo "  • 💾 数据持久化"
    echo ""
    echo "🚀 可以分发 DMG 文件："
    echo "   open ${DMG_NAME}.dmg"
else
    echo "❌ DMG 创建失败"
    rm -rf "${TEMP_DIR}"
    exit 1
fi