import SwiftUI

// MARK: - Citing Paper Detail View
struct CitingPaperDetailView: View {
    let paper: CitingPaper
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题
                titleSection
                
                // 作者
                authorsSection
                
                // 发表信息
                publicationInfoSection
                
                // 摘要
                if let abstract = paper.abstract {
                    abstractSection(abstract)
                }
                
                // 操作按钮
                actionButtons
            }
            .padding()
        }
        .navigationTitle("paper_details".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("title".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text(paper.title)
                .font(.title3)
                .fontWeight(.bold)
        }
    }
    
    // MARK: - Authors Section
    
    private var authorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("authors".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(paper.authors, id: \.self) { author in
                    Text(author)
                        .font(.body)
                }
            }
        }
    }
    
    // MARK: - Publication Info Section
    
    private var publicationInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let year = paper.year {
                infoRow(label: "year".localized, value: String(year))
            }
            
            if let venue = paper.venue {
                infoRow(label: "venue".localized, value: venue)
            }
            
            if let citationCount = paper.citationCount {
                infoRow(label: "citations".localized, value: String(citationCount))
            }
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.body)
        }
    }
    
    // MARK: - Abstract Section
    
    private func abstractSection(_ abstract: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("abstract".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text(abstract)
                .font(.body)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if paper.hasScholarUrl, let urlString = paper.scholarUrl, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "link")
                        Text("view_on_scholar".localized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            
            if paper.hasPDF, let urlString = paper.pdfUrl, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text("download_pdf".localized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
    }
}

// MARK: - Preview
struct CitingPaperDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CitingPaperDetailView(paper: CitingPaper.mock())
        }
    }
}
