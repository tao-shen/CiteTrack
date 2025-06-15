# CiteTrack 📊

一个轻量级的 macOS 菜单栏应用，用于监控 Google Scholar 学术引用数量。

![CiteTrack](https://img.shields.io/badge/platform-macOS-blue)
![Swift](https://img.shields.io/badge/language-Swift-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ 功能特点

- 🔄 **实时监控**: 自动获取 Google Scholar 引用数据
- 👥 **多学者支持**: 同时监控多个学者的引用情况
- 🎨 **自定义图标**: 为每个学者设置个性化 emoji 图标
- 🌙 **主题适配**: 自动适配系统深色/浅色主题
- ⚡ **轻量级**: 应用大小仅 752KB
- 🔒 **隐私保护**: 所有数据本地存储，不收集个人信息

## 📥 下载安装

### 快速安装
1. 下载 [CiteTrack_with_installer.dmg](CiteTrack_with_installer.dmg)
2. 打开 DMG 文件
3. 如遇安全警告，运行 `bypass_security_warning.sh` 脚本
4. 将 CiteTrack.app 拖拽到 Applications 文件夹

### 安全警告解决
如果看到 "Apple could not verify CiteTrack is free of malware" 错误：

**方法 1 - 自动脚本（推荐）**
```bash
./bypass_security_warning.sh
```

**方法 2 - 手动操作**
- 右键点击 CiteTrack.app → 选择"打开" → 点击"打开"
- 或运行：`xattr -dr com.apple.quarantine CiteTrack.app`

详细说明请查看 [用户安装指南](用户安装指南.md)

## 🚀 使用方法

1. **首次启动**: 应用会引导您添加第一个学者
2. **添加学者**: 输入 Google Scholar 个人页面 URL
3. **自定义图标**: 为每个学者选择 emoji 图标
4. **查看数据**: 点击菜单栏图标查看引用统计
5. **管理设置**: 通过菜单访问设置界面

## 🛠️ 开发构建

### 环境要求
- macOS 10.15+
- Xcode Command Line Tools
- Swift 5.0+

### 构建步骤
```bash
# 克隆仓库
git clone https://github.com/tao-shen/CiteTrack.git
cd CiteTrack

# 构建应用
./build_complete.sh

# 创建 DMG
./create_user_friendly_dmg.sh
```

## 📁 项目结构

```
CiteTrack/
├── Sources/
│   └── main.swift              # 主应用代码
├── CiteTrack.app               # 构建的应用程序
├── CiteTrack_with_installer.dmg # 完整安装包
├── bypass_security_warning.sh  # 安全警告解决脚本
├── build_complete.sh           # 构建脚本
├── create_user_friendly_dmg.sh # DMG 创建脚本
├── 用户安装指南.md             # 用户安装指南
└── README.md                   # 项目说明
```

## 🔐 安全性说明

CiteTrack 是完全安全的开源应用：
- ✅ **开源透明**: 所有代码公开可查看
- ✅ **无恶意行为**: 仅访问 Google Scholar 公开数据
- ✅ **本地存储**: 数据存储在用户设备上
- ✅ **无数据收集**: 不收集任何个人信息
- ✅ **代码签名**: 使用 ad-hoc 签名，符合 macOS 安全要求

安全警告出现是因为应用未通过 Apple 付费公证服务（$99/年），这不影响应用的安全性和功能。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 📞 支持

如有问题或建议，请：
- 提交 [GitHub Issue](https://github.com/tao-shen/CiteTrack/issues)
- 查看 [用户安装指南](用户安装指南.md)
- 查看 [Apple公证解决方案总结](Apple公证解决方案总结.md)

---

*让学术引用监控变得简单高效！* 🎓 