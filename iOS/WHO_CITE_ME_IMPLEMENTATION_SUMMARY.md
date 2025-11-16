# Who Cite Me 功能实现总结

## 实现方案

根据用户需求，实现了以下功能：
**只显示论文列表和引用数量，不尝试获取具体的引用论文。**

## 主要改动

### 1. 后端服务层 (`CitationFetchService.swift`)
- 将 `ScholarPublication` 改为公开结构体
- 公开 `fetchScholarPublications` 方法，用于获取学者的论文列表

### 2. 管理层 (`CitationManager.swift`)
- 新增 `scholarPublications` 属性存储论文列表
- 新增 `PublicationInfo` 结构体用于在iOS视图中展示
- 实现 `fetchScholarPublications` 方法
- 实现 `updatePublicationStatistics` 方法用于计算聚合统计

### 3. 视图层

#### WhoCiteMeView (iOS)
- 显示论文列表
- 显示总引用数和年均引用数统计
- 添加说明横幅，告知用户功能限制

#### 新增视图组件
- `InfoBanner`: 信息提示横幅
- `PublicationListView`: 论文列表视图
- `ScholarPublication`: 论文数据模型（iOS专用）

## 数据流程

```
1. 用户打开 Who Cite Me 页面
   ↓
2. 调用 CitationManager.fetchScholarPublications()
   ↓
3. 调用 CitationFetchService.fetchScholarPublications()
   ↓
4. 从 Google Scholar 获取学者主页
   ↓
5. 解析HTML，提取论文信息（标题、年份、引用数、cluster ID）
   ↓
6. 转换为 PublicationInfo 结构
   ↓
7. 更新统计信息（总引用数、年均引用）
   ↓
8. 在视图中显示论文列表和统计
```

## 显示内容

###统计信息
- **总引用数**: 所有论文的引用数之和
- **年均引用数**: 根据论文年份计算的平均引用数

### 论文列表
每篇论文显示：
- 论文标题
- 发表年份
- 引用数量
- （可选）cluster ID

## 限制说明

由于 Google Scholar 的反爬虫机制，目前无法获取：
- 具体引用该论文的其他论文列表
- 引用作者信息
- 引用论文的详细信息

这个实现方案规避了这些限制，只显示从学者主页就能获取的信息。

## 测试建议

1. 添加一个学者（建议使用引用数较高的知名学者）
2. 进入 "Who Cite Me" 页面
3. 验证以下内容：
   - 信息横幅正确显示
   - 统计卡片显示总引用数和年均引用
   - 论文列表正确显示所有论文
   - 每篇论文显示标题、年份、引用数
   - 下拉刷新功能正常工作

## 未来改进方向

1. **缓存机制**: 缓存论文列表数据
2. **排序功能**: 按引用数/年份排序
3. **筛选功能**: 按年份范围筛选
4. **导出功能**: 导出论文列表为CSV/JSON
5. **图表可视化**: 显示引用数趋势图

