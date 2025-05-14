//
//  LogMedicationView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI

struct LogMedicationView: View {
    @EnvironmentObject var store: MedicationStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let medicationToLog: Medication
    @State private var actualTimeTaken: Date = Date()
    @State private var logNotes: String = ""
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Use the same background as ContentView for consistency in sheets
                    LinearGradient.pillrBackground
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: calculateVerticalSpacing(for: geometry)) {
                            Text("Log: \(medicationToLog.name)")
                                .font(horizontalSizeClass == .regular ? .title : .title2).bold()
                                .foregroundColor(.white)
                                .padding(.top)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading) {
                                Text("Time Taken")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.9))
                                DatePicker("Time Taken", selection: $actualTimeTaken)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding(10)
                                    .background(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Material.ultraThinMaterial)
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.pillrNavy.opacity(0.1))
                                        }
                                    )
                                    .cornerRadius(10)
                                    .colorScheme(.dark)
                                    .accentColor(.cyan)
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
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }

                            VStack(alignment: .leading) {
                                Text("Notes (Optional)")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.9))
                                TextEditor(text: $logNotes)
                                    .frame(height: calculateTextEditorHeight(for: geometry))
                                    .glassTextEditorStyle()
                            }

                            Button {
                                store.logMedicationTaken(medication: medicationToLog, actualTime: actualTimeTaken, notes: logNotes.isEmpty ? nil : logNotes)
                                dismiss()
                            } label: {
                                Text("Confirm Log")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.pillrNavy.opacity(1.2))
                                    .cornerRadius(15)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 20 : 0)
                        }
                        .padding(calculateHorizontalPadding(for: geometry))
                        .gyroGlassCardStyle(
                            cornerRadius: 25, 
                            material: .regularMaterial, 
                            borderColor: Color.white.opacity(0.25),
                            shadowOpacity: 0.18,
                            shadowRadius: 15,
                            shineOpacity: 0.5
                        )
                        .padding(calculateHorizontalPadding(for: geometry))
                        .frame(
                            width: calculateMaxWidth(for: geometry),
                            alignment: .center
                        )
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .background(LinearGradient.pillrBackground.ignoresSafeArea())
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        keyboardHeight = keyboardFrame.height
                    }
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    keyboardHeight = 0
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // Calculate adaptive spacing values
    private func calculateVerticalSpacing(for geometry: GeometryProxy) -> CGFloat {
        horizontalSizeClass == .regular ? 25 : 20
    }
    
    private func calculateHorizontalPadding(for geometry: GeometryProxy) -> CGFloat {
        if horizontalSizeClass == .regular {
            return 24 // iPad
        } else {
            return geometry.size.width < 375 ? 12 : 16 // Small vs regular phone
        }
    }
    
    private func calculateMaxWidth(for geometry: GeometryProxy) -> CGFloat {
        if horizontalSizeClass == .regular && geometry.size.width > 768 {
            return 650 // Constrain width on larger iPads
        }
        return geometry.size.width // Full width on phones
    }
    
    private func calculateTextEditorHeight(for geometry: GeometryProxy) -> CGFloat {
        if horizontalSizeClass == .regular {
            return 150 // Taller on iPad
        } else {
            // Adjust based on screen size for phones
            return geometry.size.height < 700 ? 80 : 100
        }
    }
}