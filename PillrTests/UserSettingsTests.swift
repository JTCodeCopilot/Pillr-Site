import Foundation
import Testing
@testable import Pillr

struct UserSettingsTests {
    @Test
    func userSettingsWritesUpdatedValuesToLocalStorage() async throws {
        clearPillrUserDefaults()

        let settings = UserSettings()
        settings.saveUserName("Taylor")
        settings.markPrivacyNoticeAsShown()
        settings.markNotificationOnboardingPromptSeen()
        settings.markAppOnboardingComplete()
        settings.setBiometricLockEnabled(true)
        settings.markOnboardingStageSeen("history")

        #expect(UserDefaults.standard.string(forKey: "userName") == "Taylor")
        #expect(UserDefaults.standard.bool(forKey: "hasShownPrivacyNotice") == true)
        #expect(UserDefaults.standard.bool(forKey: "hasSeenNotificationOnboardingPrompt") == true)
        #expect(UserDefaults.standard.bool(forKey: "has_completed_app_onboarding") == true)
        #expect(UserDefaults.standard.bool(forKey: "is_biometric_lock_enabled") == true)
        #expect((UserDefaults.standard.stringArray(forKey: "seen_onboarding_stages") ?? []).contains("history"))
    }

    @Test
    func customSideEffectsIgnoreBlankAndCaseDuplicateEntries() async throws {
        clearPillrUserDefaults()

        let settings = UserSettings()
        settings.customSideEffects = []

        settings.addCustomSideEffect("  Dry mouth  ")
        settings.addCustomSideEffect("dry MOUTH")
        settings.addCustomSideEffect("   ")

        #expect(settings.customSideEffects == ["Dry mouth"])

        settings.removeCustomSideEffect("DRY MOUTH")
        #expect(settings.customSideEffects.isEmpty)
    }

    @Test
    func canAddMedicationRespectsFreeAndPremiumLimits() async throws {
        clearPillrUserDefaults()

        let settings = UserSettings()
        settings.setPremiumStatus(false)
        settings.setSubscriptionType(nil)
        defer {
            settings.setPremiumStatus(false)
            settings.setSubscriptionType(nil)
        }

        #expect(settings.canAddMedication(currentCount: 2) == true)
        #expect(settings.canAddMedication(currentCount: UserSettings.maxFreeMedications) == false)

        settings.setPremiumStatus(true)
        #expect(settings.canAddMedication(currentCount: UserSettings.maxFreeMedications) == true)
        #expect(settings.hasAIAccess() == true)
        #expect(settings.hasAdvancedAnalytics() == true)
        #expect(settings.canUsePillTracking() == true)
    }
}
