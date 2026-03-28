//
//  UserSettings.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import Foundation
import SwiftUI

class UserSettings: ObservableObject {
    static var isUITestMode: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["PILLR_UI_TEST_MODE"] == "1" { return true }
        if CommandLine.arguments.contains("--uitesting") { return true }
        return false
    }

    @Published var userName: String {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(userName, forKey: userNameKey)
            }
        }
    }
    
    @Published var hasShownPrivacyNotice: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(hasShownPrivacyNotice, forKey: privacyNoticeKey)
            }
        }
    }

    @Published var hasSeenCabinetIntroOverlay: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(hasSeenCabinetIntroOverlay, forKey: cabinetIntroOverlayKey)
            }
        }
    }

    @Published var hasSeenNotificationOnboardingPrompt: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(hasSeenNotificationOnboardingPrompt, forKey: notificationOnboardingPromptKey)
            }
        }
    }

    @Published var hasCompletedAppOnboarding: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(hasCompletedAppOnboarding, forKey: appOnboardingCompleteKey)
            }
        }
    }

    @Published var isBiometricLockEnabled: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(isBiometricLockEnabled, forKey: biometricLockEnabledKey)
            }
        }
    }
    
    @Published var isFirstLaunch: Bool = false

    @Published private(set) var seenOnboardingStages: Set<String> = [] {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(Array(seenOnboardingStages), forKey: onboardingStagesKey)
            }
        }
    }
    
    // Premium status management
    @Published var isPremiumUser: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(isPremiumUser, forKey: premiumStatusKey)
            }
        }
    }
    
    @Published var shouldUseCloudSync: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(shouldUseCloudSync, forKey: cloudSyncPreferenceKey)
            }
        }
    }
    
    @Published var shouldShowAppleHealthData: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(shouldShowAppleHealthData, forKey: appleHealthVisibilityKey)
            }
        }
    }

    @Published var isHistoryTabEnabled: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(isHistoryTabEnabled, forKey: historyTabEnabledKey)
            }
        }
    }

    @Published var isReflectionTabEnabled: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(isReflectionTabEnabled, forKey: reflectionTabEnabledKey)
            }
        }
    }

    @Published var isTimelineTabEnabled: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(isTimelineTabEnabled, forKey: timelineTabEnabledKey)
            }
        }
    }

    @Published var isInteractionCheckerShortcutEnabled: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(isInteractionCheckerShortcutEnabled, forKey: interactionCheckerShortcutEnabledKey)
            }
        }
    }

    @Published var customSideEffects: [String] {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(customSideEffects, forKey: customSideEffectsKey)
            }
        }
    }

    @Published var subscriptionType: String? {
        didSet {
            if !isPreviewMode {
                if let type = subscriptionType {
                    UserDefaults.standard.set(type, forKey: subscriptionTypeKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: subscriptionTypeKey)
                }
            }
        }
    }
    
    // User settings storage keys - data persists until app is completely uninstalled
    private let userNameKey = "userName"
    private let privacyNoticeKey = "hasShownPrivacyNotice"
    private let premiumStatusKey = "is_premium_user"
    private let subscriptionTypeKey = "subscription_type"
    private let onboardingStagesKey = "seen_onboarding_stages"
    private let cabinetIntroOverlayKey = "hasSeenCabinetIntroOverlay"
    private let notificationOnboardingPromptKey = "hasSeenNotificationOnboardingPrompt"
    private let appOnboardingCompleteKey = "has_completed_app_onboarding"
    private let biometricLockEnabledKey = "is_biometric_lock_enabled"
    private let cloudSyncPreferenceKey = "should_use_cloud_sync"
    private let appleHealthVisibilityKey = "should_show_apple_health_data"
    private let historyTabEnabledKey = "is_history_tab_enabled"
    private let reflectionTabEnabledKey = "is_reflection_tab_enabled"
    private let timelineTabEnabledKey = "is_timeline_tab_enabled"
    private let interactionCheckerShortcutEnabledKey = "is_interaction_checker_shortcut_enabled"
    private let customSideEffectsKey = "custom_side_effects"
    private let debugPremiumOverrideKey = "debug_premium_override_enabled"
    private let isPreviewMode: Bool
    private let forceUITestMode: Bool

    #if DEBUG
    /// Set `PILLR_ENABLE_TEST_PREMIUM=1` in the scheme / environment to keep premium unlocked in debug builds.
    private let forcePremiumFromEnv = ProcessInfo.processInfo.environment["PILLR_ENABLE_TEST_PREMIUM"] == "1"
    var isDebugPremiumOverrideEnabled: Bool {
        forcePremiumFromEnv || UserDefaults.standard.bool(forKey: debugPremiumOverrideKey)
    }
    #else
    private let forcePremiumFromEnv = false
    var isDebugPremiumOverrideEnabled: Bool { false }
    #endif
    
    // Free tier limitations
    static let maxFreeMedications = 3
    
    static let shared = UserSettings()
    
    // Static method to create a lightweight preview settings
    static func previewSettings() -> UserSettings {
        return UserSettings(isPreview: true)
    }
    
    init(isPreview: Bool = false) {
        self.isPreviewMode = isPreview
        self.forceUITestMode = UserSettings.isUITestMode
        
        if isPreview {
            // Use default values for preview
            self.userName = "Preview User"
            self.hasShownPrivacyNotice = true
            self.isPremiumUser = false
            self.subscriptionType = nil
            self.seenOnboardingStages = []
            self.hasSeenCabinetIntroOverlay = false
            self.hasSeenNotificationOnboardingPrompt = false
            self.hasCompletedAppOnboarding = true
            self.isBiometricLockEnabled = false
            self.shouldUseCloudSync = true
            self.shouldShowAppleHealthData = true
            self.isHistoryTabEnabled = true
            self.isReflectionTabEnabled = true
            self.isTimelineTabEnabled = true
            self.isInteractionCheckerShortcutEnabled = true
            self.customSideEffects = []
        } else if forceUITestMode {
            // Stable defaults for UI automation so first-run prompts do not interrupt flows.
            self.userName = "UI Test User"
            self.hasShownPrivacyNotice = true
            self.isPremiumUser = true
            self.subscriptionType = "one-time-purchase"
            self.seenOnboardingStages = [
                "cloudSyncChoice",
                "meds",
                "history",
                "checkIns",
                "focus",
                "more"
            ]
            self.hasSeenCabinetIntroOverlay = true
            self.hasSeenNotificationOnboardingPrompt = true
            self.hasCompletedAppOnboarding = true
            self.isBiometricLockEnabled = false
            self.shouldUseCloudSync = false
            self.shouldShowAppleHealthData = false
            self.isHistoryTabEnabled = true
            self.isReflectionTabEnabled = true
            self.isTimelineTabEnabled = true
            self.isInteractionCheckerShortcutEnabled = true
            self.customSideEffects = []
        } else {
            // Load user name if available, otherwise use default
            self.userName = UserDefaults.standard.string(forKey: userNameKey) ?? "User"
            // Check if privacy notice has been shown
            self.hasShownPrivacyNotice = UserDefaults.standard.bool(forKey: privacyNoticeKey)
            // Load premium status
            self.isPremiumUser = UserDefaults.standard.bool(forKey: premiumStatusKey)
            self.subscriptionType = UserDefaults.standard.string(forKey: subscriptionTypeKey)
            self.seenOnboardingStages = Set(UserDefaults.standard.stringArray(forKey: onboardingStagesKey) ?? [])
            self.hasSeenCabinetIntroOverlay = UserDefaults.standard.bool(forKey: cabinetIntroOverlayKey)
            self.hasSeenNotificationOnboardingPrompt = UserDefaults.standard.bool(forKey: notificationOnboardingPromptKey)
            self.hasCompletedAppOnboarding = UserDefaults.standard.bool(forKey: appOnboardingCompleteKey)
            self.isBiometricLockEnabled = UserDefaults.standard.bool(forKey: biometricLockEnabledKey)
            if let stored = UserDefaults.standard.object(forKey: cloudSyncPreferenceKey) as? Bool {
                self.shouldUseCloudSync = stored
            } else {
                self.shouldUseCloudSync = true
            }
            if let storedAppleHealthVisibility = UserDefaults.standard.object(forKey: appleHealthVisibilityKey) as? Bool {
                self.shouldShowAppleHealthData = storedAppleHealthVisibility
            } else {
                self.shouldShowAppleHealthData = true
            }
            if let stored = UserDefaults.standard.object(forKey: historyTabEnabledKey) as? Bool {
                self.isHistoryTabEnabled = stored
            } else {
                self.isHistoryTabEnabled = true
            }
            if let stored = UserDefaults.standard.object(forKey: reflectionTabEnabledKey) as? Bool {
                self.isReflectionTabEnabled = stored
            } else {
                self.isReflectionTabEnabled = true
            }
            if let stored = UserDefaults.standard.object(forKey: timelineTabEnabledKey) as? Bool {
                self.isTimelineTabEnabled = stored
            } else {
                self.isTimelineTabEnabled = true
            }
            if let stored = UserDefaults.standard.object(forKey: interactionCheckerShortcutEnabledKey) as? Bool {
                self.isInteractionCheckerShortcutEnabled = stored
            } else {
                self.isInteractionCheckerShortcutEnabled = true
            }
            self.customSideEffects = UserDefaults.standard.stringArray(forKey: customSideEffectsKey) ?? []
        }

        if forcePremiumFromEnv {
            isPremiumUser = true
            subscriptionType = "one-time-purchase"
            if !isPreviewMode {
                // Keep the local test unlock after the app is relaunched outside Xcode.
                UserDefaults.standard.set(true, forKey: debugPremiumOverrideKey)
                UserDefaults.standard.set(true, forKey: premiumStatusKey)
                UserDefaults.standard.set("one-time-purchase", forKey: subscriptionTypeKey)
            }
        }
        if !isPreviewMode {
            // Ensure visibility flag is persisted even if not set earlier
            if UserDefaults.standard.object(forKey: appleHealthVisibilityKey) == nil {
                UserDefaults.standard.set(true, forKey: appleHealthVisibilityKey)
            }
            if UserDefaults.standard.object(forKey: historyTabEnabledKey) == nil {
                UserDefaults.standard.set(true, forKey: historyTabEnabledKey)
            }
            if UserDefaults.standard.object(forKey: reflectionTabEnabledKey) == nil {
                UserDefaults.standard.set(true, forKey: reflectionTabEnabledKey)
            }
            if UserDefaults.standard.object(forKey: timelineTabEnabledKey) == nil {
                UserDefaults.standard.set(true, forKey: timelineTabEnabledKey)
            }
            if UserDefaults.standard.object(forKey: interactionCheckerShortcutEnabledKey) == nil {
                UserDefaults.standard.set(true, forKey: interactionCheckerShortcutEnabledKey)
            }
        }
    }
    
    func saveUserName(_ name: String) {
        userName = name
    }

    func setCloudSyncPreference(_ enabled: Bool) {
        shouldUseCloudSync = enabled
    }

    func reloadFromStorage() {
        guard !isPreviewMode, !forceUITestMode else { return }

        userName = UserDefaults.standard.string(forKey: userNameKey) ?? "User"
        hasShownPrivacyNotice = UserDefaults.standard.bool(forKey: privacyNoticeKey)
        isPremiumUser = UserDefaults.standard.bool(forKey: premiumStatusKey)
        subscriptionType = UserDefaults.standard.string(forKey: subscriptionTypeKey)
        seenOnboardingStages = Set(UserDefaults.standard.stringArray(forKey: onboardingStagesKey) ?? [])
        hasSeenCabinetIntroOverlay = UserDefaults.standard.bool(forKey: cabinetIntroOverlayKey)
        hasSeenNotificationOnboardingPrompt = UserDefaults.standard.bool(forKey: notificationOnboardingPromptKey)
        hasCompletedAppOnboarding = UserDefaults.standard.bool(forKey: appOnboardingCompleteKey)
        isBiometricLockEnabled = UserDefaults.standard.bool(forKey: biometricLockEnabledKey)
        shouldUseCloudSync = (UserDefaults.standard.object(forKey: cloudSyncPreferenceKey) as? Bool) ?? true
        shouldShowAppleHealthData = (UserDefaults.standard.object(forKey: appleHealthVisibilityKey) as? Bool) ?? true
        isHistoryTabEnabled = (UserDefaults.standard.object(forKey: historyTabEnabledKey) as? Bool) ?? true
        isReflectionTabEnabled = (UserDefaults.standard.object(forKey: reflectionTabEnabledKey) as? Bool) ?? true
        isTimelineTabEnabled = (UserDefaults.standard.object(forKey: timelineTabEnabledKey) as? Bool) ?? true
        isInteractionCheckerShortcutEnabled = (UserDefaults.standard.object(forKey: interactionCheckerShortcutEnabledKey) as? Bool) ?? true
        customSideEffects = UserDefaults.standard.stringArray(forKey: customSideEffectsKey) ?? []
    }
    
    func markPrivacyNoticeAsShown() {
        hasShownPrivacyNotice = true
    }
    
    // Premium management methods
    func setPremiumStatus(_ isPremium: Bool) {
        if forceUITestMode || isDebugPremiumOverrideEnabled {
            isPremiumUser = true
            subscriptionType = "one-time-purchase"
            return
        }
        isPremiumUser = isPremium
        if isPremium {
            subscriptionType = "one-time-purchase"
        }
    }
    
    func setSubscriptionType(_ type: String?) {
        subscriptionType = type
    }
    
    // Check if user can add more medications
    func canAddMedication(currentCount: Int) -> Bool {
        return isPremiumUser || currentCount < UserSettings.maxFreeMedications
    }
    
    // Check if user has access to AI features
    func hasAIAccess() -> Bool {
        return isPremiumUser
    }
    
    // Check if user has access to advanced analytics
    func hasAdvancedAnalytics() -> Bool {
        return isPremiumUser
    }
    
    // Check if user can use pill tracking feature
    func canUsePillTracking() -> Bool {
        return isPremiumUser
    }

    func hasSeenOnboardingStage(_ key: String) -> Bool {
        return seenOnboardingStages.contains(key)
    }

    func markOnboardingStageSeen(_ key: String) {
        guard !seenOnboardingStages.contains(key) else { return }
        var updatedStages = seenOnboardingStages
        updatedStages.insert(key)
        seenOnboardingStages = updatedStages
    }

    func markCabinetIntroOverlaySeen() {
        hasSeenCabinetIntroOverlay = true
    }

    func markNotificationOnboardingPromptSeen() {
        guard !hasSeenNotificationOnboardingPrompt else { return }
        hasSeenNotificationOnboardingPrompt = true
    }

    func markAppOnboardingComplete() {
        hasCompletedAppOnboarding = true
    }

    func setBiometricLockEnabled(_ enabled: Bool) {
        isBiometricLockEnabled = enabled
    }

    func addCustomSideEffect(_ effect: String) {
        let trimmed = effect.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = trimmed.lowercased()
        if customSideEffects.contains(where: { $0.lowercased() == normalized }) {
            return
        }
        customSideEffects.append(trimmed)
    }

    func removeCustomSideEffects(at offsets: IndexSet) {
        customSideEffects.remove(atOffsets: offsets)
    }

    func removeCustomSideEffect(_ effect: String) {
        let normalized = effect.lowercased()
        customSideEffects.removeAll { $0.lowercased() == normalized }
    }
}
