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
    @State private var reminderTimes: [Date] = []
    @State private var notes: String = ""
    @State private var enableNotification: Bool = true
    @State private var pillCountString: String = ""
    @State private var pillsPerDoseString: String = "1"
    @State private var refillThresholdString: String = ""
    @State private var trackPillCount: Bool = false
    
    // For dynamically adjusting scroll position when keyboard appears
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, dosage, frequency, notes, pillCount, pillsPerDose, refillThreshold
    }

    let frequencies = ["Once daily", "Twice daily", "Three times daily", "Four times daily", "As needed", "Every 4 hours", "Every 6 hours"]

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#404C42")
                    .ignoresSafeArea()
                
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header
                            Text("Add New Medication")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .padding(.top, 15)
                            
                            // Basic information fields
                            simpleInputField(title: "Medication Name", text: $name, field: .name)
                                .id(Field.name)
                            
                            simpleInputField(title: "Dosage (e.g., 50mg)", text: $dosage, field: .dosage)
                                .id(Field.dosage)
                            
                            // Frequency picker
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Frequency")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                Menu {
                                    ForEach(frequencies, id: \.self) { freq in
                                        Button(freq) {
                                            self.frequency = freq
                                            setupReminderTimesForFrequency(freq)
                                            focusedField = .notes
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(frequency.isEmpty ? "Select frequency" : frequency)
                                            .foregroundColor(frequency.isEmpty ? Color(hex: "#C7C7BD").opacity(0.5) : Color(hex: "#C7C7BD"))
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(4)
                                }
                            }
                            .id(Field.frequency)
                            
                            // Multiple Reminder Times
                            if needsMultipleReminders {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Reminder Times")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                    
                                    ForEach(0..<reminderTimes.count, id: \.self) { index in
                                        HStack {
                                            Text("Dose #\(index + 1):")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                                .frame(width: 70, alignment: .leading)
                                            
                                            DatePicker("", selection: $reminderTimes[index], displayedComponents: .hourAndMinute)
                                                .datePickerStyle(.compact)
                                                .labelsHidden()
                                                .colorScheme(.dark)
                                                .accentColor(Color.pillrAccent)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            } else {
                                // Single Reminder Time
                                if frequency != "As needed" {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Time to Take")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                        
                                        DatePicker("", selection: $timeToTake, displayedComponents: .hourAndMinute)
                                            .datePickerStyle(.compact)
                                            .labelsHidden()
                                            .colorScheme(.dark)
                                            .accentColor(Color.pillrAccent)
                                    }
                                }
                            }
                            
                            // Track Pill Count Toggle
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Track Pill Count", isOn: $trackPillCount)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .tint(Color.pillrAccent)
                            }
                            
                            if trackPillCount {
                                // Pill Count Fields
                                simpleInputField(title: "Total Pill Count", text: $pillCountString, field: .pillCount, keyboardType: .numberPad)
                                    .id(Field.pillCount)
                                
                                simpleInputField(title: "Pills Per Dose", text: $pillsPerDoseString, field: .pillsPerDose, keyboardType: .numberPad)
                                    .id(Field.pillsPerDose)
                                
                                simpleInputField(title: "Refill Reminder Threshold", text: $refillThresholdString, field: .refillThreshold, keyboardType: .numberPad)
                                    .id(Field.refillThreshold)
                            }
                            
                            // Notification Toggle
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Enable Reminder", isOn: $enableNotification)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .tint(Color.pillrAccent)
                            }
                            
                            // Notes
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Notes (Optional)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                TextEditor(text: $notes)
                                    .frame(height: horizontalSizeClass == .regular ? 120 : 80)
                                    .padding(6)
                                    .background(Color.black.opacity(0.2))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .cornerRadius(4)
                                    .focused($focusedField, equals: .notes)
                            }
                            .id(Field.notes)

                            // Add button
                            Button {
                                saveMedication()
                            } label: {
                                Text("Add Medication")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isFormValid ? Color.pillrAccent.opacity(0.5) : Color.black.opacity(0.4))
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(hex: "#C7C7BD").opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .disabled(!isFormValid)
                            .opacity(isFormValid ? 1.0 : 0.6)
                            .padding(.top, 10)
                            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 20)
                        }
                        .padding(.horizontal, 16)
                    }
                    .onChange(of: focusedField) { field in
                        if let field = field {
                            withAnimation {
                                scrollProxy.scrollTo(field, anchor: .top)
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
    
    // Check if we need multiple reminder fields
    private var needsMultipleReminders: Bool {
        switch frequency {
        case "Twice daily", "Three times daily", "Four times daily":
            return true
        default:
            return false
        }
    }
    
    // Setup reminder times based on the frequency
    private func setupReminderTimesForFrequency(_ frequency: String) {
        let calendar = Calendar.current
        
        switch frequency {
        case "Twice daily":
            let morningTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
            let eveningTime = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
            reminderTimes = [morningTime, eveningTime]
            enableNotification = true
            
        case "Three times daily":
            let morningTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
            let middayTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date()
            let eveningTime = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
            reminderTimes = [morningTime, middayTime, eveningTime]
            enableNotification = true
            
        case "Four times daily":
            let earlyMorningTime = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: Date()) ?? Date()
            let middayTime = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
            let afternoonTime = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
            let bedtimeTime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
            reminderTimes = [earlyMorningTime, middayTime, afternoonTime, bedtimeTime]
            enableNotification = true
            
        case "As needed":
            reminderTimes = []
            enableNotification = false
            
        default:
            // For once daily or other frequencies, use a single time
            reminderTimes = []
            enableNotification = true
        }
    }
    
    // Form validation status
    private var isFormValid: Bool {
        let basicValid = !name.isEmpty && !dosage.isEmpty && !frequency.isEmpty
        
        if needsMultipleReminders && reminderTimes.isEmpty {
            return false
        }
        
        if trackPillCount {
            // If pill count tracking is enabled, ensure these fields have valid values
            let pillCountValid = !pillCountString.isEmpty && Int(pillCountString) != nil
            let pillsPerDoseValid = !pillsPerDoseString.isEmpty && Int(pillsPerDoseString) != nil && Int(pillsPerDoseString)! > 0
            
            return basicValid && pillCountValid && pillsPerDoseValid
        }
        
        return basicValid
    }
    
    @ViewBuilder
    private func simpleInputField(title: String, text: Binding<String>, field: Field, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD"))
            
            TextField("Enter \(title.lowercased())", text: text)
                .keyboardType(keyboardType)
                .padding(8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(hex: "#C7C7BD").opacity(0.1), lineWidth: 1)
                )
                .focused($focusedField, equals: field)
                .submitLabel(field == .name ? .next : .done)
                .onSubmit {
                    switch field {
                    case .name: focusedField = .dosage
                    case .dosage: focusedField = .frequency
                    case .frequency: focusedField = .notes
                    case .notes:
                        if trackPillCount { focusedField = .pillCount }
                        else { focusedField = nil }
                    case .pillCount: focusedField = .pillsPerDose
                    case .pillsPerDose: focusedField = .refillThreshold
                    case .refillThreshold: focusedField = nil
                    }
                }
        }
    }

    private func saveMedication() {
        let pillCount = trackPillCount ? Int(pillCountString) : nil
        let pillsPerDose = trackPillCount ? (Int(pillsPerDoseString) ?? 1) : 1
        let refillThreshold = trackPillCount && !refillThresholdString.isEmpty ? Int(refillThresholdString) : nil
        
        store.addMedication(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
            frequency: frequency,
            timeToTake: timeToTake,
            reminderTimes: needsMultipleReminders ? reminderTimes : [],
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            enableNotification: enableNotification,
            pillCount: pillCount,
            pillsPerDose: pillsPerDose,
            refillThreshold: refillThreshold
        )
        
        onAdd()
    }
}