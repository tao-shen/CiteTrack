#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 应用信息
APP_NAME="GoogleScholarCitations"
APP_VERSION="1.0"
BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S")

echo -e "${PURPLE}${BOLD}♾️  Google Scholar Citations - 专业构建工具${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${BLUE}应用名称:${NC} $APP_NAME"
echo -e "${BLUE}版本:${NC} $APP_VERSION"
echo -e "${BLUE}构建时间:${NC} $BUILD_DATE"
echo ""

# 清理旧文件
echo -e "${YELLOW}🧹 清理旧文件...${NC}"
rm -rf "$APP_NAME.app" 2>/dev/null
rm -f "$APP_NAME.dmg" 2>/dev/null
rm -rf icon_temp* 2>/dev/null
rm -f app_icon.icns 2>/dev/null

# 创建应用图标
echo -e "${BLUE}🎨 生成专业应用图标...${NC}"

# 尝试使用Swift生成专业图标
if swift create_sf_icon.swift 2>/dev/null; then
    echo -e "${GREEN}  ✅ 专业图标生成成功${NC}"
elif chmod +x create_basic_icon.sh && ./create_basic_icon.sh; then
    echo -e "${GREEN}  ✅ 基础图标生成成功${NC}"
elif chmod +x create_simple_icon.sh && ./create_simple_icon.sh; then
    echo -e "${GREEN}  ✅ 简单图标生成成功${NC}"
else
    echo -e "${YELLOW}  ⚠️  图标生成失败，使用默认图标${NC}"
fi

# 编译Swift代码
echo -e "${BLUE}🔨 编译Swift应用...${NC}"
rm -rf "$APP_NAME" 2>/dev/null || true
swiftc -O Sources/main.swift -o "${APP_NAME}_temp" -framework Cocoa -framework Foundation

if [ $? -eq 0 ]; then
    mv "${APP_NAME}_temp" "$APP_NAME"
    echo -e "${GREEN}  ✅ 编译成功${NC}"
else
    echo -e "${RED}  ❌ 编译失败，尝试其他编译选项...${NC}"
    rm -f "${APP_NAME}_temp" 2>/dev/null
    # 尝试不同的编译选项
    swiftc Sources/main.swift -o "${APP_NAME}_temp" -framework Cocoa -framework Foundation -target x86_64-apple-macos12.0
    if [ $? -eq 0 ]; then
        mv "${APP_NAME}_temp" "$APP_NAME"
        echo -e "${GREEN}  ✅ 编译成功 (备选方案)${NC}"
    else
        echo -e "${RED}  ❌ 所有编译选项都失败${NC}"
        rm -f "${APP_NAME}_temp" 2>/dev/null
        exit 1
    fi
fi

# 创建应用包结构
echo -e "${BLUE}📦 创建应用包...${NC}"
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

# 移动可执行文件
mv "$APP_NAME" "$APP_NAME.app/Contents/MacOS/"

# 创建Info.plist
cat > "$APP_NAME.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.scholar.citations</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Google Scholar Citations</string>
    <key>CFBundleVersion</key>
    <string>$APP_VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSHumanReadableCopyright</key>
    <string>© 2024 Google Scholar Citations. All rights reserved.</string>
    <key>CFBundleIconFile</key>
    <string>app_icon</string>
</dict>
</plist>
EOF

# 复制图标文件
if [ -f "app_icon.icns" ]; then
    cp "app_icon.icns" "$APP_NAME.app/Contents/Resources/"
    echo -e "${GREEN}  ✅ 应用图标已添加${NC}"
else
    echo -e "${YELLOW}  ⚠️  未找到图标文件${NC}"
fi

# 设置权限
chmod +x "$APP_NAME.app/Contents/MacOS/$APP_NAME"

# 获取应用大小
APP_SIZE=$(du -sh "$APP_NAME.app" | cut -f1)
echo -e "${GREEN}  ✅ 应用包创建完成 (大小: $APP_SIZE)${NC}"

# 验证应用
echo -e "${BLUE}🔍 验证应用包...${NC}"
if [ -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" ]; then
    echo -e "${GREEN}  ✅ 可执行文件存在${NC}"
else
    echo -e "${RED}  ❌ 可执行文件缺失${NC}"
    exit 1
fi

if [ -f "$APP_NAME.app/Contents/Info.plist" ]; then
    echo -e "${GREEN}  ✅ Info.plist 存在${NC}"
else
    echo -e "${RED}  ❌ Info.plist 缺失${NC}"
    exit 1
fi

# 创建DMG
echo -e "${BLUE}💿 创建DMG安装包...${NC}"

# 创建临时目录
DMG_DIR="dmg_temp"
mkdir -p "$DMG_DIR"

# 复制应用到临时目录
cp -R "$APP_NAME.app" "$DMG_DIR/"

# 创建Applications文件夹的符号链接
ln -s /Applications "$DMG_DIR/Applications"

# 创建DMG
DMG_NAME="$APP_NAME.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_DIR" -ov -format UDBZ "$DMG_NAME"

if [ $? -eq 0 ]; then
    DMG_SIZE=$(du -sh "$DMG_NAME" | cut -f1)
    echo -e "${GREEN}  ✅ DMG创建成功 (大小: $DMG_SIZE)${NC}"
else
    echo -e "${RED}  ❌ DMG创建失败${NC}"
    exit 1
fi

# 清理临时文件
rm -rf "$DMG_DIR"
rm -rf icon_temp* 2>/dev/null

# 构建总结
echo ""
echo -e "${PURPLE}${BOLD}🎉 构建完成!${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}✅ 编译成功${NC}"
echo -e "${GREEN}✅ 应用包创建成功${NC}"
echo -e "${GREEN}✅ DMG安装包创建成功${NC}"
echo ""
echo -e "${BOLD}📊 构建统计:${NC}"
echo -e "${BLUE}  • 应用大小:${NC} $APP_SIZE"
echo -e "${BLUE}  • DMG大小:${NC} $DMG_SIZE"
echo -e "${BLUE}  • 构建时间:${NC} $BUILD_DATE"
echo ""
echo -e "${BOLD}📁 生成的文件:${NC}"
echo -e "${BLUE}  • $APP_NAME.app${NC} - macOS应用程序"
echo -e "${BLUE}  • $APP_NAME.dmg${NC} - 安装包"
echo ""
echo -e "${BOLD}🚀 使用方法:${NC}"
echo -e "${CYAN}  1. 双击 $APP_NAME.dmg 打开安装包${NC}"
echo -e "${CYAN}  2. 将应用拖拽到 Applications 文件夹${NC}"
echo -e "${CYAN}  3. 在 Applications 中启动应用${NC}"
echo -e "${CYAN}  4. 应用将在菜单栏显示 ♾️ 图标${NC}"
echo ""
echo -e "${BOLD}✨ 功能特色:${NC}"
echo -e "${CYAN}  • 🎯 小而精的专业设计${NC}"
echo -e "${CYAN}  • 🌓 自适应系统主题${NC}"
echo -e "${CYAN}  • 📚 多学者管理${NC}"
echo -e "${CYAN}  • 🔄 智能URL解析${NC}"
echo -e "${CYAN}  • ⚙️  专业设置界面${NC}"
echo -e "${CYAN}  • 🎨 精美菜单栏显示${NC}"
echo ""
echo -e "${GREEN}${BOLD}构建成功完成! 🎊${NC}" 