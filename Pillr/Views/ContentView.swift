//
//  ContentView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

// MARK: - Global Background Definition
extension Color {
    static let pillrNavy = Color.black
    static let pillrSoftBlue = Color.black
    static let pillrDeepBlue = Color.black
}

extension LinearGradient {
    static let pillrBackground = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: "#404C42"),  // Solid background color
        ]),
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}

// Alternative background accessor for direct color use
extension View {
    func pillrNavyBackground() -> some View {
        self.background(LinearGradient.pillrBackground)
    }
}

// MARK: - Color Extension for Theme Colors
extension Color {
    static var pillrAccent: Color {
        return Color(hex: "#C7C7BD") // New accent color
    }
    
    static var pillrSecondary: Color {
        return Color(hex: "#C7C7BD") // New secondary color
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Custom transition for tab view
extension AnyTransition {
    static var moveAndFade: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        )
    }
    
    static var smoothTab: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing).animation(.easeInOut(duration: 0.3))),
            removal: .opacity.combined(with: .move(edge: .leading).animation(.easeInOut(duration: 0.3)))
        )
    }
}

struct ContentView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @State private var selectedTab: Tab = .medications
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    enum Tab {
        case medications
        case log
        case interactions
        case settings
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Dynamic Background
                LinearGradient.pillrBackground
                    .ignoresSafeArea(edges: [.top, .leading, .trailing, .bottom])
                
                // Add subtle animated background shapes for depth
                ZStack {
                    // Single large solid background
                    Rectangle()
                        .fill(Color(hex: "#404C42"))
                        .ignoresSafeArea()
                    
                    // Top navbar area
                    Rectangle()
                        .fill(Color(hex: "#404C42"))
                        .frame(height: geometry.safeAreaInsets.top + 44)
                        .ignoresSafeArea(edges: .top)
                }

                // 2. Main Content Area
                VStack(spacing: 0) {
                    // Header removed
                    
                    TabView(selection: $selectedTab) {
                        MedicationsListView()
                            .scrollContentBackground(.hidden)
                            .tag(Tab.medications)
                            .toolbarBackground(.hidden, for: .tabBar)
                            .transition(.smoothTab)
                            .padding(.top, geometry.safeAreaInsets.top)

                        MedicationLogView()
                            .tag(Tab.log)
                            .toolbarBackground(.hidden, for: .tabBar)
                            .transition(.smoothTab)
                            .padding(.top, geometry.safeAreaInsets.top)
                            
                        InteractionSearchView()
                            .tag(Tab.interactions)
                            .toolbarBackground(.hidden, for: .tabBar)
                            .transition(.smoothTab)
                            .padding(.top, geometry.safeAreaInsets.top)
                            
                        SettingsView()
                            .tag(Tab.settings)
                            .toolbarBackground(.hidden, for: .tabBar)
                            .transition(.smoothTab)
                            .padding(.top, geometry.safeAreaInsets.top)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: selectedTab)
                    .frame(maxHeight: .infinity)

                    // Minimal Tab Bar
                    HStack {
                        CustomTabBar(selectedTab: $selectedTab)
                            .padding(.vertical, 5)
                            .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom - 0 : 5)
                    }
                    .frame(height: 40 + (geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom - 10 : 0))
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#404C42"),
                                Color(hex: "#404C42")
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea(.keyboard)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityValue("Pillr Medication Tracker App")
    }
    
    // Simplified - no longer need adaptive font size
    private func adaptiveFontSize(for geometry: GeometryProxy) -> CGFloat {
        let baseFontSize: CGFloat = 28
        let minFontSize: CGFloat = 24
        let maxFontSize: CGFloat = 34
        
        if horizontalSizeClass == .compact {
            return min(max(baseFontSize * (geometry.size.width / 390), minFontSize), maxFontSize)
        } else {
            return maxFontSize
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MedicationStore())
            .environmentObject(UserSettings.shared)
    }
}
