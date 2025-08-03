# CiteTrack - 仓库代码组织结构

本文档描述了CiteTrack项目的新代码组织结构，支持macOS和iOS平台的开发。

## 📁 目录结构

```
google_scholar_plugin/
├── README.md                    # 项目主要说明文档
├── LICENSE                      # MIT许可证
├── REPOSITORY_STRUCTURE.md      # 本文档 - 仓库结构说明
│
├── macOS/                       # macOS专用代码
│   ├── Sources/                 # Swift源代码
│   ├── scripts/                 # 构建和部署脚本
│   ├── assets/                  # 资源文件（图标等）
│   ├── CiteTrack.app/          # 编译后的应用
│   ├── CiteTrack.entitlements  # 应用权限配置
│   ├── Frameworks/             # 第三方框架（如Sparkle）
│   ├── docs/                   # macOS专用文档
│   └── *.dmg                   # 发布的安装包
│
├── iOS/                        # iOS专用代码（待创建）
│   ├── CiteTrack-iOS/          # iOS项目目录
│   │   ├── App/                # 应用入口和配置
│   │   ├── Views/              # SwiftUI视图
│   │   ├── ViewModels/         # MVVM视图模型
│   │   ├── Resources/          # iOS专用资源
│   │   └── Widgets/            # iOS小组件
│   ├── CiteTrack-iOS.xcodeproj # Xcode项目文件
│   └── Package.swift          # Swift Package配置
│
├── Shared/                     # 跨平台共享代码
│   ├── Models/                 # 数据模型
│   │   ├── Scholar.swift       # 学者数据模型
│   │   ├── CitationHistory.swift # 引用历史模型
│   │   └── ExportFormat.swift  # 导出格式定义
│   │
│   ├── Services/               # 业务服务层
│   │   ├── GoogleScholarService.swift # Google Scholar API服务
│   │   ├── DataSyncService.swift      # 数据同步服务
│   │   └── NotificationService.swift  # 通知服务
│   │
│   ├── Managers/               # 管理器类
│   │   ├── CoreDataManager.swift      # Core Data管理
│   │   ├── SettingsManager.swift      # 设置管理
│   │   └── LocalizationManager.swift  # 多语言管理
│   │
│   ├── Utilities/              # 工具类和扩展
│   │   ├── DateExtensions.swift       # 日期扩展
│   │   ├── StringExtensions.swift     # 字符串扩展
│   │   └── NetworkHelpers.swift       # 网络工具
│   │
│   └── CoreData/               # Core Data模型文件
│       └── CitationTrackingModel.xcdatamodeld
│
└── docs/                       # 项目文档
    ├── iOS_DEVELOPMENT_GUIDE.md    # iOS开发指南
    ├── SHARED_CODE_STRATEGY.md     # 共享代码策略
    └── DEPLOYMENT_GUIDE.md         # 部署指南
```

## 🔄 代码共享策略

### 高度共享的组件

这些组件在macOS和iOS之间几乎完全共享：

- **数据模型** (`Shared/Models/`)
  - `Scholar.swift` - 学者数据结构
  - `CitationHistory.swift` - 引用历史记录
  - `ExportFormat.swift` - 数据导出格式

- **业务服务** (`Shared/Services/`)
  - `GoogleScholarService.swift` - Google Scholar数据抓取
  - `DataSyncService.swift` - 数据同步逻辑
  - `NotificationService.swift` - 通知系统

- **数据管理** (`Shared/Managers/`)
  - `CoreDataManager.swift` - 数据持久化
  - `SettingsManager.swift` - 应用设置
  - `LocalizationManager.swift` - 多语言支持

- **工具类** (`Shared/Utilities/`)
  - `DateExtensions.swift` - 日期处理工具
  - `StringExtensions.swift` - 字符串处理工具
  - `NetworkHelpers.swift` - 网络请求工具

### 平台特定的组件

这些组件需要针对每个平台单独实现：

- **UI界面**
  - macOS: AppKit + NSViewController
  - iOS: SwiftUI + UIKit

- **图表实现**
  - macOS: 自定义ChartView + Core Graphics
  - iOS: SwiftCharts + Charts框架

- **系统集成**
  - macOS: 菜单栏集成、Launch Agent
  - iOS: Widget、Siri Shortcuts、后台刷新

## 🚀 开发流程

### 1. 共享代码开发
- 在 `Shared/` 目录下开发跨平台组件
- 使用条件编译 `#if os(iOS)` / `#if os(macOS)` 处理平台差异
- 确保API接口在两个平台上保持一致

### 2. 平台特定开发
- macOS: 继续在 `macOS/Sources/` 下开发
- iOS: 在 `iOS/CiteTrack-iOS/` 下开发新功能

### 3. 测试策略
- 共享组件: 使用Swift Package Manager进行单元测试
- UI组件: 分别在各平台进行集成测试

## 📦 依赖管理

### macOS
- 使用传统的Framework方式管理依赖（如Sparkle）
- 逐步迁移到Swift Package Manager

### iOS
- 使用Swift Package Manager管理所有依赖
- 包括图表库、网络库等

### 共享代码
- 使用Swift Package Manager进行依赖管理
- 确保依赖库支持多平台

## 🔧 构建配置

### macOS构建
```bash
cd macOS
./scripts/build_charts.sh
./scripts/create_charts_dmg.sh
```

### iOS构建
```bash
cd iOS
swift build
# 或使用Xcode打开项目文件
```

### 共享代码测试
```bash
cd Shared
swift test
```

## 📋 迁移清单

- [x] 创建新的目录结构
- [x] 移动现有macOS代码到 `macOS/` 目录
- [x] 创建共享的数据模型
- [x] 创建共享的服务层
- [x] 创建共享的管理器类
- [x] 创建共享的工具类
- [x] 复制Core Data模型到共享目录
- [ ] 创建iOS项目基础结构
- [ ] 实现iOS核心功能模块
- [ ] 实现iOS用户界面
- [ ] 配置CI/CD流程
- [ ] 完善文档和测试

## 🔮 未来扩展

这个结构为将来可能的扩展做好了准备：

1. **watchOS支持**: 可以在根目录添加 `watchOS/` 文件夹
2. **tvOS支持**: 可以在根目录添加 `tvOS/` 文件夹
3. **Web版本**: 可以添加 `Web/` 文件夹用于SwiftWasm
4. **服务端**: 可以添加 `Server/` 文件夹用于Vapor后端

## 📝 注意事项

1. **Git历史**: 移动文件时保留了Git历史记录
2. **向后兼容**: 现有的macOS构建流程保持不变
3. **文档同步**: 各平台特定的文档放在对应目录下
4. **资源文件**: 图标、图片等资源按平台分别管理
5. **配置文件**: 项目配置文件保留在各自的目录中