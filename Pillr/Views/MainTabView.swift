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
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var selectedTab: MainTab = .meds
    @StateObject private var addFlowCoordinator = AddMedicationFlowCoordinator()
    @State private var pendingTabSelection: MainTab?
    @State private var showDiscardAlert = false
    @State private var activeOnboardingStage: OnboardingStageInfo?
    @State private var activeOnboardingTab: MainTab?
    @State private var showCloudSyncChoice = false
    @State private var showNotificationOnboardingPrompt = false
    @State private var needsOnboardingAfterNotificationPrompt = false
    @State private var isRequestingNotificationAuthorization = false
    @State private var showReviewPrompt = false
    @State private var referenceDate = Date()
    @State private var suppressTabSelectionUntil = Date.distantPast
    @AppStorage("reviewPromptFirstLaunchTimeInterval") private var reviewPromptFirstLaunchTimeInterval: Double = 0
    @AppStorage("reviewPromptHasShown") private var reviewPromptHasShown = false
    @AppStorage("reviewPromptLastDismissedTimeInterval") private var reviewPromptLastDismissedTimeInterval: Double = 0
    @AppStorage("reviewPromptSeeded") private var reviewPromptSeeded = false
    @AppStorage("appLaunchCount") private var appLaunchCount: Int = 0
    private var isUITestMode: Bool { UserSettings.isUITestMode }
    
    private static let cloudSyncOnboardingKey = "cloudSyncChoice"
    private static let reviewPromptURL = "https://apps.apple.com/us/app/pillr-adhd-medication-tracker/id6746717689?action=write-review"
    private static let reviewPromptDelaySeconds: TimeInterval = 1.2
    private static let reviewPromptMinimumDays: Double = 3
    private static let reviewPromptSnoozeDays: Double = 30
    private let badgeRefreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                guard !isTabSelectionTemporarilySuppressed else { return }
                if selectedTab == .meds && newValue != .meds && addFlowCoordinator.isShowing {
                    pendingTabSelection = newValue
                    showDiscardAlert = true
                } else {
                    applySelectedTab(newValue)
                }
            }
        )
    }
    
    private var overdueBadgeCount: Int {
        max(0, store.overdueReminderCount(referenceDate: referenceDate))
    }

    private var modalOverlayTransition: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }

    private var modalOverlayAnimation: Animation {
        .spring(response: 0.42, dampingFraction: 0.86)
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
                    .badge(overdueBadgeCount)
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
            .onChange(of: selectedTab) { _, _ in
                HapticManager.shared.strongImpact()
            }
            .accentColor(Color.pillrAccent)
            .onReceive(badgeRefreshTimer) { output in
                guard scenePhase == .active else { return }
                referenceDate = output
                store.refreshOverdueMedicationIDs(referenceDate: output)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard shouldSuppressTabSelection(for: value) else { return }
                        suppressTabSelectionUntil = Date().addingTimeInterval(0.35)
                    }
            )

                if let stage = activeOnboardingStage {
                    OnboardingOverlayView(info: stage) {
                        dismissOnboarding()
                    }
                    .transition(modalOverlayTransition)
                    .zIndex(1)
                }
                if showCloudSyncChoice {
                    CloudSyncChoiceOverlay { choice in
                        handleCloudSyncSelection(choice)
                    }
                    .transition(modalOverlayTransition)
                    .zIndex(4)
                }
                if showNotificationOnboardingPrompt {
                    NotificationPermissionOnboardingPrompt(
                        onContinue: handleNotificationPromptContinue,
                        onSkip: handleNotificationPromptSkip
                    )
                    .transition(modalOverlayTransition)
                    .zIndex(3)
                }
                if showReviewPrompt {
                    ReviewPromptSheet(
                        onDismiss: dismissReviewPrompt,
                        onLeaveReview: openReviewLink
                    )
                    .transition(modalOverlayTransition)
                    .zIndex(2)
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
            scheduleReviewPromptIfNeeded()
            store.refreshOverdueMedicationIDs(referenceDate: referenceDate)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            referenceDate = Date()
            store.refreshOverdueMedicationIDs(referenceDate: referenceDate)
        }
        .onChange(of: store.requestedMainTab) { _, requested in
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

    private var isTabSelectionTemporarilySuppressed: Bool {
        Date() < suppressTabSelectionUntil
    }

    private func shouldSuppressTabSelection(for value: DragGesture.Value) -> Bool {
        let startNearBottom = value.startLocation.y > (UIScreen.main.bounds.height - 120)
        guard startNearBottom else { return false }

        let verticalTravel = -value.translation.height
        let horizontalTravel = abs(value.translation.width)
        return verticalTravel > 20 && verticalTravel > (horizontalTravel * 1.2)
    }

    private func scheduleOnboarding(for tab: MainTab) {
        guard !isUITestMode else { return }
        guard activeOnboardingStage == nil else { return }
        let key = tab.rawValue
        if tab == .meds && !userSettings.hasSeenOnboardingStage(Self.cloudSyncOnboardingKey) {
            withAnimation(modalOverlayAnimation) {
                showCloudSyncChoice = true
            }
            return
        }
        guard !userSettings.hasSeenOnboardingStage(key) else { return }
        guard let info = tab.onboardingInfo else { return }
        activeOnboardingTab = tab
        withAnimation(modalOverlayAnimation) {
            activeOnboardingStage = info
        }
    }

    private func scheduleReviewPromptIfNeeded() {
        guard !isUITestMode else { return }
        guard !reviewPromptHasShown else { return }
        seedReviewPromptBaselineIfNeeded()

        let now = Date()
        if reviewPromptFirstLaunchTimeInterval == 0 {
            reviewPromptFirstLaunchTimeInterval = now.timeIntervalSince1970
        }

        let firstLaunchDate = Date(timeIntervalSince1970: reviewPromptFirstLaunchTimeInterval)
        let minimumShowDate = Calendar.current.date(byAdding: .day, value: Int(Self.reviewPromptMinimumDays), to: firstLaunchDate) ?? now
        let lastDismissedDate = reviewPromptLastDismissedTimeInterval > 0
            ? Date(timeIntervalSince1970: reviewPromptLastDismissedTimeInterval)
            : nil
        let snoozeUntil = lastDismissedDate.flatMap {
            Calendar.current.date(byAdding: .day, value: Int(Self.reviewPromptSnoozeDays), to: $0)
        }

        guard now >= minimumShowDate else { return }
        if let snoozeUntil, now < snoozeUntil { return }
        guard !isBlockingReviewPrompt else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reviewPromptDelaySeconds) {
            guard !reviewPromptHasShown else { return }
            guard !isBlockingReviewPrompt else { return }
            withAnimation(modalOverlayAnimation) {
                showReviewPrompt = true
            }
        }
    }

    private var isBlockingReviewPrompt: Bool {
        activeOnboardingStage != nil
            || showCloudSyncChoice
            || showNotificationOnboardingPrompt
    }

    private func seedReviewPromptBaselineIfNeeded() {
        guard !reviewPromptSeeded else { return }
        reviewPromptSeeded = true

        if isLikelyExistingUser {
            let threeDaysAgo = Date().addingTimeInterval(-Self.reviewPromptMinimumDays * 24 * 60 * 60)
            reviewPromptFirstLaunchTimeInterval = threeDaysAgo.timeIntervalSince1970
        } else if reviewPromptFirstLaunchTimeInterval == 0 {
            reviewPromptFirstLaunchTimeInterval = Date().timeIntervalSince1970
        }
    }

    private var isLikelyExistingUser: Bool {
        if userSettings.hasShownPrivacyNotice { return true }
        if userSettings.hasSeenCabinetIntroOverlay { return true }
        if userSettings.hasSeenNotificationOnboardingPrompt { return true }
        if !userSettings.seenOnboardingStages.isEmpty { return true }
        return userSettings.userName != "User"
    }

    private func dismissReviewPrompt() {
        withAnimation(modalOverlayAnimation) {
            showReviewPrompt = false
        }
        reviewPromptLastDismissedTimeInterval = Date().timeIntervalSince1970
    }

    private func openReviewLink() {
        reviewPromptHasShown = true
        withAnimation(modalOverlayAnimation) {
            showReviewPrompt = false
        }
        guard let url = URL(string: Self.reviewPromptURL), UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func dismissOnboarding() {
        let dismissedTab = activeOnboardingTab
        if let tab = dismissedTab {
            userSettings.markOnboardingStageSeen(tab.rawValue)
        }
        withAnimation(modalOverlayAnimation) {
            activeOnboardingStage = nil
            activeOnboardingTab = nil
        }
        scheduleReviewPromptIfNeeded()
    }


    private func handleCloudSyncSelection(_ choice: CloudSyncChoice) {
        let enableSync = choice == .connect
        userSettings.setCloudSyncPreference(enableSync)
        userSettings.markOnboardingStageSeen(Self.cloudSyncOnboardingKey)
        withAnimation(modalOverlayAnimation) {
            showCloudSyncChoice = false
        }
        handleCloudSyncCompletion()
    }

    private func handleCloudSyncCompletion() {
        guard !isUITestMode else {
            DispatchQueue.main.async {
                scheduleOnboarding(for: selectedTab)
            }
            return
        }
        guard !userSettings.hasSeenNotificationOnboardingPrompt else {
            DispatchQueue.main.async {
                scheduleOnboarding(for: selectedTab)
                scheduleReviewPromptIfNeeded()
            }
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    needsOnboardingAfterNotificationPrompt = true
                    userSettings.markNotificationOnboardingPromptSeen()
                    presentNotificationPromptAfterCloudChoiceDismissal()
                } else {
                    scheduleOnboarding(for: selectedTab)
                    scheduleReviewPromptIfNeeded()
                }
            }
        }
    }

    private func presentNotificationPromptAfterCloudChoiceDismissal(attempt: Int = 0) {
        let maxAttempts = 10
        guard attempt <= maxAttempts else {
            withAnimation(modalOverlayAnimation) {
                showNotificationOnboardingPrompt = true
            }
            return
        }

        // Ensure the sync chooser sheet is fully dismissed first.
        guard !showCloudSyncChoice else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                presentNotificationPromptAfterCloudChoiceDismissal(attempt: attempt + 1)
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(modalOverlayAnimation) {
                showNotificationOnboardingPrompt = true
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
        withAnimation(modalOverlayAnimation) {
            showNotificationOnboardingPrompt = false
        }
        isRequestingNotificationAuthorization = false
        DispatchQueue.main.async {
            scheduleOnboarding(for: selectedTab)
            scheduleReviewPromptIfNeeded()
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

struct ReviewPromptSheet: View {
    let onDismiss: () -> Void
    let onLeaveReview: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)

                VStack {
                    Spacer()

                    VStack(spacing: 14) {
                        Text("Enjoying Pillr?")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text("If Pillr has helped you, tap a star to leave a review and help others find us.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)

                        HStack(spacing: 8) {
                            ForEach(0..<5) { _ in
                                Button(action: onLeaveReview) {
                                    Image(systemName: "star")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(Color.white.opacity(0.8))
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .accessibilityLabel("Leave a 5-star review")
                            }
                        }

                        Button(action: onDismiss) {
                            Text("Not now")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.75))
                        }
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 22)
                    .frame(maxWidth: 420)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(hex: "#2A2D28").opacity(0.98))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
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
                    title: "Reflection",
                    description: AnyView(
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Capture a short daily note about how you are feeling.")
                                .multilineTextAlignment(.leading)
                            Text("Your Reflection entries stay tied to the medications you logged that day.")
                                .multilineTextAlignment(.leading)
                        }
                    ),
                    benefits: [

                    ],
                    icon: .system(name: "book.pages"),
                    accentColor: Color(hex: "#9FBBA5"),
                    buttonAccessibilityLabel: "Continue to Reflection"
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
