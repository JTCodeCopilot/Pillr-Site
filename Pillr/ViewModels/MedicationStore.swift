//
//  MedicationStore.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI
import Combine
import UserNotifications

struct ADHDDoseTimelineEntry: Identifiable, Equatable {
    let id = UUID()
    let medication: Medication
    let actualTime: Date
    let scheduledTime: Date?
    let onsetTime: Date
    let fadeTime: Date
}

class MedicationStore: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var logs: [MedicationLog] = []
    @Published var recentADHDDoseTimeline: ADHDDoseTimelineEntry?
    /// When set (typically from a notification tap), the UI
    /// should present a daily check-in logging sheet for this medication.
    @Published var dailyCheckInMedication: Medication?
    /// When set, the medications list should highlight / expand this medication card.
    @Published var highlightedMedicationID: UUID?
    /// The medication that should currently show expanded details on the My Meds list.
    @Published var expandedMedicationID: UUID?
    /// Allows any view to request a specific tab to show (e.g., jump back to My Meds).
    @Published var requestedMainTab: MainTab?
    private let notificationManager = NotificationManager.shared
    private let hapticManager = HapticManager.shared
    
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

    // Computed properties for active and archived medications
    var activeMedications: [Medication] {
        medications.filter { !$0.isArchived }
    }
    var archivedMedications: [Medication] {
        medications.filter { $0.isArchived }
    }

    init(isPreview: Bool = false) {
        self.isPreviewMode = isPreview
        if !isPreview {
            loadMedications()
            loadLogs()
        }
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
        dailyCheckInTime: Date? = nil
    ) -> Bool {
        // Check if user can add more medications
        let currentActiveMedications = activeMedications.count
        guard UserSettings.shared.canAddMedication(currentCount: currentActiveMedications) else {
            return false // Cannot add medication due to free tier limit
        }
        
        // Only allow pill tracking for premium users
        let finalPillCount = UserSettings.shared.isPremiumUser ? pillCount : nil
        let finalPillsPerDose = UserSettings.shared.isPremiumUser ? pillsPerDose : 1
        let finalRefillThreshold = UserSettings.shared.isPremiumUser ? refillThreshold : nil
        
        var newMed = Medication(
            name: name,
            dosage: dosage,
            dosageUnit: dosageUnit,
            iconName: iconName,
            createdAt: Date(), // Set creation date to now
            frequency: frequency,
            medicationType: medicationType,
            isExtendedRelease: isExtendedRelease,
            onsetMinutes: onsetMinutes,
            durationMinutes: durationMinutes,
            enableDailyCheckIn: enableDailyCheckIn,
            dailyCheckInTime: enableDailyCheckIn ? dailyCheckInTime : nil,
            timeToTake: timeToTake,
            reminderTimes: reminderTimes,
            notes: notes,
            pillCount: finalPillCount,
            pillsPerDose: finalPillsPerDose,
            refillThreshold: finalRefillThreshold,
            isOneTimeWithFollowUp: isOneTimeWithFollowUp,
            isArchived: false // Always add as not archived
        )
        
        // Schedule notifications only if enabled
        if enableNotification {
            if isOneTimeWithFollowUp {
                let notificationID = notificationManager.scheduleNotification(for: newMed)
                newMed.notificationID = notificationID
                newMed.notificationIDs = []
            } else if reminderTimes.isEmpty {
                // Legacy single notification support
                let notificationID = notificationManager.scheduleNotification(for: newMed)
                newMed.notificationID = notificationID
            } else {
                // Multiple notifications support
                let notificationIDs = notificationManager.scheduleMultipleNotifications(for: newMed)
                newMed.notificationIDs = notificationIDs
            }
        }
        
        medications.append(newMed)
        saveMedications()
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
            
            // Only allow pill tracking for premium users
            if !UserSettings.shared.isPremiumUser {
                updatedMedication.pillCount = nil
                updatedMedication.pillsPerDose = 1
                updatedMedication.refillThreshold = nil
            }
            
            // Schedule new notifications if enabled
            if enableNotification {
                if updatedMedication.reminderTimes.isEmpty {
                    // Legacy single notification
                    let newNotificationID = notificationManager.scheduleNotification(for: updatedMedication)
                    updatedMedication.notificationID = newNotificationID
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
                notificationManager.cancelNotifications(forMedicationID: updatedMedication.id)
            }
            
            // Update medication name in existing logs if it changed
            let oldMedication = medications[index]
            if oldMedication.name != updatedMedication.name {
                updateMedicationNameInLogs(medicationID: updatedMedication.id, newName: updatedMedication.name)
            }
            
            // Update in the array
            medications[index] = updatedMedication
            saveMedications()
        }
    }

    func logMedicationTaken(
        medication: Medication,
        actualTime: Date,
        notes: String?,
        skipped: Bool = false,
        reminderIndex: Int? = nil,
        focusRating: Int? = nil,
        sideEffectSeverity: Int? = nil,
        showFocusTimeline: Bool = true
    ) {
        let pillsConsumed = skipped ? 0 : medication.pillsPerDose
        let calendar = Calendar.current
        var previousLog: MedicationLog?
        
        if let existingIndex = logs.firstIndex(where: { log in
            log.medicationID == medication.id &&
            calendar.isDate(log.takenAt, inSameDayAs: actualTime) &&
            log.reminderIndex == reminderIndex
        }) {
            let existingLog = logs[existingIndex]
            if existingLog.skipped == skipped {
                hapticManager.warningNotification()
                return
            }
            
            previousLog = existingLog
            logs.remove(at: existingIndex)
        } else if reminderIndex == nil {
            // Single-dose medications (no reminder index) can only be logged once per day
            let alreadyLogged = logs.contains { log in
                log.medicationID == medication.id &&
                calendar.isDate(log.takenAt, inSameDayAs: actualTime) &&
                log.reminderIndex == nil
            }
            
            if alreadyLogged {
                hapticManager.warningNotification()
                return
            }
        }
        
        let newLog = MedicationLog(
            medicationID: medication.id,
            medicationName: medication.name,
            takenAt: actualTime,
            notes: notes,
            skipped: skipped,
            pillsConsumed: pillsConsumed,
            reminderIndex: reminderIndex,
            focusRating: focusRating,
            sideEffectSeverity: sideEffectSeverity
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
        
        // Cancel the specific notification that triggered this log
        if let specificIndex = reminderIndex, !medication.notificationIDs.isEmpty, specificIndex < medication.notificationIDs.count {
            // Cancel the specific notification if we know which one
            notificationManager.cancelNotification(with: medication.notificationIDs[specificIndex])
        } else if let notificationID = medication.notificationID {
            // Legacy support - cancel the single notification
            notificationManager.cancelNotification(with: notificationID)
        }
        
        // Reset application badge if no more pending medications for today
        resetBadgeIfNeeded()

        // If this is an ADHD stimulant with timing metadata and not skipped, prepare a focus timeline entry
        if showFocusTimeline,
           !skipped,
           medication.hasStimulantTiming,
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
                reminderIndex: reminderIndex
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
    }
    
    // Helper method to check if badge should be reset
    public func resetBadgeIfNeeded() {
        // Check if there are any remaining medications to be taken today
        let today = Calendar.current.startOfDay(for: Date())
        let hasPendingMedications = medications.contains { medication in
            // Only check active medications
            if medication.isArchived { return false }
            
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
    
    func skipMedication(
        medication: Medication,
        actualTime: Date,
        notes: String?,
        reminderIndex: Int? = nil,
        focusRating: Int? = nil,
        sideEffectSeverity: Int? = nil,
        showFocusTimeline: Bool = true
    ) {
        logMedicationTaken(
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
    
    func toggleSkipStatus(for medicationID: UUID) {
        if let index = medications.firstIndex(where: { $0.id == medicationID }) {
            var updatedMedication = medications[index]
            updatedMedication.isSkipped.toggle()
            medications[index] = updatedMedication
            saveMedications()
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
        // Cancel notifications for the medications being deleted
        for index in offsets {
            let medication = medications[index]

            if let notificationID = medication.notificationID {
                notificationManager.cancelNotification(with: notificationID)
            }
            
            if !medication.notificationIDs.isEmpty {
                notificationManager.cancelMultipleNotifications(ids: medication.notificationIDs)
            }

            notificationManager.cancelNotifications(forMedicationID: medication.id)
        }
        
        medications.remove(atOffsets: offsets)
        saveMedications()
    }
    
    func deleteLog(at offsets: IndexSet) {
        logs.remove(atOffsets: offsets)
        saveLogs()
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
    }

    public func loadMedications() {
        if let savedMedications = UserDefaults.standard.data(forKey: medicationsKey) {
            if let decodedMedications = try? JSONDecoder().decode([Medication].self, from: savedMedications) {
                self.medications = decodedMedications

                let activeMedicationIDs = Set(decodedMedications.filter { !$0.isArchived }.map { $0.id })
                notificationManager.purgeNotifications(excluding: activeMedicationIDs)
                
                // Reschedule notifications on app launch (in case app was terminated)
                for (index, medication) in medications.enumerated() {
                    // Cancel any existing notifications first
                    if let notificationID = medication.notificationID {
                        notificationManager.cancelNotification(with: notificationID)
                    }
                    if !medication.notificationIDs.isEmpty {
                        notificationManager.cancelMultipleNotifications(ids: medication.notificationIDs)
                    }
                    
                    var updatedMedication = medication
                    
                    // Only schedule notifications for active (non-archived) medications
                    if !medication.isArchived {
                        // Reschedule based on whether it uses single or multiple notifications
                        if !medication.reminderTimes.isEmpty {
                            // Use multiple reminders
                            let notificationIDs = notificationManager.scheduleMultipleNotifications(for: medication)
                            updatedMedication.notificationIDs = notificationIDs
                            updatedMedication.notificationID = nil
                        } else if medication.notificationID != nil {
                            // Legacy - use single reminder
                            let notificationID = notificationManager.scheduleNotification(for: medication)
                            updatedMedication.notificationID = notificationID
                        }
                    } else {
                        // Clear notification IDs for archived medications
                        updatedMedication.notificationID = nil
                        updatedMedication.notificationIDs = []
                        notificationManager.cancelNotifications(forMedicationID: updatedMedication.id)
                    }
                    
                    medications[index] = updatedMedication
                }
                saveMedications()
                
                // Reset badge on app launch if needed
                resetBadgeIfNeeded()
                
                return
            }
        }
        self.medications = []
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

    private func saveLogs() {
        // Save medication logs locally on device only
        // This data persists until the app is completely uninstalled from the device
        if let encoded = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(encoded, forKey: logsKey)
        }
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
                    let notificationIDs = notificationManager.scheduleMultipleNotifications(for: medication)
                    updatedMedication.notificationIDs = notificationIDs
                } else {
                    let notificationID = notificationManager.scheduleNotification(for: medication)
                    updatedMedication.notificationID = notificationID
                }
                
                medications[index] = updatedMedication
            }
            
            saveMedications()
        }
    }

    // Archive a medication
    func archiveMedication(_ medication: Medication) {
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            var updatedMedication = medications[index]
            
            // Cancel notifications for archived medication
            if let notificationID = updatedMedication.notificationID {
                notificationManager.cancelNotification(with: notificationID)
                updatedMedication.notificationID = nil
            }
            
            if !updatedMedication.notificationIDs.isEmpty {
                notificationManager.cancelMultipleNotifications(ids: updatedMedication.notificationIDs)
                updatedMedication.notificationIDs = []
            }

            notificationManager.cancelNotifications(forMedicationID: updatedMedication.id)
            
            updatedMedication.isArchived = true
            medications[index] = updatedMedication
            saveMedications()
        }
    }

    // Unarchive a medication
    func unarchiveMedication(_ medication: Medication) {
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            var updatedMedication = medications[index]
            updatedMedication.isArchived = false
            
            // Reschedule notifications for unarchived medication
            if updatedMedication.reminderTimes.isEmpty {
                // Legacy single notification
                let notificationID = notificationManager.scheduleNotification(for: updatedMedication)
                updatedMedication.notificationID = notificationID
            } else {
                // Multiple notifications
                let notificationIDs = notificationManager.scheduleMultipleNotifications(for: updatedMedication)
                updatedMedication.notificationIDs = notificationIDs
            }
            
            medications[index] = updatedMedication
            saveMedications()
        }
    }
}
