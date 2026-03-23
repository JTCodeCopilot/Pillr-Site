import Foundation
import Testing
@testable import Pillr

struct HealthAndSettingsModelTests {
    @Test
    func healthDistanceUnitConvertsMilesAndKilometers() async throws {
        #expect(HealthDistanceUnit.miles.label == "MI")
        #expect(HealthDistanceUnit.miles.convertDistance(fromMiles: 3) == 3)
        #expect(abs(HealthDistanceUnit.kilometers.convertDistance(fromMiles: 3) - 4.82802) < 0.00001)
    }

    @Test
    func focusTimingGuidanceOnlyHasTimingForStimulantsWithRequiredValues() async throws {
        let stimulant = FocusTimingGuidance(
            medicationType: .stimulant,
            isExtendedRelease: true,
            typicalOnsetMinutes: 45,
            typicalDurationMinutes: 360,
            typicalEffectsGoneMinMinutes: 480,
            typicalEffectsGoneMaxMinutes: 600,
            note: "XR assumed"
        )
        #expect(stimulant.hasStimulantTiming == true)

        let missingDuration = FocusTimingGuidance(
            medicationType: .stimulant,
            isExtendedRelease: false,
            typicalOnsetMinutes: 30,
            typicalDurationMinutes: nil,
            typicalEffectsGoneMinMinutes: nil,
            typicalEffectsGoneMaxMinutes: nil,
            note: nil
        )
        #expect(missingDuration.hasStimulantTiming == false)

        let otherType = FocusTimingGuidance(
            medicationType: .other,
            isExtendedRelease: false,
            typicalOnsetMinutes: 30,
            typicalDurationMinutes: 240,
            typicalEffectsGoneMinMinutes: nil,
            typicalEffectsGoneMaxMinutes: nil,
            note: nil
        )
        #expect(otherType.hasStimulantTiming == false)
    }
}
