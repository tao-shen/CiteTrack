#!/bin/bash

# CiteTrack v1.1.3 正规版本构建脚本
# 使用统一的EdDSA签名系统

# 切换到项目根目录
cd "$(dirname "$0")/.."

APP_NAME="CiteTrack"
VERSION="1.1.3"
BUILD_DIR="build"
SOURCES_DIR="Sources"

echo "📊 构建 CiteTrack v${VERSION} 正规签名版本..."

# 清理旧的构建文件
echo "🧹 清理旧文件..."
rm -rf "${APP_NAME}.app"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 检查必需的源文件
REQUIRED_FILES=(
    "${SOURCES_DIR}/main_v1.1.3.swift"
    "${SOURCES_DIR}/Localization.swift"
    "${SOURCES_DIR}/SettingsWindow_v1.1.3.swift"
)

echo "🔍 检查源文件..."
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ 错误: 找不到 $file"
        exit 1
    else
        echo "✅ $file"
    fi
done

echo "📝 编译应用..."

# 编译应用 - v1.1.3 版本
swiftc -O \
    -target arm64-apple-macos10.15 \
    -F Frameworks \
    -framework Sparkle \
    -Xlinker -rpath \
    -Xlinker @executable_path/../Frameworks \
    "${SOURCES_DIR}/Localization.swift" \
    "${SOURCES_DIR}/SettingsWindow_v1.1.3.swift" \
    "${SOURCES_DIR}/main_v1.1.3.swift" \
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

# 创建 Info.plist with 正规签名配置
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
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/tao-shen/CiteTrack/main/appcast.xml</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <string>86400</string>
    <key>SUAllowsAutomaticUpdates</key>
    <true/>
    <key>SUPublicEDKey</key>
    <string>NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=</string>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>NSUserNotificationsUsageDescription</key>
    <string>CiteTrack needs notification permission to alert you about citation changes.</string>
</dict>
</plist>
EOF

# 复制图标文件
if [ -f "assets/app_icon.icns" ]; then
    echo "📋 使用assets目录中的专业图标文件..."
    cp "assets/app_icon.icns" "${APP_BUNDLE}/Contents/Resources/"
    echo "✅ 专业图标复制成功"
elif [ -f "app_icon.icns" ]; then
    echo "📋 使用根目录中的图标文件..."
    cp "app_icon.icns" "${APP_BUNDLE}/Contents/Resources/"
    echo "✅ 图标复制成功"
fi

echo "📦 复制 Sparkle 框架..."

# 创建 Frameworks 目录
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"

# 复制 Sparkle 框架
if [ -d "Frameworks/Sparkle.framework" ]; then
    cp -R "Frameworks/Sparkle.framework" "${APP_BUNDLE}/Contents/Frameworks/"
    echo "✅ Sparkle 框架复制成功"
else
    echo "❌ 找不到 Sparkle 框架"
    exit 1
fi

echo "🔐 代码签名..."

# 先签名 Sparkle 框架
codesign --force --deep --sign - "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Sparkle 框架签名成功"
else
    echo "❌ Sparkle 框架签名失败"
    exit 1
fi

# 代码签名应用包
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ 代码签名成功"
else
    echo "❌ 代码签名失败"
    exit 1
fi

# 清理可能的 quarantine 属性
echo "🧹 清理 quarantine 属性..."
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true

# 清理构建目录
rm -rf "${BUILD_DIR}"

# 获取应用大小
APP_SIZE=$(du -sh "${APP_BUNDLE}" | cut -f1)
EXECUTABLE_SIZE=$(du -sh "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" | cut -f1)

echo ""
echo "🎉 CiteTrack v${VERSION} 正规签名版本构建完成！"
echo "📁 应用包: ${APP_BUNDLE}"
echo "📏 应用大小: ${APP_SIZE}"
echo "⚙️  可执行文件: ${EXECUTABLE_SIZE}"
echo ""
echo "🔒 签名配置:"
echo "  • SUPublicEDKey: BA627faCSozuFLMFaEKYeIvT50Wr8iJYKr3iyIMooKo="
echo "  • 账户: citetrack_official"
echo "  • 签名验证: 启用"
echo ""
echo "🚀 可以运行应用进行测试："
echo "   open ${APP_BUNDLE}"