# CiteTrack v2.0.0 编译和调试指南

## ✅ 已完成的修复

1. ✅ 移除了对不存在的 `CloudKitSyncService` 的依赖
2. ✅ 修复了所有警告（将 var 改为 let）
3. ✅ 源代码已经可以成功编译

## 方法 1: 使用命令行编译（推荐，已验证可用）

### 编译应用
```bash
cd /Users/tao.shen/google_scholar_plugin/macOS
bash scripts/build_charts.sh
```

### 运行应用
```bash
open CiteTrack.app
```

### 查看日志（用于调试）
```bash
# 在另一个终端窗口中
log stream --predicate 'process == "CiteTrack"' --level debug
```

## 方法 2: 在 Xcode 中调试

由于项目文件配置复杂，建议按以下步骤操作：

### 步骤 1: 使用命令行编译生成 .app
```bash
cd /Users/tao.shen/google_scholar_plugin/macOS
bash scripts/build_charts.sh
```

### 步骤 2: 在 Xcode 中附加调试器

1. 在 Xcode 中：`Debug` → `Attach to Process by PID or Name...`
2. 输入：`CiteTrack`
3. 点击 `Attach`
4. 运行应用：`open CiteTrack.app`

现在您可以在 Xcode 中设置断点并调试！

### 步骤 3: 查看编译输出
编译输出会显示：
- 应用大小
- 包含的功能
- 支持的语言

## 创建 DMG 分发包

```bash
cd /Users/tao.shen/google_scholar_plugin/macOS
bash scripts/create_v2.0.0_dmg.sh
```

## v2.0.0 新功能验证清单

运行应用后，验证以下功能：

- [ ] 📈 点击"图表"菜单项，打开图表窗口
- [ ] 📊 查看历史数据追踪（线图、柱状图、面积图）
- [ ] 🔔 接收引用变化通知
- [ ] 📤 导出数据（CSV/JSON格式）
- [ ] 💾 iCloud 同步（如果启用）
- [ ] 🌍 多语言支持测试
- [ ] 🔄 自动更新功能

## 编译成功的标志

您应该看到：
```
🎉 CiteTrack 图表功能版本构建完成！
📁 应用包: CiteTrack.app
📏 应用大小: ~4-5MB
⚙️  可执行文件: ~1-2MB
```

## 如果遇到问题

### 问题：无法打开应用
```bash
# 移除quarantine属性
xattr -cr CiteTrack.app
```

### 问题：Core Data 错误
```bash
# 清理旧数据
rm -rf ~/Library/Containers/com.citetrack.app/
```

### 问题：iCloud 不工作
1. 确保在 macOS 系统偏好设置中已登录 iCloud
2. 检查 entitlements 文件是否正确

## 调试技巧

### 添加调试输出
在源代码中添加：
```swift
print("🐛 [Debug] Your message here")
```

### 查看 Console 日志
打开 `/Applications/Utilities/Console.app`，搜索 "CiteTrack"

### 检查数据库
```bash
# 查找 SQLite 数据库
find ~/Library/Containers/com.citetrack.app -name "*.sqlite"

# 使用 sqlite3 检查
sqlite3 path/to/database.sqlite
.tables
.schema CitationHistoryEntity
SELECT * FROM CitationHistoryEntity LIMIT 10;
```

## 性能监控

使用 Instruments 进行性能分析：
```bash
# 时间分析
open -a Instruments CiteTrack.app

# 内存泄漏检测
open -a Instruments -W CiteTrack.app --template='Leaks'
```

## 已知限制

1. CloudKit 同步：当前版本使用 iCloud Drive 文件同步代替
2. 通知权限：首次运行时需要用户授权

## 版本信息

- 版本：2.0.0  
- 构建日期：2024-10-26
- 最低系统：macOS 11.0
- 架构：Apple Silicon (arm64)

## 下一步开发

如需继续开发，建议：
1. 使用命令行编译来验证代码
2. 使用 Xcode 的附加调试器功能进行调试
3. 所有源文件都在 `Sources/` 目录中

