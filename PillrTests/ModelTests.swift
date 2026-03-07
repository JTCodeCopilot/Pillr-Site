import Foundation
import Testing
@testable import Pillr

struct ModelTests {
    @Test
    func medicationDosageWithUnitHandlesDuplicatesAndWhitespace() async throws {
        var med = Medication(
            name: "Test",
            dosage: " 10 mg ",
            dosageUnit: "mg",
            frequency: "Once daily",
            timeToTake: Date()
        )
        #expect(med.dosageWithUnit == "10 mg")

        med = Medication(
            name: "Test",
            dosage: "1 tablet",
            dosageUnit: "tablets",
            frequency: "Once daily",
            timeToTake: Date()
        )
        #expect(med.dosageWithUnit == "1 tablet")
    }

    @Test
    func medicationReminderStateComputedProperties() async throws {
        var med = Medication(
            name: "Test",
            dosage: "10",
            dosageUnit: "mg",
            frequency: "Once daily",
            timeToTake: Date()
        )
        med.notificationID = UUID()
        med.reminderNotificationsEnabled = true
        #expect(med.hasActiveReminder == true)
        #expect(med.shouldScheduleReminder == true)
        #expect(med.isCabinetMedication == false)

        med.notificationID = nil
        med.notificationIDs = []
        med.reminderNotificationsEnabled = false
        med.frequency = "As needed"
        #expect(med.isCabinetMedication == true)
    }

    @Test
    func medicationLogDoseFlagsAndIconFallbacks() async throws {
        let log = MedicationLog(
            medicationID: UUID(),
            medicationName: "Test",
            takenAt: Date(),
            pillsConsumed: nil,
            reminderIndex: nil,
            hiddenFromMyMeds: false,
            medicationDosageText: "10 mg",
            medicationIconName: ""
        )
        #expect(log.isDoseLog == true)
        #expect(log.recordedIconName == "pill")
    }

    @Test
    func drugInteractionDisplayTitleAndUnknownSeverity() async throws {
        let interaction = DrugInteraction(
            drugA: " ",
            drugB: " ",
            severity: .unknown,
            description: "",
            recommendedAction: ""
        )
        #expect(interaction.displayTitle == "Medication Interaction")
        #expect(DrugInteraction.InteractionSeverity.unknown.displayName == "No interaction")
    }
}
