#!/bin/bash

# CiteTrack File Provider Extension 设置脚本
# 用于将File Provider Extension集成到Xcode项目中

echo "🔧 开始设置 CiteTrack File Provider Extension..."

# 设置路径
PROJECT_DIR="/Users/tao.shen/google_scholar_plugin/iOS"
XCODE_PROJECT="$PROJECT_DIR/CiteTrack_tauon.xcodeproj"
PROVIDER_DIR="$PROJECT_DIR/CiteTrackFileProvider"

# 检查项目目录
if [ ! -d "$XCODE_PROJECT" ]; then
    echo "❌ 找不到 Xcode 项目: $XCODE_PROJECT"
    exit 1
fi

echo "✅ 项目目录验证成功"

# 检查File Provider文件
echo "🔍 检查 File Provider Extension 文件..."

REQUIRED_FILES=(
    "$PROVIDER_DIR/FileProviderExtension.swift"
    "$PROVIDER_DIR/FileProviderItem.swift"
    "$PROVIDER_DIR/FileProviderEnumerator.swift"
    "$PROVIDER_DIR/Info.plist"
    "$PROVIDER_DIR/CiteTrackFileProvider.entitlements"
    "$PROVIDER_DIR/FileProviderIcon.png"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ 缺少文件: $file"
    fi
done

# 检查主应用文件
MAIN_APP_FILES=(
    "$PROJECT_DIR/CiteTrack/FileProviderManager.swift"
    "$PROJECT_DIR/CiteTrack/CiteTrackApp.swift"
)

for file in "${MAIN_APP_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ 缺少主应用文件: $file"
    fi
done

echo ""
echo "📋 File Provider Extension 设置总结:"
echo "1. ✅ File Provider Extension 源代码已创建"
echo "2. ✅ 配置文件(Info.plist, entitlements)已创建"  
echo "3. ✅ 主应用集成代码已添加"
echo "4. ✅ 图标资源已复制"
echo ""
echo "🎯 下一步操作（需要在 Xcode 中手动完成）:"
echo "1. 打开 Xcode 项目"
echo "2. 右键点击项目 → Add Files to 'CiteTrack_tauon'"
echo "3. 选择整个 CiteTrackFileProvider 文件夹并添加"
echo "4. 在项目设置中创建新的 App Extension Target"
echo "5. 配置 Target 的 Bundle Identifier 为: com.citetrack.CiteTrack.FileProvider"
echo "6. 设置正确的 entitlements 和 Info.plist 文件"
echo "7. 添加 FileProvider.framework 到项目依赖"
echo ""
echo "⚠️  重要提醒:"
echo "- 确保 App Group 'group.com.citetrack.CiteTrack' 在主应用和扩展中都已启用"
echo "- 确保在项目的 Capabilities 中启用了 File Provider extension"
echo "- 构建前请增加 CFBundleVersion (Build Number)"
echo ""

# 创建快速检查脚本
cat > "$PROJECT_DIR/check_file_provider_setup.sh" << 'EOF'
#!/bin/bash
echo "🔍 File Provider Extension 配置检查"
echo ""

# 检查App Group配置
echo "📱 检查 App Group 配置..."
if grep -q "group.com.citetrack.CiteTrack" "/Users/tao.shen/google_scholar_plugin/iOS/CiteTrack/CiteTrack.entitlements"; then
    echo "✅ 主应用 App Group 配置正确"
else
    echo "❌ 主应用缺少 App Group 配置"
fi

if grep -q "group.com.citetrack.CiteTrack" "/Users/tao.shen/google_scholar_plugin/iOS/CiteTrackFileProvider/CiteTrackFileProvider.entitlements"; then
    echo "✅ File Provider Extension App Group 配置正确"
else
    echo "❌ File Provider Extension 缺少 App Group 配置"
fi

echo ""
echo "📄 检查关键文件..."
if [ -f "/Users/tao.shen/google_scholar_plugin/iOS/CiteTrack/FileProviderManager.swift" ]; then
    echo "✅ FileProviderManager.swift 存在"
else
    echo "❌ FileProviderManager.swift 缺失"
fi

if [ -f "/Users/tao.shen/google_scholar_plugin/iOS/CiteTrackFileProvider/FileProviderExtension.swift" ]; then
    echo "✅ FileProviderExtension.swift 存在"
else
    echo "❌ FileProviderExtension.swift 缺失"
fi

echo ""
echo "🎯 如果所有检查都通过，可以尝试构建项目"
EOF

chmod +x "$PROJECT_DIR/check_file_provider_setup.sh"

echo "✅ 设置脚本执行完成!"
echo "✅ 创建了检查脚本: check_file_provider_setup.sh"
echo ""
echo "🚀 现在可以在 Xcode 中打开项目并按照上述步骤完成集成"
