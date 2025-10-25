#!/bin/bash

# 修复应用图标的脚本
# 在编译后自动添加 CFBundleIconFile 配置

APP_BUNDLE=$(find /Users/tao.shen/Library/Developer/Xcode/DerivedData/ -name "CiteTrack.app" -type d 2>/dev/null | head -1)
INFO_PLIST="${APP_BUNDLE}/Contents/Info.plist"

echo "🔧 修复应用图标配置..."

# 检查 Info.plist 是否存在
if [ ! -f "$INFO_PLIST" ]; then
    echo "❌ 找不到 Info.plist: $INFO_PLIST"
    exit 1
fi

# 检查是否已经有 CFBundleIconFile
if grep -q "CFBundleIconFile" "$INFO_PLIST"; then
    echo "✅ CFBundleIconFile 已存在"
else
    echo "🔧 添加 CFBundleIconFile 配置..."
    
    # 在 LSUIElement 后面添加 CFBundleIconFile
    sed -i '' '/<key>LSUIElement<\/key>/a\
	<key>CFBundleIconFile</key>\
	<string>app_icon</string>' "$INFO_PLIST"
    
    echo "✅ 已添加 CFBundleIconFile 配置"
fi

# 验证配置
echo "📋 验证配置:"
grep -A 3 -B 1 "LSUIElement\|CFBundleIconFile" "$INFO_PLIST"

echo "🎉 图标配置修复完成！"
