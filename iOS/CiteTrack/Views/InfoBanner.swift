import SwiftUI

// MARK: - Info Banner
struct InfoBanner: View {
    let message: String
    let icon: String
    var color: Color = .blue
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview
struct InfoBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            InfoBanner(
                message: "This is an informational message",
                icon: "info.circle"
            )
            
            InfoBanner(
                message: "Warning message here",
                icon: "exclamationmark.triangle",
                color: .orange
            )
            
            InfoBanner(
                message: "Success message",
                icon: "checkmark.circle",
                color: .green
            )
        }
        .padding()
    }
}

