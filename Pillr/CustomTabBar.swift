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
            
            Spacer()
            
            TabBarButton(
                imageName: "list.bullet",
                title: "Log",
                isSelected: selectedTab == .log,
                namespace: animation
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .log
                }
            }
            
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
            
            Spacer()
        }
    }
} 