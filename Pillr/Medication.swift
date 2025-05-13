//
//  Medication.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI

struct Medication: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var dosage: String // e.g., "50mg", "1 tablet"
    var frequency: String // e.g., "Once daily", "Twice daily"
    var timeToTake: Date // Specific time, can be simplified if not needed
    var notes: String?
}

struct MedicationLog: Identifiable, Codable, Hashable {
    var id = UUID()
    var medicationID: UUID
    var medicationName: String // Denormalized for easy display
    var takenAt: Date
    var notes: String?
}