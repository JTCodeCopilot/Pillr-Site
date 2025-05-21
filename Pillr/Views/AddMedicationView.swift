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
    @State private var dosageUnit: String = "mg" // Default unit
    @State private var iconName: String = "pill.fill" // Default icon
    @State private var frequency: String = ""
    @State private var timeToTake: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var reminderTimes: [Date] = []
    @State private var notes: String = ""
    @State private var enableNotification: Bool = true
    @State private var pillCountString: String = ""
    @State private var pillsPerDoseString: String = "1"
    @State private var refillThresholdString: String = ""
    @State private var trackPillCount: Bool = false
    @State private var showMedicationSearch: Bool = false
    @State private var showPremiumUpsellSheet: Bool = false
    @State private var isOneTimeWithFollowUp: Bool = false
    
    // For dynamically adjusting scroll position when keyboard appears
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, dosage, frequency, notes, pillCount, pillsPerDose, refillThreshold
    }

    let frequencies = ["Once daily", "Twice daily", "Three times daily", "As needed"]
    let dosageUnits = ["mg", "ml"]

    @State private var showFrequencyPicker = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#404C42")
                    .ignoresSafeArea()
                
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header
                            Text("Add Medication")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                                .padding(.top, 16)
                            
                            // Basic information fields
                            VStack(alignment: .leading) {
                                Text("MEDICATION INFO")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                    .padding(.bottom, 8)
                                
                                HStack {
                                    systemInputField(
                                        title: "Name", 
                                        placeholder: "Enter medication name",
                                        text: $name, 
                                        field: .name,
                                        iconName: "pill"
                                    )
                                    
                                    Button(action: {
                                        if OpenAIService.shared.isPremiumMode {
                                            showMedicationSearch.toggle()
                                        } else {
                                            showPremiumUpsellSheet.toggle()
                                        }
                                    }) {
                                        if OpenAIService.shared.isPremiumMode {
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 18))
                                                .foregroundColor(Color(hex: "#C7C7BD"))
                                                .padding(6)
                                                .background(Color.black.opacity(0.2))
                                                .cornerRadius(8)
                                        } else {
                                            HStack(spacing: 4) {
                                                Image(systemName: "magnifyingglass")
                                                    .font(.system(size: 14))
                                                Text("Search")
                                                    .font(.system(size: 14, weight: .medium))
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.yellow)
                                            }
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(Color.black.opacity(0.2))
                                            .cornerRadius(8)
                                        }
                                    }
                                    .sheet(isPresented: $showMedicationSearch) {
                                        MedicationSearchView(selectedMedication: $name)
                                            .preferredColorScheme(.dark)
                                            .presentationDetents([.medium, .large])
                                            .presentationDragIndicator(.visible)
                                    }
                                }
                                .id(Field.name)
                                
                                Divider()
                                    .background(Color(hex: "#C7C7BD").opacity(0.2))
                                
                                systemInputField(
                                    title: "Dosage", 
                                    placeholder: dosageUnit == "ml" ? "e.g., 10ml" : "e.g., 50mg", 
                                    text: $dosage, 
                                    field: .dosage,
                                    iconName: "measure"
                                )
                                .id(Field.dosage)

                                Divider()
                                    .background(Color(hex: "#C7C7BD").opacity(0.2))

                                // Dosage Unit Picker
                                HStack {
                                    Image(systemName: "scalemass")
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                        .frame(width: 25, alignment: .center)
                                    Text("Unit")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                    Spacer()
                                    Picker("Unit", selection: $dosageUnit) {
                                        ForEach(dosageUnits, id: \.self) { unit in
                                            Text(unit)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .frame(width: 100)
                                }
                                .padding(.vertical, 8)

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
                                            Button(freq) {
                                                self.frequency = freq
                                                setupReminderTimesForFrequency(freq)
                                                // Don't automatically jump to notes
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
                                
                                Divider()
                                    .background(Color(hex: "#C7C7BD").opacity(0.2))
                                
                                // Multiple Reminder Times
                                if needsMultipleReminders {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Reminder Times")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                        
                                        ForEach(0..<reminderTimes.count, id: \.self) { index in
                                            HStack {
                                                Image(systemName: "clock")
                                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                                    .frame(width: 25, alignment: .center)
                                                
                                                Text("Dose #\(index + 1)")
                                                    .font(.system(size: 15))
                                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                                
                                                Spacer()
                                                
                                                DatePicker("", selection: $reminderTimes[index], displayedComponents: .hourAndMinute)
                                                    .datePickerStyle(.compact)
                                                    .labelsHidden()
                                                    .colorScheme(.dark)
                                                    .accentColor(Color(hex: "#C7C7BD"))
                                            }
                                            if index < reminderTimes.count - 1 {
                                                Divider()
                                                    .background(Color(hex: "#C7C7BD").opacity(0.2))
                                            }
                                        }
                                    }
                                } else {
                                    // Single Reminder Time
                                    if frequency != "As needed" {
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
                                    }
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(10)
                            
                            // Track Pill Count Toggle
                            VStack(alignment: .leading) {
                                Text("INVENTORY")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                    .padding(.bottom, 8)
                                
                                Toggle(isOn: $trackPillCount) {
                                    HStack {
                                        Image(systemName: "number.circle")
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                            .frame(width: 25, alignment: .center)
                                        
                                        Text("Track Pill Count")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                
                                if trackPillCount {
                                    Divider()
                                        .background(Color(hex: "#C7C7BD").opacity(0.2))
                                    
                                    systemInputField(
                                        title: "Total Pills", 
                                        placeholder: "Enter total count", 
                                        text: $pillCountString, 
                                        field: .pillCount, 
                                        keyboardType: .numberPad,
                                        iconName: "pill.fill"
                                    )
                                    .id(Field.pillCount)
                                    
                                    Divider()
                                        .background(Color(hex: "#C7C7BD").opacity(0.2))
                                    
                                    systemInputField(
                                        title: "Pills Per Dose", 
                                        placeholder: "Enter amount", 
                                        text: $pillsPerDoseString, 
                                        field: .pillsPerDose, 
                                        keyboardType: .numberPad,
                                        iconName: "pills"
                                    )
                                    .id(Field.pillsPerDose)
                                    
                                    Divider()
                                        .background(Color(hex: "#C7C7BD").opacity(0.2))
                                    
                                    systemInputField(
                                        title: "Refill Reminder", 
                                        placeholder: "Enter threshold", 
                                        text: $refillThresholdString, 
                                        field: .refillThreshold, 
                                        keyboardType: .numberPad,
                                        iconName: "bell.badge"
                                    )
                                    .id(Field.refillThreshold)
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(10)
                            
                            // Notification Toggle
                            VStack(alignment: .leading) {
                                Text("REMINDERS")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                    .padding(.bottom, 8)
                                
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
                                Toggle(isOn: $isOneTimeWithFollowUp) {
                                    HStack {
                                        Image(systemName: "1.circle")
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                            .frame(width: 25, alignment: .center)
                                        Text("Remind me once with follow up")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                .disabled(!enableNotification)
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

                            // Add button
                            Button {
                                saveMedication()
                            } label: {
                                Text("Add Medication")
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
                    }
                    .onChange(of: focusedField) { _, field in
                        if let field = field {
                            withAnimation {
                                scrollProxy.scrollTo(field, anchor: .top)
                            }
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            saveMedication()
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
                    
                    // Auto-focus the name field when view appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        focusedField = .name
                    }
                }
            }
        }
        .sheet(isPresented: $showPremiumUpsellSheet) {
            PremiumSearchUpsellView(isPresented: $showPremiumUpsellSheet)
                .preferredColorScheme(.dark)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
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
    
    // Check if we need multiple reminder fields
    private var needsMultipleReminders: Bool {
        switch frequency {
        case "Twice daily", "Three times daily":
            return true
        default:
            return false
        }
    }
    
    // Field navigation helpers
    private var canMoveToPreviousField: Bool {
        guard let currentField = focusedField else { return false }
        switch currentField {
        case .name: return false  // Already at the first field
        case .dosage, .frequency, .notes, .pillCount, .pillsPerDose, .refillThreshold: return true
        }
    }
    
    private var canMoveToNextField: Bool {
        guard let currentField = focusedField else { return false }
        switch currentField {
        case .name, .dosage, .frequency: return true
        case .notes:
            return trackPillCount // Only can move down if pill count tracking is enabled
        case .pillCount, .pillsPerDose: return trackPillCount
        case .refillThreshold: return false  // Already at the last field
        }
    }
    
    private func moveToPreviousField() {
        guard let currentField = focusedField else { return }
        switch currentField {
        case .name: break  // Already at the first field
        case .dosage: focusedField = .name
        case .frequency: focusedField = .dosage
        case .notes:
            focusedField = .frequency
        case .pillCount:
            focusedField = .notes
        case .pillsPerDose:
            focusedField = .pillCount
        case .refillThreshold:
            focusedField = .pillsPerDose
        }
    }
    
    private func moveToNextField() {
        guard let currentField = focusedField else { return }
        switch currentField {
        case .name: focusedField = .dosage
        case .dosage: focusedField = .frequency
        case .frequency: focusedField = nil // Don't auto-jump to notes
        case .notes:
            if trackPillCount { focusedField = .pillCount }
            else { focusedField = nil }
        case .pillCount:
            focusedField = .pillsPerDose
        case .pillsPerDose:
            focusedField = .refillThreshold
        case .refillThreshold:
            focusedField = nil
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
    private func systemInputField(title: String, placeholder: String, text: Binding<String>, field: Field, keyboardType: UIKeyboardType = .default, iconName: String? = nil) -> some View {
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
                    .keyboardType(keyboardType)
                    .focused($focusedField, equals: field)
                    .submitLabel(field == .name ? .next : .done)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .onSubmit {
                        switch field {
                        case .name: focusedField = .dosage
                        case .dosage: focusedField = .frequency
                        case .frequency: focusedField = nil // Don't auto-jump to notes
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
        .padding(.vertical, 8)
    }

    private func saveMedication() {
        let pillCount = trackPillCount ? Int(pillCountString) : nil
        let pillsPerDose = trackPillCount ? (Int(pillsPerDoseString) ?? 1) : 1
        let refillThreshold = trackPillCount && !refillThresholdString.isEmpty ? Int(refillThresholdString) : nil
        
        store.addMedication(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
            dosageUnit: dosageUnit,
            iconName: iconName,
            frequency: frequency,
            timeToTake: timeToTake,
            reminderTimes: (needsMultipleReminders && !isOneTimeWithFollowUp) ? reminderTimes : [],
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            enableNotification: enableNotification,
            pillCount: pillCount,
            pillsPerDose: pillsPerDose,
            refillThreshold: refillThreshold,
            isOneTimeWithFollowUp: isOneTimeWithFollowUp
        )
        
        onAdd()
    }
}