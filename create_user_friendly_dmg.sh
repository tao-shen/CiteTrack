#!/bin/bash

# 创建包含安装工具的用户友好 DMG
# 包含: CiteTrack.app, 绕过脚本, 安装指南, Applications 快捷方式

DMG_NAME="CiteTrack_with_installer"
VOLUME_NAME="CiteTrack"
APP_NAME="CiteTrack"

echo "🚀 创建用户友好的 CiteTrack DMG..."

# 检查必要文件
if [ ! -d "$APP_NAME.app" ]; then
    echo "❌ 错误: 找不到 $APP_NAME.app"
    exit 1
fi

# 清理旧文件
echo "🧹 清理旧文件..."
rm -f "$DMG_NAME.dmg"
rm -rf dmg_temp

# 创建临时目录
echo "📁 创建临时目录..."
mkdir -p dmg_temp

# 复制应用
echo "📱 复制 CiteTrack.app..."
cp -R "$APP_NAME.app" dmg_temp/

# 创建 Applications 快捷方式
echo "🔗 创建 Applications 快捷方式..."
ln -s /Applications dmg_temp/Applications

# 不再包含其他文件 - 保持DMG简洁干净

# 获取应用大小
APP_SIZE=$(du -sm "$APP_NAME.app" | cut -f1)
TOTAL_SIZE=$((APP_SIZE + 5))  # 额外空间给其他文件

echo "📏 应用大小: ${APP_SIZE}MB, DMG 大小: ${TOTAL_SIZE}MB"

# 创建 DMG
echo "💿 创建 DMG..."
hdiutil create -size ${TOTAL_SIZE}m -fs HFS+ -volname "$VOLUME_NAME" -srcfolder dmg_temp "$DMG_NAME.dmg"

if [ $? -ne 0 ]; then
    echo "❌ DMG 创建失败"
    exit 1
fi

# 清理临时文件
echo "🧹 清理临时文件..."
rm -rf dmg_temp

# 获取最终大小
FINAL_SIZE=$(du -h "$DMG_NAME.dmg" | cut -f1)

echo ""
echo "✅ 用户友好 DMG 创建完成！"
echo "📁 文件名: $DMG_NAME.dmg"
echo "📏 大小: $FINAL_SIZE"
echo ""
echo "📦 DMG 内容:"
echo "  • CiteTrack.app - 主应用程序"
echo "  • Applications - 应用程序文件夹快捷方式"
echo ""
echo "🎯 用户只需要:"
echo "1. 打开 DMG"
echo "2. 拖拽应用到 Applications 文件夹"
echo ""
echo "💡 这个 DMG 包含了完整的安装支持！" 