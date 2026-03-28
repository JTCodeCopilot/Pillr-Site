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

        med = Medication(
            name: "Test",
            dosage: "",
            dosageUnit: " ml ",
            frequency: "Once daily",
            timeToTake: Date()
        )
        #expect(med.dosageWithUnit == "ml")
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
        #expect(med.isCabinetMedication == false)

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
        #expect(log.recordedDosageWithUnit == "10 mg")
        #expect(log.recordedHasMultipleReminders == false)
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
        #expect(DrugInteraction.InteractionSeverity.major.color == "#FF9800")
    }

    @Test
    func medicationDecodeEnablesReminderFlagWhenStoredIDsExist() async throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "name": "Saved Med",
          "dosage": "10",
          "dosageUnit": "mg",
          "frequency": "Once daily",
          "timeToTake": 0,
          "notificationIDs": ["\(UUID().uuidString)"]
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let medication = try decoder.decode(Medication.self, from: Data(json.utf8))
        #expect(medication.reminderNotificationsEnabled == true)
        #expect(medication.hasActiveReminder == true)
    }

    @Test
    func medicationDecodeDefaultsLegacyScheduledMedicationToReminderEnabled() async throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "name": "Legacy Med",
          "dosage": "10",
          "dosageUnit": "mg",
          "frequency": "Once daily",
          "timeToTake": 0
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let medication = try decoder.decode(Medication.self, from: Data(json.utf8))
        #expect(medication.reminderNotificationsEnabled == true)
        #expect(medication.isCabinetMedication == false)
    }

    @Test
    func medicationDecodeKeepsLegacyAsNeededMedicationOutOfReminderScheduling() async throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "name": "Legacy PRN",
          "dosage": "10",
          "dosageUnit": "mg",
          "frequency": "As needed",
          "timeToTake": 0
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let medication = try decoder.decode(Medication.self, from: Data(json.utf8))
        #expect(medication.reminderNotificationsEnabled == false)
        #expect(medication.isCabinetMedication == true)
    }

    @Test
    func medicationLogRoundTripKeepsReminderDisplayFields() async throws {
        let original = MedicationLog(
            medicationID: UUID(),
            medicationName: "Round Trip",
            takenAt: Date(),
            pillsConsumed: 2,
            reminderIndex: 1,
            hiddenFromMyMeds: true,
            medicationDosageText: "20 mg",
            medicationIconName: "capsule",
            medicationReminderCount: 3
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MedicationLog.self, from: data)

        #expect(decoded.pillsConsumed == 2)
        #expect(decoded.reminderIndex == 1)
        #expect(decoded.hiddenFromMyMeds == true)
        #expect(decoded.recordedDosageWithUnit == "20 mg")
        #expect(decoded.recordedIconName == "capsule")
        #expect(decoded.recordedHasMultipleReminders == true)
    }
}
