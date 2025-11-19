//
//  Medication.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI

enum MedicationType: String, Codable, CaseIterable, Identifiable {
    case stimulant
    case nonStimulant
    case other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .stimulant:
            return "ADHD stimulant"
        case .nonStimulant:
            return "Non-stimulant"
        case .other:
            return "Other / unknown"
        }
    }
}

struct Medication: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var dosage: String // e.g., "50mg", "1 tablet"
    var dosageUnit: String = "mg" // "mg" or "ml"
    var iconName: String = "pill.fill" // Default icon
    var createdAt: Date? = Date() // When the medication was added
    
    // Computed property to get the correct icon based on dosageUnit
    var unitIconName: String {
        switch dosageUnit {
        case "mg":
            return "scalemass.fill"
        case "ml":
            return "drop.fill"
        case "tablets":
            return "circle.fill"
        case "capsules":
            return "pills.fill"
        default:
            // For custom units
            return "text.cursor"
        }
    }
    
    var frequency: String // e.g., "Once daily", "Twice daily"
    
    // ADHD / stimulant specific metadata
    var medicationType: MedicationType = .other
    var isExtendedRelease: Bool = false
    /// Approximate minutes after taking when effects start to be felt
    var onsetMinutes: Int? = nil
    /// Approximate total duration in minutes that the medication is effective
    var durationMinutes: Int? = nil
    
    var hasStimulantTiming: Bool {
        medicationType == .stimulant && onsetMinutes != nil && durationMinutes != nil
    }
    
    /// When enabled for ADHD stimulants, Pillr will prompt
    /// a daily check-in around the time the medication wears off.
    var enableDailyCheckIn: Bool = false
    
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

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case dosage
        case dosageUnit
        case iconName
        case createdAt
        case frequency
        case medicationType
        case isExtendedRelease
        case onsetMinutes
        case durationMinutes
        case enableDailyCheckIn
        case timeToTake
        case reminderTimes
        case notes
        case notificationID
        case notificationIDs
        case pillCount
        case pillsPerDose
        case refillThreshold
        case isSkipped
        case isOneTimeWithFollowUp
        case isArchived
    }

    init(
        id: UUID = UUID(),
        name: String,
        dosage: String,
        dosageUnit: String = "mg",
        iconName: String = "pill.fill",
        createdAt: Date? = Date(),
        frequency: String,
        medicationType: MedicationType = .other,
        isExtendedRelease: Bool = false,
        onsetMinutes: Int? = nil,
        durationMinutes: Int? = nil,
        enableDailyCheckIn: Bool = false,
        timeToTake: Date,
        reminderTimes: [Date] = [],
        notes: String? = nil,
        notificationID: UUID? = nil,
        notificationIDs: [UUID] = [],
        pillCount: Int? = nil,
        pillsPerDose: Int = 1,
        refillThreshold: Int? = nil,
        isSkipped: Bool = false,
        isOneTimeWithFollowUp: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.dosageUnit = dosageUnit
        self.iconName = iconName
        self.createdAt = createdAt
        self.frequency = frequency
        self.medicationType = medicationType
        self.isExtendedRelease = isExtendedRelease
        self.onsetMinutes = onsetMinutes
        self.durationMinutes = durationMinutes
        self.enableDailyCheckIn = enableDailyCheckIn
        self.timeToTake = timeToTake
        self.reminderTimes = reminderTimes
        self.notes = notes
        self.notificationID = notificationID
        self.notificationIDs = notificationIDs
        self.pillCount = pillCount
        self.pillsPerDose = pillsPerDose
        self.refillThreshold = refillThreshold
        self.isSkipped = isSkipped
        self.isOneTimeWithFollowUp = isOneTimeWithFollowUp
        self.isArchived = isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.dosage = try container.decode(String.self, forKey: .dosage)
        self.dosageUnit = try container.decodeIfPresent(String.self, forKey: .dosageUnit) ?? "mg"
        self.iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? "pill.fill"
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.frequency = try container.decode(String.self, forKey: .frequency)

        // New ADHD metadata – default safely for older data
        self.medicationType = try container.decodeIfPresent(MedicationType.self, forKey: .medicationType) ?? .other
        self.isExtendedRelease = try container.decodeIfPresent(Bool.self, forKey: .isExtendedRelease) ?? false
        self.onsetMinutes = try container.decodeIfPresent(Int.self, forKey: .onsetMinutes)
        self.durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        self.enableDailyCheckIn = try container.decodeIfPresent(Bool.self, forKey: .enableDailyCheckIn) ?? false

        self.timeToTake = try container.decode(Date.self, forKey: .timeToTake)
        self.reminderTimes = try container.decodeIfPresent([Date].self, forKey: .reminderTimes) ?? []
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.notificationID = try container.decodeIfPresent(UUID.self, forKey: .notificationID)
        self.notificationIDs = try container.decodeIfPresent([UUID].self, forKey: .notificationIDs) ?? []
        self.pillCount = try container.decodeIfPresent(Int.self, forKey: .pillCount)
        self.pillsPerDose = try container.decodeIfPresent(Int.self, forKey: .pillsPerDose) ?? 1
        self.refillThreshold = try container.decodeIfPresent(Int.self, forKey: .refillThreshold)
        self.isSkipped = try container.decodeIfPresent(Bool.self, forKey: .isSkipped) ?? false
        self.isOneTimeWithFollowUp = try container.decodeIfPresent(Bool.self, forKey: .isOneTimeWithFollowUp) ?? false
        self.isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(dosage, forKey: .dosage)
        try container.encode(dosageUnit, forKey: .dosageUnit)
        try container.encode(iconName, forKey: .iconName)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(medicationType, forKey: .medicationType)
        try container.encode(isExtendedRelease, forKey: .isExtendedRelease)
        try container.encodeIfPresent(onsetMinutes, forKey: .onsetMinutes)
        try container.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
        try container.encode(enableDailyCheckIn, forKey: .enableDailyCheckIn)
        try container.encode(timeToTake, forKey: .timeToTake)
        try container.encode(reminderTimes, forKey: .reminderTimes)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(notificationID, forKey: .notificationID)
        try container.encode(notificationIDs, forKey: .notificationIDs)
        try container.encodeIfPresent(pillCount, forKey: .pillCount)
        try container.encode(pillsPerDose, forKey: .pillsPerDose)
        try container.encodeIfPresent(refillThreshold, forKey: .refillThreshold)
        try container.encode(isSkipped, forKey: .isSkipped)
        try container.encode(isOneTimeWithFollowUp, forKey: .isOneTimeWithFollowUp)
        try container.encode(isArchived, forKey: .isArchived)
    }
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
    var focusRating: Int? // 1–5 focus quality rating
    var sideEffectSeverity: Int? // 1–5 overall side-effect severity

    enum CodingKeys: String, CodingKey {
        case id
        case medicationID
        case medicationName
        case takenAt
        case notes
        case skipped
        case pillsConsumed
        case reminderIndex
        case focusRating
        case sideEffectSeverity
    }

    init(
        id: UUID = UUID(),
        medicationID: UUID,
        medicationName: String,
        takenAt: Date,
        notes: String? = nil,
        skipped: Bool = false,
        pillsConsumed: Int? = nil,
        reminderIndex: Int? = nil,
        focusRating: Int? = nil,
        sideEffectSeverity: Int? = nil
    ) {
        self.id = id
        self.medicationID = medicationID
        self.medicationName = medicationName
        self.takenAt = takenAt
        self.notes = notes
        self.skipped = skipped
        self.pillsConsumed = pillsConsumed
        self.reminderIndex = reminderIndex
        self.focusRating = focusRating
        self.sideEffectSeverity = sideEffectSeverity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.medicationID = try container.decode(UUID.self, forKey: .medicationID)
        self.medicationName = try container.decode(String.self, forKey: .medicationName)
        self.takenAt = try container.decode(Date.self, forKey: .takenAt)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.skipped = try container.decodeIfPresent(Bool.self, forKey: .skipped) ?? false
        self.pillsConsumed = try container.decodeIfPresent(Int.self, forKey: .pillsConsumed)
        self.reminderIndex = try container.decodeIfPresent(Int.self, forKey: .reminderIndex)
        self.focusRating = try container.decodeIfPresent(Int.self, forKey: .focusRating)
        self.sideEffectSeverity = try container.decodeIfPresent(Int.self, forKey: .sideEffectSeverity)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(medicationID, forKey: .medicationID)
        try container.encode(medicationName, forKey: .medicationName)
        try container.encode(takenAt, forKey: .takenAt)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(skipped, forKey: .skipped)
        try container.encodeIfPresent(pillsConsumed, forKey: .pillsConsumed)
        try container.encodeIfPresent(reminderIndex, forKey: .reminderIndex)
        try container.encodeIfPresent(focusRating, forKey: .focusRating)
        try container.encodeIfPresent(sideEffectSeverity, forKey: .sideEffectSeverity)
    }
}
