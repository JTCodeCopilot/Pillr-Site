import SwiftUI

enum MainTab: Hashable, CaseIterable {
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
    @AppStorage("hasCompletedOnboardingGuide") private var hasCompletedOnboardingGuide = false
    @State private var onboardingStep: OnboardingStep?
    @State private var highlightFrames: [OnboardingTarget: CGRect] = [:]

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
        GeometryReader { geometry in
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

            }
            .coordinateSpace(name: "onboarding")
            .onPreferenceChange(OnboardingHighlightPreferenceKey.self) { highlightFrames = $0 }
            .overlay {
                if let step = onboardingStep {
                    OnboardingGuideOverlay(
                        step: step,
                        geometry: geometry,
                        highlightFrame: highlightRect(for: step, geometry: geometry),
                        stepIndex: stepIndex(for: step),
                        totalSteps: OnboardingStep.allCases.count,
                        onNext: advanceOnboarding,
                        onSkip: skipOnboarding
                    )
                    .transition(.opacity)
                }
            }
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
        .onAppear {
            startOnboardingIfNeeded()
        }
        .onChange(of: onboardingStep) { newStep in
            handleOnboardingStepChange(newStep)
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

    private func startOnboardingIfNeeded() {
        guard !hasCompletedOnboardingGuide else { return }
        if onboardingStep == nil {
            onboardingStep = .addMedication
        }
    }

    private func advanceOnboarding() {
        guard let current = onboardingStep,
              let index = OnboardingStep.allCases.firstIndex(of: current) else {
            return
        }

        let nextIndex = index + 1
        if OnboardingStep.allCases.indices.contains(nextIndex) {
            onboardingStep = OnboardingStep.allCases[nextIndex]
        } else {
            completeOnboarding()
        }
    }

    private func skipOnboarding() {
        completeOnboarding()
    }

    private func completeOnboarding() {
        hasCompletedOnboardingGuide = true
        onboardingStep = nil
    }

    private func handleOnboardingStepChange(_ step: OnboardingStep?) {
        guard let step else { return }
        switch step {
        case .historyTab:
            selectedTab = .history
        case .focusTimeline:
            selectedTab = .focus
        default:
            if selectedTab != .meds {
                selectedTab = .meds
            }
        }
    }

    private func highlightRect(for step: OnboardingStep, geometry: GeometryProxy) -> CGRect? {
        guard step.target != .historyTab else { return nil }
        guard let rect = highlightFrames[step.target] else { return nil }
        return convertToLocal(rect, geometry: geometry)
    }

    private func convertToLocal(_ rect: CGRect, geometry: GeometryProxy) -> CGRect {
        let rootFrame = geometry.frame(in: .global)
        return CGRect(
            x: rect.origin.x - rootFrame.origin.x,
            y: rect.origin.y - rootFrame.origin.y,
            width: rect.width,
            height: rect.height
        )
    }

    private func stepIndex(for step: OnboardingStep) -> Int {
        (OnboardingStep.allCases.firstIndex(of: step) ?? 0) + 1
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
