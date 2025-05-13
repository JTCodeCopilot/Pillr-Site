//
//  MedicationStore.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI
import Combine

class MedicationStore: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var logs: [MedicationLog] = []

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

    func addMedication(name: String, dosage: String, frequency: String, timeToTake: Date, notes: String?) {
        let newMed = Medication(name: name, dosage: dosage, frequency: frequency, timeToTake: timeToTake, notes: notes)
        medications.append(newMed)
        saveMedications()
    }

    func logMedicationTaken(medication: Medication, actualTime: Date, notes: String?) {
        let newLog = MedicationLog(medicationID: medication.id, medicationName: medication.name, takenAt: actualTime, notes: notes)
        logs.insert(newLog, at: 0) // Add to the top
        saveLogs()
    }

    func deleteMedication(at offsets: IndexSet) {
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
        saveMedications()
    }
}