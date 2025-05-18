//
//  HapticManager.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import UIKit
import SwiftUI

// Haptic feedback manager to provide consistent and soothing haptic 
// feedback throughout the application
class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // Light feedback for routine actions like button taps
    func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Medium feedback for more significant actions
    func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Heavy feedback for important actions
    func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Soft feedback for subtle interactions
    func softImpact() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Rigid feedback for actions that require attention
    func rigidImpact() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Success notification feedback
    func successNotification() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    // Warning notification feedback
    func warningNotification() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare() 
        generator.notificationOccurred(.warning)
    }
    
    // Error notification feedback
    func errorNotification() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    // Selection feedback
    func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

// SwiftUI Button extension to add haptic feedback
extension Button {
    func hapticFeedback(_ style: HapticStyle = .light) -> some View {
        self.onTapGesture {
            switch style {
            case .light:
                HapticManager.shared.lightImpact()
            case .medium:
                HapticManager.shared.mediumImpact()
            case .heavy:
                HapticManager.shared.heavyImpact()
            case .soft:
                HapticManager.shared.softImpact()
            case .rigid:
                HapticManager.shared.rigidImpact()
            case .success:
                HapticManager.shared.successNotification()
            case .warning:
                HapticManager.shared.warningNotification()
            case .error:
                HapticManager.shared.errorNotification()
            case .selection:
                HapticManager.shared.selectionChanged()
            }
        }
    }
}

// Haptic styles for the Button extension
enum HapticStyle {
    case light
    case medium
    case heavy
    case soft
    case rigid
    case success
    case warning
    case error
    case selection
}

// HapticButtonStyle - a SwiftUI ButtonStyle that includes haptic feedback
struct HapticFeedbackButtonStyle: ButtonStyle {
    let style: HapticStyle
    
    init(style: HapticStyle = .light) {
        self.style = style
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    switch style {
                    case .light:
                        HapticManager.shared.lightImpact()
                    case .medium:
                        HapticManager.shared.mediumImpact()
                    case .heavy:
                        HapticManager.shared.heavyImpact()
                    case .soft:
                        HapticManager.shared.softImpact()
                    case .rigid:
                        HapticManager.shared.rigidImpact()
                    case .success:
                        HapticManager.shared.successNotification()
                    case .warning:
                        HapticManager.shared.warningNotification()
                    case .error:
                        HapticManager.shared.errorNotification()
                    case .selection:
                        HapticManager.shared.selectionChanged()
                    }
                }
            }
    }
}

// Minimal Button Style - for buttons that need subtle feedback
struct MinimalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    HapticManager.shared.softImpact()
                }
            }
    }
}

// Extension to View to add haptic feedback modifier
extension View {
    func onTapWithHaptic(_ style: HapticStyle = .light, action: @escaping () -> Void) -> some View {
        self.onTapGesture {
            switch style {
            case .light:
                HapticManager.shared.lightImpact()
            case .medium:
                HapticManager.shared.mediumImpact()
            case .heavy:
                HapticManager.shared.heavyImpact()
            case .soft:
                HapticManager.shared.softImpact()
            case .rigid:
                HapticManager.shared.rigidImpact()
            case .success:
                HapticManager.shared.successNotification()
            case .warning:
                HapticManager.shared.warningNotification()
            case .error:
                HapticManager.shared.errorNotification()
            case .selection:
                HapticManager.shared.selectionChanged()
            }
            action()
        }
    }
} 
