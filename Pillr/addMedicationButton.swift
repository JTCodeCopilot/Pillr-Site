//
//  addMedicationButton.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

/// A styled button with glassmorphism effects for adding a medication
struct AddMedicationButtonView: View {
    var isFormValid: Bool
    var action: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        Button(action: action) {
            Text("Add Medication")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.white)
                .padding(.vertical, horizontalSizeClass == .regular ? 16 : 14)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            isFormValid ? Color.purple.opacity(0.7) : Color.gray.opacity(0.3),
                            isFormValid ? Color.blue.opacity(0.6) : Color.gray.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .buttonStyle(HapticButtonStyle(style: isFormValid ? .success : .soft))
        .disabled(!isFormValid)
        .opacity(isFormValid ? 1.0 : 0.6)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .gyroGlassCardStyle(
            cornerRadius: 18,
            material: .ultraThinMaterial,
            borderColor: isFormValid ? Color.white.opacity(0.4) : Color.white.opacity(0.2),
            borderWidth: isFormValid ? 1.2 : 0.8,
            adaptivePadding: false,
            shadowOpacity: isFormValid ? 0.25 : 0.15,
            shadowRadius: 12,
            shineOpacity: isFormValid ? 0.7 : 0.3,
            shineIntensity: isFormValid ? 1.2 : 0.6
        )
    }
} 
