import SwiftUI

// MARK: - Citation Statistics View
struct CitationStatisticsView: View {
    let statistics: CitationStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            // 统计卡片
            HStack(spacing: 12) {
                CitationStatCard(
                    title: "total_citing_papers".localized,
                    value: "\(statistics.totalCitingPapers)",
                    icon: "doc.text.fill",
                    color: .blue
                )
                
                CitationStatCard(
                    title: "unique_authors".localized,
                    value: "\(statistics.uniqueCitingAuthors)",
                    icon: "person.2.fill",
                    color: .green
                )
            }
            
            // 年均引用数
            CitationStatCard(
                title: "average_per_year".localized,
                value: String(format: "%.1f", statistics.averageCitationsPerYear),
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
            
            // 年度趋势
            if !statistics.citationsByYear.isEmpty {
                yearTrendSection
            }
            
            // 最频繁引用作者
            if !statistics.topCitingAuthors.isEmpty {
                topAuthorsSection
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Year Trend Section
    
    private var yearTrendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("citations_by_year".localized)
                .font(.headline)
            
            // 简单的条形图
            ForEach(statistics.sortedCitationsByYear.suffix(5), id: \.year) { item in
                HStack {
                    Text(String(item.year))
                        .font(.caption)
                        .frame(width: 50, alignment: .leading)
                    
                    GeometryReader { geometry in
                        let maxCount = statistics.sortedCitationsByYear.map { $0.count }.max() ?? 1
                        let width = CGFloat(item.count) / CGFloat(maxCount) * geometry.size.width
                        
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: width, height: 20)
                            
                            Text("\(item.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 20)
                }
            }
        }
    }
    
    // MARK: - Top Authors Section
    
    private var topAuthorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("top_citing_authors".localized)
                .font(.headline)
            
            ForEach(statistics.topCitingAuthors.prefix(5)) { author in
                HStack {
                    Text(author.name)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(author.citingPaperCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Stat Card (Private to avoid conflicts)
private struct CitationStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Preview
struct CitationStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        CitationStatisticsView(statistics: CitationStatistics.mock())
            .padding()
    }
}
