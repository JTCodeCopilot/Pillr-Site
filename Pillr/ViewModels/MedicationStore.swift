//
//  MedicationStore.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI
import UserNotifications
import CloudKit
import UIKit
import Combine

struct ADHDDoseTimelineEntry: Identifiable, Equatable {
    let id = UUID()
    let medication: Medication
    let actualTime: Date
    let scheduledTime: Date?
    let onsetTime: Date
    let fadeTime: Date
}

enum DailyCheckInEntrySource {
    case manual
    case notification
}

struct DailyCheckInContext: Identifiable {
    let id: UUID
    let medication: Medication
    let logID: UUID?
    let entrySource: DailyCheckInEntrySource

    init(
        medication: Medication,
        logID: UUID? = nil,
        entrySource: DailyCheckInEntrySource = .manual
    ) {
        self.id = logID ?? UUID()
        self.medication = medication
        self.logID = logID
        self.entrySource = entrySource
    }
}

enum PendingCheckIn {
    case daily(DailyCheckInContext)

    var key: String {
        switch self {
        case .daily(let context):
            let logKey = context.logID?.uuidString ?? "none"
            return "daily-\(context.medication.id.uuidString)-\(logKey)"
        }
    }
}

@MainActor
class MedicationStore: ObservableObject {
    struct LogUndoAction: Identifiable, Equatable {
        let id = UUID()
        let newLog: MedicationLog
        let replacedLog: MedicationLog?
        let replacedLogIndex: Int?
        let pillCountDelta: Int

        init(newLog: MedicationLog, replacedLog: MedicationLog?, replacedLogIndex: Int?, pillCountDelta: Int) {
            self.newLog = newLog
            self.replacedLog = replacedLog
            self.replacedLogIndex = replacedLogIndex
            self.pillCountDelta = pillCountDelta
        }
    }

    @Published var medications: [Medication] = []
    @Published var logs: [MedicationLog] = []
    @Published private(set) var lastCloudSyncDate: Date?
    @Published var recentADHDDoseTimeline: ADHDDoseTimelineEntry?
    /// When set (typically from a notification tap), the UI
    /// should present a Reflection logging sheet for this medication.
    @Published var dailyCheckInContext: DailyCheckInContext?
    /// When set, the medications list should highlight / expand this medication card.
    @Published var highlightedMedicationID: UUID?
    /// When a medication reminder notification is tapped, this ID gets a quick glow treatment.
    @Published var notificationHighlightMedicationID: UUID?
    /// The medication that should currently show expanded details on the My Meds list.
    @Published var expandedMedicationID: UUID?
    /// Most recently added medication (used to prompt interaction checks).
    @Published var lastAddedMedicationID: UUID?
    /// Allows any view to request a specific tab to show (e.g., jump back to My Meds).
    @Published var requestedMainTab: MainTab?
    @Published private(set) var overdueMedicationIDs: Set<UUID> = []
    @Published private(set) var overdueReminderNotificationIDs: Set<String> = []
    @Published private(set) var isCloudSyncInProgress = false
    private let notificationManager: NotificationManagerProtocol
    private let hapticManager = HapticManager.shared
    private let cloudSync: CloudKitMedicationSyncProtocol
    private var dayChangeObserver: NSObjectProtocol?
    private var appActiveObserver: NSObjectProtocol?
    private var cloudSyncPreferenceCancellable: AnyCancellable?
    private var cloudSyncOperationCount = 0
    private var lastCloudSyncPreferenceState: Bool = false
    private var isPerformingInitialCloudSync = false
    private var lastReminderKickstartDate: Date?
    private let reminderKickstartMinimumInterval: TimeInterval = 30
    private var lastNotificationResetDay = Calendar.current.startOfDay(for: Date())
    private var pendingCheckIns: [PendingCheckIn] = []
    
    // Shared instance for access from notification handlers
    static let shared = MedicationStore()
    
    // Static method to create a lightweight preview store
    static func previewStore() -> MedicationStore {
        let store = MedicationStore(isPreview: true)
        store.addSampleData()
        return store
    }

    // Local device storage using UserDefaults - all data stays on device
    // No cloud storage or external servers involved
    // Data is only removed when the app is completely uninstalled from the device
    private let medicationsKey = "medicationsData"
    private let logsKey = "medicationLogsData"
    private let medicationsBackupKey = "medicationsData_backup"
    private let logsBackupKey = "medicationLogsData_backup"
    private let deletedMedicationIDsKey = "deletedMedicationIDs"
    private let legacyLogMedicationIDRepairV1Key = "legacyLogMedicationIDRepair_v1_complete"
    private var deletedMedicationIDs: Set<UUID> = []
    private let isPreviewMode: Bool

    private var shouldUseCloudSync: Bool {
        !isPreviewMode && UserSettings.shared.shouldUseCloudSync
    }

    var activeMedications: [Medication] {
        medications.filter { !$0.isDeleted }
    }

    #if DEBUG
    var debugDeletedMedicationCount: Int {
        deletedMedicationIDs.count
    }

    var debugTotalMedicationCount: Int {
        medications.count
    }
    #endif

    init(
        isPreview: Bool = false,
        notificationManager: NotificationManagerProtocol = NotificationManager.shared,
        cloudSync: CloudKitMedicationSyncProtocol = CloudKitMedicationSync.shared
    ) {
        self.isPreviewMode = isPreview
        self.notificationManager = notificationManager
        self.cloudSync = cloudSync
        if !isPreview {
            if let stored = UserDefaults.standard.stringArray(forKey: deletedMedicationIDsKey) {
                deletedMedicationIDs = Set(stored.compactMap { UUID(uuidString: $0) })
            }
        }
        self.lastCloudSyncPreferenceState = shouldUseCloudSync
        notificationManager.badgeCountProvider = { [weak self] date in
            guard let self else { return 0 }
            if Thread.isMainThread {
                return self.overdueReminderCount(referenceDate: date)
            }
            var result = 0
            DispatchQueue.main.sync {
                result = self.overdueReminderCount(referenceDate: date)
            }
            return result
        }
        if !isPreview {
            loadMedications()
            loadLogs()
            runLegacyLogMedicationIDRepair(markCompleteWhenNoChanges: !shouldUseCloudSync)
            if shouldUseCloudSync {
                fetchCloudData()
            }
            lastNotificationResetDay = Calendar.current.startOfDay(for: Date())
            startObservingDayChanges()
            observeCloudSyncPreference()
        }
    }

    deinit {
        if let observer = dayChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = appActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        cloudSyncPreferenceCancellable?.cancel()
    }
    
    // Find a medication by its ID
    func findMedication(with id: UUID) -> Medication? {
        return medications.first { $0.id == id && !$0.isDeleted }
    }

    func addMedication(
        name: String,
        dosage: String,
        dosageUnit: String,
        iconName: String,
        frequency: String,
        timeToTake: Date,
        reminderTimes: [Date] = [],
        notes: String?,
        enableNotification: Bool = true,
        pillCount: Int? = nil,
        pillsPerDose: Int = 1,
        refillThreshold: Int? = nil,
        isOneTimeWithFollowUp: Bool = false,
        medicationType: MedicationType = .other,
        isExtendedRelease: Bool = false,
        onsetMinutes: Int? = nil,
        durationMinutes: Int? = nil,
        effectsGoneMinutes: Int? = nil,
        enableDailyCheckIn: Bool = false,
        enableStimulantPhaseNotifications: Bool = false,
        dailyCheckInTime: Date? = nil
    ) -> Bool {
        // Check if user can add more medications
        let currentActiveMedications = activeMedications.count
        guard UserSettings.shared.canAddMedication(currentCount: currentActiveMedications) else {
            return false // Cannot add medication due to free tier limit
        }
        
        let isPremiumUser = UserSettings.shared.isPremiumUser
        // Only allow pill tracking for premium users
        let finalPillCount = isPremiumUser ? pillCount : nil
        let finalPillsPerDose = isPremiumUser ? pillsPerDose : 1
        let finalRefillThreshold = isPremiumUser ? refillThreshold : nil
        let finalFrequency = isPremiumUser ? frequency : (frequency == "As needed" ? frequency : "Once daily")
        let finalReminderTimes = isPremiumUser ? reminderTimes : []
        let finalEnableDailyCheckIn = isPremiumUser ? enableDailyCheckIn : false
        let finalDailyCheckInTime = finalEnableDailyCheckIn ? dailyCheckInTime : nil
        
        var newMed = Medication(
            name: name,
            dosage: dosage,
            dosageUnit: dosageUnit,
            iconName: iconName,
            createdAt: Date(), // Set creation date to now
            updatedAt: Date(),
            frequency: finalFrequency,
            medicationType: medicationType,
            isExtendedRelease: isExtendedRelease,
            onsetMinutes: onsetMinutes,
            durationMinutes: durationMinutes,
            effectsGoneMinutes: effectsGoneMinutes,
            enableDailyCheckIn: finalEnableDailyCheckIn,
            enableStimulantPhaseNotifications: enableStimulantPhaseNotifications,
            dailyCheckInTime: finalDailyCheckInTime,
            timeToTake: timeToTake,
            reminderTimes: finalReminderTimes,
            notes: notes,
            pillCount: finalPillCount,
            initialPillCount: finalPillCount,
            pillsPerDose: finalPillsPerDose,
            refillThreshold: finalRefillThreshold,
            isOneTimeWithFollowUp: isOneTimeWithFollowUp,
        )
        
        deletedMedicationIDs.remove(newMed.id)
        persistDeletedMedicationIDs()
        notificationManager.registerTrackedMedicationID(newMed.id)

        // Schedule notifications only if enabled
        if enableNotification && finalFrequency != "As needed" {
            notificationManager.requestAuthorizationIfNeeded()
            if !newMed.reminderTimes.isEmpty {
                // Multiple notifications support
                let notificationIDs = notificationManager.scheduleMultipleNotifications(for: newMed)
                newMed.notificationIDs = notificationIDs
                newMed.notificationID = nil
            } else if isOneTimeWithFollowUp {
                newMed.notificationID = notificationManager.scheduleNotification(for: newMed)
                newMed.notificationIDs = []
            } else if reminderTimes.isEmpty {
                // Legacy single notification support
                newMed.notificationID = notificationManager.scheduleNotification(for: newMed)
                newMed.notificationIDs = []
            }
        } else {
            newMed.notificationID = nil
            newMed.notificationIDs = []
        }
        
        medications.append(newMed)
        lastAddedMedicationID = newMed.id
        saveMedications()
        syncMedicationWithCloud(newMed)
        scheduleDailyCheckInReminderIfNeeded(for: newMed)
        return true // Successfully added medication
    }
    
    func updateMedication(_ medication: Medication, enableNotification: Bool = true) {
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            let oldMedication = medications[index]

            // Create a mutable copy
            var updatedMedication = medication
            
            // Only allow premium-only features when subscribed
            if !UserSettings.shared.isPremiumUser {
                updatedMedication.pillCount = nil
                updatedMedication.pillsPerDose = 1
                updatedMedication.refillThreshold = nil
                updatedMedication.enableDailyCheckIn = false
                updatedMedication.dailyCheckInTime = nil
                updatedMedication.reminderTimes = []
                if updatedMedication.frequency != "As needed" {
                    updatedMedication.frequency = "Once daily"
                }
            }
            updatedMedication.updatedAt = Date()
            if updatedMedication.initialPillCount == nil {
                updatedMedication.initialPillCount = oldMedication.initialPillCount
                    ?? estimatedInitialPillCount(for: oldMedication)
                    ?? updatedMedication.pillCount
            }
            
            // Schedule new notifications if enabled
            let wantsNotifications = enableNotification && updatedMedication.frequency != "As needed"
            let reminderSettingsChanged = medicationReminderSettingsChanged(
                old: oldMedication,
                updated: updatedMedication
            )
            let shouldRescheduleMedicationReminders = wantsNotifications
                && (!oldMedication.hasActiveReminder || reminderSettingsChanged)

            if wantsNotifications {
                notificationManager.registerTrackedMedicationID(updatedMedication.id)
                notificationManager.requestAuthorizationIfNeeded()
                if shouldRescheduleMedicationReminders {
                    if let oldNotificationID = oldMedication.notificationID {
                        notificationManager.cancelNotification(with: oldNotificationID)
                    }

                    if !oldMedication.notificationIDs.isEmpty {
                        notificationManager.cancelMultipleNotifications(ids: oldMedication.notificationIDs)
                    }

                    if !updatedMedication.reminderTimes.isEmpty {
                        // Multiple notifications
                        let newNotificationIDs = notificationManager.scheduleMultipleNotifications(for: updatedMedication)
                        updatedMedication.notificationIDs = newNotificationIDs
                        updatedMedication.notificationID = nil
                    } else if updatedMedication.isOneTimeWithFollowUp {
                        updatedMedication.notificationID = notificationManager.scheduleNotification(for: updatedMedication)
                        updatedMedication.notificationIDs = []
                    } else if updatedMedication.reminderTimes.isEmpty {
                        // Legacy single notification
                        updatedMedication.notificationID = notificationManager.scheduleNotification(for: updatedMedication)
                        updatedMedication.notificationIDs = []
                    }
                } else {
                    updatedMedication.notificationID = oldMedication.notificationID
                    updatedMedication.notificationIDs = oldMedication.notificationIDs
                }
            } else {
                if let oldNotificationID = oldMedication.notificationID {
                    notificationManager.cancelNotification(with: oldNotificationID)
                }

                if !oldMedication.notificationIDs.isEmpty {
                    notificationManager.cancelMultipleNotifications(ids: oldMedication.notificationIDs)
                }

                updatedMedication.notificationID = nil
                updatedMedication.notificationIDs = []
                notificationManager.cancelMedicationNotifications(for: updatedMedication.id)
            }
            
            // Update medication name in existing logs if it changed
            if oldMedication.name != updatedMedication.name {
                updateMedicationNameInLogs(medicationID: updatedMedication.id, newName: updatedMedication.name)
            }
            
            // Update in the array
            medications[index] = updatedMedication
            saveMedications()
            syncMedicationWithCloud(updatedMedication)
            let dailyCheckInSettingsChanged = oldMedication.enableDailyCheckIn != updatedMedication.enableDailyCheckIn
                || oldMedication.dailyCheckInTime != updatedMedication.dailyCheckInTime
            if dailyCheckInSettingsChanged {
                notificationManager.cancelPendingDailyCheckInNotifications(for: updatedMedication.id)
                scheduleDailyCheckInReminderIfNeeded(for: updatedMedication)
            }

        }
    }

    private func medicationReminderSettingsChanged(old: Medication, updated: Medication) -> Bool {
        if old.isOneTimeWithFollowUp != updated.isOneTimeWithFollowUp {
            return true
        }

        let calendar = Calendar.current
        let oldTime = calendar.dateComponents([.hour, .minute], from: old.timeToTake)
        let newTime = calendar.dateComponents([.hour, .minute], from: updated.timeToTake)
        if oldTime.hour != newTime.hour || oldTime.minute != newTime.minute {
            return true
        }

        return !reminderTimesMatch(old.reminderTimes, updated.reminderTimes)
    }

    private func reminderTimesMatch(_ lhs: [Date], _ rhs: [Date]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        let calendar = Calendar.current

        for (left, right) in zip(lhs, rhs) {
            let leftComponents = calendar.dateComponents([.hour, .minute], from: left)
            let rightComponents = calendar.dateComponents([.hour, .minute], from: right)
            if leftComponents.hour != rightComponents.hour
                || leftComponents.minute != rightComponents.minute {
                return false
            }
        }

        return true
    }

    private func estimatedInitialPillCount(for medication: Medication) -> Int? {
        guard let currentCount = medication.pillCount else { return nil }
        let consumedTotal = logs
            .filter { $0.medicationID == medication.id && $0.isDoseLog && !$0.skipped }
            .reduce(0) { partial, log in
                let consumed = log.pillsConsumed ?? medication.pillsPerDose
                return partial + max(consumed, 0)
            }
        return currentCount + consumedTotal
    }

    @discardableResult
    func logMedicationTaken(
        medication: Medication,
        actualTime: Date,
        notes: String?,
        skipped: Bool = false,
        reminderIndex: Int? = nil,
        feelingRating: Int? = nil,
        focusRating: Int? = nil,
        sideEffectSeverity: Int? = nil,
        reflectionSummary: String? = nil,
        showFocusTimeline: Bool = true,
        isDailyCheckIn: Bool = false
    ) -> LogUndoAction? {
        let storedMedication = medications.first(where: { $0.id == medication.id })
        let pillsConsumed: Int? = {
            if isDailyCheckIn {
                return nil
            }
            return skipped ? 0 : medication.pillsPerDose
        }()
        let calendar = Calendar.current
        let resolvedReminderIndex = reminderIndex ?? inferReminderIndexIfNeeded(for: medication, actualTime: actualTime)
        var previousLog: MedicationLog?
        var previousLogIndex: Int?
        
        if !medication.isCabinetMedication {
            if let existingIndex = logs.firstIndex(where: { log in
                guard log.medicationID == medication.id,
                      calendar.isDate(log.takenAt, inSameDayAs: actualTime) else {
                    return false
                }

                if let resolvedReminderIndex {
                    if log.reminderIndex == resolvedReminderIndex {
                        return true
                    }
                    if log.reminderIndex == nil && medication.reminderTimes.count <= 1 {
                        return true
                    }
                    return false
                } else {
                    return log.reminderIndex == nil
                }
            }) {
                let existingLog = logs[existingIndex]
                if isDailyCheckIn {
                    applyDailyCheckInUpdates(
                        at: existingIndex,
                        notes: notes,
                        feelingRating: feelingRating,
                        focusRating: focusRating,
                        sideEffectSeverity: sideEffectSeverity,
                        reflectionSummary: reflectionSummary
                    )
                    return nil
                }

                if existingLog.skipped == skipped {
                    hapticManager.warningNotification()
                    return nil
                }

                previousLog = existingLog
                previousLogIndex = existingIndex
                logs.remove(at: existingIndex)
            } else if resolvedReminderIndex == nil {
                // Single-dose medications (no reminder index) can only be logged once per day
                let alreadyLogged = logs.contains { log in
                    log.medicationID == medication.id &&
                    calendar.isDate(log.takenAt, inSameDayAs: actualTime) &&
                    log.reminderIndex == nil
                }

                if alreadyLogged {
                    hapticManager.warningNotification()
                    return nil
                }
            }
        }

        if isDailyCheckIn,
           let existingIndex = logs.firstIndex(where: { log in
            log.medicationID == medication.id &&
            calendar.isDate(log.takenAt, inSameDayAs: actualTime)
           }) {
            applyDailyCheckInUpdates(
                at: existingIndex,
                notes: notes,
                feelingRating: feelingRating,
                focusRating: focusRating,
                sideEffectSeverity: sideEffectSeverity,
                reflectionSummary: reflectionSummary
            )
            return nil
        }
        
        let newLog = MedicationLog(
            medicationID: medication.id,
            medicationName: medication.name,
            takenAt: actualTime,
            updatedAt: Date(),
            notes: notes,
            skipped: skipped,
            isDailyCheckIn: isDailyCheckIn,
            pillsConsumed: pillsConsumed,
            reminderIndex: resolvedReminderIndex,
            feelingRating: feelingRating,
            focusRating: focusRating,
            sideEffectSeverity: sideEffectSeverity,
            reflectionSummary: reflectionSummary,
            medicationDosageText: medication.dosageWithUnit,
            medicationIconName: medication.iconName,
            medicationReminderCount: medication.reminderTimes.count
        )
        
        logs.insert(newLog, at: 0) // Add to the top
        saveLogs()
        
        // Play haptic feedback
        if !skipped { // Only play success haptic if medication is taken, not skipped
            hapticManager.successNotification()
        } else {
            hapticManager.warningNotification() // Optional: different haptic for skipping
        }
        
        // If medication has a pill count, update it (and restore if replacing a taken log)
        var pillCountDelta = 0
        if !skipped && !isDailyCheckIn {
            pillCountDelta -= medication.pillsPerDose
        }
        if let previousLog, !previousLog.skipped, !isDailyCheckIn {
            pillCountDelta += medication.pillsPerDose
        }
        
        if pillCountDelta != 0,
           let index = medications.firstIndex(where: { $0.id == medication.id }),
           var updatedMedication = medications[index] as Medication?,
           var pillCount = updatedMedication.pillCount {
            
            pillCount = max(0, pillCount + pillCountDelta)
            updatedMedication.pillCount = pillCount
            updatedMedication.updatedAt = Date()
            
            // Check if we need to show refill reminder
            if let refillThreshold = updatedMedication.refillThreshold, 
               pillCount <= refillThreshold {
                // Schedule a refill reminder notification
                let content = UNMutableNotificationContent()
                content.title = "Medication Refill Reminder"
                content.body = "Your supply of \(updatedMedication.name) is running low. Only \(pillCount) left."
                content.sound = UNNotificationSound.default
                content.userInfo = [
                    "medicationID": updatedMedication.id.uuidString,
                    "notificationType": "refill"
                ]
                
                let request = UNNotificationRequest(
                    identifier: "refill-\(updatedMedication.id)",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                )
                
                UNUserNotificationCenter.current().add(request)
            }
            
            medications[index] = updatedMedication
            saveMedications()
        }
        syncLogWithCloud(newLog)
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            syncMedicationWithCloud(medications[index])
        }
        
        clearNotificationsForLoggedDose(
            medication: medication,
            storedMedication: storedMedication,
            actualTime: actualTime,
            reminderIndex: resolvedReminderIndex,
            isDailyCheckIn: isDailyCheckIn
        )

        // If this is an ADHD stimulant with timing metadata and not skipped, prepare a focus timeline entry
        if showFocusTimeline,
           !skipped,
           medication.hasStimulantTiming,
           medication.enableStimulantPhaseNotifications,
           let onsetMinutes = medication.onsetMinutes,
           let durationMinutes = medication.durationMinutes {

            let calendar = Calendar.current

            // Compute onset/fade based on the actual logged time
            let onsetTime = calendar.date(byAdding: .minute, value: onsetMinutes, to: actualTime) ?? actualTime
            let fadeTime = calendar.date(byAdding: .minute, value: durationMinutes, to: actualTime) ?? actualTime

            // Best-effort scheduled time for today (for copy like "Scheduled for 8:00, logged at 8:45")
            let scheduledTime = scheduledTimeForToday(
                medication: medication,
                actualTime: actualTime,
                reminderIndex: resolvedReminderIndex
            )

            recentADHDDoseTimeline = ADHDDoseTimelineEntry(
                medication: medication,
                actualTime: actualTime,
                scheduledTime: scheduledTime,
                onsetTime: onsetTime,
                fadeTime: fadeTime
            )
        }

        if !skipped,
           !isDailyCheckIn,
           medication.enableStimulantPhaseNotifications,
           medication.medicationType == .stimulant,
           medication.enableDailyCheckIn,
           medication.dailyCheckInTime == nil {
            notificationManager.scheduleStimulantPhaseNotifications(
                for: medication,
                doseTime: actualTime,
                logID: newLog.id
            )
        }
        
        if !skipped && !isDailyCheckIn {
            scheduleDailyCheckInReminderIfNeeded(for: medication, referenceDate: actualTime)
        }

        return LogUndoAction(
            newLog: newLog,
            replacedLog: previousLog,
            replacedLogIndex: previousLogIndex,
            pillCountDelta: pillCountDelta
        )
    }
    
    // Helper method to update badge count based on overdue medication reminders
    public func resetBadgeIfNeeded() {
        recomputeOverdueStateFromSnapshots(referenceDate: Date())
    }
    
    // Public method that can be called from app delegate/scene
    func checkAndResetBadge() {
        resetBadgeIfNeeded()
    }

    func refreshCloudSyncIfNeeded(completion: ((UIBackgroundFetchResult) -> Void)? = nil) {
        guard shouldUseCloudSync else {
            completion?(.noData)
            return
        }
        fetchCloudData(completion: completion)
    }

    /// Re-applies scheduled reminder windows for active medications that already
    /// have reminders configured, primarily to recover schedules after reinstall
    /// or auth state transitions.
    func kickstartActiveReminderSchedules(referenceDate: Date = Date(), force: Bool = false) {
        guard !isPreviewMode else { return }
        let now = Date()
        if !force,
           let lastRun = lastReminderKickstartDate,
           now.timeIntervalSince(lastRun) < reminderKickstartMinimumInterval {
            return
        }
        lastReminderKickstartDate = now

        let hasActiveReminderMedication = medications.contains {
            !$0.isDeleted && $0.frequency != "As needed" && $0.hasActiveReminder
        }
        guard hasActiveReminderMedication else { return }

        notificationManager.requestAuthorizationIfNeeded { [weak self] granted in
            guard let self, granted else { return }
            DispatchQueue.main.async {
                var updatedMedications = self.medications
                var didRefresh = false

                for index in updatedMedications.indices {
                    let medication = updatedMedications[index]
                    guard !medication.isDeleted,
                          medication.frequency != "As needed",
                          medication.hasActiveReminder else {
                        continue
                    }
                    updatedMedications[index] = self.refreshNotificationSchedule(for: medication)
                    didRefresh = true
                }

                if didRefresh {
                    self.medications = updatedMedications
                    self.saveMedications()
                }
                self.reconcileNotificationSchedules(referenceDate: referenceDate)
                self.resetBadgeIfNeeded()
            }
        }
    }

    private func overdueDoseCount(referenceDate: Date) -> Int {
        overdueReminderCountSnapshot(referenceDate: referenceDate)
    }

    func refreshOverdueMedicationIDs(referenceDate: Date = Date()) {
        recomputeOverdueStateFromSnapshots(referenceDate: referenceDate)
    }

    private func recomputeOverdueStateFromSnapshots(referenceDate: Date) {
        let overdueIDs = overdueMedicationIDsSnapshot(referenceDate: referenceDate)
        let overdueCount = overdueReminderCountSnapshot(referenceDate: referenceDate)
        overdueReminderNotificationIDs = []
        updateOverdueMedicationIDs(overdueIDs)
        notificationManager.setApplicationBadge(count: overdueCount)
    }

    private func overdueMedicationIDsSnapshot(referenceDate: Date) -> Set<UUID> {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        let now = referenceDate
        func startOfMinute(_ date: Date) -> Date {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            return calendar.date(from: components) ?? date
        }
        let nowMinute = startOfMinute(now)
        var overdueIDs = Set<UUID>()

        for medication in activeMedications {
            if medication.frequency == "As needed" {
                continue
            }

            let medicationLogs = logs.filter { log in
                log.medicationID == medication.id &&
                log.isDoseLog &&
                calendar.isDate(log.takenAt, inSameDayAs: referenceDate) &&
                log.takenAt <= referenceDate
            }

            let takenIndices = resolvedTakenReminderIndices(
                medication: medication,
                dayStart: dayStart,
                logs: medicationLogs
            )

            if medication.reminderTimes.isEmpty {
                let dueTime = scheduledReminderTime(
                    medication: medication,
                    reminderIndex: nil,
                    dayStart: dayStart,
                    referenceDate: referenceDate
                )

                let wasTaken = !medicationLogs.isEmpty
                if !wasTaken,
                   nowMinute >= startOfMinute(dueTime),
                   calendar.isDate(dueTime, inSameDayAs: now) {
                    overdueIDs.insert(medication.id)
                }
                continue
            }

            var isOverdue = false
            for (index, _) in medication.reminderTimes.enumerated() {
                if takenIndices.contains(index) {
                    continue
                }
                let dueTime = scheduledReminderTime(
                    medication: medication,
                    reminderIndex: index,
                    dayStart: dayStart,
                    referenceDate: referenceDate
                )
                if nowMinute >= startOfMinute(dueTime),
                   calendar.isDate(dueTime, inSameDayAs: now) {
                    isOverdue = true
                    break
                }
            }

            if isOverdue {
                overdueIDs.insert(medication.id)
            }
        }

        return overdueIDs
    }

    func overdueReminderCount(referenceDate: Date = Date()) -> Int {
        overdueReminderCountSnapshot(referenceDate: referenceDate)
    }

    private func overdueReminderCountSnapshot(referenceDate: Date) -> Int {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        let now = referenceDate
        func startOfMinute(_ date: Date) -> Date {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            return calendar.date(from: components) ?? date
        }
        let nowMinute = startOfMinute(now)
        var overdueCount = 0

        for medication in activeMedications {
            if medication.frequency == "As needed" {
                continue
            }

            let medicationLogs = logs.filter { log in
                log.medicationID == medication.id &&
                log.isDoseLog &&
                calendar.isDate(log.takenAt, inSameDayAs: referenceDate) &&
                log.takenAt <= referenceDate
            }

            let takenIndices = resolvedTakenReminderIndices(
                medication: medication,
                dayStart: dayStart,
                logs: medicationLogs
            )

            if medication.reminderTimes.isEmpty {
                let dueTime = scheduledReminderTime(
                    medication: medication,
                    reminderIndex: nil,
                    dayStart: dayStart,
                    referenceDate: referenceDate
                )

                let wasTaken = !medicationLogs.isEmpty
                if !wasTaken,
                   nowMinute >= startOfMinute(dueTime),
                   calendar.isDate(dueTime, inSameDayAs: now) {
                    overdueCount += 1
                }
                continue
            }

            for (index, _) in medication.reminderTimes.enumerated() {
                if takenIndices.contains(index) {
                    continue
                }
                let dueTime = scheduledReminderTime(
                    medication: medication,
                    reminderIndex: index,
                    dayStart: dayStart,
                    referenceDate: referenceDate
                )
                if nowMinute >= startOfMinute(dueTime),
                   calendar.isDate(dueTime, inSameDayAs: now) {
                    overdueCount += 1
                }
            }
        }

        return overdueCount
    }

    private func updateOverdueMedicationIDs(_ overdueIDs: Set<UUID>) {
        let apply = {
            if self.overdueMedicationIDs != overdueIDs {
                self.overdueMedicationIDs = overdueIDs
            }
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    private func cancelPendingReminderIfNeeded(
        medication: Medication,
        reminderIndex: Int?,
        actualTime: Date
    ) {
        guard let scheduled = scheduledTimeForToday(
            medication: medication,
            actualTime: actualTime,
            reminderIndex: reminderIndex
        ) else { return }
        guard actualTime < scheduled else { return }

        if let reminderIndex,
           medication.notificationIDs.indices.contains(reminderIndex) {
            let baseID = medication.notificationIDs[reminderIndex]
            notificationManager.cancelReminderOccurrence(for: baseID, on: scheduled)
            return
        }

        if let baseID = medication.notificationID {
            notificationManager.cancelReminderOccurrence(for: baseID, on: scheduled)
        }
    }

    private func refreshUpcomingReminderBadges(for medication: Medication, referenceDate: Date) {
        if medication.reminderTimes.isEmpty {
            if let baseID = medication.notificationID {
                notificationManager.rescheduleReminderOccurrenceIfPending(
                    medication: medication,
                    time: medication.timeToTake,
                    baseID: baseID,
                    reminderIndex: nil,
                    referenceDate: referenceDate
                )
            }
            return
        }

        for (index, time) in medication.reminderTimes.enumerated() {
            guard medication.notificationIDs.indices.contains(index) else { continue }
            let baseID = medication.notificationIDs[index]
            notificationManager.rescheduleReminderOccurrenceIfPending(
                medication: medication,
                time: time,
                baseID: baseID,
                reminderIndex: index,
                referenceDate: referenceDate
            )
        }
    }

    private func resolveOverdueReminder(identifierPrefix: String) {
        if overdueReminderNotificationIDs.isEmpty { return }
        let updated = overdueReminderNotificationIDs.filter { !$0.hasPrefix("\(identifierPrefix)_") && $0 != identifierPrefix }
        if updated.count != overdueReminderNotificationIDs.count {
            overdueReminderNotificationIDs = Set(updated)
        }
    }

    private func refreshOverdueFromDeliveredNotifications(referenceDate: Date) {
        notificationManager.fetchDeliveredMedicationReminders { [weak self] notifications in
            guard let self else { return }
            DispatchQueue.main.async {
                let calendar = Calendar.current
                let dayStart = calendar.startOfDay(for: referenceDate)
                var overdueIDs = Set<UUID>()
                var reminderIDs = Set<String>()

                for notification in notifications {
                    guard calendar.isDate(notification.date, inSameDayAs: referenceDate) else {
                        continue
                    }
                    let userInfo = notification.request.content.userInfo
                    guard let medicationIDString = userInfo["medicationID"] as? String,
                          let medicationID = UUID(uuidString: medicationIDString),
                          let medication = self.findMedication(with: medicationID),
                          medication.frequency != "As needed" else {
                        continue
                    }

                    let reminderIndex = userInfo["reminderIndex"] as? Int
                    let medicationLogs = self.logs.filter { log in
                        log.medicationID == medication.id &&
                        log.isDoseLog &&
                        calendar.isDate(log.takenAt, inSameDayAs: referenceDate) &&
                        log.takenAt <= referenceDate
                    }
                    let takenIndices = self.resolvedTakenReminderIndices(
                        medication: medication,
                        dayStart: dayStart,
                        logs: medicationLogs
                    )

                    if let reminderIndex, takenIndices.contains(reminderIndex) {
                        continue
                    }
                    if reminderIndex == nil, !medicationLogs.isEmpty {
                        continue
                    }

                    overdueIDs.insert(medication.id)
                    reminderIDs.insert(notification.request.identifier)
                }

                if reminderIDs.isEmpty {
                    let snapshotIDs = self.overdueMedicationIDsSnapshot(referenceDate: referenceDate)
                    let snapshotCount = self.overdueReminderCountSnapshot(referenceDate: referenceDate)
                    self.overdueReminderNotificationIDs = []
                    self.updateOverdueMedicationIDs(snapshotIDs)
                    self.notificationManager.setApplicationBadge(count: snapshotCount)
                    return
                }

                self.overdueReminderNotificationIDs = reminderIDs
                self.updateOverdueMedicationIDs(overdueIDs)
                self.notificationManager.setApplicationBadge(count: reminderIDs.count)
            }
        }
    }

    private func resolvedTakenReminderIndices(
        medication: Medication,
        dayStart: Date,
        logs: [MedicationLog]
    ) -> Set<Int> {
        guard !medication.reminderTimes.isEmpty else { return [] }

        let doseLogs = logs.filter { $0.isDoseLog }
        var takenIndices = Set(doseLogs.compactMap { $0.reminderIndex })

        if medication.reminderTimes.count <= 1,
           doseLogs.contains(where: { $0.reminderIndex == nil }) {
            takenIndices.insert(0)
            return takenIndices
        }

        let calendar = Calendar.current
        let anchoredTimes: [(index: Int, time: Date)] = medication.reminderTimes.enumerated().compactMap { index, reminder in
            let components = calendar.dateComponents([.hour, .minute], from: reminder)
            guard let time = localTimeOnDay(
                calendar: calendar,
                hour: components.hour ?? 8,
                minute: components.minute ?? 0,
                dayStart: dayStart
            ) else {
                return nil
            }
            return (index, time)
        }

        let nilIndexLogs = doseLogs.filter { $0.reminderIndex == nil }.sorted { $0.takenAt < $1.takenAt }
        guard !nilIndexLogs.isEmpty, !anchoredTimes.isEmpty else {
            return takenIndices
        }

        var available = Set(anchoredTimes.map { $0.index }).subtracting(takenIndices)
        for log in nilIndexLogs {
            if available.isEmpty { break }
            let closest = anchoredTimes
                .filter { available.contains($0.index) }
                .min(by: { lhs, rhs in
                    abs(lhs.time.timeIntervalSince(log.takenAt)) < abs(rhs.time.timeIntervalSince(log.takenAt))
                })
            if let closest {
                takenIndices.insert(closest.index)
                available.remove(closest.index)
            }
        }

        return takenIndices
    }

    private func scheduledReminderTime(
        medication: Medication,
        reminderIndex: Int?,
        dayStart: Date,
        referenceDate: Date
    ) -> Date {
        let calendar = Calendar.current
        let reminderTime: Date

        if let reminderIndex,
           medication.reminderTimes.indices.contains(reminderIndex) {
            reminderTime = medication.reminderTimes[reminderIndex]
        } else {
            reminderTime = medication.timeToTake
        }

        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        var scheduled = localTimeOnDay(
            calendar: calendar,
            hour: components.hour ?? 8,
            minute: components.minute ?? 0,
            dayStart: dayStart
        ) ?? reminderTime

        if let creationDate = medication.createdAt,
           calendar.isDate(creationDate, inSameDayAs: referenceDate),
           scheduled < creationDate {
            scheduled = calendar.date(byAdding: .day, value: 1, to: scheduled) ?? scheduled
        }

        return scheduled
    }

    private func localTimeOnDay(
        calendar: Calendar,
        hour: Int,
        minute: Int,
        dayStart: Date
    ) -> Date? {
        if let exact = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) {
            return exact
        }

        guard let next = calendar.nextDate(
            after: dayStart,
            matching: DateComponents(hour: hour, minute: minute, second: 0),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ), calendar.isDate(next, inSameDayAs: dayStart) else {
            return nil
        }

        return next
    }

    private func scheduleDailyCheckInReminders(referenceDate: Date) {
        guard !isPreviewMode else { return }

        for medication in medications where medication.enableDailyCheckIn && !medication.isDeleted {
            scheduleDailyCheckInReminderIfNeeded(for: medication, referenceDate: referenceDate)
        }
    }

    private func scheduleDailyCheckInReminderIfNeeded(
        for medication: Medication,
        referenceDate: Date = Date()
    ) {
        guard !isPreviewMode else { return }
        guard shouldScheduleDailyCheckInReminder(for: medication, referenceDate: referenceDate) else {
            return
        }

        notificationManager.scheduleDailyCheckInReminder(for: medication, referenceDate: referenceDate)
    }

    func enqueuePendingCheckIns(_ checkIns: [PendingCheckIn]) {
        guard !checkIns.isEmpty else { return }

        var seenKeys = Set(pendingCheckIns.map { $0.key })
        if let dailyCheckInContext {
            seenKeys.insert(PendingCheckIn.daily(dailyCheckInContext).key)
        }

        var newItems: [PendingCheckIn] = []
        for item in checkIns {
            let key = item.key
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            newItems.append(item)
        }

        guard !newItems.isEmpty else { return }
        pendingCheckIns.append(contentsOf: newItems)
        presentNextPendingCheckInIfNeeded()
    }

    func presentNextPendingCheckInIfNeeded() {
        guard dailyCheckInContext == nil else {
            return
        }

        while !pendingCheckIns.isEmpty {
            let next = pendingCheckIns.removeFirst()
            if case .daily(let context) = next {
                guard findMedication(with: context.medication.id) != nil else { continue }
                dailyCheckInContext = context
                return
            }
        }
    }
    
    @discardableResult
    func skipMedication(
        medication: Medication,
        actualTime: Date,
        notes: String?,
        reminderIndex: Int? = nil,
        feelingRating: Int? = nil,
        focusRating: Int? = nil,
        sideEffectSeverity: Int? = nil,
        reflectionSummary: String? = nil,
        showFocusTimeline: Bool = true
    ) -> LogUndoAction? {
        return logMedicationTaken(
            medication: medication,
            actualTime: actualTime,
            notes: notes,
            skipped: true,
            reminderIndex: reminderIndex,
            feelingRating: feelingRating,
            focusRating: focusRating,
            sideEffectSeverity: sideEffectSeverity,
            reflectionSummary: reflectionSummary,
            showFocusTimeline: showFocusTimeline
        )
    }

    func undoLogAction(_ action: LogUndoAction) {
        guard let insertedIndex = logs.firstIndex(where: { $0.id == action.newLog.id }) else { return }

        logs.remove(at: insertedIndex)
        saveLogs()
        syncDeleteLog(action.newLog)

        if let replacedLog = action.replacedLog {
            let restoreIndex = min(action.replacedLogIndex ?? 0, logs.count)
            logs.insert(replacedLog, at: restoreIndex)
            saveLogs()
            syncLogWithCloud(replacedLog)
        }

        if action.pillCountDelta != 0,
           let index = medications.firstIndex(where: { $0.id == action.newLog.medicationID }),
           var pillCount = medications[index].pillCount {
            pillCount = max(0, pillCount - action.pillCountDelta)
            medications[index].pillCount = pillCount
            medications[index].updatedAt = Date()
            saveMedications()
            syncMedicationWithCloud(medications[index])
        }

        resetBadgeIfNeeded()
    }

    func removeDoseLog(_ log: MedicationLog) {
        guard log.isDoseLog else { return }

        deleteLog(log)

        if !log.skipped,
           !log.isDailyCheckIn,
           let index = medications.firstIndex(where: { $0.id == log.medicationID }),
           var updatedMedication = medications[index] as Medication?,
           var pillCount = updatedMedication.pillCount {
            let pillsToRestore = log.pillsConsumed ?? updatedMedication.pillsPerDose
            if pillsToRestore > 0 {
                pillCount += pillsToRestore
                updatedMedication.pillCount = pillCount
                updatedMedication.updatedAt = Date()
                medications[index] = updatedMedication
                saveMedications()
                syncMedicationWithCloud(updatedMedication)
            }
        }

        resetBadgeIfNeeded()
    }
    
    func toggleSkipStatus(for medicationID: UUID) {
        if let index = medications.firstIndex(where: { $0.id == medicationID }) {
            var updatedMedication = medications[index]
            updatedMedication.isSkipped.toggle()
            updatedMedication.updatedAt = Date()
            medications[index] = updatedMedication
            saveMedications()
            syncMedicationWithCloud(updatedMedication)
        }
    }
    
    func getRemainingPillCount(for medicationID: UUID) -> Int? {
        return medications.first(where: { $0.id == medicationID })?.pillCount
    }
    
    func needsRefill(medicationID: UUID) -> Bool {
        guard let medication = medications.first(where: { $0.id == medicationID }),
              let pillCount = medication.pillCount,
              let refillThreshold = medication.refillThreshold else {
            return false
        }
        
        return pillCount <= refillThreshold
    }

    func deleteMedication(at offsets: IndexSet) {
        let medicationsToDelete = offsets.compactMap { medications.indices.contains($0) ? medications[$0] : nil }
        for medication in medicationsToDelete {
            prepareMedicationForDeletion(medication)
            if let index = medications.firstIndex(where: { $0.id == medication.id }) {
                medications[index].isDeleted = true
                medications[index].updatedAt = Date()
                deletedMedicationIDs.insert(medications[index].id)
                persistDeletedMedicationIDs()
                syncMedicationWithCloud(medications[index])
            }
        }
        saveMedications()
    }

    func deleteMedication(_ medication: Medication) {
        guard let index = medications.firstIndex(where: { $0.id == medication.id }) else { return }
        prepareMedicationForDeletion(medication)
        medications[index].isDeleted = true
        medications[index].updatedAt = Date()
        deletedMedicationIDs.insert(medications[index].id)
        persistDeletedMedicationIDs()
        syncMedicationWithCloud(medications[index])
        saveMedications()
    }

    private func prepareMedicationForDeletion(_ medication: Medication) {
        notificationManager.unregisterTrackedMedicationID(medication.id)
        clearReminderState(for: medication)

        if let notificationID = medication.notificationID {
            notificationManager.cancelNotification(with: notificationID)
        }

        if !medication.notificationIDs.isEmpty {
            notificationManager.cancelMultipleNotifications(ids: medication.notificationIDs)
        }
        notificationManager.cancelMedicationNotifications(for: medication.id)
    }

    private func clearReminderState(for medication: Medication) {
        if dailyCheckInContext?.medication.id == medication.id {
            dailyCheckInContext = nil
        }
        if highlightedMedicationID == medication.id {
            highlightedMedicationID = nil
        }
        if notificationHighlightMedicationID == medication.id {
            notificationHighlightMedicationID = nil
        }
        if recentADHDDoseTimeline?.medication.id == medication.id {
            recentADHDDoseTimeline = nil
        }
    }
    
    func deleteLog(at offsets: IndexSet) {
        let logsToRemove = offsets.compactMap { index in logs[index] }
        logs.remove(atOffsets: offsets)
        saveLogs()
        for log in logsToRemove {
            syncDeleteLog(log)
        }
    }

    func deleteLog(_ log: MedicationLog) {
        guard let index = logs.firstIndex(where: { $0.id == log.id }) else { return }
        logs.remove(at: index)
        saveLogs()
        syncDeleteLog(log)
    }

    func updateLogDate(_ log: MedicationLog, newDate: Date) {
        guard let index = logs.firstIndex(where: { $0.id == log.id }) else { return }
        var updatedLog = logs[index]
        updatedLog.takenAt = newDate
        updatedLog.updatedAt = Date()
        logs[index] = updatedLog
        saveLogs()
        syncLogWithCloud(updatedLog)
    }

    func hideLogFromMyMeds(_ log: MedicationLog) {
        guard let index = logs.firstIndex(where: { $0.id == log.id }) else { return }
        var updatedLog = logs[index]
        guard !updatedLog.hiddenFromMyMeds else { return }
        updatedLog.hiddenFromMyMeds = true
        updatedLog.updatedAt = Date()
        logs[index] = updatedLog
        saveLogs()
        syncLogWithCloud(updatedLog)
    }

    private func preservedReminderIdentifiers(
        for medication: Medication,
        excludingReminderIndex excludedIndex: Int?,
        excludeSingleReminder: Bool
    ) -> Set<String> {
        var identifiers: Set<String> = []

        if !excludeSingleReminder, let singleID = medication.notificationID?.uuidString {
            identifiers.insert(singleID)
            identifiers.insert("\(singleID)_followup")
        }

        if !medication.notificationIDs.isEmpty {
            for (index, uuid) in medication.notificationIDs.enumerated() {
                if let excludedIndex, excludedIndex == index { continue }
                let idString = uuid.uuidString
                identifiers.insert(idString)
                identifiers.insert("\(idString)_followup")
            }
        }

        return identifiers
    }

    private func clearNotificationsForLoggedDose(
        medication: Medication,
        storedMedication: Medication?,
        actualTime: Date,
        reminderIndex: Int?,
        isDailyCheckIn: Bool
    ) {
        // Clear the delivered notification and cancel any follow-up for today without touching future reminders.
        let followUpBaseTime = scheduledTimeForToday(
            medication: medication,
            actualTime: actualTime,
            reminderIndex: reminderIndex
        ) ?? actualTime
        let followUpCancelDate = Calendar.current.date(byAdding: .minute, value: 30, to: followUpBaseTime) ?? actualTime

        if let specificIndex = reminderIndex,
           let referenceMedication = storedMedication,
           !referenceMedication.notificationIDs.isEmpty,
           specificIndex < referenceMedication.notificationIDs.count {
            let notificationID = referenceMedication.notificationIDs[specificIndex]
            notificationManager.cancelFollowUpNotification(for: notificationID, on: followUpCancelDate)
            notificationManager.clearDeliveredNotifications(for: notificationID)
            resolveOverdueReminder(identifierPrefix: notificationID.uuidString)
            cancelPendingReminderIfNeeded(
                medication: referenceMedication,
                reminderIndex: specificIndex,
                actualTime: actualTime
            )
            refreshUpcomingReminderBadges(for: referenceMedication, referenceDate: actualTime)
        } else if let notificationID = storedMedication?.notificationID ?? medication.notificationID {
            notificationManager.cancelFollowUpNotification(for: notificationID, on: followUpCancelDate)
            notificationManager.clearDeliveredNotifications(for: notificationID)
            resolveOverdueReminder(identifierPrefix: notificationID.uuidString)
            cancelPendingReminderIfNeeded(
                medication: storedMedication ?? medication,
                reminderIndex: nil,
                actualTime: actualTime
            )
            refreshUpcomingReminderBadges(for: storedMedication ?? medication, referenceDate: actualTime)
        }

        let identifiersToKeep = preservedReminderIdentifiers(
            for: medication,
            excludingReminderIndex: nil,
            excludeSingleReminder: false
        )
        notificationManager.removeUntrackedMedicationReminders(
            for: medication.id,
            preservingIdentifiers: identifiersToKeep
        )

        // Recompute overdue state from source-of-truth logs immediately.
        // This prevents stale delivered-reminder cache from keeping a medication
        // marked as overdue right after it was logged from a notification action.
        synchronizeOverdueStateAfterDoseLog(referenceDate: actualTime)

        if isDailyCheckIn {
            notificationManager.cancelDailyCheckInNotification(for: medication.id, on: actualTime)
        }
    }

    private func synchronizeOverdueStateAfterDoseLog(referenceDate: Date) {
        recomputeOverdueStateFromSnapshots(referenceDate: referenceDate)
    }

    private func inferReminderIndexIfNeeded(
        for medication: Medication,
        actualTime: Date
    ) -> Int? {
        guard !medication.reminderTimes.isEmpty else { return nil }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: actualTime)

        let todaysTimes: [(index: Int, time: Date)] = medication.reminderTimes.enumerated().compactMap { index, reminder in
            let components = calendar.dateComponents([.hour, .minute], from: reminder)
            guard let date = localTimeOnDay(
                calendar: calendar,
                hour: components.hour ?? 8,
                minute: components.minute ?? 0,
                dayStart: dayStart
            ) else {
                return nil
            }
            return (index, date)
        }

        guard !todaysTimes.isEmpty else { return nil }

        let todaysLogs = logs.filter {
            $0.medicationID == medication.id &&
            $0.isDoseLog &&
            calendar.isDate($0.takenAt, inSameDayAs: actualTime)
        }

        var takenIndices = Set(todaysLogs.compactMap { $0.reminderIndex })
        if medication.reminderTimes.count <= 1,
           todaysLogs.contains(where: { $0.reminderIndex == nil }) {
            takenIndices.insert(0)
        }

        let available = todaysTimes.filter { !takenIndices.contains($0.index) }
        let candidates = available.isEmpty ? todaysTimes : available

        return candidates.min(by: { lhs, rhs in
            abs(lhs.time.timeIntervalSince(actualTime)) < abs(rhs.time.timeIntervalSince(actualTime))
        })?.index
    }

    private func scheduledTimeForToday(
        medication: Medication,
        actualTime: Date,
        reminderIndex: Int?
    ) -> Date? {
        // For ADHD medications that are explicitly "As needed" without reminders,
        // we treat doses as ad-hoc and do not surface a scheduled time. This keeps
        // the copy in the focus timeline sheet aligned with how the user configured it.
        if medication.frequency == "As needed" && medication.reminderTimes.isEmpty {
            return nil
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: actualTime)

        // Build candidate times for today from reminderTimes if present
        if !medication.reminderTimes.isEmpty {
            let baseTimes: [Date] = medication.reminderTimes.compactMap { raw in
                let components = calendar.dateComponents([.hour, .minute], from: raw)
                return localTimeOnDay(
                    calendar: calendar,
                    hour: components.hour ?? 8,
                    minute: components.minute ?? 0,
                    dayStart: dayStart
                )
            }

            guard !baseTimes.isEmpty else { return nil }

            if let index = reminderIndex,
               index >= 0,
               index < baseTimes.count {
                return baseTimes[index]
            }

            // Fallback: nearest scheduled time to when the dose was actually logged
            return baseTimes.min(by: { lhs, rhs in
                abs(lhs.timeIntervalSince(actualTime)) < abs(rhs.timeIntervalSince(actualTime))
            })
        } else {
            // Legacy single-time medications: anchor timeToTake to today
            let components = calendar.dateComponents([.hour, .minute], from: medication.timeToTake)
            return localTimeOnDay(
                calendar: calendar,
                hour: components.hour ?? 8,
                minute: components.minute ?? 0,
                dayStart: dayStart
            )
        }
    }
    
    private func applyDailyCheckInUpdates(
        at index: Int,
        notes: String?,
        feelingRating: Int?,
        focusRating: Int?,
        sideEffectSeverity: Int?,
        reflectionSummary: String?
    ) {
        var logEntry = logs[index]
        logEntry.isDailyCheckIn = true
        logEntry.updatedAt = Date()
        if let mergedNotes = mergeNotes(existing: logEntry.notes, with: notes) {
            logEntry.notes = mergedNotes
        }
        if let feelingRating {
            logEntry.feelingRating = feelingRating
        }
        if let focusRating {
            logEntry.focusRating = focusRating
        }
        if let sideEffectSeverity {
            logEntry.sideEffectSeverity = sideEffectSeverity
        }
        if let reflectionSummary {
            logEntry.reflectionSummary = reflectionSummary
        }
        logs[index] = logEntry
        saveLogs()
        syncLogWithCloud(logEntry)
        hapticManager.successNotification()
    }

    func isDailyCheckInOverdue(for medication: Medication, referenceDate: Date = Date()) -> Bool {
        guard medication.enableDailyCheckIn else { return false }
        guard let triggerDate = dailyCheckInTriggerDate(for: medication, referenceDate: referenceDate) else {
            return false
        }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        guard triggerDate >= dayStart, triggerDate < dayEnd else { return false }
        guard referenceDate >= triggerDate else { return false }
        if isStandaloneDailyCheckIn(medication),
           !hasTakenDoseBeforeCheckInTime(for: medication, triggerDate: triggerDate, referenceDate: referenceDate) {
            return false
        }
        return !hasCompletedDailyCheckIn(for: medication, referenceDate: referenceDate)
    }

    private func dailyCheckInTriggerDate(for medication: Medication, referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)

        if let customCheckInTime = medication.dailyCheckInTime {
            let components = calendar.dateComponents([.hour, .minute], from: customCheckInTime)
            guard let hour = components.hour,
                  let minute = components.minute,
                  let triggerDate = localTimeOnDay(
                    calendar: calendar,
                    hour: hour,
                    minute: minute,
                    dayStart: dayStart
                  ) else {
                return nil
            }

            if let createdAt = medication.createdAt,
               calendar.isDate(createdAt, inSameDayAs: referenceDate),
               triggerDate < createdAt {
                return nil
            }
            return triggerDate
        }

        if isStimulantPhaseDailyCheckIn(medication),
           medication.hasStimulantTiming,
           let durationMinutes = medication.durationMinutes {
            let medicationID = medication.logIdentifier
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
                  let previousDayStart = calendar.date(byAdding: .day, value: -1, to: dayStart) else {
                return nil
            }

            let candidateLogs = logs.filter { log in
                log.medicationID == medicationID &&
                log.isDoseLog &&
                !log.skipped &&
                log.takenAt >= previousDayStart &&
                log.takenAt < dayEnd
            }

            let triggerDates = candidateLogs.compactMap { log in
                calendar.date(byAdding: .minute, value: durationMinutes, to: log.takenAt)
            }.filter { triggerDate in
                triggerDate >= dayStart && triggerDate < dayEnd
            }

            return triggerDates.min()
        }

        guard shouldUseDefaultDailyCheckInTime(for: medication),
              let triggerDate = localTimeOnDay(
                calendar: calendar,
                hour: 19,
                minute: 0,
                dayStart: dayStart
              ) else {
            return nil
        }

        if let createdAt = medication.createdAt,
           calendar.isDate(createdAt, inSameDayAs: referenceDate),
           triggerDate < createdAt {
            return nil
        }

        return triggerDate
    }

    private func hasCompletedDailyCheckIn(for medication: Medication, referenceDate: Date) -> Bool {
        let calendar = Calendar.current
        let medicationID = medication.logIdentifier
        return logs.contains { log in
            log.medicationID == medicationID &&
            calendar.isDate(log.takenAt, inSameDayAs: referenceDate) &&
            isDailyCheckInLog(log)
        }
    }

    private func isDailyCheckInLog(_ log: MedicationLog) -> Bool {
        if log.isDailyCheckIn {
            return true
        }
        if log.feelingRating != nil || log.focusRating != nil || log.sideEffectSeverity != nil {
            return true
        }
        if let notes = log.notes,
           notes.range(of: "Side effects:", options: [.caseInsensitive]) != nil {
            return true
        }
        return false
    }

    private func shouldScheduleDailyCheckInReminder(for medication: Medication, referenceDate: Date) -> Bool {
        guard medication.enableDailyCheckIn,
              isStandaloneDailyCheckIn(medication),
              let triggerDate = dailyCheckInTriggerDate(for: medication, referenceDate: referenceDate) else {
            return false
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        guard triggerDate >= dayStart, triggerDate < dayEnd else { return false }
        guard referenceDate <= triggerDate else { return false }
        return hasTakenDoseBeforeCheckInTime(for: medication, triggerDate: triggerDate, referenceDate: referenceDate)
    }

    private func hasTakenDoseBeforeCheckInTime(
        for medication: Medication,
        triggerDate: Date,
        referenceDate: Date
    ) -> Bool {
        let calendar = Calendar.current
        let medicationID = medication.logIdentifier
        return logs.contains { log in
            log.medicationID == medicationID &&
            log.isDoseLog &&
            !log.skipped &&
            calendar.isDate(log.takenAt, inSameDayAs: referenceDate) &&
            log.takenAt <= triggerDate
        }
    }

    private func shouldUseDefaultDailyCheckInTime(for medication: Medication) -> Bool {
        medication.enableDailyCheckIn && medication.dailyCheckInTime == nil && !isStimulantPhaseDailyCheckIn(medication)
    }

    private func isStandaloneDailyCheckIn(_ medication: Medication) -> Bool {
        medication.dailyCheckInTime != nil || !isStimulantPhaseDailyCheckIn(medication)
    }

    private func isStimulantPhaseDailyCheckIn(_ medication: Medication) -> Bool {
        medication.enableStimulantPhaseNotifications && medication.medicationType == .stimulant && medication.dailyCheckInTime == nil
    }


    private func mergeNotes(existing: String?, with newNotes: String?) -> String? {
        let trimmedExisting = existing?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNew = newNotes?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedExisting, !trimmedExisting.isEmpty {
            if let trimmedNew, !trimmedNew.isEmpty {
                return "\(trimmedExisting)\n\n\(trimmedNew)"
            }
            return trimmedExisting
        }

        if let trimmedNew, !trimmedNew.isEmpty {
            return trimmedNew
        }

        return nil
    }

    // Helper function to update medication names in existing logs
    private func updateMedicationNameInLogs(medicationID: UUID, newName: String) {
        var updatedLogs: [MedicationLog] = []
        for index in logs.indices {
            if logs[index].medicationID == medicationID {
                logs[index].medicationName = newName
                logs[index].updatedAt = Date()
                updatedLogs.append(logs[index])
            }
        }
        saveLogs()
        for log in updatedLogs {
            syncLogWithCloud(log)
        }
    }

    // --- Local Device Persistence ---
    // All data is stored locally on the user's device using iOS UserDefaults
    // No data is transmitted to external servers or cloud services
    // Data persists between app launches and is ONLY deleted when the app is uninstalled completely
    public func saveMedications() {
        if let encoded = try? JSONEncoder().encode(medications) {
            if let existing = UserDefaults.standard.data(forKey: medicationsKey) {
                UserDefaults.standard.set(existing, forKey: medicationsBackupKey)
            }
            UserDefaults.standard.set(encoded, forKey: medicationsKey)
        }
        let currentIDs = Set(medications.filter { !$0.isDeleted }.map { $0.id })
        notificationManager.updateTrackedMedicationIDs(currentIDs)
    }

    public func loadMedications() {
        if let savedMedications = UserDefaults.standard.data(forKey: medicationsKey) {
            if let decodedMedications = try? JSONDecoder().decode([Medication].self, from: savedMedications) {
                self.medications = decodedMedications.map { medication in
                    if deletedMedicationIDs.contains(medication.id) {
                        var updated = medication
                        updated.isDeleted = true
                        return updated
                    }
                    return medication
                }

                let activeMedicationIDs = Set(self.medications.filter { !$0.isDeleted }.map { $0.id })
                notificationManager.updateTrackedMedicationIDs(activeMedicationIDs)
                notificationManager.purgeNotifications(excluding: activeMedicationIDs)
                
                // Reschedule notifications on app launch (in case app was terminated)
                for index in medications.indices {
                    if !medications[index].isDeleted {
                        medications[index] = refreshNotificationSchedule(for: medications[index])
                    }
                }
                saveMedications()
                scheduleDailyCheckInReminders(referenceDate: Date())
                lastNotificationResetDay = Calendar.current.startOfDay(for: Date())
                
                // Update badge on app launch if needed
                resetBadgeIfNeeded()
                refreshOverdueMedicationIDs(referenceDate: Date())
                reconcileNotificationSchedules(referenceDate: Date())
                
                return
            }
        }
        if let backupMedications = UserDefaults.standard.data(forKey: medicationsBackupKey),
           let decodedMedications = try? JSONDecoder().decode([Medication].self, from: backupMedications) {
            self.medications = decodedMedications.map { medication in
                if deletedMedicationIDs.contains(medication.id) {
                    var updated = medication
                    updated.isDeleted = true
                    return updated
                }
                return medication
            }

            let activeMedicationIDs = Set(self.medications.filter { !$0.isDeleted }.map { $0.id })
            notificationManager.updateTrackedMedicationIDs(activeMedicationIDs)
            notificationManager.purgeNotifications(excluding: activeMedicationIDs)

            for index in medications.indices {
                if !medications[index].isDeleted {
                    medications[index] = refreshNotificationSchedule(for: medications[index])
                }
            }
            saveMedications()
            scheduleDailyCheckInReminders(referenceDate: Date())
            lastNotificationResetDay = Calendar.current.startOfDay(for: Date())
            resetBadgeIfNeeded()
            refreshOverdueMedicationIDs(referenceDate: Date())
            reconcileNotificationSchedules(referenceDate: Date())
            return
        }
        self.medications = []
        notificationManager.updateTrackedMedicationIDs([])
        refreshOverdueMedicationIDs(referenceDate: Date())
    }

    public func loadLogs() {
        if let savedLogs = UserDefaults.standard.data(forKey: logsKey) {
            if let decodedLogs = try? JSONDecoder().decode([MedicationLog].self, from: savedLogs) {
                self.logs = decodedLogs.filter { !$0.isDeleted }
                scheduleDailyCheckInReminders(referenceDate: Date())
                refreshOverdueMedicationIDs(referenceDate: Date())
                return
            }
        }
        if let backupLogs = UserDefaults.standard.data(forKey: logsBackupKey),
           let decodedLogs = try? JSONDecoder().decode([MedicationLog].self, from: backupLogs) {
            self.logs = decodedLogs.filter { !$0.isDeleted }
            scheduleDailyCheckInReminders(referenceDate: Date())
            refreshOverdueMedicationIDs(referenceDate: Date())
            return
        }
        self.logs = []
        scheduleDailyCheckInReminders(referenceDate: Date())
        refreshOverdueMedicationIDs(referenceDate: Date())
    }

    private func runLegacyLogMedicationIDRepair(
        markCompleteWhenNoChanges: Bool,
        allowInPreview: Bool = false
    ) {
        if isPreviewMode && !allowInPreview {
            return
        }
        if !allowInPreview,
           UserDefaults.standard.bool(forKey: legacyLogMedicationIDRepairV1Key) {
            return
        }

        let validMedicationIDs = Set(medications.map { $0.id })
        guard !logs.isEmpty else {
            if markCompleteWhenNoChanges && !allowInPreview {
                UserDefaults.standard.set(true, forKey: legacyLogMedicationIDRepairV1Key)
            }
            return
        }

        let logsByID = Dictionary(uniqueKeysWithValues: logs.map { ($0.id, $0) })
        var repaired = false
        var repairedLogs: [MedicationLog] = []

        for index in logs.indices {
            let current = logs[index]
            if validMedicationIDs.contains(current.medicationID) {
                continue
            }

            guard let sourceLog = logsByID[current.medicationID] else {
                continue
            }
            let correctedMedicationID = sourceLog.medicationID
            guard correctedMedicationID != current.medicationID,
                  validMedicationIDs.contains(correctedMedicationID) else {
                continue
            }

            logs[index].medicationID = correctedMedicationID
            logs[index].updatedAt = Date()
            repairedLogs.append(logs[index])
            repaired = true
        }

        if repaired {
            saveLogs()
            for log in repairedLogs {
                syncLogWithCloud(log)
            }
            resetBadgeIfNeeded()
            refreshOverdueMedicationIDs(referenceDate: Date())
            if !allowInPreview {
                UserDefaults.standard.set(true, forKey: legacyLogMedicationIDRepairV1Key)
            }
            return
        }

        if markCompleteWhenNoChanges && !allowInPreview {
            UserDefaults.standard.set(true, forKey: legacyLogMedicationIDRepairV1Key)
        }
    }

    private func startObservingDayChanges() {
        guard dayChangeObserver == nil else { return }

        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.performDailyResetIfNeeded()
            }
        }

        appActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.performDailyResetIfNeeded()
                self?.reconcileNotificationSchedules(referenceDate: Date())
            }
        }
    }

    private func observeCloudSyncPreference() {
        cloudSyncPreferenceCancellable = UserSettings.shared.$shouldUseCloudSync
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleCloudSyncPreferenceChange()
            }
    }

    private func handleCloudSyncPreferenceChange() {
        let enabled = shouldUseCloudSync
        if enabled && !lastCloudSyncPreferenceState {
            cloudSync.ensureSubscriptions()
            performInitialCloudSync()
        } else if !enabled {
            cloudSyncOperationCount = 0
            isCloudSyncInProgress = false
        }
        lastCloudSyncPreferenceState = enabled
    }

    private func beginCloudSyncOperation() {
        guard shouldUseCloudSync else { return }
        cloudSyncOperationCount += 1
        isCloudSyncInProgress = cloudSyncOperationCount > 0
    }

    private func endCloudSyncOperation() {
        guard cloudSyncOperationCount > 0 else {
            isCloudSyncInProgress = false
            return
        }
        cloudSyncOperationCount -= 1
        isCloudSyncInProgress = cloudSyncOperationCount > 0
    }

    private func performDailyResetIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        guard today > lastNotificationResetDay else { return }
        lastNotificationResetDay = today
        resetNotificationsForNewDay()
        overdueReminderNotificationIDs = []
        notificationManager.clearDeliveredMedicationReminders()
        resetBadgeIfNeeded()
    }

    private func resetNotificationsForNewDay() {
        guard !isPreviewMode else { return }
        var updatedMedications = medications
        var didReschedule = false

        for index in updatedMedications.indices {
            let medication = updatedMedications[index]
            if medication.isDeleted { continue }
            guard medication.hasActiveReminder else { continue }
            updatedMedications[index] = refreshNotificationSchedule(for: medication)
            didReschedule = true
        }

        if didReschedule {
            medications = updatedMedications
            saveMedications()
        }

        scheduleDailyCheckInReminders(referenceDate: Date())
    }

    private func refreshNotificationSchedule(for medication: Medication) -> Medication {
        guard medication.hasActiveReminder else { return medication }
        var updatedMedication = medication

        if let notificationID = medication.notificationID {
            notificationManager.cancelNotification(with: notificationID)
        }

        if !medication.notificationIDs.isEmpty {
            notificationManager.cancelMultipleNotifications(ids: medication.notificationIDs)
        }

            notificationManager.cancelMedicationNotifications(for: medication.id)

        if !updatedMedication.reminderTimes.isEmpty {
            let notificationIDs = notificationManager.scheduleMultipleNotifications(for: updatedMedication)
            updatedMedication.notificationIDs = notificationIDs
            updatedMedication.notificationID = nil
        } else if updatedMedication.isOneTimeWithFollowUp {
            updatedMedication.notificationID = notificationManager.scheduleNotification(for: updatedMedication)
            updatedMedication.notificationIDs = []
        } else if updatedMedication.notificationID != nil {
            updatedMedication.notificationID = notificationManager.scheduleNotification(for: updatedMedication)
            updatedMedication.notificationIDs = []
        }

        var identifiersToKeep = Set<String>()
        if let notificationID = updatedMedication.notificationID {
            identifiersToKeep.insert(notificationID.uuidString)
        }
        if !updatedMedication.notificationIDs.isEmpty {
            identifiersToKeep.formUnion(updatedMedication.notificationIDs.map { $0.uuidString })
        }
        if !identifiersToKeep.isEmpty {
            notificationManager.removeUntrackedMedicationReminders(
                for: updatedMedication.id,
                preservingIdentifiers: identifiersToKeep
            )
        }

        return updatedMedication
    }

    func reconcileNotificationSchedules(referenceDate: Date = Date()) {
        guard !isPreviewMode else { return }
        let active = activeMedications.filter { $0.hasActiveReminder }
        guard !active.isEmpty else { return }

        notificationManager.fetchPendingMedicationReminders { [weak self] requests in
            guard let self else { return }
            DispatchQueue.main.async {
                self.reconcileNotificationSchedules(
                    withPendingRequests: requests,
                    referenceDate: referenceDate
                )
            }
        }
    }

    private func reconcileNotificationSchedules(
        withPendingRequests requests: [UNNotificationRequest],
        referenceDate: Date
    ) {
        var pendingIDs = Set(requests.map { $0.identifier })
        var didRepair = false
        var repairsApplied = 0

        for medication in activeMedications where medication.hasActiveReminder {
            if medication.reminderTimes.isEmpty {
                guard let baseID = medication.notificationID else { continue }
                guard let scheduled = scheduledTimeForToday(
                    medication: medication,
                    actualTime: referenceDate,
                    reminderIndex: nil
                ), scheduled > referenceDate else {
                    continue
                }
                let dayID = reminderIdentifier(baseID: baseID, fireDate: scheduled)
                if !pendingIDs.contains(dayID) {
                    notificationManager.rescheduleReminderOccurrenceIfPending(
                        medication: medication,
                        time: medication.timeToTake,
                        baseID: baseID,
                        reminderIndex: nil,
                        referenceDate: referenceDate
                    )
                    didRepair = true
                    repairsApplied += 1
                    pendingIDs.insert(dayID)
                }
                continue
            }

            for (index, time) in medication.reminderTimes.enumerated() {
                guard medication.notificationIDs.indices.contains(index) else { continue }
                let baseID = medication.notificationIDs[index]
                guard let scheduled = scheduledTimeForToday(
                    medication: medication,
                    actualTime: referenceDate,
                    reminderIndex: index
                ), scheduled > referenceDate else {
                    continue
                }
                let dayID = reminderIdentifier(baseID: baseID, fireDate: scheduled)
                if pendingIDs.contains(dayID) { continue }
                notificationManager.rescheduleReminderOccurrenceIfPending(
                    medication: medication,
                    time: time,
                    baseID: baseID,
                    reminderIndex: index,
                    referenceDate: referenceDate
                )
                didRepair = true
                repairsApplied += 1
                pendingIDs.insert(dayID)
            }
        }

        let healthCheckRepairs = runReminderHealthCheck(
            pendingIDs: &pendingIDs,
            referenceDate: referenceDate
        )
        if healthCheckRepairs > 0 {
            didRepair = true
            repairsApplied += healthCheckRepairs
            recordNotificationReliabilityMetric("health_check_repair_applied", amount: healthCheckRepairs)
        }

        if didRepair {
            recordNotificationReliabilityMetric("repair_applied", amount: repairsApplied)
            resetBadgeIfNeeded()
        }
    }

    private func runReminderHealthCheck(
        pendingIDs: inout Set<String>,
        referenceDate: Date
    ) -> Int {
        var repairsApplied = 0

        for medication in activeMedications where medication.hasActiveReminder {
            if medication.reminderTimes.isEmpty {
                guard let baseID = medication.notificationID else { continue }
                guard let nextFireDate = nextReminderFireDate(for: medication.timeToTake, after: referenceDate) else { continue }
                let expectedID = reminderIdentifier(baseID: baseID, fireDate: nextFireDate)
                guard !pendingIDs.contains(expectedID) else { continue }

                notificationManager.rescheduleReminderOccurrenceIfPending(
                    medication: medication,
                    time: medication.timeToTake,
                    baseID: baseID,
                    reminderIndex: nil,
                    referenceDate: referenceDate
                )
                pendingIDs.insert(expectedID)
                repairsApplied += 1
                continue
            }

            for (index, time) in medication.reminderTimes.enumerated() {
                guard medication.notificationIDs.indices.contains(index) else { continue }
                let baseID = medication.notificationIDs[index]
                guard let nextFireDate = nextReminderFireDate(for: time, after: referenceDate) else { continue }
                let expectedID = reminderIdentifier(baseID: baseID, fireDate: nextFireDate)
                guard !pendingIDs.contains(expectedID) else { continue }

                notificationManager.rescheduleReminderOccurrenceIfPending(
                    medication: medication,
                    time: time,
                    baseID: baseID,
                    reminderIndex: index,
                    referenceDate: referenceDate
                )
                pendingIDs.insert(expectedID)
                repairsApplied += 1
            }
        }

        return repairsApplied
    }

    private func nextReminderFireDate(for time: Date, after referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.nextDate(
            after: referenceDate,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    private func recordNotificationReliabilityMetric(_ metric: String, amount: Int = 1) {
        let key = "notification_reliability_store_\(metric)"
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + amount, forKey: key)
    }

    private func reminderIdentifier(baseID: UUID, fireDate: Date) -> String {
        let components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: fireDate)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let dateString = String(format: "%04d%02d%02d", year, month, day)
        return "\(baseID.uuidString)_day_\(dateString)"
    }

    private func saveLogs() {
        // Save medication logs locally on device only
        // This data persists until the app is completely uninstalled from the device
        if let encoded = try? JSONEncoder().encode(logs) {
            if let existing = UserDefaults.standard.data(forKey: logsKey) {
                UserDefaults.standard.set(existing, forKey: logsBackupKey)
            }
            UserDefaults.standard.set(encoded, forKey: logsKey)
        }
    }
    
    private func fetchCloudData(completion: ((UIBackgroundFetchResult) -> Void)? = nil) {
        guard shouldUseCloudSync else { return }
        beginCloudSyncOperation()
        cloudSync.fetchAllRecords { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                defer { self.endCloudSyncOperation() }
                switch result {
                case let .success(payload):
                    self.mergeCloudMedications(payload.medications, allowSnapshotDeletion: true)
                    self.mergeCloudLogs(payload.logs)
                    self.runLegacyLogMedicationIDRepair(markCompleteWhenNoChanges: true)
                    self.lastCloudSyncDate = Date()
                    completion?(.newData)
                case let .failure(error):
                    print("CloudKit fetch failed: \(error)")
                    completion?(.failed)
                }
            }
        }
    }

    private func syncMedicationWithCloud(_ medication: Medication) {
        guard shouldUseCloudSync else { return }
        beginCloudSyncOperation()
        cloudSync.save(medication: medication) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                defer { self.endCloudSyncOperation() }
                switch result {
                case let .success(record):
                    if let modificationDate = record.modificationDate {
                        self.updateCloudLastModified(for: medication.id, date: modificationDate)
                    }
                    self.lastCloudSyncDate = Date()
                case let .failure(error):
                    print("CloudKit medication save failed: \(error)")
                }
            }
        }
    }

    private func syncLogWithCloud(_ log: MedicationLog) {
        guard shouldUseCloudSync else { return }
        guard let medication = medications.first(where: { $0.id == log.medicationID }) else { return }
        beginCloudSyncOperation()
        cloudSync.save(log: log, medication: medication) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                defer { self.endCloudSyncOperation() }
                if case let .failure(error) = result {
                    print("CloudKit log save failed: \(error)")
                } else {
                    self.lastCloudSyncDate = Date()
                }
            }
        }
    }

    private func syncDeleteMedication(_ medication: Medication) {
        guard shouldUseCloudSync else { return }
        var tombstone = medication
        tombstone.isDeleted = true
        tombstone.updatedAt = Date()
        deletedMedicationIDs.insert(tombstone.id)
        persistDeletedMedicationIDs()
        beginCloudSyncOperation()
        cloudSync.markMedicationDeleted(tombstone) { result in
            DispatchQueue.main.async {
                defer { self.endCloudSyncOperation() }
                if case let .failure(error) = result {
                    print("CloudKit medication delete failed: \(error)")
                }
            }
        }
    }

    private func syncDeleteLog(_ log: MedicationLog) {
        guard shouldUseCloudSync else { return }
        var tombstone = log
        tombstone.isDeleted = true
        tombstone.updatedAt = Date()
        beginCloudSyncOperation()
        cloudSync.markLogDeleted(tombstone) { result in
            DispatchQueue.main.async {
                defer { self.endCloudSyncOperation() }
                if case let .failure(error) = result {
                    print("CloudKit log delete failed: \(error)")
                }
            }
        }
    }

    private func updateCloudLastModified(for medicationID: UUID, date: Date) {
        guard shouldUseCloudSync else { return }
        if let index = medications.firstIndex(where: { $0.id == medicationID }) {
            var medication = medications[index]
            medication.cloudLastModified = date
            medications[index] = medication
            saveMedications()
            lastCloudSyncDate = Date()
        }
    }

    private func mergeCloudMedications(_ remote: [Medication]) {
        mergeCloudMedications(remote, allowSnapshotDeletion: true)
    }

    private func mergeCloudMedications(_ remote: [Medication], allowSnapshotDeletion: Bool) {
        guard !remote.isEmpty else { return }
        DispatchQueue.main.async {
            var updated = self.medications
            var hasChanges = false
            let deletedIDs = self.deletedMedicationIDs
            let remoteIDs = Set(remote.map { $0.id })

            // CloudKit is the source of truth when sync is enabled.
            // Remove any local medications that are missing from the remote snapshot.
            if self.shouldUseCloudSync && allowSnapshotDeletion {
                let missingLocals = updated.filter { !remoteIDs.contains($0.id) }
                if !missingLocals.isEmpty {
                    for medication in missingLocals {
                        self.notificationManager.cancelMedicationNotifications(for: medication.id)
                        self.notificationManager.unregisterTrackedMedicationID(medication.id)
                        self.clearReminderState(for: medication)
                        self.deletedMedicationIDs.insert(medication.id)
                    }
                    self.persistDeletedMedicationIDs()
                    updated.removeAll { !remoteIDs.contains($0.id) }
                    hasChanges = true
                }
            }

            for remoteMedication in remote {
                if remoteMedication.isDeleted {
                    if let index = updated.firstIndex(where: { $0.id == remoteMedication.id }) {
                        let toRemove = updated[index]
                        self.notificationManager.cancelMedicationNotifications(for: toRemove.id)
                        self.notificationManager.unregisterTrackedMedicationID(toRemove.id)
                        self.clearReminderState(for: toRemove)
                        updated.remove(at: index)
                        hasChanges = true
                    }
                    self.deletedMedicationIDs.insert(remoteMedication.id)
                    self.persistDeletedMedicationIDs()
                    continue
                }

                if deletedIDs.contains(remoteMedication.id) {
                    if let index = updated.firstIndex(where: { $0.id == remoteMedication.id }) {
                        let toRemove = updated[index]
                        self.notificationManager.cancelMedicationNotifications(for: toRemove.id)
                        self.notificationManager.unregisterTrackedMedicationID(toRemove.id)
                        self.clearReminderState(for: toRemove)
                        updated.remove(at: index)
                        hasChanges = true
                    }
                    var tombstone = remoteMedication
                    tombstone.isDeleted = true
                    tombstone.updatedAt = Date()
                    self.syncMedicationWithCloud(tombstone)
                    continue
                }

                if let index = updated.firstIndex(where: { $0.id == remoteMedication.id }) {
                    if self.shouldReplace(local: updated[index], with: remoteMedication) {
                        self.notificationManager.registerTrackedMedicationID(remoteMedication.id)
                        let scheduled = self.scheduleNotificationsForCloudMedication(remoteMedication)
                        updated[index] = scheduled
                        hasChanges = true
                    }
                } else {
                    self.notificationManager.registerTrackedMedicationID(remoteMedication.id)
                    let scheduled = self.scheduleNotificationsForCloudMedication(remoteMedication)
                    updated.append(scheduled)
                    hasChanges = true
                }
            }

            let missingDeletedIDs = deletedIDs.subtracting(remoteIDs)
            if !missingDeletedIDs.isEmpty {
                for id in missingDeletedIDs {
                    let tombstone = Medication(
                        id: id,
                        name: "Deleted Medication",
                        dosage: "Deleted",
                        dosageUnit: "",
                        iconName: "pill",
                        createdAt: nil,
                        updatedAt: Date(),
                        frequency: "Once daily",
                        timeToTake: Date(),
                        isDeleted: true
                    )
                    self.syncMedicationWithCloud(tombstone)
                }
            }

            self.notificationManager.updateTrackedMedicationIDs(
                Set(updated.filter { !$0.isDeleted }.map { $0.id })
            )

            if hasChanges {
                self.medications = updated
                self.saveMedications()
                self.resetBadgeIfNeeded()
            }
            self.kickstartActiveReminderSchedules(referenceDate: Date(), force: true)
        }
    }

    private func performInitialCloudSync() {
        guard shouldUseCloudSync else { return }
        guard !isPerformingInitialCloudSync else { return }
        isPerformingInitialCloudSync = true
        beginCloudSyncOperation()
        cloudSync.fetchAllRecords { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                defer { self.endCloudSyncOperation() }
                self.isPerformingInitialCloudSync = false
                switch result {
                case let .success(payload):
                    if payload.medications.isEmpty && payload.logs.isEmpty {
                        self.pushAllLocalDataToCloud()
                        self.runLegacyLogMedicationIDRepair(markCompleteWhenNoChanges: true)
                        self.lastCloudSyncDate = Date()
                        return
                    }

                    self.mergeCloudMedications(payload.medications, allowSnapshotDeletion: false)
                    self.mergeCloudLogs(payload.logs)
                    self.runLegacyLogMedicationIDRepair(markCompleteWhenNoChanges: true)
                    self.pushLocalChangesToCloud(remoteMedications: payload.medications, remoteLogs: payload.logs)
                    self.lastCloudSyncDate = Date()
                case let .failure(error):
                    print("CloudKit fetch failed: \(error)")
                }
            }
        }
    }

    private func pushAllLocalDataToCloud() {
        guard shouldUseCloudSync else { return }
        for medication in medications {
            syncMedicationWithCloud(medication)
        }
        for log in logs {
            syncLogWithCloud(log)
        }

        let medicationIDs = Set(medications.map { $0.id })
        let missingDeletedIDs = deletedMedicationIDs.subtracting(medicationIDs)
        for id in missingDeletedIDs {
            let tombstone = Medication(
                id: id,
                name: "Deleted Medication",
                dosage: "Deleted",
                dosageUnit: "",
                iconName: "pill",
                createdAt: nil,
                updatedAt: Date(),
                frequency: "Once daily",
                timeToTake: Date(),
                isDeleted: true
            )
            syncMedicationWithCloud(tombstone)
        }
    }

    private func pushLocalChangesToCloud(remoteMedications: [Medication], remoteLogs: [MedicationLog]) {
        guard shouldUseCloudSync else { return }
        let remoteMedsByID = Dictionary(uniqueKeysWithValues: remoteMedications.map { ($0.id, $0) })
        for medication in medications {
            if let remote = remoteMedsByID[medication.id] {
                if shouldReplace(local: medication, with: remote) {
                    continue
                }
            }
            syncMedicationWithCloud(medication)
        }

        let remoteLogsByID = Dictionary(uniqueKeysWithValues: remoteLogs.map { ($0.id, $0) })
        for log in logs {
            if let remote = remoteLogsByID[log.id] {
                if shouldReplace(local: log, with: remote) {
                    continue
                }
            }
            syncLogWithCloud(log)
        }

        let remoteIDs = Set(remoteMedications.map { $0.id })
        let missingDeletedIDs = deletedMedicationIDs.subtracting(remoteIDs)
        for id in missingDeletedIDs {
            let tombstone = Medication(
                id: id,
                name: "Deleted Medication",
                dosage: "Deleted",
                dosageUnit: "",
                iconName: "pill",
                createdAt: nil,
                updatedAt: Date(),
                frequency: "Once daily",
                timeToTake: Date(),
                isDeleted: true
            )
            syncMedicationWithCloud(tombstone)
        }
    }

    private func mergeCloudLogs(_ remoteLogs: [MedicationLog]) {
        guard !remoteLogs.isEmpty else { return }
        DispatchQueue.main.async {
            var updated = self.logs
            var changed = false
            var syncedLogs: [MedicationLog] = []

            for log in remoteLogs {
                if log.isDeleted {
                    if let index = updated.firstIndex(where: { $0.id == log.id }),
                       self.shouldReplace(local: updated[index], with: log) {
                        updated.remove(at: index)
                        changed = true
                    }
                    continue
                }

                if let index = updated.firstIndex(where: { $0.id == log.id }) {
                    if self.shouldReplace(local: updated[index], with: log) {
                        updated[index] = log
                        changed = true
                        syncedLogs.append(log)
                    }
                } else {
                    updated.insert(log, at: 0)
                    changed = true
                    syncedLogs.append(log)
                }
            }

            if changed {
                updated.sort(by: { $0.takenAt > $1.takenAt })
                self.logs = updated
                self.saveLogs()
                self.clearSyncedLogNotificationsIfNeeded(syncedLogs)
            }
        }
    }

    private func shouldReplace(local: Medication, with remote: Medication) -> Bool {
        guard let remoteDate = remote.updatedAt ?? remote.cloudLastModified else {
            return false
        }

        let localDate = local.updatedAt ?? local.cloudLastModified ?? local.createdAt ?? Date.distantPast
        return remoteDate > localDate
    }


    private func shouldReplace(local: MedicationLog, with remote: MedicationLog) -> Bool {
        guard let remoteDate = remote.updatedAt else {
            return false
        }

        let localDate = local.updatedAt ?? local.takenAt
        return remoteDate > localDate
    }

    private func clearSyncedLogNotificationsIfNeeded(_ syncedLogs: [MedicationLog]) {
        guard !syncedLogs.isEmpty else { return }
        let uniqueLogs = Dictionary(grouping: syncedLogs, by: { $0.id }).compactMap { $0.value.first }

        for log in uniqueLogs {
            if let medication = medications.first(where: { $0.id == log.medicationID }) {
                clearNotificationsForLoggedDose(
                    medication: medication,
                    storedMedication: medication,
                    actualTime: log.takenAt,
                    reminderIndex: log.reminderIndex,
                    isDailyCheckIn: log.isDailyCheckIn
                )
            } else {
                notificationManager.cancelMedicationNotifications(for: log.medicationID)
            }
        }
    }

    private func scheduleNotificationsForCloudMedication(_ medication: Medication) -> Medication {
        var mutable = medication

        if let notificationID = mutable.notificationID {
            notificationManager.cancelNotification(with: notificationID)
            mutable.notificationID = nil
        }

        if !mutable.notificationIDs.isEmpty {
            notificationManager.cancelMultipleNotifications(ids: mutable.notificationIDs)
            mutable.notificationIDs = []
        }

        if mutable.reminderTimes.isEmpty {
            mutable.notificationID = notificationManager.scheduleNotification(for: mutable)
            mutable.notificationIDs = []
        } else {
            mutable.notificationIDs = notificationManager.scheduleMultipleNotifications(for: mutable)
            mutable.notificationID = nil
        }

        return mutable
    }

    private func persistDeletedMedicationIDs() {
        let ids = deletedMedicationIDs.map { $0.uuidString }
        UserDefaults.standard.set(ids, forKey: deletedMedicationIDsKey)
    }

    // Made public to support previews
    func addSampleData() {
        // Morning and evening reminder times for Vitamin D
        let morningTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let eveningTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        
        let sampleMed1 = Medication(
            name: "Vitamin D", 
            dosage: "1000 IU", 
            dosageUnit: "IU",
            iconName: "vitamin-d",
            createdAt: Date().addingTimeInterval(-86400), // Created yesterday
            frequency: "Twice daily", 
            timeToTake: morningTime,
            reminderTimes: [morningTime, eveningTime],
            pillCount: 60,
            pillsPerDose: 1,
            refillThreshold: 10
        )
        
        let sampleMed2 = Medication(
            name: "Pain Relief", 
            dosage: "1 tablet", 
            dosageUnit: "tablet",
            iconName: "pain-relief",
            createdAt: Date().addingTimeInterval(-86400), // Created yesterday
            frequency: "As needed", 
            timeToTake: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!, 
            notes: "Max 4 per day",
            pillCount: 20,
            pillsPerDose: 1,
            refillThreshold: 4
        )
        
        medications = [sampleMed1, sampleMed2]
        
        // Schedule notifications for sample data only if not in preview mode
        if !isPreviewMode {
            // Schedule notifications for each medication
            for (index, medication) in medications.enumerated() {
                var updatedMedication = medication
                
            if !medication.reminderTimes.isEmpty {
                updatedMedication.notificationIDs = notificationManager.scheduleMultipleNotifications(for: medication)
                updatedMedication.notificationID = nil
            } else {
                updatedMedication.notificationID = notificationManager.scheduleNotification(for: medication)
                updatedMedication.notificationIDs = []
            }
                
                medications[index] = updatedMedication
            }
            
            saveMedications()
        }
    }

}

#if DEBUG
extension MedicationStore {
    func _test_scheduledReminderTime(
        medication: Medication,
        reminderIndex: Int?,
        dayStart: Date,
        referenceDate: Date
    ) -> Date {
        scheduledReminderTime(
            medication: medication,
            reminderIndex: reminderIndex,
            dayStart: dayStart,
            referenceDate: referenceDate
        )
    }

    func _test_scheduledTimeForToday(
        medication: Medication,
        actualTime: Date,
        reminderIndex: Int?
    ) -> Date? {
        scheduledTimeForToday(
            medication: medication,
            actualTime: actualTime,
            reminderIndex: reminderIndex
        )
    }

    func _test_resolvedTakenReminderIndices(
        medication: Medication,
        dayStart: Date,
        logs: [MedicationLog]
    ) -> Set<Int> {
        resolvedTakenReminderIndices(
            medication: medication,
            dayStart: dayStart,
            logs: logs
        )
    }

    func _test_inferReminderIndexIfNeeded(
        medication: Medication,
        actualTime: Date
    ) -> Int? {
        inferReminderIndexIfNeeded(
            for: medication,
            actualTime: actualTime
        )
    }

    func _test_overdueMedicationIDsSnapshot(referenceDate: Date) -> Set<UUID> {
        overdueMedicationIDsSnapshot(referenceDate: referenceDate)
    }

    func _test_overdueReminderCountSnapshot(referenceDate: Date) -> Int {
        overdueReminderCountSnapshot(referenceDate: referenceDate)
    }

    func _test_setOverdueReminderNotificationIDs(_ ids: Set<String>) {
        overdueReminderNotificationIDs = ids
    }

    func _test_reconcileNotificationSchedules(
        withPendingRequests requests: [UNNotificationRequest],
        referenceDate: Date
    ) {
        reconcileNotificationSchedules(
            withPendingRequests: requests,
            referenceDate: referenceDate
        )
    }

    func _test_mergeCloudMedications(_ remote: [Medication]) {
        mergeCloudMedications(remote, allowSnapshotDeletion: true)
    }

    func _test_mergeCloudLogs(_ remote: [MedicationLog]) {
        mergeCloudLogs(remote)
    }

    func _test_shouldReplace(local: Medication, with remote: Medication) -> Bool {
        shouldReplace(local: local, with: remote)
    }

    func _test_shouldReplace(local: MedicationLog, with remote: MedicationLog) -> Bool {
        shouldReplace(local: local, with: remote)
    }

    func _test_setDeletedMedicationIDs(_ ids: Set<UUID>) {
        deletedMedicationIDs = ids
        persistDeletedMedicationIDs()
    }

    func _test_getDeletedMedicationIDs() -> Set<UUID> {
        deletedMedicationIDs
    }

    func _test_runLegacyLogMedicationIDRepair(markCompleteWhenNoChanges: Bool = true) {
        runLegacyLogMedicationIDRepair(
            markCompleteWhenNoChanges: markCompleteWhenNoChanges,
            allowInPreview: true
        )
    }
}
#endif
