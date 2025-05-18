//
//  EditMedicationView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI

struct EditMedicationView: View {
    @EnvironmentObject var store: MedicationStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    
    // Passed-in medication to edit
    var medication: Medication
    var onUpdate: () -> Void
    
    // State for editing
    @State private var name: String
    @State private var dosage: String
    @State private var frequency: String
    @State private var timeToTake: Date
    @State private var notes: String
    @State private var enableNotification: Bool
    
    // For dynamically adjusting scroll position when keyboard appears
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, dosage, frequency, notes
    }

    let frequencies = ["Once daily", "Twice daily", "As needed", "Every 4 hours", "Every 6 hours"]
    
    // Initialize with the medication's existing values
    init(medication: Medication, onUpdate: @escaping () -> Void) {
        self.medication = medication
        self.onUpdate = onUpdate
        
        // Initialize state variables with existing medication values
        _name = State(initialValue: medication.name)
        _dosage = State(initialValue: medication.dosage)
        _frequency = State(initialValue: medication.frequency)
        _timeToTake = State(initialValue: medication.timeToTake)
        _notes = State(initialValue: medication.notes ?? "")
        _enableNotification = State(initialValue: medication.notificationID != nil)
    }

    var body: some View {
        ZStack {
            Color(hex: "#404C42")
                .ignoresSafeArea()
            
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        Text("Edit Medication")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .padding(.top, 16)
                        
                        // Basic information fields
                        VStack(alignment: .leading) {
                            Text("MEDICATION INFO")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                .padding(.bottom, 8)
                            
                            systemInputField(
                                title: "Name", 
                                placeholder: "Enter medication name",
                                text: $name, 
                                field: .name,
                                iconName: "pill"
                            )
                            .id(Field.name)
                            
                            Divider()
                                .background(Color(hex: "#C7C7BD").opacity(0.2))
                            
                            systemInputField(
                                title: "Dosage", 
                                placeholder: "e.g., 50mg", 
                                text: $dosage, 
                                field: .dosage,
                                iconName: "measure"
                            )
                            .id(Field.dosage)
                        }
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(10)
                        
                        // Frequency picker
                        VStack(alignment: .leading) {
                            Text("SCHEDULE")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                .padding(.bottom, 8)
                            
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .frame(width: 25, alignment: .center)
                                
                                Text("Frequency")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                Spacer()
                                
                                Menu {
                                    ForEach(frequencies, id: \.self) { freq in
                                        Button(action: {
                                            self.frequency = freq
                                            // Disable notifications if "As needed" is selected
                                            if freq == "As needed" {
                                                enableNotification = false
                                            }
                                        }) {
                                            HStack {
                                                Text(freq)
                                                if frequency == freq {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(frequency.isEmpty ? "Select" : frequency)
                                            .foregroundColor(frequency.isEmpty ? Color(hex: "#C7C7BD").opacity(0.6) : Color(hex: "#C7C7BD"))
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            
                            // Only show time picker if not "As needed"
                            if frequency != "As needed" {
                                Divider()
                                    .background(Color(hex: "#C7C7BD").opacity(0.2))
                                
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                        .frame(width: 25, alignment: .center)
                                    
                                    Text("Time to Take")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                    
                                    Spacer()
                                    
                                    DatePicker("", selection: $timeToTake, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        .accentColor(Color(hex: "#C7C7BD"))
                                }
                                .padding(.vertical, 8)
                                
                                Divider()
                                    .background(Color(hex: "#C7C7BD").opacity(0.2))
                                
                                // Enable Reminder
                                Toggle(isOn: $enableNotification) {
                                    HStack {
                                        Image(systemName: "bell.badge")
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                            .frame(width: 25, alignment: .center)
                                        
                                        Text("Enable Reminder")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                .padding(.vertical, 8)
                            } else {
                                // Show a subtle message for "As needed" medications
                                Divider()
                                    .background(Color(hex: "#C7C7BD").opacity(0.2))
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                        .frame(width: 25, alignment: .center)
                                    
                                    Text("No scheduled reminders needed")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(10)
                        
                        // Notes
                        VStack(alignment: .leading) {
                            Text("NOTES")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                .padding(.bottom, 8)
                            
                            HStack(alignment: .top) {
                                Image(systemName: "note.text")
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .frame(width: 25, alignment: .center)
                                    .padding(.top, 3)
                                
                                TextEditor(text: $notes)
                                    .frame(minHeight: 100)
                                    .focused($focusedField, equals: .notes)
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .overlay(
                                        Group {
                                            if notes.isEmpty {
                                                Text("Optional notes")
                                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                                                    .padding(.top, 8)
                                                    .padding(.leading, 5)
                                                    .allowsHitTesting(false)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                    )
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(10)
                        .id(Field.notes)

                        // Update button
                        Button {
                            updateMedication()
                        } label: {
                            Text("Update Medication")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "#404C42"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isFormValid ? Color(hex: "#C7C7BD") : Color.gray)
                                .cornerRadius(10)
                        }
                        .disabled(!isFormValid)
                        .padding(.vertical, 10)
                        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 10)
                    }
                    .padding(.horizontal, 16)
                    .onChange(of: focusedField) { field in
                        if let field = field {
                            withAnimation {
                                scrollProxy.scrollTo(field, anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        updateMedication()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .disabled(!isFormValid)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
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
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                HStack {
                    Button(action: {
                        moveToPreviousField()
                    }) {
                        Image(systemName: "arrow.up")
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                    .disabled(!canMoveToPreviousField)
                    
                    Button(action: {
                        moveToNextField()
                    }) {
                        Image(systemName: "arrow.down")
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                    .disabled(!canMoveToNextField)
                    
                    Spacer()
                    
                    Button("Done") {
                        focusedField = nil
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
        }
    }
    
    // Helper function to format the time
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Validation to ensure required fields are not empty
    private var isFormValid: Bool {
        !name.isEmpty && !dosage.isEmpty && !frequency.isEmpty
    }
    
    // Field navigation helpers
    private var canMoveToPreviousField: Bool {
        guard let currentField = focusedField else { return false }
        switch currentField {
        case .name: return false  // Already at the first field
        case .dosage, .frequency, .notes: return true
        }
    }
    
    private var canMoveToNextField: Bool {
        guard let currentField = focusedField else { return false }
        switch currentField {
        case .name, .dosage, .frequency: return true
        case .notes: return false  // Already at the last field
        }
    }
    
    private func moveToPreviousField() {
        guard let currentField = focusedField else { return }
        switch currentField {
        case .name: break  // Already at the first field
        case .dosage: focusedField = .name
        case .frequency: focusedField = .dosage
        case .notes: focusedField = .frequency
        }
    }
    
    private func moveToNextField() {
        guard let currentField = focusedField else { return }
        switch currentField {
        case .name: focusedField = .dosage
        case .dosage: focusedField = .frequency
        case .frequency: focusedField = .notes
        case .notes: break  // Already at the last field
        }
    }

    @ViewBuilder
    private func systemInputField(title: String, placeholder: String, text: Binding<String>, field: Field, iconName: String? = nil) -> some View {
        HStack {
            if let iconName = iconName {
                Image(systemName: iconName)
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .frame(width: 25, alignment: .center)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                
                TextField(placeholder, text: text)
                    .focused($focusedField, equals: field)
                    .submitLabel(field == .name ? .next : .done)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .onSubmit {
                        switch field {
                        case .name: focusedField = .dosage
                        case .dosage: focusedField = .frequency
                        case .frequency: focusedField = .notes
                        case .notes: focusedField = nil
                        }
                    }
            }
        }
        .padding(.vertical, 8)
    }
    
    // Update the medication in the store
    private func updateMedication() {
        // Create an updated medication object with the new values
        var updatedMedication = medication
        updatedMedication.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMedication.dosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMedication.frequency = frequency
        updatedMedication.timeToTake = timeToTake
        updatedMedication.notes = notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update the medication in the store - should only be enabled if not "As needed"
        store.updateMedication(updatedMedication, enableNotification: enableNotification && frequency != "As needed")
        
        onUpdate()
        dismiss()
    }
} 
