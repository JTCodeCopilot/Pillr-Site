//
//  MedicationsListView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI
import UIKit
import UserNotifications
import Combine

final class AddMedicationFlowCoordinator: ObservableObject {
    @Published var isShowing = false
    @Published var hasUnsavedChanges = false
    @Published var dismissTrigger = UUID()
    @Published var resetTrigger = UUID()

    func discardFlow() {
        hasUnsavedChanges = false
        isShowing = false
        dismissTrigger = UUID()
        resetTrigger = UUID()
    }
}

@MainActor
struct MedicationsListView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var addFlowCoordinator: AddMedicationFlowCoordinator
    @State private var showingLogSheetFor: Medication?
    @State private var showingDailyCheckInFor: Medication?
    @State private var selectedMedicationToEdit: Medication?
    @State private var showingAddSheet = false
    @State private var scrolledOffset: CGFloat = 0
    @StateObject private var healthKitManager = HealthKitManager()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var medicationToDelete: Medication? = nil
    @State private var logToDelete: MedicationLog? = nil
    @State private var showDeleteAlert = false
    @State private var showingInteractionSheet = false
    @State private var showingMedicationSelectionSheet = false
    @State private var interactionCheckError: String? = nil
    @State private var foundInteractions: [DrugInteraction]? = nil
    @State private var isCheckingInteractions = false
    @State private var showingInteractionResultSheet = false
    @State private var showingPremiumUpgrade = false
    @State private var showingFocusTimeline = false
    @State private var showingCabinetSheet = false
    @State private var activeCustomLogRequest: CustomLogRequest?
    @State private var refillPromptMedication: Medication?
    @State private var showCabinetIntroOverlay = false
    @State private var referenceDate = Date()
    private let referenceTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let healthRefreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var undoToastAction: MedicationStore.LogUndoAction?
    @State private var undoToastDismissWorkItem: DispatchWorkItem?
    @State private var dashboardHighlightedMedicationIDs = Set<UUID>()
    @State private var dashboardHighlightResetWorkItem: DispatchWorkItem?
    @State private var suppressAutoExpandForHighlightedMedicationID: UUID?
    private let undoToastDuration: TimeInterval = 5.0
    @State private var isViewActive = false
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus?
    @State private var visibleInteractionPromptMedicationID: UUID?

    private struct CustomLogRequest: Identifiable {
        let id = UUID()
        let medication: Medication
        let reminderIndex: Int?
    }

    private var reminderMedications: [Medication] {
        store.activeMedications.filter { !$0.isCabinetMedication }
    }
    
    private var cabinetMedications: [Medication] {
        store.activeMedications.filter { $0.isCabinetMedication }
    }

    private var shouldShowNotificationEnableBanner: Bool {
        guard let status = notificationAuthorizationStatus else { return false }
        switch status {
        case .authorized, .provisional, .ephemeral:
            return false
        default:
            return true
        }
    }

    init(addFlowCoordinator: AddMedicationFlowCoordinator = AddMedicationFlowCoordinator()) {
        self._addFlowCoordinator = ObservedObject(wrappedValue: addFlowCoordinator)
    }

    private var cabinetLogMedications: [Medication] {
        let calendar = Calendar.current
        return cabinetMedications.flatMap { medication in
            let todaysLogs = store.logs.filter { log in
                log.medicationID == medication.id &&
                !log.hiddenFromMyMeds &&
                log.isDoseLog &&
                calendar.isDate(log.takenAt, inSameDayAs: referenceDate)
            }
            return todaysLogs.map { log in
                createCabinetLogCard(from: medication, log: log)
            }
        }
    }

    private var displayedMedications: [Medication] {
        reminderMedications + cabinetLogMedications
    }

    private var recentInteractionPromptMedication: Medication? {
        guard let lastAddedID = visibleInteractionPromptMedicationID else { return nil }
        return store.findMedication(with: lastAddedID)
    }

    private var canShowInteractionPrompt: Bool {
        recentInteractionPromptMedication != nil
    }

    private var hasInteractionAccess: Bool {
        userSettings.hasAIAccess()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                        MedicationsListMainContent(
                        store: store,
                        showingAddSheet: $showingAddSheet,
                        scrolledOffset: $scrolledOffset,
                        dashboardHighlightedMedicationIDs: $dashboardHighlightedMedicationIDs,
                        selectedMedicationToEdit: $selectedMedicationToEdit,
                        medicationToDelete: $medicationToDelete,
                        logToDelete: $logToDelete,
                        showDeleteAlert: $showDeleteAlert,
                        showingInteractionSheet: $showingInteractionSheet,
                        isCheckingInteractions: $isCheckingInteractions,
                        onCheckAllInteractions: showMedicationSelectionSheet,
                        onOpenInteractionChecker: openInteractionCheckerSheet,
                        onShowPremiumUpgrade: { showingPremiumUpgrade = true },
                        onAddMedication: handleAddMedication,
                        onShowFocusTimeline: { showingFocusTimeline = true },
                        onPresentUndoToast: presentUndoToast,
                        onRequestCustomLogTimeAction: requestCustomLogTime,
                        onRequestRefillResetAction: presentRefillPrompt,
                        onPresentDailyCheckIn: presentDailyCheckIn,
                        displayedMedications: displayedMedications,
                        cabinetMedications: cabinetMedications,
                        onShowCabinet: handleCabinetTap,
                        suppressAutoExpandForHighlightedMedicationID: $suppressAutoExpandForHighlightedMedicationID,
                        healthKitManager: healthKitManager,
                        referenceDate: referenceDate,
                        onHighlightOverdueMedications: highlightOverdueMedications,
                        onHighlightLowSupplyMedications: highlightLowSupplyMedications,
                )
                .overlay(alignment: .bottom) {
                    if let action = undoToastAction {
                        LogUndoToastView(
                            action: action,
                            onUndo: {
                                store.undoLogAction(action)
                                dismissUndoToast()
                            },
                            onDismiss: dismissUndoToast
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .safeAreaInset(edge: .top) {
                    VStack(spacing: 8) {
                        if shouldShowNotificationEnableBanner {
                            notificationEnableBanner
                        }

                        if canShowInteractionPrompt, let recentMedication = recentInteractionPromptMedication {
                            InteractionPromptCard(
                                medicationName: recentMedication.name,
                                hasAccess: hasInteractionAccess,
                                onCheck: {
                                    Task { await showMedicationSelectionSheet() }
                                    dismissInteractionPrompt()
                                },
                                onUpgrade: {
                                    showingPremiumUpgrade = true
                                    dismissInteractionPrompt()
                                },
                                onDismiss: dismissInteractionPrompt
                            )
                            .transition(
                                .asymmetric(
                                    insertion: .offset(y: -14).combined(with: .opacity),
                                    removal: .offset(y: -56).combined(with: .scale(scale: 0.97, anchor: .top)).combined(with: .opacity)
                                )
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: shouldShowNotificationEnableBanner)
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: canShowInteractionPrompt)
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: store.lastAddedMedicationID)
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: notificationAuthorizationStatus)
            }
            .navigationDestination(isPresented: $showingAddSheet) {
                addMedicationDestination
            }
            .sheet(item: $showingLogSheetFor) { med in
                LogMedicationView(medicationToLog: med, onLogAction: presentUndoToast)
                    .environmentObject(store)
            }
            .sheet(item: $showingDailyCheckInFor, onDismiss: {
                showingDailyCheckInFor = nil
            }) { med in
                LogMedicationView(
                    medicationToLog: med,
                    isDailyCheckIn: true,
                    checkInLogID: nil,
                    onLogAction: presentUndoToast
                )
                .environmentObject(store)
            }
            .sheet(item: $activeCustomLogRequest) { request in
                MedicationLogTimePickerSheet(
                    medication: request.medication,
                    onCancel: {
                        activeCustomLogRequest = nil
                    },
                    onConfirm: { selectedTime in
                        logMedication(request.medication, at: selectedTime, reminderIndex: request.reminderIndex)
                        activeCustomLogRequest = nil
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.pillrPrimary.opacity(0.35))
            }
            .sheet(item: $refillPromptMedication) { med in
                RefillResetSheet(
                    medication: med,
                    previousBottleAmount: previousRefillAmount(for: med),
                    onCancel: {
                        refillPromptMedication = nil
                    },
                    onSave: { newCount, newThreshold in
                        applyRefillReset(for: med, pillCount: newCount, refillThreshold: newThreshold)
                        refillPromptMedication = nil
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.pillrPrimary.opacity(0.35))
            }
            .fullScreenCover(item: $selectedMedicationToEdit) { med in
                NavigationView {
                    AddMedicationView(
                        medicationToEdit: med,
                        onFinish: { selectedMedicationToEdit = nil }
                    )
                    .environmentObject(store)
                    .environmentObject(userSettings)
                }
            }
            .sheet(isPresented: $showingMedicationSelectionSheet) {
                MedicationInteractionSelectionSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingInteractionResultSheet) {
                InteractionResultsSheetView(
                    isPresented: $showingInteractionResultSheet,
                    interactions: foundInteractions ?? [],
                    error: interactionCheckError
                )
            }
            .alert(isPresented: $showDeleteAlert) {
                let isDeletingLogEntry = logToDelete != nil
                return Alert(
                    title: Text(isDeletingLogEntry ? "Hide Log Entry" : "Delete Medication"),
                    message: Text(
                        isDeletingLogEntry
                            ? "Hiding this entry removes it from the My Meds view only; the cabinet copy and history entry stay intact, and you can fully remove the medication from the Cabinet if needed."
                            : "Deleting \(medicationToDelete?.name ?? "this medication") will permanently remove it and it cannot be restored unless you enter it again."
                    ),
                    primaryButton: .destructive(Text(isDeletingLogEntry ? "Hide from My Meds" : "Delete")) {
                        if let med = medicationToDelete {
                            store.deleteMedication(med)
                        } else if let log = logToDelete {
                            store.hideLogFromMyMeds(log)
                        }
                        medicationToDelete = nil
                        logToDelete = nil
                    },
                    secondaryButton: .cancel {
                        medicationToDelete = nil
                        logToDelete = nil
                    }
                )
            }
            .sheet(isPresented: $showingPremiumUpgrade) {
                PremiumUpgradeView()
                    .environmentObject(StoreManager.shared)
            }
            .sheet(isPresented: $showingFocusTimeline) {
                FocusTimelineView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingCabinetSheet, onDismiss: {
                showCabinetIntroOverlay = false
            }) {
                MedicationCabinetSheet(
                    medications: cabinetMedications,
                    logs: store.logs,
                    referenceDate: referenceDate,
                    onLogMedication: { presentLogSheet(for: $0) },
                    onEditMedication: { presentEditSheet(for: $0) },
                    onDeleteMedication: { med in
                        HapticManager.shared.warningNotification()
                        showingCabinetSheet = false
                        medicationToDelete = store.findMedication(with: med.id) ?? med
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showDeleteAlert = true
                        }
                    },
                    showCabinetIntroOverlay: $showCabinetIntroOverlay
                )
            }
            .sheet(item: $store.dailyCheckInContext, onDismiss: {
                store.dailyCheckInContext = nil
                store.presentNextPendingCheckInIfNeeded()
            }) { context in
                LogMedicationView(
                    medicationToLog: context.medication,
                    isDailyCheckIn: true,
                    isNotificationEntry: context.entrySource == .notification,
                    checkInLogID: context.logID,
                    onLogAction: presentUndoToast
                )
                .environmentObject(store)
            }
            .sheet(item: $store.recentADHDDoseTimeline, onDismiss: {
                store.recentADHDDoseTimeline = nil
            }) { entry in
                ADHDDoseTimelineSheet(entry: entry)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onReceive(referenceTimer) { output in
                guard scenePhase == .active else { return }
                referenceDate = output
                store.refreshOverdueMedicationIDs(referenceDate: output)
            }
            .onChange(of: store.logs) { _, _ in
                guard scenePhase == .active else { return }
                refreshReferenceDate(resetBadge: false)
            }
            .onChange(of: store.medications) { _, _ in
                guard scenePhase == .active else { return }
                refreshReferenceDate(resetBadge: false)
            }
            .refreshable {
                await performPullToRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                refreshReferenceDate(resetBadge: false)
            }
            .onReceive(healthRefreshTimer) { _ in
                guard scenePhase == .active, isViewActive else { return }
                Task {
                    await healthKitManager.refreshAuthorizationState()
                    await healthKitManager.refreshMetrics()
                }
            }
            .onAppear {
                isViewActive = true
                refreshNotificationPermissionStatus()
                presentInteractionPromptIfNeeded(after: 0.2)
                Task {
                    await healthKitManager.refreshAuthorizationState()
                    await healthKitManager.refreshMetrics()
                }
            }
            .onDisappear {
                isViewActive = false
                dashboardHighlightResetWorkItem?.cancel()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    refreshReferenceDate(resetBadge: true)
                    refreshNotificationPermissionStatus()
                    Task {
                        await healthKitManager.refreshAuthorizationState()
                        await healthKitManager.refreshMetrics()
                    }
                }
            }
            .task {
                await healthKitManager.refreshAuthorizationState()
                refreshNotificationPermissionStatus()
            }
            .onChange(of: addFlowCoordinator.dismissTrigger) { _, _ in
                if showingAddSheet {
                    showingAddSheet = false
                }
            }
            .onChange(of: showingAddSheet) { _, isActive in
                addFlowCoordinator.isShowing = isActive
                addFlowCoordinator.hasUnsavedChanges = isActive ? true : false
                if !isActive {
                    presentInteractionPromptIfNeeded(after: 0.22)
                }
            }
            .onChange(of: store.lastAddedMedicationID) { _, newValue in
                guard newValue != nil, !showingAddSheet else { return }
                presentInteractionPromptIfNeeded(after: 0.12)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    private func handleCabinetTap() {
        if !userSettings.hasSeenCabinetIntroOverlay {
            showCabinetIntroOverlay = true
            userSettings.markCabinetIntroOverlaySeen()
        }
        showingCabinetSheet = true
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60

        if hours == 0 {
            return "\(minutes) min"
        }
        if remainder == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(remainder) min"
    }

    private func showMedicationSelectionSheet() async {
        if userSettings.hasAIAccess() {
            showingMedicationSelectionSheet = true
        } else {
            showingPremiumUpgrade = true
        }
    }

    private func openInteractionCheckerSheet() {
        showingMedicationSelectionSheet = true
        dismissInteractionPrompt()
    }

    private func presentInteractionPromptIfNeeded(after delay: TimeInterval = 0) {
        guard let lastAddedID = store.lastAddedMedicationID,
              store.activeMedications.count >= 2,
              store.findMedication(with: lastAddedID) != nil else {
            visibleInteractionPromptMedicationID = nil
            return
        }

        let showPrompt = {
            withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.82, blendDuration: 0.18)) {
                visibleInteractionPromptMedicationID = lastAddedID
            }
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                showPrompt()
            }
        } else {
            showPrompt()
        }
    }

    private func dismissInteractionPrompt() {
        withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.72, blendDuration: 0.2)) {
            visibleInteractionPromptMedicationID = nil
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            store.lastAddedMedicationID = nil
        }
    }

    private func refreshReferenceDate(resetBadge: Bool) {
        referenceDate = Date()
        store.refreshOverdueMedicationIDs(referenceDate: referenceDate)
        if resetBadge {
            store.checkAndResetBadge()
        }
    }

    private func refreshNotificationPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationAuthorizationStatus = settings.authorizationStatus
            }
        }
    }

    private func openNotificationSettings() {
        let urlString: String
        if #available(iOS 16.0, *) {
            urlString = UIApplication.openNotificationSettingsURLString
        } else {
            urlString = UIApplication.openSettingsURLString
        }
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func performPullToRefresh() async {
        await MainActor.run {
            store.loadMedications()
            store.loadLogs()
            refreshReferenceDate(resetBadge: true)
            refreshNotificationPermissionStatus()
        }
    }

    private func highlightOverdueMedications() {
        let overdueIDs = store.overdueMedicationIDs
        guard !overdueIDs.isEmpty else { return }

        dashboardHighlightResetWorkItem?.cancel()
        dashboardHighlightedMedicationIDs = overdueIDs

        if let firstOverdue = sortedMedications(displayedMedications, logs: store.logs, referenceDate: referenceDate)
            .first(where: { overdueIDs.contains($0.logReferenceID ?? $0.id) }) {
            suppressAutoExpandForHighlightedMedicationID = firstOverdue.id
            store.highlightedMedicationID = firstOverdue.id
        }

        let workItem = DispatchWorkItem {
            dashboardHighlightedMedicationIDs = []
        }
        dashboardHighlightResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }

    private func highlightLowSupplyMedications() {
        let lowSupplyIDs = Set(
            store.activeMedications.compactMap { medication -> UUID? in
                guard let pillCount = medication.pillCount,
                      let refillThreshold = medication.refillThreshold,
                      pillCount <= refillThreshold else {
                    return nil
                }
                return medication.id
            }
        )
        guard !lowSupplyIDs.isEmpty else { return }

        dashboardHighlightResetWorkItem?.cancel()
        dashboardHighlightedMedicationIDs = lowSupplyIDs

        if let firstLowSupply = sortedMedications(displayedMedications, logs: store.logs, referenceDate: referenceDate)
            .first(where: { lowSupplyIDs.contains($0.logReferenceID ?? $0.id) }) {
            store.highlightedMedicationID = firstLowSupply.id
            store.expandedMedicationID = firstLowSupply.id
        }

        let workItem = DispatchWorkItem {
            dashboardHighlightedMedicationIDs = []
        }
        dashboardHighlightResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }

    private var notificationEnableBanner: some View {
        HStack(spacing: 12) {
            Text("Turn on notifications to get medication reminders.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineSpacing(2)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, alignment: .center)
                Button(action: openNotificationSettings) {
                    Text("Enable")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.pillrBackground)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(Color.pillrPrimary)
                                .overlay(
                                    Capsule()
                                        .stroke(Color(hex: "#FFB74D").opacity(0.8), lineWidth: 1)
                                )
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.pillrPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: "#FFB74D").opacity(0.8), lineWidth: 1)
                )
        )
    }
    
    private func handleAddMedication() {
        let currentActiveMedications = store.activeMedications.count
        if userSettings.canAddMedication(currentCount: currentActiveMedications) {
            presentAddMedicationFlow()
        } else {
            showingPremiumUpgrade = true
        }
    }
    
    private func presentAddMedicationFlow() {
        addFlowCoordinator.resetTrigger = UUID()
        showingAddSheet = true
    }
    
    private func dismissAddMedicationFlow() {
        showingAddSheet = false
    }
    
    @ViewBuilder
    private var addMedicationDestination: some View {
        AddMedicationView(
            onFinish: { dismissAddMedicationFlow() },
            resetTrigger: addFlowCoordinator.resetTrigger
        )
            .environmentObject(store)
            .environmentObject(userSettings)
            .toolbar(.hidden, for: .navigationBar)
    }
    
    private func checkAllMedicationInteractions() async {
        guard !store.activeMedications.isEmpty else {
            self.interactionCheckError = "You don't have any active medications to check."
            self.showingInteractionResultSheet = true
            return
        }
        
        guard store.activeMedications.count >= 2 else {
            self.interactionCheckError = "You need at least 2 active medications to check for interactions."
            self.showingInteractionResultSheet = true
            return
        }
        
        isCheckingInteractions = true
        self.interactionCheckError = nil
        self.foundInteractions = nil
        
        // AI interaction checking functionality removed
        self.interactionCheckError = "Interaction checking feature has been removed"
        
        isCheckingInteractions = false
        showingInteractionResultSheet = true
    }
    
    private func presentLogSheet(for medication: Medication) {
        let resolvedMedication = store.findMedication(with: medication.logReferenceID ?? medication.id) ?? medication
        if shouldAutoLogCabinetMedication(medication) {
            quickLogCabinetMedication(resolvedMedication)
            return
        }
        
        showingCabinetSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showingLogSheetFor = resolvedMedication
        }
    }

    private func presentDailyCheckIn(for medication: Medication) {
        let resolvedMedication = store.findMedication(with: medication.logReferenceID ?? medication.id) ?? medication
        showingLogSheetFor = nil
        activeCustomLogRequest = nil
        showingCabinetSheet = false
        store.dailyCheckInContext = nil
        showingDailyCheckInFor = resolvedMedication
    }

    private func shouldAutoLogCabinetMedication(_ medication: Medication) -> Bool {
        guard medication.isCabinetMedication else { return false }
        return medication.frequency.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "as needed".lowercased()
    }

    private func requestCustomLogTime(for medication: Medication, reminderIndex: Int? = nil) {
        activeCustomLogRequest = CustomLogRequest(medication: medication, reminderIndex: reminderIndex)
    }

    private func presentRefillPrompt(for medication: Medication) {
        let resolvedMedication = store.findMedication(with: medication.logReferenceID ?? medication.id) ?? medication
        refillPromptMedication = resolvedMedication
    }

    private func applyRefillReset(for medication: Medication, pillCount: Int, refillThreshold: Int) {
        let resolvedMedication = store.findMedication(with: medication.logReferenceID ?? medication.id) ?? medication
        var updatedMedication = resolvedMedication
        updatedMedication.pillCount = pillCount
        updatedMedication.refillThreshold = refillThreshold
        if updatedMedication.pillsPerDose <= 0 {
            updatedMedication.pillsPerDose = 1
        }
        store.updateMedication(updatedMedication, enableNotification: resolvedMedication.shouldScheduleReminder)
        saveLastRefillValues(bottleAmount: pillCount, refillThreshold: refillThreshold, for: updatedMedication.id)
        HapticManager.shared.successNotification()
    }

    private func refillAmountStorageKeyV2(for medicationID: UUID) -> String {
        "last_refill_bottle_amount_v2_\(medicationID.uuidString)"
    }

    private func refillThresholdStorageKeyV2(for medicationID: UUID) -> String {
        "last_refill_threshold_v2_\(medicationID.uuidString)"
    }

    private func lastRefillAmount(for medication: Medication) -> Int? {
        let medicationID = medication.logReferenceID ?? medication.id
        let bottleKeyV2 = refillAmountStorageKeyV2(for: medicationID)
        if UserDefaults.standard.object(forKey: bottleKeyV2) != nil {
            return UserDefaults.standard.integer(forKey: bottleKeyV2)
        }
        return nil
    }

    private func previousRefillAmount(for medication: Medication) -> Int? {
        if let savedLast = lastRefillAmount(for: medication) {
            return savedLast
        }

        if let originalTotal = medication.initialPillCount {
            return originalTotal
        }

        return estimatedBottleAmount(for: medication)
    }

    private func estimatedBottleAmount(for medication: Medication) -> Int? {
        guard let currentPillCount = medication.pillCount else { return nil }

        let medicationID = medication.logReferenceID ?? medication.id
        let consumedTotal = store.logs
            .filter { log in
                log.medicationID == medicationID && log.isDoseLog && !log.skipped
            }
            .reduce(0) { partial, log in
                let consumed = log.pillsConsumed ?? medication.pillsPerDose
                return partial + max(consumed, 0)
            }

        return currentPillCount + consumedTotal
    }

    private func saveLastRefillValues(bottleAmount: Int, refillThreshold: Int, for medicationID: UUID) {
        let bottleKeyV2 = refillAmountStorageKeyV2(for: medicationID)
        let thresholdKeyV2 = refillThresholdStorageKeyV2(for: medicationID)
        UserDefaults.standard.set(bottleAmount, forKey: bottleKeyV2)
        UserDefaults.standard.set(refillThreshold, forKey: thresholdKeyV2)
    }

    private func logMedication(_ medication: Medication, at time: Date, reminderIndex: Int? = nil) {
        let resolvedMedication = store.findMedication(with: medication.logReferenceID ?? medication.id) ?? medication
        if let action = store.logMedicationTaken(
            medication: resolvedMedication,
            actualTime: time,
            notes: nil,
            skipped: false,
            reminderIndex: reminderIndex
        ) {
            presentUndoToast(action)
        }
    }

    private func quickLogCabinetMedication(_ medication: Medication) {
        showingCabinetSheet = false
        let resolvedMedication = store.findMedication(with: medication.logReferenceID ?? medication.id) ?? medication
        if let action = store.logMedicationTaken(
            medication: resolvedMedication,
            actualTime: Date(),
            notes: nil,
            skipped: false,
            reminderIndex: nil
        ) {
            presentUndoToast(action)
        }
    }

    private func presentEditSheet(for medication: Medication) {
        showingCabinetSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            selectedMedicationToEdit = medication
        }
    }

    private func presentUndoToast(_ action: MedicationStore.LogUndoAction) {
        undoToastDismissWorkItem?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            undoToastAction = action
        }

        let workItem = DispatchWorkItem {
            dismissUndoToast()
        }
        undoToastDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + undoToastDuration, execute: workItem)
    }

	    private func dismissUndoToast() {
	        undoToastDismissWorkItem?.cancel()
	        undoToastDismissWorkItem = nil
	        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
	            undoToastAction = nil
	        }
	    }
	}

// MARK: - Subviews

fileprivate struct LogUndoToastView: View {
    let action: MedicationStore.LogUndoAction
    let onUndo: () -> Void
    let onDismiss: () -> Void

    private var title: String {
        action.newLog.skipped ? "Skipped" : "Logged"
    }

    private var subtitle: String {
        action.newLog.medicationName
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.pillrBackground)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.pillrSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button(action: {
                HapticManager.shared.lightImpact()
                onUndo()
            }) {
                Text("Undo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.pillrPrimary.opacity(0.95))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(ScaleButtonStyle())

            Button(action: {
                HapticManager.shared.lightImpact()
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.pillrSecondary.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.pillrPrimary.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 8)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
        .accessibilityHint("Undo to revert this action.")
    }
}

fileprivate struct RefillResetSheet: View {
    let medication: Medication
    let previousBottleAmount: Int?
    let onCancel: () -> Void
    let onSave: (Int, Int) -> Void

    @State private var pillCountText: String
    @State private var refillThresholdText: String
    @FocusState private var focusedField: Field?

    private enum Field {
        case count
        case threshold
    }

    init(
        medication: Medication,
        previousBottleAmount: Int? = nil,
        onCancel: @escaping () -> Void,
        onSave: @escaping (Int, Int) -> Void
    ) {
        self.medication = medication
        self.previousBottleAmount = previousBottleAmount
        self.onCancel = onCancel
        self.onSave = onSave
        _pillCountText = State(initialValue: (previousBottleAmount ?? medication.pillCount).map(String.init) ?? "")
        _refillThresholdText = State(initialValue: medication.refillThreshold.map(String.init) ?? "")
    }

    private var titleText: String {
        let trimmed = medication.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Refill pill count" : "Refill \(trimmed)"
    }

    private var parsedPillCount: Int? {
        Int(pillCountText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var parsedRefillThreshold: Int? {
        Int(refillThresholdText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var validationMessage: String? {
        guard let pillCount = parsedPillCount, let threshold = parsedRefillThreshold else {
            return "Enter both numbers."
        }
        if pillCount <= 0 {
            return "Pill count must be at least 1."
        }
        if threshold < 0 {
            return "Refill reminder number cannot be negative."
        }
        if threshold > pillCount {
            return "Refill reminder number should be less than or equal to the pill count."
        }
        return nil
    }

    private var canSave: Bool {
        validationMessage == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(titleText)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color.pillrBackground)

            Text("Set your new bottle amount and choose when refill reminders should start.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.pillrSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let previousBottleAmount {
                Text("Previous bottle amount: \(previousBottleAmount)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.pillrSecondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Refill amount")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.pillrSecondary)
                    TextField("Example: 30", text: $pillCountText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .count)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .threshold
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .foregroundColor(Color.pillrBackground)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Remind me to refill at")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.pillrSecondary)
                    TextField("Example: 7", text: $refillThresholdText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .threshold)
                        .submitLabel(.done)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .foregroundColor(Color.pillrBackground)
                }
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#FFB74D"))
            }

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.pillrBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                Button(action: {
                    guard let pillCount = parsedPillCount,
                          let threshold = parsedRefillThreshold else { return }
                    onSave(pillCount, threshold)
                }) {
                    Text("Save")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.pillrPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canSave ? Color(hex: "#FFB74D") : Color.pillrAccent)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }

            Spacer(minLength: 4)
        }
        .padding(20)
        .onAppear {
            focusedField = .count
        }
    }
}

@ViewBuilder
fileprivate func EmptyMedicationsView(onAddMedication: @escaping () -> Void) -> some View {
    EmptyStateView(
        title: "Your medication list is empty",
        message: "Get started by adding your first medication by tapping the + button above.",
        actionTitle: nil,
        action: nil,
        icon: "pills.fill"
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Your medication list is empty. Add your first medication to get started.")
    .accessibilityHint("Double tap to add your first medication")
}

@ViewBuilder
fileprivate func NoActiveRemindersView(
    onOpenCabinet: @escaping () -> Void,
    hiddenCount: Int
) -> some View {
    VStack(spacing: 16) {
        Image(systemName: "cabinet.fill")
            .font(.system(size: 42))
            .foregroundColor(Color.pillrBackground.opacity(0.82))
            .padding(.top, 10)
        Text("No active reminders")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(Color.pillrBackground)
        Text(hiddenCount > 0 ? "You have \(hiddenCount) medication\(hiddenCount == 1 ? "" : "s") stored in your cabinet." : "Add reminder times to see medications here.")
            .font(.system(size: 15))
            .multilineTextAlignment(.center)
            .foregroundColor(Color.pillrSecondary.opacity(0.9))
            .padding(.horizontal)
        Button(action: onOpenCabinet) {
            Text("Open Cabinet")
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.pillrBackground)
                )
                .foregroundColor(Color.pillrPrimary.opacity(0.95))
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.bottom, 10)
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.pillrPrimary.opacity(0.38))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.pillrBackground.opacity(0.14), lineWidth: 1)
            )
    )
    .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 10)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("No medications with active reminders. Open the cabinet to view stored medications.")
}

// Helper function to sort medications by priority (overdue first, then by due time)
fileprivate func sortedMedications(
    _ medications: [Medication],
    logs: [MedicationLog],
    referenceDate: Date
) -> [Medication] {
    let calendar = Calendar.current
    let now = referenceDate
    func startOfMinute(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }
    let doseLogs = logs.filter { $0.isDoseLog }
    let logsByMedication = Dictionary(grouping: doseLogs, by: { $0.medicationID })
    let logsByID = Dictionary(uniqueKeysWithValues: doseLogs.map { ($0.id, $0) })

    struct MedicationSortInfo {
        let medication: Medication
        let dueTime: Date
        let isOverdue: Bool
        let wasTakenToday: Bool
        let overdueDuration: TimeInterval
        let lastLogDate: Date?
    }

    let metadata = medications.map { medication -> MedicationSortInfo in
        let medLogs: [MedicationLog]
        if let entryID = medication.logEntryID {
            medLogs = logsByID[entryID].map { [$0] } ?? []
        } else {
            medLogs = logsByMedication[medication.logIdentifier] ?? []
        }

        let dueTime: Date
        if medication.logEntryID != nil, let logDate = medLogs.first?.takenAt {
            dueTime = logDate
        } else {
            dueTime = calculateEffectiveDueTime(for: medication, at: now)
        }

        let wasTakenToday = medLogs.contains { log in
            calendar.isDate(log.takenAt, inSameDayAs: now)
        }
        let nowMinute = startOfMinute(now)
        let dueMinute = startOfMinute(dueTime)
        let isOverdue = !wasTakenToday &&
            nowMinute > dueMinute &&
            calendar.isDate(dueMinute, inSameDayAs: now)
        let overdueDuration = isOverdue ? nowMinute.timeIntervalSince(dueMinute) : 0
        let lastLogDate = medLogs
            .max(by: { $0.takenAt < $1.takenAt })?
            .takenAt

        return MedicationSortInfo(
            medication: medication,
            dueTime: dueTime,
            isOverdue: isOverdue,
            wasTakenToday: wasTakenToday,
            overdueDuration: overdueDuration,
            lastLogDate: lastLogDate
        )
    }

    enum MedicationPriority: Int {
        case overdue = 0
        case pending = 1
        case logged = 2
    }

    func priority(for info: MedicationSortInfo) -> MedicationPriority {
        if info.isOverdue {
            return .overdue
        }
        return info.wasTakenToday ? .logged : .pending
    }

    let sortedMetadata = metadata.sorted { info1, info2 in
        let priority1 = priority(for: info1)
        let priority2 = priority(for: info2)

        if priority1 != priority2 {
            return priority1.rawValue < priority2.rawValue
        }

        switch priority1 {
        case .overdue:
            return info1.overdueDuration > info2.overdueDuration
        case .pending:
            return info1.dueTime < info2.dueTime
        case .logged:
            let lastTaken1 = info1.lastLogDate ?? info1.dueTime
            let lastTaken2 = info2.lastLogDate ?? info2.dueTime
            if lastTaken1 != lastTaken2 {
                return lastTaken1 > lastTaken2
            }
            return info1.medication.name < info2.medication.name
        }
    }

    return sortedMetadata.map { $0.medication }
}

/// Calculate the effective daily due time for a medication, anchored to the
/// current day and time-of-day of its schedule.
///
/// Behaviour:
/// - For recurring meds, we always anchor the due time to *today* at the
///   scheduled hour/minute so that:
///     - Before that time: status is "Due in …"
///     - After that time (until midnight): status is "Overdue by …"
///     - After midnight: the due time rolls forward to the new day and
///       status goes back to "Due in …".
/// - For meds created *today* where the chosen time was already in the past
///   at the moment they were added, we treat the first dose as
///   "tomorrow at that time" so they don't appear immediately overdue when
///   first created. After that first day, they behave like any other recurring
///   medication and can become overdue.
fileprivate func calculateEffectiveDueTime(for medication: Medication, at referenceDate: Date = Date()) -> Date {
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: referenceDate)
    let reminderSources = medication.reminderTimes.isEmpty ? [medication.timeToTake] : medication.reminderTimes
    
    let anchoredTimes = reminderSources
        .sorted()
        .compactMap { reminder -> Date? in
            let components = calendar.dateComponents([.hour, .minute], from: reminder)
            return calendar.date(
                bySettingHour: components.hour ?? 8,
                minute: components.minute ?? 0,
                second: 0,
                of: dayStart
            )
        }
    
    var scheduledForToday: Date
    if let upcoming = anchoredTimes.first(where: { $0 >= referenceDate }) {
        scheduledForToday = upcoming
    } else if let lastTime = anchoredTimes.last {
        scheduledForToday = lastTime
    } else {
        scheduledForToday = referenceDate
    }
    
    if let creationDate = medication.createdAt,
       calendar.isDate(creationDate, inSameDayAs: referenceDate),
       scheduledForToday < creationDate {
        scheduledForToday = calendar.date(byAdding: .day, value: 1, to: scheduledForToday) ?? scheduledForToday
    }
    
    return scheduledForToday
}

fileprivate func calculateDueTime(
    for medication: Medication,
    reminderIndex: Int,
    referenceDate: Date = Date()
) -> Date {
    guard medication.reminderTimes.indices.contains(reminderIndex) else {
        return calculateEffectiveDueTime(for: medication, at: referenceDate)
    }
    
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: referenceDate)
    let reminderTime = medication.reminderTimes[reminderIndex]
    let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
    
    var scheduled = calendar.date(
        bySettingHour: components.hour ?? 8,
        minute: components.minute ?? 0,
        second: 0,
        of: dayStart
    ) ?? reminderTime
    
    if let creationDate = medication.createdAt,
       calendar.isDate(creationDate, inSameDayAs: referenceDate),
       scheduled < creationDate {
        scheduled = calendar.date(byAdding: .day, value: 1, to: scheduled) ?? scheduled
    }
    
    return scheduled
}

@ViewBuilder
@MainActor
fileprivate func MedicationsListContent(
	    store: MedicationStore,
	    showingAddSheet: Binding<Bool>,
	    scrolledOffset: Binding<CGFloat>,
	    horizontalInsets: CGFloat,
	    selectedMedicationToEdit: Binding<Medication?>,
	    medicationToDelete: Binding<Medication?>,
	    logToDelete: Binding<MedicationLog?>,
	    showDeleteAlert: Binding<Bool>,
	    showingInteractionSheet: Binding<Bool>,
	    isCheckingInteractions: Binding<Bool>,
	    onCheckAllInteractions: @escaping () async -> Void,
	    onAddMedication: @escaping () -> Void,
	    onShowFocusTimeline: @escaping () -> Void,
	    onPresentUndoToast: @escaping (MedicationStore.LogUndoAction) -> Void,
	    onRequestCustomLogTimeAction: @escaping (Medication, Int?) -> Void,
        onRequestRefillResetAction: @escaping (Medication) -> Void,
	    onPresentDailyCheckIn: @escaping (Medication) -> Void,
	    medications: [Medication],
        dashboardHighlightedMedicationIDs: Set<UUID>,
	    referenceDate: Date
	) -> some View {
	    VStack(alignment: .leading, spacing: 12) {
	        ForEach(sortedMedications(medications, logs: store.logs, referenceDate: referenceDate)) { med in
            MedicationRow(
                medication: med,
                referenceDate: referenceDate,
                isDashboardHighlighted: dashboardHighlightedMedicationIDs.contains(med.logReferenceID ?? med.id),
                onPresentUndoToast: onPresentUndoToast,
                onRequestCustomLogTime: { resolvedMedication, resolvedIndex in
                    HapticManager.shared.lightImpact()
                    onRequestCustomLogTimeAction(resolvedMedication, resolvedIndex)
                },
                onRefillBannerTap: {
                    HapticManager.shared.lightImpact()
                    onRequestRefillResetAction(med)
                },
                onDailyCheckInTap: { onPresentDailyCheckIn(med) },
                onEditTap: {
                    HapticManager.shared.lightImpact()
                    selectedMedicationToEdit.wrappedValue = store.findMedication(with: med.logReferenceID ?? med.id) ?? med
                },
                onDeleteTap: {
                    HapticManager.shared.warningNotification()
                    if let logEntryID = med.logEntryID,
                       let logEntry = store.logs.first(where: { $0.id == logEntryID }) {
                        logToDelete.wrappedValue = logEntry
                        medicationToDelete.wrappedValue = nil
                    } else {
                        medicationToDelete.wrappedValue = store.findMedication(with: med.logReferenceID ?? med.id) ?? med
                        logToDelete.wrappedValue = nil
                    }
                    showDeleteAlert.wrappedValue = true
                }
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)).combined(with: .scale(scale: 0.95)),
                removal: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.95))
            ))
            .id(med.id)
        }
    }
    .padding(.horizontal, horizontalInsets)
}

@ViewBuilder
@MainActor
fileprivate func MedicationsListHeader(
    store: MedicationStore,
    horizontalInsets: CGFloat,
    onAddMedication: @escaping () -> Void,
    onShowCabinet: @escaping () -> Void,
    cabinetCount: Int
) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Meds")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color.pillrBackground)
                
                Text("\(store.activeMedications.count) medication\(store.activeMedications.count == 1 ? "" : "s")")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.pillrSecondary.opacity(0.9))
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Button(action: onShowCabinet) {
                    Image(systemName: "cabinet.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.pillrBackground)
                        .frame(width: 24, height: 24)
                        .overlay(alignment: .topTrailing) {
                            if cabinetCount > 0 {
                                Text("\(cabinetCount)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.pillrPrimary)
                                    .padding(4)
                                    .background(Color.pillrBackground)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                }
                .buttonStyle(.plain)
                .frame(width: 46, height: 46)
                .glassCircleBackground(diameter: 46, isSelected: false, opacity: 0.95)
                .contentShape(Circle())

                Button(action: onAddMedication) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.pillrBackground)
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel("Add Medication")
                .accessibilityIdentifier("addMedicationButton")
                .buttonStyle(.plain)
                .frame(width: 46, height: 46)
                .glassCircleBackground(diameter: 46, isSelected: false, opacity: 0.95)
                .contentShape(Circle())
            }
        }
    }
    .padding(.leading, horizontalInsets + 8)
    .padding(.trailing, horizontalInsets)
    .padding(.top, 12)
}

fileprivate struct HealthSummaryWidget: View {
    @EnvironmentObject private var userSettings: UserSettings

    enum Style {
        case standalone
        case embedded
    }

    @ObservedObject var manager: HealthKitManager
    let style: Style
    private static var defaultDistanceUnit: HealthDistanceUnit {
        Locale.current.measurementSystem == .metric ? .kilometers : .miles
    }
    @AppStorage("healthSnapshotDistanceUnit") private var distanceUnitRawValue = defaultDistanceUnit.rawValue
    @AppStorage("healthSnapshotDailyStepGoal") private var dailyStepGoal = 10000

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    private struct Metric {
        let title: String
        let unit: String
        let value: String
    }

    private var distanceUnit: HealthDistanceUnit {
        HealthDistanceUnit(rawValue: distanceUnitRawValue) ?? .miles
    }

    private var metrics: [Metric] {
        [
            Metric(title: "Heart Rate", unit: "bpm / 1 hr avg", value: formattedHeartRate(manager.hourlyAverageHeartRate)),
            Metric(title: "Steps", unit: "Goal: \(formattedStepGoal(dailyStepGoal))", value: formattedSteps(manager.dailySteps)),
            Metric(title: "Distance", unit: distanceUnit.rawValue, value: formattedDistance(manager.dailyDistanceMiles))
        ]
    }

    init(manager: HealthKitManager, style: Style = .standalone) {
        self.manager = manager
        self.style = style
    }

    private var primaryTextColor: Color {
        style == .embedded ? MedicationCardPalette.titleText : Color.pillrBackground
    }

    private var secondaryTextColor: Color {
        style == .embedded ? MedicationCardPalette.secondaryText : Color.pillrSecondary
    }

    private var actionBackgroundColor: Color {
        Color.pillrPrimary
    }

    private var actionTextColor: Color {
        Color.pillrBackground
    }

    private var dividerColor: Color {
        style == .embedded ? MedicationCardPalette.divider.opacity(0.6) : Color.white.opacity(0.12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !manager.isHealthDataAvailable {
                Text("Apple Health is not available on this device.")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColor.opacity(0.9))
            } else if manager.hasConnected || manager.hasAnyPermission || manager.hasMetricValues {
                VStack(alignment: .leading, spacing: 8) {
                    metricGrid
                    if shouldShowHeartRatePrompt {
                        heartRatePermissionPrompt
                    }
                }
            } else {
                permissionPrompt
            }

            if let error = manager.authorizationError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(MedicationCardPalette.urgency)
                    .lineLimit(2)
            }
        }
        .padding(style == .embedded ? 0 : 8)
        .background(
            Group {
                if style == .standalone {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.pillrPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(MedicationCardPalette.divider.opacity(0.25), lineWidth: 1)
                        )
                }
            }
        )
        .shadow(color: style == .embedded ? .clear : Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var shouldShowHeartRatePrompt: Bool {
        manager.isHealthDataAvailable && manager.hasAnyPermission && !manager.hasHeartRatePermission
    }

    private var metricGrid: some View {
        HStack(spacing: 10) {
            ForEach(metrics.indices, id: \.self) { index in
                metricSquare(metric: metrics[index])
                if index < metrics.count - 1 {
                    verticalDivider
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var permissionPrompt: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(
                manager.hasDeniedPermission
                    ? "Health access is off. Open Settings to turn it back on."
                    : "Connect Apple Health to show steps, distance and heart rate."
            )
            .font(.system(size: 13))
            .foregroundColor(secondaryTextColor.opacity(0.9))
            .lineLimit(3)

            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let spacing: CGFloat = 10
                let hideWidth = max(76, (totalWidth - spacing) * 0.24)
                let connectWidth = max(0, totalWidth - spacing - hideWidth)

                HStack(spacing: spacing) {
                    Button {
                        Task {
                            await manager.requestAuthorizationIfNeeded()
                            await manager.refreshMetrics()
                        }
                    } label: {
                        Text("Connect Apple Health")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(actionTextColor)
                            .padding(.vertical, 8)
                            .frame(width: connectWidth)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(actionBackgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(MedicationCardPalette.divider.opacity(0.7), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button {
                        userSettings.shouldShowAppleHealthData = false
                    } label: {
                        Text("Hide")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor.opacity(0.95))
                            .padding(.vertical, 8)
                            .frame(width: hideWidth)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(MedicationCardPalette.divider.opacity(0.7), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .frame(height: 42)
        }
    }

    private var heartRatePermissionPrompt: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(
                manager.hasDeniedHeartRatePermission
                    ? "Heart rate access is denied. Open Settings to re-allow heart rate data."
                    : "Allow access to Apple Health heart rate to show your average over the last hour."
            )
            .font(.system(size: 12))
            .foregroundColor(secondaryTextColor.opacity(0.9))
            .lineLimit(2)

            Button {
                if manager.hasDeniedHeartRatePermission {
                    manager.openHealthSettings()
                } else {
                    Task {
                        await manager.requestHeartRateAuthorizationIfNeeded()
                        await manager.refreshMetrics()
                    }
                }
            } label: {
                Text(manager.hasDeniedHeartRatePermission ? "Open Settings" : "Enable Heart Rate")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(actionTextColor)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(actionBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(MedicationCardPalette.divider.opacity(0.7), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func metricSquare(metric: Metric) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(metric.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(secondaryTextColor.opacity(0.9))

            Text(metric.value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(primaryTextColor)

            Text(metric.unit)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(secondaryTextColor.opacity(0.7))
        }
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private var verticalDivider: some View {
        Rectangle()
            .frame(width: 1)
            .foregroundColor(dividerColor)
            .padding(.vertical, 6)
    }

    private func formattedSteps(_ value: Int?) -> String {
        guard let value = value else {
            return "--"
        }
        return Self.integerFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formattedStepGoal(_ value: Int) -> String {
        Self.integerFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    private func formattedDistance(_ milesValue: Double?) -> String {
        guard let converted = convertedDistance(fromMiles: milesValue) else {
            return "--"
        }
        return Self.decimalFormatter.string(from: NSNumber(value: converted)) ?? String(format: "%.1f", converted)
    }

    private func formattedHeartRate(_ value: Double?) -> String {
        guard let value = value else {
            return "--"
        }
        let rounded = Int(value.rounded())
        return Self.integerFormatter.string(from: NSNumber(value: rounded)) ?? "\(rounded)"
    }
    
    private func convertedDistance(fromMiles milesValue: Double?) -> Double? {
        guard let miles = milesValue else { return nil }
        return distanceUnit.convertDistance(fromMiles: miles)
    }

}

fileprivate struct InteractionPromptCard: View {
    let medicationName: String
    let hasAccess: Bool
    let onCheck: () -> Void
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    @State private var progress: CGFloat = 0

    private let autoDismissDuration: TimeInterval = 5.0

    private var displayName: String {
        let trimmed = medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "this medication" : trimmed
    }

    private var titleText: String {
        "\(displayName) added. Review interactions?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.pillrBackground)
                .lineLimit(2)

            Button(action: {
                if hasAccess {
                    onCheck()
                } else {
                    onUpgrade()
                }
            }) {
                HStack(spacing: 6) {
                    Text("Check interactions")
                        .font(.system(size: 13, weight: .semibold))
                    if !hasAccess {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .foregroundColor(Color.pillrPrimary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.92))
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(hex: "#70826F").opacity(0.98))

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(hex: "#859684").opacity(0.92))
                        .frame(width: geometry.size.width * progress)

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .task(id: medicationName) {
            progress = 0

            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.linear(duration: autoDismissDuration)) {
                progress = 1
            }

            do {
                try await Task.sleep(nanoseconds: UInt64(autoDismissDuration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                onDismiss()
            } catch {
            }
        }
    }
}

fileprivate struct InteractionShortcutCard: View {
    let isPremiumEnabled: Bool
    let canRunCheckNow: Bool
    let onTap: () -> Void

    private var subtitleText: String {
        if !canRunCheckNow {
            return "Open the checker and choose 2 or more medications."
        }
        return "Check how your medications work together."
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 46, height: 46)

                    Image(systemName: "point.3.connected.trianglepath")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.pillrBackground)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Interaction Checker")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.pillrBackground)
                            .lineLimit(1)

                        if !isPremiumEnabled {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.pillrSecondary)
                        }
                    }

                    Text(subtitleText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.pillrSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.pillrSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.pillrAccent)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Interaction Checker")
    }
}

fileprivate struct FloatingActionButton: View {
    @Binding var showingAddSheet: Bool
    @Binding var isCheckingInteractions: Bool
    let onCheckAllInteractions: () async -> Void
    let onAddMedication: () -> Void
    @State private var isExpanded = false
    @State private var showBackdrop = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Enhanced backdrop with blur effect
            if showBackdrop {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .background(.ultraThinMaterial)
                    .onTapGesture {
                        collapseMenu()
                    }
                    .transition(.opacity)
            }
            
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Expanded action buttons
                        if isExpanded {
                            VStack(spacing: 12) {
                                // Add medication button
                                expandedActionButton(
                                    icon: "plus.app",
                                    text: "Add Medication",
                                    delay: 0.05
                                ) {
                                    HapticManager.shared.lightImpact()
                                    onAddMedication()
                                    collapseMenu()
                                }
                            }
                            .padding(.bottom, 16)
                        }
                        
                        // Main floating button
                        mainFloatingButton
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showBackdrop)
        .onAppear {
            // Removed tooltip auto-show logic
        }
    }
    
    // MARK: - Subviews
    


    
    private var mainFloatingButton: some View {
        Button(action: {
            HapticManager.shared.mediumImpact()
            toggleMenu()
        }) {
            ZStack {
                // Perfect circle with enhanced 3D gradient
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.pillrBackground, location: 0.0),
                                .init(color: Color.pillrBackground, location: 0.25),
                                .init(color: Color.pillrBackground, location: 0.5),
                                .init(color: Color.pillrSecondary, location: 0.75),
                                .init(color: Color.pillrSecondary, location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)
                    .overlay(
                        // Enhanced inner highlight with multiple layers
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(isExpanded ? 0.7 : 0.5),
                                        Color.white.opacity(0.3),
                                        Color.clear,
                                        Color.black.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .overlay(
                        // Subtle inner shadow for depth
                        Circle()
                            .stroke(
                                Color.black.opacity(0.1),
                                lineWidth: 0.8
                            )
                            .blur(radius: 0.8)
                            .offset(x: 1, y: 1)
                    )

                // More rectangular plus icon with enhanced animation
                ZStack {
                    if isExpanded {
                        // X mark for close
                        Image(systemName: "xmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.pillrPrimary)
                    } else {
                        // Custom rectangular plus
                        ZStack {
                            // Horizontal bar (more rectangular)
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color.pillrPrimary)
                                .frame(width: 24, height: 4)
                            
                            // Vertical bar (more rectangular)
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color.pillrPrimary)
                                .frame(width: 4, height: 24)
                        }
                    }
                }
                .rotationEffect(.degrees(isExpanded ? 540 : 0))
                .scaleEffect(isExpanded ? 0.85 : 1.0)
                .animation(.spring(response: 0.42, dampingFraction: 0.78), value: isExpanded)
            }
            .shadow(color: Color.black.opacity(isExpanded ? 0.35 : 0.25), radius: isExpanded ? 15 : 12, x: 0, y: isExpanded ? 10 : 8)
            .shadow(color: Color.pillrPrimary.opacity(0.2), radius: 4, x: 0, y: 3)
            .shadow(color: Color.white.opacity(0.5), radius: 1, x: 0, y: -1)
            .scaleEffect(isExpanded ? 1.05 : 1.0)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isExpanded)
        }
        .buttonStyle(EnhancedScaleButtonStyle())
        .accessibilityLabel(isExpanded ? "Close actions menu" : "Show actions menu")
        .accessibilityHint(actionsMenuAccessibilityHint)
        .accessibilityAddTraits(.isButton)
    }
    
    private var actionsMenuAccessibilityHint: String {
        let action = isExpanded ? "close" : "open"
        return "Double tap to \(action) the actions menu with options to add medications"
    }

    // MARK: - Helper Methods
    
    private func toggleMenu() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isExpanded.toggle()
            showBackdrop = isExpanded
        }

    }
    
    private func collapseMenu() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isExpanded = false
            showBackdrop = false
        }
    }
    
    private func expandedActionButton(
        icon: String,
        text: String,
        delay: Double,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.pillrPrimary)
                    .frame(width: 20)
                
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.pillrPrimary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.pillrBackground,
                        Color.pillrBackground,
                        Color.pillrSecondary,
                        Color.pillrSecondary
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(28)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .shadow(color: Color.white.opacity(0.3), radius: 1, x: 0, y: -1)
        }
        .buttonStyle(EnhancedScaleButtonStyle())
        .transition(.asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: .bottom))
                .combined(with: .scale(scale: 0.92))
                .animation(.spring(response: 0.45, dampingFraction: 0.82).delay(delay)),
            removal: .opacity
                .combined(with: .move(edge: .bottom))
                .combined(with: .scale(scale: 0.95))
                .animation(.spring(response: 0.32, dampingFraction: 0.9))
        ))
    }
}

// Enhanced button style with better feedback
struct EnhancedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    HapticManager.shared.pulseButton()
                }
            }
    }
}

fileprivate struct MedicationCabinetSheet: View {
    let medications: [Medication]
    let logs: [MedicationLog]
    let referenceDate: Date
    let onLogMedication: (Medication) -> Void
    let onEditMedication: (Medication) -> Void
    let onDeleteMedication: ((Medication) -> Void)?
    @Binding var showCabinetIntroOverlay: Bool
    @Environment(\.dismiss) private var dismiss

    private var asNeededMedications: [Medication] {
        medications.filter { $0.frequency == "As needed" }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.pillrPrimary
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Medication Cabinet")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(Color.pillrBackground)

                            Text("\(asNeededMedications.count) medication\(asNeededMedications.count == 1 ? "" : "s")")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.pillrSecondary.opacity(0.9))
                        }
                        .padding(.top, 12)

                        if asNeededMedications.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Your Cabinet Is Empty")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color.pillrBackground)
                                Text("Anything you set as \"as needed\" stays here tucked away and ready when you need it.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.pillrSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.pillrAccent)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        } else {
                            cabinetSection(title: "Ready when you need them.", medications: asNeededMedications)
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }

                if showCabinetIntroOverlay {
                    CabinetIntroOverlayView(onDismiss: hideCabinetIntroOverlay)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.pillrBackground)
                }
            }
        }
    }

    private func hideCabinetIntroOverlay() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showCabinetIntroOverlay = false
        }
    }

    @ViewBuilder
    private func cabinetSection(title: String, medications: [Medication]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.pillrSecondary)

            ForEach(sortedMedications(medications, logs: logs, referenceDate: referenceDate)) { medication in
                CabinetMedicationRow(
                    medication: medication,
                    onLogTap: { onLogMedication(medication) },
                    onEditTap: { onEditMedication(medication) },
                    onDeleteTap: onDeleteMedication.map { action in
                        { action(medication) }
                    }
                )
            }
        }
    }
}

fileprivate struct CabinetIntroOverlayView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "cabinet.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.white)

                Text("Medication Cabinet")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Medications set as “as needed” are located here, making it easy to log a dose whenever needed.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                Button(action: onDismiss) {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.pillrPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.pillrBackground)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.pillrPrimary.opacity(0.95))
                    .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 12)
            )
            .padding(.horizontal, 20)
        }
        .accessibilityAddTraits(.isModal)
    }
}

fileprivate struct CabinetMedicationRow: View {
    let medication: Medication
    let onLogTap: () -> Void
    let onEditTap: () -> Void
    let onDeleteTap: (() -> Void)?
    @State private var showDetails = false

    private var expandedActions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: onEditTap) {
                    Text("Edit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.pillrBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(hex: "#444C44"))
                        )
                }
                .buttonStyle(.plain)
            }

            if let deleteTap = onDeleteTap {
                Button {
                    HapticManager.shared.warningNotification()
                    deleteTap()
                } label: {
                    Text("Delete medication")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.red.opacity(0.95))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(hex: "#4A4A45"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.red.opacity(0.22), lineWidth: 0.8)
                                )
                        )
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            MedicationRowHeaderView(
                medication: medication,
                cycleStatus: .asNeeded,
                overdueMinutes: nil,
                overdueBadgeActive: false,
                showDetails: $showDetails,
                doseStates: [],
                onRequestCustomLogTime: { _ in
                    onLogTap()
                },
                onSkipDose: { _ in },
                highlightedDoseIndex: nil,
                compactLayout: false,
                referenceDate: Date(),
                showsSkipButton: false,
                hideScheduleLine: true
            )

            if showDetails {
                expandedActions
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(MedicationCardPalette.background)
        .cornerRadius(12)
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MedicationCardPalette.divider.opacity(0.7), lineWidth: 0.8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            MedicationCardPalette.divider.opacity(0.65),
                            MedicationCardPalette.divider.opacity(0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: showDetails)
        .overlay(alignment: .topTrailing) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showDetails.toggle()
                }
            }) {
                Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13))
                    .foregroundColor(MedicationCardPalette.secondaryText.opacity(0.75))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(MedicationCardPalette.background.opacity(0.92))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .padding(.trailing, 24)
        }
    }
}

@MainActor
fileprivate struct MedicationsListMainContent: View {
    @ObservedObject var store: MedicationStore
    @Binding var showingAddSheet: Bool
    @Binding var scrolledOffset: CGFloat
    @Binding var dashboardHighlightedMedicationIDs: Set<UUID>
    @Binding var selectedMedicationToEdit: Medication?
    @Binding var medicationToDelete: Medication?
    @Binding var logToDelete: MedicationLog?
    @Binding var showDeleteAlert: Bool
    @Binding var showingInteractionSheet: Bool
    @Binding var isCheckingInteractions: Bool
    let onCheckAllInteractions: () async -> Void
    let onOpenInteractionChecker: () -> Void
    let onShowPremiumUpgrade: () -> Void
    let onAddMedication: () -> Void
    let onShowFocusTimeline: () -> Void
    let onPresentUndoToast: (MedicationStore.LogUndoAction) -> Void
    let onRequestCustomLogTimeAction: (Medication, Int?) -> Void
    let onRequestRefillResetAction: (Medication) -> Void
    let onPresentDailyCheckIn: (Medication) -> Void
    let displayedMedications: [Medication]
    let cabinetMedications: [Medication]
    let onShowCabinet: () -> Void
    @Binding var suppressAutoExpandForHighlightedMedicationID: UUID?
    let healthKitManager: HealthKitManager
    let referenceDate: Date
    let onHighlightOverdueMedications: () -> Void
    let onHighlightLowSupplyMedications: () -> Void
    @EnvironmentObject private var userSettings: UserSettings

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    fileprivate struct NextScheduledDose {
        let medicationName: String
        let dueTime: Date
        let medicationsAtSameTimeCount: Int
    }

    fileprivate struct TodaySummaryData {
        let hasMedications: Bool
        let overdueCount: Int
        let takenCount: Int
        let lowSupplyCount: Int
        let overdueDose: NextScheduledDose?
        let overdueDoses: [NextScheduledDose]
        let nextDose: NextScheduledDose?

        var title: String {
            if !hasMedications {
                return "No medications added"
            }
            if overdueCount > 0 {
                return overdueCount == 1 ? "1 reminder needs attention" : "\(overdueCount) reminders need attention"
            }
            if nextDose != nil {
                return "Your next dose is lined up"
            }
            if takenCount > 0 {
                return "You’re caught up for now"
            }
            return "Nothing is due yet"
        }

        var subtitle: String {
            if !hasMedications {
                return "Add a medication to see what’s due next."
            }
            if overdueCount > 0 {
                return "Start with the overdue medication at the top of your list."
            }
            if let nextDose {
                return "\(nextDose.medicationName) is next."
            }
            if lowSupplyCount > 0 {
                return lowSupplyCount == 1 ? "One medication is running low." : "\(lowSupplyCount) medications are running low."
            }
            if takenCount > 0 {
                return takenCount == 1 ? "You’ve logged 1 dose today." : "You’ve logged \(takenCount) doses today."
            }
            return "Your medications will show up here as they become due."
        }
    }

    private var todaySummary: TodaySummaryData? {
        let overdueCount = store.overdueReminderCount(referenceDate: referenceDate)
        let takenCount = doseLogsToday.filter { !$0.skipped }.count
        let lowSupplyCount = store.activeMedications.filter { medication in
            guard let pillCount = medication.pillCount,
                  let refillThreshold = medication.refillThreshold else {
                return false
            }
            return pillCount <= refillThreshold
        }.count

        return TodaySummaryData(
            hasMedications: !store.activeMedications.isEmpty,
            overdueCount: overdueCount,
            takenCount: takenCount,
            lowSupplyCount: lowSupplyCount,
            overdueDose: nextOverdueDose,
            overdueDoses: overdueScheduledDoses,
            nextDose: nextScheduledDose
        )
    }

    private var doseLogsToday: [MedicationLog] {
        let calendar = Calendar.current
        return store.logs.filter { log in
            log.isDoseLog && calendar.isDate(log.takenAt, inSameDayAs: referenceDate)
        }
    }

    private var nextScheduledDose: NextScheduledDose? {
        let doses = store.activeMedications
            .compactMap { medication -> NextScheduledDose? in
                guard let dueTime = nextPendingDueTime(for: medication),
                      dueTime >= referenceDate else {
                    return nil
                }

                return NextScheduledDose(
                    medicationName: medication.name,
                    dueTime: dueTime,
                    medicationsAtSameTimeCount: 1
                )
            }
            .sorted { $0.dueTime < $1.dueTime }

        guard let nextDose = doses.first else { return nil }

        let sameTimeCount = doses.filter {
            Calendar.current.compare($0.dueTime, to: nextDose.dueTime, toGranularity: .minute) == .orderedSame
        }.count

        return NextScheduledDose(
            medicationName: nextDose.medicationName,
            dueTime: nextDose.dueTime,
            medicationsAtSameTimeCount: sameTimeCount
        )
    }

    private var nextOverdueDose: NextScheduledDose? {
        overdueScheduledDoses.first
    }

    private var overdueScheduledDoses: [NextScheduledDose] {
        store.activeMedications
            .compactMap { medication -> NextScheduledDose? in
                guard let dueTime = nextPendingDueTime(for: medication),
                      dueTime < referenceDate else {
                    return nil
                }

                return NextScheduledDose(
                    medicationName: medication.name,
                    dueTime: dueTime,
                    medicationsAtSameTimeCount: 1
                )
            }
            .sorted { $0.dueTime < $1.dueTime }
    }

    private func horizontalInsets(for width: CGFloat) -> CGFloat {
        if horizontalSizeClass == .regular && width > 768 {
            return max((width - 650) / 2, 16)
        }
        return 16
    }

    private func medicationLogsToday(for medication: Medication) -> [MedicationLog] {
        let calendar = Calendar.current
        return store.logs.filter { log in
            log.medicationID == medication.id &&
            log.isDoseLog &&
            calendar.isDate(log.takenAt, inSameDayAs: referenceDate)
        }
    }

    private func nextPendingDueTime(for medication: Medication) -> Date? {
        guard medication.frequency != "As needed" else { return nil }

        let logs = medicationLogsToday(for: medication)

        if medication.reminderTimes.isEmpty {
            return logs.isEmpty ? calculateEffectiveDueTime(for: medication, at: referenceDate) : nil
        }

        var assignedReminderIndices = Set(logs.compactMap(\.reminderIndex))
        var unassignedLogCount = logs.filter { $0.reminderIndex == nil }.count

        for index in medication.reminderTimes.indices {
            if assignedReminderIndices.contains(index) {
                continue
            }

            if unassignedLogCount > 0 {
                unassignedLogCount -= 1
                assignedReminderIndices.insert(index)
                continue
            }

            return calculateDueTime(for: medication, reminderIndex: index, referenceDate: referenceDate)
        }

        return nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.pillrPrimary
                .ignoresSafeArea(edges: [.top, .leading, .trailing, .bottom])

            ScrollViewReader { proxy in
                ScrollView {
                    let horizontalInset = horizontalInsets(for: UIScreen.main.bounds.width)
                    VStack(alignment: .leading, spacing: 28) {
                        MedicationsListHeader(
                            store: store,
                            horizontalInsets: horizontalInset,
                            onAddMedication: onAddMedication,
                            onShowCabinet: onShowCabinet,
                            cabinetCount: cabinetMedications.count
                        )

                        TodaySummaryCard(
                            summary: todaySummary ?? TodaySummaryData(
                                hasMedications: false,
                                overdueCount: 0,
                                takenCount: 0,
                                lowSupplyCount: 0,
                                overdueDose: nil,
                                overdueDoses: [],
                                nextDose: nil
                            ),
                            referenceDate: referenceDate,
                            onOverdueTap: onHighlightOverdueMedications,
                            onLowSupplyTap: onHighlightLowSupplyMedications,
                            healthKitManager: healthKitManager,
                            showsHealthSummary: userSettings.shouldShowAppleHealthData
                        )
                        .padding(.horizontal, horizontalInset)

                        if store.activeMedications.isEmpty {
                            EmptyMedicationsView(onAddMedication: onAddMedication)
                                .padding(.horizontal, horizontalInset)
                        } else if displayedMedications.isEmpty {
                            NoActiveRemindersView(
                                onOpenCabinet: onShowCabinet,
                                hiddenCount: cabinetMedications.count
                            )
                            .padding(.horizontal, horizontalInset)
                        } else {
                            MedicationsListContent(
                                store: store,
                                showingAddSheet: $showingAddSheet,
                                scrolledOffset: $scrolledOffset,
                                horizontalInsets: horizontalInset,
                                selectedMedicationToEdit: $selectedMedicationToEdit,
                                medicationToDelete: $medicationToDelete,
                                logToDelete: $logToDelete,
                                showDeleteAlert: $showDeleteAlert,
                                showingInteractionSheet: $showingInteractionSheet,
                                isCheckingInteractions: $isCheckingInteractions,
                                onCheckAllInteractions: onCheckAllInteractions,
                                onAddMedication: onAddMedication,
                                onShowFocusTimeline: onShowFocusTimeline,
                                onPresentUndoToast: onPresentUndoToast,
                                onRequestCustomLogTimeAction: onRequestCustomLogTimeAction,
                                onRequestRefillResetAction: onRequestRefillResetAction,
                                onPresentDailyCheckIn: onPresentDailyCheckIn,
                                medications: displayedMedications,
                                dashboardHighlightedMedicationIDs: dashboardHighlightedMedicationIDs,
                                referenceDate: referenceDate
                            )

                        }
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.bottom, 50)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .global).minY
                            )
                        }
                    )
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrolledOffset = -value
                }
                .onChange(of: store.highlightedMedicationID) { _, target in
                    guard let target else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                    if suppressAutoExpandForHighlightedMedicationID == target {
                        suppressAutoExpandForHighlightedMedicationID = nil
                    } else if store.notificationHighlightMedicationID != target {
                        store.expandedMedicationID = target
                    }
                    DispatchQueue.main.async {
                        store.highlightedMedicationID = nil
                    }
                }
                .onChange(of: store.expandedMedicationID) { _, expandedID in
                    guard let expandedID else { return }
                    // Scroll the expanded card into view so its details are fully visible.
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            proxy.scrollTo(expandedID, anchor: .top)
                        }
                    }
                }
            }
        }
    }
}

fileprivate struct TodaySummaryCard: View {
    let summary: MedicationsListMainContent.TodaySummaryData
    let referenceDate: Date
    let onOverdueTap: () -> Void
    let onLowSupplyTap: () -> Void
    let healthKitManager: HealthKitManager
    let showsHealthSummary: Bool

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE, d MMMM")
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()

    private var dashboardDateLabel: String {
        Self.headerDateFormatter.string(from: referenceDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dashboardDateLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(MedicationCardPalette.secondaryText.opacity(0.82))
                        .textCase(.uppercase)
                        .tracking(0.7)

                    Text(primaryTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(MedicationCardPalette.titleText)
                        .lineLimit(2)

                    if let primarySubtitle {
                        Text(primarySubtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MedicationCardPalette.secondaryText.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                GeometryReader { geometry in
                    let chipSpacing: CGFloat = 10
                    let visibleChipCount = summary.lowSupplyCount > 0 ? 3 : 2
                    let chipWidth = (geometry.size.width - (chipSpacing * CGFloat(visibleChipCount - 1))) / CGFloat(visibleChipCount)

                    HStack(spacing: chipSpacing) {
                        overdueSummaryChip
                            .frame(width: chipWidth)

                        summaryChip(
                            title: "Taken",
                            value: "\(summary.takenCount)",
                            accent: MedicationCardPalette.titleText,
                            background: Color.white.opacity(0.08)
                        )
                        .frame(width: chipWidth)

                        if summary.lowSupplyCount > 0 {
                            lowSupplySummaryChip
                                .frame(width: chipWidth)
                        }
                    }
                }
                .frame(height: 44)
            }
            .padding(16)
            .background(cardBackground)
            .zIndex(1)

            if showsHealthSummary {
                HealthSummaryWidget(manager: healthKitManager, style: .embedded)
                    .padding(.horizontal, 16)
                    .padding(.top, 30)
                    .padding(.bottom, 8)
                    .background(connectedHealthBackground)
                    .padding(.top, -18)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(MedicationCardPalette.background)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(MedicationCardPalette.divider.opacity(0.75), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
    }

    private var connectedHealthBackground: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 22,
                bottomTrailingRadius: 22,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(MedicationCardPalette.secondaryTint)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .stroke(MedicationCardPalette.divider.opacity(0.75), lineWidth: 1)
            )

            Rectangle()
                .fill(MedicationCardPalette.background)
                .frame(height: 6)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 6)
    }

    private var overdueSummaryChip: some View {
        Button(action: onOverdueTap) {
            summaryChip(
                title: "Overdue",
                value: "\(summary.overdueCount)",
                accent: summary.overdueCount > 0 ? MedicationCardPalette.urgency : MedicationCardPalette.titleText.opacity(0.82),
                isEmphasized: summary.overdueCount > 0,
                showsChevron: summary.overdueCount > 0
            )
        }
        .buttonStyle(.plain)
        .disabled(summary.overdueCount == 0)
    }

    private var lowSupplySummaryChip: some View {
        Button(action: onLowSupplyTap) {
            HStack(spacing: 8) {
                Text("\(summary.lowSupplyCount)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(summary.lowSupplyCount > 0 ? Color(hex: "#FFD27D") : MedicationCardPalette.titleText)
                    .lineLimit(1)

                Text("Low supply")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(MedicationCardPalette.secondaryText.opacity(0.82))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(MedicationCardPalette.background)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke((summary.lowSupplyCount > 0 ? Color(hex: "#FFD27D") : MedicationCardPalette.divider).opacity(0.7), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(summary.lowSupplyCount == 0)
    }

    private var primaryTitle: String {
        if summary.overdueCount > 0 {
            if let overdueDose = summary.overdueDose {
                if summary.overdueCount > 1 {
                    let additionalCount = summary.overdueCount - 1
                    return additionalCount == 1
                        ? "\(overdueDose.medicationName) and one other haven't been taken yet"
                        : "\(overdueDose.medicationName) and \(additionalCount) others haven't been taken yet"
                }
                return "\(overdueDose.medicationName) is past due"
            }
            return summary.overdueCount == 1 ? "You've missed a dose" : "You've missed \(summary.overdueCount) doses"
        }
        if let nextDose = summary.nextDose {
            return nextDoseTitle(for: nextDose.dueTime)
        }
        if summary.takenCount > 0 {
            return "All done for today"
        }
        return "Nothing scheduled today"
    }

    private var primarySubtitle: String? {
        if let overdueDose = summary.overdueDose, summary.overdueCount > 0 {
            return summary.overdueCount > 1
                ? overdueNamesSubtitle(excluding: overdueDose.medicationName)
                : "Missed at \(Self.timeFormatter.string(from: overdueDose.dueTime))"
        }
        if let nextDose = summary.nextDose {
            return nextDoseSubtitle(for: nextDose)
        }
        if summary.takenCount > 0 {
            return nil
        }
        return nil
    }

    private func nextDoseTitle(for dueTime: Date) -> String {
        let time = Self.timeFormatter.string(from: dueTime)
        let calendar = Calendar.current

        if calendar.isDate(dueTime, inSameDayAs: referenceDate) {
            return "Next dose at \(time)"
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate),
           calendar.isDate(dueTime, inSameDayAs: tomorrow) {
            return "Next dose tomorrow at \(time)"
        }

        return "Next dose \(Self.weekdayFormatter.string(from: dueTime)) at \(time)"
    }

    private func nextDoseSubtitle(for nextDose: MedicationsListMainContent.NextScheduledDose) -> String {
        let time = Self.timeFormatter.string(from: nextDose.dueTime)

        if nextDose.medicationsAtSameTimeCount > 1 {
            let otherCount = nextDose.medicationsAtSameTimeCount - 1
            return otherCount == 1
                ? "\(nextDose.medicationName) and 1 other at \(time)"
                : "\(nextDose.medicationName) and \(otherCount) others at \(time)"
        }

        return "\(nextDose.medicationName) · \(time)\(nextDoseDayText(for: nextDose.dueTime))"
    }

    private func overdueNamesSubtitle(excluding primaryName: String) -> String? {
        let additionalNames = summary.overdueDoses
            .map(\.medicationName)
            .filter { $0 != primaryName }

        guard !additionalNames.isEmpty else { return nil }

        if additionalNames.count == 1 {
            return "Also overdue: \(additionalNames[0])"
        }

        if additionalNames.count == 2 {
            return "Also overdue: \(additionalNames[0]) and \(additionalNames[1])"
        }

        return "Also overdue: \(additionalNames[0]), \(additionalNames[1]), and \(additionalNames.count - 2) more"
    }

    private func nextDoseDayText(for dueTime: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDate(dueTime, inSameDayAs: referenceDate) {
            return ""
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate),
           calendar.isDate(dueTime, inSameDayAs: tomorrow) {
            return " tomorrow"
        }

        return " on \(Self.weekdayFormatter.string(from: dueTime))"
    }

    private func summaryChip(
        title: String,
        value: String,
        accent: Color,
        background: Color = MedicationCardPalette.background,
        isEmphasized: Bool = false,
        showsChevron: Bool = false
    ) -> some View {
        HStack(spacing: 8) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(accent)
                .lineLimit(1)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(MedicationCardPalette.secondaryText.opacity(0.82))
                .lineLimit(1)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(MedicationCardPalette.secondaryText.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(background)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke((isEmphasized ? accent : MedicationCardPalette.divider).opacity(isEmphasized ? 0.75 : 0.6), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preference Key for Scroll Position
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

fileprivate func commonFormatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

fileprivate func createCabinetLogCard(
    from medication: Medication,
    log: MedicationLog
) -> Medication {
    var clone = medication
    clone.id = log.id
    clone.createdAt = log.takenAt
    clone.timeToTake = log.takenAt
    clone.logReferenceID = medication.id
    clone.logEntryID = log.id
    return clone
}

// MARK: - Button Style
// ScaleButtonStyle is now defined in UIComponents.swift

fileprivate struct DoseButtonState: Identifiable {
    enum Status {
        case pending
        case taken
        case skipped
    }
    
    let index: Int
    let status: Status
    let scheduledTime: Date?
    let customTitle: String?
    
    let actualTime: Date?

    init(index: Int, status: Status, scheduledTime: Date?, customTitle: String? = nil, actualTime: Date? = nil) {
        self.index = index
        self.status = status
        self.scheduledTime = scheduledTime
        self.customTitle = customTitle
        self.actualTime = actualTime
    }
    
    var id: Int { index }
    var title: String {
        customTitle ?? "Dose \(index + 1)"
    }
    
    var actionLabel: String {
        switch status {
        case .pending:
            return "Tap to log"
        case .taken:
            return "Taken"
        case .skipped:
            return "Dose skipped"
        }
    }
    
    var iconName: String {
        switch status {
        case .pending:
            return "circle"
        case .taken:
            return "checkmark.circle.fill"
        case .skipped:
            return "xmark.circle.fill"
        }
    }
    
    var foregroundColor: Color {
        switch status {
        case .pending:
            return Color.pillrBackground
        case .taken:
            return Color.pillrPrimary
        case .skipped:
            return Color(hex: "#FFF0F1")
        }
    }
    
    var backgroundColor: Color {
        switch status {
        case .pending:
            return Color.white.opacity(0.08)
        case .taken:
            return Color(hex: "#CDE5C8")
        case .skipped:
            return Color(hex: "#8B3E44")
        }
    }
    
    var formattedTime: String? {
        guard let scheduledTime else { return nil }
        return DoseButtonState.timeFormatter.string(from: scheduledTime)
    }

    var loggedTimeLabel: String? {
        switch status {
        case .skipped:
            return "Dose skipped"
        case .taken:
            guard let actualTime else { return "Taken" }
            return "Taken \(DoseButtonState.loggedTimeFormatter.string(from: actualTime))"
        case .pending:
            return nil
        }
    }
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let loggedTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

fileprivate struct MedicationStatusLabel: View {
    let text: String
    let foregroundColor: Color
    let iconForegroundColor: Color?
    let iconName: String?
    let iconCircleColor: Color?
    let textFont: Font
    let iconSize: CGFloat
    let iconWeight: Font.Weight
    let circleSize: CGFloat

    init(
        text: String,
        foregroundColor: Color,
        iconForegroundColor: Color? = nil,
        iconName: String?,
        iconCircleColor: Color?,
        textFont: Font = .system(size: 17, weight: .semibold),
        iconSize: CGFloat = 10,
        iconWeight: Font.Weight = .medium,
        circleSize: CGFloat = 18
    ) {
        self.text = text
        self.foregroundColor = foregroundColor
        self.iconForegroundColor = iconForegroundColor
        self.iconName = iconName
        self.iconCircleColor = iconCircleColor
        self.textFont = textFont
        self.iconSize = iconSize
        self.iconWeight = iconWeight
        self.circleSize = circleSize
    }

    var body: some View {
        HStack(spacing: 6) {
            if let iconName {
                Image(systemName: iconName)
                    .font(.system(size: iconSize, weight: iconWeight))
                    .foregroundColor(iconForegroundColor ?? foregroundColor)
                    .frame(width: circleSize, alignment: .center)
            }

            Text(text)
                .font(textFont)
                .foregroundColor(foregroundColor)
        }
    }
}

fileprivate enum MedicationCardPalette {
    static let background = Color(hex: "#59655B")
    static let secondaryTint = Color(hex: "#424C43")
    static let divider = Color(hex: "#8C988E")
    static let titleText = Color(hex: "#F1F3F0")
    static let secondaryText = Color(hex: "#D6DBD3")
    static let timeText = Color(hex: "#E8ECE6")
    static let primaryAction = Color(hex: "#424C43")
    static let urgency = Color(hex: "#F5C4B3")
    static let takenBackground = Color(hex: "#DDE5DF")
    static let takenTitleText = Color(hex: "#2F3A33")
    static let takenSecondaryText = Color(hex: "#5F6E64")
    static let takenDivider = Color(hex: "#A9B7AD")
    static let takenStatusText = Color(hex: "#6F9D7A")
    static let skippedBackground = Color(hex: "#E8E0D8")
    static let skippedStatusText = Color(hex: "#8B7366")
}

// New fileprivate struct for the header content of a MedicationRow
fileprivate struct MedicationRowHeaderView: View {
    let medication: Medication
    let cycleStatus: MedicationCycleStatus
    let overdueMinutes: Int?
    let overdueBadgeActive: Bool
    @Binding var showDetails: Bool
    let doseStates: [DoseButtonState]
    let onRequestCustomLogTime: (Int?) -> Void
    let onSkipDose: (Int) -> Void
    let highlightedDoseIndex: Int?
    let compactLayout: Bool
    let referenceDate: Date
    let showsSkipButton: Bool
    let hideScheduleLine: Bool
    
    private let timelineTimeWidth: CGFloat = 58
    private let logButtonMinWidth: CGFloat = 96
    private let overdueHighlightColor = MedicationCardPalette.urgency

	    private var usesTimelineLayout: Bool {
	        !doseStates.isEmpty && !compactLayout
	    }

	    private var pendingDoseIndex: Int? {
	        doseStates.first(where: { $0.status == .pending })?.index
	    }

    private var horizontalPadding: CGFloat {
        compactLayout ? 14 : 18
    }

    private var verticalPadding: CGFloat {
        if compactLayout {
            return 12
        }
        if allDosesLogged {
            return usesTimelineLayout ? 12 : 11
        }
        return usesTimelineLayout ? 18 : 14
    }

    private var stackSpacing: CGFloat {
        if usesTimelineLayout {
            return 12
        }
        return compactLayout ? 4 : 0
    }

    private var headerIsLoggedStatus: Bool {
        switch cycleStatus {
        case .taken, .skipped:
            return true
        default:
            return false
        }
    }

    private var usesLightLoggedCardStyle: Bool {
        cycleStatus == .taken || cycleStatus == .skipped
    }

    private var loggedCardBackgroundColor: Color {
        cycleStatus == .skipped ? MedicationCardPalette.skippedBackground : MedicationCardPalette.takenBackground
    }

    private var headerTitleColor: Color {
        usesLightLoggedCardStyle ? MedicationCardPalette.takenTitleText : MedicationCardPalette.titleText
    }

    private var headerSecondaryColor: Color {
        usesLightLoggedCardStyle ? MedicationCardPalette.takenSecondaryText : MedicationCardPalette.secondaryText
    }

    private var headerTitleOpacity: Double {
        if cycleStatus == .taken {
            return 0.82
        }
        if cycleStatus == .skipped {
            return 0.9
        }
        return headerIsLoggedStatus ? 0.9 : 1.0
    }

    private var detailTextOpacity: Double {
        cycleStatus == .taken ? 0.72 : 1.0
    }

    private var allDosesLogged: Bool {
        guard !doseStates.isEmpty else { return false }
        return doseStates.allSatisfy { $0.status != .pending }
    }

    private var doseRowVerticalPadding: CGFloat {
        allDosesLogged ? 6 : 9
    }

    private func startOfMinute(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }

    private func isOverdueDose(_ state: DoseButtonState) -> Bool {
        guard medication.reminderTimes.count > 1 else { return false }
        guard state.status == .pending else { return false }
        guard state.scheduledTime != nil else { return false }
        let dueTime = calculateDueTime(for: medication, reminderIndex: state.index, referenceDate: referenceDate)
        let nowMinute = startOfMinute(referenceDate)
        let dueMinute = startOfMinute(dueTime)
        return dueMinute < nowMinute
    }
    
    // Moved statusDisplay computed property
    private var statusDisplay: (text: String, color: Color, show: Bool) {
        if medication.frequency == "As needed" {
            return ("", .clear, false) // No status text for "As needed" meds
        }
        if overdueBadgeActive, let minutesPast = overdueMinutes {
            return ("\(formatOverdueTimeText(minutes: minutesPast)) overdue", MedicationCardPalette.urgency, true)
        }
        switch cycleStatus {
        case .taken:
            return ("", .clear, false) // No status text when taken, button shows "Taken"
        case .skipped:
            return ("", .clear, false) // No status text when skipped, button shows "Dose skipped"
        case .overdue(let minutesPast):
            return ("\(formatOverdueTimeText(minutes: minutesPast)) overdue", MedicationCardPalette.urgency, true)
        case .due(let minutesRemaining):
            if minutesRemaining > 0 {
                return ("Due in \(formatTimeText(minutes: minutesRemaining))", MedicationCardPalette.titleText, true)
            }
            return ("Due now", MedicationCardPalette.titleText, true)
        case .asNeeded: // Add .asNeeded case
            return ("", .clear, false)
        }
    }
    
    // Format minutes into human-readable text
    private func formatTimeText(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min\(minutes == 1 ? "" : "s")"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            
            if remainingMinutes == 0 {
                let hourText = hours == 1 ? "hour" : "hours"
                return "\(hours) \(hourText)"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }

    private func formatOverdueTimeText(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }

    private struct DoseBadgeItem: Identifiable {
        let id: Int
        let text: String
        let color: Color
        let iconName: String?
        let iconCircleColor: Color?
        let isMinimal: Bool
    }

    private var takenDoseBadges: [DoseBadgeItem] {
        guard compactLayout else { return [] }
        let showDoseLabel = doseStates.count > 1
        var badges: [DoseBadgeItem] = []

        for state in doseStates {
            switch state.status {
            case .taken:
                if let actualTime = state.actualTime {
                    let timeText = Self.badgeTimeFormatter.string(from: actualTime)
                    let prefix: String? = showDoseLabel
                        ? ((state.customTitle?.isEmpty == false) ? state.customTitle : "Dose \(state.index + 1)")
                        : nil
                    let label = prefix != nil ? "\(prefix!) taken at \(timeText)" : "Taken at \(timeText)"
                    badges.append(
                        DoseBadgeItem(
                            id: state.index,
                            text: label,
                            color: Color(hex: "#5E886B"),
                            iconName: "checkmark",
                            iconCircleColor: Color(hex: "#ECF5EE"),
                            isMinimal: badges.isEmpty && doseStates.count == 1
                        )
                    )
                }

            case .skipped:
                let prefix: String? = showDoseLabel
                    ? ((state.customTitle?.isEmpty == false) ? state.customTitle : "Dose \(state.index + 1)")
                        : nil
                let timeText = state.actualTime.map { Self.badgeTimeFormatter.string(from: $0) } ?? "today"
                let label = prefix != nil ? "\(prefix!) skipped at \(timeText)" : "Skipped at \(timeText)"
                badges.append(
                    DoseBadgeItem(
                        id: state.index,
                        text: label,
                        color: Color(hex: "#8C6B5D"),
                        iconName: "xmark",
                        iconCircleColor: Color(hex: "#F2E4DA"),
                        isMinimal: badges.isEmpty && doseStates.count == 1
                    )
                )

            case .pending:
                continue
            }
        }

        return badges
    }

    @ViewBuilder
    private var doseBadgesView: some View {
        let badges = takenDoseBadges
        if !badges.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(badges) { badge in
                    if badge.isMinimal {
                        MedicationStatusLabel(
                            text: badge.text,
                            foregroundColor: badge.color.opacity(0.92),
                            iconName: badge.iconName,
                            iconCircleColor: badge.iconCircleColor?.opacity(0.55),
                            textFont: .system(size: 14, weight: .medium),
                            iconSize: 7,
                            iconWeight: .semibold,
                            circleSize: 14
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        MedicationStatusLabel(
                            text: badge.text,
                            foregroundColor: MedicationCardPalette.takenSecondaryText.opacity(0.92),
                            iconForegroundColor: badge.color,
                            iconName: badge.iconName,
                            iconCircleColor: nil,
                            textFont: .system(size: 14, weight: .medium),
                            iconSize: 8,
                            iconWeight: .semibold,
                            circleSize: 16
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
            .padding(.bottom, badgeBottomPadding)
        }
    }

    private var badgeBottomPadding: CGFloat {
        takenDoseBadges.count == 1 && takenDoseBadges.first?.isMinimal == true ? 2 : 4
    }


    private static let badgeTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private var canPerformPrimaryAction: Bool {
        switch cycleStatus {
        case .due, .overdue, .asNeeded:
            return true
        default:
            return false
        }
    }

    private var skipActionAvailable: Bool {
        pendingDoseIndex != nil
    }

    private var baseTakeButtonColors: (fg: Color, bg: Color, border: Color) {
        (
            fg: MedicationCardPalette.primaryAction,
            bg: MedicationCardPalette.titleText,
            border: MedicationCardPalette.titleText.opacity(0.9)
        )
    }

    private var baseSkipButtonColors: (fg: Color, bg: Color, border: Color) {
        (
            fg: MedicationCardPalette.secondaryText,
            bg: MedicationCardPalette.background,
            border: MedicationCardPalette.divider.opacity(0.5)
        )
    }

    private var takeButtonStyle: (fg: Color, bg: Color, border: Color) {
        if canPerformPrimaryAction {
            return baseTakeButtonColors
        } else {
            return (
                fg: MedicationCardPalette.secondaryText.opacity(0.75),
                bg: MedicationCardPalette.background,
                border: MedicationCardPalette.divider.opacity(0.35)
            )
        }
    }

    private var skipButtonStyle: (fg: Color, bg: Color, border: Color) {
        if skipActionAvailable {
            return baseSkipButtonColors
        } else {
            return (
                fg: MedicationCardPalette.secondaryText.opacity(0.75),
                bg: Color.clear,
                border: MedicationCardPalette.divider.opacity(0.35)
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: stackSpacing) {
            HStack(alignment: .center, spacing: 10) {
                medicationInfoSection
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    if !usesTimelineLayout && !compactLayout {
                        actionButtonRow
                            .padding(.top, cycleStatus == .asNeeded ? 34 : 0)
                    }
                }
            }
            if usesTimelineLayout {
                Rectangle()
                    .fill(MedicationCardPalette.divider.opacity(0.35))
                    .frame(height: 1)
                    .padding(.top, 4)
                multiDoseGrid
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showDetails.toggle()
            }
        }
    }
    
    private var medicationInfoSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(medication.name)
                .font(.system(size: compactLayout ? 19 : 21, weight: .semibold))
                .foregroundColor(headerTitleColor.opacity(headerTitleOpacity))
                .lineLimit(2)
                .minimumScaleFactor(0.9)
            
            if hasSubtitle {
                subtitleView
            }

            if compactLayout {
                doseBadgesView
                    .padding(.top, 2)
                    .padding(.bottom, 6)
            }
        }
    }
    
    private var dosageAmountLine: String {
        let baseDosage = medication.dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = medication.dosageUnit.trimmingCharacters(in: .whitespacesAndNewlines)

        if baseDosage.isEmpty {
            return trimmedUnit
        } else if trimmedUnit.isEmpty {
            return baseDosage
        }

        return "\(baseDosage) \(trimmedUnit)"
    }

    private var scheduleLine: String {
        guard !hideScheduleLine else { return "" }
        return medication.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSubtitle: Bool {
        !dosageAmountLine.isEmpty || !scheduleLine.isEmpty || statusDisplay.show
    }

    private var subtitleView: some View {
        subtitleLineText
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var subtitleOpacity: Double {
        0.95
    }

    private var subtitleLineText: Text {
        let display = statusDisplay
        let separator = Text(" • ")
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(headerSecondaryColor.opacity(subtitleOpacity))
        let statusSeparator = Text("  • ")
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(headerSecondaryColor.opacity(subtitleOpacity))

        var text = Text("")

        if !dosageAmountLine.isEmpty {
            text = text + Text(dosageAmountLine)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(headerSecondaryColor.opacity(subtitleOpacity))
        }

        if !scheduleLine.isEmpty {
            if !dosageAmountLine.isEmpty {
                text = text + separator
            }
            text = text + Text(scheduleLine)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(headerSecondaryColor.opacity(subtitleOpacity))
        }

        if display.show {
            if !dosageAmountLine.isEmpty || !scheduleLine.isEmpty {
                text = text + statusSeparator
            }
            text = text + Text(display.text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(display.color)
        }

        return text
    }
    
    private var actionButtonRow: some View {
        Group {
            if showsSkipButton {
                takeSkipButtonRow
            } else {
                takeOnlyButtonRow
            }
        }
    }

    private var takeSkipButtonRow: some View {
        HStack(spacing: 12) {
            takeButton
            skipButton
        }
        .frame(maxWidth: 224)
    }

    private var takeOnlyButtonRow: some View {
        takeButton
            .frame(width: cycleStatus == .asNeeded ? 144 : 148)
    }
    
    private var takeButton: some View {
        let style = takeButtonStyle
        
        return Button(action: {
            handleButtonTap()
        }) {
            Text("Take")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(style.fg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(style.bg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style.border, lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canPerformPrimaryAction)
    }

    private var skipButton: some View {
        let style = skipButtonStyle
        
        return Button(action: {
            guard let index = pendingDoseIndex else { return }
            HapticManager.shared.warningNotification()
            onSkipDose(index)
        }) {
            Text("Skip")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(style.fg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(style.bg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style.border, lineWidth: 0.8)
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!skipActionAvailable)
    }

    private var multiDoseGrid: some View {
        VStack(spacing: 0) {
            let primaryIndex = highlightedDoseIndex
            ForEach(Array(doseStates.enumerated()), id: \.offset) { index, state in
                let isPrimary = primaryIndex != nil ? state.index == primaryIndex : false
                doseCardRow(for: state, isPrimary: isPrimary)
                    .padding(.vertical, doseRowVerticalPadding)
                if index < doseStates.count - 1 {
                    Rectangle()
                        .fill(MedicationCardPalette.divider.opacity(0.3))
                        .frame(height: 1)
                        .padding(.top, doseRowVerticalPadding)
                        .padding(.bottom, doseRowVerticalPadding)
                }
            }
        }
        .padding(.top, 2)
    }

    private func doseCardRow(for state: DoseButtonState, isPrimary: Bool) -> some View {
        let displayText = state.formattedTime ?? state.title
        let capsuleCornerRadius: CGFloat = 10
        let capsuleVerticalPadding: CGFloat = 9
        let interButtonSpacing: CGFloat = 10
        let textFont: Font = .system(size: 14)
        let takeStyle = baseTakeButtonColors
        let skipStyle = baseSkipButtonColors

        return HStack(spacing: 12) {
            if state.status == .taken, let actualTime = state.actualTime {
                let loggedText = "Taken at \(Self.badgeTimeFormatter.string(from: actualTime))"
                MedicationStatusLabel(
                    text: loggedText,
                    foregroundColor: MedicationCardPalette.timeText.opacity(0.96),
                    iconForegroundColor: Color(hex: "#5E886B"),
                    iconName: "checkmark",
                    iconCircleColor: Color(hex: "#ECF5EE"),
                    textFont: .system(size: 14, weight: .medium),
                    iconSize: 7,
                    iconWeight: .semibold,
                    circleSize: 14
                )
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .frame(minWidth: logButtonMinWidth, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
            } else if state.status == .skipped {
                MedicationStatusLabel(
                    text: state.loggedTimeLabel ?? "Dose skipped",
                    foregroundColor: MedicationCardPalette.timeText.opacity(0.96),
                    iconForegroundColor: Color(hex: "#8C6B5D"),
                    iconName: "xmark",
                    iconCircleColor: Color(hex: "#F2E4DA"),
                    textFont: .system(size: 14, weight: .medium),
                    iconSize: 7,
                    iconWeight: .medium,
                    circleSize: 14
                )
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .frame(minWidth: logButtonMinWidth, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
            } else {
                HStack(spacing: interButtonSpacing) {
                    Button(action: {
                        handleDoseButtonTap(for: state)
                    }) {
                        Text("Take")
                            .font(textFont.weight(.semibold))
                            .foregroundColor(takeStyle.fg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, capsuleVerticalPadding)
                            .background(
                                RoundedRectangle(cornerRadius: capsuleCornerRadius)
                                    .fill(takeStyle.bg)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: capsuleCornerRadius)
                                    .stroke(takeStyle.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: {
                        HapticManager.shared.warningNotification()
                        onSkipDose(state.index)
                    }) {
                        Text("Skip")
                            .font(textFont.weight(.semibold))
                            .foregroundColor(skipStyle.fg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, capsuleVerticalPadding)
                            .background(
                                RoundedRectangle(cornerRadius: capsuleCornerRadius)
                                    .fill(skipStyle.bg)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: capsuleCornerRadius)
                                    .stroke(skipStyle.border, lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            if shouldShowDoseLabel(for: state) {
                let isOverdue = isOverdueDose(state)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(displayText)
                        .font(.system(.body, design: .default).weight(.semibold))
                        .foregroundColor(isOverdue ? overdueHighlightColor : MedicationCardPalette.timeText.opacity(state.status == .pending ? 1 : 0.7))
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.85)
                        .frame(minWidth: timelineTimeWidth, alignment: .trailing)
                        .padding(.trailing, 6)
                        .layoutPriority(1)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    private func shouldShowDoseLabel(for state: DoseButtonState) -> Bool {
        guard medication.frequency != "As needed" else {
            return state.scheduledTime != nil
        }
        return true
    }
    
    private func nodeFill(for state: DoseButtonState) -> Color {
        switch state.status {
        case .pending:
            return Color.pillrAccent
        case .taken:
            return Color.pillrSecondary
        case .skipped:
            return Color(hex: "#7A3330")
        }
    }
    
    private func nodeIconColor(for state: DoseButtonState) -> Color {
        switch state.status {
        case .pending:
            return Color.pillrBackground
        case .taken:
            return Color.pillrAccent
        case .skipped:
            return Color(hex: "#FFE4E6")
        }
    }
    
    // Handle button tap with appropriate haptic feedback
    private func handleButtonTap() {
        switch cycleStatus {
        case .due(_), .overdue(_):
            HapticManager.shared.successNotification()
        case .taken, .skipped:
            HapticManager.shared.lightImpact()
        case .asNeeded: // Add .asNeeded case
            HapticManager.shared.lightImpact()
        }
        onRequestCustomLogTime(nil)
    }

    private func handleDoseButtonTap(for state: DoseButtonState) {
        guard state.status == .pending else { return }

        HapticManager.shared.successNotification()
        withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.75)) {
            onRequestCustomLogTime(state.index)
        }
    }
}

@MainActor
struct MedicationRow: View {
    let medication: Medication
    let referenceDate: Date
    let isDashboardHighlighted: Bool
    let onPresentUndoToast: (MedicationStore.LogUndoAction) -> Void
    let onRequestCustomLogTime: (Medication, Int?) -> Void
    let onRefillBannerTap: () -> Void
    let onDailyCheckInTap: () -> Void
    let onEditTap: () -> Void
    let onDeleteTap: (() -> Void)?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var store: MedicationStore
    @State private var isNotificationGlowActive = false
    @State private var notificationGlowResetWorkItem: DispatchWorkItem?
    private let notificationGlowDuration: TimeInterval = 2.0

    private var isHighlightGlowActive: Bool {
        isNotificationGlowActive || isDashboardHighlighted
    }
    
    private var todaysLogsForMedication: [MedicationLog] {
        let calendar = Calendar.current
        if let logEntryID = medication.logEntryID {
            return store.logs.filter { log in
                log.id == logEntryID &&
                calendar.isDate(log.takenAt, inSameDayAs: referenceDate) &&
                log.isDoseLog
            }
        }
        return store.logs.filter { log in
            log.medicationID == medication.logIdentifier &&
            calendar.isDate(log.takenAt, inSameDayAs: referenceDate) &&
            log.isDoseLog
        }
    }
    
    private var totalDosesForToday: Int {
        let scheduledCount = medication.reminderTimes.isEmpty ? 1 : medication.reminderTimes.count
        return max(1, scheduledCount)
    }
    
    private var completedDoseCount: Int {
        if medication.reminderTimes.isEmpty {
            return todaysLogsForMedication.isEmpty ? 0 : 1
        }
        
        var uniqueIndices = Set<Int>()
        var unspecifiedCount = 0
        for log in todaysLogsForMedication {
            if let index = log.reminderIndex {
                uniqueIndices.insert(index)
            } else {
                unspecifiedCount += 1
            }
        }
        
        return min(totalDosesForToday, uniqueIndices.count + unspecifiedCount)
    }
    
    private var hasRemainingDoseToday: Bool {
        if medication.frequency == "As needed" && medication.reminderTimes.isEmpty {
            return todaysLogsForMedication.isEmpty
        }
        return completedDoseCount < totalDosesForToday
    }
    
    private var hasTakenDoseToday: Bool {
        todaysLogsForMedication.contains { !$0.skipped }
    }
    
    private var hasSkippedDoseToday: Bool {
        todaysLogsForMedication.contains { $0.skipped }
    }

    private var hasAnyLoggedDoseToday: Bool {
        hasTakenDoseToday || hasSkippedDoseToday
    }

    private var isDailyCheckInOverdue: Bool {
        store.isDailyCheckInOverdue(for: medication, referenceDate: referenceDate)
    }

    private var hasCompletedDailyCheckInToday: Bool {
        store.hasCompletedDailyCheckInToday(for: medication, referenceDate: referenceDate)
    }
    
    private var doseButtonStates: [DoseButtonState] {
        if medication.frequency == "As needed" && medication.reminderTimes.isEmpty {
            let log = todaysLogsForMedication.sorted(by: { $0.takenAt > $1.takenAt }).first
            let status: DoseButtonState.Status
            if let log = log {
                status = log.skipped ? .skipped : .taken
            } else {
                status = .pending
            }
            return [
                DoseButtonState(
                    index: 0,
                    status: status,
                    scheduledTime: nil,
                    customTitle: "As needed",
                    actualTime: log?.takenAt
                )
            ]
        }
        
        let scheduleTimes: [Date]
        if medication.reminderTimes.isEmpty {
            scheduleTimes = [medication.timeToTake]
        } else {
            scheduleTimes = medication.reminderTimes
        }
        
        var states: [DoseButtonState] = []
        var unassignedLogs = todaysLogsForMedication.filter { $0.reminderIndex == nil }
        
        for index in 0..<scheduleTimes.count {
            let scheduledTime = scheduleTimes[index]
            if let log = todaysLogsForMedication.first(where: { $0.reminderIndex == index }) {
                let status: DoseButtonState.Status = log.skipped ? .skipped : .taken
                states.append(DoseButtonState(index: index, status: status, scheduledTime: scheduledTime, actualTime: log.takenAt))
            } else if !unassignedLogs.isEmpty {
                let fallbackLog = unassignedLogs.removeFirst()
                let status: DoseButtonState.Status = fallbackLog.skipped ? .skipped : .taken
                states.append(DoseButtonState(index: index, status: status, scheduledTime: scheduledTime, actualTime: fallbackLog.takenAt))
            } else {
                states.append(DoseButtonState(index: index, status: .pending, scheduledTime: scheduledTime))
            }
        }
        
        return states
    }
    
    private var nextPendingDoseIndex: Int? {
        doseButtonStates.first { $0.status == .pending }?.index
    }
    
    private var highlightedDoseIndex: Int? {
        if let pending = nextPendingDoseIndex {
            return pending
        }
        return nil
    }
    
    private func nextReminderIndexToLog() -> Int? {
        guard !medication.reminderTimes.isEmpty else { return nil }
        let usedIndices = Set(todaysLogsForMedication.compactMap { $0.reminderIndex })
        for index in 0..<medication.reminderTimes.count {
            if !usedIndices.contains(index) {
                return index
            }
        }
        return nil
    }

    private var resolvedMedicationForLogging: Medication {
        store.findMedication(with: medication.logReferenceID ?? medication.id) ?? medication
    }
    
    // Helper to get the effective due time, considering the reset logic
    private var effectiveDueTime: Date {
        let now = referenceDate
        if let pendingIndex = nextPendingDoseIndex {
            return calculateDueTime(for: medication, reminderIndex: pendingIndex, referenceDate: now)
        }
        return calculateEffectiveDueTime(for: medication, at: now)
    }

    private func startOfMinute(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }

    // Calculates minutes to the effective due time
    private var minutesToEffectiveDueTime: Int {
        let now = referenceDate
        let calendar = Calendar.current
        let nowMinute = startOfMinute(now)
        let dueMinute = startOfMinute(effectiveDueTime)
        return calendar.dateComponents([.minute], from: nowMinute, to: dueMinute).minute ?? 0
    }

    private var overdueMinutesForBadge: Int? {
        let minutes = minutesToEffectiveDueTime
        return minutes < 0 ? abs(minutes) : nil
    }

    private var overdueBadgeMedicationID: UUID {
        medication.logReferenceID ?? medication.id
    }

    private var isOverdueBadgeActive: Bool {
        store.overdueMedicationIDs.contains(overdueBadgeMedicationID)
    }
    
    private var cycleStatus: MedicationCycleStatus {
        if !hasRemainingDoseToday {
            if hasTakenDoseToday {
                return .taken
            } else if hasSkippedDoseToday {
                return .skipped
            }
        }
        
        if medication.frequency == "As needed" { // Then check if it's "As needed" and not yet taken/skipped
            return .asNeeded
        }
        
        let minutes = minutesToEffectiveDueTime
        
        if minutes < 0 {
            // Once the daily due time has passed (but before midnight),
            // show this as overdue rather than jumping ahead 24 hours.
            return .overdue(minutesPast: abs(minutes))
        } else { // Due in the future (today or later)
            return .due(minutesRemaining: minutes)
        }
    }

    private var isLoggedStatus: Bool {
        switch cycleStatus {
        case .taken, .skipped:
            return true
        default:
            return false
        }
    }
    
    private var isOverdueStatus: Bool {
        if case .overdue = cycleStatus {
            return true
        }
        return false
    }

    private var usesLightLoggedCardStyle: Bool {
        cycleStatus == .taken || cycleStatus == .skipped
    }

    private var loggedCardBackgroundColor: Color {
        cycleStatus == .skipped ? MedicationCardPalette.skippedBackground : MedicationCardPalette.takenBackground
    }

    private var takenCardColor: Color {
        usesLightLoggedCardStyle ? loggedCardBackgroundColor : MedicationCardPalette.background
    }

    private var cardBackgroundColor: Color {
        takenCardColor
    }

    private var innerStrokeColor: Color {
        if usesLightLoggedCardStyle {
            return MedicationCardPalette.takenDivider.opacity(0.7)
        }
        if isOverdueStatus {
            return MedicationCardPalette.divider.opacity(0.42)
        }
        return MedicationCardPalette.divider.opacity(0.7)
    }

    private var innerStrokeWidth: CGFloat {
        switch cycleStatus {
        case .taken:
            return 1
        case .skipped:
            return 1
        case .overdue:
            return 0.9
        case .due:
            return 0.8
        case .asNeeded:
            return 0.6
        }
    }

    private var cardPrimaryShadowOpacity: Double {
        if usesLoggedCardStyle {
            return 0.015
        }
        return isLoggedStatus ? 0.18 : 0.25
    }

    private var cardPrimaryShadowRadius: CGFloat {
        if usesLoggedCardStyle {
            return 2
        }
        return isLoggedStatus ? 10 : 12
    }

    private var cardPrimaryShadowYOffset: CGFloat {
        if usesLoggedCardStyle {
            return 0.5
        }
        return isLoggedStatus ? 4 : 6
    }

    private var cardSecondaryShadowOpacity: Double {
        if usesLoggedCardStyle {
            return 0
        }
        return isLoggedStatus ? 0.08 : 0.1
    }

    private var cardSecondaryShadowRadius: CGFloat {
        if usesLoggedCardStyle {
            return 0
        }
        return isLoggedStatus ? 3 : 4
    }

    private var cardSecondaryShadowYOffset: CGFloat {
        if usesLoggedCardStyle {
            return 0
        }
        return isLoggedStatus ? 1 : 2
    }

    private var usesLoggedCardStyle: Bool {
        switch cycleStatus {
        case .taken, .skipped:
            return true
        default:
            return false
        }
    }

    private var skippedAccentColor: Color {
        MedicationCardPalette.divider
    }

    private var accessoryIconColor: Color {
        usesLightLoggedCardStyle ? MedicationCardPalette.takenTitleText : Color.pillrBackground.opacity(0.85)
    }

    private var accessoryBackgroundColor: Color {
        usesLightLoggedCardStyle ? loggedCardBackgroundColor : MedicationCardPalette.background
    }

    private var accessoryBorderColor: Color {
        usesLightLoggedCardStyle ? MedicationCardPalette.takenDivider : MedicationCardPalette.divider.opacity(0.7)
    }

    private var chevronColor: Color {
        usesLightLoggedCardStyle ? MedicationCardPalette.takenSecondaryText.opacity(0.85) : MedicationCardPalette.secondaryText.opacity(0.75)
    }

    private var lowPillBanner: (text: String, isUrgent: Bool)? {
        guard let pillCount = medication.pillCount,
              let refillThreshold = medication.refillThreshold,
              pillCount <= refillThreshold else {
            return nil
        }
        let pillsText = pillCount == 1 ? "pill" : "pills"
        let urgentCutoff = max(1, refillThreshold / 2)
        if pillCount <= urgentCutoff {
            return ("Refill now • \(pillCount) \(pillsText) left", true)
        }
        return ("Low supply • \(pillCount) \(pillsText) left", false)
    }

    var body: some View {
        let showsDetails = store.expandedMedicationID == medication.id
        let detailBinding = Binding<Bool>(
            get: { store.expandedMedicationID == medication.id },
            set: { newValue in
                if newValue {
                    store.expandedMedicationID = medication.id
                } else if store.expandedMedicationID == medication.id {
                    store.expandedMedicationID = nil
                }
            }
        )
        
        return VStack(spacing: 0) {
            // Use the new MedicationRowHeaderView
            MedicationRowHeaderView(
                medication: medication,
                cycleStatus: cycleStatus, // Pass the calculated cycleStatus
                overdueMinutes: overdueMinutesForBadge,
                overdueBadgeActive: isOverdueBadgeActive,
                showDetails: detailBinding,
                doseStates: doseButtonStates,
                onRequestCustomLogTime: { reminderIndex in
                    onRequestCustomLogTime(medication, reminderIndex)
                },
                onSkipDose: { doseIndex in
                    skipDose(at: doseIndex)
                },
                highlightedDoseIndex: highlightedDoseIndex,
                compactLayout: usesLoggedCardStyle,
                referenceDate: referenceDate,
                showsSkipButton: true,
                hideScheduleLine: false
            )
            
            if showsDetails {
                MedicationRowDetailsView(
                    medication: medication,
                    referenceDate: referenceDate,
                    useTakenStyle: usesLightLoggedCardStyle,
                    useSkippedStyle: cycleStatus == .skipped,
                    onEditTap: onEditTap,
                    moreActionTitle: hasAnyLoggedDoseToday ? "Undo dose" : nil,
                    onMoreActionTap: nil,
                    onMoreActionTapForLog: hasAnyLoggedDoseToday ? { log in
                        HapticManager.shared.lightImpact()
                        store.removeDoseLog(log)
                    } : nil,
                    onDeleteTap: onDeleteTap
                )
                .padding(.top, 8)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    )
                )
            }
        }
        .background(
            cardBackgroundColor
        )
        .cornerRadius(12)
        .clipped()
        .overlay(notificationGlowOverlay)
        .overlay(alignment: .bottomTrailing) {
            if medication.enableDailyCheckIn && hasTakenDoseToday && !showsDetails {
                Button(action: {
                    guard !hasCompletedDailyCheckInToday else { return }
                    onDailyCheckInTap()
                }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(hasCompletedDailyCheckInToday ? accessoryIconColor.opacity(0.45) : accessoryIconColor)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(hasCompletedDailyCheckInToday ? accessoryBackgroundColor.opacity(0.55) : accessoryBackgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(accessoryBorderColor.opacity(hasCompletedDailyCheckInToday ? 0.45 : 1.0), lineWidth: 0.7)
                                    )
                            )

                        if hasCompletedDailyCheckInToday {
                            Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(accessoryIconColor.opacity(0.8))
                                .padding(1)
                                .background(
                                    Circle()
                                        .fill(accessoryBackgroundColor)
                                )
                                .offset(x: 4, y: -4)
                                .accessibilityHidden(true)
                        } else if isDailyCheckInOverdue {
                            Circle()
                                .fill(Color(hex: "#FF5A5A"))
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                                )
                                .offset(x: 4, y: -4)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(hasCompletedDailyCheckInToday)
                .padding(.trailing, 10)
                .padding(.bottom, 10)
                .accessibilityLabel(hasCompletedDailyCheckInToday ? "Reflection completed today" : "Log Reflection")
            }
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 8) {
                if let banner = lowPillBanner {
                    Button(action: onRefillBannerTap) {
                        HStack(spacing: 5) {
                            if banner.isUrgent {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            Text(banner.text)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#FFB74D"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .lineLimit(1)
                            .background(
                                Capsule()
                                    .fill(MedicationCardPalette.background)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(hex: "#FFB74D").opacity(0.8), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                    .padding(.top, 10)
                    .accessibilityLabel("Refill needed, \(banner.text)")
                    .accessibilityHint("Double tap to update refill amount and reminder level")
                }

                Button(action: {
                    toggleExpansion()
                }) {
                    Image(systemName: showsDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13))
                        .foregroundColor(chevronColor)
                        .padding(.top, lowPillBanner == nil ? 12 : 0)
                        .padding(.trailing, 12)
                        .padding(.bottom, 10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(innerStrokeColor, lineWidth: innerStrokeWidth)
        )
        .overlay(enhancedBorderOverlay)
        .shadow(color: Color.black.opacity(cardPrimaryShadowOpacity), radius: cardPrimaryShadowRadius, x: 0, y: cardPrimaryShadowYOffset)
        .shadow(color: Color.black.opacity(cardSecondaryShadowOpacity), radius: cardSecondaryShadowRadius, x: 0, y: cardSecondaryShadowYOffset)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: showsDetails)
        .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.72, blendDuration: 0.25), value: isLoggedStatus)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(medication.name), \(medication.dosage), \(medication.frequency), \(commonFormatTime(medication.timeToTake))")
        .accessibilityHint(accessibilityHintText())
        .accessibilityValue(accessibilityValueText())
        .accessibilityAction(.default) {
            switch cycleStatus {
            case .due(_), .overdue(_):
                onRequestCustomLogTime(medication, nil)
            case .taken, .skipped:
                toggleExpansion()
            case .asNeeded:
                onRequestCustomLogTime(medication, nil)
            }
        }
        .accessibilityAction(named: accessibilityActionName()) {
            toggleExpansion()
        }
        .onTapGesture {
            toggleExpansion()
        }
        .onAppear {
            handleNotificationHighlightChange(store.notificationHighlightMedicationID)
        }
        .onChange(of: store.notificationHighlightMedicationID) { _, newValue in
            handleNotificationHighlightChange(newValue)
        }
        .onDisappear {
            notificationGlowResetWorkItem?.cancel()
            isNotificationGlowActive = false
        }
    }
    
    private var notificationGlowOverlay: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(MedicationCardPalette.divider.opacity(isHighlightGlowActive ? 0.95 : 0), lineWidth: isHighlightGlowActive ? 2.5 : 0)
            .shadow(color: MedicationCardPalette.divider.opacity(isHighlightGlowActive ? 0.9 : 0), radius: isHighlightGlowActive ? 18 : 0)
            .blur(radius: isHighlightGlowActive ? 0.5 : 0)
            .padding(-6)
            .blendMode(.screen)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.35), value: isHighlightGlowActive)
    }

    // Enhanced border overlay with better visual feedback
    private var enhancedBorderOverlay: some View {
        let isOverdueCard = isOverdueBadgeActive || {
            switch cycleStatus {
            case .overdue:
                return true
            default:
                return false
            }
        }()

        let borderColor = isOverdueCard ? MedicationCardPalette.urgency : MedicationCardPalette.divider
        let borderWidth: CGFloat = isOverdueCard ? 1.0 : 1.1
        let showSkippedGlow = false
        
        return ZStack {
            if showSkippedGlow {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(skippedAccentColor.opacity(0.3), lineWidth: borderWidth * 3.2)
                    .blur(radius: 6)
                    .padding(-6)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor.opacity(isOverdueCard ? 0.95 : 0.65), lineWidth: borderWidth)
        }
    }

    private func handleNotificationHighlightChange(_ newValue: UUID?) {
        guard newValue == medication.id else { return }
        triggerNotificationGlow()
        clearNotificationHighlightIfNeeded()
    }

    private var loggedBadge: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 14, weight: .heavy))
            .foregroundColor(Color.white)
            .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
    }

    private func triggerNotificationGlow() {
        notificationGlowResetWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.35)) {
            isNotificationGlowActive = true
        }
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.4)) {
                isNotificationGlowActive = false
            }
        }
        notificationGlowResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + notificationGlowDuration, execute: workItem)
    }

    private func clearNotificationHighlightIfNeeded() {
        DispatchQueue.main.async {
            if store.notificationHighlightMedicationID == medication.id {
                store.notificationHighlightMedicationID = nil
            }
        }
    }

    // Helper for accessibility hint text
    private func accessibilityHintText() -> String {
        switch cycleStatus {
        case .taken:
            return "Already taken today. Tap status or chevron to expand details."
        case .skipped:
            return "Skipped. Tap to log or tap status/chevron to expand details."
        case .due(_), .overdue(_):
            return "Tap to log in the app, or tap status/chevron to expand details."
        case .asNeeded: // Add .asNeeded case
            return "Tap to log in the app, or tap status/chevron to expand details."
        }
    }

    // Helper for accessibility value text
    private func accessibilityValueText() -> String {
        switch cycleStatus {
        case .taken:
            return "Taken today"
        case .skipped:
            return "Skipped today"
        case .due(let minutesRemaining):
            return minutesRemaining > 0 ? "Due in \(minutesRemaining) minutes" : "Due now"
        case .overdue(let minutesPast):
            return "Overdue by \(minutesPast) minutes"
        case .asNeeded:
            return "Take as needed"
        }
    }

    // Helper for accessibility action name
    private func accessibilityActionName() -> String {
        switch cycleStatus {
        case .taken, .skipped:
            return "View Details"
        case .due(_), .overdue(_):
            return "View Details Without Logging"
        case .asNeeded: // Add .asNeeded case
            return "View Details"
        }
    }
    
    // Quick log medication function for context menu
    private func quickLogMedication(taken: Bool) {
        guard hasRemainingDoseToday else { return }
        let now = Date()

        let reminderIndex = medication.reminderTimes.isEmpty ? nil : nextReminderIndexToLog()
        
        if medication.reminderTimes.count > 0 && reminderIndex == nil {
            return
        }
        
        if let action = store.logMedicationTaken(
            medication: resolvedMedicationForLogging,
            actualTime: now,
            notes: nil,
            skipped: !taken,
            reminderIndex: reminderIndex
        ) {
            onPresentUndoToast(action)
            if store.expandedMedicationID == medication.id {
                store.expandedMedicationID = nil
            }
        }
    }

    private func skipDose(at index: Int) {
        if medication.reminderTimes.isEmpty {
            guard todaysLogsForMedication.first(where: { $0.reminderIndex == nil }) == nil else { return }
            if let action = store.skipMedication(
                medication: resolvedMedicationForLogging,
                actualTime: Date(),
                notes: nil,
                reminderIndex: nil
            ) {
                onPresentUndoToast(action)
                if store.expandedMedicationID == medication.id {
                    store.expandedMedicationID = nil
                }
            }
            return
        }

        guard medication.reminderTimes.indices.contains(index) else { return }
        guard !todaysLogsForMedication.contains(where: { $0.reminderIndex == index }) else { return }

        if let action = store.skipMedication(
            medication: resolvedMedicationForLogging,
            actualTime: Date(),
            notes: nil,
            reminderIndex: index
        ) {
            onPresentUndoToast(action)
            if store.expandedMedicationID == medication.id {
                store.expandedMedicationID = nil
            }
        }
    }

    private func undoMostRecentLog(skipped: Bool) {
        guard let log = todaysLogsForMedication
            .filter({ $0.skipped == skipped })
            .sorted(by: { $0.takenAt > $1.takenAt })
            .first else { return }

        store.removeDoseLog(log)
    }
    
    private func toggleExpansion() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if store.expandedMedicationID == medication.id {
                store.expandedMedicationID = nil
            } else {
                store.expandedMedicationID = medication.id
            }
        }
    }
}

// MARK: - Medication Cycle Status Enum
fileprivate enum MedicationCycleStatus {
    case due(minutesRemaining: Int)
    case overdue(minutesPast: Int)
    case taken
    case skipped
    case asNeeded // New case
}

// MARK: - MedicationCycleStatus Equatable implementation
extension MedicationCycleStatus: Equatable {
    static func == (lhs: MedicationCycleStatus, rhs: MedicationCycleStatus) -> Bool {
        switch (lhs, rhs) {
        case (.taken, .taken), (.skipped, .skipped):
            return true
        case (.asNeeded, .asNeeded): // Add .asNeeded to Equatable
            return true
        case (.due(let lhsMinutes), .due(let rhsMinutes)):
            return lhsMinutes == rhsMinutes
        case (.overdue(let lhsMinutes), .overdue(let rhsMinutes)):
            return lhsMinutes == rhsMinutes
        default:
            return false
        }
    }
}

// MARK: - MedicationRowDetailsView
fileprivate struct MedicationRowDetailsView: View {
    let medication: Medication
    let referenceDate: Date
    let useTakenStyle: Bool
    let useSkippedStyle: Bool
    let onEditTap: () -> Void
    let moreActionTitle: String?
    let onMoreActionTap: (() -> Void)?
    let onMoreActionTapForLog: ((MedicationLog) -> Void)?
    let onDeleteTap: (() -> Void)?
    @EnvironmentObject var store: MedicationStore
    @State private var showingDeleteAction = false
    @State private var showingUntakeOptions = false

    private var detailBackgroundColor: Color {
        if useSkippedStyle {
            return MedicationCardPalette.skippedBackground
        }
        return useTakenStyle ? MedicationCardPalette.takenBackground : MedicationCardPalette.background
    }

    private var detailPrimaryTextColor: Color {
        if useSkippedStyle {
            return MedicationCardPalette.skippedStatusText
        }
        return useTakenStyle ? MedicationCardPalette.takenTitleText : Color.pillrBackground
    }

    private var detailSecondaryTextColor: Color {
        if useSkippedStyle {
            return MedicationCardPalette.skippedStatusText.opacity(0.82)
        }
        return useTakenStyle ? MedicationCardPalette.takenSecondaryText : Color.pillrSecondary
    }

    private var detailDividerColor: Color {
        if useSkippedStyle {
            return MedicationCardPalette.skippedStatusText
        }
        return useTakenStyle ? MedicationCardPalette.takenDivider : MedicationCardPalette.divider
    }

    private var actionButtonTextColor: Color {
        Color.white.opacity(0.92)
    }

    private var notificationsEnabled: Bool {
        return !(medication.notificationID == nil && medication.notificationIDs.isEmpty)
    }

    private var todaysLogsForMedication: [MedicationLog] {
        let calendar = Calendar.current
        return store.logs
            .filter { log in
                log.medicationID == medication.logIdentifier &&
                !log.hiddenFromMyMeds &&
                log.isDoseLog &&
                calendar.isDate(log.takenAt, inSameDayAs: referenceDate)
            }
            .sorted(by: { $0.takenAt < $1.takenAt })
    }

    private var untakeableLogs: [MedicationLog] {
        todaysLogsForMedication
    }

    private var pillsTakenToday: Int {
        todaysLogsForMedication.reduce(0) { partial, log in
            let consumed = log.pillsConsumed ?? medication.pillsPerDose
            return partial + max(consumed, 0)
        }
    }

    private var focusWindowTimingEntries: [FocusTimingEntry] {
        guard medication.hasStimulantTiming,
              medication.enableStimulantPhaseNotifications else {
            return []
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)

        if medication.frequency == "As needed" && medication.reminderTimes.isEmpty {
            return todaysLogsForMedication.map { FocusTimingEntry(baseTime: $0.takenAt, source: .logged) }
        }

        var entries: [FocusTimingEntry] = []
        var unassignedLogs = todaysLogsForMedication.filter { $0.reminderIndex == nil }
        let scheduledTimes = medication.reminderTimes.isEmpty ? [medication.timeToTake] : medication.reminderTimes

        for (index, rawTime) in scheduledTimes.enumerated() {
            let components = calendar.dateComponents([.hour, .minute], from: rawTime)
            guard let scheduledBase = calendar.date(
                bySettingHour: components.hour ?? 8,
                minute: components.minute ?? 0,
                second: 0,
                of: dayStart
            ) else {
                continue
            }

            let scheduledIndex = medication.reminderTimes.isEmpty ? nil : index
            let (baseTime, source) = actualDoseTime(
                for: scheduledIndex,
                scheduledBase: scheduledBase,
                unassignedLogs: &unassignedLogs
            )
            entries.append(
                FocusTimingEntry(baseTime: baseTime, source: source)
            )
        }

        return entries
    }

    private func actualDoseTime(
        for scheduledIndex: Int?,
        scheduledBase: Date,
        unassignedLogs: inout [MedicationLog]
    ) -> (baseTime: Date, source: FocusTimingSource) {
        if let index = scheduledIndex,
           let matchingLog = todaysLogsForMedication.first(where: { $0.reminderIndex == index }) {
            return (matchingLog.takenAt, .logged)
        }

        if !unassignedLogs.isEmpty {
            return (unassignedLogs.removeFirst().takenAt, .logged)
        }

        return (scheduledBase, .scheduled)
    }

    private enum FocusTimingSource {
        case scheduled
        case logged
    }

    private struct FocusTimingEntry: Identifiable {
        let id = UUID()
        let baseTime: Date
        let source: FocusTimingSource
    }

    private struct FocusWindowDescription: Identifiable {
        let id = UUID()
        let summary: String
        let source: FocusTimingSource
    }

    private func collapseCard() {
        if store.expandedMedicationID == medication.id {
            store.expandedMedicationID = nil
        }
    }

    private var focusWindowDescriptions: [FocusWindowDescription] {
        guard let onset = medication.onsetMinutes,
              let duration = medication.durationMinutes else {
            return []
        }

        let entries = focusWindowTimingEntries
        guard !entries.isEmpty else { return [] }

        let calendar = Calendar.current
        return entries.enumerated().compactMap { index, entry in
            guard let onsetDate = calendar.date(byAdding: .minute, value: onset, to: entry.baseTime),
                  let fadeDate = calendar.date(byAdding: .minute, value: duration, to: entry.baseTime) else {
                return nil
            }
            let onsetString = commonFormatTime(onsetDate)
            let fadeString = commonFormatTime(fadeDate)
            let labelPrefix = entries.count > 1 ? "Dose \(index + 1) • " : ""
            let summary = "\(labelPrefix)Starts ~\(onsetString), starts fading ~\(fadeString)"
            return FocusWindowDescription(summary: summary, source: entry.source)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                let detailEntries = detailRowEntries
                if !detailEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(detailEntries, id: \.label) { entry in
                            VStack(alignment: .leading, spacing: entry.placeValueOnNewLine ? 4 : 2) {
                                Text("\(entry.label):")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(detailSecondaryTextColor.opacity(0.85))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(entry.value)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(entry.valueColor)
                                    .lineLimit(entry.lineLimit)
                                    .lineSpacing(3)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !focusWindowDescriptions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Focus Window:")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(detailSecondaryTextColor.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(focusWindowDescriptions) { entry in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.summary)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(detailPrimaryTextColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(entry.source == .logged ? "Based on logged time" : "Based on reminder time")
                                    .font(.system(size: 12))
                                    .foregroundColor(detailSecondaryTextColor.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let rawNotes = medication.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !rawNotes.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOTES")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(detailSecondaryTextColor)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            Text(rawNotes)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(detailPrimaryTextColor)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(detailBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(detailDividerColor.opacity(0.55), lineWidth: 1)
                            )
                    )
                }
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button {
                        onEditTap()
                        collapseCard()
                    } label: {
                        Text("Edit")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(actionButtonTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: "#444C44"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(detailDividerColor.opacity(0.65), lineWidth: 0.8)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            showingDeleteAction.toggle()
                        }
                    } label: {
                        Text("...")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(actionButtonTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: "#444C44"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(detailDividerColor.opacity(0.65), lineWidth: 0.8)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(onDeleteTap == nil && onMoreActionTap == nil && onMoreActionTapForLog == nil)
                    .opacity((onDeleteTap == nil && onMoreActionTap == nil && onMoreActionTapForLog == nil) ? 0.5 : 1)
                }

                if showingDeleteAction, let moreActionTitle {
                    if moreActionTitle == "Undo dose", onMoreActionTapForLog != nil, untakeableLogs.count > 0 {
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                showingUntakeOptions.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(moreActionTitle)
                                Spacer(minLength: 0)
                                Image(systemName: showingUntakeOptions ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(actionButtonTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: "#444C44"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(detailDividerColor.opacity(0.65), lineWidth: 0.8)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.move(edge: .top).combined(with: .opacity))

                        if showingUntakeOptions {
                            VStack(spacing: 8) {
                                ForEach(untakeableLogs, id: \.id) { log in
                                    Button {
                                        onMoreActionTapForLog?(log)
                                        collapseCard()
                                    } label: {
                                        HStack(spacing: 10) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(log.medicationName)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                Text(log.skipped ? "Skipped at \(commonFormatTime(log.takenAt))" : "Taken at \(commonFormatTime(log.takenAt))")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.white)
                                            }
                                            Spacer(minLength: 0)
                                                Text(log.reminderIndex != nil ? "Dose \(log.reminderIndex! + 1)" : "Dose")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(.white)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color(hex: "#3F463F"))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .stroke(detailDividerColor.opacity(0.5), lineWidth: 0.8)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    } else if let moreActionTap = onMoreActionTap {
                        Button {
                            moreActionTap()
                            collapseCard()
                        } label: {
                            Text(moreActionTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(actionButtonTextColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(hex: "#4A4A45"))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(detailDividerColor.opacity(0.65), lineWidth: 0.8)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                if showingDeleteAction, let deleteTap = onDeleteTap {
                    Button {
                        HapticManager.shared.warningNotification()
                        deleteTap()
                        collapseCard()
                    } label: {
                        Text("Delete medication")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.red.opacity(0.95))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: "#4A4A45"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.red.opacity(0.2), lineWidth: 0.8)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            detailBackgroundColor
        )
    }

    private var pillInventoryDetail: (text: String, color: Color)? {
        guard let pillCount = medication.pillCount else { return nil }
        var segments: [String] = ["\(pillCount) left"]
        let takenTodayValue = pillsTakenToday
        if takenTodayValue > 0 {
            segments.append("\(takenTodayValue) taken today")
        }
        let detailText = segments.joined(separator: " • ")
        if let threshold = medication.refillThreshold, pillCount <= threshold {
            return (detailText, Color(hex: "#FFC857"))
        }
        return (detailText, detailPrimaryTextColor)
    }

    private var detailRowEntries: [DetailEntry] {
        var entries: [DetailEntry] = []

        if let inventoryDetail = pillInventoryDetail {
            entries.append(
                DetailEntry(
                    label: "Pill Inventory",
                    value: inventoryDetail.text,
                    valueColor: inventoryDetail.color,
                    lineLimit: 2
                )
            )
        }

        if medication.enableDailyCheckIn {
            let checkInDescription: String
            if medication.medicationType == .stimulant {
                if let customTime = medication.dailyCheckInTime {
                    checkInDescription = "Custom: \(commonFormatTime(customTime))"
                } else {
                    checkInDescription = "around fade start"
                }
            } else if let customTime = medication.dailyCheckInTime {
                checkInDescription = "Reflection: \(commonFormatTime(customTime))"
            } else {
                checkInDescription = "Reflection reminder"
            }

            entries.append(
                DetailEntry(
                    label: "Reflection",
                    value: checkInDescription,
                    valueColor: detailPrimaryTextColor,
                    lineLimit: 1
                )
            )
        }

        return entries
    }

    private struct DetailEntry {
        let label: String
        let value: String
        let valueColor: Color
        let lineLimit: Int?
        let placeValueOnNewLine: Bool

        init(
            label: String,
            value: String,
            valueColor: Color = MedicationCardPalette.titleText,
            lineLimit: Int? = 1,
            placeValueOnNewLine: Bool = false
        ) {
            self.label = label
            self.value = value
            self.valueColor = valueColor
            self.lineLimit = lineLimit
            self.placeValueOnNewLine = placeValueOnNewLine
        }
    }
}

fileprivate struct MedicationLogTimePickerSheet: View {
    let medication: Medication
    let onConfirm: (Date) -> Void
    let onCancel: () -> Void
    @State private var selectedTime: Date

    init(
        medication: Medication,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (Date) -> Void
    ) {
        self.medication = medication
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _selectedTime = State(initialValue: MedicationLogTimePickerSheet.roundToMinute(Date()))
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("When did you take \(medication.name)?")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.pillrBackground)
                    .multilineTextAlignment(.center)

                Text("Drag to adjust the time you logged")
                    .font(.system(size: 13))
                    .foregroundColor(Color.pillrSecondary.opacity(0.9))
            }
            .padding(.horizontal, 12)

            DatePicker(
                "",
                selection: $selectedTime,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 180)
            .clipped()

            Text(selectedTime, style: .time)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.pillrBackground)

            HStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.lightImpact()
                    onCancel()
                }) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(Color.pillrBackground)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                }

                Button(action: {
                    HapticManager.shared.successNotification()
                    onConfirm(selectedTime)
                }) {
                    Text("Log time")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(Color.pillrPrimary)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.pillrBackground)
                        )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(Color.clear)
    }

    private static func roundToMinute(_ date: Date) -> Date {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        return Calendar.current.date(from: components) ?? date
    }
}

// Extension to convert ShapeStyle types to AnyShapeStyle
extension ShapeStyle {
    func anyShapeStyle() -> AnyShapeStyle {
        return AnyShapeStyle(self)
    }
}

extension DateFormatter {
    static let takenTodayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
