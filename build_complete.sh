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
APP_NAME="CiteTrack"
APP_VERSION="1.0"
BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S")

echo -e "${PURPLE}${BOLD}♾️  CiteTrack - 专业构建工具${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${BLUE}应用名称:${NC} $APP_NAME"
echo -e "${BLUE}版本:${NC} $APP_VERSION"
echo -e "${BLUE}构建时间:${NC} $BUILD_DATE"
echo ""

# 清理旧文件
echo -e "${YELLOW}🧹 清理旧文件...${NC}"
rm -rf "$APP_NAME.app" 2>/dev/null
rm -f "$APP_NAME.dmg" 2>/dev/null
rm -f "$APP_NAME" 2>/dev/null

# 检查图标文件
echo -e "${BLUE}🎨 检查应用图标...${NC}"
if [ -f "app_icon.icns" ]; then
    echo -e "${GREEN}  ✅ 图标文件存在${NC}"
else
    echo -e "${YELLOW}  ⚠️  图标文件不存在，尝试生成...${NC}"
    if [ -f "create_basic_icon.sh" ]; then
        chmod +x create_basic_icon.sh && ./create_basic_icon.sh
    fi
fi

# 编译Swift代码
echo -e "${BLUE}🔨 编译Swift应用...${NC}"
swiftc -O Sources/main.swift -o "${APP_NAME}_temp" -framework Cocoa -framework ServiceManagement

if [ $? -eq 0 ]; then
    mv "${APP_NAME}_temp" "$APP_NAME"
    echo -e "${GREEN}  ✅ 编译成功${NC}"
else
    echo -e "${RED}  ❌ 编译失败${NC}"
    exit 1
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
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>CiteTrack</string>
    <key>CFBundleExecutable</key>
    <string>CiteTrack</string>
    <key>CFBundleIconFile</key>
    <string>app_icon</string>
    <key>CFBundleIdentifier</key>
    <string>com.citetrack.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>CiteTrack</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2024 CiteTrack. 小而精，专业可靠。</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>SMAuthorizedClients</key>
    <array>
        <string>com.citetrack.app</string>
    </array>
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

# 创建DMG
echo -e "${BLUE}💿 创建DMG安装包...${NC}"
./create_professional_dmg.sh

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
if [ -f "$APP_NAME.dmg" ]; then
    DMG_SIZE=$(du -sh "$APP_NAME.dmg" | cut -f1)
    echo -e "${BLUE}  • DMG大小:${NC} $DMG_SIZE"
fi
echo -e "${BLUE}  • 构建时间:${NC} $BUILD_DATE"
echo ""
echo -e "${BOLD}🚀 使用方法:${NC}"
echo -e "${CYAN}  1. 双击 $APP_NAME.dmg 打开安装包${NC}"
echo -e "${CYAN}  2. 将应用拖拽到 Applications 文件夹${NC}"
echo -e "${CYAN}  3. 在 Applications 中启动应用${NC}"
echo ""
echo -e "${BOLD}🧪 测试复制粘贴功能:${NC}"
echo -e "${CYAN}  1. 启动应用并打开设置${NC}"
echo -e "${CYAN}  2. 点击'添加学者'${NC}"
echo -e "${CYAN}  3. 尝试在输入框中使用 Cmd+C/V/A${NC}"
echo -e "${CYAN}  4. 预填充的文本应该可以复制粘贴${NC}"