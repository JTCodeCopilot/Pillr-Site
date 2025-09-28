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
    
    @Published var isFirstLaunch: Bool = false
    
    // Premium status management
    @Published var isPremiumUser: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(isPremiumUser, forKey: premiumStatusKey)
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
    private let isPreviewMode: Bool
    
    // Free tier limitations
    static let maxFreeMedications = 5
    
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
        } else {
            // Load user name if available, otherwise use default
            self.userName = UserDefaults.standard.string(forKey: userNameKey) ?? "User"
            // Check if privacy notice has been shown
            self.hasShownPrivacyNotice = UserDefaults.standard.bool(forKey: privacyNoticeKey)
            // Load premium status
            self.isPremiumUser = UserDefaults.standard.bool(forKey: premiumStatusKey)
            self.subscriptionType = UserDefaults.standard.string(forKey: subscriptionTypeKey)
        }
    }
    
    func saveUserName(_ name: String) {
        userName = name
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
} 

