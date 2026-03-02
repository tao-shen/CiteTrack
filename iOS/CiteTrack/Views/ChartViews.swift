import SwiftUI

// MARK: - Citation Ranking Chart
struct CitationRankingChart: View {
    let scholars: [Scholar]
    @StateObject private var localizationManager = LocalizationManager.shared

    var sortedScholars: [Scholar] {
        scholars.sorted { ($0.citations ?? 0) > ($1.citations ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(localizationManager.localized("citation_ranking"))
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(Array(sortedScholars.enumerated()), id: \.element.id) { index, scholar in
                    ScholarRankingRowView(index: index, scholar: scholar)
                }
            }
        }
    }
}

// MARK: - Scholar Ranking Row
private struct ScholarRankingRowView: View {
    let index: Int
    let scholar: Scholar
    var body: some View {
        HStack {
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
            Text(scholar.displayName)
                .font(.body)
                .lineLimit(1)
            Spacer()
            Text("\(scholar.citationDisplay)")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Citation Distribution Chart
struct CitationDistributionChart: View {
    let scholars: [Scholar]
    @StateObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(localizationManager.localized("citation_distribution"))
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(scholars, id: \.id) { scholar in
                    if let citations = scholar.citations {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(scholar.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(citations)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 8)
                                        .cornerRadius(4)

                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: geometry.size.width * CGFloat(citations) / CGFloat(maxCitationCount), height: 8)
                                        .cornerRadius(4)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
    }

    private var maxCitationCount: Int {
        scholars.compactMap { $0.citations }.max() ?? 1
    }
}

// MARK: - Scholar Statistics Chart
struct ScholarStatisticsChart: View {
    let scholars: [Scholar]
    @StateObject private var localizationManager = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(localizationManager.localized("scholar_statistics"))
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                StatCard(title: localizationManager.localized("total_scholars"), value: "\(scholars.count)", icon: "person.2.fill", color: .blue)
                StatCard(title: localizationManager.localized("total_citations"), value: "\(totalCitations)", icon: "quote.bubble.fill", color: .green)
                StatCard(title: localizationManager.localized("average_citations"), value: "\(averageCitations)", icon: "chart.bar.fill", color: .orange)
                StatCard(title: localizationManager.localized("highest_citations"), value: "\(maxCitations)", icon: "star.fill", color: .red)
            }
        }
    }

    private var totalCitations: Int {
        scholars.reduce(0) { $0 + ($1.citations ?? 0) }
    }

    private var averageCitations: String {
        let avg = scholars.isEmpty ? 0 : totalCitations / scholars.count
        return "\(avg)"
    }

    private var maxCitations: Int {
        scholars.compactMap { $0.citations }.max() ?? 0
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
