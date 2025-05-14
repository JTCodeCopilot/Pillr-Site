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

    // Simple persistence using UserDefaults for demonstration
    // For a real app, use SwiftData or Core Data
    private let medicationsKey = "medicationsData"
    private let logsKey = "medicationLogsData"

    init() {
        loadMedications()
        loadLogs()
        // Add some sample data if empty
        if medications.isEmpty {
            addSampleData()
        }
    }
    
    // Find a medication by its ID
    func findMedication(with id: UUID) -> Medication? {
        return medications.first { $0.id == id }
    }

    func addMedication(name: String, dosage: String, frequency: String, timeToTake: Date, notes: String?, enableNotification: Bool = true) {
        var newMed = Medication(name: name, dosage: dosage, frequency: frequency, timeToTake: timeToTake, notes: notes)
        
        // Schedule notification only if enabled
        if enableNotification {
            let notificationID = notificationManager.scheduleNotification(for: newMed)
            newMed.notificationID = notificationID
        }
        
        medications.append(newMed)
        saveMedications()
    }
    
    func updateMedication(_ medication: Medication, enableNotification: Bool = true) {
        if let index = medications.firstIndex(where: { $0.id == medication.id }) {
            // Cancel old notification if it exists
            if let oldNotificationID = medications[index].notificationID {
                notificationManager.cancelNotification(with: oldNotificationID)
            }
            
            // Create a mutable copy
            var updatedMedication = medication
            
            // Schedule new notification if enabled
            if enableNotification {
                let newNotificationID = notificationManager.scheduleNotification(for: updatedMedication)
                updatedMedication.notificationID = newNotificationID
            } else {
                updatedMedication.notificationID = nil
            }
            
            // Update in the array
            medications[index] = updatedMedication
            saveMedications()
        }
    }

    func logMedicationTaken(medication: Medication, actualTime: Date, notes: String?) {
        let newLog = MedicationLog(medicationID: medication.id, medicationName: medication.name, takenAt: actualTime, notes: notes)
        logs.insert(newLog, at: 0) // Add to the top
        saveLogs()
        
        // If this medication has a notification ID, cancel the notification
        // since the medication has been taken
        if let notificationID = medication.notificationID {
            notificationManager.cancelNotification(with: notificationID)
        }
    }

    func deleteMedication(at offsets: IndexSet) {
        // Cancel notifications for the medications being deleted
        for index in offsets {
            if let notificationID = medications[index].notificationID {
                notificationManager.cancelNotification(with: notificationID)
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
                    // Only reschedule if it had a notification ID
                    if medication.notificationID != nil {
                        let notificationID = notificationManager.scheduleNotification(for: medication)
                        // Update the notification ID
                        medications[index].notificationID = notificationID
                    }
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
    
    private func addSampleData() {
        let sampleMed1 = Medication(name: "Vitamin D", dosage: "1000 IU", frequency: "Once daily", timeToTake: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!)
        let sampleMed2 = Medication(name: "Pain Relief", dosage: "1 tablet", frequency: "As needed", timeToTake: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!, notes: "Max 4 per day")
        medications = [sampleMed1, sampleMed2]
        
        // Schedule notifications for sample data
        for (index, medication) in medications.enumerated() {
            let notificationID = notificationManager.scheduleNotification(for: medication)
            medications[index].notificationID = notificationID
        }
        
        saveMedications()
    }
}