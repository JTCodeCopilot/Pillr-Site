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
    @State private var showWelcomeOnboardingFlow = false
    @State private var showBiometricAppLock = false
    @State private var isBiometricAuthInProgress = false
    @State private var biometricLockErrorMessage: String?
    @State private var requiresBiometricOnNextActive = true
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

    private var onboardingOverlayAnimation: Animation {
        .spring(response: 0.5, dampingFraction: 0.88)
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
                if showWelcomeOnboardingFlow {
                    PillrWelcomeOnboardingFlow { result in
                        completeWelcomeOnboarding(using: result)
                    }
                    .transition(.opacity)
                    .zIndex(5)
                }
                if showBiometricAppLock && !showWelcomeOnboardingFlow {
                    BiometricAppLockOverlay(
                        biometryType: BiometricLockCoordinator.availableBiometryType(),
                        isUnlocking: isBiometricAuthInProgress,
                        errorMessage: biometricLockErrorMessage,
                        onUnlock: requestBiometricUnlock
                    )
                    .transition(.opacity)
                    .zIndex(6)
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
            startWelcomeOnboardingIfNeeded()
            if !showWelcomeOnboardingFlow {
                scheduleOnboarding(for: selectedTab)
            }
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
        .onChange(of: showWelcomeOnboardingFlow) { _, showing in
            if !showing {
                handleBiometricGateIfNeeded()
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
            scheduleOnboarding(for: selectedTab)
            scheduleReviewPromptIfNeeded()
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

    private let biometryType = BiometricLockCoordinator.availableBiometryType()

    private enum Step: Int, CaseIterable {
        case welcome
        case biometric
        case notifications
        case storage
        case done
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#404C42"),
                        Color(hex: "#3A443D")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if step == .done {
                    DoneConfettiBackgroundView(animate: runDoneConfetti)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 3)
                        .overlay(alignment: .leading) {
                            GeometryReader { progressGeo in
                                Capsule()
                                    .fill(Color(hex: "#F5F7F4"))
                                    .frame(width: progressGeo.size.width * progressFraction, height: 3)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, geometry.safeAreaInsets.top + 6)

                    VStack(spacing: 26) {
                        Group {
                            if step == .done {
                                Color.clear
                                    .frame(width: 248, height: 170)
                            } else {
                                onboardingHeroImage(
                                    assetName: heroAssetName,
                                    fallbackSystemName: iconName,
                                    size: 248
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 14, x: 0, y: 7)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 170, maxHeight: 170, alignment: .top)
                        .padding(.bottom, 64)

                        VStack(spacing: 12) {
                            Text(title)
                                .font(.system(size: 48, weight: .regular, design: .rounded))
                                .foregroundColor(Color(hex: "#F5F7F4"))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)

                            Text(message)
                                .font(step == .welcome ? .system(size: 22, weight: .semibold, design: .rounded) : .system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: "#E0E7DC").opacity(0.94))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.top, step == .welcome ? 14 : 0)
                                .padding(.horizontal, 16)
                        }

                        if step == .storage {
                            VStack(spacing: 10) {
                                PillrOnboardingOptionCard(
                                    title: "Use iCloud Sync",
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
                            .padding(.top, 4)
                        }

                        if let helperMessage {
                            Text(helperMessage)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: "#E0E7DC").opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 18)
                        }
                    }
                    .padding(.top, 26)
                    .padding(.horizontal, 22)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.spring(response: 0.42, dampingFraction: 0.84), value: step)

                    Spacer(minLength: 20)

                    VStack(spacing: 14) {
                        Button(action: handlePrimaryAction) {
                            HStack(spacing: 10) {
                                if isWorking {
                                    ProgressView()
                                        .tint(Color(hex: "#11140F"))
                                } else if step == .biometric && biometryType != .none {
                                    Image(systemName: biometryType.iconName)
                                        .font(.system(size: 18, weight: .semibold))
                                }

                                Text(primaryButtonTitle)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(Color(hex: "#11140F"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#F5F7F4"))
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isWorking)

                        if let secondaryTitle = secondaryButtonTitle {
                            Button(action: handleSecondaryAction) {
                                Text(secondaryTitle)
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(hex: "#E0E7DC").opacity(0.88))
                                    .underline()
                            }
                            .buttonStyle(.plain)
                            .disabled(isWorking)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 22)
                }
            }
        }
        .onChange(of: step) { _, newStep in
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

    private var progressFraction: CGFloat {
        CGFloat(step.rawValue + 1) / CGFloat(Step.allCases.count)
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
                            Color(hex: "#5F6F61"),
                            Color(hex: "#404C42")
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size + 24, height: size + 24)
                .overlay {
                    Image(systemName: fallbackSystemName)
                        .font(.system(size: size * 0.45, weight: .medium))
                        .foregroundColor(Color(hex: "#F5F7F4"))
                }
        }
    }

    private var title: String {
        switch step {
        case .welcome:
            return "Welcome to Pillr"
        case .biometric:
            return "Protect your medications"
        case .notifications:
            return "Stay on schedule"
        case .storage:
            return "Choose your storage"
        case .done:
            return "You’re all set"
        }
    }

    private var message: String {
        switch step {
        case .welcome:
            return "Designed by the ADHD community for the ADHD community"
        case .biometric:
            if biometryType == .none {
                return "This device does not support Face ID or Touch ID. You can continue without app lock."
            }
            return "Use \(biometryType.displayName) so only you can open Pillr."
        case .notifications:
            return "Turn on reminders so you do not miss a dose."
        case .storage:
            return "Choose where Pillr stores your medication data."
        case .done:
            return "Your medication tracker is ready to use."
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome:
            return "Let's get started"
        case .biometric:
            return biometryType == .none ? "Continue" : "Enable \(biometryType.displayName)"
        case .notifications:
            return "Turn on notifications"
        case .storage:
            return "Continue"
        case .done:
            return "Continue to My Meds"
        }
    }

    private var secondaryButtonTitle: String? {
        switch step {
        case .biometric where biometryType != .none:
            return "Not now"
        case .notifications:
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
            NotificationManager.shared.requestAuthorization { _ in
                DispatchQueue.main.async {
                    isWorking = false
                    advanceStep()
                }
            }
        case .storage:
            advanceStep()
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
        default:
            break
        }
    }

    private func advanceStep() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            step = next
        }
    }
}

private struct DoneConfettiBackgroundView: View {
    let animate: Bool

    private let pieces: [DoneConfettiPiece] = [
        DoneConfettiPiece(xPercent: 0.04, startYOffset: -90, travelMultiplier: 1.26, rotation: -28, delay: 0.00, duration: 3.8, isCapsule: false, color: Color.white.opacity(0.42), drift: -12),
        DoneConfettiPiece(xPercent: 0.08, startYOffset: -130, travelMultiplier: 1.22, rotation: 22, delay: 0.22, duration: 4.2, isCapsule: true, color: Color(hex: "#B9D2BC").opacity(0.38), drift: 9),
        DoneConfettiPiece(xPercent: 0.13, startYOffset: -110, travelMultiplier: 1.28, rotation: 34, delay: 0.10, duration: 4.0, isCapsule: false, color: Color.white.opacity(0.36), drift: 7),
        DoneConfettiPiece(xPercent: 0.18, startYOffset: -150, travelMultiplier: 1.24, rotation: -15, delay: 0.36, duration: 4.3, isCapsule: true, color: Color(hex: "#A9C4AD").opacity(0.4), drift: -8),
        DoneConfettiPiece(xPercent: 0.23, startYOffset: -95, travelMultiplier: 1.27, rotation: 18, delay: 0.16, duration: 3.9, isCapsule: false, color: Color.white.opacity(0.39), drift: 10),
        DoneConfettiPiece(xPercent: 0.28, startYOffset: -140, travelMultiplier: 1.2, rotation: -31, delay: 0.46, duration: 4.1, isCapsule: true, color: Color(hex: "#BCD4BF").opacity(0.36), drift: -11),
        DoneConfettiPiece(xPercent: 0.33, startYOffset: -125, travelMultiplier: 1.25, rotation: 26, delay: 0.04, duration: 3.7, isCapsule: false, color: Color.white.opacity(0.35), drift: 14),
        DoneConfettiPiece(xPercent: 0.38, startYOffset: -105, travelMultiplier: 1.3, rotation: -24, delay: 0.28, duration: 4.4, isCapsule: true, color: Color(hex: "#A8C3AC").opacity(0.39), drift: -6),
        DoneConfettiPiece(xPercent: 0.43, startYOffset: -155, travelMultiplier: 1.23, rotation: 21, delay: 0.14, duration: 4.2, isCapsule: false, color: Color.white.opacity(0.37), drift: 12),
        DoneConfettiPiece(xPercent: 0.48, startYOffset: -120, travelMultiplier: 1.29, rotation: -18, delay: 0.40, duration: 4.0, isCapsule: true, color: Color(hex: "#BCD4BF").opacity(0.4), drift: -9),
        DoneConfettiPiece(xPercent: 0.53, startYOffset: -100, travelMultiplier: 1.24, rotation: 29, delay: 0.08, duration: 3.9, isCapsule: false, color: Color.white.opacity(0.34), drift: 8),
        DoneConfettiPiece(xPercent: 0.58, startYOffset: -145, travelMultiplier: 1.22, rotation: -12, delay: 0.52, duration: 4.3, isCapsule: true, color: Color(hex: "#A9C4AD").opacity(0.37), drift: -10),
        DoneConfettiPiece(xPercent: 0.63, startYOffset: -115, travelMultiplier: 1.31, rotation: 24, delay: 0.18, duration: 4.1, isCapsule: false, color: Color.white.opacity(0.4), drift: 13),
        DoneConfettiPiece(xPercent: 0.68, startYOffset: -135, travelMultiplier: 1.23, rotation: -27, delay: 0.32, duration: 4.4, isCapsule: true, color: Color(hex: "#B9D2BC").opacity(0.39), drift: -7),
        DoneConfettiPiece(xPercent: 0.73, startYOffset: -90, travelMultiplier: 1.27, rotation: 19, delay: 0.06, duration: 3.8, isCapsule: false, color: Color.white.opacity(0.38), drift: 9),
        DoneConfettiPiece(xPercent: 0.78, startYOffset: -150, travelMultiplier: 1.25, rotation: -21, delay: 0.44, duration: 4.2, isCapsule: true, color: Color(hex: "#BCD4BF").opacity(0.35), drift: -12),
        DoneConfettiPiece(xPercent: 0.83, startYOffset: -108, travelMultiplier: 1.3, rotation: 31, delay: 0.12, duration: 4.0, isCapsule: false, color: Color.white.opacity(0.36), drift: 11),
        DoneConfettiPiece(xPercent: 0.88, startYOffset: -142, travelMultiplier: 1.24, rotation: -16, delay: 0.54, duration: 4.3, isCapsule: true, color: Color(hex: "#A8C3AC").opacity(0.4), drift: -8),
        DoneConfettiPiece(xPercent: 0.93, startYOffset: -118, travelMultiplier: 1.26, rotation: 27, delay: 0.24, duration: 4.1, isCapsule: false, color: Color.white.opacity(0.35), drift: 10),
        DoneConfettiPiece(xPercent: 0.97, startYOffset: -132, travelMultiplier: 1.21, rotation: -23, delay: 0.60, duration: 4.4, isCapsule: true, color: Color(hex: "#A9C4AD").opacity(0.38), drift: -9)
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
                        .foregroundColor(Color(hex: "#F5F7F4"))

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "#E0E7DC").opacity(0.86))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "#F5F7F4").opacity(isSelected ? 0.95 : 0.45))
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
                    Color(hex: "#404C42"),
                    Color(hex: "#3A443D")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: biometryType.iconName)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundColor(Color(hex: "#F5F7F4"))
                    .padding(.bottom, 2)

                Text("Unlock Pillr")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#F5F7F4"))

                Text("Authenticate with \(biometryType.displayName) to access your medications.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#E0E7DC").opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "#E0E7DC").opacity(0.78))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                Button(action: onUnlock) {
                    HStack(spacing: 10) {
                        if isUnlocking {
                            ProgressView()
                                .tint(Color(hex: "#11140F"))
                        }

                        Text(isUnlocking ? "Unlocking..." : "Unlock with \(biometryType.displayName)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: "#11140F"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#F5F7F4"))
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
