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
    var dosageUnit: String = "mg" // "mg" or "ml"
    var iconName: String = "pill.fill" // Default icon
    var frequency: String // e.g., "Once daily", "Twice daily"
    var timeToTake: Date // Primary time to take - legacy support
    var reminderTimes: [Date] = [] // Multiple reminder times for medications
    var notes: String?
    var notificationID: UUID? // Legacy support for single notification
    var notificationIDs: [UUID] = [] // IDs for multiple scheduled notifications
    var pillCount: Int? // Total count of pills available
    var pillsPerDose: Int = 1 // Number of pills taken per dose
    var refillThreshold: Int? // Threshold to trigger refill reminder
    var isSkipped: Bool = false // Whether to skip this medication for now
    var isOneTimeWithFollowUp: Bool = false // If true, only schedule a one-time notification and a follow up
    var isArchived: Bool = false // Whether this medication is archived
}

struct MedicationLog: Identifiable, Codable, Hashable {
    var id = UUID()
    var medicationID: UUID
    var medicationName: String // Denormalized for easy display
    var takenAt: Date
    var notes: String?
    var skipped: Bool = false // Whether this log represents a skipped dose
    var pillsConsumed: Int? // Number of pills consumed in this dose
    var reminderIndex: Int? // Which reminder this log corresponds to (if multiple reminders)
}