//
//  MedicationsListView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

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
    @State private var showCabinetIntroOverlay = false
    @State private var referenceDate = Date()
    private let referenceTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let healthRefreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var undoToastAction: MedicationStore.LogUndoAction?
    @State private var undoToastDismissWorkItem: DispatchWorkItem?
    private let undoToastDuration: TimeInterval = 5.0
    @State private var isViewActive = false

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

    init(addFlowCoordinator: AddMedicationFlowCoordinator = AddMedicationFlowCoordinator()) {
        self._addFlowCoordinator = ObservedObject(wrappedValue: addFlowCoordinator)
    }

    private var cabinetLogMedications: [Medication] {
        let calendar = Calendar.current
        return cabinetMedications.flatMap { medication in
            let todaysLogs = store.logs.filter { log in
                log.medicationID == medication.id &&
                !log.hiddenFromMyMeds &&
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                MedicationsListMainContent(
                    store: store,
                    showingAddSheet: $showingAddSheet,
                    scrolledOffset: $scrolledOffset,
                    selectedMedicationToEdit: $selectedMedicationToEdit,
                    medicationToDelete: $medicationToDelete,
                    logToDelete: $logToDelete,
                    showDeleteAlert: $showDeleteAlert,
                    showingInteractionSheet: $showingInteractionSheet,
                    isCheckingInteractions: $isCheckingInteractions,
                    onCheckAllInteractions: showMedicationSelectionSheet,
                    onAddMedication: handleAddMedication,
                    onShowFocusTimeline: { showingFocusTimeline = true },
                    onPresentUndoToast: presentUndoToast,
                    onRequestCustomLogTimeAction: requestCustomLogTime,
                    onPresentDailyCheckIn: presentDailyCheckIn,
                    displayedMedications: displayedMedications,
                    cabinetMedications: cabinetMedications,
                    onShowCabinet: handleCabinetTap,
                    healthKitManager: healthKitManager,
                    referenceDate: referenceDate
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

                NavigationLink(
                    destination: addMedicationDestination,
                    isActive: $showingAddSheet
                ) {
                    EmptyView()
                }
                .hidden()
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
                .presentationBackground(Color(hex: "#1E201A").opacity(0.35))
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
                    checkInLogID: context.logID,
                    onLogAction: presentUndoToast
                )
                .environmentObject(store)
            }
            .sheet(item: $store.recentADHDDoseTimeline, onDismiss: {
                store.recentADHDDoseTimeline = nil
            }) { entry in
                ADHDDoseTimelineSheet(entry: entry)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .onReceive(referenceTimer) { output in
                guard scenePhase == .active else { return }
                referenceDate = output
                store.refreshOverdueMedicationIDs(referenceDate: output)
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
                Task {
                    await healthKitManager.refreshAuthorizationState()
                    await healthKitManager.refreshMetrics()
                }
            }
            .onDisappear {
                isViewActive = false
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    refreshReferenceDate(resetBadge: true)
                    Task {
                        await healthKitManager.refreshAuthorizationState()
                        await healthKitManager.refreshMetrics()
                    }
                }
            }
            .task {
                await healthKitManager.refreshAuthorizationState()
            }
            .onChange(of: addFlowCoordinator.dismissTrigger) { _ in
                if showingAddSheet {
                    showingAddSheet = false
                }
            }
            .onChange(of: showingAddSheet) { isActive in
                addFlowCoordinator.isShowing = isActive
                addFlowCoordinator.hasUnsavedChanges = isActive ? true : false
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

    private func refreshReferenceDate(resetBadge: Bool) {
        referenceDate = Date()
        store.refreshOverdueMedicationIDs(referenceDate: referenceDate)
        if resetBadge {
            store.checkAndResetBadge()
        }
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
        if shouldAutoLogCabinetMedication(medication) {
            quickLogCabinetMedication(medication)
            return
        }
        
        showingCabinetSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showingLogSheetFor = medication
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

    private func logMedication(_ medication: Medication, at time: Date, reminderIndex: Int? = nil) {
        let resolvedMedication = store.findMedication(with: medication.id) ?? medication
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
        let resolvedMedication = store.findMedication(with: medication.id) ?? medication
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
                    .foregroundColor(Color(hex: "#F5F7F4"))
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button(action: {
                HapticManager.shared.lightImpact()
                onUndo()
            }) {
                Text("Undo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2F352F"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#E0E7DC"))
                    )
            }
            .buttonStyle(ScaleButtonStyle())

            Button(action: {
                HapticManager.shared.lightImpact()
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#E0E7DC").opacity(0.9))
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
                .fill(Color(hex: "#2F352F").opacity(0.94))
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

@ViewBuilder
fileprivate func EmptyMedicationsView(onAddMedication: @escaping () -> Void) -> some View {
    EmptyStateView(
        title: "Your medication list is empty",
        message: "Get started by adding your first medication below.",
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
            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
            .padding(.top, 10)
        Text("No active reminders")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(Color(hex: "#F5F7F4"))
        Text(hiddenCount > 0 ? "You have \(hiddenCount) medication\(hiddenCount == 1 ? "" : "s") stored in your cabinet." : "Add reminder times to see medications here.")
            .font(.system(size: 15))
            .multilineTextAlignment(.center)
            .foregroundColor(Color(hex: "#E0E7DC").opacity(0.85))
            .padding(.horizontal)
        Button(action: onOpenCabinet) {
            Text("Open Cabinet")
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#E0E7DC"))
                )
                .foregroundColor(Color(hex: "#2F352F"))
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.bottom, 10)
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(hex: "#5B695D"))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    )
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
    let logsByMedication = Dictionary(grouping: logs, by: { $0.medicationID })
    let logsByID = Dictionary(uniqueKeysWithValues: logs.map { ($0.id, $0) })

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
	    onPresentDailyCheckIn: @escaping (Medication) -> Void,
	    medications: [Medication],
	    referenceDate: Date
	) -> some View {
	    VStack(alignment: .leading, spacing: 16) {
	        ForEach(sortedMedications(medications, logs: store.logs, referenceDate: referenceDate)) { med in
            MedicationRow(
                medication: med,
                referenceDate: referenceDate,
                onPresentUndoToast: onPresentUndoToast,
                onRequestCustomLogTime: { resolvedMedication, resolvedIndex in
                    HapticManager.shared.lightImpact()
                    onRequestCustomLogTimeAction(resolvedMedication, resolvedIndex)
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
                    .foregroundColor(Color(hex: "#F5F7F4"))
                
                Text("\(store.activeMedications.count) medication\(store.activeMedications.count == 1 ? "" : "s")")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#E0E7DC").opacity(0.9))
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Button(action: onShowCabinet) {
                    Image(systemName: "cabinet.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#F5F7F4"))
                        .frame(width: 24, height: 24)
                        .overlay(alignment: .topTrailing) {
                            if cabinetCount > 0 {
                                Text("\(cabinetCount)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "#2F352F"))
                                    .padding(4)
                                    .background(Color(hex: "#F5F7F4"))
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
                        .foregroundColor(Color(hex: "#F5F7F4"))
                        .frame(width: 24, height: 24)
                }
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
    @ObservedObject var manager: HealthKitManager
    private static var defaultDistanceUnit: HealthDistanceUnit {
        Locale.current.usesMetricSystem ? .kilometers : .miles
    }
    @AppStorage("healthSnapshotDistanceUnit") private var distanceUnitRawValue = defaultDistanceUnit.rawValue

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
            Metric(title: "Steps", unit: "steps", value: formattedSteps(manager.dailySteps)),
            Metric(title: "Distance", unit: distanceUnit.rawValue, value: formattedDistance(manager.dailyDistanceMiles))
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if shouldShowHeader {
                header
            }

            if !manager.isHealthDataAvailable {
                Text("Apple Health is not available on this device.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
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
                    .foregroundColor(Color(hex: "#FFB74D"))
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#404C42"))
        )
        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var shouldShowHeader: Bool {
        !(manager.hasConnected || manager.hasAnyPermission || manager.hasMetricValues)
    }

    private var shouldShowHeartRatePrompt: Bool {
        manager.isHealthDataAvailable && manager.hasAnyPermission && !manager.hasHeartRatePermission
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Health Snapshot")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
            }
            
            Spacer()
        }
    }

    private var metricGrid: some View {
        HStack(spacing: 12) {
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
                    ? "Health permissions are currently denied. Open Settings to re-allow fitness data."
                    : "Allow access to Apple Health to show your daily steps, distance, and heart rate."
            )
            .font(.system(size: 13))
            .foregroundColor(Color(hex: "#E0E7DC").opacity(0.9))
            .lineLimit(3)

            Button {
                Task {
                    await manager.requestAuthorizationIfNeeded()
                    await manager.refreshMetrics()
                }
            } label: {
                Text("Connect to Health")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2F352F"))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#F5F7F4"))
                    )
            }
            .buttonStyle(ScaleButtonStyle())
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
            .foregroundColor(Color(hex: "#E0E7DC").opacity(0.9))
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#2F352F"))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#F5F7F4"))
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func metricSquare(metric: Metric) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))

            Text(metric.value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "#F5F7F4"))

            Text(metric.unit)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
        }
        .frame(height: 70)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var verticalDivider: some View {
        Rectangle()
            .frame(width: 1)
            .foregroundColor(Color.white.opacity(0.12))
            .padding(.vertical, 4)
    }

    private func formattedSteps(_ value: Int?) -> String {
        guard let value = value else {
            return "--"
        }
        return Self.integerFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
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
                                .init(color: Color(hex: "#F0F0E8"), location: 0.0),
                                .init(color: Color(hex: "#E8E8E0"), location: 0.25),
                                .init(color: Color(hex: "#DFDFD9"), location: 0.5),
                                .init(color: Color(hex: "#C7C7BD"), location: 0.75),
                                .init(color: Color(hex: "#B8B8AE"), location: 1.0)
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
                            .foregroundColor(Color(hex: "#3A443D"))
                    } else {
                        // Custom rectangular plus
                        ZStack {
                            // Horizontal bar (more rectangular)
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color(hex: "#3A443D"))
                                .frame(width: 24, height: 4)
                            
                            // Vertical bar (more rectangular)
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(Color(hex: "#3A443D"))
                                .frame(width: 4, height: 24)
                        }
                    }
                }
                .rotationEffect(.degrees(isExpanded ? 540 : 0))
                .scaleEffect(isExpanded ? 0.85 : 1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: isExpanded)
            }
            .shadow(color: Color.black.opacity(isExpanded ? 0.35 : 0.25), radius: isExpanded ? 15 : 12, x: 0, y: isExpanded ? 10 : 8)
            .shadow(color: Color(hex: "#2F352F").opacity(0.2), radius: 4, x: 0, y: 3)
            .shadow(color: Color.white.opacity(0.5), radius: 1, x: 0, y: -1)
            .scaleEffect(isExpanded ? 1.08 : 1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isExpanded)
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
                    .foregroundColor(Color(hex: "#3A443D"))
                    .frame(width: 20)
                
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#3A443D"))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#E8E8E0"),
                        Color(hex: "#DFDFD9"),
                        Color(hex: "#C7C7BD"),
                        Color(hex: "#B8B8AE")
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
                .combined(with: .scale(scale: 0.1))
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(delay)),
            removal: .opacity
                .combined(with: .move(edge: .bottom))
                .combined(with: .scale(scale: 0.3))
                .animation(.spring(response: 0.4, dampingFraction: 0.9))
        ))
        .modifier(ShakeAnimationModifier(isExpanded: isExpanded, delay: delay))
    }
}

// Enhanced button style with better feedback
struct EnhancedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { newValue in
                if newValue {
                    HapticManager.shared.pulseButton()
                }
            }
    }
}

// Shake animation modifier for floating action buttons
struct ShakeAnimationModifier: ViewModifier {
    let isExpanded: Bool
    let delay: Double
    @State private var shakeOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: isExpanded) { _, newValue in
                if newValue {
                    // Start shake animation after the spring delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.3) {
                        // First intense shake
                        withAnimation(.easeInOut(duration: 0.06).repeatCount(7, autoreverses: true)) {
                            shakeOffset = 15
                        }
                        
                        // Reset shake offset after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            shakeOffset = 0
                        }
                    }
                } else {
                    shakeOffset = 0
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
    
    private var inactiveReminderMedications: [Medication] {
        medications.filter { $0.frequency != "As needed" }
    }

    var body: some View {
        NavigationView {
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
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Medication Cabinet")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "#F5F7F4"))
                            .padding(.top, 12)
                        if medications.isEmpty {
                            VStack(spacing: 10) {
                                Text("Your Cabinet Is Empty")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color(hex: "#F5F7F4"))
                                VStack(spacing: 6) {

                                    Text("Anything you set as \"as needed\" stays here tucked away and ready when you need them.")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "#E0E7DC"))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color(hex: "#5B695D"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                        } else {
                            if !asNeededMedications.isEmpty {
                                cabinetSection(title: "As needed", medications: asNeededMedications)
                            }
                            
                            if !inactiveReminderMedications.isEmpty {
                                cabinetSection(title: "No daily reminders", medications: inactiveReminderMedications)
                            }
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
                        .foregroundColor(Color(hex: "#C7C7BD"))
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#E0E7DC"))

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
                        .foregroundColor(Color(hex: "#2F352F"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "#F5F7F4"))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(hex: "#1B1D19").opacity(0.95))
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

    private var detailSubtitle: String {
        if medication.frequency == "As needed" {
            return "Take when you need it"
        }
        return "No reminder scheduled"
    }

    private var longPressHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
            Text("Long press to edit or delete")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#E0E7DC").opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.12))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(medication.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#F5F7F4"))
                    .lineLimit(1)
                Text("\(medication.dosage) \(medication.dosageUnit) • \(medication.frequency)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#E0E7DC").opacity(0.9))
                    .lineLimit(1)
                Text(detailSubtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#C7C7BD"))
            }

            HStack(spacing: 12) {
                Button(action: onLogTap) {
                    HStack(spacing: 6) {
                        Text("Log dose")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(logButtonDefaultForeground)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(logButtonDefaultBackground)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if showDetails {
                longPressHint
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "#4C584F"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showDetails.toggle()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showDetails.toggle()
                }
            }) {
                Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#E0E7DC").opacity(0.65))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
        .contextMenu {
            Button {
                onEditTap()
            } label: {
                Text("Edit Medication")
            }
            if let deleteTap = onDeleteTap {
                Button(role: .destructive) {
                    deleteTap()
                } label: {
                    Text("Delete Medication")
                }
            }
        }
    }

    private var logButtonDefaultForeground: Color {
        Color(hex: "#2F352F")
    }

    private var logButtonDefaultBackground: Color {
        Color(hex: "#E0E7DC")
    }
}

fileprivate struct MedicationsListMainContent: View {
    @ObservedObject var store: MedicationStore
    @Binding var showingAddSheet: Bool
    @Binding var scrolledOffset: CGFloat
    @Binding var selectedMedicationToEdit: Medication?
    @Binding var medicationToDelete: Medication?
    @Binding var logToDelete: MedicationLog?
    @Binding var showDeleteAlert: Bool
    @Binding var showingInteractionSheet: Bool
    @Binding var isCheckingInteractions: Bool
    let onCheckAllInteractions: () async -> Void
    let onAddMedication: () -> Void
    let onShowFocusTimeline: () -> Void
    let onPresentUndoToast: (MedicationStore.LogUndoAction) -> Void
    let onRequestCustomLogTimeAction: (Medication, Int?) -> Void
    let onPresentDailyCheckIn: (Medication) -> Void
    let displayedMedications: [Medication]
    let cabinetMedications: [Medication]
    let onShowCabinet: () -> Void
    let healthKitManager: HealthKitManager
    let referenceDate: Date
    @EnvironmentObject private var userSettings: UserSettings

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private func horizontalInsets(for width: CGFloat) -> CGFloat {
        if horizontalSizeClass == .regular && width > 768 {
            return max((width - 650) / 2, 16)
        }
        return 16
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#404C42")
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

                        if userSettings.shouldShowAppleHealthData {
                            HealthSummaryWidget(manager: healthKitManager)
                                .environmentObject(userSettings)
                                .padding(.horizontal, horizontalInset)
                        }

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
                                onPresentDailyCheckIn: onPresentDailyCheckIn,
                                medications: displayedMedications,
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
                .onChange(of: store.highlightedMedicationID) { target in
                    guard let target else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                    if store.notificationHighlightMedicationID != target {
                        store.expandedMedicationID = target
                    }
                    DispatchQueue.main.async {
                        store.highlightedMedicationID = nil
                    }
                }
                .onChange(of: store.expandedMedicationID) { expandedID in
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
            return "Skipped"
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
            return Color(hex: "#F5F7F4")
        case .taken:
            return Color(hex: "#4A5A4A")
        case .skipped:
            return Color(hex: "#FFE4E6")
        }
    }
    
    var backgroundColor: Color {
        switch status {
        case .pending:
            return Color.white.opacity(0.08)
        case .taken:
            return Color(hex: "#D7CCC8")
        case .skipped:
            return Color(hex: "#8C3A37")
        }
    }
    
    var formattedTime: String? {
        guard let scheduledTime else { return nil }
        return DoseButtonState.timeFormatter.string(from: scheduledTime)
    }

    var loggedTimeLabel: String? {
        guard let actualTime else { return nil }
        let statusLabel = status == .skipped ? "Skipped" : "Taken"
        return "\(statusLabel) at \(DoseButtonState.loggedTimeFormatter.string(from: actualTime))"
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
    
    private let timelineTimeWidth: CGFloat = 58
    private let logButtonMinWidth: CGFloat = 96

	    private var usesTimelineLayout: Bool {
	        !doseStates.isEmpty && !compactLayout
	    }

	    private var pendingDoseIndex: Int? {
	        doseStates.first(where: { $0.status == .pending })?.index
	    }

    private var horizontalPadding: CGFloat {
        compactLayout ? 16 : 20
    }

    private var verticalPadding: CGFloat {
        if compactLayout {
            return 12
        }
        if allDosesLogged {
            return usesTimelineLayout ? 16 : 14
        }
        return usesTimelineLayout ? 24 : 18
    }

    private var stackSpacing: CGFloat {
        if usesTimelineLayout {
            return 16
        }
        return compactLayout ? 8 : 0
    }

    private var headerIsLoggedStatus: Bool {
        switch cycleStatus {
        case .taken, .skipped:
            return true
        default:
            return false
        }
    }

    private var headerTitleOpacity: Double {
        if cycleStatus == .taken || cycleStatus == .skipped {
            return 0.55
        }
        return headerIsLoggedStatus ? 0.9 : 1.0
    }

    private var detailTextOpacity: Double {
        cycleStatus == .taken ? 0.45 : 1.0
    }

    private var allDosesLogged: Bool {
        guard !doseStates.isEmpty else { return false }
        return doseStates.allSatisfy { $0.status != .pending }
    }

    private var doseRowVerticalPadding: CGFloat {
        allDosesLogged ? 8 : 12
    }
    
    // Moved statusDisplay computed property
    private var statusDisplay: (text: String, color: Color, show: Bool) {
        if medication.frequency == "As needed" {
            return ("", .clear, false) // No status text for "As needed" meds
        }
        if overdueBadgeActive, let minutesPast = overdueMinutes {
            return ("Overdue by \(formatTimeText(minutes: minutesPast))", Color(hex: "#FFA726"), true)
        }
        switch cycleStatus {
        case .taken:
            return ("", .clear, false) // No status text when taken, button shows "Taken"
        case .skipped:
            return ("", .clear, false) // No status text when skipped, button shows "Skipped"
        case .overdue(let minutesPast):
            return ("Overdue by \(formatTimeText(minutes: minutesPast))", Color(hex: "#FFA726"), true)
        case .due(let minutesRemaining):
            if minutesRemaining > 0 {
                return ("Due in \(formatTimeText(minutes: minutesRemaining))", Color(hex: "#D7CCC8"), true)
            }
            return ("Due now", Color(hex: "#D7CCC8"), true)
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

    private var notesPreview: String? {
        guard let notes = medication.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
              !notes.isEmpty else {
            return nil
        }
        return notes
    }

    private struct DoseBadgeItem: Identifiable {
        let id: Int
        let text: String
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
                    let label = prefix != nil ? "\(prefix!) • \(timeText)" : timeText
                    badges.append(DoseBadgeItem(id: state.index, text: label))
                }

            case .skipped:
                let prefix: String? = showDoseLabel
                    ? ((state.customTitle?.isEmpty == false) ? state.customTitle : "Dose \(state.index + 1)")
                    : nil
                let label = prefix != nil ? "\(prefix!) • Skipped" : "Skipped"
                badges.append(DoseBadgeItem(id: state.index, text: label))

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
            VStack(alignment: .leading, spacing: 2) {
                ForEach(badges) { badge in
                    Text(badge.text)
                        .font(.system(.body, weight: .semibold))
                        .foregroundColor(Color(hex: "#F5F7F4"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
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
            fg: Color(hex: "#2F352F"),
            bg: Color(hex: "#E0E7DC"),
            border: Color.white.opacity(0.18)
        )
    }

    private var baseSkipButtonColors: (fg: Color, bg: Color, border: Color) {
        baseTakeButtonColors
    }

    private var takeButtonStyle: (fg: Color, bg: Color, border: Color) {
        if canPerformPrimaryAction {
            return baseTakeButtonColors
        } else {
            return (
                fg: Color(hex: "#C7C7BD").opacity(0.6),
                bg: Color.white.opacity(0.08),
                border: Color.white.opacity(0.05)
            )
        }
    }

    private var skipButtonStyle: (fg: Color, bg: Color, border: Color) {
        if skipActionAvailable {
            return baseSkipButtonColors
        } else {
            return (
                fg: Color(hex: "#C7C7BD").opacity(0.6),
                bg: Color.white.opacity(0.08),
                border: Color.white.opacity(0.05)
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: stackSpacing) {
            HStack(alignment: .center, spacing: 16) {
                medicationInfoSection
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    if !usesTimelineLayout && !compactLayout {
                        takeSkipButtonRow
                    }
                }
            }
            if usesTimelineLayout {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
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
                .font(.system(size: 21, weight: .semibold))
                .foregroundColor(Color(hex: "#F5F7F4").opacity(headerTitleOpacity))
                .lineLimit(2)
                .minimumScaleFactor(0.9)
            
            if hasSubtitle {
                subtitleView
            }

            if statusDisplay.show {
                statusBadge
            }

            if compactLayout {
                doseBadgesView
                    .padding(.top, 2)
                    .padding(.bottom, 6)
            }
            
            if showDetails, let preview = notesPreview {
                Text(preview)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#E0E7DC").opacity(0.9 * detailTextOpacity))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 2)
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
        medication.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSubtitle: Bool {
        !dosageAmountLine.isEmpty || !scheduleLine.isEmpty
    }

    private var subtitleView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if !dosageAmountLine.isEmpty {
                Text(dosageAmountLine)
            }
            if !dosageAmountLine.isEmpty && !scheduleLine.isEmpty {
                Text("•")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(hex: "#E0E7DC").opacity(subtitleOpacity))
            }
            if !scheduleLine.isEmpty {
                Text(scheduleLine)
            }
        }
        .font(.system(size: 15, weight: .regular))
        .foregroundColor(Color(hex: "#E0E7DC").opacity(subtitleOpacity))
    }

    private var subtitleOpacity: Double {
        0.95
    }
    

    @ViewBuilder
    private var statusBadge: some View {
        let display = statusDisplay
        if display.show {
            Text(display.text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(display.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(display.color.opacity(0.2))
                .clipShape(Capsule())
                .padding(.top, 3)
        }
    }
    
    private var takeSkipButtonRow: some View {
        HStack(spacing: 12) {
            takeButton
            skipButton
        }
        .frame(maxWidth: 240)
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
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(style.bg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
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
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(style.bg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(style.border, lineWidth: 1)
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
                        .fill(Color(hex: "#D0D5D8").opacity(0.08))
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
        let capsuleCornerRadius: CGFloat = 12
        let capsuleVerticalPadding: CGFloat = 12
        let interButtonSpacing: CGFloat = 10
        let textFont: Font = .system(size: 14)
        let takeStyle = baseTakeButtonColors
        let skipStyle = baseSkipButtonColors

        return HStack(spacing: 12) {
            if state.status == .taken, let loggedText = state.loggedTimeLabel {
                HStack(spacing: 0) {
                    Text(loggedText)
                        .font(.system(.body, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .frame(minWidth: logButtonMinWidth, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.005))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.6)
                )
            } else if state.status == .skipped {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#FFE4E6").opacity(0.95))
                    Text(state.loggedTimeLabel ?? "Skipped")
                        .font(.system(.body, weight: .semibold))
                        .foregroundColor(Color(hex: "#FFE4E6"))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .frame(minWidth: logButtonMinWidth, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#7A3330").opacity(0.25))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.6)
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
                                    .stroke(skipStyle.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            if shouldShowDoseLabel(for: state) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(displayText)
                        .font(.system(.body, design: .default).weight(.semibold))
                        .foregroundColor(Color(hex: "#F5F7F4").opacity(state.status == .pending ? 1 : 0.7))
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
            return Color(hex: "#4D5A4F")
        case .taken:
            return Color(hex: "#C8CCBE")
        case .skipped:
            return Color(hex: "#7A3330")
        }
    }
    
    private func nodeIconColor(for state: DoseButtonState) -> Color {
        switch state.status {
        case .pending:
            return Color(hex: "#F5F7F4")
        case .taken:
            return Color(hex: "#616D5F")
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

struct MedicationRow: View {
    let medication: Medication
    let referenceDate: Date
    let onPresentUndoToast: (MedicationStore.LogUndoAction) -> Void
    let onRequestCustomLogTime: (Medication, Int?) -> Void
    let onDailyCheckInTap: () -> Void
    let onEditTap: () -> Void
    let onDeleteTap: (() -> Void)?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var store: MedicationStore
    @State private var isNotificationGlowActive = false
    @State private var notificationGlowResetWorkItem: DispatchWorkItem?
    private let notificationGlowDuration: TimeInterval = 2.0
    
    private var todaysLogsForMedication: [MedicationLog] {
        let calendar = Calendar.current
        if let logEntryID = medication.logEntryID {
            return store.logs.filter { log in
                log.id == logEntryID &&
                calendar.isDate(log.takenAt, inSameDayAs: referenceDate)
            }
        }
        return store.logs.filter { log in
            log.medicationID == medication.logIdentifier &&
            calendar.isDate(log.takenAt, inSameDayAs: referenceDate)
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

    private var isDailyCheckInOverdue: Bool {
        store.isDailyCheckInOverdue(for: medication, referenceDate: referenceDate)
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

    private var takenCardColor: Color {
        Color(hex: "#A0A69B")
    }

    private var cardBackgroundColor: Color {
        let baseColor = Color(hex: "#5B695D")
        if usesLoggedCardStyle {
            return takenCardColor.opacity(0.65)
        }
        return isLoggedStatus ? baseColor.opacity(1.0) : baseColor.opacity(0.92)
    }

    private var innerStrokeColor: Color {
        switch cycleStatus {
        case .taken:
            return Color.white.opacity(0.01)
        case .skipped:
            return Color.white.opacity(0.08)
        default:
            return .clear
        }
    }

    private var innerStrokeWidth: CGFloat {
        switch cycleStatus {
        case .taken:
            return 0.3
        case .skipped:
            return 1
        default:
            return 0
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
        Color(hex: "#FF6B6B")
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
                compactLayout: usesLoggedCardStyle
            )
            
            if showsDetails {
                MedicationRowDetailsView(
                    medication: medication,
                    referenceDate: referenceDate,
                    onEditTap: onEditTap
                )
                .padding(.top, 12)
            }
        }
        .background(
            cardBackgroundColor
        )
        .cornerRadius(14)
        .overlay(loggedCheckmarkOverlay, alignment: .topTrailing)
        .overlay(notificationGlowOverlay)
        .overlay(alignment: .bottomTrailing) {
            if medication.enableDailyCheckIn && hasTakenDoseToday {
                Button(action: {
                    onDailyCheckInTap()
                }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#F5F7F4").opacity(0.85))
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "#F5F7F4").opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                                    )
                            )

                        if isDailyCheckInOverdue {
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
                .padding(.trailing, 10)
                .padding(.bottom, 10)
                .accessibilityLabel("Log Reflect")
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: {
                toggleExpansion()
            }) {
                Image(systemName: showsDetails ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#E0E7DC").opacity(0.55))
                    .padding(.top, 12)
                    .padding(.trailing, 12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(innerStrokeColor, lineWidth: innerStrokeWidth)
        )
        .overlay(enhancedBorderOverlay)
        .shadow(color: Color.black.opacity(cardPrimaryShadowOpacity), radius: cardPrimaryShadowRadius, x: 0, y: cardPrimaryShadowYOffset)
        .shadow(color: Color.black.opacity(cardSecondaryShadowOpacity), radius: cardSecondaryShadowRadius, x: 0, y: cardSecondaryShadowYOffset)
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
        .contextMenu {
            Button {
                HapticManager.shared.lightImpact()
                onEditTap()
            } label: {
                Text("Edit Medication")
            }

            if let deleteTap = onDeleteTap {
                Button(role: .destructive) {
                    HapticManager.shared.warningNotification()
                    deleteTap()
                } label: {
                    Text("Delete Medication")
                }
            }
        }
        .onAppear {
            handleNotificationHighlightChange(store.notificationHighlightMedicationID)
        }
        .onChange(of: store.notificationHighlightMedicationID) { newValue in
            handleNotificationHighlightChange(newValue)
        }
        .onDisappear {
            notificationGlowResetWorkItem?.cancel()
            isNotificationGlowActive = false
        }
    }
    
    private var notificationGlowOverlay: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color(hex: "#F6FFE0").opacity(isNotificationGlowActive ? 0.95 : 0), lineWidth: isNotificationGlowActive ? 2.5 : 0)
            .shadow(color: Color(hex: "#DFFFC0").opacity(isNotificationGlowActive ? 0.9 : 0), radius: isNotificationGlowActive ? 18 : 0)
            .blur(radius: isNotificationGlowActive ? 0.5 : 0)
            .padding(-6)
            .blendMode(.screen)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.35), value: isNotificationGlowActive)
    }

    @ViewBuilder
    private var loggedCheckmarkOverlay: some View {
        if usesLoggedCardStyle {
            GeometryReader { geometry in
                HStack {
                    Spacer()
                    Image(systemName: cycleStatus == .skipped ? "xmark" : "checkmark")
                        .font(.system(size: geometry.size.height * 0.9, weight: .heavy, design: .rounded))
                        .foregroundColor(cycleStatus == .skipped ? skippedAccentColor : Color.white)
                        .opacity(cycleStatus == .skipped ? 0.09 : 0.045)
                        .rotationEffect(.degrees(cycleStatus == .skipped ? 0 : -10))
                        .frame(height: geometry.size.height * 0.9)
                        .padding(.trailing, 18)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .allowsHitTesting(false)
        }
    }
    
    // Enhanced border overlay with better visual feedback
    private var enhancedBorderOverlay: some View {
        let (borderColor, borderWidth): (Color, CGFloat)
        
        var showSkippedGlow = false

        switch cycleStatus {
        case .taken:
            borderColor = Color(hex: "#D7CCC8").opacity(0.35)
            borderWidth = 0.6
        case .skipped:
            borderColor = skippedAccentColor
            borderWidth = 1.4
            showSkippedGlow = true
        case .overdue(_):
            borderColor = Color(hex: "#FFB74D")
            borderWidth = 2.0
        case .due(_):
            // No colored border for due medications
            borderColor = Color.clear
            borderWidth = 0.0
        case .asNeeded:
            borderColor = Color.clear
            borderWidth = 0.0
        }
        
        return ZStack {
            if showSkippedGlow {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(skippedAccentColor.opacity(0.3), lineWidth: borderWidth * 3.2)
                    .blur(radius: 6)
                    .padding(-6)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            borderColor.opacity(0.65),
                            borderColor.opacity(0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: borderWidth
                )
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
            return "Tap 'Take Now' to log, or tap status/chevron to expand details."
        case .asNeeded: // Add .asNeeded case
            return "Tap 'Take Now' to log, or tap status/chevron to expand details."
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
	            medication: medication,
	            actualTime: now,
	            notes: nil,
	            skipped: !taken,
	            reminderIndex: reminderIndex
	        ) {
	            onPresentUndoToast(action)
	        }
	    }

	    private func skipDose(at index: Int) {
	        if medication.reminderTimes.isEmpty {
	            guard todaysLogsForMedication.first(where: { $0.reminderIndex == nil }) == nil else { return }
	            if let action = store.skipMedication(
	                medication: medication,
	                actualTime: Date(),
	                notes: nil,
	                reminderIndex: nil
	            ) {
	                onPresentUndoToast(action)
	            }
	            return
	        }

        guard medication.reminderTimes.indices.contains(index) else { return }
        guard !todaysLogsForMedication.contains(where: { $0.reminderIndex == index }) else { return }

	        if let action = store.skipMedication(
	            medication: medication,
	            actualTime: Date(),
	            notes: nil,
	            reminderIndex: index
	        ) {
	            onPresentUndoToast(action)
	        }
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
    let onEditTap: () -> Void
    @EnvironmentObject var store: MedicationStore

    private var notificationsEnabled: Bool {
        return !(medication.notificationID == nil && medication.notificationIDs.isEmpty)
    }

    private var todaysLogsForMedication: [MedicationLog] {
        let calendar = Calendar.current
        return store.logs
            .filter { log in
                log.medicationID == medication.logIdentifier &&
                !log.hiddenFromMyMeds &&
                !log.skipped &&
                calendar.isDate(log.takenAt, inSameDayAs: referenceDate)
            }
            .sorted(by: { $0.takenAt < $1.takenAt })
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
        VStack(alignment: .leading, spacing: 12) {
            // Enhanced detail cards with better visual hierarchy
            VStack(alignment: .leading, spacing: 12) {
                let detailEntries = detailRowEntries
                if !detailEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(detailEntries, id: \.label) { entry in
                            VStack(alignment: .leading, spacing: entry.placeValueOnNewLine ? 6 : 4) {
                                Text("\(entry.label):")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
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
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !focusWindowDescriptions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Focus Window:")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(focusWindowDescriptions) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.summary)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#F5F7F4"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(entry.source == .logged ? "Based on logged time" : "Based on reminder time")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.65))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                
                if let rawNotes = medication.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !rawNotes.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOTES")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            Text(rawNotes)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#E8E8E0"))
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#606A63").opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }

            // Hint for editing or archiving via context menu with tap icon
            VStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("Long press to edit or delete")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.08)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
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
        return (detailText, Color(hex: "#F5F7F4"))
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
                checkInDescription = "Reflect: \(commonFormatTime(customTime))"
            } else {
                checkInDescription = "Reflect reminder"
            }

            entries.append(
                DetailEntry(
                    label: "Reflect",
                    value: checkInDescription,
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
            valueColor: Color = Color(hex: "#F5F7F4"),
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
            Capsule()
                .fill(Color.white.opacity(0.5))
                .frame(width: 42, height: 4)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("When did you take \(medication.name)?")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#F5F7F4"))
                    .multilineTextAlignment(.center)

                Text("Drag to adjust the time you logged")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
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
                .foregroundColor(Color(hex: "#F5F7F4"))

            HStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.lightImpact()
                    onCancel()
                }) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(Color(hex: "#F5F7F4"))
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
                        .foregroundColor(Color(hex: "#2F352F"))
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: "#F5F7F4"))
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
