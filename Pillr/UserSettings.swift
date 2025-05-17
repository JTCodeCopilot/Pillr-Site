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
            UserDefaults.standard.set(userName, forKey: userNameKey)
        }
    }
    
    @Published var isFirstLaunch: Bool {
        didSet {
            UserDefaults.standard.set(!isFirstLaunch, forKey: hasLaunchedBeforeKey)
        }
    }
    
    private let userNameKey = "userName"
    private let hasLaunchedBeforeKey = "hasLaunchedBefore"
    
    static let shared = UserSettings()
    
    init() {
        // Load user name if available, otherwise use default
        self.userName = UserDefaults.standard.string(forKey: userNameKey) ?? "User"
        
        // Check if this is first launch
        self.isFirstLaunch = !UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
    }
    
    func saveUserName(_ name: String) {
        userName = name
    }
} 