import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: horizontalSizeClass == .compact ? 15 : 25) {
            Spacer()
            
            TabBarButton(
                imageName: "pills",
                title: "Medications",
                isSelected: selectedTab == .medications,
                namespace: animation
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .medications
                }
            }
            .scaleEffect(1.5)
            
            Spacer()
            
            TabBarButton(
                imageName: "checklist.checked",
                title: "Log",
                isSelected: selectedTab == .log,
                namespace: animation
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .log
                }
            }
            .scaleEffect(1.5)
            
            Spacer()
            
            TabBarButton(
                imageName: "arrow.left.arrow.right",
                title: "Interactions",
                isSelected: selectedTab == .interactions,
                namespace: animation
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .interactions
                }
            }
            .scaleEffect(1.5)
            
            Spacer()
            
            TabBarButton(
                imageName: "gearshape",
                title: "Settings",
                isSelected: selectedTab == .settings,
                namespace: animation
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .settings
                }
            }
            .scaleEffect(1.5)
            
            Spacer()
        }
    }
}
