import SwiftUI
import UserNotifications

enum MainTab: String, Hashable, CaseIterable {
    case meds
    case history
    case checkIns
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
    @State private var showCloudSyncChoice = false
    @State private var showCloudSyncConfirmation = false
    @State private var pendingCloudSyncChoice: CloudSyncChoice?
    @State private var showNotificationOnboardingPrompt = false
    @State private var needsOnboardingAfterNotificationPrompt = false
    @State private var isRequestingNotificationAuthorization = false
    @State private var showingPremiumUpgrade = false
    
    private static let cloudSyncOnboardingKey = "cloudSyncChoice"
    private var isPremiumActive: Bool {
        storeManager.isPremiumPurchased() || OpenAIService.shared.isPremiumUser()
    }

    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .checkIns && !isPremiumActive {
                    showingPremiumUpgrade = true
                    return
                }
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
                
                DailyCheckInHistoryView()
                    .tabItem {
                        Image(systemName: "book.pages")
                            .accessibilityLabel("Check-Ins")
                    }
                    .tag(MainTab.checkIns)

                FocusTimelineView(isModal: false)
                    .tabItem {
                        Image(systemName: "hourglass")
                            .accessibilityLabel("Focus")
                    }
                    .tag(MainTab.focus)

                MedicationHistoryView()
                    .tabItem {
                        Image(systemName: "calendar")
                            .accessibilityLabel("History")
                    }
                    .tag(MainTab.history)
                
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
                if showCloudSyncChoice && !showCloudSyncConfirmation {
                    CloudSyncChoiceOverlay { choice in
                        handleCloudSyncSelection(choice)
                    }
                    .transition(.opacity)
                }
                if showCloudSyncConfirmation, let pending = pendingCloudSyncChoice {
                    CloudSyncChoiceConfirmationOverlay(
                        choice: pending,
                        onConfirm: confirmCloudSyncChoice,
                        onCancel: cancelCloudSyncChoice
                    )
                }
                if showNotificationOnboardingPrompt {
                    NotificationPermissionOnboardingPrompt(
                        onContinue: handleNotificationPromptContinue,
                        onSkip: handleNotificationPromptSkip
                    )
                    .transition(.opacity)
                    .zIndex(3)
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
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
                .environmentObject(StoreManager.shared)
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
        if tab == .meds && !userSettings.hasSeenOnboardingStage(Self.cloudSyncOnboardingKey) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showCloudSyncChoice = true
            }
            return
        }
        guard !userSettings.hasSeenOnboardingStage(key) else { return }
        guard let info = tab.onboardingInfo else { return }
        activeOnboardingTab = tab
        withAnimation(.easeInOut(duration: 0.2)) {
            activeOnboardingStage = info
        }
    }

    private func dismissOnboarding() {
        let dismissedTab = activeOnboardingTab
        if let tab = dismissedTab {
            userSettings.markOnboardingStageSeen(tab.rawValue)
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            activeOnboardingStage = nil
            activeOnboardingTab = nil
        }
    }


    private func handleCloudSyncSelection(_ choice: CloudSyncChoice) {
        pendingCloudSyncChoice = choice
        withAnimation(.easeInOut(duration: 0.2)) {
            showCloudSyncChoice = false
            showCloudSyncConfirmation = true
        }
    }

    private func confirmCloudSyncChoice() {
        guard let choice = pendingCloudSyncChoice else { return }
        let enableSync = choice == .connect
        userSettings.setCloudSyncPreference(enableSync)
        userSettings.markOnboardingStageSeen(Self.cloudSyncOnboardingKey)
        pendingCloudSyncChoice = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            showCloudSyncConfirmation = false
        }
        handleCloudSyncCompletion()
    }

    private func cancelCloudSyncChoice() {
        pendingCloudSyncChoice = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            showCloudSyncConfirmation = false
            showCloudSyncChoice = true
        }
    }

    private func handleCloudSyncCompletion() {
        guard !userSettings.hasSeenNotificationOnboardingPrompt else {
            DispatchQueue.main.async {
                scheduleOnboarding(for: selectedTab)
            }
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    needsOnboardingAfterNotificationPrompt = true
                    userSettings.markNotificationOnboardingPromptSeen()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showNotificationOnboardingPrompt = true
                    }
                } else {
                    scheduleOnboarding(for: selectedTab)
                }
            }
        }
    }

    private func handleNotificationPromptContinue() {
        guard !isRequestingNotificationAuthorization else { return }

        isRequestingNotificationAuthorization = true
        NotificationManager.shared.requestAuthorization { _ in
            DispatchQueue.main.async {
                self.isRequestingNotificationAuthorization = false
                self.finishNotificationPromptFlow()
            }
        }
    }

    private func handleNotificationPromptSkip() {
        finishNotificationPromptFlow()
    }

    private func finishNotificationPromptFlow() {
        guard needsOnboardingAfterNotificationPrompt else { return }
        needsOnboardingAfterNotificationPrompt = false
        withAnimation(.easeInOut(duration: 0.25)) {
            showNotificationOnboardingPrompt = false
        }
        isRequestingNotificationAuthorization = false
        DispatchQueue.main.async {
            scheduleOnboarding(for: selectedTab)
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

struct NotificationPermissionOnboardingPrompt: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    VStack(spacing: 24) {
                    VStack(alignment: .center, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.and.waves.left.and.right")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)

                            Text("Medication Reminders")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text("Next you will be asked to allow notifications so we can remind you to take medications that have reminders set.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                        VStack(spacing: 12) {
                            Button(action: onContinue) {
                                Text("Continue")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(hex: "#404C42"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.white)
                                            .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 4)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())

                            Button(action: onSkip) {
                                Text("Not now")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.85))
                            }
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: 460)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color(hex: "#2A2D28").opacity(0.98))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
                    .padding(.horizontal, 16)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 30)

                    Spacer()
                }
            }
        }
    }
}

private extension MainTab {
    var onboardingInfo: OnboardingStageInfo? {
        switch self {
        case .meds:
                return OnboardingStageInfo(
                    title: "My Meds",
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
        case .checkIns:
                return OnboardingStageInfo(
                    title: "Reflect",
                    description: AnyView(
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Capture a short daily note about how you are feeling.")
                                .multilineTextAlignment(.leading)
                            Text("Your check-ins stay tied to the medications you logged that day.")
                                .multilineTextAlignment(.leading)
                        }
                    ),
                    benefits: [

                    ],
                    icon: .system(name: "book.pages"),
                    accentColor: Color(hex: "#9FBBA5"),
                    buttonAccessibilityLabel: "Continue to Reflect"
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
