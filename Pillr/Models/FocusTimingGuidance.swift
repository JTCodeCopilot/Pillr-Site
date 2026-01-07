import Foundation

struct FocusTimingGuidance {
    let medicationType: MedicationType
    let isExtendedRelease: Bool
    let typicalOnsetMinutes: Int?
    let typicalDurationMinutes: Int?
    let typicalEffectsGoneMinMinutes: Int?
    let typicalEffectsGoneMaxMinutes: Int?
    let note: String?

    var hasStimulantTiming: Bool {
        medicationType == .stimulant && typicalOnsetMinutes != nil && typicalDurationMinutes != nil
    }
}
