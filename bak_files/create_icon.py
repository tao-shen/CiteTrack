#!/usr/bin/env python3
"""
生成 Google Scholar Citations 应用图标
使用 ♾️ emoji 作为设计基础
"""

import os
import subprocess
from PIL import Image, ImageDraw, ImageFont
import sys

def create_icon_with_text(size, text="♾️", bg_color=(255, 255, 255, 0)):
    """创建带文字的图标"""
    # 创建图像
    img = Image.new('RGBA', (size, size), bg_color)
    draw = ImageDraw.Draw(img)
    
    # 尝试使用系统字体
    try:
        # macOS 系统emoji字体
        font_size = int(size * 0.7)
        font = ImageFont.truetype("/System/Library/Fonts/Apple Color Emoji.ttc", font_size)
    except:
        try:
            # 备选字体
            font_size = int(size * 0.7)
            font = ImageFont.truetype("/Library/Fonts/Arial Unicode.ttf", font_size)
        except:
            # 默认字体
            font = ImageFont.load_default()
    
    # 计算文字位置
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    x = (size - text_width) // 2
    y = (size - text_height) // 2
    
    # 绘制文字
    draw.text((x, y), text, fill=(0, 0, 0, 255), font=font)
    
    return img

def create_simple_infinity_icon(size):
    """创建简单的无穷符号图标"""
    img = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    
    # 计算无穷符号的参数
    center_x, center_y = size // 2, size // 2
    radius = size // 6
    width = size // 20 + 2
    
    # 绘制无穷符号 (两个相交的圆)
    color = (0, 122, 255, 255)  # 蓝色
    
    # 左圆
    left_center = (center_x - radius, center_y)
    draw.ellipse(
        [left_center[0] - radius, left_center[1] - radius,
         left_center[0] + radius, left_center[1] + radius],
        outline=color, width=width
    )
    
    # 右圆
    right_center = (center_x + radius, center_y)
    draw.ellipse(
        [right_center[0] - radius, right_center[1] - radius,
         right_center[0] + radius, right_center[1] + radius],
        outline=color, width=width
    )
    
    return img

def create_gradient_background(size):
    """创建渐变背景"""
    img = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    
    # 创建圆形渐变背景
    center = size // 2
    max_radius = center
    
    for i in range(max_radius):
        alpha = int(255 * (1 - i / max_radius) * 0.1)
        color = (0, 122, 255, alpha)
        draw.ellipse([center - i, center - i, center + i, center + i], 
                    outline=color, width=1)
    
    return img

def generate_icon_sizes():
    """生成所有需要的图标尺寸"""
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    
    if not os.path.exists('icon_temp'):
        os.makedirs('icon_temp')
    
    print("🎨 生成应用图标...")
    
    for size in sizes:
        print(f"  📐 生成 {size}x{size} 图标...")
        
        # 方法1: 尝试使用emoji
        try:
            icon = create_icon_with_text(size, "♾️")
            icon.save(f'icon_temp/icon_{size}x{size}.png')
            print(f"    ✅ emoji图标 {size}x{size} 生成成功")
            continue
        except Exception as e:
            print(f"    ⚠️  emoji图标生成失败: {e}")
        
        # 方法2: 使用简单图形
        try:
            # 创建背景
            bg = create_gradient_background(size)
            # 创建无穷符号
            infinity = create_simple_infinity_icon(size)
            # 合并
            icon = Image.alpha_composite(bg, infinity)
            icon.save(f'icon_temp/icon_{size}x{size}.png')
            print(f"    ✅ 图形图标 {size}x{size} 生成成功")
        except Exception as e:
            print(f"    ❌ 图标生成失败: {e}")
            # 创建纯色图标作为备选
            icon = Image.new('RGBA', (size, size), (0, 122, 255, 255))
            icon.save(f'icon_temp/icon_{size}x{size}.png')
            print(f"    ✅ 备选图标 {size}x{size} 生成成功")

def create_icns_file():
    """创建 .icns 文件"""
    print("\n📦 创建 .icns 文件...")
    
    try:
        # 使用 iconutil 创建 icns 文件
        subprocess.run(['iconutil', '-c', 'icns', 'icon_temp', '-o', 'app_icon.icns'], 
                      check=True)
        print("✅ app_icon.icns 创建成功")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ iconutil 失败: {e}")
        return False
    except FileNotFoundError:
        print("❌ iconutil 未找到，尝试手动创建...")
        return False

def main():
    """主函数"""
    print("♾️ Google Scholar Citations 图标生成器")
    print("=" * 50)
    
    # 检查 PIL 是否可用
    try:
        generate_icon_sizes()
    except ImportError:
        print("❌ 需要安装 Pillow: pip install Pillow")
        return False
    
    # 创建 icns 文件
    success = create_icns_file()
    
    if success:
        print("\n🎉 图标生成完成!")
        print("📍 生成的文件:")
        print("  • app_icon.icns - macOS应用图标")
        print("  • icon_temp/ - 各尺寸PNG图标")
    else:
        print("\n⚠️  图标生成部分成功")
        print("📍 生成的文件:")
        print("  • icon_temp/ - 各尺寸PNG图标")
    
    return success

if __name__ == "__main__":
    main() 