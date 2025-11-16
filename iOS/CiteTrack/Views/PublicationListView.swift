import SwiftUI

// MARK: - String Extension for iOS
private extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}

// MARK: - Scholar Publication Model (iOS-specific)
struct ScholarPublication: Identifiable {
    let id: String
    let title: String
    let clusterId: String?
    let citationCount: Int?
    let year: Int?
}

// MARK: - Publication List View
struct PublicationListView: View {
    let publications: [ScholarPublication]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Text("publications".localized)
                    .font(.headline)
                
                Spacer()
                
                Text("\(publications.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if isLoading {
                loadingView
            } else if publications.isEmpty {
                emptyView
            } else {
                publicationsList
            }
        }
    }
    
    // MARK: - Publications List
    
    private var publicationsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(publications) { pub in
                PublicationRow(publication: pub)
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
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("no_publications_found".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Publication Row
struct PublicationRow: View {
    let publication: ScholarPublication
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            Text(publication.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // 元数据
            HStack(spacing: 12) {
                if let year = publication.year {
                    Label(String(year), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let citationCount = publication.citationCount {
                    Label("\(citationCount)", systemImage: "quote.bubble")
                        .font(.caption)
                        .foregroundColor(citationCount > 0 ? .blue : .secondary)
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
struct PublicationListView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            PublicationListView(
                publications: [],
                isLoading: false
            )
            .padding()
        }
    }
}

