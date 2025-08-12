#!/bin/bash

echo "🎨 创建优化尺寸的应用图标..."

# 创建图标目录
mkdir -p icon_temp.iconset

# 创建优化尺寸的专业图标
create_optimized_icon() {
    local size=$1
    local output=$2
    
    # 创建SVG图标 - 优化圆角和边距
    cat > temp_icon.svg << EOF
<svg width="$size" height="$size" xmlns="http://www.w3.org/2000/svg">
    <defs>
        <!-- 白色质感背景渐变 -->
        <radialGradient id="bgGrad" cx="50%" cy="30%" r="70%">
            <stop offset="0%" style="stop-color:#FFFFFF;stop-opacity:1" />
            <stop offset="70%" style="stop-color:#F8F9FA;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#E9ECEF;stop-opacity:1" />
        </radialGradient>
        
        <!-- 边框渐变 -->
        <linearGradient id="borderGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#DEE2E6;stop-opacity:0.8" />
            <stop offset="100%" style="stop-color:#CED4DA;stop-opacity:0.6" />
        </linearGradient>
        
        <!-- 无穷符号渐变 -->
        <linearGradient id="symbolGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#007AFF;stop-opacity:1" />
            <stop offset="50%" style="stop-color:#0056CC;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#003D99;stop-opacity:1" />
        </linearGradient>
        
        <!-- 阴影滤镜 -->
        <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
            <feDropShadow dx="0" dy="1" stdDeviation="$(($size/80))" flood-color="#000000" flood-opacity="0.1"/>
        </filter>
    </defs>
    
    <!-- 优化的白色背景 - 更小的圆角，符合macOS标准 -->
    <rect width="$size" height="$size" 
          rx="$(($size/8))" ry="$(($size/8))" 
          fill="url(#bgGrad)" 
          stroke="url(#borderGrad)" 
          stroke-width="$(($size/60))"
          filter="url(#shadow)"/>
    
    <!-- 无穷符号 - 适当缩小，增加边距 -->
    <g transform="translate($(($size/2)), $(($size/2)))">
        <!-- 左圆 -->
        <circle cx="-$(($size/6))" cy="0" r="$(($size/5))" 
                fill="none" 
                stroke="url(#symbolGrad)" 
                stroke-width="$(($size/10))" 
                stroke-linecap="round"/>
        <!-- 右圆 -->
        <circle cx="$(($size/6))" cy="0" r="$(($size/5))" 
                fill="none" 
                stroke="url(#symbolGrad)" 
                stroke-width="$(($size/10))" 
                stroke-linecap="round"/>
    </g>
</svg>
EOF
    
    # 转换SVG到PNG
    if command -v rsvg-convert >/dev/null 2>&1; then
        rsvg-convert -w $size -h $size temp_icon.svg -o "$output"
    elif command -v convert >/dev/null 2>&1; then
        convert temp_icon.svg -resize ${size}x${size} "$output"
    elif command -v inkscape >/dev/null 2>&1; then
        inkscape temp_icon.svg -w $size -h $size -o "$output" 2>/dev/null
    else
        # 使用Python PIL创建优化图标
        python3 -c "
import sys
try:
    from PIL import Image, ImageDraw
    
    # 创建图像
    img = Image.new('RGBA', ($size, $size), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    # 绘制圆角背景 - 更小的圆角
    margin = $size // 20
    corner_radius = $size // 8  # 从 $size//5 改为 $size//8
    
    # 白色质感背景
    draw.rounded_rectangle([margin, margin, $size-margin, $size-margin], 
                          radius=corner_radius, 
                          fill=(248, 249, 250, 255),
                          outline=(206, 212, 218, 200),
                          width=max(1, $size//60))
    
    # 绘制无穷符号 - 适当缩小
    center = $size // 2
    radius = $size // 5  # 保持半径
    width = max($size // 10, 3)  # 稍微细一点
    
    # 左圆 - 距离中心更近
    left_center = (center - $size//6, center)  # 从 $size//5 改为 $size//6
    draw.ellipse([left_center[0] - radius, left_center[1] - radius,
                  left_center[0] + radius, left_center[1] + radius],
                 outline=(0, 122, 255, 255), width=width)
    
    # 右圆
    right_center = (center + $size//6, center)  # 从 $size//5 改为 $size//6
    draw.ellipse([right_center[0] - radius, right_center[1] - radius,
                  right_center[0] + radius, right_center[1] + radius],
                 outline=(0, 122, 255, 255), width=width)
    
    img.save('$output')
    print('Created optimized $output using PIL')
except ImportError:
    # 创建基本PNG
    with open('$output', 'wb') as f:
        # 简单的PNG头
        f.write(b'\\x89PNG\\r\\n\\x1a\\n\\x00\\x00\\x00\\rIHDR\\x00\\x00\\x00 \\x00\\x00\\x00 \\x08\\x06\\x00\\x00\\x00szz\\xf4\\x00\\x00\\x00\\x19tEXtSoftware\\x00Adobe ImageReadyq\\xc9e<\\x00\\x00\\x00\\x00IEND\\xaeB\`\\x82')
    print('Created fallback $output')
" 2>/dev/null || echo "Created fallback icon"
    fi
    
    rm -f temp_icon.svg 2>/dev/null
}

# 生成所有尺寸的优化图标
echo "  📐 生成各尺寸优化图标..."

create_optimized_icon 16 "icon_temp.iconset/icon_16x16.png"
create_optimized_icon 32 "icon_temp.iconset/icon_16x16@2x.png"
create_optimized_icon 32 "icon_temp.iconset/icon_32x32.png"
create_optimized_icon 64 "icon_temp.iconset/icon_32x32@2x.png"
create_optimized_icon 128 "icon_temp.iconset/icon_128x128.png"
create_optimized_icon 256 "icon_temp.iconset/icon_128x128@2x.png"
create_optimized_icon 256 "icon_temp.iconset/icon_256x256.png"
create_optimized_icon 512 "icon_temp.iconset/icon_256x256@2x.png"
create_optimized_icon 512 "icon_temp.iconset/icon_512x512.png"
create_optimized_icon 1024 "icon_temp.iconset/icon_512x512@2x.png"

echo "✅ 优化图标生成完成"

# 创建icns文件
if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns icon_temp.iconset -o app_icon_optimized.icns
    if [ -f "app_icon_optimized.icns" ]; then
        echo "✅ app_icon_optimized.icns 创建成功"
    fi
else
    echo "⚠️  iconutil 不可用"
fi

echo "🎉 优化尺寸图标生成完成"