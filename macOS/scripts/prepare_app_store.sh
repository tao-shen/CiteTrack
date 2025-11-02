#!/bin/bash
#
# App Store提交准备脚本
# 此脚本从Archive中移除Sparkle框架，确保App通过App Store验证
#
# 使用方法：
# 1. 在Xcode中Archive应用（确保启用APP_STORE编译标志）
# 2. 运行此脚本：./scripts/prepare_app_store.sh <archive_path>
# 3. 使用Xcode的Organizer上传处理后的Archive

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  CiteTrack App Store 提交准备工具     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# 检查参数
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}未指定Archive路径，正在搜索最新的Archive...${NC}"
    ARCHIVES_DIR="$HOME/Library/Developer/Xcode/Archives"
    
    # 查找最新的CiteTrack archive
    LATEST_ARCHIVE=$(find "$ARCHIVES_DIR" -name "CiteTrack*.xcarchive" -type d -print0 | xargs -0 ls -dt | head -n 1)
    
    if [ -z "$LATEST_ARCHIVE" ]; then
        echo -e "${RED}❌ 错误：未找到CiteTrack Archive${NC}"
        echo -e "${YELLOW}请先在Xcode中Archive应用，或手动指定Archive路径：${NC}"
        echo -e "   $0 <archive_path>"
        exit 1
    fi
    
    ARCHIVE_PATH="$LATEST_ARCHIVE"
    echo -e "${GREEN}✓ 找到Archive: $ARCHIVE_PATH${NC}"
else
    ARCHIVE_PATH="$1"
fi

# 验证Archive路径
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}❌ 错误：Archive不存在: $ARCHIVE_PATH${NC}"
    exit 1
fi

APP_PATH="$ARCHIVE_PATH/Products/Applications/CiteTrack.app"
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ 错误：在Archive中找不到CiteTrack.app${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📦 Archive信息：${NC}"
echo -e "   路径: $ARCHIVE_PATH"
echo -e "   应用: $APP_PATH"
echo ""

# 创建备份
BACKUP_PATH="${ARCHIVE_PATH}.backup_$(date +%Y%m%d_%H%M%S)"
echo -e "${YELLOW}⏳ 创建备份...${NC}"
cp -R "$ARCHIVE_PATH" "$BACKUP_PATH"
echo -e "${GREEN}✓ 备份已创建: $BACKUP_PATH${NC}"
echo ""

# 移除Sparkle框架
FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
SPARKLE_FRAMEWORK="$FRAMEWORKS_DIR/Sparkle.framework"

if [ -d "$SPARKLE_FRAMEWORK" ]; then
    echo -e "${YELLOW}⏳ 移除Sparkle框架...${NC}"
    rm -rf "$SPARKLE_FRAMEWORK"
    echo -e "${GREEN}✓ Sparkle框架已移除${NC}"
else
    echo -e "${GREEN}✓ Sparkle框架不存在（可能已使用APP_STORE标志编译）${NC}"
fi

# 检查其他可能的Sparkle组件
SPARKLE_FILES=(
    "$APP_PATH/Contents/Frameworks/Sparkle.framework"
    "$APP_PATH/Contents/XPCServices/org.sparkle-project.*.xpc"
)

for file in "${SPARKLE_FILES[@]}"; do
    if [ -e "$file" ]; then
        echo -e "${YELLOW}⏳ 移除 $(basename "$file")...${NC}"
        rm -rf "$file"
    fi
done

echo ""

# 验证应用签名
echo -e "${YELLOW}⏳ 验证应用签名...${NC}"
if codesign --verify --deep --strict "$APP_PATH" 2>/dev/null; then
    echo -e "${GREEN}✓ 应用签名有效${NC}"
else
    echo -e "${YELLOW}⚠ 警告：应用签名可能需要重新签名${NC}"
    echo -e "${YELLOW}   在上传到App Store Connect时，Xcode会自动重新签名${NC}"
fi

echo ""

# 检查沙盒权限
echo -e "${YELLOW}⏳ 检查沙盒权限...${NC}"
ENTITLEMENTS=$(codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | plutil -convert xml1 - -o -)

if echo "$ENTITLEMENTS" | grep -q "com.apple.security.app-sandbox"; then
    echo -e "${GREEN}✓ 应用沙盒已启用${NC}"
else
    echo -e "${RED}❌ 错误：应用沙盒未启用${NC}"
    echo -e "${YELLOW}   请在Xcode项目设置中启用App Sandbox${NC}"
fi

echo ""

# 检查dSYM文件
echo -e "${YELLOW}⏳ 检查dSYM文件...${NC}"
DSYMS_DIR="$ARCHIVE_PATH/dSYMs"

if [ -d "$DSYMS_DIR" ]; then
    DSYM_COUNT=$(find "$DSYMS_DIR" -name "*.dSYM" -type d | wc -l)
    if [ "$DSYM_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ 找到 $DSYM_COUNT 个dSYM文件${NC}"
        find "$DSYMS_DIR" -name "*.dSYM" -type d -exec basename {} \; | while read -r dsym; do
            echo -e "   - $dsym"
        done
    else
        echo -e "${YELLOW}⚠ 警告：未找到dSYM文件${NC}"
        echo -e "${YELLOW}   请在Xcode Build Settings中设置：${NC}"
        echo -e "   - Debug Information Format = DWARF with dSYM File${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 警告：dSYMs目录不存在${NC}"
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           准备完成                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ Archive已准备好上传到App Store${NC}"
echo ""
echo -e "${BLUE}下一步操作：${NC}"
echo -e "1. 打开Xcode"
echo -e "2. 选择 Window → Organizer"
echo -e "3. 在Archives标签中找到: $(basename "$ARCHIVE_PATH")"
echo -e "4. 点击 'Distribute App'"
echo -e "5. 选择 'App Store Connect'"
echo -e "6. 按照向导完成上传"
echo ""
echo -e "${YELLOW}注意：${NC}"
echo -e "- 原始Archive已备份到: $BACKUP_PATH"
echo -e "- 如果遇到问题，可以恢复备份"
echo ""

