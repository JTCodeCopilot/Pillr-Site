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
    /// should present a daily check-in logging sheet for this medication.
    @Published var dailyCheckInMedication: Medication?
    /// When set, the medications list should highlight / expand this medication card.
    @Published var highlightedMedicationID: UUID?
    /// When a medication reminder notification is tapped, this ID gets a quick glow treatment.
    @Published var notificationHighlightMedicationID: UUID?
    /// The medication that should currently show expanded details on the My Meds list.
    @Published var expandedMedicationID: UUID?
    /// Allows any view to request a specific tab to show (e.g., jump back to My Meds).
    @Published var requestedMainTab: MainTab?
    private let notificationManager = NotificationManager.shared
    private let hapticManager = HapticManager.shared
    private let cloudSync = CloudKitMedicationSync.shared
    private var dayChangeObserver: NSObjectProtocol?
    private var appActiveObserver: NSObjectProtocol?
    private var cloudSyncPreferenceCancellable: AnyCancellable?
    private var lastCloudSyncPreferenceState: Bool = false
    private var lastNotificationResetDay = Calendar.current.startOfDay(for: Date())
    
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
    private let isPreviewMode: Bool

    private var shouldUseCloudSync: Bool {
        !isPreviewMode && UserSettings.shared.shouldUseCloudSync
    }

    var activeMedications: [Medication] {
        medications
    }

    init(isPreview: Bool = false) {
        self.isPreviewMode = isPreview
        self.lastCloudSyncPreferenceState = shouldUseCloudSync
        if !isPreview {
            loadMedications()
            loadLogs()
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
        return medications.first { $0.id == id }
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
            frequency: finalFrequency,
            medicationType: medicationType,
            isExtendedRelease: isExtendedRelease,
            onsetMinutes: onsetMinutes,
            durationMinutes: durationMinutes,
            enableDailyCheckIn: finalEnableDailyCheckIn,
            enableStimulantPhaseNotifications: enableStimulantPhaseNotifications,
            dailyCheckInTime: finalDailyCheckInTime,
            timeToTake: timeToTake,
            reminderTimes: finalReminderTimes,
            notes: notes,
            pillCount: finalPillCount,
            pillsPerDose: finalPillsPerDose,
            refillThreshold: finalRefillThreshold,
            isOneTimeWithFollowUp: isOneTimeWithFollowUp,
        )
        
        notificationManager.registerTrackedMedicationID(newMed.id)

        // Schedule notifications only if enabled
        if enableNotification {
            notificationManager.requestAuthorizationIfNeeded()
            if isOneTimeWithFollowUp {
                newMed.notificationID = notificationManager.scheduleNotification(for: newMed)
                newMed.notificationIDs = []
            } else if reminderTimes.isEmpty {
                // Legacy single notification support
                newMed.notificationID = notificationManager.scheduleNotification(for: newMed)
                newMed.notificationIDs = []
            } else {
                // Multiple notifications support
                let notificationIDs = notificationManager.scheduleMultipleNotifications(for: newMed)
                newMed.notificationIDs = notificationIDs
            }
        } else {
            newMed.notificationID = nil
            newMed.notificationIDs = []
        }
        
        medications.append(newMed)
        saveMedications()
        syncMedicationWithCloud(newMed)
        return true // Successfully added medication
    }
    
    func updateMedication(_ medication: Medication, enableNotification: Bool = true) {
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            // Cancel old notifications if they exist
            if let oldNotificationID = medications[index].notificationID {
                notificationManager.cancelNotification(with: oldNotificationID)
            }
            
            if !medications[index].notificationIDs.isEmpty {
                notificationManager.cancelMultipleNotifications(ids: medications[index].notificationIDs)
            }
            
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
            
            // Schedule new notifications if enabled
            if enableNotification {
                notificationManager.registerTrackedMedicationID(updatedMedication.id)
                notificationManager.requestAuthorizationIfNeeded()
                if updatedMedication.isOneTimeWithFollowUp {
                    updatedMedication.notificationID = notificationManager.scheduleNotification(for: updatedMedication)
                    updatedMedication.notificationIDs = []
                } else if updatedMedication.reminderTimes.isEmpty {
                    // Legacy single notification
                    updatedMedication.notificationID = notificationManager.scheduleNotification(for: updatedMedication)
                    updatedMedication.notificationIDs = []
                } else {
                    // Multiple notifications
                    let newNotificationIDs = notificationManager.scheduleMultipleNotifications(for: updatedMedication)
                    updatedMedication.notificationIDs = newNotificationIDs
                    updatedMedication.notificationID = nil
                }
            } else {
                updatedMedication.notificationID = nil
                updatedMedication.notificationIDs = []
                notificationManager.cancelMedicationNotifications(for: updatedMedication.id)
            }
            
            // Update medication name in existing logs if it changed
            let oldMedication = medications[index]
            if oldMedication.name != updatedMedication.name {
                updateMedicationNameInLogs(medicationID: updatedMedication.id, newName: updatedMedication.name)
            }
            
            // Update in the array
            medications[index] = updatedMedication
            saveMedications()
            syncMedicationWithCloud(updatedMedication)
        }
    }

    @discardableResult
    func logMedicationTaken(
        medication: Medication,
        actualTime: Date,
        notes: String?,
        skipped: Bool = false,
        reminderIndex: Int? = nil,
        focusRating: Int? = nil,
        sideEffectSeverity: Int? = nil,
        showFocusTimeline: Bool = true,
        isDailyCheckIn: Bool = false
    ) -> LogUndoAction? {
        let storedMedication = medications.first(where: { $0.id == medication.id })
        let pillsConsumed = skipped ? 0 : medication.pillsPerDose
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
                if existingLog.skipped == skipped {
                    if isDailyCheckIn {
                        applyDailyCheckInUpdates(
                            at: existingIndex,
                            notes: notes,
                            focusRating: focusRating,
                            sideEffectSeverity: sideEffectSeverity
                        )
                    } else {
                        hapticManager.warningNotification()
                    }
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
        
        let newLog = MedicationLog(
            medicationID: medication.id,
            medicationName: medication.name,
            takenAt: actualTime,
            notes: notes,
            skipped: skipped,
            pillsConsumed: pillsConsumed,
            reminderIndex: resolvedReminderIndex,
            focusRating: focusRating,
            sideEffectSeverity: sideEffectSeverity,
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
        if !skipped {
            pillCountDelta -= medication.pillsPerDose
        }
        if let previousLog, !previousLog.skipped {
            pillCountDelta += medication.pillsPerDose
        }
        
        if pillCountDelta != 0,
           let index = medications.firstIndex(where: { $0.id == medication.id }),
           var updatedMedication = medications[index] as Medication?,
           var pillCount = updatedMedication.pillCount {
            
            pillCount = max(0, pillCount + pillCountDelta)
            updatedMedication.pillCount = pillCount
            
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
        
        // Cancel the specific notification that triggered this log
        if let specificIndex = resolvedReminderIndex,
           let referenceMedication = storedMedication,
           !referenceMedication.notificationIDs.isEmpty,
           specificIndex < referenceMedication.notificationIDs.count {
            // Cancel the specific notification if we know which one
            notificationManager.cancelNotification(with: referenceMedication.notificationIDs[specificIndex])
        } else if let notificationID = storedMedication?.notificationID ?? medication.notificationID {
            // Legacy support - cancel the single notification
            notificationManager.cancelNotification(with: notificationID)
        }

        let identifiersToKeep = preservedReminderIdentifiers(
            for: medication,
            excludingReminderIndex: resolvedReminderIndex,
            excludeSingleReminder: resolvedReminderIndex == nil
        )
        notificationManager.removeUntrackedMedicationReminders(
            for: medication.id,
            preservingIdentifiers: identifiersToKeep
        )
        
        // Reset application badge if no more pending medications for today
        resetBadgeIfNeeded()

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

            notificationManager.scheduleStimulantPhaseNotifications(for: medication, doseTime: actualTime)
        }
        
        if !skipped && !isDailyCheckIn {
            notificationManager.scheduleDailyCheckInReminder(for: medication, referenceDate: actualTime)
        }

        return LogUndoAction(
            newLog: newLog,
            replacedLog: previousLog,
            replacedLogIndex: previousLogIndex,
            pillCountDelta: pillCountDelta
        )
    }
    
    // Helper method to check if badge should be reset
    public func resetBadgeIfNeeded() {
        // Check if there are any remaining medications to be taken today
        let today = Calendar.current.startOfDay(for: Date())
        let hasPendingMedications = medications.contains { medication in
            
            // Get today's logs for this medication
            let medicationLogs = logs.filter { log in
                log.medicationID == medication.id &&
                Calendar.current.isDate(log.takenAt, inSameDayAs: today)
            }
            
            // For "As needed" medications, we don't count them as pending
            if medication.frequency == "As needed" {
                return false
            }
            
            // For medications with multiple reminders
            if !medication.reminderTimes.isEmpty {
                // Check if all reminders have been taken or skipped
                return medicationLogs.count < medication.reminderTimes.count
            } else {
                // For single reminder medications
                return medicationLogs.isEmpty
            }
        }
        
        // If no pending medications, reset badge
        if !hasPendingMedications {
            notificationManager.resetApplicationBadge()
        }
    }
    
    // Public method that can be called from app delegate/scene
    func checkAndResetBadge() {
        resetBadgeIfNeeded()
    }
    
    @discardableResult
    func skipMedication(
        medication: Medication,
        actualTime: Date,
        notes: String?,
        reminderIndex: Int? = nil,
        focusRating: Int? = nil,
        sideEffectSeverity: Int? = nil,
        showFocusTimeline: Bool = true
    ) -> LogUndoAction? {
        return logMedicationTaken(
            medication: medication,
            actualTime: actualTime,
            notes: notes,
            skipped: true,
            reminderIndex: reminderIndex,
            focusRating: focusRating,
            sideEffectSeverity: sideEffectSeverity,
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
            saveMedications()
            syncMedicationWithCloud(medications[index])
        }

        resetBadgeIfNeeded()
    }
    
    func toggleSkipStatus(for medicationID: UUID) {
        if let index = medications.firstIndex(where: { $0.id == medicationID }) {
            var updatedMedication = medications[index]
            updatedMedication.isSkipped.toggle()
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
        }
        medications.remove(atOffsets: offsets)
        saveMedications()
    }

    func deleteMedication(_ medication: Medication) {
        guard let index = medications.firstIndex(where: { $0.id == medication.id }) else { return }
        prepareMedicationForDeletion(medication)
        medications.remove(at: index)
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
        syncDeleteMedication(medication)
    }

    private func clearReminderState(for medication: Medication) {
        if dailyCheckInMedication?.id == medication.id {
            dailyCheckInMedication = nil
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

    func hideLogFromMyMeds(_ log: MedicationLog) {
        guard let index = logs.firstIndex(where: { $0.id == log.id }) else { return }
        var updatedLog = logs[index]
        guard !updatedLog.hiddenFromMyMeds else { return }
        updatedLog.hiddenFromMyMeds = true
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

    private func inferReminderIndexIfNeeded(
        for medication: Medication,
        actualTime: Date
    ) -> Int? {
        guard !medication.reminderTimes.isEmpty else { return nil }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: actualTime)

        let todaysTimes: [(index: Int, time: Date)] = medication.reminderTimes.enumerated().compactMap { index, reminder in
            let components = calendar.dateComponents([.hour, .minute], from: reminder)
            guard let date = calendar.date(
                bySettingHour: components.hour ?? 8,
                minute: components.minute ?? 0,
                second: 0,
                of: dayStart
            ) else {
                return nil
            }
            return (index, date)
        }

        guard !todaysTimes.isEmpty else { return nil }

        let todaysLogs = logs.filter {
            $0.medicationID == medication.id &&
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
                return calendar.date(
                    bySettingHour: components.hour ?? 8,
                    minute: components.minute ?? 0,
                    second: 0,
                    of: dayStart
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
            return calendar.date(
                bySettingHour: components.hour ?? 8,
                minute: components.minute ?? 0,
                second: 0,
                of: dayStart
            )
        }
    }
    
    private func applyDailyCheckInUpdates(
        at index: Int,
        notes: String?,
        focusRating: Int?,
        sideEffectSeverity: Int?
    ) {
        var logEntry = logs[index]
        if let mergedNotes = mergeNotes(existing: logEntry.notes, with: notes) {
            logEntry.notes = mergedNotes
        }
        if let focusRating {
            logEntry.focusRating = focusRating
        }
        if let sideEffectSeverity {
            logEntry.sideEffectSeverity = sideEffectSeverity
        }
        logs[index] = logEntry
        saveLogs()
        hapticManager.successNotification()
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
        for index in logs.indices {
            if logs[index].medicationID == medicationID {
                logs[index].medicationName = newName
            }
        }
        saveLogs()
    }

    // --- Local Device Persistence ---
    // All data is stored locally on the user's device using iOS UserDefaults
    // No data is transmitted to external servers or cloud services
    // Data persists between app launches and is ONLY deleted when the app is uninstalled completely
    public func saveMedications() {
        if let encoded = try? JSONEncoder().encode(medications) {
            UserDefaults.standard.set(encoded, forKey: medicationsKey)
        }
        let currentIDs = Set(medications.map { $0.id })
        notificationManager.updateTrackedMedicationIDs(currentIDs)
    }

    public func loadMedications() {
        if let savedMedications = UserDefaults.standard.data(forKey: medicationsKey) {
            if let decodedMedications = try? JSONDecoder().decode([Medication].self, from: savedMedications) {
                self.medications = decodedMedications

                let activeMedicationIDs = Set(decodedMedications.map { $0.id })
                notificationManager.updateTrackedMedicationIDs(activeMedicationIDs)
                notificationManager.purgeNotifications(excluding: activeMedicationIDs)
                
                // Reschedule notifications on app launch (in case app was terminated)
                for index in medications.indices {
                    medications[index] = refreshNotificationSchedule(for: medications[index])
                }
                saveMedications()
                lastNotificationResetDay = Calendar.current.startOfDay(for: Date())
                
                // Reset badge on app launch if needed
                resetBadgeIfNeeded()
                
                return
            }
        }
        self.medications = []
        notificationManager.updateTrackedMedicationIDs([])
    }

    public func loadLogs() {
        if let savedLogs = UserDefaults.standard.data(forKey: logsKey) {
            if let decodedLogs = try? JSONDecoder().decode([MedicationLog].self, from: savedLogs) {
                self.logs = decodedLogs
                return
            }
        }
        self.logs = []
    }

    private func startObservingDayChanges() {
        guard dayChangeObserver == nil else { return }

        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.performDailyResetIfNeeded()
        }

        appActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.performDailyResetIfNeeded()
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
            fetchCloudData()
        }
        lastCloudSyncPreferenceState = enabled
    }

    private func performDailyResetIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        guard today > lastNotificationResetDay else { return }
        lastNotificationResetDay = today
        resetNotificationsForNewDay()
        resetBadgeIfNeeded()
    }

    private func resetNotificationsForNewDay() {
        guard !isPreviewMode else { return }
        var updatedMedications = medications
        var didReschedule = false

        for index in updatedMedications.indices {
            let medication = updatedMedications[index]
            guard medication.hasActiveReminder else { continue }
            updatedMedications[index] = refreshNotificationSchedule(for: medication)
            didReschedule = true
        }

        if didReschedule {
            medications = updatedMedications
            saveMedications()
        }
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

        if updatedMedication.isOneTimeWithFollowUp {
            updatedMedication.notificationID = notificationManager.scheduleNotification(for: updatedMedication)
            updatedMedication.notificationIDs = []
        } else if !updatedMedication.reminderTimes.isEmpty {
            let notificationIDs = notificationManager.scheduleMultipleNotifications(for: updatedMedication)
            updatedMedication.notificationIDs = notificationIDs
            updatedMedication.notificationID = nil
        } else if updatedMedication.notificationID != nil {
            updatedMedication.notificationID = notificationManager.scheduleNotification(for: updatedMedication)
            updatedMedication.notificationIDs = []
        }

        return updatedMedication
    }

    private func saveLogs() {
        // Save medication logs locally on device only
        // This data persists until the app is completely uninstalled from the device
        if let encoded = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(encoded, forKey: logsKey)
        }
    }
    
    private func fetchCloudData() {
        guard shouldUseCloudSync else { return }
        cloudSync.fetchAllRecords { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(payload):
                self.mergeCloudMedications(payload.medications)
                self.mergeCloudLogs(payload.logs)
                self.lastCloudSyncDate = Date()
            case let .failure(error):
                print("CloudKit fetch failed: \(error)")
            }
        }
    }

    private func syncMedicationWithCloud(_ medication: Medication) {
        guard shouldUseCloudSync else { return }
        cloudSync.save(medication: medication) { [weak self] result in
            switch result {
            case let .success(record):
                if let modificationDate = record.modificationDate {
                    self?.updateCloudLastModified(for: medication.id, date: modificationDate)
                }
                self?.lastCloudSyncDate = Date()
            case let .failure(error):
                print("CloudKit medication save failed: \(error)")
            }
        }
    }

    private func syncLogWithCloud(_ log: MedicationLog) {
        guard shouldUseCloudSync else { return }
        guard let medication = medications.first(where: { $0.id == log.medicationID }) else { return }
        cloudSync.save(log: log, medication: medication) { [weak self] result in
            if case let .failure(error) = result {
                print("CloudKit log save failed: \(error)")
            } else {
                self?.lastCloudSyncDate = Date()
            }
        }
    }

    private func syncDeleteMedication(_ medication: Medication) {
        guard shouldUseCloudSync else { return }
        cloudSync.deleteMedication(withID: medication.id) { result in
            if case let .failure(error) = result {
                print("CloudKit medication delete failed: \(error)")
            }
        }
    }

    private func syncDeleteLog(_ log: MedicationLog) {
        guard shouldUseCloudSync else { return }
        cloudSync.delete(log: log) { result in
            if case let .failure(error) = result {
                print("CloudKit log delete failed: \(error)")
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
        guard !remote.isEmpty else { return }
        DispatchQueue.main.async {
            var updated = self.medications
            var hasChanges = false
            let deletedRemoteIDs = Set(remote.filter { $0.isDeleted }.map { $0.id })

            if !deletedRemoteIDs.isEmpty {
                let toRemove = updated.filter { deletedRemoteIDs.contains($0.id) }
                for medication in toRemove {
                    self.notificationManager.cancelMedicationNotifications(for: medication.id)
                    self.notificationManager.unregisterTrackedMedicationID(medication.id)
                    self.clearReminderState(for: medication)
                }

                let beforeCount = updated.count
                updated.removeAll { deletedRemoteIDs.contains($0.id) }
                if updated.count != beforeCount {
                    hasChanges = true
                }
            }

            for remoteMedication in remote where !remoteMedication.isDeleted {
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

            self.notificationManager.updateTrackedMedicationIDs(Set(updated.map { $0.id }))

            if hasChanges {
                self.medications = updated
                self.saveMedications()
                self.resetBadgeIfNeeded()
            }
        }
    }

    private func mergeCloudLogs(_ remoteLogs: [MedicationLog]) {
        guard !remoteLogs.isEmpty else { return }
        DispatchQueue.main.async {
            var updated = self.logs
            var seenIDs = Set(updated.map { $0.id })
            var changed = false

            for log in remoteLogs {
                if !seenIDs.contains(log.id) {
                    seenIDs.insert(log.id)
                    updated.insert(log, at: 0)
                    changed = true
                }
            }

            if changed {
                updated.sort(by: { $0.takenAt > $1.takenAt })
                self.logs = updated
                self.saveLogs()
            }
        }
    }

    private func shouldReplace(local: Medication, with remote: Medication) -> Bool {
        guard let remoteDate = remote.cloudLastModified else {
            return false
        }

        if let localDate = local.cloudLastModified {
            return remoteDate > localDate
        }

        return true
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
