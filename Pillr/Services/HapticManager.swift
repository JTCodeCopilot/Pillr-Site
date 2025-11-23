//
//  HapticManager.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import Foundation
import SwiftUI
import UIKit

// Haptic feedback manager to provide consistent and soothing haptic 
// feedback throughout the application
class HapticManager {
    static let shared = HapticManager()
    
    private let lightImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
    private let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
    
    private init() {
        // Prepare all generators in advance
        prepareGenerators()
    }
    
    func prepareGenerators() {
        lightImpactFeedbackGenerator.prepare()
        mediumImpactFeedbackGenerator.prepare()
        heavyImpactFeedbackGenerator.prepare()
        softImpactFeedbackGenerator.prepare()
        rigidImpactFeedbackGenerator.prepare()
        selectionFeedbackGenerator.prepare()
        notificationFeedbackGenerator.prepare()
    }

    private func triggerStrongImpact() {
        let generator = rigidImpactFeedbackGenerator
        generator.prepare()
        generator.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            generator.impactOccurred()
            generator.prepare()
        }
    }

    func strongImpact() {
        triggerStrongImpact()
    }
    
    // MARK: - Impact Feedback
    
    func lightImpact() {
        triggerStrongImpact()
    }
    
    func mediumImpact() {
        triggerStrongImpact()
    }
    
    func heavyImpact() {
        triggerStrongImpact()
    }
    
    func softImpact() {
        triggerStrongImpact()
    }
    
    func rigidImpact() {
        triggerStrongImpact()
    }
    
    // MARK: - Notification Feedback
    
    func successNotification() {
        notificationFeedbackGenerator.notificationOccurred(.success)
        notificationFeedbackGenerator.prepare()
    }
    
    func warningNotification() {
        notificationFeedbackGenerator.notificationOccurred(.warning)
        notificationFeedbackGenerator.prepare()
    }
    
    func errorNotification() {
        notificationFeedbackGenerator.notificationOccurred(.error)
        notificationFeedbackGenerator.prepare()
    }
    
    // MARK: - Selection Feedback
    
    func selectionChanged() {
        selectionFeedbackGenerator.selectionChanged()
        selectionFeedbackGenerator.prepare()
    }
    
    // MARK: - Pulsed Feedback
    
    func pulseLight() {
        strongImpact()
    }
    
    func pulseMedium() {
        strongImpact()
    }
    
    func pulseRigid() {
        strongImpact()
    }
    
    func pulseButton() {
        strongImpact()
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
            case .pulseLight:
                HapticManager.shared.pulseLight()
            case .pulseMedium:
                HapticManager.shared.pulseMedium()
            case .pulseRigid:
                HapticManager.shared.pulseRigid()
            case .pulseButton:
                HapticManager.shared.pulseButton()
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
    case pulseLight
    case pulseMedium
    case pulseRigid
    case pulseButton
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
                    case .pulseLight:
                        HapticManager.shared.pulseLight()
                    case .pulseMedium:
                        HapticManager.shared.pulseMedium()
                    case .pulseRigid:
                        HapticManager.shared.pulseRigid()
                    case .pulseButton:
                        HapticManager.shared.pulseButton()
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
                    HapticManager.shared.pulseLight()
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
            case .pulseLight:
                HapticManager.shared.pulseLight()
            case .pulseMedium:
                HapticManager.shared.pulseMedium()
            case .pulseRigid:
                HapticManager.shared.pulseRigid()
            case .pulseButton:
                HapticManager.shared.pulseButton()
            }
            action()
        }
    }
} 
