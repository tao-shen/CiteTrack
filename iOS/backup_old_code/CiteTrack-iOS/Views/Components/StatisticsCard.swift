import SwiftUI

struct StatisticsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct SyncStatusCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isAnimating: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title2)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CitationChangeRow: View {
    let change: CitationChange
    
    var body: some View {
        HStack(spacing: 12) {
            // 变化指示器
            Image(systemName: change.change >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(change.change >= 0 ? .green : .red)
                .font(.title3)
            
            // 学者信息
            VStack(alignment: .leading, spacing: 2) {
                Text(change.scholarName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(change.oldCount) → \(change.newCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 变化量和时间
            VStack(alignment: .trailing, spacing: 2) {
                Text(change.change >= 0 ? "+\(change.change)" : "\(change.change)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(change.change >= 0 ? .green : .red)
                
                Text(change.date.timeAgoString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct ScholarSummaryRow: View {
    let scholar: Scholar
    
    var body: some View {
        HStack(spacing: 12) {
            // 学者头像占位符
            Circle()
                .fill(Color(scholar.id.hashColor))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(scholar.name.initials())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                )
            
            // 学者信息
            VStack(alignment: .leading, spacing: 2) {
                Text(scholar.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(scholar.citationDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 更新状态
            VStack(alignment: .trailing, spacing: 2) {
                if let lastUpdated = scholar.lastUpdated {
                    Text(lastUpdated.timeAgoString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("never_updated".localized)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews
struct StatisticsCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            StatisticsCard(
                title: "总引用数",
                value: "12,345",
                icon: "quote.bubble.fill",
                color: .blue
            )
            
            SyncStatusCard(
                title: "同步中",
                subtitle: "正在同步数据...",
                icon: "icloud.and.arrow.up",
                isAnimating: true
            )
            
            EmptyStateView(
                icon: "chart.bar",
                title: "暂无数据",
                subtitle: "数据将在这里显示"
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}