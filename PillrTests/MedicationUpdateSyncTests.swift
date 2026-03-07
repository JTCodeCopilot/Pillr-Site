import Foundation
import Testing
@testable import Pillr

@MainActor
struct MedicationUpdateSyncTests {
    @Test
    func editingMedicationReschedulesRemindersAndSyncsToCloud() async throws {
        clearPillrUserDefaults()
        UserSettings.shared.setPremiumStatus(true)
        UserSettings.shared.setSubscriptionType("one-time-purchase")
        UserSettings.shared.setCloudSyncPreference(true)

        let fakeNotifications = FakeNotificationManager()
        let fakeCloud = FakeCloudKitSync()
        let store = MedicationStore(
            isPreview: false,
            notificationManager: fakeNotifications,
            cloudSync: fakeCloud
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
        #expect(fakeCloud.savedMedications.count >= 1)

        guard let stored = store.medications.first else {
            #expect(Bool(false))
            return
        }

        #expect(stored.reminderTimes.count == 2)
        #expect(stored.timeToTake == evening)
    }
}
