# Who Cite Me 功能限制说明

## 问题现状

iOS应用中的"Who Cite Me"功能目前无法正常工作，这是由于**Google Scholar的反爬虫机制**导致的，而不是代码错误。

### 技术细节

我们已经成功实现了：
- ✅ 从学者主页提取论文列表
- ✅ 提取每篇论文的cluster ID  
- ✅ 构建正确的引用查询URL
- ✅ 发送HTTP请求

**但是**，Google Scholar检测到这是自动化请求后，返回一个只包含CSS/JavaScript的空页面（75KB），没有实际的论文数据。

### 为什么会这样？

Google Scholar的反爬虫机制会检测：
1. **缺少JavaScript执行环境**
2. **不是真实浏览器**
3. **缺少cookies和session**
4. **请求模式不自然**

即使我们设置了正确的User-Agent和请求头，Google Scholar仍然可以通过其他特征识别自动化请求。

## 解决方案

### 方案A：使用WebView（最可靠）

**描述**：使用`WKWebView`加载Google Scholar页面，模拟真实浏览器。

**优点**：
- 最接近真实浏览器行为
- 可以执行JavaScript
- 成功率高

**缺点**：
- 需要重构大量代码
- 占用更多内存
- 速度较慢（每个页面需要完全加载）
- 用户可能看到加载的网页

**工作量**：约2-3天开发时间

### 方案B：使用替代API（推荐）

**描述**：使用其他学术数据库的官方API。

#### Semantic Scholar API
- **官方API**：https://api.semanticscholar.org/
- **免费配额**：100请求/5分钟
- **数据质量**：非常好
- **覆盖范围**：广泛

示例API：
```
GET https://api.semanticscholar.org/graph/v1/paper/{paperId}/citations
```

#### CrossRef API  
- **官方API**：https://api.crossref.org/
- **免费**：无限制（礼貌使用）
- **数据质量**：好
- **覆盖范围**：主要是已发表的论文

**优点**：
- 合法且稳定
- 有官方支持
- 不会被封禁
- 数据结构化

**缺点**：
- 需要学习新API
- 覆盖范围可能不如Google Scholar全面
- 需要API密钥注册

**工作量**：约1-2天开发时间

### 方案C：仅显示统计数据

**描述**：从学者主页获取论文的引用数量，但不尝试获取具体的引用论文列表。

**可以显示**：
- 总引用数（从学者主页）
- 每篇论文的引用数
- h-index
- 引用趋势图

**无法显示**：
- 具体是谁引用了
- 引用论文的详细信息

**优点**：
- 立即可用
- 不受Google Scholar限制
- 简单可靠

**缺点**：
- 功能受限
- 用户体验打折扣

**工作量**：约半天开发时间

### 方案D：macOS专属功能

**描述**：将"Who Cite Me"功能标记为macOS专属，iOS上暂时禁用或显示说明。

macOS版本可能因为不同的网络环境或用户行为模式，可以绕过某些限制。

**优点**：
- 无需修改iOS代码
- 用户理解功能差异

**缺点**：
- iOS功能不完整

**工作量**：1小时

## 推荐方案

### 短期（立即）
**方案D + 方案C 组合**：
1. 在iOS上显示友好的说明消息
2. 显示基本统计数据（从学者主页获取）

### 中期（1-2周）
**方案B - 集成Semantic Scholar API**：
1. 注册Semantic Scholar API
2. 实现API调用逻辑
3. 替换Google Scholar数据源

### 长期（可选）
**方案A - WebView方案**：
作为备选方案，如果其他API无法满足需求

## 代码修改建议

### 立即修改（显示友好提示）

在`WhoCiteMeView.swift`中添加说明：

```swift
if citingPapers.isEmpty && !citationManager.isLoading {
    VStack(spacing: 20) {
        Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 60))
            .foregroundColor(.orange)
        
        Text("功能暂时受限")
            .font(.headline)
        
        Text("由于Google Scholar的访问限制，暂时无法获取引用详情。\n\n我们正在开发替代解决方案。")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding()
        
        Button("了解更多") {
            // 打开说明链接
        }
    }
}
```

## 为什么macOS版本可能可以工作？

1. **桌面User-Agent更常见**
2. **用户可能有Google账号登录**
3. **网络环境不同**
4. **请求频率更低**（单用户使用）

## 法律和道德考虑

Google Scholar的服务条款禁止自动化访问。使用官方API或替代数据源是合法且道德的解决方案。

## 下一步行动

请选择以下之一：

1. **✅ 推荐**：实施短期方案（显示说明）+ 开发Semantic Scholar集成
2. **⚡ 快速**：仅显示说明，暂时禁用功能
3. **🔧 技术**：尝试WebView方案（需要更多时间）

## 参考资源

- Semantic Scholar API: https://api.semanticscholar.org/
- CrossRef API: https://github.com/CrossRef/rest-api-doc
- OpenCitations: https://opencitations.net/
- Google Scholar TOS: https://scholar.google.com/intl/en/scholar/terms.html

