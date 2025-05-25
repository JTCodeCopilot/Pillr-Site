//
//  MedicationLogView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

struct MedicationLogView: View {
    @EnvironmentObject var store: MedicationStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingCalendar = false
    @State private var selectedDate: Date = Date()
    @State private var showingFilterOptions = false
    @State private var selectedMedicationFilter: String = "All"
    
    // Group logs by date
    private var groupedLogs: [Date: [MedicationLog]] {
        let calendar = Calendar.current
        var result = [Date: [MedicationLog]]()
        
        // Filter logs based on selected medication and exclude skipped logs
        let filteredLogs = store.logs.filter { log in
            let medicationMatch = selectedMedicationFilter == "All" || log.medicationName == selectedMedicationFilter
            return !log.skipped && medicationMatch
        }

        for log in filteredLogs {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: log.takenAt)
            if let date = calendar.date(from: dateComponents) {
                if result[date] == nil {
                    result[date] = [log]
                } else {
                    result[date]?.append(log)
                }
            }
        }
        
        // Sort logs within each day by time (most recent first)
        for (date, logs) in result {
            result[date] = logs.sorted { $0.takenAt > $1.takenAt }
        }
        
        return result
    }
    
    // Sort dates in descending order (most recent first)
    private var sortedDates: [Date] {
        return groupedLogs.keys.sorted(by: >)
    }
    
    // Filter logs for the selected date
    private var logsForSelectedDate: [MedicationLog] {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        guard let startOfDay = calendar.date(from: dateComponents) else { return [] }
        
        return groupedLogs[startOfDay] ?? []
    }
    
    // Get unique medication names for filter
    private var uniqueMedicationNames: [String] {
        let names = Set(store.logs.filter { !$0.skipped }.map { $0.medicationName })
        return ["All"] + Array(names).sorted()
    }
    
    // Date formatter for section headers
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }
    
    // Relative date formatter for recent dates
    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background color
                    Color(hex: "#404C42")
                        .ignoresSafeArea(edges: [.top, .leading, .trailing, .bottom])
                    
                    VStack(spacing: 0) {
                        // Enhanced header with filter options
                        VStack(spacing: 12) {
                            HStack {
                                Text("Medication History")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                Spacer()
                                
                                // Filter button
                                Button(action: {
                                    showingFilterOptions.toggle()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "line.3.horizontal.decrease.circle")
                                            .font(.system(size: 16))
                                        Text(selectedMedicationFilter == "All" ? "All" : selectedMedicationFilter)
                                            .font(.system(size: 14, weight: .medium))
                                            .lineLimit(1)
                                    }
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(20)
                                }
                            }
                            
                            // Stats row
                            HStack(spacing: 20) {
                                StatCard(
                                    title: "Total Doses",
                                    value: "\(store.logs.filter { !$0.skipped }.count)",
                                    icon: "pills.fill"
                                )
                                
                                StatCard(
                                    title: "This Week",
                                    value: "\(logsThisWeek)",
                                    icon: "calendar.badge.clock"
                                )
                                
                                StatCard(
                                    title: "Streak",
                                    value: "\(currentStreak) days",
                                    icon: "flame.fill"
                                )
                            }
                            
                            // Show selected date if not today
                            if !Calendar.current.isDateInToday(selectedDate) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                    
                                    Text(isDateRecent(selectedDate) ? 
                                         relativeDateFormatter.localizedString(for: selectedDate, relativeTo: Date()) :
                                         dateFormatter.string(from: selectedDate))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.15))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .background(Color(hex: "#404C42"))
                        .zIndex(1)
                        
                        // Content area
                        ZStack {
                            if store.logs.filter({ !$0.skipped }).isEmpty {
                                EmptyHistoryView()
                            } else if logsForSelectedDate.isEmpty && !Calendar.current.isDateInToday(selectedDate) {
                                NoLogsForDateView(date: selectedDate, dateFormatter: dateFormatter)
                            } else {
                                LogsContentView(
                                    selectedDate: selectedDate,
                                    sortedDates: sortedDates,
                                    groupedLogs: groupedLogs,
                                    logsForSelectedDate: logsForSelectedDate,
                                    store: store
                                )
                            }
                        }
                        .navigationBarHidden(true)
                    }
                    .padding(.horizontal, horizontalInsets(for: geometry))
                    
                    // Floating buttons
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            VStack(spacing: 12) {
                                // Calendar button
                                FloatingButton(
                                    icon: "calendar",
                                    action: { showingCalendar = true }
                                )
                                
                                // Today button (only show if not on today)
                                if !Calendar.current.isDateInToday(selectedDate) {
                                    FloatingButton(
                                        icon: "house.fill",
                                        action: { selectedDate = Date() }
                                    )
                                }
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 50)
                    }
                    .zIndex(2)
                    
                    // Filter options overlay
                    if showingFilterOptions {
                        FilterOptionsOverlay(
                            uniqueMedicationNames: uniqueMedicationNames,
                            selectedMedicationFilter: $selectedMedicationFilter,
                            showingFilterOptions: $showingFilterOptions,
                            geometry: geometry
                        )
                        .zIndex(3)
                    }
                    
                    // Date Picker Popover
                    if showingCalendar {
                        DatePickerOverlay(
                            selectedDate: $selectedDate,
                            showingCalendar: $showingCalendar,
                            geometry: geometry
                        )
                        .zIndex(4)
                    }
                }
            }
        }
        .background(Color.clear)
        .navigationViewStyle(.stack)
    }
    
    // Calculate logs this week
    private var logsThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        return store.logs.filter { log in
            !log.skipped && log.takenAt >= weekAgo && log.takenAt <= now
        }.count
    }
    
    // Calculate current streak
    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        
        while true {
            let hasLogForDate = store.logs.contains { log in
                !log.skipped && calendar.isDate(log.takenAt, inSameDayAs: currentDate)
            }
            
            if hasLogForDate {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    // Check if date is recent (within last week)
    private func isDateRecent(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return date >= weekAgo
    }
    
    // Calculate proper insets based on screen size
    private func horizontalInsets(for geometry: GeometryProxy) -> CGFloat {
        if horizontalSizeClass == .regular && geometry.size.width > 768 {
            return max((geometry.size.width - 768) / 3, 0)
        }
        return 0
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#81C784"))
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "#C7C7BD"))
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.15))
        .cornerRadius(12)
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                    .padding(.bottom, 10)
                
                Text("No medication history yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                
                Text("Start logging your medications to see your history here. Your medication adherence journey begins with the first dose!")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding(40)
            .background(Color.black.opacity(0.12))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.top, 40)
        }
    }
}

struct NoLogsForDateView: View {
    let date: Date
    let dateFormatter: DateFormatter
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                    .padding(.bottom, 10)
                
                Text("No medications taken")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                
                Text("No medications were logged on \(dateFormatter.string(from: date))")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding(30)
            .background(Color.black.opacity(0.12))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }
}

struct LogsContentView: View {
    let selectedDate: Date
    let sortedDates: [Date]
    let groupedLogs: [Date: [MedicationLog]]
    let logsForSelectedDate: [MedicationLog]
    let store: MedicationStore
    
    var body: some View {
        if Calendar.current.isDateInToday(selectedDate) {
            // Show all logs grouped by date
            ScrollView {
                LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                    ForEach(sortedDates, id: \.self) { date in
                        Section {
                            VStack(spacing: 12) {
                                ForEach(groupedLogs[date] ?? []) { logEntry in
                                    EnhancedLogEntryRow(logEntry: logEntry, store: store)
                                }
                            }
                        } header: {
                            DateSectionHeader(date: date)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        } else {
            // Show only logs for selected date
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(logsForSelectedDate) { logEntry in
                        EnhancedLogEntryRow(logEntry: logEntry, store: store)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
    }
}

struct DateSectionHeader: View {
    let date: Date
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter
    }
    
    var body: some View {
        HStack {
            Text(isDateRecent(date) ? 
                 relativeDateFormatter.localizedString(for: date, relativeTo: Date()) :
                 dateFormatter.string(from: date))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#C7C7BD"))
            
            Spacer()
            
            // Day of week
            Text(dayOfWeekFormatter.string(from: date))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(hex: "#404C42"))
    }
    
    private var dayOfWeekFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }
    
    private func isDateRecent(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return date >= weekAgo
    }
}

struct EnhancedLogEntryRow: View {
    let logEntry: MedicationLog
    let store: MedicationStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Get medication details
    private var medication: Medication? {
        store.medications.first { $0.id == logEntry.medicationID }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main medication info
            HStack(alignment: .top, spacing: 12) {
                // Medication icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "#81C784").opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: medication?.iconName ?? "pill.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#81C784"))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Medication name and dosage
                    HStack {
                        Text(logEntry.medicationName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                        
                        Spacer()
                        
                        // Time taken
                        Text(timeFormatter.string(from: logEntry.takenAt))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                    }
                    
                    // Dosage information
                    if let med = medication {
                        HStack(spacing: 8) {
                            Text("\(med.dosage) \(med.dosageUnit)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#81C784"))
                            
                            if let pillsConsumed = logEntry.pillsConsumed, pillsConsumed > 1 {
                                Text("• \(pillsConsumed) pills")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                            }
                            
                            Spacer()
                        }
                    }
                    
                    // Notes and side effects
                    if let notes = logEntry.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            if notes.contains("Side effects:") {
                                let components = notes.components(separatedBy: "Side effects:")
                                
                                // Regular notes
                                if components.count > 0 && !components[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(components[0].trimmingCharacters(in: .whitespacesAndNewlines))
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                }
                                
                                // Side effects
                                if components.count > 1 {
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                        
                                        Text("Side effects: \(components[1].trimmingCharacters(in: .whitespacesAndNewlines))")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.orange)
                                    }
                                }
                            } else {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "note.text")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                                    
                                    Text(notes)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.08)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#C7C7BD").opacity(0.1), lineWidth: 1)
        )
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

struct FloatingButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#404C42"))
                .frame(width: 50, height: 50)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#E8E8E0"),
                            Color(hex: "#D0D0C8"),
                            Color(hex: "#C7C7BD")
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct FilterOptionsOverlay: View {
    let uniqueMedicationNames: [String]
    @Binding var selectedMedicationFilter: String
    @Binding var showingFilterOptions: Bool
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showingFilterOptions = false
                }
            
            VStack(spacing: 16) {
                HStack {
                    Text("Filter by Medication")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    
                    Spacer()
                    
                    Button(action: {
                        showingFilterOptions = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(uniqueMedicationNames, id: \.self) { medicationName in
                            Button(action: {
                                selectedMedicationFilter = medicationName
                                showingFilterOptions = false
                            }) {
                                HStack {
                                    Text(medicationName)
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                    
                                    Spacer()
                                    
                                    if selectedMedicationFilter == medicationName {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: "#81C784"))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    selectedMedicationFilter == medicationName ? 
                                    Color.black.opacity(0.3) : Color.clear
                                )
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
                .padding(.horizontal, 8)
                .padding(.bottom, 20)
            }
            .background(Color(hex: "#404C42"))
            .cornerRadius(16)
            .frame(width: min(geometry.size.width - 40, 350))
            .padding(.horizontal, 20)
        }
    }
}

struct DatePickerOverlay: View {
    @Binding var selectedDate: Date
    @Binding var showingCalendar: Bool
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showingCalendar = false
                }
            
            VStack(spacing: 16) {
                HStack {
                    Text("Select Date")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                    
                    Spacer()
                    
                    Button(action: {
                        showingCalendar = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 12)
                
                HStack(spacing: 12) {
                    Button("Today") {
                        selectedDate = Date()
                        showingCalendar = false
                    }
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(10)
                    
                    Spacer()
                    
                    Button("Select") {
                        showingCalendar = false
                    }
                    .foregroundColor(Color(hex: "#404C42"))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color(hex: "#C7C7BD"))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(hex: "#404C42"))
            .cornerRadius(16)
            .frame(width: min(geometry.size.width - 40, 400))
            .padding(.horizontal, 20)
        }
    }
}


