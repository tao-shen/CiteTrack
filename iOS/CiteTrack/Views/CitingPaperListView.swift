import SwiftUI

// MARK: - Citing Paper List View
struct CitingPaperListView: View {
    let scholarId: String
    let papers: [CitingPaper]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Text("citing_papers".localized)
                    .font(.headline)
                
                Spacer()
                
                Text("\(papers.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if isLoading {
                loadingView
            } else if papers.isEmpty {
                emptyView
            } else {
                papersList
            }
        }
    }
    
    // MARK: - Papers List
    
    private var papersList: some View {
        LazyVStack(spacing: 12) {
            ForEach(papers) { paper in
                NavigationLink(destination: CitingPaperDetailView(paper: paper)) {
                    CitingPaperRow(paper: paper)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("loading".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("no_citations_found".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Citing Paper Row
struct CitingPaperRow: View {
    let paper: CitingPaper
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            Text(paper.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // 作者
            Text(paper.authorsDisplay)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // 元数据
            HStack(spacing: 12) {
                if let year = paper.year {
                    Label(String(year), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let citationCount = paper.citationCount {
                    Label("\(citationCount)", systemImage: "quote.bubble")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let venue = paper.venue {
                    Text(venue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview
struct CitingPaperListView_Previews: PreviewProvider {
    static var previews: some View {
        let mockPapers = [
            CitingPaper.mock(id: "1", title: "Machine Learning in Healthcare", year: 2023),
            CitingPaper.mock(id: "2", title: "Deep Learning Applications", year: 2022),
            CitingPaper.mock(id: "3", title: "Neural Networks Research", year: 2024)
        ]
        
        CitingPaperListView(
            scholarId: "test",
            papers: mockPapers,
            isLoading: false
        )
        .padding()
    }
}
