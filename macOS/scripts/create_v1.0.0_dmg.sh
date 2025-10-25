#!/bin/bash

# CiteTrack v1.0.0 DMG 创建脚本
# 为专业图表版本创建DMG

cd "$(dirname "$0")/.."

APP_NAME="CiteTrack"
VERSION="1.0.0"
DMG_NAME="CiteTrack-Charts-Professional-v${VERSION}"
APP_BUNDLE="${APP_NAME}.app"

echo "📦 创建 CiteTrack v${VERSION} 专业图表版DMG..."

# 检查应用包是否存在
if [ ! -d "${APP_BUNDLE}" ]; then
    echo "❌ 应用包不存在: ${APP_BUNDLE}"
    echo "请先运行 build_charts.sh"
    exit 1
fi

# 创建临时目录
TEMP_DIR="dmg_temp_v2"
rm -rf "${TEMP_DIR}"
mkdir -p "${TEMP_DIR}"

# 复制应用到临时目录
echo "📋 复制应用到临时目录..."
cp -R "${APP_BUNDLE}" "${TEMP_DIR}/"

# 创建Applications快捷方式
echo "🔗 创建Applications快捷方式..."
ln -s /Applications "${TEMP_DIR}/Applications"

# 删除旧DMG
rm -f "${DMG_NAME}.dmg"

# 创建DMG
echo "💿 创建DMG文件..."
hdiutil create -volname "${DMG_NAME}" \
    -srcfolder "${TEMP_DIR}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_NAME}.dmg"

if [ $? -eq 0 ]; then
    echo "✅ DMG创建成功: ${DMG_NAME}.dmg"
    
    # 获取DMG大小
    DMG_SIZE=$(du -sh "${DMG_NAME}.dmg" | cut -f1)
    DMG_BYTES=$(wc -c < "${DMG_NAME}.dmg" | tr -d ' ')
    
    echo "📏 DMG大小: ${DMG_SIZE} (${DMG_BYTES} bytes)"
    
    # 验证DMG内容
    echo "🔍 验证DMG内容..."
    if hdiutil verify "${DMG_NAME}.dmg" >/dev/null 2>&1; then
        echo "✅ DMG验证成功"
    else
        echo "❌ DMG验证失败"
        exit 1
    fi
else
    echo "❌ DMG创建失败"
    exit 1
fi

# 清理临时文件
rm -rf "${TEMP_DIR}"

echo ""
echo "🎉 CiteTrack v${VERSION} 专业图表版DMG构建完成！"
echo "📁 DMG文件: ${DMG_NAME}.dmg"
echo "📏 文件大小: ${DMG_SIZE} (${DMG_BYTES} bytes)"
echo ""
echo "🔒 签名配置:"
echo "  • SUPublicEDKey: BA627faCSozuFLMFaEKYeIvT50Wr8iJYKr3iyIMooKo="
echo "  • 账户: ed25519 (citetrack_official)"
echo "  • 签名验证: 启用"
echo "  • 更新链: v1.1.3 → v2.0.0"
echo ""
echo "📊 新功能亮点:"
echo "  • 📈 专业图表系统 (线图、柱状图、面积图)"
echo "  • 📊 历史数据追踪和Core Data持久化"
echo "  • 🔔 智能通知系统"
echo "  • 📤 数据导出 (CSV/JSON)"
echo "  • 💾 iCloud同步支持"
echo ""
echo "🚀 可以测试DMG安装:"
echo "   open ${DMG_NAME}.dmg"