import SwiftUI

struct DraggableBadge: View {
    let count: Int
    let onClear: () -> Void
    
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red)
                .frame(width: 20, height: 20)
            
            Text("\(count)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .offset(offset)
        .opacity(opacity)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    // Only allow dragging towards top-right
                    let translation = gesture.translation
                    offset = translation
                    
                    // Fade out as dragged further
                    let distance = sqrt(pow(translation.width, 2) + pow(translation.height, 2))
                    opacity = max(0.2, 1.0 - distance / 100.0)
                }
                .onEnded { gesture in
                    let translation = gesture.translation
                    // Threshold: Dragged at least 30pt right and 30pt up (negative height)
                    if translation.width > 30 && translation.height < -30 {
                        // Trigger clear
                        withAnimation(.easeOut(duration: 0.2)) {
                            offset = CGSize(width: 100, height: -100)
                            opacity = 0
                        }
                        
                        // Delay actual action slightly to allow animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onClear()
                            // Reset state (though view might disappear)
                            offset = .zero
                            opacity = 1.0
                        }
                    } else {
                        // Reset
                        withAnimation(.spring()) {
                            offset = .zero
                            opacity = 1.0
                        }
                    }
                }
        )
    }
}
