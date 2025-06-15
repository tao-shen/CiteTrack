# CiteTrack v1.0.0 发布说明

## 🎉 首次发布

CiteTrack 是一个轻量级的 macOS 菜单栏应用，专为学术研究者设计，用于监控 Google Scholar 引用数量。

## ✨ 主要功能

### 📊 引用监控
- **实时数据**: 自动获取 Google Scholar 引用统计
- **多学者支持**: 同时监控多个学者的引用情况
- **菜单栏显示**: 在菜单栏直接显示当前引用数

### 🎨 个性化定制
- **自定义图标**: 为每个学者设置个性化 emoji 图标
- **主题适配**: 自动适配 macOS 深色/浅色主题
- **智能显示**: 根据学者数量智能选择显示方式

### 🔧 用户体验
- **首次设置向导**: 引导用户轻松添加第一个学者
- **简洁界面**: 直观的设置和管理界面
- **一键更新**: 手动刷新功能确保数据最新

## 📦 技术规格

- **应用大小**: 752KB
- **安装包大小**: 564KB (DMG)
- **系统要求**: macOS 10.15+
- **开发语言**: Swift
- **架构**: 原生 Apple Silicon 支持

## 🔐 安全性

- ✅ **开源透明**: 完整源代码公开
- ✅ **隐私保护**: 不收集任何个人信息
- ✅ **本地存储**: 所有数据存储在用户设备
- ✅ **代码签名**: 使用 ad-hoc 签名确保完整性

## 📥 安装方式

### 推荐方式
1. 下载 `CiteTrack_with_installer.dmg`
2. 打开 DMG 文件
3. 如遇安全警告，运行 `bypass_security_warning.sh`
4. 将 CiteTrack.app 拖拽到 Applications 文件夹

### 安全警告解决
应用使用 ad-hoc 签名，可能触发 macOS 安全警告。这是正常现象，不影响应用安全性。

**快速解决方法**:
- 运行提供的 `bypass_security_warning.sh` 脚本
- 或右键点击应用选择"打开"

## 🛠️ 开发者信息

### 构建环境
- **开发工具**: Xcode Command Line Tools
- **编译器**: Swift 5.0+
- **构建脚本**: `build_complete.sh`
- **打包脚本**: `create_user_friendly_dmg.sh`

### 项目结构
```
CiteTrack/
├── Sources/main.swift              # 主应用代码 (1800+ 行)
├── CiteTrack.app                   # 构建的应用程序
├── CiteTrack_with_installer.dmg    # 完整安装包
├── bypass_security_warning.sh     # 安全警告解决工具
├── build_complete.sh              # 自动化构建脚本
└── 用户安装指南.md                # 详细安装说明
```

## 📋 已知问题

### 安全警告
- **问题**: macOS 显示"无法验证开发者"警告
- **原因**: 未购买 Apple Developer Program ($99/年)
- **解决**: 使用提供的绕过脚本或手动操作
- **影响**: 不影响应用功能和安全性

### Google Scholar 限制
- **问题**: 频繁请求可能被暂时限制
- **解决**: 应用内置智能延迟机制
- **建议**: 避免过于频繁的手动刷新

## 🔄 更新计划

### v1.1.0 (计划中)
- [ ] 引用趋势图表
- [ ] 导出数据功能
- [ ] 更多自定义选项
- [ ] 通知提醒功能

### 长期规划
- [ ] Apple 官方公证 (考虑用户反馈)
- [ ] 更多学术平台支持
- [ ] 团队协作功能

## 🤝 贡献

欢迎社区贡献！
- **Bug 报告**: 提交 GitHub Issue
- **功能建议**: 通过 Issue 讨论
- **代码贡献**: 提交 Pull Request

## 📞 支持

- **GitHub**: https://github.com/tao-shen/CiteTrack
- **Issues**: https://github.com/tao-shen/CiteTrack/issues
- **文档**: 查看仓库中的详细指南

## 📄 许可证

本项目采用 MIT 许可证，允许自由使用、修改和分发。

---

**感谢使用 CiteTrack！让学术引用监控变得简单高效！** 🎓📊 