//
//  MedicationStore.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI
import Combine
import UserNotifications

class MedicationStore: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var logs: [MedicationLog] = []
    private let notificationManager = NotificationManager.shared
    
    // Shared instance for access from notification handlers
    static let shared = MedicationStore()
    
    // Static method to create a lightweight preview store
    static func previewStore() -> MedicationStore {
        let store = MedicationStore(isPreview: true)
        store.addSampleData()
        return store
    }

    // Simple persistence using UserDefaults for demonstration
    // For a real app, use SwiftData or Core Data
    private let medicationsKey = "medicationsData"
    private let logsKey = "medicationLogsData"
    private let isPreviewMode: Bool

    init(isPreview: Bool = false) {
        self.isPreviewMode = isPreview
        if !isPreview {
            loadMedications()
            loadLogs()
            // Add some sample data if empty
            if medications.isEmpty {
                addSampleData()
            }
        }
    }
    
    // Find a medication by its ID
    func findMedication(with id: UUID) -> Medication? {
        return medications.first { $0.id == id }
    }

    func addMedication(
        name: String,
        dosage: String,
        frequency: String,
        timeToTake: Date,
        reminderTimes: [Date] = [],
        notes: String?,
        enableNotification: Bool = true,
        pillCount: Int? = nil,
        pillsPerDose: Int = 1,
        refillThreshold: Int? = nil
    ) {
        var newMed = Medication(
            name: name, 
            dosage: dosage, 
            frequency: frequency, 
            timeToTake: timeToTake,
            reminderTimes: reminderTimes,
            notes: notes,
            pillCount: pillCount,
            pillsPerDose: pillsPerDose,
            refillThreshold: refillThreshold
        )
        
        // Schedule notifications only if enabled
        if enableNotification {
            if reminderTimes.isEmpty {
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
            }
            
            // Update in the array
            medications[index] = updatedMedication
            saveMedications()
        }
    }

    func logMedicationTaken(medication: Medication, actualTime: Date, notes: String?, skipped: Bool = false, reminderIndex: Int? = nil) {
        let pillsConsumed = skipped ? 0 : medication.pillsPerDose
        
        let newLog = MedicationLog(
            medicationID: medication.id, 
            medicationName: medication.name, 
            takenAt: actualTime, 
            notes: notes,
            skipped: skipped,
            pillsConsumed: pillsConsumed,
            reminderIndex: reminderIndex
        )
        
        logs.insert(newLog, at: 0) // Add to the top
        saveLogs()
        
        // If medication has a pill count, update it
        if let index = medications.firstIndex(where: { $0.id == medication.id }), 
           var updatedMedication = medications[index] as Medication?,
           !skipped, // Only reduce pill count if not skipped
           var pillCount = updatedMedication.pillCount {
            
            // Reduce pill count
            pillCount = max(0, pillCount - (medication.pillsPerDose))
            updatedMedication.pillCount = pillCount
            
            // Check if we need to show refill reminder
            if let refillThreshold = updatedMedication.refillThreshold, 
               pillCount <= refillThreshold {
                // Schedule a refill reminder notification
                let content = UNMutableNotificationContent()
                content.title = "Medication Refill Reminder"
                content.body = "Your supply of \(updatedMedication.name) is running low. Only \(pillCount) left."
                content.sound = UNNotificationSound.default
                
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
    }
    
    func skipMedication(medication: Medication, actualTime: Date, notes: String?, reminderIndex: Int? = nil) {
        logMedicationTaken(medication: medication, actualTime: actualTime, notes: notes, skipped: true, reminderIndex: reminderIndex)
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
            if let notificationID = medications[index].notificationID {
                notificationManager.cancelNotification(with: notificationID)
            }
            
            if !medications[index].notificationIDs.isEmpty {
                notificationManager.cancelMultipleNotifications(ids: medications[index].notificationIDs)
            }
        }
        
        medications.remove(atOffsets: offsets)
        saveMedications()
    }
    
    func deleteLog(at offsets: IndexSet) {
        logs.remove(atOffsets: offsets)
        saveLogs()
    }

    // --- Persistence ---
    private func saveMedications() {
        if let encoded = try? JSONEncoder().encode(medications) {
            UserDefaults.standard.set(encoded, forKey: medicationsKey)
        }
    }

    private func loadMedications() {
        if let savedMedications = UserDefaults.standard.data(forKey: medicationsKey) {
            if let decodedMedications = try? JSONDecoder().decode([Medication].self, from: savedMedications) {
                self.medications = decodedMedications
                
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
                    
                    medications[index] = updatedMedication
                }
                saveMedications()
                return
            }
        }
        self.medications = []
    }

    private func saveLogs() {
        if let encoded = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(encoded, forKey: logsKey)
        }
    }

    private func loadLogs() {
        if let savedLogs = UserDefaults.standard.data(forKey: logsKey) {
            if let decodedLogs = try? JSONDecoder().decode([MedicationLog].self, from: savedLogs) {
                self.logs = decodedLogs
                return
            }
        }
        self.logs = []
    }
    
    // Made public to support previews
    func addSampleData() {
        // Morning and evening reminder times for Vitamin D
        let morningTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let eveningTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        
        let sampleMed1 = Medication(
            name: "Vitamin D", 
            dosage: "1000 IU", 
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
}