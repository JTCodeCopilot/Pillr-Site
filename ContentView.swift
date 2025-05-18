struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MedicationStore.shared)
            .environmentObject(UserSettings.shared)
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
                                Color(hex: "#404C42").opacity(0.95),
                                Color(hex: "#404C42")
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.2)),
                        alignment: .top
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
}

@main
struct PillrApp: App {
    @StateObject private var store = MedicationStore.shared
    @StateObject private var userSettings = UserSettings.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(userSettings)
                .preferredColorScheme(.dark)
        }
    }
} 