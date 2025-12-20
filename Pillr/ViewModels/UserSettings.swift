//
//  UserSettings.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import Foundation
import SwiftUI

class UserSettings: ObservableObject {
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
    private let cloudSyncPreferenceKey = "should_use_cloud_sync"
    private let isPreviewMode: Bool

    #if DEBUG
    /// Set `PILLR_ENABLE_TEST_PREMIUM=1` in the scheme / environment to keep premium unlocked in debug builds.
    private let forcePremiumFromEnv = ProcessInfo.processInfo.environment["PILLR_ENABLE_TEST_PREMIUM"] == "1"
    #else
    private let forcePremiumFromEnv = false
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
        
        if isPreview {
            // Use default values for preview
            self.userName = "Preview User"
            self.hasShownPrivacyNotice = true
            self.isPremiumUser = false
            self.subscriptionType = nil
            self.seenOnboardingStages = []
            self.hasSeenCabinetIntroOverlay = false
            self.shouldUseCloudSync = true
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
            if let stored = UserDefaults.standard.object(forKey: cloudSyncPreferenceKey) as? Bool {
                self.shouldUseCloudSync = stored
            } else {
                self.shouldUseCloudSync = true
            }
        }

        if forcePremiumFromEnv {
            isPremiumUser = true
            subscriptionType = "one-time-purchase"
        }
    }
    
    func saveUserName(_ name: String) {
        userName = name
    }

    func setCloudSyncPreference(_ enabled: Bool) {
        shouldUseCloudSync = enabled
    }
    
    func markPrivacyNoticeAsShown() {
        hasShownPrivacyNotice = true
    }
    
    // Premium management methods
    func setPremiumStatus(_ isPremium: Bool) {
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
}
