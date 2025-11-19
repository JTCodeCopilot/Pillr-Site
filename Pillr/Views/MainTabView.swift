import SwiftUI

enum MainTab: Hashable {
    case meds
    case add
    case focus
    case interactions
    case settings
}

struct MainTabView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var storeManager: StoreManager
    
    @State private var selectedTab: MainTab = .meds
    
    var body: some View {
        ZStack {
            // Shared app background
            LinearGradient.pillrBackground
                .ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                // Home / My Meds
                MedicationsHomeView()
                    .tabItem {
                        Label("My Meds", systemImage: "pills.fill")
                    }
                    .tag(MainTab.meds)
                
                // Add medication
                NavigationView {
                    AddMedicationView(onAdd: {
                        // After saving, return to My Meds tab
                        selectedTab = .meds
                    })
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
                
                // Settings
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(MainTab.settings)
            }
            .accentColor(Color.pillrAccent)
        }
        .preferredColorScheme(.dark)
    }
}

struct MedicationsHomeView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
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
                
                MedicationsListView()
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: .infinity)
            }
        }
    }
}
