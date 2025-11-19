//
//  ADHDMedicationGuidelines.swift
//  Pillr
//
//  Provides approximate, evidence-informed onset and duration timings
//  for common ADHD stimulant medications. These values are intended
//  for planning focus windows and are approximate averages only.
//

import Foundation

struct ADHDMedicationGuideline {
    let medicationType: MedicationType
    let isExtendedRelease: Bool
    let typicalOnsetMinutes: Int
    let typicalDurationMinutes: Int
}

enum ADHDMedicationGuidelines {
    // Ordered from more specific to more general matches
    private static let entries: [(matchers: [String], guideline: ADHDMedicationGuideline)] = [
        // Mixed amphetamine salts – extended release
        (
            matchers: ["adderall xr", "mixed amphetamine salts xr", "amphetamine extended-release"],
            guideline: ADHDMedicationGuideline(
                medicationType: .stimulant,
                isExtendedRelease: true,
                typicalOnsetMinutes: 60,
                typicalDurationMinutes: 720 // ~12 hours
            )
        ),
        // Mixed amphetamine salts – immediate release
        (
            matchers: ["adderall", "mixed amphetamine salts"],
            guideline: ADHDMedicationGuideline(
                medicationType: .stimulant,
                isExtendedRelease: false,
                typicalOnsetMinutes: 30,
                typicalDurationMinutes: 360 // ~6 hours
            )
        ),
        // Lisdexamfetamine
        (
            matchers: ["vyvanse", "lisdexamfetamine"],
            guideline: ADHDMedicationGuideline(
                medicationType: .stimulant,
                isExtendedRelease: true,
                typicalOnsetMinutes: 60,
                typicalDurationMinutes: 720 // ~12 hours
            )
        ),
        // Methylphenidate – extended release (e.g., Concerta, Ritalin LA)
        (
            matchers: ["concerta", "ritalin la", "metadate cd", "methylphenidate er", "methylphenidate extended-release"],
            guideline: ADHDMedicationGuideline(
                medicationType: .stimulant,
                isExtendedRelease: true,
                typicalOnsetMinutes: 60,
                typicalDurationMinutes: 720 // ~12 hours
            )
        ),
        // Methylphenidate – immediate release (e.g., Ritalin)
        (
            matchers: ["ritalin", "methylphenidate"],
            guideline: ADHDMedicationGuideline(
                medicationType: .stimulant,
                isExtendedRelease: false,
                typicalOnsetMinutes: 30,
                typicalDurationMinutes: 240 // ~4 hours
            )
        ),
        // Dexmethylphenidate – extended release (Focalin XR)
        (
            matchers: ["focalin xr", "dexmethylphenidate er", "dexmethylphenidate extended-release"],
            guideline: ADHDMedicationGuideline(
                medicationType: .stimulant,
                isExtendedRelease: true,
                typicalOnsetMinutes: 60,
                typicalDurationMinutes: 720 // ~12 hours
            )
        ),
        // Dexmethylphenidate – immediate release (Focalin)
        (
            matchers: ["focalin", "dexmethylphenidate"],
            guideline: ADHDMedicationGuideline(
                medicationType: .stimulant,
                isExtendedRelease: false,
                typicalOnsetMinutes: 30,
                typicalDurationMinutes: 240 // ~4 hours
            )
        ),
        // Dextroamphetamine – extended release (e.g., Spansule)
        (
            matchers: ["dexedrine spansule", "dextroamphetamine er", "dextroamphetamine extended-release"],
            guideline: ADHDMedicationGuideline(
                medicationType: .stimulant,
                isExtendedRelease: true,
                typicalOnsetMinutes: 60,
                typicalDurationMinutes: 600 // ~10 hours
            )
        ),
        // Dextroamphetamine – immediate release
        (
            matchers: ["dexedrine", "dextroamphetamine"],
            guideline: ADHDMedicationGuideline(
                medicationType: .stimulant,
                isExtendedRelease: false,
                typicalOnsetMinutes: 30,
                typicalDurationMinutes: 360 // ~6 hours
            )
        ),
        // Methylphenidate transdermal patch
        (
            matchers: ["daytrana", "methylphenidate patch"],
            guideline: ADHDMedicationGuideline(
                medicationType: .stimulant,
                isExtendedRelease: true,
                typicalOnsetMinutes: 60,
                typicalDurationMinutes: 600 // ~10 hours
            )
        )
    ]

    static func guideline(for medicationName: String) -> ADHDMedicationGuideline? {
        let normalized = medicationName
            .lowercased()
            .replacingOccurrences(of: "®", with: "")
            .replacingOccurrences(of: "™", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for entry in entries {
            for matcher in entry.matchers {
                if normalized.contains(matcher) {
                    return entry.guideline
                }
            }
        }

        return nil
    }
}

