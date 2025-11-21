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
                        Label("My Meds", systemImage: "pills.fill")
                    }
                    .tag(MainTab.meds)
                
                // Add medication
                NavigationView {
                    AddMedicationView(
                        onAdd: {
                            // After saving, return to My Meds tab
                            hasUnsavedAddFlow = false
                            selectedTab = .meds
                        },
                        onProgressStateChange: { hasUnsavedAddFlow = $0 }
                    )
                }
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(MainTab.add)
                
                // Focus timeline
                FocusTimelineView(isModal: false)
                    .tabItem {
                        Label("Focus", systemImage: "brain.head.profile")
                    }
                    .tag(MainTab.focus)
                
                // Interaction history
                InteractionHistoryView(isModal: false)
                    .tabItem {
                        Label("Interactions", systemImage: "checkmark.circle")
                    }
                    .tag(MainTab.interactions)
            }
            .accentColor(Color.pillrAccent)
        }
        .alert("Discard medication?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                hasUnsavedAddFlow = false
                selectedTab = pendingTabSelection ?? .meds
                pendingTabSelection = nil
            }
            Button("Keep editing", role: .cancel) {
                pendingTabSelection = nil
            }
        } message: {
            Text("Any progress you've made on this medication will be discarded.")
        }
        .preferredColorScheme(.dark)
    }
}

struct MedicationsHomeView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingSettings = false
    
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
                
                MedicationsListView(onShowSettings: { showingSettings = true })
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: .infinity)
            }
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}
