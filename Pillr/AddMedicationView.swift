//
//  AddMedicationView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI

struct AddMedicationView: View {
    @EnvironmentObject var store: MedicationStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var onAdd: () -> Void

    @State private var name: String = ""
    @State private var dosage: String = ""
    @State private var frequency: String = ""
    @State private var timeToTake: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var notes: String = ""
    
    // For dynamically adjusting scroll position when keyboard appears
    @State private var keyboardHeight: CGFloat = 0

    let frequencies = ["Once daily", "Twice daily", "As needed", "Every 4 hours", "Every 6 hours"]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Use the same background as ContentView for consistency
                LinearGradient.pillrBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: calculateVerticalSpacing(for: geometry)) {
                        
                        inputField(title: "Medication Name", text: $name)
                        inputField(title: "Dosage (e.g., 50mg)", text: $dosage)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Frequency")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.9))
                            Picker("Frequency", selection: $frequency) {
                                ForEach(frequencies, id: \.self) { freq in
                                    Text(freq).tag(freq)
                                }
                            }
                            .pickerStyle(.menu)
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
                        
                        DatePicker("Time to Take", selection: $timeToTake, displayedComponents: .hourAndMinute)
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

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Notes (Optional)")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.9))
                            TextEditor(text: $notes)
                                .frame(height: calculateTextEditorHeight(for: geometry))
                                .glassTextEditorStyle()
                        }

                        Button {
                            saveMedication()
                        } label: {
                            Text("Add Medication")
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
                        .disabled(name.isEmpty || dosage.isEmpty || frequency.isEmpty)
                        .opacity((name.isEmpty || dosage.isEmpty || frequency.isEmpty) ? 0.6 : 1.0)
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
            .background(Color.clear)
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
    
    @ViewBuilder
    private func inputField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
            TextField("Enter \(title.lowercased())", text: text)
                .textFieldStyle(GlassTextFieldStyle())
        }
    }

    func saveMedication() {
        store.addMedication(name: name, dosage: dosage, frequency: frequency, timeToTake: timeToTake, notes: notes.isEmpty ? nil : notes)
        onAdd()
        name = ""
        dosage = ""
        notes = ""
    }
}