#!/usr/bin/env swift

import Cocoa
import CoreGraphics

func createInfinityIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    
    image.lockFocus()
    
    // 背景透明
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    
    // 绘制无穷符号
    let context = NSGraphicsContext.current?.cgContext
    context?.saveGState()
    
    // 设置绘制参数
    let lineWidth = max(size / 40, 2.0)
    let centerX = size / 2
    let centerY = size / 2
    let radius = size / 6
    
    // 创建无穷符号路径
    let path = NSBezierPath()
    
    // 左半部分 (圆)
    let leftCenter = NSPoint(x: centerX - radius, y: centerY)
    path.appendArc(withCenter: leftCenter, radius: radius, startAngle: 0, endAngle: 360)
    
    // 右半部分 (圆)
    let rightCenter = NSPoint(x: centerX + radius, y: centerY)
    path.appendArc(withCenter: rightCenter, radius: radius, startAngle: 0, endAngle: 360)
    
    // 设置线条样式
    path.lineWidth = lineWidth
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    
    // 使用系统蓝色
    NSColor.systemBlue.setStroke()
    path.stroke()
    
    context?.restoreGState()
    
    image.unlockFocus()
    return image
}

func createModernInfinityIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    
    image.lockFocus()
    
    // 背景渐变
    let gradient = NSGradient(colors: [
        NSColor.systemBlue.withAlphaComponent(0.1),
        NSColor.systemBlue.withAlphaComponent(0.05)
    ])
    
    let backgroundPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), 
                                    xRadius: size / 8, yRadius: size / 8)
    gradient?.draw(in: backgroundPath, angle: 45)
    
    // 绘制无穷符号
    let context = NSGraphicsContext.current?.cgContext
    context?.saveGState()
    
    let lineWidth = size / 20
    let centerX = size / 2
    let centerY = size / 2
    let radius = size / 5
    
    // 创建更精细的无穷符号
    let path = NSBezierPath()
    
    // 使用贝塞尔曲线创建平滑的无穷符号
    path.move(to: NSPoint(x: centerX - radius * 1.5, y: centerY))
    path.curve(to: NSPoint(x: centerX, y: centerY + radius * 0.7),
               controlPoint1: NSPoint(x: centerX - radius * 1.5, y: centerY + radius * 1.2),
               controlPoint2: NSPoint(x: centerX - radius * 0.7, y: centerY + radius * 0.7))
    path.curve(to: NSPoint(x: centerX + radius * 1.5, y: centerY),
               controlPoint1: NSPoint(x: centerX + radius * 0.7, y: centerY + radius * 0.7),
               controlPoint2: NSPoint(x: centerX + radius * 1.5, y: centerY + radius * 1.2))
    path.curve(to: NSPoint(x: centerX, y: centerY - radius * 0.7),
               controlPoint1: NSPoint(x: centerX + radius * 1.5, y: centerY - radius * 1.2),
               controlPoint2: NSPoint(x: centerX + radius * 0.7, y: centerY - radius * 0.7))
    path.curve(to: NSPoint(x: centerX - radius * 1.5, y: centerY),
               controlPoint1: NSPoint(x: centerX - radius * 0.7, y: centerY - radius * 0.7),
               controlPoint2: NSPoint(x: centerX - radius * 1.5, y: centerY - radius * 1.2))
    
    path.lineWidth = lineWidth
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    
    // 渐变色描边
    NSColor.systemBlue.setStroke()
    path.stroke()
    
    context?.restoreGState()
    
    image.unlockFocus()
    return image
}

func saveIconSet() {
    let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]
    let iconSetPath = "icon_temp.iconset"
    
    // 创建图标集目录
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: iconSetPath) {
        try? fileManager.removeItem(atPath: iconSetPath)
    }
    try? fileManager.createDirectory(atPath: iconSetPath, withIntermediateDirectories: true)
    
    print("🎨 生成专业图标...")
    
    for size in sizes {
        let icon = createModernInfinityIcon(size: size)
        
        // 保存不同尺寸的文件
        let configs = [
            (size: 16, name: "icon_16x16.png", targetSize: 16),
            (size: 32, name: "icon_16x16@2x.png", targetSize: 16),
            (size: 32, name: "icon_32x32.png", targetSize: 32),
            (size: 64, name: "icon_32x32@2x.png", targetSize: 32),
            (size: 128, name: "icon_128x128.png", targetSize: 128),
            (size: 256, name: "icon_128x128@2x.png", targetSize: 128),
            (size: 256, name: "icon_256x256.png", targetSize: 256),
            (size: 512, name: "icon_256x256@2x.png", targetSize: 256),
            (size: 512, name: "icon_512x512.png", targetSize: 512),
            (size: 1024, name: "icon_512x512@2x.png", targetSize: 512)
        ]
        
        for config in configs {
            if config.size == Int(size) {
                let targetIcon = (config.size == Int(size)) ? icon : createModernInfinityIcon(size: CGFloat(config.size))
                
                if let tiffData = targetIcon.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                    
                    let filePath = "\(iconSetPath)/\(config.name)"
                    pngData.write(to: URL(fileURLWithPath: filePath))
                    print("  ✅ \(config.name) - \(config.size)x\(config.size)")
                }
            }
        }
    }
    
    print("\n📦 创建 .icns 文件...")
    
    // 使用 iconutil 创建 .icns 文件
    let task = Process()
    task.launchPath = "/usr/bin/iconutil"
    task.arguments = ["-c", "icns", iconSetPath, "-o", "app_icon.icns"]
    
    do {
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus == 0 {
            print("✅ app_icon.icns 创建成功")
        } else {
            print("❌ iconutil 执行失败")
        }
    } catch {
        print("❌ 无法执行 iconutil: \(error)")
    }
}

// 主程序
print("♾️ Google Scholar Citations 专业图标生成器")
print("=" * 50)

saveIconSet()

print("\n🎉 专业图标生成完成!")
print("📍 生成的文件:")
print("  • app_icon.icns - macOS应用图标")
print("  • icon_temp.iconset/ - 图标集合") 