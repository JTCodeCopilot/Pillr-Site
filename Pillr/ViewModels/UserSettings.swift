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
    
    @Published var isFirstLaunch: Bool {
        didSet {
            if !isPreviewMode {
                UserDefaults.standard.set(!isFirstLaunch, forKey: hasLaunchedBeforeKey)
            }
        }
    }
    
    private let userNameKey = "userName"
    private let hasLaunchedBeforeKey = "hasLaunchedBefore"
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
            self.isFirstLaunch = false
        } else {
            // Load user name if available, otherwise use default
            self.userName = UserDefaults.standard.string(forKey: userNameKey) ?? "User"
            
            // Check if this is first launch
            self.isFirstLaunch = !UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
        }
    }
    
    func saveUserName(_ name: String) {
        userName = name
    }
} 