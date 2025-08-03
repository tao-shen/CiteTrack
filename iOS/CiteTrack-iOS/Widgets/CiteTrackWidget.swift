import WidgetKit
import SwiftUI

// MARK: - Widget Provider
struct CiteTrackWidgetProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> CiteTrackWidgetEntry {
        CiteTrackWidgetEntry(
            date: Date(),
            scholars: [
                Scholar.mock(id: "placeholder1", name: "示例学者 A", citations: 1250),
                Scholar.mock(id: "placeholder2", name: "示例学者 B", citations: 850)
            ],
            totalCitations: 2100,
            configuration: CiteTrackWidgetConfiguration()
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CiteTrackWidgetEntry) -> ()) {
        let entry = placeholder(in: context)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CiteTrackWidgetEntry>) -> ()) {
        let settingsManager = SettingsManager.shared
        let scholars = settingsManager.getScholars()
        
        let currentDate = Date()
        let entry = CiteTrackWidgetEntry(
            date: currentDate,
            scholars: Array(scholars.prefix(3)), // 最多显示3个学者
            totalCitations: scholars.compactMap { $0.citations }.reduce(0, +),
            configuration: CiteTrackWidgetConfiguration()
        )
        
        // 设置下次更新时间（根据用户设置的更新间隔）
        let nextUpdate = Calendar.current.date(
            byAdding: .minute,
            value: Int(settingsManager.updateInterval / 60),
            to: currentDate
        ) ?? Date().addingTimeInterval(3600)
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Entry
struct CiteTrackWidgetEntry: TimelineEntry {
    let date: Date
    let scholars: [Scholar]
    let totalCitations: Int
    let configuration: CiteTrackWidgetConfiguration
}

// MARK: - Widget Configuration
struct CiteTrackWidgetConfiguration {
    let showTotalCitations: Bool
    let maxScholarsToShow: Int
    let theme: WidgetTheme
    
    init(
        showTotalCitations: Bool = true,
        maxScholarsToShow: Int = 3,
        theme: WidgetTheme = .system
    ) {
        self.showTotalCitations = showTotalCitations
        self.maxScholarsToShow = maxScholarsToShow
        self.theme = theme
    }
}

enum WidgetTheme {
    case light
    case dark
    case system
}

// MARK: - Widget Views

// Small Widget (2x2)
struct SmallCiteTrackWidgetView: View {
    let entry: CiteTrackWidgetEntry
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Image(systemName: "quote.bubble.fill")
                    .foregroundColor(.blue)
                Text("CiteTrack")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            Spacer()
            
            // Total Citations
            VStack(spacing: 2) {
                Text("\(entry.totalCitations)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("总引用数")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Last update
            Text("更新: \(entry.date.timeAgoString)")
                .font(.caption2)
                .foregroundColor(.tertiary)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// Medium Widget (4x2)
struct MediumCiteTrackWidgetView: View {
    let entry: CiteTrackWidgetEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side - Total stats
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundColor(.blue)
                    Text("CiteTrack")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.totalCitations)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("总引用数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(entry.scholars.count) 位学者")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Right side - Scholar list
            VStack(alignment: .leading, spacing: 4) {
                Text("学者列表")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                ForEach(Array(entry.scholars.prefix(3)), id: \.id) { scholar in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(scholar.id.hashColor))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text(scholar.name.initials())
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(scholar.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            Text(scholar.citationDisplay)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                if entry.scholars.count > 3 {
                    Text("还有 \(entry.scholars.count - 3) 位...")
                        .font(.caption2)
                        .foregroundColor(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// Large Widget (4x4)
struct LargeCiteTrackWidgetView: View {
    let entry: CiteTrackWidgetEntry
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundColor(.blue)
                    Text("CiteTrack")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                Text(entry.date.timeAgoString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Stats Row
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(entry.totalCitations)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("总引用数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(entry.scholars.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("学者数量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    let avgCitations = entry.scholars.isEmpty ? 0 : entry.totalCitations / entry.scholars.count
                    Text("\(avgCitations)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("平均引用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Scholar List
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("学者详情")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                ForEach(Array(entry.scholars.prefix(4)), id: \.id) { scholar in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(scholar.id.hashColor))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text(scholar.name.initials())
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scholar.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            HStack(spacing: 8) {
                                Text(scholar.citationDisplay)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                if let lastUpdated = scholar.lastUpdated {
                                    Text(lastUpdated.timeAgoString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.tertiary)
                    }
                }
                
                if entry.scholars.count > 4 {
                    Text("还有 \(entry.scholars.count - 4) 位学者...")
                        .font(.caption)
                        .foregroundColor(.tertiary)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Main Widget View
struct CiteTrackWidgetView: View {
    let entry: CiteTrackWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallCiteTrackWidgetView(entry: entry)
        case .systemMedium:
            MediumCiteTrackWidgetView(entry: entry)
        case .systemLarge:
            LargeCiteTrackWidgetView(entry: entry)
        @unknown default:
            SmallCiteTrackWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration
@main
struct CiteTrackWidget: Widget {
    let kind: String = "CiteTrackWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CiteTrackWidgetProvider()) { entry in
            CiteTrackWidgetView(entry: entry)
        }
        .configurationDisplayName("CiteTrack 引用追踪")
        .description("快速查看您关注的学者的最新引用数据")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Preview
struct CiteTrackWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEntry = CiteTrackWidgetEntry(
            date: Date(),
            scholars: [
                Scholar.mock(id: "abc123", name: "张三教授", citations: 1500),
                Scholar.mock(id: "def456", name: "李四博士", citations: 800),
                Scholar.mock(id: "ghi789", name: "王五研究员", citations: 2200)
            ],
            totalCitations: 4500,
            configuration: CiteTrackWidgetConfiguration()
        )
        
        Group {
            CiteTrackWidgetView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small Widget")
            
            CiteTrackWidgetView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium Widget")
            
            CiteTrackWidgetView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large Widget")
        }
    }
}