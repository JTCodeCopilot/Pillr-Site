import Foundation
import Testing
@testable import Pillr

@Suite(.serialized)
@MainActor
struct MedicationUpdateSyncTests {
    @Test
    func editingSingleReminderUpdatesStoredCardAndReschedulesNotification() async throws {
        clearPillrUserDefaults()
        await userSettingsTestGate.withExclusiveAccess {
            UserSettings.shared.setPremiumStatus(true)
            UserSettings.shared.setSubscriptionType("one-time-purchase")
            defer {
                UserSettings.shared.setPremiumStatus(false)
                UserSettings.shared.setSubscriptionType(nil)
            }

            let fakeNotifications = FakeNotificationManager()
            let store = MedicationStore(
                isPreview: false,
                notificationManager: fakeNotifications
            )

            let oldTime = makeDate(year: 2025, month: 2, day: 1, hour: 16, minute: 0)
            let newTime = makeDate(year: 2025, month: 2, day: 1, hour: 16, minute: 5)
            let medication = Medication(
                name: "Test",
                dosage: "10",
                dosageUnit: "mg",
                iconName: "pill",
                createdAt: oldTime,
                updatedAt: oldTime,
                frequency: "Once daily",
                medicationType: .other,
                isExtendedRelease: false,
                onsetMinutes: nil,
                durationMinutes: nil,
                effectsGoneMinutes: nil,
                enableDailyCheckIn: false,
                enableStimulantPhaseNotifications: false,
                dailyCheckInTime: nil,
                timeToTake: oldTime,
                reminderTimes: [],
                notes: "Original note",
                notificationID: UUID(),
                notificationIDs: [],
                pillCount: 30,
                pillsPerDose: 1,
                refillThreshold: 5,
                isSkipped: false,
                isOneTimeWithFollowUp: false,
                isDeleted: false,
                logReferenceID: nil,
                logEntryID: nil,
                cloudLastModified: nil
            )
            store.medications = [medication]

            var updated = medication
            updated.name = "Updated"
            updated.dosage = "20"
            updated.notes = "Updated note"
            updated.timeToTake = newTime

            store.updateMedication(updated, enableNotification: true)

            #expect(fakeNotifications.canceledSingle.count == 1)
            #expect(fakeNotifications.scheduledSingle.count == 1)

            guard let stored = store.medications.first else {
                #expect(Bool(false))
                return
            }

            #expect(stored.name == "Updated")
            #expect(stored.dosage == "20")
            #expect(stored.notes == "Updated note")
            #expect(stored.timeToTake == newTime)
            #expect(stored.updatedAt != nil)
        }
    }

    @Test
    func editingMedicationReschedulesRemindersWithCloudSyncDisabled() async throws {
        clearPillrUserDefaults()
        await userSettingsTestGate.withExclusiveAccess {
            UserSettings.shared.setPremiumStatus(true)
            UserSettings.shared.setSubscriptionType("one-time-purchase")
            defer {
                UserSettings.shared.setPremiumStatus(false)
                UserSettings.shared.setSubscriptionType(nil)
            }

            let fakeNotifications = FakeNotificationManager()
            let store = MedicationStore(
                isPreview: false,
                notificationManager: fakeNotifications
            )

            let morning = makeDate(year: 2025, month: 2, day: 1, hour: 8, minute: 0)
            let evening = makeDate(year: 2025, month: 2, day: 1, hour: 20, minute: 0)
            var existing = Medication(
                name: "Test",
                dosage: "10",
                dosageUnit: "mg",
                frequency: "Once daily",
                timeToTake: morning,
                reminderTimes: [morning]
            )
            existing.notificationIDs = [UUID()]
            existing.reminderNotificationsEnabled = true

            store.medications = [existing]

            var updated = existing
            updated.reminderTimes = [morning, evening]
            updated.timeToTake = evening

            store.updateMedication(updated, enableNotification: true)

            #expect(fakeNotifications.scheduledMultiple.count == 1)
            #expect(fakeNotifications.canceledMultiple.count == 1)

            guard let stored = store.medications.first else {
                #expect(Bool(false))
                return
            }

            #expect(stored.reminderTimes.count == 2)
            #expect(stored.timeToTake == evening)
        }
    }
}
