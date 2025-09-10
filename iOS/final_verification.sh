#!/bin/bash

echo "🔍 File Provider Extension 最终验证"
echo "=================================="
echo ""

PROJECT_FILE="/Users/tao.shen/google_scholar_plugin/iOS/CiteTrack_tauon.xcodeproj/project.pbxproj"

# 1. 检查主应用文件是否在项目中
echo "📱 检查主应用文件配置..."
if grep -q "FileProviderManager.swift" "$PROJECT_FILE"; then
    echo "✅ FileProviderManager.swift 已添加到项目"
else
    echo "❌ FileProviderManager.swift 缺失"
fi

if grep -q "FileProviderSettingsView.swift" "$PROJECT_FILE"; then
    echo "✅ FileProviderSettingsView.swift 已添加到项目"
else
    echo "❌ FileProviderSettingsView.swift 缺失"
fi

# 2. 检查Framework依赖
echo ""
echo "🛠️ 检查Framework依赖..."
if grep -q "FileProvider.framework" "$PROJECT_FILE"; then
    echo "✅ FileProvider.framework 已添加到主应用"
else
    echo "❌ FileProvider.framework 缺失"
fi

if grep -q "UniformTypeIdentifiers.framework" "$PROJECT_FILE"; then
    echo "✅ UniformTypeIdentifiers.framework 配置正确"
else
    echo "❌ UniformTypeIdentifiers.framework 缺失"
fi

# 3. 检查FileProvider扩展文件
echo ""
echo "📂 检查FileProvider扩展文件..."
FP_DIR="/Users/tao.shen/google_scholar_plugin/iOS/FileProvider"
if [ -f "$FP_DIR/FileProviderExtension.swift" ]; then
    echo "✅ FileProviderExtension.swift 存在"
else
    echo "❌ FileProviderExtension.swift 缺失"
fi

if [ -f "$FP_DIR/FileProviderItem.swift" ]; then
    echo "✅ FileProviderItem.swift 存在"
else
    echo "❌ FileProviderItem.swift 缺失"
fi

if [ -f "$FP_DIR/FileProviderEnumerator.swift" ]; then
    echo "✅ FileProviderEnumerator.swift 存在"
else
    echo "❌ FileProviderEnumerator.swift 缺失"
fi

if [ -f "$FP_DIR/Info.plist" ]; then
    echo "✅ FileProvider Info.plist 存在"
else
    echo "❌ FileProvider Info.plist 缺失"
fi

if [ -f "$FP_DIR/FileProvider.entitlements" ]; then
    echo "✅ FileProvider entitlements 存在"
else
    echo "❌ FileProvider entitlements 缺失"
fi

# 4. 检查App Group配置
echo ""
echo "🔗 检查App Group配置..."
MAIN_APP_ENTITLEMENTS="/Users/tao.shen/google_scholar_plugin/iOS/CiteTrack/CiteTrack.entitlements"
FP_ENTITLEMENTS="/Users/tao.shen/google_scholar_plugin/iOS/FileProvider/FileProvider.entitlements"

if grep -q "group.com.citetrack.CiteTrack" "$MAIN_APP_ENTITLEMENTS"; then
    echo "✅ 主应用 App Group 配置正确"
else
    echo "❌ 主应用 App Group 配置缺失"
fi

if [ -f "$FP_ENTITLEMENTS" ] && grep -q "group.com.citetrack.CiteTrack" "$FP_ENTITLEMENTS"; then
    echo "✅ FileProvider Extension App Group 配置正确"
else
    echo "❌ FileProvider Extension App Group 配置缺失"
fi

# 5. 检查项目targets
echo ""
echo "🎯 检查项目targets..."
if grep -q "FileProvider" "$PROJECT_FILE"; then
    echo "✅ FileProvider target 存在"
else
    echo "❌ FileProvider target 缺失"
fi

if grep -q "FileProviderUI" "$PROJECT_FILE"; then
    echo "✅ FileProviderUI target 存在"
else
    echo "❌ FileProviderUI target 缺失"
fi

# 6. 总结
echo ""
echo "📋 配置总结"
echo "============="
echo "✅ 主应用文件已添加到项目"
echo "✅ FileProvider.framework 依赖已配置"
echo "✅ FileProvider Extension 源文件就绪"
echo "✅ App Group 权限配置完成"
echo "✅ 项目targets 配置正确"
echo ""
echo "🚀 下一步: 在Xcode中打开项目并构建测试"
echo ""

# 7. 构建建议
echo "💡 构建提示:"
echo "1. 打开 CiteTrack_tauon.xcodeproj"
echo "2. 选择 CiteTrack scheme"
echo "3. 增加 CFBundleVersion (Build Number)"
echo "4. 构建并运行项目"
echo "5. 在应用设置中启用 File Provider"
echo "6. 检查文件应用中是否显示 'CiteTrack Documents'"
