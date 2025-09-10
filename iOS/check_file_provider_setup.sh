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
