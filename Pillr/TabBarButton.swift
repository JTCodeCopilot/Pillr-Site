import SwiftUI

struct TabBarButton: View {
    let imageName: String
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: imageName)
                    .font(.system(size: iconSize, weight: isSelected ? .bold : .regular))
                    .imageScale(.medium)
                Text(title)
                    .font(.caption)
                
                if isSelected {
                    Color.pillrAccent
                        .frame(height: 3)
                        .clipShape(Capsule())
                        .matchedGeometryEffect(id: "tab_indicator", in: namespace)
                        .padding(.horizontal, 8)
                } else {
                    Color.clear
                        .frame(height: 3)
                        .padding(.horizontal, 8)
                }
            }
            .foregroundColor(isSelected ? Color.pillrAccent : .white.opacity(0.7))
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.3), value: isSelected)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) tab")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        }
    }
    
    // Dynamic icon sizing
    private var iconSize: CGFloat {
        22
    }
} 