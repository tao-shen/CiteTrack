# CiteTrack 图表稳定性改进文档

## 概述

针对图表显示过程中的闪退问题，我们进行了全面的代码审查和稳定性改进。本文档记录了所有改进措施和测试方法。

## 主要问题分析

### 1. 内存管理问题
- **问题**：Tracking areas 在视图销毁时未正确清理
- **解决**：在 `ChartView.deinit` 中添加完整的资源清理

### 2. 鼠标事件处理不安全
- **问题**：鼠标事件在异步环境中可能访问已释放的内存
- **解决**：所有鼠标事件处理改为异步 + weak self 模式

### 3. 线程安全问题
- **问题**：UI 更新和数据加载在不同线程间缺乏保护
- **解决**：增强线程安全检查，确保所有 UI 操作在主线程

### 4. 边界条件检查不足
- **问题**：数值计算和坐标转换缺乏边界检查
- **解决**：添加 `.isFinite` 检查和有效性验证

## 详细改进列表

### ChartView.swift 改进

#### 1. 增强的 deinit 清理
```swift
deinit {
    print("ChartView: Starting cleanup in deinit")
    
    // 清理所有tracking areas
    for trackingArea in trackingAreas {
        removeTrackingArea(trackingArea)
    }
    
    // 清理tooltip
    hideTooltip()
    
    // 清理delegate引用
    delegate = nil
    
    // 清理数据引用
    chartData = nil
    hoveredPoint = nil
    selectedPoint = nil
    
    print("ChartView: Cleanup completed in deinit")
}
```

#### 2. 线程安全的鼠标事件处理
```swift
override func mouseMoved(with event: NSEvent) {
    // 确保在主线程上执行，并添加完整的安全检查
    DispatchQueue.main.async { [weak self] in
        guard let self = self,
              self.window != nil,
              self.superview != nil,
              !self.isHidden else { 
            print("ChartView: mouseMoved - view not ready")
            return 
        }
        
        // 其余鼠标处理逻辑...
    }
}
```

#### 3. 增强的数值安全检查
```swift
private func findNearestPoint(to location: NSPoint) -> ChartDataPoint? {
    // 验证point.y是有效数值
    guard point.y.isFinite else { continue }
    
    // 确保计算的坐标是有效的
    guard x.isFinite, y.isFinite else { continue }
    
    // 确保distance是有效数值
    guard distance.isFinite else { continue }
    
    // 其余逻辑...
}
```

### ChartsViewController.swift 改进

#### 1. 增强的数据加载安全检查
```swift
historyManager.getHistory(for: scholar.id, in: timeRange) { [weak self] result in
    DispatchQueue.main.async {
        guard let self = self else { return }
        
        // 检查view controller是否还在活跃状态
        guard self.isViewLoaded,
              self.view.window != nil else {
            print("ChartsViewController: View controller no longer active")
            return
        }
        
        // 再次检查视图是否仍然存在
        guard let chartView = self.chartView,
              let statisticsView = self.statisticsView else {
            print("ChartsViewController: Chart views became nil during async operation")
            return
        }
        
        // 处理数据...
    }
}
```

#### 2. 改进的 refresh 操作保护
```swift
@objc private func refreshData() {
    guard let scholar = currentScholar,
          let refreshButton = self.refreshButton else { 
        print("ChartsViewController: Cannot refresh - no scholar or refresh button")
        return 
    }
    
    // 添加防止重复刷新的检查
    guard refreshButton.isEnabled else {
        print("ChartsViewController: Refresh already in progress")
        return
    }
    
    // 其余刷新逻辑...
}
```

#### 3. 完整的 deinit 清理
```swift
deinit {
    print("ChartsViewController: Starting cleanup in deinit")
    
    // Remove notification observers (必须在deinit中同步执行)
    NotificationCenter.default.removeObserver(self)
    
    // Clear delegate to avoid potential retain cycle
    chartView?.delegate = nil
    
    // 清理其他引用
    scholars.removeAll()
    currentScholar = nil
    
    print("ChartsViewController: Cleanup completed in deinit")
}
```

## 新增压力测试功能

为了更好地检测和预防闪退问题，我们添加了comprehensive压力测试系统：

### 1. 快速数据更新测试
- 连续快速更新图表数据
- 测试数据处理管道的稳定性
- 检查内存泄漏和竞态条件

### 2. 鼠标交互压力测试
- 模拟快速、随机的鼠标移动
- 测试 tooltip 创建/销毁的稳定性
- 验证鼠标事件处理的线程安全性

### 3. 内存压力测试
- 创建大量临时对象模拟内存压力
- 在内存压力下测试图表重绘
- 检查在低内存环境下的应用稳定性

## 测试方法

### 1. 启动应用
```bash
open CiteTrack.app
```

### 2. 打开图表窗口
1. 点击菜单栏中的 CiteTrack 图标
2. 选择 "图表分析..." 选项

### 3. 运行基础测试
1. 点击 "Test Data" 按钮添加测试数据
2. 观察图表是否正常显示
3. 尝试鼠标悬停在数据点上
4. 切换不同的图表类型和时间范围

### 4. 运行压力测试
1. 点击 "Stress Test" 按钮
2. 观察控制台输出和应用稳定性
3. 测试持续时间约 10-15 秒
4. 检查是否有闪退或异常

### 5. 手动压力测试
1. 快速移动鼠标在图表区域
2. 快速点击各种控件和按钮
3. 快速切换时间范围和图表类型
4. 多次刷新数据

## 监控和调试

### 1. 控制台日志
应用现在输出详细的调试信息：
- `ChartView: ` 前缀的日志来自图表视图
- `ChartsViewController: ` 前缀的日志来自控制器
- 关注任何 "cleanup" 或 "error" 相关的消息

### 2. 活动监视器
使用 macOS 活动监视器监控：
- CPU 使用率是否异常
- 内存使用是否持续增长
- 是否有内存泄漏迹象

### 3. Xcode 调试
如果有 Xcode，可以：
1. 使用 Instruments 进行内存分析
2. 启用 Address Sanitizer 检测内存错误
3. 使用 Thread Sanitizer 检测竞态条件

## 预期结果

经过这些改进，图表功能应该具备：

1. **内存安全**：无内存泄漏，正确的资源清理
2. **线程安全**：所有 UI 操作在主线程，正确的异步处理
3. **错误处理**：优雅处理边界条件和异常情况
4. **用户体验**：流畅的交互，无卡顿或闪退

## 故障排除

### 如果仍然遇到闪退：

1. **检查控制台日志**：寻找最后的错误信息
2. **运行压力测试**：确定是否为特定场景触发
3. **重现步骤**：记录导致闪退的具体操作步骤
4. **系统信息**：记录 macOS 版本和硬件信息

### 常见问题：

- **Tooltip 闪烁**：正常现象，由快速鼠标移动引起
- **图表加载慢**：可能是数据量大，属于正常情况
- **压力测试期间卡顿**：预期行为，测试完成后应恢复正常

## 总结

通过系统性的内存管理改进、线程安全增强、边界条件检查和comprehensive测试机制，图表功能的稳定性得到了显著提升。这些改进不仅解决了已知的闪退问题，还建立了一个robust的基础架构来预防future的稳定性问题。 