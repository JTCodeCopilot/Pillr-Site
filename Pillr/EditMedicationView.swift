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
        GeometryReader { geometry in
            ZStack {
                // Set background to specified color
                Color(hex: "#404C42")
                    .ignoresSafeArea()
                
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Edit Medication")
                                .font(.headline)
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .padding(.top, 8)
                                .padding(.bottom, 8)
                            
                            // Medication Name
                            Text("Medication Name")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "#C7C7BD"))
                            
                            TextField("Enter medication name", text: $name)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(8)
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .id(Field.name)
                            
                            // Dosage
                            Text("Dosage (e.g., 50mg)")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "#C7C7BD"))
                            
                            TextField("Enter dosage (e.g., 50mg)", text: $dosage)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(8)
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .focused($focusedField, equals: .dosage)
                                .submitLabel(.next)
                                .id(Field.dosage)
                            
                            // Frequency
                            Text("Frequency")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "#C7C7BD"))
                            
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
                                    Text(frequency.isEmpty ? "Select frequency" : frequency)
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity)
                            }
                            .id(Field.frequency)
                            
                            // Only show time picker if not "As needed"
                            if frequency != "As needed" {
                                // Time to Take
                                Text("Time to Take")
                                    .font(.subheadline)
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                HStack {
                                    Text("\(formatTime(timeToTake))")
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                        .background(Color.black.opacity(0.2))
                                        .cornerRadius(8)
                                    
                                    Spacer()
                                }
                                .onTapGesture {
                                    // This would ideally open a time picker
                                    // For now, we'll keep the date picker below
                                }
                                
                                DatePicker("", selection: $timeToTake, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding(.top, -8)
                                    .accentColor(Color.pillrAccent)
                                    .frame(maxWidth: 120)
                                
                                // Enable Reminder
                                HStack {
                                    Text("Enable Reminder")
                                        .font(.subheadline)
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $enableNotification)
                                        .labelsHidden()
                                        .toggleStyle(SwitchToggleStyle(tint: Color.pillrAccent))
                                }
                            } else {
                                // Show a subtle message for "As needed" medications
                                Text("This medication will be taken only when needed")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                    .padding(.bottom, 8)
                            }
                            
                            // Notes
                            Text("Notes (Optional)")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "#C7C7BD"))
                            
                            TextEditor(text: $notes)
                                .frame(height: 120)
                                .scrollContentBackground(.hidden)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(8)
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .focused($focusedField, equals: .notes)
                                .id(Field.notes)
                            
                            // Update Button
                            Button {
                                updateMedication()
                            } label: {
                                Text("Update Medication")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(isFormValid ? Color.pillrAccent : Color.gray.opacity(0.5))
                                    .cornerRadius(8)
                            }
                            .disabled(!isFormValid)
                            .padding(.top, 10)
                            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 20)
                        }
                        .padding(.horizontal, 20)
                        .onChange(of: focusedField) { field in
                            if let field = field {
                                withAnimation {
                                    scrollProxy.scrollTo(field, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
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
    
    private func updateMedication() {
        // Create an updated medication, keeping the original id
        var updatedMedication = Medication(
            id: medication.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
            frequency: frequency,
            // For "As needed" medications, set a default time but it won't be used
            timeToTake: frequency == "As needed" ? Date() : timeToTake,
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            notificationID: medication.notificationID
        )
        
        // Update the medication in the store
        // For "As needed", always disable notifications
        store.updateMedication(updatedMedication, enableNotification: frequency == "As needed" ? false : enableNotification)
        
        onUpdate()
        dismiss()
    }
} 