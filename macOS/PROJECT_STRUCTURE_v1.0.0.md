# CiteTrack v1.0.0 macOS 项目结构

## 📁 项目目录结构

### 🎯 核心项目文件
```
CiteTrack_macOS/
├── CiteTrack_macOS.xcodeproj/          # Xcode项目文件
│   ├── project.pbxproj                 # 项目配置
│   └── xcshareddata/                   # 共享数据
├── Sources/                            # 源代码文件
│   ├── main.swift                      # 应用程序入口
│   ├── SettingsWindow.swift            # 设置窗口
│   ├── DataManager.swift               # 数据管理器
│   ├── iCloudSyncManager.swift         # iCloud同步
│   ├── CitationHistoryManager.swift    # 引用历史管理
│   ├── CoreDataManager.swift           # Core Data管理
│   ├── Localization.swift              # 本地化支持
│   ├── NotificationManager.swift       # 通知管理
│   ├── GoogleScholarService+History.swift # Google Scholar服务
│   ├── ChartView.swift                 # 图表视图
│   ├── ChartTheme.swift                # 图表主题
│   ├── ChartsViewController.swift        # 图表控制器
│   ├── ChartsWindowController.swift     # 图表窗口控制器
│   ├── DashboardComponents.swift        # 仪表板组件
│   ├── EnhancedChartTypes.swift        # 增强图表类型
│   ├── ModernCardView.swift             # 现代卡片视图
│   ├── DataRepairViewController.swift   # 数据修复视图
│   ├── CitationHistoryEntity.swift     # 引用历史实体
│   └── CitationHistory.swift           # 引用历史模型
├── assets/                             # 资源文件
│   ├── app_icon.icns                   # 应用图标
│   ├── hinton_citations_example.png    # 示例图片
│   └── logo.png                        # 应用Logo
├── Assets.xcassets/                    # 资源包
│   └── AppIcon.appiconset/             # 应用图标集
├── Frameworks/                         # 框架文件
│   └── Sparkle.framework/              # Sparkle更新框架
├── scripts/                            # 构建脚本
│   ├── build_charts.sh                 # 图表构建脚本
│   ├── build_mas.sh                    # Mac App Store构建
│   ├── create_v1.0.0_dmg.sh            # v1.0.0 DMG创建
│   └── ...                             # 其他构建脚本
├── docs/                               # 文档
│   ├── CHANGELOG.md                    # 更新日志
│   ├── FEATURES.md                     # 功能说明
│   └── ICLOUD_DEBUG_GUIDE.md          # iCloud调试指南
├── CiteTrack.entitlements              # 应用权限
├── Info.plist                          # 应用信息
├── appcast.xml                         # Sparkle更新配置
└── FINAL_V2_COMPLETE_SUMMARY.md       # 项目完成报告
```

### 🗂️ 备份文件
```
backup_old_files_20251026_024551/       # 旧文件备份
├── backup_files/                       # 历史备份
├── CiteTrack_macOS.xcodeproj.backup_*/ # 项目备份
├── *.dmg                              # 旧版本DMG文件
├── *.app                              # 旧版本应用
├── *.py                               # Python脚本
├── *.rb                               # Ruby脚本
├── *.sh                               # Shell脚本
├── *.md                               # 旧文档
└── build_output*.log                  # 构建日志
```

## 🎯 保留的核心文件

### 源代码 (Sources/)
- **main.swift** - 应用程序入口点
- **SettingsWindow.swift** - 设置窗口，包含数据管理功能
- **DataManager.swift** - 数据管理器，与iOS兼容
- **iCloudSyncManager.swift** - iCloud同步管理器
- **CitationHistoryManager.swift** - 引用历史管理器
- **CoreDataManager.swift** - Core Data管理器
- **Localization.swift** - 多语言支持
- **NotificationManager.swift** - 通知管理器
- **GoogleScholarService+History.swift** - Google Scholar服务扩展
- **ChartView.swift** - 图表视图组件
- **ChartTheme.swift** - 图表主题配置
- **ChartsViewController.swift** - 图表控制器
- **ChartsWindowController.swift** - 图表窗口控制器
- **DashboardComponents.swift** - 仪表板组件
- **EnhancedChartTypes.swift** - 增强图表类型
- **ModernCardView.swift** - 现代卡片视图
- **DataRepairViewController.swift** - 数据修复视图控制器
- **CitationHistoryEntity.swift** - 引用历史实体
- **CitationHistory.swift** - 引用历史模型

### 资源文件
- **assets/app_icon.icns** - 应用图标
- **Assets.xcassets/** - 资源包
- **Frameworks/Sparkle.framework** - 更新框架

### 配置文件
- **CiteTrack_macOS.xcodeproj** - Xcode项目
- **CiteTrack.entitlements** - 应用权限
- **Info.plist** - 应用信息
- **appcast.xml** - 更新配置

### 构建脚本
- **scripts/build_charts.sh** - 图表构建
- **scripts/create_v2.0.0_dmg.sh** - DMG创建
- **scripts/build_mas.sh** - Mac App Store构建

### 文档
- **docs/** - 项目文档
- **FINAL_V2_COMPLETE_SUMMARY.md** - 完成报告

## 🗑️ 已移动的旧文件

### 开发脚本
- Python脚本 (*.py)
- Ruby脚本 (*.rb)
- Shell脚本 (*.sh)

### 构建文件
- 构建日志 (*.log)
- 构建输出文件
- 旧版本应用和DMG

### 备份文件
- 项目备份
- 历史备份文件
- 旧文档

### 临时文件
- 编译输出
- 调试文件
- 临时脚本

## 🚀 项目状态

- **版本**: v1.0.0
- **编译状态**: ✅ 成功 (0错误, 0警告)
- **功能状态**: ✅ 全部实现
- **文件整理**: ✅ 完成
- **备份状态**: ✅ 安全备份

## 📋 使用说明

1. **开发**: 在Xcode中打开 `CiteTrack_macOS.xcodeproj`
2. **构建**: 使用 `scripts/` 目录下的构建脚本
3. **文档**: 查看 `docs/` 目录和 `FINAL_V2_COMPLETE_SUMMARY.md`
4. **备份**: 旧文件已安全备份到 `backup_old_files_*/` 目录

---

**整理完成时间**: 2024年10月26日  
**项目状态**: ✅ 清理完成  
**文件数量**: 精简到核心文件  
**备份状态**: ✅ 安全备份
