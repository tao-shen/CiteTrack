#!/bin/bash

# CiteTrack 多语言版本构建脚本
# 构建支持多语言的 CiteTrack 应用

APP_NAME="CiteTrack"
VERSION="1.1.2"
BUILD_DIR="build"
SOURCES_DIR="Sources"

echo "🌍 构建 CiteTrack 多语言版本 v${VERSION}..."

# 清理旧的构建文件
echo "🧹 清理旧文件..."
rm -rf "${APP_NAME}.app"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 检查源文件
if [ ! -f "${SOURCES_DIR}/Localization.swift" ]; then
    echo "❌ 错误: 找不到 Localization.swift"
    exit 1
fi

if [ ! -f "${SOURCES_DIR}/main_localized.swift" ]; then
    echo "❌ 错误: 找不到 main_localized.swift"
    exit 1
fi

echo "📝 编译多语言应用..."

# 编译应用
swiftc -O \
    -target arm64-apple-macos10.15 \
    "${SOURCES_DIR}/Localization.swift" \
    "${SOURCES_DIR}/SettingsWindow.swift" \
    "${SOURCES_DIR}/main_localized.swift" \
    -o "${BUILD_DIR}/${APP_NAME}"

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi

echo "📦 创建应用包结构..."

# 创建应用包结构
APP_BUNDLE="${APP_NAME}.app"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 复制可执行文件
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# 创建 Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.citetrack.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>CiteTrack</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>app_icon</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2024 CiteTrack. All rights reserved.</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
        <string>ja</string>
        <string>ko</string>
        <string>es</string>
        <string>fr</string>
        <string>de</string>
    </array>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
</dict>
</plist>
EOF

# 复制图标文件（如果存在）
if [ -f "app_icon.icns" ]; then
    echo "📋 使用专业图标文件..."
    cp "app_icon.icns" "${APP_BUNDLE}/Contents/Resources/"
    echo "✅ 专业图标复制成功"
elif [ -f "bak_files/app_icon.icns" ]; then
    echo "📋 使用备份图标文件..."
    cp "bak_files/app_icon.icns" "${APP_BUNDLE}/Contents/Resources/"
    echo "✅ 备份图标复制成功"
elif [ -f "logo.png" ]; then
    echo "🎨 处理应用图标..."
    
    # 创建临时 iconset
    ICONSET_DIR="${BUILD_DIR}/app_icon.iconset"
    mkdir -p "${ICONSET_DIR}"
    
    # 生成不同尺寸的图标
    sips -z 16 16 logo.png --out "${ICONSET_DIR}/icon_16x16.png" 2>/dev/null
    sips -z 32 32 logo.png --out "${ICONSET_DIR}/icon_16x16@2x.png" 2>/dev/null
    sips -z 32 32 logo.png --out "${ICONSET_DIR}/icon_32x32.png" 2>/dev/null
    sips -z 64 64 logo.png --out "${ICONSET_DIR}/icon_32x32@2x.png" 2>/dev/null
    sips -z 128 128 logo.png --out "${ICONSET_DIR}/icon_128x128.png" 2>/dev/null
    sips -z 256 256 logo.png --out "${ICONSET_DIR}/icon_128x128@2x.png" 2>/dev/null
    sips -z 256 256 logo.png --out "${ICONSET_DIR}/icon_256x256.png" 2>/dev/null
    sips -z 512 512 logo.png --out "${ICONSET_DIR}/icon_256x256@2x.png" 2>/dev/null
    sips -z 512 512 logo.png --out "${ICONSET_DIR}/icon_512x512.png" 2>/dev/null
    sips -z 1024 1024 logo.png --out "${ICONSET_DIR}/icon_512x512@2x.png" 2>/dev/null
    
    # 创建 .icns 文件
    iconutil -c icns "${ICONSET_DIR}" -o "${APP_BUNDLE}/Contents/Resources/app_icon.icns"
    
    if [ $? -eq 0 ]; then
        echo "✅ 应用图标创建成功"
    else
        echo "⚠️  图标创建失败，使用默认图标"
    fi
    
    # 清理临时文件
    rm -rf "${ICONSET_DIR}"
fi

echo "🔐 代码签名..."

# 代码签名
codesign --force --deep --sign - "${APP_BUNDLE}"

if [ $? -eq 0 ]; then
    echo "✅ 代码签名成功"
else
    echo "❌ 代码签名失败"
    exit 1
fi

# 清理构建目录
rm -rf "${BUILD_DIR}"

# 获取应用大小
APP_SIZE=$(du -sh "${APP_BUNDLE}" | cut -f1)
EXECUTABLE_SIZE=$(du -sh "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" | cut -f1)

echo ""
echo "🎉 多语言版本构建完成！"
echo "📁 应用包: ${APP_BUNDLE}"
echo "📏 应用大小: ${APP_SIZE}"
echo "⚙️  可执行文件: ${EXECUTABLE_SIZE}"
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
echo "✨ 新功能:"
echo "  • 多语言界面支持"
echo "  • 自动检测系统语言"
echo "  • 实时语言切换"
echo "  • 本地化错误消息"
echo ""
echo "🚀 可以运行应用进行测试："
echo "   open ${APP_BUNDLE}" 