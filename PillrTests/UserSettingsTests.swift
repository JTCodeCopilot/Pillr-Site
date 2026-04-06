import Foundation
import Testing
@testable import Pillr

@Suite(.serialized)
struct UserSettingsTests {
    @Test
    func userSettingsWritesUpdatedValuesToLocalStorage() async throws {
        await userSettingsTestGate.withExclusiveAccess {
            clearPillrUserDefaults()
            defer { clearPillrUserDefaults() }

            let settings = UserSettings()
            settings.saveUserName("Taylor")
            settings.markPrivacyNoticeAsShown()
            settings.markAppOnboardingComplete()
            settings.setBiometricLockEnabled(true)

            #expect(UserDefaults.standard.string(forKey: "userName") == "Taylor")
            #expect(UserDefaults.standard.bool(forKey: "hasShownPrivacyNotice") == true)
            #expect(UserDefaults.standard.bool(forKey: "has_completed_app_onboarding") == true)
            #expect(UserDefaults.standard.bool(forKey: "is_biometric_lock_enabled") == true)
        }
    }

    @Test
    func customSideEffectsIgnoreBlankAndCaseDuplicateEntries() async throws {
        await userSettingsTestGate.withExclusiveAccess {
            clearPillrUserDefaults()
            defer { clearPillrUserDefaults() }

            let settings = UserSettings()
            settings.customSideEffects = []

            settings.addCustomSideEffect("  Dry mouth  ")
            settings.addCustomSideEffect("dry MOUTH")
            settings.addCustomSideEffect("   ")

            #expect(settings.customSideEffects == ["Dry mouth"])

            settings.removeCustomSideEffect("DRY MOUTH")
            #expect(settings.customSideEffects.isEmpty)
        }
    }

    @Test
    func canAddMedicationRespectsFreeAndPremiumLimits() async throws {
        await userSettingsTestGate.withExclusiveAccess {
            clearPillrUserDefaults()
            defer { clearPillrUserDefaults() }

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
}
