import Foundation

struct FocusTimingGuidance {
    enum Source {
        case ai
        case local
    }

    let medicationType: MedicationType
    let isExtendedRelease: Bool
    let typicalOnsetMinutes: Int
    let typicalDurationMinutes: Int
    let source: Source
    let note: String?

    static func fromGuideline(_ guideline: ADHDMedicationGuideline, source: Source, note: String? = nil) -> FocusTimingGuidance {
        FocusTimingGuidance(
            medicationType: guideline.medicationType,
            isExtendedRelease: guideline.isExtendedRelease,
            typicalOnsetMinutes: guideline.typicalOnsetMinutes,
            typicalDurationMinutes: guideline.typicalDurationMinutes,
            source: source,
            note: note
        )
    }
}
