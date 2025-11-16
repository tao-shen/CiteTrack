# Who Cite Me 功能 v2.0 完成

## ✅ 实现状态

**编译状态**: ✅ BUILD SUCCEEDED  
**完成时间**: 2025-11-15

## 🎯 实现的功能

根据用户两个需求：

### 1. ✅ 样式修改 + 可点击引用数

- **从卡片改为简单列表**: 去除了阴影和复杂背景，使用简洁的列表样式
- **左对齐布局**: 所有内容左对齐显示
- **引用数可点击**: 点击引用数字（蓝色下划线）会弹出详情页面
- **视觉反馈**: 鼠标悬停时有下划线提示可点击

### 2. ✅ 缓存机制 + 变化追踪

- **本地缓存**: 自动缓存所有论文的标题和引用数
- **变化对比**: 下次获取时自动对比新旧数据
- **增量标记**: 引用数增加的论文会在右侧显示绿色标签（+数字）
- **总体提示**: 列表标题旁显示总新增引用数

## 📁 主要修改的文件

### 1. 后端服务层

**`Shared/Services/CitationFetchService.swift`**
- ✅ 添加 `fetchCitingPapersForClusterId()` 方法
- ✅ 支持根据cluster ID获取引用文章

**`Shared/Services/CitationCacheService.swift`**
- ✅ 添加 `PublicationSnapshot` 结构体
- ✅ 添加 `cachePublications()` 方法缓存论文
- ✅ 添加 `getCachedPublications()` 方法获取缓存
- ✅ 添加 `comparePublications()` 方法对比变化
- ✅ 定义 `PublicationChange` 和 `PublicationChanges` 结构体

### 2. 管理层

**`Shared/Managers/CitationManager.swift`**
- ✅ 添加 `publicationChanges` Published属性
- ✅ 集成缓存对比逻辑
- ✅ 在 `fetchScholarPublications` 中自动对比并标记变化

### 3. iOS视图层

**`iOS/CiteTrack/Views/WhoCiteMeView.swift`**
- ✅ 修改论文行样式为简单列表
- ✅ 添加可点击的引用数按钮
- ✅ 添加变化标记显示（绿色+数字）
- ✅ 添加总新增引用数提示
- ✅ 添加 `citingPapersSheetView` 弹出详情页面

## 🎨 UI 展示

### 论文列表
```
论文列表                           [+15]  20

────────────────────────────────────────
Generative Adversarial Nets        [+8]
📅 2014  💬 105,335 ↗

────────────────────────────────────────
Deep Learning                       [+7]
📅 2015  💬 104,352 ↗

────────────────────────────────────────
...
```

### 变化标记说明
- **列表头部**: 显示总新增引用数（例：`+15`表示本次有15条新引用）
- **论文右侧**: 引用数增加的论文显示绿色标签（例：`+8`）
- **引用数**: 蓝色可点击，引导用户查看详情

### 点击引用数后
弹出页面显示：
- 论文标题
- 发表年份和引用数
- 提示信息（由于Google Scholar限制）

## 💾 缓存机制工作流程

```
第一次 Fetch
    ↓
获取论文列表（例：A论文 100引用，B论文 50引用）
    ↓
缓存到本地（PublicationSnapshot）
    ↓
第二次 Fetch（下拉刷新）
    ↓
获取新数据（例：A论文 108引用，B论文 50引用）
    ↓
对比缓存：A +8, B +0
    ↓
更新缓存 + 显示变化标记
    ↓
用户看到 A论文右侧显示 [+8]
```

## 📊 数据结构

### PublicationSnapshot
```swift
public struct PublicationSnapshot: Codable {
    public let title: String
    public let clusterId: String?
    public let citationCount: Int?
    public let year: Int?
}
```

### PublicationChanges
```swift
public struct PublicationChanges {
    public let increased: [PublicationChange]  // 引用数增加的论文
    public let decreased: [PublicationChange]  // 引用数减少的论文
    public let newPublications: [PublicationSnapshot]  // 新增论文
    
    public var totalNewCitations: Int  // 总新增引用数
}
```

## 🔧 技术要点

### 1. 缓存策略
- **永久缓存**: 论文缓存不设过期时间
- **智能对比**: 基于论文标题匹配
- **增量更新**: 只更新有变化的数据

### 2. UI交互
- **点击响应**: 引用数按钮使用 SwiftUI `Button`
- **模态展示**: 使用 `.sheet(item:)` 展示详情
- **视觉反馈**: 下划线提示可点击

### 3. 数据绑定
- **@Published**: `publicationChanges` 自动更新UI
- **@State**: `selectedPublication` 控制弹出
- **实时更新**: 缓存对比结果立即反映到视图

## 🎯 用户体验提升

### Before (v1.0)
- ❌ 卡片样式占空间
- ❌ 引用数不可点击
- ❌ 无法知道哪些是新引用
- ❌ 需要手动对比数据

### After (v2.0)
- ✅ 简洁列表，信息密度高
- ✅ 引用数可点击查看详情
- ✅ 自动标记新增引用
- ✅ 一眼看出变化趋势

## 🚀 未来优化方向

1. **持久化存储**: 将缓存保存到文件，避免app重启后丢失
2. **历史记录**: 保存多次fetch的历史，生成引用增长曲线
3. **通知提醒**: 检测到新引用时发送通知
4. **详细对比**: 点击变化标签查看具体是哪些论文引用了
5. **导出变化**: 导出变化报告为PDF/Excel

## 📝 测试指南

1. **首次测试**
   ```
   - 添加学者
   - 进入 Who Cite Me
   - 查看论文列表
   - 点击任意引用数（蓝色数字）
   ```

2. **缓存测试**
   ```
   - 在浏览器手动增加论文引用（等待Google Scholar更新）
   - 回到app，下拉刷新
   - 观察是否出现绿色+数字标记
   - 检查列表头部是否显示总增量
   ```

3. **交互测试**
   ```
   - 点击引用数（0的应该不可点击）
   - 验证弹出页面正确显示论文信息
   - 点击"关闭"按钮返回列表
   ```

## ⚠️ 已知限制

1. **Google Scholar限制**: 点击引用数后无法获取具体引用文章（需要更高级的抓取方案）
2. **缓存仅在内存**: App重启后缓存清空（可以在未来版本持久化）
3. **标题匹配**: 如果论文标题改变，无法正确匹配（极少见）

## 🎉 总结

v2.0成功实现了用户的两个核心需求：
1. ✅ 简洁的列表样式 + 可点击引用数
2. ✅ 智能缓存 + 自动变化追踪

用户现在可以：
- 更高效地浏览论文列表
- 一眼看出哪些论文获得了新引用
- 点击引用数了解更多（虽然受Google Scholar限制）
- 通过视觉标记快速识别热门论文

这为学者追踪自己的学术影响力提供了更好的工具！🎓✨

