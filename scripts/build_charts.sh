#!/bin/bash

# CiteTrack 图表功能版本构建脚本
# 构建包含完整图表功能的 CiteTrack 应用

# 切换到项目根目录
cd "$(dirname "$0")/.."

APP_NAME="CiteTrack"
VERSION="2.0.1"
BUILD_DIR="build"
SOURCES_DIR="Sources"

echo "📊 构建 CiteTrack 图表功能版本 v${VERSION}..."

# 清理旧的构建文件
echo "🧹 清理旧文件..."
rm -rf "${APP_NAME}.app"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 确保build目录存在并有正确权限
if [ ! -d "${BUILD_DIR}" ]; then
    mkdir -p "${BUILD_DIR}"
fi

# 检查所有必需的源文件
REQUIRED_FILES=(
    "${SOURCES_DIR}/main.swift"
    "${SOURCES_DIR}/Localization.swift"
    "${SOURCES_DIR}/SettingsWindow.swift"
    "${SOURCES_DIR}/CoreDataManager.swift"
    "${SOURCES_DIR}/CitationHistoryEntity.swift"
    "${SOURCES_DIR}/CitationHistory.swift"
    "${SOURCES_DIR}/CitationHistoryManager.swift"
    "${SOURCES_DIR}/GoogleScholarService+History.swift"
    "${SOURCES_DIR}/ChartDataService.swift"
    "${SOURCES_DIR}/ChartView.swift"
    "${SOURCES_DIR}/ChartsViewController.swift"
    "${SOURCES_DIR}/ChartsWindowController.swift"
    "${SOURCES_DIR}/DataRepairViewController.swift"
    "${SOURCES_DIR}/iCloudSyncManager.swift"
    "${SOURCES_DIR}/NotificationManager.swift"
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

# 编译应用 - 包含所有新的源文件
swiftc -O \
    -target arm64-apple-macos10.15 \
    -F Frameworks \
    -framework Sparkle \
    -framework CoreData \
    -framework UserNotifications \
    -Xlinker -rpath \
    -Xlinker @executable_path/../Frameworks \
    "${SOURCES_DIR}/Localization.swift" \
    "${SOURCES_DIR}/CoreDataManager.swift" \
    "${SOURCES_DIR}/CitationHistoryEntity.swift" \
    "${SOURCES_DIR}/CitationHistory.swift" \
    "${SOURCES_DIR}/CitationHistoryManager.swift" \
    "${SOURCES_DIR}/GoogleScholarService+History.swift" \
    "${SOURCES_DIR}/ChartDataService.swift" \
    "${SOURCES_DIR}/ChartView.swift" \
    "${SOURCES_DIR}/ChartsViewController.swift" \
    "${SOURCES_DIR}/ChartsWindowController.swift" \
    "${SOURCES_DIR}/DataRepairViewController.swift" \
    "${SOURCES_DIR}/iCloudSyncManager.swift" \
    "${SOURCES_DIR}/NotificationManager.swift" \
    "${SOURCES_DIR}/SettingsWindow.swift" \
    "${SOURCES_DIR}/main.swift" \
    -o "${BUILD_DIR}/${APP_NAME}"

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    echo "🔍 检查build目录权限..."
    ls -la "${BUILD_DIR}"
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

# 编译并复制 Core Data 模型文件
echo "📊 编译 Core Data 模型..."
if [ -d "${SOURCES_DIR}/CitationTrackingModel.xcdatamodeld" ]; then
    # 使用momc编译Core Data模型
    if command -v momc >/dev/null 2>&1; then
        echo "🔨 使用 momc 编译模型..."
        momc "${SOURCES_DIR}/CitationTrackingModel.xcdatamodeld" "${APP_BUNDLE}/Contents/Resources/CitationTrackingModel.momd"
        if [ $? -eq 0 ]; then
            echo "✅ Core Data 模型编译成功"
        else
            echo "❌ Core Data 模型编译失败，回退到直接复制"
            cp -R "${SOURCES_DIR}/CitationTrackingModel.xcdatamodeld" "${APP_BUNDLE}/Contents/Resources/"
        fi
    else
        echo "ℹ️  开发工具不可用，使用源模型文件（这是正常的）"
        cp -R "${SOURCES_DIR}/CitationTrackingModel.xcdatamodeld" "${APP_BUNDLE}/Contents/Resources/"
    fi
    echo "✅ Core Data 模型处理完成"
else
    echo "❌ 找不到 Core Data 模型文件"
    exit 1
fi

# 验证Core Data模型文件是否正确复制
echo "🔍 验证Core Data模型文件..."
if [ -d "${APP_BUNDLE}/Contents/Resources/CitationTrackingModel.momd" ]; then
    echo "✅ 编译后的模型文件存在"
    echo "📁 模型文件内容:"
    ls -la "${APP_BUNDLE}/Contents/Resources/CitationTrackingModel.momd/"
elif [ -d "${APP_BUNDLE}/Contents/Resources/CitationTrackingModel.xcdatamodeld" ]; then
    echo "✅ 源模型文件存在"
    echo "📁 模型文件内容:"
    ls -la "${APP_BUNDLE}/Contents/Resources/CitationTrackingModel.xcdatamodeld/"
else
    echo "❌ Core Data模型文件复制失败"
    echo "📁 当前Resources目录内容:"
    ls -la "${APP_BUNDLE}/Contents/Resources/"
    exit 1
fi

# 复制图标文件
if [ -f "assets/app_icon.icns" ]; then
    echo "📋 使用assets目录中的专业图标文件..."
    cp "assets/app_icon.icns" "${APP_BUNDLE}/Contents/Resources/"
    echo "✅ 专业图标复制成功"
elif [ -f "app_icon.icns" ]; then
    echo "📋 使用根目录中的图标文件..."
    cp "app_icon.icns" "${APP_BUNDLE}/Contents/Resources/"
    echo "✅ 图标复制成功"
elif [ -f "assets/logo.png" ]; then
    echo "🎨 处理应用图标..."
    
    # 创建临时 iconset
    ICONSET_DIR="${BUILD_DIR}/app_icon.iconset"
    mkdir -p "${ICONSET_DIR}"
    
    # 生成不同尺寸的图标
    sips -z 16 16 assets/logo.png --out "${ICONSET_DIR}/icon_16x16.png" 2>/dev/null
    sips -z 32 32 assets/logo.png --out "${ICONSET_DIR}/icon_16x16@2x.png" 2>/dev/null
    sips -z 32 32 assets/logo.png --out "${ICONSET_DIR}/icon_32x32.png" 2>/dev/null
    sips -z 64 64 assets/logo.png --out "${ICONSET_DIR}/icon_32x32@2x.png" 2>/dev/null
    sips -z 128 128 assets/logo.png --out "${ICONSET_DIR}/icon_128x128.png" 2>/dev/null
    sips -z 256 256 assets/logo.png --out "${ICONSET_DIR}/icon_128x128@2x.png" 2>/dev/null
    sips -z 256 256 assets/logo.png --out "${ICONSET_DIR}/icon_256x256.png" 2>/dev/null
    sips -z 512 512 assets/logo.png --out "${ICONSET_DIR}/icon_256x256@2x.png" 2>/dev/null
    sips -z 512 512 assets/logo.png --out "${ICONSET_DIR}/icon_512x512.png" 2>/dev/null
    sips -z 1024 1024 assets/logo.png --out "${ICONSET_DIR}/icon_512x512@2x.png" 2>/dev/null
    
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

# 代码签名应用包，包含 iCloud 权限
ENTITLEMENTS_FILE="CiteTrack.entitlements"
if [ -f "${ENTITLEMENTS_FILE}" ]; then
    echo "📋 使用 iCloud 权限文件进行签名..."
    codesign --force --deep --sign - --entitlements "${ENTITLEMENTS_FILE}" "${APP_BUNDLE}" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ 代码签名成功（包含 iCloud 权限）"
    else
        echo "⚠️  iCloud 权限签名失败，尝试标准签名..."
        codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "✅ 代码签名成功（标准权限）"
        else
            echo "❌ 代码签名失败"
            exit 1
        fi
    fi
else
    echo "⚠️  未找到权限文件，使用标准签名..."
    codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✅ 代码签名成功（标准权限）"
    else
        echo "❌ 代码签名失败"
        exit 1
    fi
fi

# 清理可能的 quarantine 属性（用户可能遇到的问题）
echo "🧹 清理 quarantine 属性..."
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true

# 清理构建目录
rm -rf "${BUILD_DIR}"

# 获取应用大小
APP_SIZE=$(du -sh "${APP_BUNDLE}" | cut -f1)
EXECUTABLE_SIZE=$(du -sh "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" | cut -f1)

echo ""
echo "🎉 CiteTrack 图表功能版本构建完成！"
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
echo "📊 新功能特性:"
echo "  • 📈 专业图表系统 (线图、柱状图、面积图)"
echo "  • 📊 历史数据追踪和分析"
echo "  • 🔔 智能通知系统"
echo "  • 📤 数据导出 (CSV/JSON)"
echo "  • 📈 趋势分析和统计"
echo "  • 🎯 时间范围过滤"
echo "  • 🎨 多种图表样式和配色"
echo "  • 💾 Core Data 数据持久化"
echo "  • 🔄 自动数据收集"
echo "  • 📱 交互式图表界面"
echo ""
echo "🚀 可以运行应用进行测试："
echo "   open ${APP_BUNDLE}"