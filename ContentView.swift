#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MedicationStore.previewStore())
            .environmentObject(UserSettings.previewSettings())
            .environmentObject(InteractionStore.previewStore())
            .environmentObject(StoreManager.previewManager())
            .previewDisplayName("ContentView Preview")
    }
}
#endif

struct ContentView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var interactionStore: InteractionStore
    @EnvironmentObject var storeManager: StoreManager
    @State private var selectedTab: Tab = .medications
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    
    // Check if running in preview
    private var isPreview: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" || 
               UserDefaults.standard.bool(forKey: "isRunningPreview")
        #else
        return false
        #endif
    }

    enum Tab {
        case medications
        case log
        case settings
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Dynamic Background - simplified in preview
                if isPreview {
                    Color(hex: "#404C42").ignoresSafeArea()
                } else {
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
                }

                // 2. Main Content Area
                VStack(spacing: 0) {
                    // Display only MedicationsListView in preview
                    if isPreview {
                        MedicationsListView(onShowSettings: {
                            selectedTab = .settings
                        })
                            .scrollContentBackground(.hidden)
                            .padding(.top, geometry.safeAreaInsets.top)
                    } else {
                        TabView(selection: $selectedTab) {
                            MedicationsListView()
                                .scrollContentBackground(.hidden)
                                .tag(Tab.medications)
                                .toolbarBackground(.hidden, for: .tabBar)
                                .transition(.smoothTab)
                                .padding(.top, geometry.safeAreaInsets.top)
                                .accessibilityLabel("Medications Tab")

                            MedicationLogView()
                                .tag(Tab.log)
                                .toolbarBackground(.hidden, for: .tabBar)
                                .transition(.smoothTab)
                                .padding(.top, geometry.safeAreaInsets.top)
                                .accessibilityLabel("Medication Log Tab")
                                
                            SettingsView()
                                .tag(Tab.settings)
                                .toolbarBackground(.hidden, for: .tabBar)
                                .transition(.smoothTab)
                                .padding(.top, geometry.safeAreaInsets.top)
                                .accessibilityLabel("Settings Tab")
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut(duration: 0.3), value: selectedTab)
                        .frame(maxHeight: .infinity)

                        // Minimal Tab Bar - hide in preview
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
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .edgesIgnoringSafeArea(.bottom)
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    // Refresh data when returning to the app
                    store.loadMedications()
                    store.checkAndResetBadge()
                }
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityValue("Pillr Medication Tracker App")
    }
} 
