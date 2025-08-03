#!/bin/bash

# CiteTrack Core Data 快速修复脚本
# 解决Core Data模型缺失导致的闪退问题

# 切换到项目根目录
cd "$(dirname "$0")/.."

echo "🔧 开始修复 Core Data 问题..."

# 检查现有的应用
if [ -d "CiteTrack.app" ]; then
    echo "📱 找到现有应用，检查Core Data模型..."
    
    # 检查Core Data模型文件
    if [ ! -d "CiteTrack.app/Contents/Resources/CitationTrackingModel.momd" ] && \
       [ ! -d "CiteTrack.app/Contents/Resources/CitationTrackingModel.xcdatamodeld" ]; then
        echo "❌ 发现Core Data模型缺失，这是导致闪退的原因"
        echo "🔧 正在修复..."
        
        # 复制Core Data模型文件
        if [ -d "Sources/CitationTrackingModel.xcdatamodeld" ]; then
            echo "📁 复制Core Data模型文件..."
            cp -R "Sources/CitationTrackingModel.xcdatamodeld" "CiteTrack.app/Contents/Resources/"
            echo "✅ Core Data模型文件已复制"
        else
            echo "❌ 找不到源Core Data模型文件"
            exit 1
        fi
    else
        echo "✅ Core Data模型文件已存在"
    fi
else
    echo "📱 找不到现有应用，需要重新构建"
    echo "请运行: ./scripts/build_charts.sh"
    exit 1
fi

# 验证修复结果
echo "🔍 验证修复结果..."
if [ -d "CiteTrack.app/Contents/Resources/CitationTrackingModel.xcdatamodeld" ]; then
    echo "✅ Core Data模型文件已正确复制"
    echo "📁 模型文件内容:"
    ls -la "CiteTrack.app/Contents/Resources/CitationTrackingModel.xcdatamodeld/"
else
    echo "❌ Core Data模型文件复制失败"
    exit 1
fi

echo "✅ 修复完成！现在应用应该可以正常启动而不会闪退。"
echo "💡 建议运行测试脚本验证修复效果: ./scripts/test_app.sh" 