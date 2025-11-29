import SwiftUI

enum MainTab: Hashable {
    case meds
    case add
    case focus
    case interactions
}

struct MainTabView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var storeManager: StoreManager
    
    @State private var selectedTab: MainTab = .meds
    @State private var hasUnsavedAddFlow = false
    @State private var pendingTabSelection: MainTab?
    @State private var showDiscardAlert = false
    @State private var addFormResetToken = UUID()
    
    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if selectedTab == .add && newValue != .add && hasUnsavedAddFlow {
                    pendingTabSelection = newValue
                    showDiscardAlert = true
                } else {
                    selectedTab = newValue
                    pendingTabSelection = nil
                }
            }
        )
    }

    var body: some View {
        ZStack {
            // Shared app background
            LinearGradient.pillrBackground
                .ignoresSafeArea()
            
            TabView(selection: tabSelection) {
                // Home / My Meds
                MedicationsHomeView()
                    .tabItem {
                        Image(systemName: "pill")
                            .symbolVariant(.none) // Keep outline style even when selected
                            .accessibilityLabel("My Meds")
                    }
                    .tag(MainTab.meds)
                
                // Add medication
                NavigationView {
                    AddMedicationView(
                        onFinish: {
                            // After saving, return to My Meds tab
                            hasUnsavedAddFlow = false
                            selectedTab = .meds
                            // Ensure a fresh form next time
                            addFormResetToken = UUID()
                        },
                        onProgressStateChange: { hasUnsavedAddFlow = $0 },
                        resetTrigger: addFormResetToken
                    )
                }
                .tabItem {
                    Image(systemName: "plus.app")
                        .symbolVariant(.none) // Use unfilled variant
                        .accessibilityLabel("Add")
                }
                .tag(MainTab.add)
                
                // Focus timeline
                FocusTimelineView(isModal: false)
                    .tabItem {
                        Image(systemName: "hourglass")
                            .accessibilityLabel("Focus")
                    }
                    .tag(MainTab.focus)
                
                // Interaction history
                InteractionHistoryView(isModal: false)
                    .tabItem {
                        Image(systemName: "link")
                            .accessibilityLabel("Interactions")
                    }
                    .tag(MainTab.interactions)
            }
            .onChange(of: selectedTab) { _ in
                HapticManager.shared.strongImpact()
            }
            .accentColor(Color.pillrAccent)
        }
        .alert("Discard medication?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                hasUnsavedAddFlow = false
                // Force the AddMedicationView to reset its form the next time it's shown
                addFormResetToken = UUID()
                selectedTab = pendingTabSelection ?? .meds
                pendingTabSelection = nil
            }
            Button("Keep editing", role: .cancel) {
                pendingTabSelection = nil
            }
        } message: {
            Text("Any progress you've made on this medication will be discarded.")
        }
        .onChange(of: store.requestedMainTab) { requested in
            guard let requested else { return }
            selectedTab = requested
            DispatchQueue.main.async {
                store.requestedMainTab = nil
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct MedicationsHomeView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingSettings = false
    @State private var showingHistory = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Match the existing ContentView background
                LinearGradient.pillrBackground
                    .ignoresSafeArea(edges: [.top, .leading, .trailing, .bottom])
                
                Rectangle()
                    .fill(Color(hex: "#404C42"))
                    .ignoresSafeArea()
                
                Rectangle()
                    .fill(Color(hex: "#404C42"))
                    .frame(height: geometry.safeAreaInsets.top + 44)
                    .ignoresSafeArea(edges: .top)
                
                MedicationsListView(
                    onShowSettings: { showingSettings = true },
                    onShowHistory: { showingHistory = true }
                )
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: .infinity)
            }
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showingHistory) {
            MedicationHistoryView(isModal: true)
        }
    }
}
