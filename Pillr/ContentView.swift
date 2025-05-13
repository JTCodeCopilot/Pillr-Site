//
//  ContentView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

// MARK: - Global Background Definition
extension Color {
    static let pillrNavy = Color(red: 0.08, green: 0.14, blue: 0.28)
}

extension LinearGradient {
    static let pillrBackground = LinearGradient(
        gradient: Gradient(colors: [Color.pillrNavy]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// Alternative background accessor for direct color use
extension View {
    func pillrNavyBackground() -> some View {
        self.background(Color.pillrNavy)
    }
}

struct ContentView: View {
    @EnvironmentObject var store: MedicationStore
    @State private var selectedTab: Tab = .medications
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    enum Tab {
        case medications
        case log
        case add
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Dynamic Background
                LinearGradient.pillrBackground
                    .ignoresSafeArea()
                
                // Add subtle animated background shapes for depth
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: geometry.size.width * 0.8)
                        .blur(radius: 30)
                        .offset(x: -geometry.size.width * 0.3, y: -geometry.size.height * 0.1)
                    
                    Circle()
                        .fill(Color(red: 0.25, green: 0.35, blue: 0.55).opacity(0.1))
                        .frame(width: geometry.size.width * 0.7)
                        .blur(radius: 25)
                        .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.2)
                }

                // 2. Main Content Area
                VStack(spacing: 0) {
                    // Custom Header with responsive sizing
                    Text(headerTitle)
                        .font(.system(size: adaptiveFontSize(for: geometry)))
                        .bold()
                        .foregroundColor(.white)
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 20)
                        .padding(.bottom, 10)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    TabView(selection: $selectedTab) {
                        MedicationsListView()
                            .tag(Tab.medications)
                            .toolbarBackground(.hidden, for: .tabBar)

                        MedicationLogView()
                            .tag(Tab.log)
                            .toolbarBackground(.hidden, for: .tabBar)

                        AddMedicationView(onAdd: {
                            // Switch back to medications list after adding
                            selectedTab = .medications
                        })
                        .tag(Tab.add)
                        .toolbarBackground(.hidden, for: .tabBar)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxHeight: .infinity)

                    // Custom Tab Bar with dynamic padding
                    CustomTabBar(selectedTab: $selectedTab)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom - 10 : 10)
                        .gyroGlassCardStyle(
                            cornerRadius: 25, 
                            material: .thinMaterial, 
                            borderColor: .white.opacity(0.3),
                            borderWidth: 1.2,
                            shadowOpacity: 0.2,
                            shadowRadius: 10,
                            shineOpacity: 0.7
                        )
                        .padding(.horizontal)
                        .frame(height: 70 + (geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom - 10 : 0))
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // Adaptive font sizing based on screen width
    private func adaptiveFontSize(for geometry: GeometryProxy) -> CGFloat {
        let baseSize: CGFloat = 28
        
        if geometry.size.width < 375 {
            return baseSize * 0.8 // Smaller iPhones
        } else if geometry.size.width >= 834 {
            return baseSize * 1.2 // iPads
        } else {
            return baseSize
        }
    }

    var headerTitle: String {
        switch selectedTab {
        case .medications:
            return "Take"
        case .log:
            return "Taken"
        case .add:
            return "Add New Medication"
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MedicationStore())
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        HStack {
            TabBarButton(iconName: "list.bullet.clipboard.fill", title: "Meds", tab: .medications, selectedTab: $selectedTab)
            Spacer()
            TabBarButton(iconName: "pills.fill", title: "Log", tab: .log, selectedTab: $selectedTab)
            Spacer()
            TabBarButton(iconName: "plus.circle.fill", title: "Add", tab: .add, selectedTab: $selectedTab)
        }
        .padding(.vertical, horizontalSizeClass == .regular ? 12 : 10)
    }
}

struct TabBarButton: View {
    let iconName: String
    let title: String
    let tab: ContentView.Tab
    @Binding var selectedTab: ContentView.Tab
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Button(action: {
            withAnimation {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: iconSize, weight: selectedTab == tab ? .bold : .regular))
                Text(title)
                    .font(horizontalSizeClass == .regular ? .body : .caption)
            }
            .foregroundColor(selectedTab == tab ? .cyan : .white.opacity(0.7))
            .padding(.horizontal)
            .background(
                selectedTab == tab ? 
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .blur(radius: 0.5)
                        .padding(-5) : nil
            )
            .overlay(
                selectedTab == tab ?
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .padding(-5) : nil
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title) tab")
            .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
        }
    }
    
    // Dynamic icon sizing
    private var iconSize: CGFloat {
        horizontalSizeClass == .regular ? 26 : 22
    }
}
