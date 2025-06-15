# 🌍 CiteTrack 多语言功能说明

## 概述

CiteTrack v1.1.0 现已支持多语言界面，为全球用户提供本地化体验。应用会自动检测系统语言，并提供实时语言切换功能。

## 支持的语言

| 语言 | 代码 | 状态 |
|------|------|------|
| English | en | ✅ 完整支持 |
| 简体中文 | zh-Hans | ✅ 完整支持 |
| 日本語 | ja | ✅ 完整支持 |
| 한국어 | ko | ✅ 完整支持 |
| Español | es | ✅ 基础支持 |
| Français | fr | ✅ 基础支持 |
| Deutsch | de | ✅ 基础支持 |

## 功能特性

### 🔄 自动语言检测
- 应用启动时自动检测系统语言
- 如果系统语言不受支持，默认使用英语
- 用户设置的语言优先级高于系统语言

### 🎛️ 实时语言切换
- 在设置窗口中选择语言
- 界面立即更新，无需重启应用
- 菜单栏、对话框、错误消息全部本地化

### 📝 完整本地化
- 菜单项和按钮文本
- 错误消息和提示信息
- 设置窗口所有选项
- 时间间隔显示
- 对话框和警告信息

## 技术实现

### 本地化管理器
```swift
class LocalizationManager {
    static let shared = LocalizationManager()
    
    enum Language: String, CaseIterable {
        case english = "en"
        case chinese = "zh-Hans"
        case japanese = "ja"
        case korean = "ko"
        case spanish = "es"
        case french = "fr"
        case german = "de"
    }
    
    func localized(_ key: String) -> String
    func setLanguage(_ language: Language)
}
```

### 便捷函数
```swift
// 简单本地化
func L(_ key: String) -> String

// 带参数的本地化
func L(_ key: String, _ args: CVarArg...) -> String
```

### 语言变化通知
```swift
extension Notification.Name {
    static let languageChanged = Notification.Name("LanguageChanged")
}
```

## 使用方法

### 1. 自动检测
应用启动时会自动检测系统语言：
- 中文系统 → 显示简体中文界面
- 日文系统 → 显示日语界面
- 韩文系统 → 显示韩语界面
- 其他系统 → 显示英语界面

### 2. 手动切换
在设置窗口中：
1. 打开 "偏好设置" / "Preferences"
2. 找到 "语言" / "Language" 选项
3. 选择您偏好的语言
4. 界面立即更新

### 3. 持久化设置
- 用户选择的语言会保存到 UserDefaults
- 下次启动时使用上次选择的语言
- 可以随时更改语言设置

## 本地化键值

### 应用信息
- `app_name`: 应用名称
- `app_description`: 应用描述
- `app_version`: 版本信息
- `app_about`: 关于信息

### 菜单项
- `menu_no_scholars`: 无学者数据
- `menu_manual_update`: 手动更新
- `menu_preferences`: 偏好设置
- `menu_about`: 关于
- `menu_quit`: 退出

### 设置窗口
- `settings_title`: 设置窗口标题
- `settings_scholar_management`: 学者管理
- `settings_app_settings`: 应用设置
- `setting_language`: 语言设置

### 错误消息
- `error_invalid_url`: 无效URL
- `error_no_data`: 无数据
- `error_parsing_error`: 解析错误
- `error_network_error`: 网络错误

## 添加新语言

### 1. 更新语言枚举
```swift
enum Language: String, CaseIterable {
    // 现有语言...
    case newLanguage = "xx"
    
    var displayName: String {
        switch self {
        // 现有语言...
        case .newLanguage: return "New Language"
        }
    }
}
```

### 2. 添加本地化字典
```swift
localizations[.newLanguage] = [
    "app_name": "CiteTrack",
    "menu_preferences": "Preferences...",
    // 添加所有必要的键值对...
]
```

### 3. 更新 Info.plist
```xml
<key>CFBundleLocalizations</key>
<array>
    <!-- 现有语言... -->
    <string>xx</string>
</array>
```

## 文件结构

```
Sources/
├── Localization.swift          # 本地化管理器
├── SettingsWindow.swift        # 设置窗口（支持语言切换）
└── main_localized.swift        # 主应用（多语言版本）

Scripts/
├── build_multilingual.sh       # 多语言版本构建脚本
└── create_multilingual_dmg.sh  # 多语言 DMG 创建脚本
```

## 构建和分发

### 构建多语言版本
```bash
./build_multilingual.sh
```

### 创建多语言 DMG
```bash
./create_multilingual_dmg.sh
```

### DMG 内容
- CiteTrack.app (多语言版本)
- 多语言安装指南
- 多语言安全绕过工具
- Applications 文件夹快捷方式
- 欢迎文档

## 测试建议

### 语言切换测试
1. 在不同系统语言下启动应用
2. 测试手动语言切换功能
3. 验证所有界面元素都已本地化
4. 检查错误消息的本地化

### 功能测试
1. 添加学者功能在各语言下正常工作
2. 设置保存和加载正确
3. 菜单栏显示正确的本地化文本
4. 对话框和警告信息正确显示

## 已知限制

1. **部分语言支持**: 西班牙语、法语、德语目前只有基础支持
2. **系统集成**: 某些系统对话框仍使用系统语言
3. **字体支持**: 某些语言可能需要特定字体支持

## 未来计划

1. **完善现有语言**: 补充西班牙语、法语、德语的完整翻译
2. **添加新语言**: 考虑添加意大利语、葡萄牙语、俄语等
3. **RTL 支持**: 为阿拉伯语、希伯来语等添加从右到左文本支持
4. **本地化资源**: 使用 .strings 文件替代硬编码字典

## 贡献指南

欢迎为 CiteTrack 贡献翻译：

1. Fork 项目仓库
2. 在 `Localization.swift` 中添加新语言支持
3. 测试所有功能在新语言下正常工作
4. 提交 Pull Request

---

**注意**: 本文档描述的是 CiteTrack v1.1.0 的多语言功能。功能可能在后续版本中有所变化。 