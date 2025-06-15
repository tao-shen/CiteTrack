#!/bin/bash

# CiteTrack 多语言版本 DMG 创建脚本
# 创建包含多语言支持的专业安装包

APP_NAME="CiteTrack"
VERSION="1.1.1"
DMG_NAME="CiteTrack-Multilingual-v${VERSION}"
TEMP_DIR="dmg_temp"

echo "🌍 创建 CiteTrack 多语言版本 DMG 安装包..."

# 检查应用是否存在
if [ ! -d "${APP_NAME}.app" ]; then
    echo "❌ 错误: 找不到 ${APP_NAME}.app"
    echo "请先运行 ./build_multilingual.sh 构建应用"
    exit 1
fi

# 清理旧文件
echo "🧹 清理旧文件..."
rm -rf "${TEMP_DIR}"
rm -f "${DMG_NAME}.dmg"
mkdir -p "${TEMP_DIR}"

echo "📦 准备 DMG 内容..."

# 复制应用到临时目录
cp -R "${APP_NAME}.app" "${TEMP_DIR}/"

# 创建 Applications 文件夹的符号链接
ln -s /Applications "${TEMP_DIR}/Applications"

# 创建多语言安装指南
cat > "${TEMP_DIR}/Installation Guide - 安装指南.txt" << 'EOF'
🌍 CiteTrack Multilingual Installation Guide
多语言安装指南

📋 ENGLISH:
1. Drag CiteTrack.app to the Applications folder
2. Open CiteTrack from Applications or Launchpad
3. If you see a security warning, right-click the app and select "Open"
4. Go to Preferences to change language and add scholars
5. The app will automatically detect your system language

📋 简体中文:
1. 将 CiteTrack.app 拖拽到应用程序文件夹
2. 从应用程序或启动台打开 CiteTrack
3. 如果看到安全警告，右键点击应用并选择"打开"
4. 进入偏好设置更改语言并添加学者
5. 应用会自动检测您的系统语言

📋 日本語:
1. CiteTrack.app をアプリケーションフォルダにドラッグ
2. アプリケーションまたはLaunchpadからCiteTrackを開く
3. セキュリティ警告が表示された場合、アプリを右クリックして「開く」を選択
4. 環境設定で言語を変更し、研究者を追加
5. アプリは自動的にシステム言語を検出します

📋 한국어:
1. CiteTrack.app을 응용 프로그램 폴더로 드래그
2. 응용 프로그램 또는 런치패드에서 CiteTrack 열기
3. 보안 경고가 표시되면 앱을 우클릭하고 "열기" 선택
4. 환경설정에서 언어 변경 및 연구자 추가
5. 앱이 자동으로 시스템 언어를 감지합니다

🌟 Supported Languages / 支持的语言:
• English
• 简体中文 (Simplified Chinese)
• 日本語 (Japanese)
• 한국어 (Korean)
• Español (Spanish)
• Français (French)
• Deutsch (German)

🔧 Features / 功能特性:
• Real-time citation monitoring / 实时引用量监控
• Multi-scholar support / 多学者支持
• Automatic updates / 自动更新
• Menu bar integration / 菜单栏集成
• Language switching / 语言切换

📧 Support: https://github.com/tao-shen/CiteTrack
EOF

# 创建安全绕过脚本（多语言版本）
cat > "${TEMP_DIR}/Security Bypass - 安全绕过.command" << 'EOF'
#!/bin/bash

# CiteTrack Security Bypass Script
# CiteTrack 安全绕过脚本

echo "🌍 CiteTrack Security Bypass / 安全绕过工具"
echo "================================================"
echo ""

# 检测系统语言
LANG_CODE=$(defaults read -g AppleLanguages | sed -n 's/.*"\([^"]*\)".*/\1/p' | head -1)

if [[ "$LANG_CODE" == zh* ]]; then
    echo "🔓 正在移除 CiteTrack 的隔离属性..."
    echo "这将允许应用正常运行而不显示安全警告。"
    echo ""
elif [[ "$LANG_CODE" == ja* ]]; then
    echo "🔓 CiteTrackの隔離属性を削除しています..."
    echo "これによりセキュリティ警告なしでアプリが正常に動作します。"
    echo ""
elif [[ "$LANG_CODE" == ko* ]]; then
    echo "🔓 CiteTrack의 격리 속성을 제거하는 중..."
    echo "이렇게 하면 보안 경고 없이 앱이 정상적으로 실행됩니다."
    echo ""
else
    echo "🔓 Removing quarantine attributes from CiteTrack..."
    echo "This will allow the app to run normally without security warnings."
    echo ""
fi

# 查找 CiteTrack.app
APP_PATH=""
if [ -d "/Applications/CiteTrack.app" ]; then
    APP_PATH="/Applications/CiteTrack.app"
elif [ -d "$(dirname "$0")/CiteTrack.app" ]; then
    APP_PATH="$(dirname "$0")/CiteTrack.app"
else
    if [[ "$LANG_CODE" == zh* ]]; then
        echo "❌ 错误: 找不到 CiteTrack.app"
        echo "请确保已将应用安装到 /Applications 文件夹"
    elif [[ "$LANG_CODE" == ja* ]]; then
        echo "❌ エラー: CiteTrack.appが見つかりません"
        echo "アプリが/Applicationsフォルダにインストールされていることを確認してください"
    elif [[ "$LANG_CODE" == ko* ]]; then
        echo "❌ 오류: CiteTrack.app을 찾을 수 없습니다"
        echo "앱이 /Applications 폴더에 설치되어 있는지 확인하세요"
    else
        echo "❌ Error: CiteTrack.app not found"
        echo "Please make sure the app is installed in /Applications folder"
    fi
    exit 1
fi

# 移除隔离属性
xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null

if [ $? -eq 0 ]; then
    if [[ "$LANG_CODE" == zh* ]]; then
        echo "✅ 成功! CiteTrack 现在可以正常运行了"
        echo "您可以从应用程序文件夹或启动台打开它"
    elif [[ "$LANG_CODE" == ja* ]]; then
        echo "✅ 成功! CiteTrackが正常に実行できるようになりました"
        echo "アプリケーションフォルダまたはLaunchpadから開くことができます"
    elif [[ "$LANG_CODE" == ko* ]]; then
        echo "✅ 성공! CiteTrack이 이제 정상적으로 실행됩니다"
        echo "응용 프로그램 폴더나 런치패드에서 열 수 있습니다"
    else
        echo "✅ Success! CiteTrack can now run normally"
        echo "You can open it from Applications folder or Launchpad"
    fi
else
    if [[ "$LANG_CODE" == zh* ]]; then
        echo "⚠️  警告: 无法自动移除隔离属性"
        echo "请手动右键点击应用并选择'打开'"
    elif [[ "$LANG_CODE" == ja* ]]; then
        echo "⚠️  警告: 隔離属性を自動的に削除できませんでした"
        echo "アプリを右クリックして「開く」を手動で選択してください"
    elif [[ "$LANG_CODE" == ko* ]]; then
        echo "⚠️  경고: 격리 속성을 자동으로 제거할 수 없습니다"
        echo "앱을 우클릭하고 '열기'를 수동으로 선택하세요"
    else
        echo "⚠️  Warning: Could not automatically remove quarantine attributes"
        echo "Please manually right-click the app and select 'Open'"
    fi
fi

echo ""
if [[ "$LANG_CODE" == zh* ]]; then
    echo "按任意键关闭此窗口..."
elif [[ "$LANG_CODE" == ja* ]]; then
    echo "何かキーを押してこのウィンドウを閉じてください..."
elif [[ "$LANG_CODE" == ko* ]]; then
    echo "아무 키나 눌러 이 창을 닫으세요..."
else
    echo "Press any key to close this window..."
fi
read -n 1
EOF

# 给脚本添加执行权限
chmod +x "${TEMP_DIR}/Security Bypass - 安全绕过.command"

# 创建欢迎文件
cat > "${TEMP_DIR}/Welcome - 欢迎.txt" << 'EOF'
🌍 Welcome to CiteTrack Multilingual Edition
欢迎使用 CiteTrack 多语言版

🎉 Thank you for downloading CiteTrack!
感谢您下载 CiteTrack！

CiteTrack is a professional macOS menu bar application for monitoring Google Scholar citations in real-time.

CiteTrack 是一个专业的 macOS 菜单栏应用程序，用于实时监控 Google Scholar 引用量。

🌟 New in v1.1.0:
• Multi-language support (7 languages)
• Automatic system language detection
• Real-time language switching
• Localized error messages
• Enhanced user interface

🌟 v1.1.0 新功能:
• 多语言支持（7种语言）
• 自动系统语言检测
• 实时语言切换
• 本地化错误消息
• 增强的用户界面

🚀 Quick Start:
1. Drag CiteTrack.app to Applications folder
2. Open the app (use Security Bypass if needed)
3. Add your Google Scholar profile
4. Enjoy real-time citation monitoring!

🚀 快速开始:
1. 将 CiteTrack.app 拖到应用程序文件夹
2. 打开应用（如需要请使用安全绕过）
3. 添加您的 Google Scholar 档案
4. 享受实时引用量监控！

📧 Support & Updates:
GitHub: https://github.com/tao-shen/CiteTrack
Issues: https://github.com/tao-shen/CiteTrack/issues

Happy citing! 引用愉快！
EOF

echo "🎨 设置 DMG 外观..."

# 创建 DMG
hdiutil create -volname "CiteTrack Multilingual v${VERSION}" \
    -srcfolder "${TEMP_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}.dmg"

if [ $? -eq 0 ]; then
    # 清理临时文件
    rm -rf "${TEMP_DIR}"
    
    # 获取 DMG 大小
    DMG_SIZE=$(du -sh "${DMG_NAME}.dmg" | cut -f1)
    
    echo ""
    echo "🎉 多语言 DMG 创建完成！"
    echo "📁 文件名: ${DMG_NAME}.dmg"
    echo "📏 文件大小: ${DMG_SIZE}"
    echo ""
    echo "📦 DMG 内容:"
    echo "  • CiteTrack.app (多语言版本)"
    echo "  • Applications 文件夹快捷方式"
    echo "  • 多语言安装指南"
    echo "  • 安全绕过工具"
    echo "  • 欢迎文档"
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
    echo "🚀 可以分发 DMG 文件："
    echo "   open ${DMG_NAME}.dmg"
else
    echo "❌ DMG 创建失败"
    rm -rf "${TEMP_DIR}"
    exit 1
fi 