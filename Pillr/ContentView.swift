//
//  ContentView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

// MARK: - Global Background Definition
extension Color {
    static let pillrNavy = Color(hex: "#000000")
    static let pillrSoftBlue = Color(hex: "#000000")
    static let pillrDeepBlue = Color(hex: "#000000")
}

extension LinearGradient {
    static let pillrBackground = LinearGradient(
        gradient: Gradient(colors: [Color.pillrSoftBlue, Color.pillrNavy, Color.pillrDeepBlue]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
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
        return Color(hex: "#D8B4F8") // Cyan-blue that works well in both light/dark modes
    }
    
    static var pillrSecondary: Color {
        return Color(hex: "#D8B4F8") // Light cyan for secondary elements
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
    @State private var selectedTab: Tab = .medications
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    enum Tab {
        case medications
        case log
        case interactions
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
                        .fill(Color.white.opacity(0.07))
                        .frame(width: geometry.size.width * 0.8)
                        .blur(radius: 35)
                        .offset(x: -geometry.size.width * 0.3, y: -geometry.size.height * 0.1)
                    
                    Circle()
                        .fill(Color(red: 0.35, green: 0.45, blue: 0.65).opacity(0.15))
                        .frame(width: geometry.size.width * 0.7)
                        .blur(radius: 30)
                        .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.2)
                        
                    Ellipse()
                        .fill(Color.pillrSoftBlue.opacity(0.12))
                        .frame(width: geometry.size.width * 0.6, height: geometry.size.height * 0.3)
                        .blur(radius: 40)
                        .offset(x: -geometry.size.width * 0.1, y: geometry.size.height * 0.35)
                }

                // 2. Main Content Area
                VStack(spacing: 0) {
                    // Custom Header with responsive sizing and semantic importance
                    Text(headerTitle)
                        .font(.system(size: adaptiveFontSize(for: geometry), weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 20)
                        .padding(.bottom, 10)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top).animation(.easeInOut(duration: 0.3))))
                        .id("header-\(selectedTab)")
                        .animation(.easeInOut(duration: 0.3), value: selectedTab)
                        .accessibilityAddTraits(.isHeader)

                    TabView(selection: $selectedTab) {
                        MedicationsListView()
                            .tag(Tab.medications)
                            .toolbarBackground(.hidden, for: .tabBar)
                            .transition(.smoothTab)

                        MedicationLogView()
                            .tag(Tab.log)
                            .toolbarBackground(.hidden, for: .tabBar)
                            .transition(.smoothTab)
                            
                        InteractionSearchView()
                            .tag(Tab.interactions)
                            .toolbarBackground(.hidden, for: .tabBar)
                            .transition(.smoothTab)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: selectedTab)
                    .frame(maxHeight: .infinity)

                    // Custom Tab Bar with dynamic padding
                    ZStack {
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
                    .background(Color.clear)
                    .ignoresSafeArea(.keyboard)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityValue("Pillr Medication Tracker App")
        .sheet(isPresented: Binding<Bool>(
            get: { selectedTab == .add },
            set: { if !$0 { selectedTab = .medications } }
        )) {
            AddMedicationView(onAdd: {
                // Switch back to medications list after adding
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = .medications
                }
            })
            .preferredColorScheme(.dark)
        }
    }
    
    // Title based on selected tab
    private var headerTitle: String {
        switch selectedTab {
        case .medications:
            return "My Medications"
        case .log:
            return "Medication Log"
        case .interactions:
            return "Drug Interactions"
        case .add:
            return "Add Medication" // This won't show as we use a sheet for adding
        }
    }
    
    // Responsive font sizing
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
    }
}
