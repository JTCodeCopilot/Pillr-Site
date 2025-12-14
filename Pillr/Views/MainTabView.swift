import SwiftUI

enum MainTab: Hashable {
    case meds
    case history
    case focus
    case more
}

struct MainTabView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var storeManager: StoreManager
    
    @State private var selectedTab: MainTab = .meds
    @StateObject private var addFlowCoordinator = AddMedicationFlowCoordinator()
    @State private var pendingTabSelection: MainTab?
    @State private var showDiscardAlert = false

    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if selectedTab == .meds && newValue != .meds && addFlowCoordinator.isShowing {
                    pendingTabSelection = newValue
                    showDiscardAlert = true
                } else {
                    selectedTab = newValue
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
                MedicationsHomeView(addFlowCoordinator: addFlowCoordinator)
                    .tabItem {
                        Image(systemName: "pill")
                            .symbolVariant(.none)
                        Text("My Meds")
                    }
                    .tag(MainTab.meds)
                
                // Medication history
                MedicationHistoryView()
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("History")
                    }
                    .tag(MainTab.history)
                
                // Focus timeline
                FocusTimelineView(isModal: false)
                    .tabItem {
                        Image(systemName: "hourglass")
                        Text("Focus")
                    }
                    .tag(MainTab.focus)
                
                // Settings / More
                SettingsView()
                    .tabItem {
                        Image(systemName: "ellipsis")
                        Text("More")
                    }
                    .tag(MainTab.more)
            }
            .onChange(of: selectedTab) { _ in
                HapticManager.shared.strongImpact()
            }
            .accentColor(Color.pillrAccent)
        }
        .alert("Discard medication?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                addFlowCoordinator.discardFlow()
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
    let addFlowCoordinator: AddMedicationFlowCoordinator
    
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
                
                MedicationsListView(addFlowCoordinator: addFlowCoordinator)
                    .scrollContentBackground(.hidden)
                    .frame(maxHeight: .infinity)
            }
        }
    }
}
