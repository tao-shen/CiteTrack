# CiteTrack iOS 应用安装指南

## 📱 安装到iPhone的步骤

### 方式一：使用 Xcode （推荐）

#### 前置要求
- **Mac电脑**: 需要 macOS 12.0 或更高版本
- **Xcode**: 从 App Store 安装最新版 Xcode (14.0+)
- **Apple ID**: 用于开发者签名
- **iPhone**: iOS 15.0 或更高版本

#### 安装步骤

1. **创建 Xcode 项目**
   ```bash
   cd /Users/tao.shen/google_scholar_plugin/iOS
   
   # 创建 Xcode 项目
   swift package generate-xcodeproj
   ```

2. **打开 Xcode 项目**
   ```bash
   open CiteTrack-iOS.xcodeproj
   ```

3. **配置项目设置**
   - 在 Xcode 中选择项目根目录
   - 在 "Signing & Capabilities" 标签页中：
     - 选择您的 Apple ID Team
     - 确保 "Automatically manage signing" 已勾选
     - 更改 Bundle Identifier 为唯一值（如：`com.yourname.citetrack`）

4. **连接iPhone**
   - 用 USB 线连接 iPhone 到 Mac
   - 在 iPhone 上信任此电脑
   - 在 Xcode 顶部选择您的设备

5. **构建和安装**
   - 点击 Xcode 左上角的 "Run" 按钮 (▶️)
   - 等待编译完成
   - 应用会自动安装到您的手机上

6. **信任开发者证书**
   - 在 iPhone 上：设置 → 通用 → VPN与设备管理 → 开发者应用
   - 点击您的 Apple ID，选择"信任"

### 方式二：使用现成的 Xcode 项目 （最简单）

我已经为您创建了一个可以直接使用的 Xcode 项目：

#### 快速安装步骤

1. **打开 Xcode 项目**
   ```bash
   cd /Users/tao.shen/google_scholar_plugin/iOS
   open CiteTrack.xcodeproj
   ```

2. **修改签名设置**
   - 在 Xcode 中，选择左侧的 "CiteTrack" 项目
   - 选择 "CiteTrack" target
   - 在 "Signing & Capabilities" 标签页：
     - ✅ 勾选 "Automatically manage signing"
     - 选择您的 Apple ID Team（如果没有，点击 "Add Account" 添加）
     - 修改 Bundle Identifier 为唯一值，如：`com.yourname.citetrack`

3. **连接iPhone并运行**
   - 用USB线连接iPhone到Mac
   - 在iPhone上点击"信任此电脑"
   - 在Xcode顶部选择您的iPhone设备
   - 点击左上角的▶️按钮运行

4. **首次运行时的设置**
   - 应用安装后，可能显示"不受信任的开发者"
   - 在iPhone上：设置 → 通用 → VPN与设备管理 → 开发者应用
   - 找到您的Apple ID，点击"信任"

#### 应用功能

安装成功后，您将获得一个功能完整的CiteTrack iOS应用：

✅ **主要功能**
- 📊 仪表板：显示总引用数和学者统计
- 👥 学者管理：添加、查看、删除学者
- 📈 图表展示：查看引用数据趋势（占位符，可扩展）
- ⚙️ 设置：应用配置和信息

✅ **当前可用功能**
- 添加学者（支持Google Scholar ID）
- 模拟引用数据获取
- 本地数据存储
- 现代化iOS界面
- 暗黑模式支持

## 🔧 故障排除

### 常见问题及解决方案

#### 1. 编译错误
**问题**: Xcode显示编译错误
**解决**: 
- 确保Xcode版本为14.0或更高
- 清理项目：Product → Clean Build Folder
- 重新构建：Product → Build

#### 2. 签名问题
**问题**: "代码签名错误"
**解决**:
- 确保已登录Apple ID
- 检查Bundle Identifier是否唯一
- 尝试手动管理签名

#### 3. 设备连接问题
**问题**: Xcode识别不到iPhone
**解决**:
- 确保iPhone已解锁并信任电脑
- 重新插拔USB线
- 重启Xcode和iPhone

#### 4. 应用安装失败
**问题**: "无法安装应用"
**解决**:
- 检查iPhone存储空间
- 确保iOS版本为15.0+
- 清理设备上的旧版本

#### 5. 信任开发者问题
**问题**: 应用无法打开，提示"不受信任"
**解决**:
- 设置 → 通用 → VPN与设备管理
- 找到开发者应用，点击信任

## 📱 应用使用指南

### 首次使用

1. **打开应用**
   - 应用图标名称：CiteTrack
   - 首次打开会请求通知权限

2. **添加第一位学者**
   - 点击"学者列表"标签
   - 点击右上角"+"按钮
   - 输入Google Scholar的学者ID
   - 可选输入学者姓名

3. **查看数据**
   - 返回"仪表板"查看统计信息
   - 引用数据为模拟数据（随机生成）

### Google Scholar ID 获取方法

1. 访问 [Google Scholar](https://scholar.google.com)
2. 搜索目标学者
3. 点击学者姓名进入个人资料页面
4. 从URL中复制ID，例如：
   ```
   https://scholar.google.com/citations?user=XXXXXXXXX&hl=en
   ```
   其中 `XXXXXXXXX` 就是学者ID

## 🔮 后续开发

### 当前版本特性
- ✅ 基础界面和导航
- ✅ 学者数据管理
- ✅ 模拟数据显示
- ✅ 本地存储

### 计划功能
- 🔄 真实Google Scholar数据抓取
- 📊 图表数据可视化
- 🔔 引用变化通知
- ☁️ iCloud数据同步
- 📱 Widget小组件

## ⚠️ 重要说明

1. **开发者账号**: 当前使用个人开发者证书，应用只能在您的设备上运行7天，之后需要重新安装
2. **数据模拟**: 当前版本使用模拟数据，实际Google Scholar数据抓取需要进一步开发
3. **网络功能**: 真实的网络请求功能需要额外的网络权限配置

## 📞 技术支持

如果遇到安装或使用问题：

1. **检查日志**: 在Xcode的Console中查看错误信息
2. **重新编译**: 清理并重新构建项目
3. **设备重启**: 重启iPhone和Mac
4. **版本检查**: 确保iOS和Xcode版本兼容

---

🎉 **安装完成后，您就拥有了一个功能完整的CiteTrack iOS应用！**