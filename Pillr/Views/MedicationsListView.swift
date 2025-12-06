//
//  MedicationsListView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

struct MedicationsListView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingLogSheetFor: Medication?
    @State private var selectedMedicationToEdit: Medication?
    @State private var showingAddSheet = false
    @State private var scrolledOffset: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingArchivedSheet = false
    @State private var medicationToArchive: Medication? = nil
    @State private var showArchiveAlert = false
    @State private var showingInteractionSheet = false
    @State private var showingMedicationSelectionSheet = false
    @State private var interactionCheckError: String? = nil
    @State private var foundInteractions: [DrugInteraction]? = nil
    @State private var isCheckingInteractions = false
    @State private var showingInteractionResultSheet = false
    @State private var showingPremiumUpgrade = false
    @State private var showingFocusTimeline = false
    @State private var showingCabinetSheet = false
    @State private var referenceDate = Date()
    private let referenceTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    let onShowSettings: () -> Void
    let onShowHistory: () -> Void

    init(
        onShowSettings: @escaping () -> Void = {},
        onShowHistory: @escaping () -> Void = {}
    ) {
        self.onShowSettings = onShowSettings
        self.onShowHistory = onShowHistory
    }

    private var reminderMedications: [Medication] {
        store.activeMedications.filter { !$0.isCabinetMedication }
    }
    
    private var cabinetMedications: [Medication] {
        store.activeMedications.filter { $0.isCabinetMedication }
    }

    private var cabinetLogMedications: [Medication] {
        let calendar = Calendar.current
        return cabinetMedications.flatMap { medication in
            let todaysLogs = store.logs.filter { log in
                log.medicationID == medication.id &&
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
        MedicationsListMainContent(
            store: store,
            showingAddSheet: $showingAddSheet,
            scrolledOffset: $scrolledOffset,
            showingLogSheetFor: $showingLogSheetFor,
            selectedMedicationToEdit: $selectedMedicationToEdit,
            medicationToArchive: $medicationToArchive,
            showArchiveAlert: $showArchiveAlert,
            showingArchivedSheet: $showingArchivedSheet,
            showingInteractionSheet: $showingInteractionSheet,
            isCheckingInteractions: $isCheckingInteractions,
            onCheckAllInteractions: showMedicationSelectionSheet,
            onAddMedication: handleAddMedication,
            onShowHistory: onShowHistory,
            onShowSettings: onShowSettings,
            onShowFocusTimeline: { showingFocusTimeline = true },
            displayedMedications: displayedMedications,
            cabinetMedications: cabinetMedications,
            onShowCabinet: { showingCabinetSheet = true },
            referenceDate: referenceDate
        )
        .sheet(item: $showingLogSheetFor) { med in
            LogMedicationView(medicationToLog: med)
                .environmentObject(store)
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
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                AddMedicationView(onFinish: { showingAddSheet = false })
                    .environmentObject(store)
                    .environmentObject(userSettings)
            }
        }
        .sheet(isPresented: $showingArchivedSheet) {
            ArchivedMedicationsSheet(
                store: store,
                showingArchivedSheet: $showingArchivedSheet
            )
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
        .alert(isPresented: $showArchiveAlert) {
            Alert(
                title: Text("Delete Medication"),
                message: Text("Deleting \(medicationToArchive?.name ?? "this medication") will permanently remove it and it cannot be restored unless you enter it again."),
                primaryButton: .destructive(Text("Delete")) {
                    if let med = medicationToArchive {
                        store.archiveMedication(med)
                    }
                    medicationToArchive = nil
                },
                secondaryButton: .cancel {
                    medicationToArchive = nil
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
        .sheet(isPresented: $showingCabinetSheet) {
            MedicationCabinetSheet(
                medications: cabinetMedications,
                logs: store.logs,
                referenceDate: referenceDate,
                onLogMedication: { presentLogSheet(for: $0) },
                onEditMedication: { presentEditSheet(for: $0) }
            )
        }
        .sheet(item: $store.dailyCheckInMedication, onDismiss: {
            store.dailyCheckInMedication = nil
        }) { med in
            LogMedicationView(medicationToLog: med, isDailyCheckIn: true)
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
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshReferenceDate(resetBadge: false)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                refreshReferenceDate(resetBadge: true)
            }
        }
    }
    
    private func showMedicationSelectionSheet() async {
        showingMedicationSelectionSheet = true
    }

    private func refreshReferenceDate(resetBadge: Bool) {
        referenceDate = Date()
        if resetBadge {
            store.checkAndResetBadge()
        }
    }
    
    private func handleAddMedication() {
        let currentActiveMedications = store.activeMedications.count
        if userSettings.canAddMedication(currentCount: currentActiveMedications) {
            showingAddSheet = true
        } else {
            showingPremiumUpgrade = true
        }
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
        showingCabinetSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showingLogSheetFor = medication
        }
    }
    
    private func presentEditSheet(for medication: Medication) {
        showingCabinetSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            selectedMedicationToEdit = medication
        }
    }
}

// MARK: - Subviews

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
        let isOverdue = !wasTakenToday &&
            dueTime < now &&
            calendar.isDate(dueTime, inSameDayAs: now)
        let overdueDuration = isOverdue ? now.timeIntervalSince(dueTime) : 0
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
    showingLogSheetFor: Binding<Medication?>,
    selectedMedicationToEdit: Binding<Medication?>,
    medicationToArchive: Binding<Medication?>,
    showArchiveAlert: Binding<Bool>,
    showingArchivedSheet: Binding<Bool>,
    showingInteractionSheet: Binding<Bool>,
    isCheckingInteractions: Binding<Bool>,
    onCheckAllInteractions: @escaping () async -> Void,
    onAddMedication: @escaping () -> Void,
    onShowFocusTimeline: @escaping () -> Void,
    medications: [Medication],
    referenceDate: Date
) -> some View {
    VStack(alignment: .leading, spacing: 16) {
        ForEach(sortedMedications(medications, logs: store.logs, referenceDate: referenceDate)) { med in
                MedicationRow(
                    medication: med,
                    referenceDate: referenceDate,
                    onLogTap: {
                        HapticManager.shared.lightImpact()
                        showingLogSheetFor.wrappedValue = store.findMedication(with: med.logReferenceID ?? med.id) ?? med
                    },
                    onEditTap: {
                        HapticManager.shared.lightImpact()
                        selectedMedicationToEdit.wrappedValue = store.findMedication(with: med.logReferenceID ?? med.id) ?? med
                    },
                    onArchiveTap: med.logEntryID == nil ? {
                        HapticManager.shared.warningNotification()
                        medicationToArchive.wrappedValue = store.findMedication(with: med.logReferenceID ?? med.id) ?? med
                        showArchiveAlert.wrappedValue = true
                    } : nil
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
    onShowHistory: @escaping () -> Void,
    onShowSettings: @escaping () -> Void,
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
                Button(action: onShowHistory) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#F5F7F4"))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .frame(width: 46, height: 46)
                .glassCircleBackground(diameter: 46, isSelected: false, opacity: 0.95)
                .contentShape(Circle())

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

                Button(action: onShowSettings) {
                    Image(systemName: "gearshape")
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

fileprivate struct FloatingActionButton: View {
    @Binding var showingAddSheet: Bool
    @Binding var showingArchivedSheet: Bool
    let hasArchivedMedications: Bool
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
                                // Archive button (always show)
                                expandedActionButton(
                                    icon: "archivebox.fill",
                                    text: "Archive",
                                    delay: 0.1
                                ) {
                                    HapticManager.shared.lightImpact()
                                    showingArchivedSheet = true
                                    collapseMenu()
                                }
                                
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
        .accessibilityHint("Double tap to \(isExpanded ? "close" : "open") the actions menu with options to add medications and view archive")
        .accessibilityAddTraits(.isButton)
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

@ViewBuilder
func ArchivedMedicationsSheet(
    store: MedicationStore,
    showingArchivedSheet: Binding<Bool>
) -> some View {
    NavigationView {
        ZStack {
            // Enhanced background with subtle gradient
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
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Enhanced Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Archived Medications")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#F5F7F4"))
                        
                        Text("Medications you've archived can be restored anytime")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#E0E7DC").opacity(0.9))
                    }
                    .padding(.top, 20)
                    
                    if store.archivedMedications.isEmpty {
                        // Empty state
                        VStack(spacing: 20) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 50))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                            
                            Text("No archived medications")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hex: "#F5F7F4"))
                            
                            Text("Medications you archive will appear here")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#E0E7DC").opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                    } else {
                        // Archived medications list
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(store.archivedMedications) { med in
                                ArchivedMedicationCard(
                                    medication: med,
                                    onUnarchive: {
                                        HapticManager.shared.lightImpact()
                                        store.unarchiveMedication(med)
                                    }
                                )
                            }
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    HapticManager.shared.lightImpact()
                    showingArchivedSheet.wrappedValue = false
                }
                .foregroundColor(Color(hex: "#C7C7BD"))
            }
        }
    }
}

@ViewBuilder
func ArchivedMedicationCard(
    medication: Medication,
    onUnarchive: @escaping () -> Void
) -> some View {
    HStack(spacing: 16) {
        // Medication icon
        Image(systemName: "pill.circle.fill")
            .font(.system(size: 32))
            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
        
        // Medication info
        VStack(alignment: .leading, spacing: 4) {
            Text(medication.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#F5F7F4"))
                .lineLimit(1)
            
            Text("\(medication.dosage) \(medication.dosageUnit) - \(medication.frequency)")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "#E0E7DC"))
                .lineLimit(1)
            
            if let notes = medication.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#E0E7DC").opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        
        Spacer()
        
        // Unarchive button
        Button(action: onUnarchive) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.bin")
                    .font(.system(size: 14, weight: .semibold))
                Text("Restore")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(Color(hex: "#404C42"))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#E0E7DC"))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    .padding(20)
    .background(
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(hex: "#5B695D"))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#E0E7DC").opacity(0.25), lineWidth: 1)
            )
    )
}

fileprivate struct MedicationCabinetSheet: View {
    let medications: [Medication]
    let logs: [MedicationLog]
    let referenceDate: Date
    let onLogMedication: (Medication) -> Void
    let onEditMedication: (Medication) -> Void
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
                        Text("The cabinet keeps medications that are taken as needed or don't currently have reminders, so they stay out of your daily queue.")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#E0E7DC").opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)

                        if medications.isEmpty {
                            Text("Once you schedule a reminder or mark a medication as daily, it will move back into your main list. Until then, everything you store here stays tucked away for when you need it.")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#E0E7DC"))
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
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
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
                    onEditTap: { onEditMedication(medication) }
                )
            }
        }
    }
}

fileprivate struct CabinetMedicationRow: View {
    let medication: Medication
    let onLogTap: () -> Void
    let onEditTap: () -> Void

    private var detailSubtitle: String {
        if medication.frequency == "As needed" {
            return "Take when you need it"
        }
        return "No reminder scheduled"
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
                    HStack {
                        Text("Tap to log")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#2F352F"))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#E0E7DC"))
                    )
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: onEditTap) {
                    HStack {
                        Text("Edit")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#E0E7DC"))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#E0E7DC").opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
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
    }
}

fileprivate struct MedicationsListMainContent: View {
    @ObservedObject var store: MedicationStore
    @Binding var showingAddSheet: Bool
    @Binding var scrolledOffset: CGFloat
    @Binding var showingLogSheetFor: Medication?
    @Binding var selectedMedicationToEdit: Medication?
    @Binding var medicationToArchive: Medication?
    @Binding var showArchiveAlert: Bool
    @Binding var showingArchivedSheet: Bool
    @Binding var showingInteractionSheet: Bool
    @Binding var isCheckingInteractions: Bool
    let onCheckAllInteractions: () async -> Void
    let onAddMedication: () -> Void
    let onShowHistory: () -> Void
    let onShowSettings: () -> Void
    let onShowFocusTimeline: () -> Void
    let displayedMedications: [Medication]
    let cabinetMedications: [Medication]
    let onShowCabinet: () -> Void
    let referenceDate: Date

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
                            onShowHistory: onShowHistory,
                            onShowSettings: onShowSettings,
                            onShowCabinet: onShowCabinet,
                            cabinetCount: cabinetMedications.count
                        )

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
                                showingLogSheetFor: $showingLogSheetFor,
                                selectedMedicationToEdit: $selectedMedicationToEdit,
                                medicationToArchive: $medicationToArchive,
                                showArchiveAlert: $showArchiveAlert,
                                showingArchivedSheet: $showingArchivedSheet,
                                showingInteractionSheet: $showingInteractionSheet,
                                isCheckingInteractions: $isCheckingInteractions,
                                onCheckAllInteractions: onCheckAllInteractions,
                                onAddMedication: onAddMedication,
                                onShowFocusTimeline: onShowFocusTimeline,
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
        return "Taken at \(DoseButtonState.loggedTimeFormatter.string(from: actualTime))"
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
    @Binding var showDetails: Bool
    let onLogTap: () -> Void
    let doseStates: [DoseButtonState]
    let onDoseTap: (Int) -> Void
    let onSkipDose: (Int) -> Void
    let highlightedDoseIndex: Int?
    let compactLayout: Bool
    
    @State private var awaitingActionConfirmation = false
    @State private var actionConfirmationWorkItem: DispatchWorkItem?
    @State private var confirmingDoseIndex: Int?
    @State private var doseConfirmationWorkItem: DispatchWorkItem?

    private let timelineTimeWidth: CGFloat = 58
    private let logButtonMinWidth: CGFloat = 96
    private let confirmationDuration: TimeInterval = 5.0

    private var usesTimelineLayout: Bool {
        !doseStates.isEmpty && !compactLayout
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
        if cycleStatus == .taken {
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
        switch cycleStatus {
        case .taken:
            return ("", .clear, false) // No status text when taken, button shows "Taken"
        case .skipped:
            return ("", .clear, false) // No status text when skipped, button shows "Skipped"
        case .overdue(let minutesPast):
            return ("Overdue by \(formatTimeText(minutes: minutesPast))", Color(hex: "#FFA726"), true)
        case .due(let minutesRemaining):
            return ("Due in \(formatTimeText(minutes: minutesRemaining))", Color(hex: "#D7CCC8"), true)
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
            guard state.status == .taken, let actualTime = state.actualTime else { continue }
            let timeText = Self.badgeTimeFormatter.string(from: actualTime)
            let prefix: String? = showDoseLabel
                ? ((state.customTitle?.isEmpty == false) ? state.customTitle : "Dose \(state.index + 1)")
                : nil
            let label: String
            if let prefix {
                label = "\(prefix) • \(timeText)"
            } else {
                label = timeText
            }
            badges.append(DoseBadgeItem(id: state.index, text: label))
        }

        return badges
    }

    @ViewBuilder
    private var takenDoseBadgesView: some View {
        let badges = takenDoseBadges
        if !badges.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(badges) { badge in
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: "checkmark.app.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.58))
                        Text(badge.text)
                            .font(.system(.body, weight: .semibold))
                            .foregroundColor(Color(hex: "#F5F7F4"))
                    }
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

    // Moved buttonProperties computed property
    private var takenButtonLabel: String {
        doseStates.count > 1 ? "All Taken" : "Taken"
    }

    private func buttonProperties() -> (iconName: String, text: String, fgColor: Color, bgColor: Color) {
        switch cycleStatus {
        case .taken:
            return (
                iconName: "checkmark.circle.fill",
                text: takenButtonLabel,
                fgColor: Color(hex: "#D9DDD7"),
                bgColor: Color(hex: "#52594F").opacity(0.6)
            )
        case .skipped:
            return (iconName: "xmark.circle.fill", text: "Skipped", fgColor: Color(hex: "#C62828"), bgColor: Color(hex: "#FFCDD2"))
        case .overdue(_), .due(_):
            return (iconName: "circle", text: "Take Now", fgColor: Color(hex: "#E0E0E0"), bgColor: Color.black.opacity(0.4))
        case .asNeeded: // Add .asNeeded case
            return (iconName: "circle", text: "Take Now", fgColor: Color(hex: "#E0E0E0"), bgColor: Color.black.opacity(0.4))
        }
    }

    private var actionButtonStrokeOpacity: Double {
        switch cycleStatus {
        case .taken, .skipped:
            return 0.12
        default:
            return 0.26
        }
    }

    private var actionButtonHorizontalPadding: CGFloat {
        switch cycleStatus {
        case .taken, .skipped:
            return 18
        default:
            return 22
        }
    }

    private var requiresActionConfirmation: Bool {
        switch cycleStatus {
        case .due, .asNeeded:
            return true
        default:
            return false
        }
    }

    private var isActionConfirmationActive: Bool {
        awaitingActionConfirmation && requiresActionConfirmation
    }

    private var confirmForegroundColor: Color {
        Color(hex: "#424C43")
    }

    private var confirmBackgroundColor: Color {
        Color(hex: "#D9D9D9")
    }

    private var actionConfirmationAppearance: (iconName: String, text: String, fgColor: Color, bgColor: Color) {
        (iconName: "hand.tap.fill", text: "Tap to confirm", fgColor: confirmForegroundColor, bgColor: confirmBackgroundColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: stackSpacing) {
            HStack(alignment: .center, spacing: 16) {
                medicationInfoSection
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    if !usesTimelineLayout && !compactLayout {
                        actionButton
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
                takenDoseBadgesView
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
    
    // Enhanced action button
    private var actionButton: some View {
        let properties = buttonProperties()
        let appearance = isActionConfirmationActive ? actionConfirmationAppearance : properties

        return Button(action: {
            handleActionButtonTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: appearance.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(appearance.fgColor)
                
                Text(appearance.text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(appearance.fgColor)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, actionButtonHorizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(appearance.bgColor)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .onChange(of: cycleStatus) { _ in
            if !requiresActionConfirmation {
                resetActionConfirmation()
            }
        }
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
        let isConfirmingDose = isDoseConfirming(state.index)
        let defaultForeground = Color.white.opacity(state.status == .pending ? 1 : 0.85)

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
            } else {
                HStack(spacing: 8) {
                    Button(action: {
                        handleDoseButtonTap(for: state)
                    }) {
                        HStack(spacing: 6) {
                            if isConfirmingDose {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(confirmForegroundColor)
                            }

                            Text(isConfirmingDose ? "Tap to confirm" : state.actionLabel)
                                .font(.system(size: 14, weight: .medium))

                            if !isConfirmingDose, state.status == .pending {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .opacity(0.95)
                            }
                        }
                        .foregroundColor(isConfirmingDose ? confirmForegroundColor : defaultForeground)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isConfirmingDose ? Color(hex: "#D9D9D9") : Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(actionButtonStrokeOpacity), lineWidth: 0.9)
                                )
                        )
                        .frame(minWidth: logButtonMinWidth, alignment: .leading)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(state.status != .pending)

                    if isConfirmingDose {
                        Button(action: {
                            HapticManager.shared.warningNotification()
                            resetDoseConfirmation()
                            onSkipDose(state.index)
                        }) {
                            Text("Skip dose")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#FF6B6B"))
                                .frame(minWidth: 80)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "#FF6B6B").opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color(hex: "#FF6B6B").opacity(0.6), lineWidth: 0.9)
                                        )
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(state.status != .pending)
                    }
                }
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
        onLogTap()
    }

    private func handleActionButtonTap() {
        guard requiresActionConfirmation else {
            handleButtonTap()
            return
        }

        if isActionConfirmationActive {
            resetActionConfirmation()
            handleButtonTap()
        } else {
            startActionConfirmation()
        }
    }

    private func startActionConfirmation() {
        awaitingActionConfirmation = true
        actionConfirmationWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            awaitingActionConfirmation = false
            actionConfirmationWorkItem = nil
        }
        actionConfirmationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + confirmationDuration, execute: workItem)
    }

    private func resetActionConfirmation() {
        awaitingActionConfirmation = false
        actionConfirmationWorkItem?.cancel()
        actionConfirmationWorkItem = nil
    }

    private func handleDoseButtonTap(for state: DoseButtonState) {
        guard state.status == .pending else { return }

        if confirmingDoseIndex == state.index {
            resetDoseConfirmation()
            withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.75)) {
                onDoseTap(state.index)
            }
        } else {
            startDoseConfirmation(for: state.index)
        }
    }

    private func startDoseConfirmation(for index: Int) {
        confirmingDoseIndex = index
        doseConfirmationWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            if confirmingDoseIndex == index {
                confirmingDoseIndex = nil
            }
            doseConfirmationWorkItem = nil
        }
        doseConfirmationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + confirmationDuration, execute: workItem)
    }

    private func resetDoseConfirmation() {
        confirmingDoseIndex = nil
        doseConfirmationWorkItem?.cancel()
        doseConfirmationWorkItem = nil
    }

    private func isDoseConfirming(_ index: Int) -> Bool {
        confirmingDoseIndex == index
    }
}

struct MedicationRow: View {
    let medication: Medication
    let referenceDate: Date
    let onLogTap: () -> Void
    let onEditTap: () -> Void
    let onArchiveTap: (() -> Void)? // Optional for archived meds
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

    // Calculates minutes to the effective due time
    private var minutesToEffectiveDueTime: Int {
        let now = referenceDate
        return Calendar.current.dateComponents([.minute], from: now, to: effectiveDueTime).minute ?? 0
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
        if isTakenStatus {
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
        if isTakenStatus {
            return 0.015
        }
        return isLoggedStatus ? 0.18 : 0.25
    }

    private var cardPrimaryShadowRadius: CGFloat {
        if isTakenStatus {
            return 2
        }
        return isLoggedStatus ? 10 : 12
    }

    private var cardPrimaryShadowYOffset: CGFloat {
        if isTakenStatus {
            return 0.5
        }
        return isLoggedStatus ? 4 : 6
    }

    private var cardSecondaryShadowOpacity: Double {
        if isTakenStatus {
            return 0
        }
        return isLoggedStatus ? 0.08 : 0.1
    }

    private var cardSecondaryShadowRadius: CGFloat {
        if isTakenStatus {
            return 0
        }
        return isLoggedStatus ? 3 : 4
    }

    private var cardSecondaryShadowYOffset: CGFloat {
        if isTakenStatus {
            return 0
        }
        return isLoggedStatus ? 1 : 2
    }

    private var isTakenStatus: Bool {
        cycleStatus == .taken
    }

    private var skippedIndicatorColor: Color {
        Color(hex: "#FF6B6B")
    }

    private var leadingIndicatorConfig: (color: Color, width: CGFloat)? {
        guard case .skipped = cycleStatus else { return nil }
        return (skippedIndicatorColor, 4)
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
                showDetails: detailBinding,
                onLogTap: onLogTap,
                doseStates: doseButtonStates,
                onDoseTap: { doseIndex in
                    logDose(at: doseIndex)
                },
                onSkipDose: { doseIndex in
                    skipDose(at: doseIndex)
                },
                highlightedDoseIndex: highlightedDoseIndex,
                compactLayout: isTakenStatus
            )
            
            if showsDetails {
                MedicationRowDetailsView(
                    medication: medication,
                    onEditTap: onEditTap,
                    onArchiveTap: onArchiveTap
                )
                .padding(.top, 12)
            }
        }
        .background(
            cardBackgroundColor
        )
        .cornerRadius(14)
        .overlay(alignment: .leading) {
            if let config = leadingIndicatorConfig {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(config.color)
                    .mask(
                        LeadingStripeMask(width: config.width, cornerRadius: 14)
                    )
            }
        }
        .overlay(notificationGlowOverlay)
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
                onLogTap()
            case .taken, .skipped:
                toggleExpansion()
            case .asNeeded:
                onLogTap()
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

            if let archiveTap = onArchiveTap {
                Button(role: .destructive) {
                    HapticManager.shared.warningNotification()
                    archiveTap()
                } label: {
                    Text("Delete")
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
    
    // Enhanced border overlay with better visual feedback
    private var enhancedBorderOverlay: some View {
        let (borderColor, borderWidth): (Color, CGFloat)
        
        switch cycleStatus {
        case .taken:
            borderColor = Color(hex: "#D7CCC8").opacity(0.35)
            borderWidth = 0.6
        case .skipped:
            borderColor = Color(hex: "#FF6B6B")
            borderWidth = 2.0
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
        
        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        borderColor.opacity(0.8),
                        borderColor.opacity(0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: borderWidth
            )
    }

    private struct LeadingStripeMask: Shape {
        var width: CGFloat
        var cornerRadius: CGFloat

        func path(in rect: CGRect) -> Path {
            let stripeWidth = min(width, rect.width)
            let radius = min(cornerRadius, rect.height / 2, stripeWidth / 2)
            let stripeRect = CGRect(x: rect.minX, y: rect.minY, width: stripeWidth, height: rect.height)

            var path = Path()
            let topLeft = CGPoint(x: stripeRect.minX, y: stripeRect.minY)
            let topRight = CGPoint(x: stripeRect.maxX, y: stripeRect.minY)
            let bottomRight = CGPoint(x: stripeRect.maxX, y: stripeRect.maxY)
            let bottomLeft = CGPoint(x: stripeRect.minX, y: stripeRect.maxY)

            path.move(to: CGPoint(x: topLeft.x, y: topLeft.y + radius))
            path.addArc(
                center: CGPoint(x: topLeft.x + radius, y: topLeft.y + radius),
                radius: radius,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 270),
                clockwise: false
            )

            path.addLine(to: topRight)
            path.addLine(to: bottomRight)

            path.addArc(
                center: CGPoint(x: bottomLeft.x + radius, y: bottomLeft.y - radius),
                radius: radius,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false
            )

            path.addLine(to: CGPoint(x: bottomLeft.x, y: bottomLeft.y - radius))
            path.closeSubpath()

            return path
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
        
        store.logMedicationTaken(
            medication: medication,
            actualTime: now,
            notes: nil,
            skipped: !taken,
            reminderIndex: reminderIndex
        )
    }
    
    private func logDose(at index: Int) {
        if medication.reminderTimes.isEmpty {
            guard todaysLogsForMedication.first(where: { $0.reminderIndex == nil }) == nil else { return }
            store.logMedicationTaken(
                medication: medication,
                actualTime: Date(),
                notes: nil,
                skipped: false,
                reminderIndex: nil
            )
            return
        }
        
        guard medication.reminderTimes.indices.contains(index) else { return }
        guard !todaysLogsForMedication.contains(where: { $0.reminderIndex == index }) else { return }
        
        store.logMedicationTaken(
            medication: medication,
            actualTime: Date(),
            notes: nil,
            skipped: false,
            reminderIndex: index
        )
    }

    private func skipDose(at index: Int) {
        if medication.reminderTimes.isEmpty {
            guard todaysLogsForMedication.first(where: { $0.reminderIndex == nil }) == nil else { return }
            store.skipMedication(
                medication: medication,
                actualTime: Date(),
                notes: nil,
                reminderIndex: nil
            )
            return
        }

        guard medication.reminderTimes.indices.contains(index) else { return }
        guard !todaysLogsForMedication.contains(where: { $0.reminderIndex == index }) else { return }

        store.skipMedication(
            medication: medication,
            actualTime: Date(),
            notes: nil,
            reminderIndex: index
        )
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
    let onEditTap: () -> Void
    let onArchiveTap: (() -> Void)?

    private var baseTimeForTiming: Date {
        // Use the first reminder time if available, otherwise fall back to the primary time
        medication.reminderTimes.first ?? medication.timeToTake
    }

    private var reminderTimesString: String {
        if medication.reminderTimes.isEmpty {
            return commonFormatTime(medication.timeToTake) // Fallback to single timeToTake
        }
        return medication.reminderTimes.map { commonFormatTime($0) }.joined(separator: ", ")
    }

    private var notificationsEnabled: Bool {
        return !(medication.notificationID == nil && medication.notificationIDs.isEmpty)
    }
    
    private var stimulantTimingSummary: String? {
        guard medication.hasStimulantTiming,
              medication.enableStimulantPhaseNotifications,
              let onset = medication.onsetMinutes,
              let duration = medication.durationMinutes else { return nil }
        
        let calendar = Calendar.current
        let base = baseTimeForTiming
        
        guard let onsetDate = calendar.date(byAdding: .minute, value: onset, to: base),
              let fadeDate = calendar.date(byAdding: .minute, value: duration, to: base) else {
            return nil
        }
        
        let onsetString = commonFormatTime(onsetDate)
        let fadeString = commonFormatTime(fadeDate)
        return "Starts ~\(onsetString), wears off ~\(fadeString)"
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

                Text("Long press to edit or archive")
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

    private var detailRowEntries: [DetailEntry] {
        var entries: [DetailEntry] = []

        if let timingSummary = stimulantTimingSummary {
            entries.append(
                DetailEntry(
                    label: "Focus Window",
                    value: timingSummary,
                    lineLimit: 2,
                    placeValueOnNewLine: true
                )
            )
        }

        if medication.enableDailyCheckIn {
            let checkInDescription: String
            if medication.medicationType == .stimulant {
                if let customTime = medication.dailyCheckInTime {
                    checkInDescription = "Custom: \(commonFormatTime(customTime))"
                } else {
                    checkInDescription = "~10 min before wear-off"
                }
            } else if let customTime = medication.dailyCheckInTime {
                checkInDescription = "Wellness: \(commonFormatTime(customTime))"
            } else {
                checkInDescription = "Daily reflection reminder"
            }

            entries.append(
                DetailEntry(
                    label: "Daily Check-in",
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
