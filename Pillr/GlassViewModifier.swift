//
//  GlassViewModifier.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI
import CoreMotion

// Manages device motion tracking for gyroscope effects
class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    
    static let shared = MotionManager()
    
    private init() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1/60
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
                guard let data = data, error == nil else { return }
                self?.pitch = data.attitude.pitch
                self?.roll = data.attitude.roll
            }
        }
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}

// Gyroscope-responsive glass effect
struct GyroGlassViewModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var frostedMaterial: Material = .ultraThinMaterial
    var borderColor: Color = Color.white.opacity(0.2)
    var borderWidth: CGFloat = 1.5
    var adaptivePadding: Bool = true
    var shadowOpacity: Double = 0.15
    var shadowRadius: CGFloat = 12
    var shineOpacity: Double = 0.5
    
    @StateObject private var motionManager = MotionManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .padding(adaptivePadding ? (horizontalSizeClass == .regular ? 16 : 12) : 16)
            .background(frostedMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                // Dynamic edge shine overlay that responds to device orientation
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(lineWidth: 0)
                    .overlay(
                        GeometryReader { geometry in
                            let width = geometry.size.width
                            let height = geometry.size.height
                            
                            // Convert motion to normalized coordinates with dampening
                            let normalizedRoll = ((motionManager.roll / .pi * 2) + 0.5) * 0.7
                            let normalizedPitch = ((motionManager.pitch / .pi * 2) + 0.5) * 0.7
                            
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(shineOpacity * 0.4),
                                            Color.white.opacity(shineOpacity * 0.7 * normalizedRoll),
                                            Color.white.opacity(shineOpacity * 0.2),
                                            Color.white.opacity(shineOpacity * 0.6 * normalizedPitch)
                                        ],
                                        startPoint: UnitPoint(x: 0.3 + (normalizedRoll * 0.4), y: 0.2),
                                        endPoint: UnitPoint(x: 0.7 + (normalizedPitch * 0.2), y: 0.8 + (normalizedRoll * 0.2))
                                    ),
                                    lineWidth: borderWidth * 0.8
                                )
                        }
                    )
                    .blendMode(.softLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                borderColor.opacity(0.6),
                                borderColor.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
            )
            .shadow(color: Color.white.opacity(0.15), radius: 2, x: 0, y: 1) // Inner shadow at top
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 2, x: 0, y: -1) // Inner shadow at bottom
    }
}

struct GlassViewModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var frostedMaterial: Material = .ultraThinMaterial
    var borderColor: Color = Color.white.opacity(0.2)
    var borderWidth: CGFloat = 1.5
    var adaptivePadding: Bool = true
    var shadowOpacity: Double = 0.15
    var shadowRadius: CGFloat = 12
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .padding(adaptivePadding ? (horizontalSizeClass == .regular ? 16 : 12) : 16)
            .background(frostedMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                borderColor.opacity(0.6),
                                borderColor.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
            )
            .shadow(color: Color.white.opacity(0.15), radius: 2, x: 0, y: 1) // Inner shadow at top
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 2, x: 0, y: -1) // Inner shadow at bottom
    }
}

extension View {
    func glassCardStyle(
        cornerRadius: CGFloat = 20,
        material: Material = .ultraThinMaterial,
        borderColor: Color = Color.white.opacity(0.2),
        borderWidth: CGFloat = 1.5,
        adaptivePadding: Bool = true,
        shadowOpacity: Double = 0.15,
        shadowRadius: CGFloat = 12
    ) -> some View {
        self.modifier(GlassViewModifier(
            cornerRadius: cornerRadius,
            frostedMaterial: material,
            borderColor: borderColor,
            borderWidth: borderWidth,
            adaptivePadding: adaptivePadding,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius
        ))
    }
    
    // Add gyro-responsive glass card style
    func gyroGlassCardStyle(
        cornerRadius: CGFloat = 20,
        material: Material = .ultraThinMaterial,
        borderColor: Color = Color.white.opacity(0.2),
        borderWidth: CGFloat = 1.5,
        adaptivePadding: Bool = true,
        shadowOpacity: Double = 0.15,
        shadowRadius: CGFloat = 12,
        shineOpacity: Double = 0.5
    ) -> some View {
        self.modifier(GyroGlassViewModifier(
            cornerRadius: cornerRadius,
            frostedMaterial: material,
            borderColor: borderColor,
            borderWidth: borderWidth,
            adaptivePadding: adaptivePadding,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shineOpacity: shineOpacity
        ))
    }
}

// Helper for consistent styling of text inputs
struct GlassTextFieldStyle: TextFieldStyle {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, horizontalSizeClass == .regular ? 12 : 10)
            .padding(.horizontal, horizontalSizeClass == .regular ? 14 : 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Material.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.18, green: 0.26, blue: 0.43).opacity(0.1))
                }
            )
            .cornerRadius(10)
            .foregroundColor(.white)
            .accentColor(.cyan) // Cursor color
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.white.opacity(0.15), radius: 2, x: 0, y: 1) // Inner shadow at top
            .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: -1) // Inner shadow at bottom
            .font(horizontalSizeClass == .regular ? .body : .callout)
    }
}

// Text editor glass style for consistent look
struct GlassTextEditorStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(5)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Material.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.18, green: 0.26, blue: 0.43).opacity(0.1))
                }
            )
            .cornerRadius(10)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.white.opacity(0.15), radius: 2, x: 0, y: 1) // Inner shadow at top
            .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: -1) // Inner shadow at bottom
    }
}

extension View {
    func glassTextEditorStyle() -> some View {
        self.modifier(GlassTextEditorStyle())
    }
}