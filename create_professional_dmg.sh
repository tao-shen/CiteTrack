#!/bin/bash

echo "🚀 构建专业CiteTrack DMG..."

# 清理旧文件
rm -f CiteTrack.dmg
rm -rf dmg_temp

# 检查应用是否存在
if [ ! -d "CiteTrack.app" ]; then
    echo "❌ CiteTrack.app 不存在，请先构建应用"
    exit 1
fi

# 创建临时目录
mkdir dmg_temp

# 复制应用到临时目录
cp -R CiteTrack.app dmg_temp/

# 对应用进行代码签名（使用ad-hoc签名）
echo "🔐 对应用进行代码签名..."
codesign --force --deep --sign - dmg_temp/CiteTrack.app

# 验证签名
if codesign --verify --deep --strict dmg_temp/CiteTrack.app; then
    echo "✅ 代码签名成功"
else
    echo "⚠️  代码签名验证失败，但继续构建"
fi

# 创建Applications快捷方式
ln -s /Applications dmg_temp/Applications

# 不添加任何其他文件 - 保持DMG简洁

# 创建DMG
echo "📦 创建DMG文件..."
hdiutil create -volname "CiteTrack" -srcfolder dmg_temp -ov -format UDZO CiteTrack.dmg 