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
    var borderColor: Color = Color.white.opacity(0.08)  // Even more subtle
    var borderWidth: CGFloat = 0.8  // Thinner border
    var adaptivePadding: Bool = true
    var shadowOpacity: Double = 0.08  // Reduced shadow
    var shadowRadius: CGFloat = 8
    var shineOpacity: Double = 0.25  // Reduced shine
    var shineIntensity: Double = 0.5  // Reduced intensity
    var shimmerSpeed: Double = 0.7
    
    @StateObject private var motionManager = MotionManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var shimmerOffset: CGFloat = 0
    
    // Timer for subtle shimmer animation - only runs if reduced motion is off
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

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
                            // Only show gyroscope effects if reduced motion is off
                            if !reducedMotion {
                                // Convert motion to normalized coordinates with natural dampening
                                let normalizedRoll = min(max(((motionManager.roll / .pi * 3) + 0.5) * 0.8, 0), 1)
                                let normalizedPitch = min(max(((motionManager.pitch / .pi * 3) + 0.5) * 0.8, 0), 1)
                                
                                // Calculate shimmer direction based on device motion
                                let dynamicShimmerX = normalizedRoll * 0.6
                                let dynamicShimmerY = normalizedPitch * 0.6
                                let gyroShimmerOffset = (shimmerOffset + (normalizedRoll + normalizedPitch) * 10).truncatingRemainder(dividingBy: 360)
                                
                                // Main highlight - adapts to color scheme
                                ZStack {
                                    // Edge shine that follows gyroscope movement
                                    RoundedRectangle(cornerRadius: cornerRadius)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [
                                                    Color(hex: colorScheme == .dark ? "#D8B4F8" : "#D8B4F8").opacity(shineOpacity * 0.15 * shineIntensity),
                                                    Color(hex: colorScheme == .dark ? "#D8B4F8" : "#D8B4F8").opacity(shineOpacity * 0.3 * normalizedRoll * shineIntensity),
                                                    Color(hex: colorScheme == .dark ? "#D8B4F8" : "#D8B4F8").opacity(shineOpacity * 0.1 * shineIntensity),
                                                    Color(hex: colorScheme == .dark ? "#D8B4F8" : "#D8B4F8").opacity(shineOpacity * 0.2 * normalizedPitch * shineIntensity)
                                                ],
                                                startPoint: UnitPoint(x: 0.2 + (normalizedRoll * 0.6), y: 0.1 + (normalizedPitch * 0.2)),
                                                endPoint: UnitPoint(x: 0.8 - (normalizedPitch * 0.3), y: 0.9 - (normalizedRoll * 0.3))
                                            ),
                                            lineWidth: borderWidth * 1.2
                                        )
                                    
                                    // Shimmer highlight with reduced intensity for better focus
                                    RoundedRectangle(cornerRadius: cornerRadius)
                                        .strokeBorder(
                                            AngularGradient(
                                                gradient: Gradient(colors: [
                                                    Color.clear,
                                                    Color.white.opacity(0.01 * shineIntensity * (1 + normalizedRoll)),
                                                    Color.white.opacity(0.04 * shineIntensity * (1 + normalizedPitch)),
                                                    Color.white.opacity(0.01 * shineIntensity * (1 + normalizedRoll)),
                                                    Color.clear
                                                ]),
                                                center: UnitPoint(x: 0.3 + normalizedRoll * 0.4, y: 0.3 + normalizedPitch * 0.4),
                                                startAngle: .degrees(gyroShimmerOffset),
                                                endAngle: .degrees(gyroShimmerOffset + 270)
                                            ),
                                            lineWidth: borderWidth * 0.5
                                        )
                                }
                                .blendMode(.softLight)
                                .onReceive(timer) { _ in
                                    // Animate the shimmer effect with speed influenced by motion
                                    let motionIntensity = sqrt(pow(motionManager.roll, 2) + pow(motionManager.pitch, 2))
                                    let adjustedSpeed = shimmerSpeed * (1 + motionIntensity)
                                    
                                    withAnimation(.linear(duration: 0.05)) {
                                        shimmerOffset = (shimmerOffset + 0.5 * adjustedSpeed).truncatingRemainder(dividingBy: 100)
                                    }
                                }
                            }
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
            .shadow(color: Color(hex: colorScheme == .dark ? "#D8B4F8" : "#D8B4F8").opacity(0.15), radius: 2, x: 0, y: 1) // Inner shadow at top
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 2, x: 0, y: -1) // Inner shadow at bottom
    }
}

struct GlassViewModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var frostedMaterial: Material = .ultraThinMaterial
    var borderColor: Color = Color.white.opacity(0.08)  // Match gyro version
    var borderWidth: CGFloat = 0.8  // Match gyro version
    var adaptivePadding: Bool = true
    var shadowOpacity: Double = 0.08  // Match gyro version
    var shadowRadius: CGFloat = 8  // Match gyro version
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

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
                                borderColor.opacity(0.3),
                                borderColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
            )
            .shadow(color: Color(hex: colorScheme == .dark ? "#D8B4F8" : "#D8B4F8").opacity(0.05), radius: 2, x: 0, y: 1) // Inner shadow at top
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
        shineOpacity: Double = 0.5,
        shineIntensity: Double = 1.0,
        shimmerSpeed: Double = 1.0
    ) -> some View {
        self.modifier(GyroGlassViewModifier(
            cornerRadius: cornerRadius,
            frostedMaterial: material,
            borderColor: borderColor,
            borderWidth: borderWidth,
            adaptivePadding: adaptivePadding,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shineOpacity: shineOpacity,
            shineIntensity: shineIntensity,
            shimmerSpeed: shimmerSpeed
        ))
    }
}

// Helper for consistent styling of text inputs
struct GlassTextFieldStyle: TextFieldStyle {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, horizontalSizeClass == .regular ? 12 : 10)
            .padding(.horizontal, horizontalSizeClass == .regular ? 14 : 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Material.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.05, green: 0.05, blue: 0.05).opacity(0.03))
                }
            )
            .cornerRadius(10)
            .foregroundColor(colorScheme == .dark ? .white : .primary)
            .accentColor(Color(hex: "#D8B4F8").opacity(0.8)) // Cursor color
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.2 : 0.15),
                                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: Color(hex: "#D8B4F8").opacity(0.04), radius: 2, x: 0, y: 1) // Inner shadow at top
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: -1) // Inner shadow at bottom
            .font(horizontalSizeClass == .regular ? .body : .callout)
    }
}

// Text editor glass style for consistent look
struct GlassTextEditorStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(5)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Material.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.05, green: 0.05, blue: 0.05).opacity(0.03))
                }
            )
            .cornerRadius(10)
            .foregroundColor(colorScheme == .dark ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.2 : 0.15),
                                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: Color(hex: "#D8B4F8").opacity(0.04), radius: 2, x: 0, y: 1) // Inner shadow at top
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: -1) // Inner shadow at bottom
    }
}

extension View {
    func glassTextEditorStyle() -> some View {
        self.modifier(GlassTextEditorStyle())
    }
}

// Simplified version for previews
struct PreviewGlassViewModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var frostedMaterial: Material = .ultraThinMaterial
    var borderColor: Color = Color.white.opacity(0.08)
    var borderWidth: CGFloat = 0.8
    
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(frostedMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
}

extension View {
    // Add a preview-friendly glass style
    func previewGlassStyle(
        cornerRadius: CGFloat = 20,
        material: Material = .ultraThinMaterial
    ) -> some View {
        self.modifier(PreviewGlassViewModifier(
            cornerRadius: cornerRadius,
            frostedMaterial: material
        ))
    }
    
    // Add check for preview environment
    @ViewBuilder
    func optimizedGlassCardStyle(
        cornerRadius: CGFloat = 20,
        material: Material = .ultraThinMaterial,
        borderColor: Color = Color.white.opacity(0.2),
        borderWidth: CGFloat = 1.5
    ) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            self.previewGlassStyle(cornerRadius: cornerRadius, material: material)
        } else {
            self.glassCardStyle(
                cornerRadius: cornerRadius,
                material: material,
                borderColor: borderColor,
                borderWidth: borderWidth
            )
        }
        #else
        self.glassCardStyle(
            cornerRadius: cornerRadius,
            material: material,
            borderColor: borderColor,
            borderWidth: borderWidth
        )
        #endif
    }
}
