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
    @Environment(\.colorScheme) private var colorScheme
    var onAdd: () -> Void

    @State private var name: String = ""
    @State private var dosage: String = ""
    @State private var frequency: String = ""
    @State private var timeToTake: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var notes: String = ""
    @State private var enableNotification: Bool = true
    
    // For dynamically adjusting scroll position when keyboard appears
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, dosage, frequency, notes
    }

    let frequencies = ["Once daily", "Twice daily", "As needed", "Every 4 hours", "Every 6 hours"]

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Use the same background as ContentView for consistency
                    LinearGradient.pillrBackground
                        .ignoresSafeArea()
                    
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(spacing: calculateVerticalSpacing(for: geometry)) {
                                
                                Text("Add New Medication")
                                    .font(horizontalSizeClass == .regular ? .title : .title2).bold()
                                    .foregroundColor(.white)
                                    .padding(.top)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                inputField(title: "Medication Name", text: $name, field: .name)
                                    .id(Field.name)
                                
                                inputField(title: "Dosage (e.g., 50mg)", text: $dosage, field: .dosage)
                                    .id(Field.dosage)
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Frequency")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.9))
                                    Menu {
                                        ForEach(frequencies, id: \.self) { freq in
                                            Button(freq) {
                                                self.frequency = freq
                                                focusedField = .notes
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(frequency.isEmpty ? "Select frequency" : frequency)
                                                .foregroundColor(frequency.isEmpty ? .white.opacity(0.5) : .white)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 10)
                                        .background(
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Material.ultraThinMaterial)
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.pillrNavy.opacity(0.1))
                                            }
                                        )
                                        .cornerRadius(10)
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
                                    }
                                    .accessibilityLabel("Frequency")
                                    .accessibilityValue(frequency.isEmpty ? "Not selected" : frequency)
                                }
                                .focused($focusedField, equals: .frequency)
                                .id(Field.frequency)
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Time to Take")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    DatePicker("Time to Take", selection: $timeToTake, displayedComponents: .hourAndMinute)
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
                                        .accentColor(Color.pillrAccent)
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
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Time to take medication")
                                .accessibilityValue(formatTime(timeToTake))
                                
                                // Notification Toggle
                                VStack(alignment: .leading, spacing: 5) {
                                    Toggle(isOn: $enableNotification) {
                                        Text("Enable Reminder")
                                            .font(.headline)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: Color.pillrAccent))
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
                                    
                                    if enableNotification {
                                        Text("You'll receive a notification at the scheduled time")
                                            .font(.footnote)
                                            .foregroundColor(.white.opacity(0.7))
                                            .padding(.horizontal, 10)
                                            .padding(.bottom, 5)
                                    }
                                }
                                .accessibilityLabel("Enable medication reminder notifications")

                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Notes (Optional)")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.9))
                                    TextEditor(text: $notes)
                                        .frame(height: calculateTextEditorHeight(for: geometry))
                                        .glassTextEditorStyle()
                                        .focused($focusedField, equals: .notes)
                                }
                                .id(Field.notes)

                                Button {
                                    saveMedication()
                                } label: {
                                    Text("Add Medication")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(isFormValid ? Color.pillrAccent : Color.pillrNavy.opacity(0.8))
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
                                
                                // Add extra padding at the bottom for keyboard
                                if keyboardHeight > 0 {
                                    Spacer()
                                        .frame(height: keyboardHeight)
                                }
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
                        .onChange(of: focusedField) { field in
                            if let field = field {
                                withAnimation {
                                    scrollProxy.scrollTo(field, anchor: .top)
                                }
                            }
                        }
                    }
                }
                .background(LinearGradient.pillrBackground.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
                .onAppear {
                    NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                            keyboardHeight = keyboardFrame.height
                        }
                    }
                    
                    NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                        keyboardHeight = 0
                    }
                    
                    // Auto-focus the name field when view appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        focusedField = .name
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }
    
    // Form validation status
    private var isFormValid: Bool {
        return !name.isEmpty && !dosage.isEmpty && !frequency.isEmpty
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
    
    // Format time for accessibility
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    @ViewBuilder
    private func inputField(title: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
            TextField("Enter \(title.lowercased())", text: text)
                .textFieldStyle(GlassTextFieldStyle())
                .focused($focusedField, equals: field)
                .submitLabel(field == .name ? .next : .done)
                .onSubmit {
                    switch field {
                    case .name:
                        focusedField = .dosage
                    case .dosage:
                        focusedField = .frequency
                    case .frequency:
                        focusedField = .notes
                    case .notes:
                        focusedField = nil
                    }
                }
        }
    }

    private func saveMedication() {
        store.addMedication(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
            frequency: frequency,
            timeToTake: timeToTake,
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            enableNotification: enableNotification
        )
        
        // Reset form
        name = ""
        dosage = ""
        frequency = ""
        timeToTake = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        notes = ""
        enableNotification = true
        
        onAdd()
    }
}