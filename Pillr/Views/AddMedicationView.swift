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
    @State private var frequency: String = "As needed"
    @State private var timeToTake: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var reminderTimes: [Date] = []
    @State private var notes: String = ""
    @State private var enableNotification: Bool = true
    @State private var pillCountString: String = ""
    @State private var pillsPerDoseString: String = "1"
    @State private var refillThresholdString: String = ""
    @State private var trackPillCount: Bool = false

    @State private var isOneTimeWithFollowUp: Bool = false
    
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

    @State private var showFrequencyPicker = false
    
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
                            // Enhanced Header
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Add Medication")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                
                                Text("Fill in the details below to add your medication")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                            }
                            
                            // Enhanced Basic Information Section
                            FormSection(title: "MEDICATION INFO", icon: "pills.fill") {
                                VStack(spacing: 16) {
                                    // Name field with search integration
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .bottom, spacing: 12) {
                                            enhancedInputField(
                                                title: "Medication Name", 
                                                placeholder: "e.g., Aspirin, Tylenol",
                                                text: $name, 
                                                field: .name,
                                                iconName: "pill.circle.fill",
                                                isRequired: true,
                                                errorMessage: nameError
                                            )
                                            
                                            // Enhanced search button - aligned to bottom
                                            VStack {
                                                Spacer()
                                                Button(action: {
                                                    HapticManager.shared.lightImpact()
                                                    // Search functionality removed
                                                }) {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "magnifyingglass")
                                                            .font(.system(size: 16, weight: .medium))
                                                    }
                                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 12)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(Color.black.opacity(0.3))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                                                            )
                                                    )
                                                }
                                                .buttonStyle(ScaleButtonStyle())
                                            }
                                            .frame(height: 70) // Match the approximate height of the input field
                                        }
                                        .id(Field.name)
                                    }
                                    
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
                                                        if enableNotification {
                                                            requestNotificationPermissionIfNeeded()
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
                                                }
                                                Text("Get refill reminders and track usage")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                            }
                                        }
                                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
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
                                                        }
                                                        Text("Single reminder + 30-min follow-up if not taken")
                                                            .font(.system(size: 13))
                                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                                    }
                                                }
                                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#C7C7BD")))
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Enhanced Notes Section
                            FormSection(title: "NOTES", icon: "note.text") {
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

                            // Enhanced Save Button
                            VStack(spacing: 12) {
                                Button {
                                    HapticManager.shared.mediumImpact()
                                    if validateForm() {
                                        saveMedication()
                                    } else {
                                        showValidationErrors = true
                                        HapticManager.shared.errorNotification()
                                    }
                                } label: {
                                    HStack {
                                        if isFormValid {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                        } else {
                                            Image(systemName: "exclamationmark.circle.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                        }
                                        Text("Add Medication")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(isFormValid ? Color(hex: "#404C42") : Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(isFormValid ? Color(hex: "#C7C7BD") : Color.gray.opacity(0.6))
                                            .shadow(color: isFormValid ? Color(hex: "#C7C7BD").opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                                    )
                                }
                                .disabled(!isFormValid)
                                .buttonStyle(ScaleButtonStyle())
                                
                                if showValidationErrors && !isFormValid {
                                    Text("Please fill in all required fields")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.red)
                                        .transition(.opacity)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, 0, for: .scrollContent)
                    .onChange(of: focusedField) { _, field in
                        if let field = field {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scrollProxy.scrollTo(field, anchor: .center)
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            HapticManager.shared.mediumImpact()
                            if validateForm() {
                                saveMedication()
                            } else {
                                showValidationErrors = true
                                HapticManager.shared.errorNotification()
                            }
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
                    // Auto-focus the name field when view appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        focusedField = .name
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
                        Image(systemName: "chevron.up")
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                    .disabled(!canMoveToPreviousField)
                    
                    Button(action: {
                        moveToNextField()
                    }) {
                        Image(systemName: "chevron.down")
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
                .submitLabel(getSubmitLabel(for: field))
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
                                    focusedField == field ? Color(hex: "#C7C7BD") : 
                                    (errorMessage != nil ? Color.red : Color(hex: "#C7C7BD").opacity(0.3)), 
                                    lineWidth: focusedField == field ? 2 : 1
                                )
                        )
                )
                .onSubmit {
                    handleFieldSubmit(field)
                }
                .onChange(of: text.wrappedValue) { _, newValue in
                    validateField(field, value: newValue)
                }
            
            if let errorMessage = errorMessage, showValidationErrors {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Helper Functions
    

    
    private func getSubmitLabel(for field: Field) -> SubmitLabel {
        switch field {
        case .name, .dosage: return .next
        case .pillCount, .pillsPerDose: return .next
        default: return .done
        }
    }
    
    private func handleFieldSubmit(_ field: Field) {
        switch field {
        case .name: focusedField = .dosage
        case .dosage: focusedField = nil // Let user pick frequency
        case .notes:
            if trackPillCount { focusedField = .pillCount }
            else { focusedField = nil }
        case .pillCount: focusedField = .pillsPerDose
        case .pillsPerDose: focusedField = .refillThreshold
        default: focusedField = nil
        }
    }
    
    private func validateField(_ field: Field, value: String) {
        switch field {
        case .name:
            nameError = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Medication name is required" : nil
        case .dosage:
            dosageError = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Dosage is required" : nil
        default:
            break
        }
    }
    
    private func validateForm() -> Bool {
        validateField(.name, value: name)
        validateField(.dosage, value: dosage)
        return isFormValid
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeInOut(duration: 0.3)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                keyboardHeight = 0
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
        let basicValid = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
                        !dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
                        !frequency.isEmpty
        
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
            notes: {
                let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmedNotes.isEmpty ? nil : trimmedNotes
            }(),
            enableNotification: enableNotification,
            pillCount: pillCount,
            pillsPerDose: pillsPerDose,
            refillThreshold: refillThreshold,
            isOneTimeWithFollowUp: isOneTimeWithFollowUp
        )
        
        onAdd()
    }

    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if granted {
                        print("Notification permission granted.")
                        // User granted permission, ensure toggle remains on
                        DispatchQueue.main.async {
                            self.enableNotification = true
                        }
                    } else {
                        print("Notification permission denied.")
                        // User denied permission, ensure toggle is off
                        DispatchQueue.main.async {
                            self.enableNotification = false
                        }
                    }
                }
            } else if settings.authorizationStatus == .denied {
                // Permissions were previously denied. Inform the user or guide them to settings.
                // For now, just ensure the toggle is off.
                print("Notification permission was previously denied.")
                DispatchQueue.main.async {
                    self.enableNotification = false
                }
            }
            // If .authorized, do nothing, toggle is already on.
        }
    }
}

// MARK: - Supporting Views

struct FrequencyCard: View {
    let frequency: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: iconForFrequency(frequency))
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "#404C42") : Color(hex: "#C7C7BD"))
                
                Text(frequency)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: "#404C42") : Color(hex: "#E8E8E0"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
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
    
    private func iconForFrequency(_ frequency: String) -> String {
        switch frequency {
        case "Once daily": return "sun.max.fill"
        case "Twice daily": return "sunrise.fill"
        case "Three times daily": return "clock.fill"
        case "As needed": return "hand.raised.fill"
        default: return "pill.fill"
        }
    }
}

struct TimePickerRow: View {
    let title: String
    @Binding var time: Date
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#E8E8E0"))
                Text(timeString(from: time))
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
            }
            
            Spacer()
            
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(.dark)
                .accentColor(Color(hex: "#C7C7BD"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Extensions

extension View {
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> some View {
        self.onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
        }
    }
}

