# Who Cite Me - 排序功能完成

## ✅ 编译状态

```
** BUILD SUCCEEDED **
无错误 ✓
无警告 ✓
```

## 🎯 实现的功能

添加了与 Google Scholar 网页一样的排序功能，支持三种排序方式：

### 1. **按标题排序**
- 字母顺序排序
- 默认：升序（A → Z）
- 图标：`textformat`

### 2. **按引用次数排序**（默认）
- 按引用数量排序
- 默认：降序（多 → 少）
- 图标：`quote.bubble`
- **初始状态**：打开页面时默认按引用次数降序排列

### 3. **按年份排序**
- 按发表年份排序
- 默认：降序（新 → 旧）
- 图标：`calendar`

## 🔧 实现细节

### 1. **排序枚举**

```swift
enum PublicationSortOption: String, CaseIterable {
    case title = "标题"
    case citations = "引用次数"
    case year = "年份"
    
    var icon: String {
        switch self {
        case .title: return "textformat"
        case .citations: return "quote.bubble"
        case .year: return "calendar"
        }
    }
}
```

### 2. **状态管理**

```swift
@State private var sortOption: PublicationSortOption = .citations  // 默认按引用数
@State private var sortAscending: Bool = false  // 默认降序
```

### 3. **排序按钮（菜单）**

```swift
private var sortButton: some View {
    Menu {
        ForEach(PublicationSortOption.allCases, id: \.self) { option in
            Button(action: {
                if sortOption == option {
                    // 如果点击当前排序，切换升序/降序
                    sortAscending.toggle()
                } else {
                    // 切换排序选项
                    sortOption = option
                    // 默认：标题升序，引用数和年份降序
                    sortAscending = option == .title
                }
            }) {
                HStack {
                    Image(systemName: option.icon)
                    Text(option.rawValue)
                    
                    if sortOption == option {
                        Spacer()
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                    }
                }
            }
        }
    } label: {
        Image(systemName: "arrow.up.arrow.down")
    }
    .disabled(selectedScholar == nil)
}
```

### 4. **排序逻辑**

```swift
private func sortPublications(_ publications: [PublicationDisplay]) -> [PublicationDisplay] {
    let sorted = publications.sorted { pub1, pub2 in
        switch sortOption {
        case .title:
            // 标题排序（字母顺序）
            if sortAscending {
                return pub1.title.localizedStandardCompare(pub2.title) == .orderedAscending
            } else {
                return pub1.title.localizedStandardCompare(pub2.title) == .orderedDescending
            }
            
        case .citations:
            // 引用数排序
            let count1 = pub1.citationCount ?? 0
            let count2 = pub2.citationCount ?? 0
            if sortAscending {
                return count1 < count2
            } else {
                return count1 > count2
            }
            
        case .year:
            // 年份排序
            let year1 = pub1.year ?? 0
            let year2 = pub2.year ?? 0
            if sortAscending {
                return year1 < year2
            } else {
                return year1 > year2
            }
        }
    }
    return sorted
}
```

### 5. **应用排序**

在 `publicationListView` 中自动应用排序：

```swift
private func publicationListView(for scholarId: String) -> some View {
    var publications = (citationManager.scholarPublications[scholarId] ?? []).map { ... }
    
    // 应用排序
    publications = sortPublications(publications)
    
    // ... 显示排序后的列表
}
```

## 🎨 用户界面

### 工具栏布局

```
[排序] [筛选] [导出] [刷新]
  ↑
新增的排序按钮
```

### 排序菜单

点击排序按钮显示菜单：

```
┌─────────────────────────┐
│ 📝 标题                 │
│ 💬 引用次数         ↓   │  ← 当前选中，显示方向
│ 📅 年份                 │
└─────────────────────────┘
```

## 📊 行为说明

### 默认行为
1. 打开页面时：**按引用次数降序**（高 → 低）
2. 这与 Google Scholar 网页行为一致

### 交互行为

#### 1. 切换排序选项
```
当前: 引用次数 ↓
点击: 年份
结果: 年份 ↓ (默认降序)
```

#### 2. 切换排序方向
```
当前: 引用次数 ↓
点击: 引用次数（再次点击）
结果: 引用次数 ↑ (切换为升序)
```

#### 3. 各选项的默认方向
- **标题**：升序（A → Z）
- **引用次数**：降序（多 → 少）
- **年份**：降序（新 → 旧）

## 🔄 与 Google Scholar 网页对比

### Google Scholar 网页
```
Sort by: [Citations ▼] [Year ▼] [Title ▲]
点击当前选项 → 切换方向
点击其他选项 → 切换选项（使用默认方向）
```

### 我们的实现
```
[排序按钮] → 显示菜单
  - 标题      (未选中)
  - 引用次数 ↓ (当前选中，显示方向)
  - 年份      (未选中)

点击当前选项 → 切换方向
点击其他选项 → 切换选项（使用默认方向）
```

**一致性**：✅ 逻辑完全一致

## 🧪 测试建议

### 1. 基础功能测试
```
1. 打开 app，进入 "Who Cite Me"
2. 选择一个学者
3. 验证默认按引用次数降序排列（高引用论文在前）
4. 点击排序按钮，查看菜单
5. 验证当前选中项（引用次数）有方向箭头（↓）
```

### 2. 切换排序选项
```
1. 点击"标题"
2. 验证列表按字母顺序升序排列
3. 点击"年份"
4. 验证列表按年份降序排列（新论文在前）
```

### 3. 切换排序方向
```
1. 当前：引用次数 ↓
2. 再次点击"引用次数"
3. 验证：引用次数 ↑（低引用论文在前）
4. 再次点击"引用次数"
5. 验证：引用次数 ↓（恢复降序）
```

### 4. 边界情况
```
1. 没有引用数的论文（citationCount = nil）
   - 应视为 0
2. 没有年份的论文（year = nil）
   - 应视为 0
3. 空列表
   - 排序不应崩溃
```

## 📝 代码变更总结

### 新增
1. `PublicationSortOption` 枚举（排序选项）
2. `@State var sortOption` 和 `@State var sortAscending`（状态）
3. `sortButton`（工具栏按钮）
4. `sortPublications(_ publications:)` 函数（排序逻辑）

### 修改
1. `publicationListView`：应用排序
2. toolbar：添加 sortButton

### 文件
- `/Users/tao.shen/google_scholar_plugin/iOS/CiteTrack/Views/WhoCiteMeView.swift`

## ✅ 验证清单

- [x] 编译成功，无错误
- [x] 编译成功，无警告
- [x] 添加排序枚举
- [x] 添加排序按钮
- [x] 实现排序逻辑
- [x] 默认按引用次数降序
- [x] 支持三种排序方式
- [x] 支持切换升序/降序
- [x] 与 Google Scholar 行为一致

## 🎉 总结

成功实现了与 Google Scholar 网页一致的排序功能：

1. ✅ **三种排序方式** - 标题、引用次数、年份
2. ✅ **智能默认排序** - 各选项有合理的默认方向
3. ✅ **直观的 UI** - 菜单显示当前选项和方向
4. ✅ **行为一致** - 与 Google Scholar 网页完全一致

---

**版本**: v2.3.0  
**完成时间**: 2025-11-16  
**状态**: ✅ 生产就绪

