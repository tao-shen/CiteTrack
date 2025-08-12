import SwiftUI
import WidgetKit

// MARK: - Shared Models (decoding from App Group storage)
private struct WidgetScholarInfo: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var citations: Int?
    var lastUpdated: Date?

    var displayName: String { name.isEmpty ? "学者 \(id.prefix(8))" : name }
    var citationDisplay: String { "\(citations ?? 0)" }
}

// 与 App 内 DataManager.CitationHistory 对应的轻量模型
private struct WidgetCitationHistory: Codable, Identifiable, Equatable {
    let id: UUID
    let scholarId: String
    let citationCount: Int
    let timestamp: Date
}

private enum SharedKeys {
    static let scholarsKey = "ScholarsList"
    static let historyKey = "CitationHistoryData"
}

private func loadScholarsFromSharedDefaults() -> [WidgetScholarInfo] {
    guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
          let data = defaults.data(forKey: SharedKeys.scholarsKey),
          let decoded = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) else {
        return []
    }
    return decoded
}

private func loadHistoryFromSharedDefaults() -> [WidgetCitationHistory] {
    guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
          let data = defaults.data(forKey: SharedKeys.historyKey),
          let decoded = try? JSONDecoder().decode([WidgetCitationHistory].self, from: data) else {
        return []
    }
    return decoded
}

// MARK: - Chart Helpers
private struct WidgetChartPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let value: Int
}

private func recentChartPoints(for scholarId: String, days: Int = 30) -> [WidgetChartPoint] {
    let all = loadHistoryFromSharedDefaults().filter { $0.scholarId == scholarId }
    guard !all.isEmpty else { return [] }

    let end = Date()
    let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
    let filtered = all.filter { $0.timestamp >= start && $0.timestamp <= end }
        .sorted { $0.timestamp < $1.timestamp }

    // 取每天最新一条
    var latestPerDay: [Date: WidgetCitationHistory] = [:]
    for h in filtered {
        let day = Calendar.current.startOfDay(for: h.timestamp)
        if let existing = latestPerDay[day] {
            if h.timestamp > existing.timestamp { latestPerDay[day] = h }
        } else {
            latestPerDay[day] = h
        }
    }

    let points = latestPerDay.keys.sorted().compactMap { day -> WidgetChartPoint? in
        guard let h = latestPerDay[day] else { return nil }
        return WidgetChartPoint(date: h.timestamp, value: h.citationCount)
    }
    return points
}

private struct SparklineView: View {
    let points: [WidgetChartPoint]
    let lineColor: Color

    init(points: [WidgetChartPoint], lineColor: Color = .blue) {
        self.points = points
        self.lineColor = lineColor
    }

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let height = max(geo.size.height, 1)

            let values = points.map { $0.value }
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let range = max(maxValue - minValue, 1)

            ZStack {
                Path { path in
                    let rows = 3
                    for i in 0...rows {
                        let y = CGFloat(i) * height / CGFloat(rows)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)

                Path { path in
                    guard points.count > 1 else { return }
                    for (idx, p) in points.enumerated() {
                        let x = CGFloat(idx) * (width / CGFloat(points.count - 1))
                        let yNorm = CGFloat(p.value - minValue) / CGFloat(range)
                        let y = height - yNorm * height
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineJoin: .round, lineCap: .round))
            }
        }
    }
}

// MARK: - Timeline
struct CiteTrackWidgetEntry: TimelineEntry {
    let date: Date
    let scholars: [WidgetScholarInfo]
    let totalCitations: Int
    let primaryScholar: WidgetScholarInfo?
    let trendPoints: [WidgetChartPoint]
}

struct CiteTrackWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CiteTrackWidgetEntry {
        let sample = [
            WidgetScholarInfo(id: "a", name: "示例学者A", citations: 1200, lastUpdated: Date()),
            WidgetScholarInfo(id: "b", name: "示例学者B", citations: 800, lastUpdated: Date())
        ]
        let sampleTrend = (0..<14).map { i in
            WidgetChartPoint(date: Date().addingTimeInterval(Double(-i) * 86400), value: 800 + i * 10)
        }.reversed()
        return CiteTrackWidgetEntry(date: Date(), scholars: sample, totalCitations: 2000, primaryScholar: sample.first, trendPoints: Array(sampleTrend))
    }

    func getSnapshot(in context: Context, completion: @escaping (CiteTrackWidgetEntry) -> Void) {
        let scholars = loadScholarsFromSharedDefaults()
        let total = scholars.compactMap { $0.citations }.reduce(0, +)
        let primary = scholars.max(by: { ($0.citations ?? 0) < ($1.citations ?? 0) })
        let trend = primary.map { recentChartPoints(for: $0.id, days: 14) } ?? []
        completion(CiteTrackWidgetEntry(date: Date(), scholars: Array(scholars.prefix(4)), totalCitations: total, primaryScholar: primary, trendPoints: trend))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CiteTrackWidgetEntry>) -> Void) {
        let scholars = loadScholarsFromSharedDefaults()
        let total = scholars.compactMap { $0.citations }.reduce(0, +)
        let primary = scholars.max(by: { ($0.citations ?? 0) < ($1.citations ?? 0) })
        let trend = primary.map { recentChartPoints(for: $0.id, days: 30) } ?? []

        let entry = CiteTrackWidgetEntry(date: Date(), scholars: Array(scholars.prefix(4)), totalCitations: total, primaryScholar: primary, trendPoints: trend)

        // 每日刷新：次日 03:00 本地时间
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 0) + 1
        comps.hour = 3
        comps.minute = 0
        comps.second = 0
        let next = Calendar.current.date(from: comps) ?? Date().addingTimeInterval(24 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views
struct SmallCiteTrackWidgetView: View {
    let entry: CiteTrackWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "quote.bubble.fill").foregroundColor(.blue)
                Text("CiteTrack").font(.caption).fontWeight(.medium)
            }
            if let primary = entry.primaryScholar, !entry.trendPoints.isEmpty {
                Text(primary.displayName).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                Text(primary.citationDisplay)
                    .font(.title2).fontWeight(.bold)
                SparklineView(points: entry.trendPoints)
                    .frame(height: 28)
            } else {
                Text("\(entry.totalCitations)")
                    .font(.title2).fontWeight(.bold)
                Text("总引用数").font(.caption).foregroundColor(.secondary)
            }
            Spacer(minLength: 2)
            Text("更新: \(relative(entry.date))")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding()
    }
}

struct MediumCiteTrackWidgetView: View {
    let entry: CiteTrackWidgetEntry
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "quote.bubble.fill").foregroundColor(.blue)
                    Text("CiteTrack").font(.subheadline).fontWeight(.medium)
                }
                if let primary = entry.primaryScholar {
                    Text(primary.displayName).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    Text(primary.citationDisplay).font(.title).fontWeight(.bold)
                } else {
                    Text("\(entry.totalCitations)").font(.title).fontWeight(.bold)
                    Text("总引用数").font(.caption).foregroundColor(.secondary)
                }
                Text("\(entry.scholars.count) 位学者").font(.caption).foregroundColor(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                if !entry.trendPoints.isEmpty {
                    Text("近30天趋势").font(.caption).foregroundColor(.secondary)
                    SparklineView(points: entry.trendPoints)
                        .frame(height: 60)
                }
                Text("学者列表").font(.caption2).foregroundColor(.secondary)
                ForEach(entry.scholars.prefix(3)) { s in
                    HStack {
                        Text(s.displayName).font(.caption).lineLimit(1)
                        Spacer()
                        Text(s.citationDisplay).font(.caption2).foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
    }
}

struct LargeCiteTrackWidgetView: View {
    let entry: CiteTrackWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "quote.bubble.fill").foregroundColor(.blue)
                Text("CiteTrack").font(.headline).fontWeight(.semibold)
                Spacer()
                Text(relative(entry.date)).font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 16) {
                statBlock(value: entry.totalCitations, label: "总引用数", color: .blue)
                statBlock(value: entry.scholars.count, label: "学者数量", color: .green)
                let avg = entry.scholars.isEmpty ? 0 : entry.totalCitations / entry.scholars.count
                statBlock(value: avg, label: "平均引用", color: .orange)
            }
            Divider()
            if let primary = entry.primaryScholar, !entry.trendPoints.isEmpty {
                Text("\(primary.displayName) 的近30天趋势").font(.subheadline).fontWeight(.medium)
                SparklineView(points: entry.trendPoints)
                    .frame(height: 90)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("学者详情").font(.subheadline).fontWeight(.medium)
                ForEach(entry.scholars.prefix(4)) { s in
                    HStack {
                        Text(s.displayName).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text(s.citationDisplay).font(.caption).foregroundColor(.blue)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    private func statBlock(value: Int, label: String, color: Color) -> some View {
        VStack { Text("\(value)").font(.title3).fontWeight(.bold).foregroundColor(color)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }
}

private func relative(_ date: Date) -> String {
    let interval = Date().timeIntervalSince(date)
    if interval < 60 { return "刚刚" }
    if interval < 3600 { return "\(Int(interval/60)) 分钟前" }
    if interval < 86400 { return "\(Int(interval/3600)) 小时前" }
    return "\(Int(interval/86400)) 天前"
}

// MARK: - Root
@main
struct CiteTrackWidget: Widget {
    let kind: String = "CiteTrackWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CiteTrackWidgetProvider()) { entry in
            switchFamily(entry: entry)
        }
        .configurationDisplayName("CiteTrack 引用追踪")
        .description("快速查看您关注的学者的最新引用与趋势")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

extension CiteTrackWidget {
    @ViewBuilder
    fileprivate func switchFamily(entry: CiteTrackWidgetEntry) -> some View {
        GeometryReader { _ in
            switch WidgetFamily.current {
            case .systemSmall: SmallCiteTrackWidgetView(entry: entry)
            case .systemMedium: MediumCiteTrackWidgetView(entry: entry)
            case .systemLarge: LargeCiteTrackWidgetView(entry: entry)
            default: SmallCiteTrackWidgetView(entry: entry)
            }
        }
    }
}


