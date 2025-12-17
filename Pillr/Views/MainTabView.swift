import SwiftUI

enum MainTab: String, Hashable, CaseIterable {
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
    @State private var activeOnboardingStage: OnboardingStageInfo?
    @State private var activeOnboardingTab: MainTab?

    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if selectedTab == .meds && newValue != .meds && addFlowCoordinator.isShowing {
                    pendingTabSelection = newValue
                    showDiscardAlert = true
                } else {
                    applySelectedTab(newValue)
                }
            }
        )
    }

    var body: some View {
        ZStack {
            LinearGradient.pillrBackground
                .ignoresSafeArea()
            
            TabView(selection: tabSelection) {
                MedicationsHomeView(addFlowCoordinator: addFlowCoordinator)
                    .tabItem {
                        Image(systemName: "pill")
                            .symbolVariant(.none)
                            .accessibilityLabel("My Meds")
                    }
                    .tag(MainTab.meds)
                
                MedicationHistoryView()
                    .tabItem {
                        Image(systemName: "calendar")
                            .accessibilityLabel("History")
                    }
                    .tag(MainTab.history)
                
                FocusTimelineView(isModal: false)
                    .tabItem {
                        Image(systemName: "hourglass")
                            .accessibilityLabel("Focus")
                    }
                    .tag(MainTab.focus)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "ellipsis")
                            .accessibilityLabel("More")
                    }
                    .tag(MainTab.more)
            }
            .onChange(of: selectedTab) { _ in
                HapticManager.shared.strongImpact()
            }
            .accentColor(Color.pillrAccent)

            if let stage = activeOnboardingStage {
                OnboardingOverlayView(info: stage) {
                    dismissOnboarding()
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .alert("Discard medication?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                addFlowCoordinator.discardFlow()
                let target = pendingTabSelection ?? .meds
                pendingTabSelection = nil
                applySelectedTab(target)
            }
            Button("Keep editing", role: .cancel) {
                pendingTabSelection = nil
            }
        } message: {
            Text("Any progress you've made on this medication will be discarded.")
        }
        .onAppear {
            scheduleOnboarding(for: selectedTab)
        }
        .onChange(of: store.requestedMainTab) { requested in
            guard let requested else { return }
            applySelectedTab(requested)
            DispatchQueue.main.async {
                store.requestedMainTab = nil
            }
        }
        .preferredColorScheme(.dark)
    }

    private func applySelectedTab(_ tab: MainTab) {
        selectedTab = tab
        scheduleOnboarding(for: tab)
    }

    private func scheduleOnboarding(for tab: MainTab) {
        guard activeOnboardingStage == nil else { return }
        let key = tab.rawValue
        guard !userSettings.hasSeenOnboardingStage(key) else { return }
        guard let info = tab.onboardingInfo else { return }
        activeOnboardingTab = tab
        withAnimation(.easeInOut(duration: 0.2)) {
            activeOnboardingStage = info
        }
    }

    private func dismissOnboarding() {
        if let tab = activeOnboardingTab {
            userSettings.markOnboardingStageSeen(tab.rawValue)
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            activeOnboardingStage = nil
            activeOnboardingTab = nil
        }
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

private extension MainTab {
    var onboardingInfo: OnboardingStageInfo? {
        switch self {
        case .meds:
                return OnboardingStageInfo(
                    title: "Welcome to Pillr!",
                    description: AnyView(
                        VStack(alignment: .leading, spacing: 6) {
                            Text("This is your medication home base.")
                                .multilineTextAlignment(.leading)
                            Text("See your medications, track doses, and stay on schedule.")
                                .multilineTextAlignment(.leading)
                        }
                    ),
                    benefits: [
                     
                    ],
                    icon: .system(name: "pill.fill"),
                    accentColor: Color(hex: "#C8F365"),
                    buttonAccessibilityLabel: "Continue to My Meds",
                    subtitle: "We will walk you through the app as you go.",
                    buttonTitle: "Get Started"
                )
        case .history:
                return OnboardingStageInfo(
                    title: "Medication History",
                    description: AnyView(
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Here you can view all your logged medications.")
                                .multilineTextAlignment(.leading)
                            Text("Use filters to narrow the list, and export everything as a PDF or CSV using the top right export button.")
                                .multilineTextAlignment(.leading)
                        }
                    ),
                    benefits: [
               
                    ],
                    icon: .system(name: "calendar"),
                    accentColor: Color(hex: "#81C784"),
                    buttonAccessibilityLabel: "Continue to History"
                )
        case .focus:
                return OnboardingStageInfo(
                    title: "Focus Timeline",
                    description: AnyView(
                        VStack(spacing: 12) {
                            Text("Focus Timeline gives you a daily view of your ADHD stimulant medications.")
                            Text("Each scheduled or logged dose becomes a visual window that shows when focus starts, peaks, and fades based on the set times.")
                        }
                    ),
                    benefits: [
       
                    ],
                    icon: .system(name: "hourglass"),
                    accentColor: Color(hex: "#64B5F6"),
                    buttonAccessibilityLabel: "Continue to Focus Timeline"
                )
                case .more:
                        return OnboardingStageInfo(
                            title: "More",
                            description: AnyView(
                                Text("Manage your preferences, privacy, and premium features all in one place.")
                            ),
                            benefits: [
 
                            ],
                            icon: .system(name: "ellipsis"),
                            accentColor: Color(hex: "#FFB74D"),
                            buttonAccessibilityLabel: "Continue to Settings"
                        )
        }
    }
}
