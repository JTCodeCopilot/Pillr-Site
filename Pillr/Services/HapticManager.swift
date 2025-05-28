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
    
    // MARK: - Impact Feedback
    
    func lightImpact() {
        lightImpactFeedbackGenerator.impactOccurred()
        lightImpactFeedbackGenerator.prepare()
    }
    
    func mediumImpact() {
        mediumImpactFeedbackGenerator.impactOccurred()
        mediumImpactFeedbackGenerator.prepare()
    }
    
    func heavyImpact() {
        heavyImpactFeedbackGenerator.impactOccurred()
        heavyImpactFeedbackGenerator.prepare()
    }
    
    func softImpact() {
        softImpactFeedbackGenerator.impactOccurred()
        softImpactFeedbackGenerator.prepare()
    }
    
    func rigidImpact() {
        rigidImpactFeedbackGenerator.impactOccurred()
        rigidImpactFeedbackGenerator.prepare()
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
        // Create a pulse effect with light impacts
        lightImpactFeedbackGenerator.impactOccurred()
        
        // Queue a second pulse after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.lightImpactFeedbackGenerator.impactOccurred()
            self?.lightImpactFeedbackGenerator.prepare()
        }
    }
    
    func pulseMedium() {
        // Create a pulse effect with medium impacts
        mediumImpactFeedbackGenerator.impactOccurred()
        
        // Queue a second pulse after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.mediumImpactFeedbackGenerator.impactOccurred()
            self?.mediumImpactFeedbackGenerator.prepare()
        }
    }
    
    func pulseRigid() {
        // Create a strong pulse effect with rigid impacts
        rigidImpactFeedbackGenerator.impactOccurred()
        
        // Queue a second pulse after a very short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.rigidImpactFeedbackGenerator.impactOccurred()
            self?.rigidImpactFeedbackGenerator.prepare()
        }
    }
    
    func pulseButton() {
        // Optimized pulse feedback for buttons
        softImpactFeedbackGenerator.impactOccurred()
        
        // Queue a second soft impact for a tactile pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { [weak self] in
            self?.lightImpactFeedbackGenerator.impactOccurred()
            self?.lightImpactFeedbackGenerator.prepare()
        }
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
