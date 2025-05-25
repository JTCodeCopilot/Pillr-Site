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
    
    private let userNameKey = "userName"
    private let privacyNoticeKey = "hasShownPrivacyNotice"
    private let isPreviewMode: Bool
    
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
        } else {
            // Load user name if available, otherwise use default
            self.userName = UserDefaults.standard.string(forKey: userNameKey) ?? "User"
            // Check if privacy notice has been shown
            self.hasShownPrivacyNotice = UserDefaults.standard.bool(forKey: privacyNoticeKey)
        }
    }
    
    func saveUserName(_ name: String) {
        userName = name
    }
    
    func markPrivacyNoticeAsShown() {
        hasShownPrivacyNotice = true
    }
} 