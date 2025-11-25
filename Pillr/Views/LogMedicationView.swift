//
//  LogMedicationView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//


import SwiftUI
import UIKit

struct LogMedicationView: View {
    @EnvironmentObject var store: MedicationStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    let medicationToLog: Medication
    var isDailyCheckIn: Bool = false
    @State private var actualTimeTaken: Date = Date()
    @State private var logNotes: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var remainingPills: Int?
    @State private var selectedDoseIndex: Int = 0
    @State private var showQuickLogOption: Bool = false
    @State private var selectedQuickTime: QuickTimeOption = .now
    @State private var showingCustomTime: Bool = false
    @State private var sideEffectTags: Set<String> = []
    @State private var customSideEffect: String = ""
    @State private var showingAddCustomSideEffect: Bool = false
    @State private var focusRating: Int = 0 // 1–5, 0 = not set
    @State private var sideEffectSeverity: Int = 0 // 1–5, 0 = not set
    
    // Quick time options for easier logging
    enum QuickTimeOption: String, CaseIterable {
        case now = "Now"
        case fiveMinAgo = "5 min ago"
        case fifteenMinAgo = "15 min ago"
        case thirtyMinAgo = "30 min ago"
        case oneHourAgo = "1 hour ago"
        case custom = "Custom time"
        
        var timeOffset: TimeInterval {
            switch self {
            case .now: return 0
            case .fiveMinAgo: return -300
            case .fifteenMinAgo: return -900
            case .thirtyMinAgo: return -1800
            case .oneHourAgo: return -3600
            case .custom: return 0
            }
        }
    }
    
    // Common side effects for quick selection
    private let commonSideEffects = [
        "Nausea", "Drowsiness", "Headache", "Dizziness", "Stomach upset",
        "Dry mouth", "Fatigue", "Insomnia", "Appetite loss", "Mood changes"
    ]
    
    // Whether this medication has multiple doses
    private var hasMultipleDoses: Bool {
        return !medicationToLog.reminderTimes.isEmpty
    }
    
    // Computed property for dose selection label to avoid complex expression
    private var doseSelectionLabel: some View {
        HStack {
            Text("Dose #\(selectedDoseIndex + 1) (\(formatTime(medicationToLog.reminderTimes[selectedDoseIndex])))")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "#E8E8E0"))
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#F5F5F5").opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#F5F5F5").opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    var body: some View {
        NavigationView {
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
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        // Enhanced Header with progress indicator
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Log Medication")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: "#E8E8E0"))
                                }
                                
                                Spacer()
                                
                                // Enhanced pill count indicator
                                if let pillCount = remainingPills {
                                    VStack(spacing: 4) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "pills.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(Color(hex: "#404C42"))
                                            Text("\(pillCount)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(Color(hex: "#404C42"))
                                        }
                                        Text("remaining")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Color(hex: "#404C42").opacity(0.8))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(hex: "#C7C7BD"))
                                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    )
                                }
                            }
                            
                            // Medication preview card
                            VStack(alignment: .leading, spacing: 6) {
                                Text(medicationToLog.name)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                    .lineLimit(2)
                                
                                Text("\(medicationToLog.dosage) \(medicationToLog.dosageUnit)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "#F5F5F5"))
                                
                                Text(medicationToLog.frequency)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.black.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color(hex: "#F5F5F5").opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.top, 20)
                        
                        // Multiple doses selector (if applicable)
                        if hasMultipleDoses {
                            FormSection(title: "DOSE SELECTION", icon: "list.number.circle.fill") {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Image(systemName: "clock.badge.checkmark")
                                            .foregroundColor(Color(hex: "#FFB74D"))
                                            .font(.system(size: 20))
                                        Text("Which dose are you logging?")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                    }
                                    
                                    Menu {
                                        ForEach(0..<medicationToLog.reminderTimes.count, id: \.self) { index in
                                            Button("Dose #\(index + 1) (\(formatTime(medicationToLog.reminderTimes[index])))") {
                                                selectedDoseIndex = index
                                            }
                                        }
                                    } label: {
                                        doseSelectionLabel
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }
                        
                        // Enhanced Time Section with quick options (hidden for daily check-ins)
                        if !isDailyCheckIn {
                            FormSection(title: "TIME TAKEN", icon: "") {
                                VStack(alignment: .leading, spacing: 20) {
                                    // Quick time selection buttons
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                        ForEach(QuickTimeOption.allCases, id: \.self) { option in
                                            Button(action: {
                                                HapticManager.shared.lightImpact()
                                                selectedQuickTime = option
                                                if option == .custom {
                                                    showingCustomTime = true
                                                } else {
                                                    actualTimeTaken = Date().addingTimeInterval(option.timeOffset)
                                                    showingCustomTime = false
                                                }
                                            }) {
                                                Text(option.rawValue)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(selectedQuickTime == option ? Color(hex: "#404C42") : Color(hex: "#E8E8E0"))
                                                    .padding(.vertical, 12)
                                                    .padding(.horizontal, 8)
                                                    .frame(maxWidth: .infinity)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(selectedQuickTime == option ? Color(hex: "#F5F5F5") : Color.black.opacity(0.2))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .stroke(selectedQuickTime == option ? Color(hex: "#F5F5F5") : Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                                                            )
                                                    )
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                        }
                                    }
                                    
                                    // Custom time picker (shown when custom is selected)
                                    if showingCustomTime {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Image(systemName: "clock.arrow.circlepath")
                                                    .foregroundColor(Color(hex: "#F5F5F5"))
                                                    .font(.system(size: 16))
                                                Text("Select custom time")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(Color(hex: "#E8E8E0"))
                                            }
                                            
                                            DatePicker("", selection: $actualTimeTaken, displayedComponents: [.date, .hourAndMinute])
                                                .datePickerStyle(.compact)
                                                .labelsHidden()
                                                .colorScheme(.dark)
                                                .accentColor(Color(hex: "#F5F5F5"))
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.black.opacity(0.1))
                                                )
                                        }
                                        .padding(16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.black.opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color(hex: "#F5F5F5").opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    }
                                }
                            }
                        }
                        
                        // Enhanced Notes & Side Effects Section
                        if isDailyCheckIn {
                            FormSection(title: "NOTES & SIDE EFFECTS", icon: "note.text.fill") {
                                VStack(alignment: .leading, spacing: 20) {
                                    // Quick check-in sliders
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("How was your focus?")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                        
                                        RatingControl(
                                            title: "Focus",
                                            value: $focusRating,
                                            lowLabel: "Foggy",
                                            highLabel: "Very focused"
                                        )
                                        
                                        Text("How strong were side effects?")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                        
                                        RatingControl(
                                            title: "Side effects",
                                            value: $sideEffectSeverity,
                                            lowLabel: "Barely noticed",
                                            highLabel: "Very strong"
                                        )
                                    }
                                    
                                    // Side effects quick selection
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Any side effects? (optional)")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                        
                                        if !sideEffectTags.isEmpty {
                                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                                                ForEach(Array(sideEffectTags), id: \.self) { effect in
                                                    HStack {
                                                        Text(effect)
                                                            .font(.system(size: 14, weight: .medium))
                                                            .foregroundColor(Color(hex: "#404C42"))
                                                        
                                                        Button(action: {
                                                            HapticManager.shared.lightImpact()
                                                            sideEffectTags.remove(effect)
                                                        }) {
                                                            Image(systemName: "xmark.circle.fill")
                                                                .font(.system(size: 16))
                                                                .foregroundColor(Color(hex: "#404C42").opacity(0.7))
                                                        }
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 20)
                                                            .fill(Color(hex: "#FFB74D"))
                                                    )
                                                }
                                            }
                                        }
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(commonSideEffects.filter { !sideEffectTags.contains($0) }, id: \.self) { effect in
                                                    Button(action: {
                                                        HapticManager.shared.lightImpact()
                                                        sideEffectTags.insert(effect)
                                                    }) {
                                                        Text(effect)
                                                            .font(.system(size: 14, weight: .medium))
                                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                                            .padding(.horizontal, 12)
                                                            .padding(.vertical, 8)
                                                            .background(
                                                                RoundedRectangle(cornerRadius: 20)
                                                                    .fill(Color.black.opacity(0.2))
                                                                    .overlay(
                                                                        RoundedRectangle(cornerRadius: 20)
                                                                            .stroke(Color(hex: "#C7C7BD").opacity(0.3), lineWidth: 1)
                                                                    )
                                                            )
                                                    }
                                                    .buttonStyle(ScaleButtonStyle())
                                                }
                                                
                                                // Add custom side effect button
                                                Button(action: {
                                                    showingAddCustomSideEffect = true
                                                }) {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "plus.circle")
                                                            .font(.system(size: 14))
                                                        Text("Add custom")
                                                            .font(.system(size: 14, weight: .medium))
                                                    }
                                                    .foregroundColor(Color(hex: "#F5F5F5"))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 20)
                                                            .fill(Color.black.opacity(0.2))
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 20)
                                                                    .stroke(Color(hex: "#F5F5F5").opacity(0.3), lineWidth: 1)
                                                            )
                                                    )
                                                }
                                                .buttonStyle(ScaleButtonStyle())
                                            }
                                            .padding(.horizontal, 1)
                                        }
                                    }
                                    
                                    // General notes
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Image(systemName: "square.and.pencil")
                                                .foregroundColor(Color(hex: "#F5F5F5"))
                                                .font(.system(size: 18))
                                            Text("Additional notes (optional)")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Color(hex: "#E8E8E0"))
                                        }
                                        
                                        ZStack(alignment: .topLeading) {
                                            TextEditor(text: $logNotes)
                                                .frame(minHeight: 80, maxHeight: 150)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(Color(hex: "#E8E8E0"))
                                                .scrollContentBackground(.hidden)
                                                .background(Color.clear)
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

                                            if logNotes.isEmpty {
                                                Text("How did you feel? Any observations?")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                                                    .padding(.leading, 20)
                                                    .padding(.top, 20)
                                                    .allowsHitTesting(false)
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            FormSection(title: "NOTES (OPTIONAL)", icon: "note.text.fill") {
                                VStack(alignment: .leading, spacing: 12) {
                                    ZStack(alignment: .topLeading) {
                                        TextEditor(text: $logNotes)
                                            .frame(minHeight: 80, maxHeight: 120)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(hex: "#E8E8E0"))
                                            .scrollContentBackground(.hidden)
                                            .background(Color.clear)
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
                                        
                                        if logNotes.isEmpty {
                                            Text("Add anything you want to remember for this dose.")
                                                .font(.system(size: 16))
                                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.5))
                                                .padding(.leading, 20)
                                                .padding(.top, 20)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Enhanced Action Buttons
                        VStack(spacing: 16) {
                            Button {
                                HapticManager.shared.successNotification()
                                processDoseAction(skipped: false)
                            } label: {
                                Text("Log Medication")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#404C42"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(hex: "#E8E8E0"))
                                    )
                                    .cornerRadius(20)
                                    .shadow(color: Color(hex: "#C7C7BD").opacity(0.3), radius: 8, x: 0, y: 4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color(hex: "#C7C7BD").opacity(0.5), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(.vertical, 20)
                        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 20 : 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                }
            }
            .onAppear {
                setupKeyboardObservers()
                // Initialize remaining pills if pill count is available
                if let pillCount = medicationToLog.pillCount {
                    remainingPills = pillCount
                }
            }
            .alert("Add Custom Side Effect", isPresented: $showingAddCustomSideEffect) {
                TextField("Side effect", text: $customSideEffect)
                Button("Add") {
                    if !customSideEffect.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        sideEffectTags.insert(customSideEffect.trimmingCharacters(in: .whitespacesAndNewlines))
                        customSideEffect = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    customSideEffect = ""
                }
            } message: {
                Text("Enter a custom side effect to track with this dose.")
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func FormSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if !icon.isEmpty {
                    Image(systemName: icon)
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .font(.system(size: 16, weight: .semibold))
                }
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
    
    private func setupKeyboardObservers() {
        // Add keyboard observers
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            keyboardHeight = keyboardFrame.height
        }
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            keyboardHeight = 0
        }
    }
    
    private func processDoseAction(skipped: Bool) {
        // Use the selected time instead of current time
        let timeToUse = selectedQuickTime == .custom ? actualTimeTaken : Date().addingTimeInterval(selectedQuickTime.timeOffset)
        
        // Combine notes with side effects
        var combinedNotes = logNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isDailyCheckIn && !sideEffectTags.isEmpty {
            let sideEffectsText = "Side effects: " + Array(sideEffectTags).joined(separator: ", ")
            if combinedNotes.isEmpty {
                combinedNotes = sideEffectsText
            } else {
                combinedNotes += "\n\n" + sideEffectsText
            }
        }
        
        let finalNotes = combinedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesToSave = finalNotes.isEmpty ? nil : finalNotes
        
        let focusToSave = isDailyCheckIn && focusRating > 0 ? focusRating : nil
        let sideEffectToSave = isDailyCheckIn && sideEffectSeverity > 0 ? sideEffectSeverity : nil
        
        if skipped {
            store.skipMedication(
                medication: medicationToLog,
                actualTime: timeToUse,
                notes: notesToSave,
                reminderIndex: hasMultipleDoses ? selectedDoseIndex : nil,
                focusRating: focusToSave,
                sideEffectSeverity: sideEffectToSave,
                showFocusTimeline: !isDailyCheckIn
            )
        } else {
            store.logMedicationTaken(
                medication: medicationToLog,
                actualTime: timeToUse,
                notes: notesToSave,
                skipped: false,
                reminderIndex: hasMultipleDoses ? selectedDoseIndex : nil,
                focusRating: focusToSave,
                sideEffectSeverity: sideEffectToSave,
                showFocusTimeline: !isDailyCheckIn,
                isDailyCheckIn: isDailyCheckIn
            )
        }
        dismiss()
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func calculateTextEditorHeight(for size: CGSize) -> CGFloat {
        if horizontalSizeClass == .regular {
            return 120
        } else {
            return size.height < 700 ? 80 : 100
        }
    }
}

// MARK: - Rating Control

struct RatingControl: View {
    let title: String
    @Binding var value: Int
    let lowLabel: String
    let highLabel: String
    
    private let range = 1...5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                if value > 0 {
                    Text("\(value)/5")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#E8E8E0"))
                }
            }
            
            HStack(spacing: 8) {
                Text(lowLabel)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                
                Spacer()
                
                Text(highLabel)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
            }
            
            HStack(spacing: 8) {
                ForEach(range, id: \.self) { index in
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        if value == index {
                            value = 0
                        } else {
                            value = index
                        }
                    }) {
                        Circle()
                            .fill(
                                index <= value
                                ? Color(hex: "#D7CCC8")
                                : Color.black.opacity(0.3)
                            )
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "#C7C7BD").opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
}
