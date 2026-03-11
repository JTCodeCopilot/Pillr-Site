import SwiftUI
import UserNotifications
import LocalAuthentication
import UIKit

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
    @State private var showWhatsNewSheet = false
    @State private var showWelcomeOnboardingFlow = false
    @State private var showBiometricAppLock = false
    @State private var isBiometricAuthInProgress = false
    @State private var biometricLockErrorMessage: String?
    @State private var requiresBiometricOnNextActive = true
    @State private var wasExistingUserAtLaunch = false
    @State private var showPostOnboardingCelebration = false
    @State private var referenceDate = Date()
    @State private var suppressTabSelectionUntil = Date.distantPast
    @AppStorage("reviewPromptFirstLaunchTimeInterval") private var reviewPromptFirstLaunchTimeInterval: Double = 0
    @AppStorage("reviewPromptHasShown") private var reviewPromptHasShown = false
    @AppStorage("reviewPromptLastDismissedTimeInterval") private var reviewPromptLastDismissedTimeInterval: Double = 0
    @AppStorage("reviewPromptSeeded") private var reviewPromptSeeded = false
    @AppStorage("appLaunchCount") private var appLaunchCount: Int = 0
    @AppStorage("hasShownOnboardingSuccessCelebration") private var hasShownOnboardingSuccessCelebration = false
    @AppStorage("lastSeenWhatsNewAnnouncementID") private var lastSeenWhatsNewAnnouncementID = ""
    private var isUITestMode: Bool { UserSettings.isUITestMode }
    
    private static let cloudSyncOnboardingKey = "cloudSyncChoice"
    private static let reviewPromptURL = "https://apps.apple.com/us/app/pillr-adhd-medication-tracker/id6746717689?action=write-review"
    private static let whatsNewAnnouncementID = "whatsnew-menu-tabs-faceid-2026-02"
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

    private var onboardingOverlayAnimation: Animation {
        .spring(response: 0.5, dampingFraction: 0.88)
    }

    private var tabVisibilitySignature: String {
        [
            userSettings.isHistoryTabEnabled ? "1" : "0",
            userSettings.isReflectionTabEnabled ? "1" : "0",
            userSettings.isTimelineTabEnabled ? "1" : "0"
        ].joined()
    }

    private var shouldBlockWithBiometricGate: Bool {
        userSettings.isBiometricLockEnabled
            && !showWelcomeOnboardingFlow
            && requiresBiometricOnNextActive
    }

    private var shouldShowBiometricLockOverlay: Bool {
        !showWelcomeOnboardingFlow
            && (showBiometricAppLock || shouldBlockWithBiometricGate)
    }

    var body: some View {
        ZStack {
            LinearGradient.pillrBackground
                .ignoresSafeArea()

            if !shouldBlockWithBiometricGate {
                TabView(selection: tabSelection) {
                    MedicationsHomeView(addFlowCoordinator: addFlowCoordinator)
                        .tabItem {
                            Image(systemName: "pill")
                                .symbolVariant(.none)
                                .accessibilityLabel("My Meds")
                        }
                        .badge(overdueBadgeCount)
                        .tag(MainTab.meds)

                    if userSettings.isReflectionTabEnabled {
                        DailyCheckInHistoryView()
                            .tabItem {
                                Image(systemName: "book.pages")
                                    .accessibilityLabel("Check-Ins")
                            }
                            .tag(MainTab.checkIns)
                    }

                    if userSettings.isTimelineTabEnabled {
                        FocusTimelineView(isModal: false)
                            .tabItem {
                                Image(systemName: "hourglass")
                                    .accessibilityLabel("Focus")
                            }
                            .tag(MainTab.focus)
                    }

                    if userSettings.isHistoryTabEnabled {
                        MedicationHistoryView()
                            .tabItem {
                                Image(systemName: "calendar")
                                    .accessibilityLabel("History")
                            }
                            .tag(MainTab.history)
                    }

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
            }

                if !showWelcomeOnboardingFlow {
                    if let stage = activeOnboardingStage {
                        OnboardingOverlayView(info: stage) {
                            dismissOnboarding()
                        }
                        .transition(.opacity)
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
                }
                if showReviewPrompt {
                    ReviewPromptSheet(
                        onDismiss: dismissReviewPrompt,
                        onLeaveReview: openReviewLink
                    )
                    .transition(modalOverlayTransition)
                    .zIndex(2)
                }
                if showWhatsNewSheet {
                    WhatsNewSheet(onDismiss: dismissWhatsNewSheet)
                        .transition(modalOverlayTransition)
                        .zIndex(2.5)
                }
                if showWelcomeOnboardingFlow {
                    PillrWelcomeOnboardingFlow { result in
                        completeWelcomeOnboarding(using: result)
                    }
                    .transition(.opacity)
                    .zIndex(5)
                }
                if shouldShowBiometricLockOverlay {
                    BiometricAppLockOverlay(
                        biometryType: BiometricLockCoordinator.availableBiometryType(),
                        isUnlocking: isBiometricAuthInProgress,
                        errorMessage: biometricLockErrorMessage,
                        onUnlock: requestBiometricUnlock
                    )
                    .transition(.opacity)
                    .zIndex(6)
                }

                if showPostOnboardingCelebration && selectedTab == .meds && !showWelcomeOnboardingFlow {
                    DoneConfettiBackgroundView(animate: showPostOnboardingCelebration)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(7)
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
            wasExistingUserAtLaunch = isLikelyExistingUser
            startWelcomeOnboardingIfNeeded()
            ensureSelectedTabIsVisible()
            if !showWelcomeOnboardingFlow {
                scheduleOnboarding(for: selectedTab)
            }
            scheduleWhatsNewIfNeeded()
            scheduleReviewPromptIfNeeded()
            store.refreshOverdueMedicationIDs(referenceDate: referenceDate)
            handleBiometricGateIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                referenceDate = Date()
                store.refreshOverdueMedicationIDs(referenceDate: referenceDate)
                handleBiometricGateIfNeeded()
                scheduleWhatsNewIfNeeded()
            case .background:
                if userSettings.isBiometricLockEnabled {
                    requiresBiometricOnNextActive = true
                }
            default:
                break
            }
        }
        .onChange(of: store.requestedMainTab) { _, requested in
            guard let requested else { return }
            applySelectedTab(requested)
            DispatchQueue.main.async {
                store.requestedMainTab = nil
            }
        }
        .onChange(of: userSettings.isBiometricLockEnabled) { _, enabled in
            if !enabled {
                showBiometricAppLock = false
                requiresBiometricOnNextActive = false
                biometricLockErrorMessage = nil
            } else {
                requiresBiometricOnNextActive = true
                handleBiometricGateIfNeeded()
            }
        }
        .onChange(of: tabVisibilitySignature) { _, _ in
            ensureSelectedTabIsVisible()
        }
        .onChange(of: showWelcomeOnboardingFlow) { _, showing in
            if !showing {
                handleBiometricGateIfNeeded()
                scheduleWhatsNewIfNeeded()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func applySelectedTab(_ tab: MainTab) {
        let resolvedTab = resolvedVisibleTab(tab)
        selectedTab = resolvedTab
        scheduleOnboarding(for: resolvedTab)
    }

    private func ensureSelectedTabIsVisible() {
        let resolvedTab = resolvedVisibleTab(selectedTab)
        guard selectedTab != resolvedTab else { return }
        selectedTab = resolvedTab
    }

    private func resolvedVisibleTab(_ tab: MainTab) -> MainTab {
        switch tab {
        case .meds, .more:
            return tab
        case .history:
            return userSettings.isHistoryTabEnabled ? tab : .meds
        case .checkIns:
            return userSettings.isReflectionTabEnabled ? tab : .meds
        case .focus:
            return userSettings.isTimelineTabEnabled ? tab : .meds
        }
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
        guard !showWelcomeOnboardingFlow else { return }
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
        withAnimation(onboardingOverlayAnimation) {
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
            || showWelcomeOnboardingFlow
            || showBiometricAppLock
            || showWhatsNewSheet
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
        if appLaunchCount > 1 { return true }
        if userSettings.hasShownPrivacyNotice { return true }
        if userSettings.hasSeenCabinetIntroOverlay { return true }
        if userSettings.hasSeenNotificationOnboardingPrompt { return true }
        if !userSettings.seenOnboardingStages.isEmpty { return true }
        return userSettings.userName != "User"
    }

    private func startWelcomeOnboardingIfNeeded() {
        guard !isUITestMode else { return }
        guard !userSettings.hasCompletedAppOnboarding else { return }

        if isLikelyExistingUser {
            userSettings.markAppOnboardingComplete()
            return
        }

        withAnimation(modalOverlayAnimation) {
            showWelcomeOnboardingFlow = true
        }
    }

    private func completeWelcomeOnboarding(using result: PillrOnboardingResult) {
        // Fresh installs should not see this release's "What's New" popup later.
        if !wasExistingUserAtLaunch {
            lastSeenWhatsNewAnnouncementID = Self.whatsNewAnnouncementID
        }
        userSettings.setCloudSyncPreference(result.useCloudSync)
        userSettings.setBiometricLockEnabled(result.enableBiometricLock)
        userSettings.markNotificationOnboardingPromptSeen()
        userSettings.markAppOnboardingComplete()
        // Mark cloud sync onboarding as handled because it's now part of the new welcome flow.
        userSettings.markOnboardingStageSeen(Self.cloudSyncOnboardingKey)

        requiresBiometricOnNextActive = false

        withAnimation(modalOverlayAnimation) {
            showWelcomeOnboardingFlow = false
            activeOnboardingStage = nil
            activeOnboardingTab = nil
            showCloudSyncChoice = false
            showNotificationOnboardingPrompt = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            selectedTab = .meds
            triggerPostOnboardingCelebrationIfNeeded()
            scheduleOnboarding(for: selectedTab)
            scheduleReviewPromptIfNeeded()
        }
    }

    private func triggerPostOnboardingCelebrationIfNeeded() {
        guard !hasShownOnboardingSuccessCelebration else { return }
        hasShownOnboardingSuccessCelebration = true

        HapticManager.shared.successNotification()

        withAnimation(.easeOut(duration: 0.2)) {
            showPostOnboardingCelebration = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.1) {
            withAnimation(.easeOut(duration: 0.35)) {
                showPostOnboardingCelebration = false
            }
        }
    }

    private func handleBiometricGateIfNeeded() {
        guard scenePhase == .active else { return }
        guard userSettings.isBiometricLockEnabled else {
            showBiometricAppLock = false
            biometricLockErrorMessage = nil
            return
        }
        guard !showWelcomeOnboardingFlow else { return }
        guard requiresBiometricOnNextActive else { return }

        showBiometricAppLock = true
        requestBiometricUnlock()
    }

    private func requestBiometricUnlock() {
        guard userSettings.isBiometricLockEnabled else { return }
        guard !isBiometricAuthInProgress else { return }

        isBiometricAuthInProgress = true
        biometricLockErrorMessage = nil

        BiometricLockCoordinator.authenticateForAppUnlock(reason: "Unlock Pillr to view your medications.") { success, error in
            isBiometricAuthInProgress = false

            if success {
                requiresBiometricOnNextActive = false
                withAnimation(.easeOut(duration: 0.2)) {
                    showBiometricAppLock = false
                }
                return
            }

            showBiometricAppLock = true
            requiresBiometricOnNextActive = true
            biometricLockErrorMessage = friendlyBiometricErrorMessage(error)
        }
    }

    private func friendlyBiometricErrorMessage(_ error: Error?) -> String? {
        guard let error else { return "Authentication failed. Please try again." }

        if let laError = error as? LAError {
            switch laError.code {
            case .userCancel, .systemCancel, .appCancel:
                return nil
            case .biometryNotAvailable:
                return "Face ID is not available on this device."
            case .biometryNotEnrolled:
                return "Face ID is not set up yet. You can enable it in iPhone Settings."
            case .biometryLockout:
                return "Face ID is temporarily locked. Use your passcode to unlock."
            default:
                return "Couldn’t verify your identity. Please try again."
            }
        }

        return "Couldn’t verify your identity. Please try again."
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

    private func scheduleWhatsNewIfNeeded() {
        guard !isUITestMode else { return }
        guard !showWhatsNewSheet else { return }
        guard !showWelcomeOnboardingFlow else { return }
        guard userSettings.hasCompletedAppOnboarding else { return }
        guard wasExistingUserAtLaunch else { return }
        guard lastSeenWhatsNewAnnouncementID != Self.whatsNewAnnouncementID else { return }
        guard activeOnboardingStage == nil else { return }
        guard !showCloudSyncChoice else { return }
        guard !showNotificationOnboardingPrompt else { return }
        guard !showBiometricAppLock else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard !showWhatsNewSheet else { return }
            guard !showWelcomeOnboardingFlow else { return }
            guard lastSeenWhatsNewAnnouncementID != Self.whatsNewAnnouncementID else { return }
            withAnimation(modalOverlayAnimation) {
                showWhatsNewSheet = true
            }
        }
    }

    private func dismissWhatsNewSheet() {
        lastSeenWhatsNewAnnouncementID = Self.whatsNewAnnouncementID
        withAnimation(modalOverlayAnimation) {
            showWhatsNewSheet = false
        }
        scheduleReviewPromptIfNeeded()
    }

    private func dismissOnboarding() {
        let dismissedTab = activeOnboardingTab
        if let tab = dismissedTab {
            userSettings.markOnboardingStageSeen(tab.rawValue)
        }
        withAnimation(onboardingOverlayAnimation) {
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
                    .fill(Color.pillrPrimary)
                    .ignoresSafeArea()
                
                Rectangle()
                    .fill(Color.pillrPrimary)
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

                        VStack(spacing: 18) {
                            Button(action: onContinue) {
                                Text("Continue")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.pillrPrimary)
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
                            .fill(Color.pillrPrimary.opacity(0.98))
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
                            .fill(Color.pillrPrimary.opacity(0.98))
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

struct WhatsNewSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)

                VStack {
                    Spacer()

                    VStack(alignment: .leading, spacing: 14) {
                        Text("What's New")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 10) {
                            whatsNewRow(
                                icon: "slider.horizontal.3",
                                title: "Customize menu tabs",
                                detail: "Turn History, Reflection, and Timeline tabs on or off."
                            )

                            whatsNewRow(
                                icon: "faceid",
                                title: "Face ID app lock",
                                detail: "Lock Pillr with Face ID (or Touch ID)."
                            )
                        }

                        Button(action: onDismiss) {
                            Text("Got it")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.pillrPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.pillrBackground)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(.top, 2)
                    }
                    .padding(22)
                    .frame(maxWidth: 460)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.pillrPrimary.opacity(0.98))
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

    @ViewBuilder
    private func whatsNewRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.pillrBackground)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.78))
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
        )
    }
}

private struct PillrOnboardingResult {
    let useCloudSync: Bool
    let enableBiometricLock: Bool
}

private enum PillrBiometricType {
    case none
    case faceID
    case touchID

    var displayName: String {
        switch self {
        case .none: return "Biometric Lock"
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "lock.fill"
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        }
    }
}

private enum BiometricLockCoordinator {
    static func availableBiometryType() -> PillrBiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }

    static func requestBiometricEnable(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        if UserSettings.isUITestMode {
            completion(true, nil)
            return
        }

        let context = LAContext()
        context.localizedCancelTitle = "Not now"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            DispatchQueue.main.async {
                completion(false, error)
            }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                completion(success, authError)
            }
        }
    }

    static func authenticateForAppUnlock(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        if UserSettings.isUITestMode {
            completion(true, nil)
            return
        }

        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            DispatchQueue.main.async {
                completion(false, error)
            }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                completion(success, authError)
            }
        }
    }
}

private struct PillrWelcomeOnboardingFlow: View {
    let onFinish: (PillrOnboardingResult) -> Void

    @State private var step: Step = .welcome
    @State private var useCloudSync = true
    @State private var enableBiometricLock = false
    @State private var isWorking = false
    @State private var helperMessage: String?
    @State private var runDoneConfetti = false
    @StateObject private var onboardingHealthKitManager = HealthKitManager()
    @State private var biometricHeroShakeOffset: CGFloat = 0
    @State private var biometricHeroJoltScale: CGFloat = 1
    @State private var biometricHeroJoltYOffset: CGFloat = 0
    @State private var storageHeroFloatYOffset: CGFloat = 0
    @State private var notificationHeroRingRotation: Double = 0
    @State private var healthHeroPulseScale: CGFloat = 1
    @State private var healthHeroPulseOpacity: Double = 0.08
    @State private var healthHeartbeatLoopToken: Int = 0
    @State private var welcomeHeroRotation: Double = 14
    @State private var welcomeHeroOpacity: Double = 1
    @State private var welcomeHeroScale: CGFloat = 1
    @State private var welcomePrimaryButtonPulseScale: CGFloat = 1
    @State private var welcomePrimaryButtonPulseGlow: Double = 0
    @State private var welcomePrimaryButtonPulseToken: Int = 0
    @State private var titleSectionVisible = false
    @State private var messageSectionVisible = false
    @State private var detailSectionVisible = false
    @State private var actionsSectionVisible = false

    private let biometryType = BiometricLockCoordinator.availableBiometryType()

    private enum Step: Int, CaseIterable {
        case welcome
        case notifications
        case storage
        case health
        case biometric
        case done
    }

    private var orderedSteps: [Step] {
        var steps: [Step] = [.welcome, .notifications, .storage]
        if onboardingHealthKitManager.isHealthDataAvailable {
            steps.append(.health)
        }
        if biometryType != .none {
            steps.append(.biometric)
        }
        return steps
    }

    private var usesEditorialLayout: Bool {
        step == .welcome || step == .notifications || step == .storage || step == .health || step == .biometric || step == .done
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.pillrPrimary,
                        Color.pillrPrimary
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if step == .welcome {
                    welcomePillSilhouette
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                if step == .notifications {
                    notificationBellSilhouette
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                if step == .storage {
                    storageCloudSilhouette
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                if step == .health {
                    healthSilhouette
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                if step == .biometric {
                    biometricSilhouette
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                if step == .done {
                    doneSilhouette
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                if step == .done {
                    DoneConfettiBackgroundView(animate: runDoneConfetti)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                VStack(spacing: 0) {
                    HStack(spacing: 7) {
                        ForEach(Array(orderedSteps.enumerated()), id: \.offset) { index, _ in
                            Capsule()
                                .fill(index <= completedProgressIndex ? Color.white.opacity(0.88) : Color.white.opacity(0.20))
                                .frame(maxWidth: .infinity)
                                .frame(height: 4)
                                .shadow(
                                    color: index <= completedProgressIndex ? Color.white.opacity(0.12) : .clear,
                                    radius: 4,
                                    x: 0,
                                    y: 0
                                )
                        }
                    }
                    .animation(.easeInOut(duration: 0.22), value: completedProgressIndex)
                    .padding(.horizontal, 22)
                    .padding(.top, geometry.safeAreaInsets.top + 6)

                    VStack(spacing: 26) {
                        Group {
                            if step == .welcome {
                                Color.clear
                                    .frame(width: 248, height: 72)
                            } else if step == .notifications {
                                Color.clear
                                    .frame(width: 248, height: 72)
                            } else if step == .storage {
                                Color.clear
                                    .frame(width: 248, height: 72)
                            } else if step == .health {
                                Color.clear
                                    .frame(width: 248, height: 72)
                            } else if step == .biometric {
                                Color.clear
                                    .frame(width: 248, height: 72)
                            } else if step == .done {
                                Color.clear
                                    .frame(width: 248, height: 72)
                            } else {
                                onboardingHeroImage(
                                    assetName: heroAssetName,
                                    fallbackSystemName: iconName,
                                    size: step == .welcome ? 285 : 248
                                )
                                .rotationEffect(.degrees(step == .welcome ? welcomeHeroRotation : 0))
                                .rotationEffect(
                                    .degrees(step == .notifications ? notificationHeroRingRotation : 0),
                                    anchor: .top
                                )
                                        .offset(
                                            x: (step == .biometric ? biometricHeroShakeOffset : 0)
                                        + 0,
                                            y: 0
                                        )
                                .scaleEffect(step == .welcome ? welcomeHeroScale : 1)
                                .opacity(step == .welcome ? welcomeHeroOpacity : 1)
                                .shadow(color: Color.black.opacity(0.3), radius: 14, x: 0, y: 7)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: usesEditorialLayout ? 72 : 170, maxHeight: usesEditorialLayout ? 72 : 170, alignment: .top)
                        .padding(.bottom, usesEditorialLayout ? 20 : 64)

                        VStack(spacing: 12) {
                            Text(title)
                                .font(
                                    .system(
                                        size: step == .welcome ? 96 : (step == .done ? 52 : ((step == .notifications || step == .storage || step == .health || step == .biometric) ? 58 : 48)),
                                        weight: .regular,
                                        design: .rounded
                                    )
                                )
                                .foregroundColor(Color.pillrBackground)
                                .multilineTextAlignment(usesEditorialLayout ? .leading : .center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                                .opacity(titleSectionVisible ? 1 : 0)
                                .offset(y: titleSectionVisible ? 0 : -10)
                                .frame(maxWidth: .infinity, alignment: usesEditorialLayout ? .leading : .center)

                            Group {
                                if step == .welcome {
                                    Text(message)
                                        .font(.system(size: 22, weight: .regular, design: .default))
                                } else {
                                    Text(message)
                                        .font(.system(size: step == .storage ? 17 : 18, weight: .medium, design: .rounded))
                                }
                            }
                            .foregroundColor(Color.pillrSecondary.opacity(0.94))
                            .multilineTextAlignment(usesEditorialLayout ? .leading : .center)
                            .lineSpacing(4)
                            .lineLimit(step == .storage ? 3 : nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: usesEditorialLayout ? .leading : .center)
                            .padding(.top, (usesEditorialLayout ? 18 : 0) + (step == .storage ? 2 : 0))
                            .padding(.horizontal, usesEditorialLayout ? 0 : 16)
                            .opacity(messageSectionVisible ? 1 : 0)
                            .offset(y: messageSectionVisible ? 0 : 12)
                        }
                        .padding(.horizontal, usesEditorialLayout ? 14 : 0)
                        .offset(y: usesEditorialLayout ? 34 : 0)

                        Group {
                            if step == .welcome {
                                HStack {
                                    Button(action: handlePrimaryAction) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.12))
                                                .frame(width: 62, height: 62)
                                            Circle()
                                                .stroke(Color.white.opacity(0.32), lineWidth: 1.5)
                                                .frame(width: 66, height: 66)
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundColor(Color.pillrBackground)
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94, hapticStyle: .pulseButton))
                                    .scaleEffect(welcomePrimaryButtonPulseScale)
                                    .shadow(color: Color.white.opacity(welcomePrimaryButtonPulseGlow), radius: 14)
                                    .disabled(isWorking)

                                    Spacer()
                                }
                                .padding(.top, 32)
                                .padding(.horizontal, 14)
                            }

                            if step == .done {
                                HStack(spacing: 14) {
                                    Button(action: handlePrimaryAction) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.pillrBackground)
                                                .frame(width: 68, height: 68)
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundColor(Color.pillrPrimary)
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle(scaleAmount: 0.94, hapticStyle: .pulseButton))
                                    .disabled(isWorking)

                                    Text("Start using Pillr")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color.pillrSecondary.opacity(0.95))

                                    Spacer()
                                }
                                .padding(.top, 18)
                                .padding(.horizontal, 14)
                            }

                            if step == .notifications {
                                HStack(spacing: 22) {
                                    Button(action: handlePrimaryAction) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.pillrBackground)
                                                .frame(width: 68, height: 68)

                                            if isWorking {
                                                ProgressView()
                                                    .tint(Color.pillrPrimary)
                                            } else {
                                                Text("On")
                                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color.pillrPrimary)
                                            }
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .disabled(isWorking)
                                    .overlay(alignment: .bottom) {
                                        Text("(recommended)")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(Color.pillrSecondary.opacity(0.8))
                                            .fixedSize(horizontal: true, vertical: false)
                                            .offset(y: 24)
                                    }

                                    Button(action: handleSecondaryAction) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.08))
                                                .frame(width: 68, height: 68)
                                            Circle()
                                                .stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                                                .frame(width: 68, height: 68)
                                            Text("Off")
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                .foregroundColor(Color.pillrSecondary.opacity(0.95))
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .disabled(isWorking)

                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 30)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 18)
                            }

                            if step == .storage {
                                VStack(spacing: 10) {
                                    PillrOnboardingOptionCard(
                                        title: "Use iCloud Sync (recommended)",
                                        subtitle: "Back up and sync across your Apple devices.",
                                        isSelected: useCloudSync
                                    ) {
                                        useCloudSync = true
                                    }

                                    PillrOnboardingOptionCard(
                                        title: "Keep data on this iPhone",
                                        subtitle: "Store everything only on this device.",
                                        isSelected: !useCloudSync
                                    ) {
                                        useCloudSync = false
                                    }
                                }
                                .padding(.top, 22)
                            }

                            if step == .health {
                                HStack(spacing: 22) {
                                    Button(action: handlePrimaryAction) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.pillrBackground)
                                                .frame(width: 68, height: 68)

                                            if isWorking {
                                                ProgressView()
                                                    .tint(Color.pillrPrimary)
                                            } else {
                                                Text("On")
                                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color.pillrPrimary)
                                            }
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .disabled(isWorking)
                                    .overlay(alignment: .bottom) {
                                        Text("(recommended)")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(Color.pillrSecondary.opacity(0.8))
                                            .fixedSize(horizontal: true, vertical: false)
                                            .offset(y: 24)
                                    }

                                    Button(action: handleSecondaryAction) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.08))
                                                .frame(width: 68, height: 68)
                                            Circle()
                                                .stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                                                .frame(width: 68, height: 68)
                                            Text("Off")
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                .foregroundColor(Color.pillrSecondary.opacity(0.95))
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .disabled(isWorking)

                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 30)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 18)
                            }

                            if step == .biometric && biometryType != .none {
                                HStack(spacing: 22) {
                                    Button(action: handlePrimaryAction) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.pillrBackground)
                                                .frame(width: 68, height: 68)

                                            if isWorking {
                                                ProgressView()
                                                    .tint(Color.pillrPrimary)
                                            } else {
                                                Text("On")
                                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color.pillrPrimary)
                                            }
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .disabled(isWorking)

                                    Button(action: handleSecondaryAction) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.08))
                                                .frame(width: 68, height: 68)
                                            Circle()
                                                .stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                                                .frame(width: 68, height: 68)
                                            Text("Off")
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                .foregroundColor(Color.pillrSecondary.opacity(0.95))
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .disabled(isWorking)

                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 30)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 18)
                            }

                            if let helperMessage {
                                Text(helperMessage)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.pillrSecondary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 18)
                            }
                        }
                        .opacity(detailSectionVisible ? 1 : 0)
                        .offset(y: detailSectionVisible ? 0 : -10)
                    }
                    .padding(.top, 26)
                    .padding(.horizontal, 22)

                    Spacer(minLength: 20)

                    if step != .welcome && step != .notifications && step != .health && step != .biometric && step != .done {
                        VStack(spacing: 14) {
                            if step == .storage {
                                HStack {
                                    Button(action: handlePrimaryAction) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.pillrBackground)
                                                .frame(width: 68, height: 68)

                                            if isWorking {
                                                ProgressView()
                                                    .tint(Color.pillrPrimary)
                                            } else {
                                                Image(systemName: "arrow.right")
                                                    .font(.system(size: 22, weight: .semibold))
                                                    .foregroundColor(Color.pillrPrimary)
                                            }
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .disabled(isWorking)

                                    Spacer()
                                }
                            } else {
                                Button(action: handlePrimaryAction) {
                                    HStack(spacing: 10) {
                                        if isWorking {
                                            ProgressView()
                                                .tint(Color.pillrPrimary)
                                        } else if step == .biometric && biometryType != .none {
                                            Image(systemName: biometryType.iconName)
                                                .font(.system(size: 18, weight: .semibold))
                                        }

                                        Text(primaryButtonTitle)
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(Color.pillrPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 17)
                                    .background(
                                        Capsule()
                                            .fill(Color.pillrBackground)
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .disabled(isWorking)
                            }

                            if let secondaryTitle = secondaryButtonTitle {
                                Button(action: handleSecondaryAction) {
                                    Text(secondaryTitle)
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color.pillrSecondary.opacity(0.88))
                                        .underline()
                                }
                                .buttonStyle(.plain)
                                .disabled(isWorking)
                            }
                        }
                        .opacity(actionsSectionVisible ? 1 : 0)
                        .offset(y: actionsSectionVisible ? 0 : -8)
                        .padding(.horizontal, 22)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + (step == .storage ? 170 : 22))
                    }
                }
            }
        }
        .onAppear {
            if step == .welcome {
                runWelcomeHeroArrival()
                scheduleWelcomePrimaryButtonPulseHint()
            }
            runStepSoftReveal(for: step)
        }
        .onChange(of: step) { _, newStep in
            if newStep == .welcome {
                runWelcomeHeroArrival()
                scheduleWelcomePrimaryButtonPulseHint()
            } else {
                welcomeHeroRotation = 0
                welcomeHeroOpacity = 1
                welcomeHeroScale = 1
                stopWelcomePrimaryButtonPulseHint()
            }

            runStepSoftReveal(for: newStep)

            if newStep == .notifications {
                runNotificationHeroRing()
            } else {
                notificationHeroRingRotation = 0
            }

            if newStep == .biometric {
                runBiometricHeroShake()
            } else {
                biometricHeroShakeOffset = 0
                biometricHeroJoltScale = 1
                biometricHeroJoltYOffset = 0
            }

            if newStep == .storage {
                runStorageHeroDriftIn()
            } else {
                storageHeroFloatYOffset = 0
            }

            if newStep == .health {
                runHealthHeroPulse()
            } else {
                healthHeroPulseScale = 1
                healthHeroPulseOpacity = 0.08
                healthHeartbeatLoopToken += 1
            }

            if newStep == .done {
                runDoneConfetti = false
                DispatchQueue.main.async {
                    runDoneConfetti = true
                }
            } else {
                runDoneConfetti = false
            }
        }
    }

    private var completedProgressIndex: Int {
        if step == .done { return max(orderedSteps.count - 1, 0) }
        return orderedSteps.firstIndex(of: step) ?? -1
    }

    @ViewBuilder
    private var welcomePillSilhouette: some View {
        GeometryReader { _ in
            Group {
                if UIImage(named: "pill") != nil {
                    Image("pill")
                        .resizable()
                        .scaledToFit()
                        .saturation(0)
                        .brightness(0.85)
                        .opacity(0.10)
                        .rotationEffect(.degrees(18))
                        .frame(width: 560, height: 560)
                        .offset(x: 0, y: 180)
                } else {
                    Image(systemName: "capsule.portrait.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color.white.opacity(0.08))
                        .rotationEffect(.degrees(18))
                        .frame(width: 470, height: 470)
                        .offset(x: 0, y: 165)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var notificationBellSilhouette: some View {
        GeometryReader { _ in
            Group {
                if UIImage(named: "notification") != nil {
                    Image("notification")
                        .resizable()
                        .scaledToFit()
                        .saturation(0)
                        .brightness(0.85)
                        .opacity(0.08)
                        .rotationEffect(.degrees(22 + notificationHeroRingRotation), anchor: .top)
                        .frame(width: 640, height: 640)
                        .offset(x: 70, y: 280)
                } else {
                    Image(systemName: "bell.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color.white.opacity(0.08))
                        .rotationEffect(.degrees(18 + notificationHeroRingRotation), anchor: .top)
                        .frame(width: 430, height: 430)
                        .offset(x: 90, y: 320)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var storageCloudSilhouette: some View {
        GeometryReader { _ in
            Group {
                if UIImage(named: "cloud") != nil {
                    Image("cloud")
                        .resizable()
                        .scaledToFit()
                        .saturation(0)
                        .brightness(0.85)
                        .opacity(0.08)
                        .frame(width: 620, height: 620)
                        .offset(x: 12, y: 332 + storageHeroFloatYOffset)
                } else {
                    Image(systemName: "icloud.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color.white.opacity(0.08))
                        .frame(width: 360, height: 360)
                        .offset(x: 22, y: 388 + storageHeroFloatYOffset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var healthSilhouette: some View {
        GeometryReader { _ in
            Group {
                if UIImage(named: "heart") != nil {
                    Image("heart")
                        .resizable()
                        .scaledToFit()
                        .saturation(0)
                        .brightness(0.86)
                        .opacity(healthHeroPulseOpacity)
                        .frame(width: 520, height: 520)
                        .scaleEffect(healthHeroPulseScale)
                        .offset(x: 55, y: 360)
                } else {
                    Image(systemName: "heart.text.square.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color.white.opacity(healthHeroPulseOpacity))
                        .frame(width: 300, height: 300)
                        .scaleEffect(healthHeroPulseScale)
                        .offset(x: 95, y: 410)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var doneSilhouette: some View {
        GeometryReader { _ in
            Group {
                if UIImage(named: "tick") != nil {
                    Image("tick")
                        .resizable()
                        .scaledToFit()
                        .saturation(0)
                        .brightness(0.9)
                        .opacity(0.08)
                        .frame(width: 560, height: 560)
                        .offset(x: 60, y: 330)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color.white.opacity(0.08))
                        .frame(width: 340, height: 340)
                        .offset(x: 90, y: 390)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var biometricSilhouette: some View {
        GeometryReader { _ in
            Group {
                if biometryType == .faceID, UIImage(named: "faceid") != nil {
                    Image("faceid")
                        .resizable()
                        .scaledToFit()
                        .saturation(0)
                        .brightness(0.85)
                        .opacity(0.08)
                        .frame(width: 620, height: 620)
                        .scaleEffect(biometricHeroJoltScale)
                        .offset(x: -20, y: 320 + biometricHeroJoltYOffset)
                } else if UIImage(named: "Feather Cloud Icon") != nil {
                    Image("Feather Cloud Icon")
                        .resizable()
                        .scaledToFit()
                        .saturation(0)
                        .brightness(0.85)
                        .opacity(0.08)
                        .frame(width: 620, height: 620)
                        .scaleEffect(biometricHeroJoltScale)
                        .offset(x: 95, y: 320 + biometricHeroJoltYOffset)
                } else if UIImage(named: "lock") != nil {
                    Image("lock")
                        .resizable()
                        .scaledToFit()
                        .saturation(0)
                        .brightness(0.85)
                        .opacity(0.08)
                        .frame(width: 560, height: 560)
                        .scaleEffect(biometricHeroJoltScale)
                        .offset(x: 95, y: 330 + biometricHeroJoltYOffset)
                } else {
                    Image(systemName: biometryType.iconName)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color.white.opacity(0.08))
                        .frame(width: 340, height: 340)
                        .scaleEffect(biometricHeroJoltScale)
                        .offset(x: 130, y: 380 + biometricHeroJoltYOffset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var iconName: String {
        switch step {
        case .welcome:
            return "pill.fill"
        case .biometric:
            return biometryType.iconName
        case .notifications:
            return "bell.badge.fill"
        case .storage:
            return "icloud.fill"
        case .health:
            return "heart.text.square.fill"
        case .done:
            return "checkmark.shield.fill"
        }
    }

    private var heroAssetName: String {
        switch step {
        case .welcome:
            return "pill"
        case .biometric:
            return "lock"
        case .notifications:
            return "notification"
        case .storage:
            return "cloud"
        case .health:
            return "heart.text.square"
        case .done:
            return "tick"
        }
    }

    @ViewBuilder
    private func onboardingHeroImage(assetName: String, fallbackSystemName: String, size: CGFloat) -> some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.pillrAccent,
                            Color.pillrPrimary
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size + 24, height: size + 24)
                .overlay {
                    Image(systemName: fallbackSystemName)
                        .font(.system(size: size * 0.45, weight: .medium))
                        .foregroundColor(Color.pillrBackground)
                }
        }
    }

    private var title: String {
        switch step {
        case .welcome:
            return "Pillr"
        case .biometric:
            return "Privacy"
        case .notifications:
            return "Notifications"
        case .storage:
            return biometryType == .none ? "Storage" : "Storage"
        case .health:
            return "Apple Health"
        case .done:
            return "Good to go!"
        }
    }

    private var message: String {
        switch step {
        case .welcome:
            return "Designed by the ADHD community\nfor the ADHD community."
        case .biometric:
            if biometryType == .none {
                return "This device does not support Face ID or Touch ID. You can continue without app lock."
            }
            return "Use \(biometryType.displayName) so only you can open Pillr."
        case .notifications:
            return "Turn on notifications so Pillr can remind you when it’s time for your meds."
        case .storage:
            if biometryType == .none {
                return "Choose where to keep your medication data: on this iPhone only, or synced with iCloud across your Apple devices."
            }
            return "Choose where to keep your medication data: on this iPhone only, or synced with iCloud across your Apple devices."
        case .health:
            return "Connect your Apple Health data with Pillr to show key health metrics right on your home screen."
        case .done:
            return ""
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome:
            return "Let's get started"
        case .biometric:
            return biometryType == .none ? "Continue" : "Enable \(biometryType.displayName)"
        case .notifications:
            return "Turn on notifications (recommended)"
        case .storage:
            return "Continue"
        case .health:
            return "Connect Apple Health"
        case .done:
            return "Start using Pillr"
        }
    }

    private var secondaryButtonTitle: String? {
        switch step {
        case .biometric where biometryType != .none:
            return "Not now"
        case .notifications:
            return "Maybe later"
        case .health:
            return "Maybe later"
        default:
            return nil
        }
    }

    private func handlePrimaryAction() {
        helperMessage = nil

        switch step {
        case .welcome:
            advanceStep()
        case .biometric:
            guard biometryType != .none else {
                advanceStep()
                return
            }

            isWorking = true
            BiometricLockCoordinator.requestBiometricEnable(reason: "Enable \(biometryType.displayName) to protect your Pillr data.") { success, _ in
                isWorking = false
                enableBiometricLock = success
                if !success {
                    helperMessage = "\(biometryType.displayName) was not enabled. You can still turn it on later in Settings."
                }
                advanceStep()
            }
        case .notifications:
            isWorking = true
            NotificationManager.shared.requestAuthorization(allowBeforeOnboardingCompletion: true) { _ in
                DispatchQueue.main.async {
                    isWorking = false
                    advanceStep()
                }
            }
        case .storage:
            advanceStep()
        case .health:
            isWorking = true
            Task {
                await onboardingHealthKitManager.requestAuthorizationIfNeeded()
                await MainActor.run {
                    isWorking = false
                    advanceStep()
                }
            }
        case .done:
            onFinish(
                PillrOnboardingResult(
                    useCloudSync: useCloudSync,
                    enableBiometricLock: enableBiometricLock
                )
            )
        }
    }

    private func handleSecondaryAction() {
        switch step {
        case .biometric:
            enableBiometricLock = false
            advanceStep()
        case .notifications:
            advanceStep()
        case .health:
            advanceStep()
        default:
            break
        }
    }

    private func advanceStep() {
        guard let currentIndex = orderedSteps.firstIndex(of: step) else { return }
        guard orderedSteps.indices.contains(currentIndex + 1) else {
            onFinish(
                PillrOnboardingResult(
                    useCloudSync: useCloudSync,
                    enableBiometricLock: enableBiometricLock
                )
            )
            return
        }
        let next = orderedSteps[currentIndex + 1]
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            step = next
        }
    }

    private func runBiometricHeroShake() {
        biometricHeroShakeOffset = 0
        biometricHeroJoltScale = 1
        biometricHeroJoltYOffset = 0
        let startDelay: TimeInterval = 0.5

        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
            guard step == .biometric else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                biometricHeroJoltScale = 0.93
                biometricHeroJoltYOffset = 12
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + 0.20) {
            guard step == .biometric else { return }
            withAnimation(.spring(response: 0.60, dampingFraction: 0.72)) {
                biometricHeroJoltScale = 1.02
                biometricHeroJoltYOffset = -2
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + 1.20) {
            guard step == .biometric else { return }
            withAnimation(.easeOut(duration: 0.80)) {
                biometricHeroJoltScale = 1
                biometricHeroJoltYOffset = 0
            }
        }
    }

    private func runHeroDropIn() {
        // No-op: icon drop-in removed so icons are immediately visible on each screen.
    }

    private func runNotificationHeroRing() {
        notificationHeroRingRotation = 0
        let startDelay: TimeInterval = 0.5
        runNotificationSimulationHaptic(startDelay: startDelay)
        let sequence: [(TimeInterval, Double)] = [
            (0.18, -7),
            (0.48, 7),
            (0.80, -5.5),
            (1.12, 5.5),
            (1.42, -4),
            (1.70, 4),
            (1.88, -2),
            (1.96, 2),
            (2.00, 0)
        ]

        for (delay, angle) in sequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + delay) {
                guard step == .notifications else { return }
                withAnimation(.easeOut(duration: 0.22)) {
                    notificationHeroRingRotation = angle
                }
            }
        }
    }

    private func runNotificationSimulationHaptic(startDelay: TimeInterval) {
        let taps: [(TimeInterval, () -> Void)] = [
            (0.08, { HapticManager.shared.strongImpact() }),
            (0.26, { HapticManager.shared.rigidImpact() }),
            (0.56, { HapticManager.shared.mediumImpact() }),
            (0.92, { HapticManager.shared.selectionChanged() }),
            (1.28, { HapticManager.shared.lightImpact() })
        ]

        for (delay, haptic) in taps {
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + delay) {
                guard step == .notifications else { return }
                haptic()
            }
        }
    }

    private func runStorageHeroDriftIn() {
        storageHeroFloatYOffset = 8
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard step == .storage else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                storageHeroFloatYOffset = -12
            }
        }
    }

    private func runHealthHeroPulse() {
        healthHeroPulseScale = 0.96
        healthHeroPulseOpacity = 0.06
        startHealthHeartbeatLoop()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            guard step == .health else { return }
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                healthHeroPulseScale = 1.03
                healthHeroPulseOpacity = 0.11
            }
        }
    }

    private func startHealthHeartbeatLoop() {
        healthHeartbeatLoopToken += 1
        let token = healthHeartbeatLoopToken
        scheduleHealthHeartbeatCycle(token: token, delay: 0.35)
    }

    private func scheduleHealthHeartbeatCycle(token: Int, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard step == .health, token == healthHeartbeatLoopToken else { return }
            HapticManager.shared.rigidImpact()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                guard step == .health, token == healthHeartbeatLoopToken else { return }
                HapticManager.shared.softImpact()
            }

            // Repeat once per second while the user stays on the Apple Health onboarding screen.
            scheduleHealthHeartbeatCycle(token: token, delay: 1.0)
        }
    }

    private func runWelcomeHeroArrival() {
        welcomeHeroOpacity = 0
        welcomeHeroScale = 0.92
        welcomeHeroRotation = -12

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            guard step == .welcome else { return }
            withAnimation(.easeOut(duration: 3.2)) {
                welcomeHeroOpacity = 1
                welcomeHeroScale = 1.03
                welcomeHeroRotation = 22
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            guard step == .welcome else { return }
            withAnimation(.easeInOut(duration: 1.8)) {
                welcomeHeroScale = 1
                welcomeHeroRotation = 14
            }
        }
    }

    private func scheduleWelcomePrimaryButtonPulseHint() {
        stopWelcomePrimaryButtonPulseHint()
        let token = welcomePrimaryButtonPulseToken

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard step == .welcome, token == welcomePrimaryButtonPulseToken else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                welcomePrimaryButtonPulseScale = 1.035
                welcomePrimaryButtonPulseGlow = 0.10
            }
        }
    }

    private func stopWelcomePrimaryButtonPulseHint() {
        welcomePrimaryButtonPulseToken += 1
        welcomePrimaryButtonPulseScale = 1
        welcomePrimaryButtonPulseGlow = 0
    }

    private func runStepSoftReveal(for step: Step) {
        titleSectionVisible = false
        messageSectionVisible = false
        detailSectionVisible = false
        actionsSectionVisible = false

        let titleDelay: TimeInterval = step == .welcome ? 0.62 : 0.10
        let messageDelay: TimeInterval = step == .welcome ? 0.82 : 0.24
        let detailDelay: TimeInterval = step == .welcome ? 1.02 : 0.30
        let actionsDelay: TimeInterval = step == .welcome ? 1.14 : 0.38
        let titleDuration: TimeInterval = step == .welcome ? 0.35 : 0.30
        let messageDuration: TimeInterval = step == .welcome ? 0.45 : 0.35
        let detailDuration: TimeInterval = step == .welcome ? 0.35 : 0.35
        let actionsDuration: TimeInterval = step == .welcome ? 0.40 : 0.35

        DispatchQueue.main.asyncAfter(deadline: .now() + titleDelay) {
            guard self.step == step else { return }
            withAnimation(.easeOut(duration: titleDuration)) {
                titleSectionVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + messageDelay) {
            guard self.step == step else { return }
            withAnimation(.easeOut(duration: messageDuration)) {
                messageSectionVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + detailDelay) {
            guard self.step == step else { return }
            withAnimation(.easeOut(duration: detailDuration)) {
                detailSectionVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + actionsDelay) {
            guard self.step == step else { return }
            withAnimation(.easeOut(duration: actionsDuration)) {
                actionsSectionVisible = true
            }
        }
    }
}

private struct DoneConfettiBackgroundView: View {
    let animate: Bool

    private let pieces: [DoneConfettiPiece] = [
        DoneConfettiPiece(xPercent: 0.04, startYOffset: -90, travelMultiplier: 1.26, rotation: -28, delay: 0.00, duration: 3.8, isCapsule: false, color: Color.white.opacity(0.42), drift: -12),
        DoneConfettiPiece(xPercent: 0.08, startYOffset: -130, travelMultiplier: 1.22, rotation: 22, delay: 0.22, duration: 4.2, isCapsule: true, color: Color.pillrAccent.opacity(0.38), drift: 9),
        DoneConfettiPiece(xPercent: 0.13, startYOffset: -110, travelMultiplier: 1.28, rotation: 34, delay: 0.10, duration: 4.0, isCapsule: false, color: Color.white.opacity(0.36), drift: 7),
        DoneConfettiPiece(xPercent: 0.18, startYOffset: -150, travelMultiplier: 1.24, rotation: -15, delay: 0.36, duration: 4.3, isCapsule: true, color: Color.pillrAccent.opacity(0.4), drift: -8),
        DoneConfettiPiece(xPercent: 0.23, startYOffset: -95, travelMultiplier: 1.27, rotation: 18, delay: 0.16, duration: 3.9, isCapsule: false, color: Color.white.opacity(0.39), drift: 10),
        DoneConfettiPiece(xPercent: 0.28, startYOffset: -140, travelMultiplier: 1.2, rotation: -31, delay: 0.46, duration: 4.1, isCapsule: true, color: Color.pillrAccent.opacity(0.36), drift: -11),
        DoneConfettiPiece(xPercent: 0.33, startYOffset: -125, travelMultiplier: 1.25, rotation: 26, delay: 0.04, duration: 3.7, isCapsule: false, color: Color.white.opacity(0.35), drift: 14),
        DoneConfettiPiece(xPercent: 0.38, startYOffset: -105, travelMultiplier: 1.3, rotation: -24, delay: 0.28, duration: 4.4, isCapsule: true, color: Color.pillrAccent.opacity(0.39), drift: -6),
        DoneConfettiPiece(xPercent: 0.43, startYOffset: -155, travelMultiplier: 1.23, rotation: 21, delay: 0.14, duration: 4.2, isCapsule: false, color: Color.white.opacity(0.37), drift: 12),
        DoneConfettiPiece(xPercent: 0.48, startYOffset: -120, travelMultiplier: 1.29, rotation: -18, delay: 0.40, duration: 4.0, isCapsule: true, color: Color.pillrAccent.opacity(0.4), drift: -9),
        DoneConfettiPiece(xPercent: 0.53, startYOffset: -100, travelMultiplier: 1.24, rotation: 29, delay: 0.08, duration: 3.9, isCapsule: false, color: Color.white.opacity(0.34), drift: 8),
        DoneConfettiPiece(xPercent: 0.58, startYOffset: -145, travelMultiplier: 1.22, rotation: -12, delay: 0.52, duration: 4.3, isCapsule: true, color: Color.pillrAccent.opacity(0.37), drift: -10),
        DoneConfettiPiece(xPercent: 0.63, startYOffset: -115, travelMultiplier: 1.31, rotation: 24, delay: 0.18, duration: 4.1, isCapsule: false, color: Color.white.opacity(0.4), drift: 13),
        DoneConfettiPiece(xPercent: 0.68, startYOffset: -135, travelMultiplier: 1.23, rotation: -27, delay: 0.32, duration: 4.4, isCapsule: true, color: Color.pillrAccent.opacity(0.39), drift: -7),
        DoneConfettiPiece(xPercent: 0.73, startYOffset: -90, travelMultiplier: 1.27, rotation: 19, delay: 0.06, duration: 3.8, isCapsule: false, color: Color.white.opacity(0.38), drift: 9),
        DoneConfettiPiece(xPercent: 0.78, startYOffset: -150, travelMultiplier: 1.25, rotation: -21, delay: 0.44, duration: 4.2, isCapsule: true, color: Color.pillrAccent.opacity(0.35), drift: -12),
        DoneConfettiPiece(xPercent: 0.83, startYOffset: -108, travelMultiplier: 1.3, rotation: 31, delay: 0.12, duration: 4.0, isCapsule: false, color: Color.white.opacity(0.36), drift: 11),
        DoneConfettiPiece(xPercent: 0.88, startYOffset: -142, travelMultiplier: 1.24, rotation: -16, delay: 0.54, duration: 4.3, isCapsule: true, color: Color.pillrAccent.opacity(0.4), drift: -8),
        DoneConfettiPiece(xPercent: 0.93, startYOffset: -118, travelMultiplier: 1.26, rotation: 27, delay: 0.24, duration: 4.1, isCapsule: false, color: Color.white.opacity(0.35), drift: 10),
        DoneConfettiPiece(xPercent: 0.97, startYOffset: -132, travelMultiplier: 1.21, rotation: -23, delay: 0.60, duration: 4.4, isCapsule: true, color: Color.pillrAccent.opacity(0.38), drift: -9)
    ]

    @State private var shouldFall = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(pieces.enumerated()), id: \.offset) { index, piece in
                    Group {
                        if piece.isCapsule {
                            Capsule()
                                .fill(piece.color)
                                .frame(width: 5, height: 14)
                        } else {
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(piece.color)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .rotationEffect(.degrees(piece.rotation))
                    .position(
                        x: (geo.size.width * piece.xPercent) + (shouldFall ? piece.drift : 0),
                        y: shouldFall ? (geo.size.height * piece.travelMultiplier) : piece.startYOffset
                    )
                    .opacity(animate ? 0.5 : 0)
                    .animation(
                        .linear(duration: piece.duration)
                            .delay(piece.delay)
                            .repeatForever(autoreverses: false),
                        value: shouldFall
                    )
                    .onAppear {
                        if animate {
                            DispatchQueue.main.asyncAfter(deadline: .now() + piece.delay + (Double(index) * 0.01)) {
                                shouldFall = true
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: animate) { _, isAnimating in
            shouldFall = false
            guard isAnimating else { return }
            DispatchQueue.main.async {
                shouldFall = true
            }
        }
    }
}

private struct DoneConfettiPiece {
    let xPercent: CGFloat
    let startYOffset: CGFloat
    let travelMultiplier: CGFloat
    let rotation: Double
    let delay: Double
    let duration: Double
    let isCapsule: Bool
    let color: Color
    let drift: CGFloat
}

private struct PillrOnboardingOptionCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.pillrBackground)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.pillrSecondary.opacity(0.86))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color.pillrBackground.opacity(isSelected ? 0.95 : 0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.14 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.42 : 0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct BiometricAppLockOverlay: View {
    let biometryType: PillrBiometricType
    let isUnlocking: Bool
    let errorMessage: String?
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.pillrPrimary,
                    Color.pillrPrimary
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: biometryType.iconName)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundColor(Color.pillrBackground)
                    .padding(.bottom, 2)

                Text("Unlock Pillr")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color.pillrBackground)

                Text("Authenticate with \(biometryType.displayName) to access your medications.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color.pillrSecondary.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color.pillrSecondary.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                Button(action: onUnlock) {
                    HStack(spacing: 10) {
                        if isUnlocking {
                            ProgressView()
                                .tint(Color.pillrPrimary)
                        }

                        Text(isUnlocking ? "Unlocking..." : "Unlock with \(biometryType.displayName)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.pillrPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.pillrBackground)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isUnlocking)
                .padding(.top, 4)
            }
            .padding(.horizontal, 26)
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
                    accentColor: Color.pillrAccent,
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
                    accentColor: Color.pillrAccent,
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
                    accentColor: Color.pillrAccent,
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
