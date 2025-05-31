//
//  EditMedicationView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

struct EditMedicationView: View {
    @EnvironmentObject var store: MedicationStore
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    
    // Passed-in medication to edit
    var medication: Medication
    var onUpdate: () -> Void
    
    // State for editing
    @State private var name: String
    @State private var dosage: String
    @State private var dosageUnit: String
    @State private var iconName: String
    @State private var frequency: String
    @State private var timeToTake: Date
    @State private var reminderTimes: [Date] = []
    @State private var notes: String
    @State private var enableNotification: Bool
    @State private var pillCountString: String = ""
    @State private var pillsPerDoseString: String = "1"
    @State private var refillThresholdString: String = ""
    @State private var trackPillCount: Bool = false
    @State private var isOneTimeWithFollowUp: Bool = false
    @State private var showingPremiumUpgrade: Bool = false
    
    // For dynamically adjusting scroll position when keyboard appears
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var focusedField: Field?
    
    // Form validation states
    @State private var showValidationErrors: Bool = false
    @State private var nameError: String? = nil
    @State private var dosageError: String? = nil
    
    enum Field {
        case name, dosage, frequency, notes, pillCount, pillsPerDose, refillThreshold
    }

    let frequencies = ["Once daily", "Twice daily", "Three times daily", "As needed"]
    let dosageUnits = ["mg", "ml", "tablets", "capsules"]
    
    // Helper function to get icon for each unit
    private func iconForUnit(_ unit: String) -> String {
        switch unit {
        case "mg":
            return "scalemass.fill"
        case "ml":
            return "drop.fill"
        case "tablets":
            return "circle.fill"
        case "capsules":
            return "pills.fill"
        default:
            return "pill.fill"
        }
    }
    
    // Computed properties
    private var needsMultipleReminders: Bool {
        return frequency == "Twice daily" || frequency == "Three times daily"
    }
    
    private var progressColor: (Int) -> Color {
        return { index in
            let completedSteps = completedFormSteps
            return index < completedSteps ? Color(hex: "#C7C7BD") : Color(hex: "#606A63")
        }
    }
    
    private var completedFormSteps: Int {
        var steps = 0
        if !name.isEmpty { steps += 1 }
        if !dosage.isEmpty { steps += 1 }
        if frequency != "As needed" || !notes.isEmpty { steps += 1 }
        if isFormValid { steps += 1 }
        return min(steps, 4)
    }
    
    // Initialize with the medication's existing values
    init(medication: Medication, onUpdate: @escaping () -> Void) {
        self.medication = medication
        self.onUpdate = onUpdate
        
        // Initialize state variables with existing medication values
        _name = State(initialValue: medication.name)
        _dosage = State(initialValue: medication.dosage)
        _dosageUnit = State(initialValue: medication.dosageUnit)
        _iconName = State(initialValue: medication.iconName)
        _frequency = State(initialValue: medication.frequency)
        _timeToTake = State(initialValue: medication.timeToTake)
        _reminderTimes = State(initialValue: medication.reminderTimes.isEmpty ? [] : medication.reminderTimes)
        _notes = State(initialValue: medication.notes ?? "")
        _enableNotification = State(initialValue: medication.notificationID != nil || !medication.notificationIDs.isEmpty)
        _pillCountString = State(initialValue: medication.pillCount != nil ? String(medication.pillCount!) : "")
        _pillsPerDoseString = State(initialValue: String(medication.pillsPerDose))
        _refillThresholdString = State(initialValue: medication.refillThreshold != nil ? String(medication.refillThreshold!) : "")
        _trackPillCount = State(initialValue: medication.pillCount != nil)
        _isOneTimeWithFollowUp = State(initialValue: medication.isOneTimeWithFollowUp)
    }

    var body: some View {
        ZStack {
            // Enhanced background with subtle gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#404C42"),
                    Color(hex: "#3A443D")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        // Enhanced Header with progress indicator
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Edit Medication")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                
                                Spacer()
                                
                                // Progress indicator
                                HStack(spacing: 4) {
                                    ForEach(0..<4) { index in
                                        Circle()
                                            .fill(progressColor(index))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                            }
                            
                            Text("Update your medication details")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                        }
                        .padding(.top, 20)
                        
                        // Enhanced Basic Information Section
                        FormSection(title: "MEDICATION INFO", icon: "pills.fill") {
                            VStack(spacing: 16) {
                                enhancedInputField(
                                    title: "Medication Name", 
                                    placeholder: "e.g., Aspirin, Tylenol",
                                    text: $name, 
                                    field: .name,
                                    iconName: "pill.circle.fill",
                                    isRequired: true,
                                    errorMessage: nameError
                                )
                                .id(Field.name)
                                
                                // Dosage and Unit in a row
                                HStack(spacing: 12) {
                                    enhancedInputField(
                                        title: "Dosage", 
                                        placeholder: dosageUnit == "ml" ? "10" : "50", 
                                        text: $dosage, 
                                        field: .dosage,
                                        iconName: "scalemass.fill",
                                        isRequired: true,
                                        errorMessage: dosageError,
                                        keyboardType: .decimalPad
                                    )
                                    .id(Field.dosage)
                                    
                                    // Enhanced unit picker
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Unit")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                        
                                        Menu {
                                            ForEach(dosageUnits, id: \.self) { unit in
                                                Button {
                                                    dosageUnit = unit
                                                    HapticManager.shared.lightImpact()
                                                } label: {
                                                    HStack {
                                                        Image(systemName: iconForUnit(unit))
                                                            .font(.system(size: 14, weight: .medium))
                                                        Text(unit)
                                                    }
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: iconForUnit(dosageUnit))
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                                Text(dosageUnit)
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 12)
                                            .frame(minWidth: 90)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.black.opacity(0.2))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                    .frame(minWidth: 110)
                                }
                            }
                        }
                        
                        // Enhanced Schedule Section
                        FormSection(title: "SCHEDULE", icon: "calendar.badge.clock") {
                            VStack(spacing: 16) {
                                // Frequency picker with better visual design
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "repeat.circle.fill")
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                            .font(.system(size: 20))
                                        Text("How often?")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                    }
                                    
                                    // Frequency selection with cards
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                                        ForEach(frequencies, id: \.self) { freq in
                                            FrequencyCard(
                                                frequency: freq,
                                                isSelected: frequency == freq,
                                                onTap: {
                                                    HapticManager.shared.lightImpact()
                                                    frequency = freq
                                                    setupReminderTimesForFrequency(freq)
                                                    // Disable notifications if "As needed" is selected
                                                    if freq == "As needed" {
                                                        enableNotification = false
                                                    }
                                                }
                                            )
                                        }
                                    }
                                }
                                
                                // Time pickers with enhanced design
                                if needsMultipleReminders {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Image(systemName: "clock.fill")
                                                .foregroundColor(Color(hex: "#C7C7BD"))
                                                .font(.system(size: 18))
                                            Text("Reminder Times")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "#E8E8E0"))
                                        }
                                        
                                        ForEach(0..<reminderTimes.count, id: \.self) { index in
                                            TimePickerRow(
                                                title: "Dose \(index + 1)",
                                                time: $reminderTimes[index]
                                            )
                                        }
                                    }
                                } else if frequency != "As needed" {
                                    TimePickerRow(
                                        title: "Reminder Time",
                                        time: $timeToTake
                                    )
                                }
                            }
                        }
                        
                        // Enhanced Inventory Section (collapsible)
                        FormSection(title: "INVENTORY", icon: "archivebox.fill") {
                            VStack(spacing: 16) {
                                // Enhanced toggle with description
                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle(isOn: $trackPillCount.animation(.easeInOut)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Image(systemName: "number.circle.fill")
                                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                                    .font(.system(size: 18))
                                                Text("Track Pill Count")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                                if !userSettings.isPremiumUser {
                                                    Button(action: {
                                                        showingPremiumUpgrade = true
                                                    }) {
                                                        Text("PREMIUM")
                                                            .font(.system(size: 10, weight: .bold))
                                                            .foregroundColor(.white)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color(hex: "#D4A017"))
                                                            .cornerRadius(4)
                                                    }
                                                }
                                            }
                                            Text(userSettings.isPremiumUser ? 
                                                 "Get refill reminders and track usage" : 
                                                 "Inventory tracking requires premium subscription")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                                    .disabled(!userSettings.isPremiumUser)
                                    .opacity(userSettings.isPremiumUser ? 1.0 : 0.6)
                                    
                                    if !userSettings.isPremiumUser && trackPillCount {
                                        Button(action: {
                                            showingPremiumUpgrade = true
                                        }) {
                                            HStack {
                                                Image(systemName: "crown.fill")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(Color(hex: "#D4A017"))
                                                Text("Upgrade to Premium")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(Color(hex: "#D4A017"))
                                            }
                                            .padding(.top, 4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                
                                if trackPillCount {
                                    VStack(spacing: 16) {
                                        HStack(spacing: 12) {
                                            enhancedInputField(
                                                title: "Total Pills", 
                                                placeholder: "30", 
                                                text: $pillCountString, 
                                                field: .pillCount, 
                                                iconName: "pill.fill",
                                                keyboardType: .numberPad
                                            )
                                            .id(Field.pillCount)
                                            
                                            enhancedInputField(
                                                title: "Per Dose", 
                                                placeholder: "1", 
                                                text: $pillsPerDoseString, 
                                                field: .pillsPerDose, 
                                                iconName: "pills.fill",
                                                keyboardType: .numberPad
                                            )
                                            .id(Field.pillsPerDose)
                                        }
                                        
                                        enhancedInputField(
                                            title: "Refill Reminder", 
                                            placeholder: "5", 
                                            text: $refillThresholdString, 
                                            field: .refillThreshold, 
                                            iconName: "bell.badge.fill",
                                            keyboardType: .numberPad
                                        )
                                        .id(Field.refillThreshold)
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        
                        // Enhanced Notifications Section
                        if frequency != "As needed" {
                            FormSection(title: "NOTIFICATIONS", icon: "bell.fill") {
                                VStack(spacing: 16) {
                                    if needsMultipleReminders || frequency == "Once daily" {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Toggle(isOn: $isOneTimeWithFollowUp.animation(.easeInOut)) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack {
                                                        Image(systemName: "arrow.clockwise.circle.fill")
                                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                                            .font(.system(size: 18))
                                                        Text("One-time with Follow-up")
                                                            .font(.system(size: 16, weight: .semibold))
                                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                                        if !userSettings.isPremiumUser {
                                                            Button(action: {
                                                                showingPremiumUpgrade = true
                                                            }) {
                                                                Text("PREMIUM")
                                                                    .font(.system(size: 10, weight: .bold))
                                                                    .foregroundColor(.white)
                                                                    .padding(.horizontal, 6)
                                                                    .padding(.vertical, 2)
                                                                    .background(Color(hex: "#D4A017"))
                                                                    .cornerRadius(4)
                                                            }
                                                        }
                                                    }
                                                    Text(userSettings.isPremiumUser ? 
                                                         "Single reminder + 30-min follow-up if not taken" : 
                                                         "Follow-up reminders require premium subscription")
                                                        .font(.system(size: 13))
                                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                                }
                                            }
                                            .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                                            .disabled(!userSettings.isPremiumUser)
                                            .opacity(userSettings.isPremiumUser ? 1.0 : 0.6)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Enhanced Notes Section
                        FormSection(title: "NOTES", icon: "note.text.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Additional Information")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                
                                ZStack(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.black.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                                        )
                                        .frame(minHeight: 100)
                                    
                                    TextEditor(text: $notes)
                                        .focused($focusedField, equals: .notes)
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                        .padding(12)
                                        .overlay(
                                            Group {
                                                if notes.isEmpty {
                                                    Text("e.g., Take with food, side effects to watch for...")
                                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                                                        .padding(.top, 20)
                                                        .padding(.leading, 16)
                                                        .allowsHitTesting(false)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                            }
                                        )
                                }
                            }
                            .id(Field.notes)
                        }
                        
                        // Enhanced Update Button
                        VStack(spacing: 12) {
                            Button {
                                HapticManager.shared.mediumImpact()
                                updateMedication()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Update Medication")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(isFormValid ? Color(hex: "#404C42") : Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: isFormValid ? [
                                            Color(hex: "#E8E8E0"),
                                            Color(hex: "#D0D0C8")
                                        ] : [
                                            Color.gray.opacity(0.6),
                                            Color.gray.opacity(0.4)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: isFormValid ? Color.black.opacity(0.15) : Color.clear, radius: 8, x: 0, y: 4)
                            }
                            .disabled(!isFormValid)
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(.vertical, 10)
                        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 20 : 40)
                    }
                    .padding(.horizontal, 20)
                }
                .onChange(of: focusedField) { _, field in
                    if let field = field {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo(field, anchor: .center)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        HapticManager.shared.mediumImpact()
                        updateMedication()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFormValid ? Color(hex: "#C7C7BD") : Color.gray)
                    .disabled(!isFormValid)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
            .onAppear {
                setupKeyboardObservers()
            }
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupReminderTimesForFrequency(_ freq: String) {
        switch freq {
        case "Twice daily":
            if reminderTimes.count != 2 {
                reminderTimes = [
                    Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
                    Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
                ]
            }
            enableNotification = true
        case "Three times daily":
            if reminderTimes.count != 3 {
                reminderTimes = [
                    Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
                    Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date(),
                    Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
                ]
            }
            enableNotification = true
        case "As needed":
            reminderTimes = []
            enableNotification = false
        default:
            reminderTimes = []
            enableNotification = true
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func FormSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                    .tracking(0.5)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#C7C7BD").opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    @ViewBuilder
    private func TimePickerRow(title: String, time: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#E8E8E0"))
            
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .accentColor(Color(hex: "#C7C7BD"))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.1))
                )
        }
    }
    
    @ViewBuilder
    private func enhancedInputField(
        title: String, 
        placeholder: String, 
        text: Binding<String>, 
        field: Field, 
        iconName: String? = nil,
        isRequired: Bool = false,
        errorMessage: String? = nil,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .font(.system(size: 16, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .focused($focusedField, equals: field)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#E8E8E0"))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    errorMessage != nil ? Color.red : (focusedField == field ? Color(hex: "#C7C7BD") : Color(hex: "#C7C7BD").opacity(0.3)), 
                                    lineWidth: focusedField == field || errorMessage != nil ? 2 : 1
                                )
                        )
                )
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.leading, 4)
            }
        }
    }
    
    @ViewBuilder
    private func FrequencyCard(frequency: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: frequencyIcon(for: frequency))
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "#404C42") : Color(hex: "#C7C7BD"))
                
                Text(frequency)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: "#404C42") : Color(hex: "#C7C7BD"))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "#C7C7BD") : Color.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color(hex: "#C7C7BD") : Color(hex: "#C7C7BD").opacity(0.3), 
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func frequencyIcon(for frequency: String) -> String {
        switch frequency {
        case "Once daily": return "sun.max.fill"
        case "Twice daily": return "sun.and.horizon.fill"
        case "As needed": return "hand.raised.fill"
        default: return "clock.fill"
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
        let nameValid = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let dosageValid = !dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let frequencyValid = !frequency.isEmpty
        
        return nameValid && dosageValid && frequencyValid && nameError == nil && dosageError == nil
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
        case .name, .dosage, .frequency, .pillCount, .pillsPerDose: return true
        case .notes, .refillThreshold: return false  // Already at the last field
        }
    }
    
    private func moveToPreviousField() {
        guard let currentField = focusedField else { return }
        switch currentField {
        case .name: break  // Already at the first field
        case .dosage: focusedField = .name
        case .frequency: focusedField = .dosage
        case .notes: focusedField = .frequency
        case .pillCount: focusedField = .frequency
        case .pillsPerDose: focusedField = .pillCount
        case .refillThreshold: focusedField = .pillsPerDose
        }
    }
    
    private func moveToNextField() {
        guard let currentField = focusedField else { return }
        switch currentField {
        case .name: focusedField = .dosage
        case .dosage: focusedField = .frequency
        case .frequency: focusedField = trackPillCount ? .pillCount : .notes
        case .pillCount: focusedField = .pillsPerDose
        case .pillsPerDose: focusedField = .refillThreshold
        case .refillThreshold: focusedField = .notes
        case .notes: break  // Already at the last field
        }
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            keyboardHeight = 0
        }
    }
    
    // Update the medication in the store
    private func updateMedication() {
        // Validate form
        validateForm()
        if !isFormValid {
            showValidationErrors = true
            return
        }
        
        // Create an updated medication object with the new values
        var updatedMedication = medication
        updatedMedication.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMedication.dosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMedication.dosageUnit = dosageUnit
        updatedMedication.iconName = iconName
        updatedMedication.frequency = frequency
        updatedMedication.timeToTake = timeToTake
        updatedMedication.reminderTimes = needsMultipleReminders ? reminderTimes : []
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMedication.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        updatedMedication.isOneTimeWithFollowUp = isOneTimeWithFollowUp
        
        // Handle pill tracking
        if trackPillCount {
            updatedMedication.pillCount = Int(pillCountString) ?? 0
            updatedMedication.pillsPerDose = Int(pillsPerDoseString) ?? 1
            updatedMedication.refillThreshold = refillThresholdString.isEmpty ? nil : Int(refillThresholdString)
        } else {
            updatedMedication.pillCount = nil
            updatedMedication.pillsPerDose = 1
            updatedMedication.refillThreshold = nil
        }
        
        // Update the medication in the store - should only be enabled if not "As needed"
        store.updateMedication(updatedMedication, enableNotification: enableNotification && frequency != "As needed")
        
        onUpdate()
        dismiss()
    }
    
    private func validateForm() {
        nameError = nil
        dosageError = nil
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nameError = "Medication name is required"
        }
        
        if dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dosageError = "Dosage is required"
        }
    }
} 
