#!/bin/bash

echo "🔨 最终编译 CiteTrack macOS..."

SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)
TARGET="arm64-apple-macos10.15"
OUTPUT="CiteTrack_Final"

# 包含所有修复后的源文件
SOURCES=(
    "Sources/main.swift"
    "Sources/Localization.swift"
    "Sources/SettingsWindow.swift"
    "Sources/ChartsWindowController.swift"
    "Sources/ChartsViewController.swift"
    "Sources/ChartView.swift"
    "Sources/ChartTheme.swift"
    "Sources/ChartDataService.swift"
    "Sources/EnhancedChartTypes.swift"
    "Sources/ModernCardView.swift"
    "Sources/DashboardComponents.swift"
    "Sources/ModernToolbar.swift"
    "Sources/iCloudSyncManager.swift"
    "Sources/CitationHistoryManager.swift"
    "Sources/CitationHistoryEntity.swift"
    "Sources/CitationHistory.swift"
    "Sources/CoreDataManager.swift"
    "Sources/GoogleScholarService+History.swift"
    "Sources/NotificationManager.swift"
    "Sources/DataRepairViewController.swift"
    "Sources/ModernChartsWindowController.swift"
)

echo "📝 编译 ${#SOURCES[@]} 个源文件..."

swiftc \
    -sdk "$SDK_PATH" \
    -target "$TARGET" \
    -F Frameworks \
    -framework Sparkle \
    -framework CoreData \
    -Xlinker -rpath \
    -Xlinker @executable_path/../Frameworks \
    "${SOURCES[@]}" \
    -o "$OUTPUT" \
    2>&1

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 ============================================"
    echo "   编译成功！所有问题已修复！"
    echo "============================================"
    echo ""
    echo "📦 二进制文件: $OUTPUT"
    ls -lh "$OUTPUT"
    echo ""
    echo "✅ 修复的所有问题:"
    echo "  1. Localization.swift 重复键"
    echo "  2. EnhancedChartTypes.swift API 兼容性"
    echo "  3. EnhancedChartTypes.swift TooltipWindow contentView 冲突"
    echo "  4. EnhancedChartTypes.swift formattedWithCommas() 不存在"
    echo "  5. DashboardComponents.swift API 兼容性"
    echo "  6. ModernCardView.swift 闭包中的私有属性访问"
    echo ""
else
    echo ""
    echo "❌ 编译失败，查看上面的错误"
fi
