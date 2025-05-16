//
//  addMedicationButton.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

/// A styled button with gradient effects for adding a medication
struct AddMedicationButtonView: View {
    var isFormValid: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Add Medication")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(isFormValid ? Color.purple : Color.white)
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isFormValid ? 1 : 0.5
                        )
                )
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .disabled(!isFormValid)
        .opacity(isFormValid ? 1.0 : 0.6)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
} 
