#!/bin/bash

set -e

echo "📚 开始构建 Google Scholar Citations 应用..."

# 清理之前的构建
echo "🧹 清理之前的构建..."
rm -rf build/
rm -rf GoogleScholarCitations.dmg

# 使用 xcodebuild 构建应用
echo "🔨 构建应用..."
xcodebuild -project GoogleScholarCitations.xcodeproj \
           -scheme GoogleScholarCitations \
           -configuration Release \
           -derivedDataPath build/ \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO

# 找到构建的应用
APP_PATH="build/Build/Products/Release/GoogleScholarCitations.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ 构建失败：找不到应用文件"
    exit 1
fi

echo "✅ 应用构建成功: $APP_PATH"

# 创建 DMG
echo "📦 创建 DMG 文件..."
mkdir -p dmg_temp
cp -r "$APP_PATH" dmg_temp/
hdiutil create -volname "Google Scholar Citations" \
               -srcfolder dmg_temp \
               -ov -format UDZO \
               GoogleScholarCitations.dmg

# 清理临时文件
rm -rf dmg_temp

echo "🎉 构建完成！"
echo "📍 DMG 文件位置: $(pwd)/GoogleScholarCitations.dmg"
echo ""
echo "📖 使用说明："
echo "1. 双击 GoogleScholarCitations.dmg 安装应用"
echo "2. 将应用拖拽到应用程序文件夹"
echo "3. 运行应用后，在菜单栏点击📚图标"
echo "4. 选择'设置学者ID'，输入您的Google Scholar用户ID"
echo "5. 应用会自动每小时更新引用量" 