import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Namespace private var animation
    
    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: horizontalSizeClass == .compact ? 30 : 45) {
                TabBarButton(
                    imageName: "pills.fill",
                    title: "Medications",
                    isSelected: selectedTab == .medications,
                    namespace: animation
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = .medications
                    }
                }
                
                TabBarButton(
                    imageName: "list.bullet.clipboard.fill",
                    title: "Log",
                    isSelected: selectedTab == .log,
                    namespace: animation
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = .log
                    }
                }
                
                TabBarButton(
                    imageName: "arrow.left.arrow.right.circle.fill",
                    title: "Interactions",
                    isSelected: selectedTab == .interactions,
                    namespace: animation
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = .interactions
                    }
                }
                
                TabBarButton(
                    imageName: "plus.circle.fill",
                    title: "Add",
                    isSelected: selectedTab == .add,
                    namespace: animation
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = .add
                    }
                }
            }
        }
    }
} 