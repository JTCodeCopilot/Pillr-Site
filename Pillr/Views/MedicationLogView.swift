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
    
    // Group logs by date
    private var groupedLogs: [Date: [MedicationLog]] {
        let calendar = Calendar.current
        var result = [Date: [MedicationLog]]()
        
        for log in store.logs {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: log.takenAt)
            if let date = calendar.date(from: dateComponents) {
                if result[date] == nil {
                    result[date] = [log]
                } else {
                    result[date]?.append(log)
                }
            }
        }
        
        // Sort logs within each day by time
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
        
        // Find logs for the selected date (using the groupedLogs dictionary)
        return groupedLogs[startOfDay] ?? []
    }
    
    // Date formatter for section headers
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
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
                        // Title header with calendar icon - now in a fixed position
                        HStack {
                            Text("Have Taken")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundColor(Color(hex: "#C7C7BD"))
                            
                            Button(action: {
                                showingCalendar = true
                            }) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .padding(.leading, 8)
                            }
                            .accessibilityLabel("Select date")
                            
                            Spacer()
                            
                            // Show selected date if not today
                            if !Calendar.current.isDateInToday(selectedDate) {
                                Text(dateFormatter.string(from: selectedDate))
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .background(Color(hex: "#404C42"))
                        .zIndex(1) // Keep title at the top
                        
                        // Content area - scrollable and takes remaining space
                        ZStack {
                            if store.logs.isEmpty {
                                // Minimal empty state
                                ScrollView {
                                    VStack(spacing: 20) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 50))
                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                            .padding(.bottom, 10)
                                        
                                        Text("No medication logs yet")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                        
                                        Text("When you log a medication, it will appear here")
                                            .font(.system(size: 14))
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                            .padding(.horizontal)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(30)
                                    .background(Color.black.opacity(0.12))
                                    .cornerRadius(8)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 20)
                                }
                            } else if logsForSelectedDate.isEmpty && !Calendar.current.isDateInToday(selectedDate) {
                                // Show message when no logs for selected date
                                ScrollView {
                                    VStack(spacing: 20) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .font(.system(size: 50))
                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                                            .padding(.bottom, 10)
                                        
                                        Text("No medications taken")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(Color(hex: "#C7C7BD"))
                                        
                                        Text("No medications were logged on \(dateFormatter.string(from: selectedDate))")
                                            .font(.system(size: 14))
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
                                            .padding(.horizontal)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(30)
                                    .background(Color.black.opacity(0.12))
                                    .cornerRadius(8)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 20)
                                }
                            } else {
                                // Show logs for the selected date or all logs by date if today is selected
                                if Calendar.current.isDateInToday(selectedDate) {
                                    // Normal grouped list by date - simplified
                                    ScrollView {
                                        LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                                            ForEach(sortedDates, id: \.self) { date in
                                                Section {
                                                    ForEach(groupedLogs[date] ?? []) { logEntry in
                                                        LogEntryRow(logEntry: logEntry)
                                                    }
                                                } header: {
                                                    Text(dateFormatter.string(from: date))
                                                        .font(.system(size: 16, weight: .medium))
                                                        .foregroundColor(Color(hex: "#C7C7BD"))
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .padding(.vertical, 8)
                                                        .padding(.horizontal, 16)
                                                        .background(Color(hex: "#404C42"))
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                } else {
                                    // Show only logs for the selected date - simplified
                                    ScrollView {
                                        LazyVStack(spacing: 8) {
                                            ForEach(logsForSelectedDate) { logEntry in
                                                LogEntryRow(logEntry: logEntry)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                        .navigationBarHidden(true)
                    }
                    // Adjust side padding based on device size
                    .padding(.horizontal, horizontalInsets(for: geometry))
                    
                    // Date Picker Popover
                    if showingCalendar {
                        ZStack {
                            // Semi-transparent background
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    showingCalendar = false
                                }
                            
                            // Calendar view - simplified for better performance
                            VStack(spacing: 12) {
                                // Calendar header
                                HStack {
                                    Text("Select Date")
                                        .font(.system(size: 18, weight: .medium))
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
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                
                                // Date picker - using inline style for better performance
                                DatePicker(
                                    "",
                                    selection: $selectedDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .padding(.horizontal, 8)
                                
                                // Action buttons
                                HStack {
                                    Button("Today") {
                                        selectedDate = Date()
                                        showingCalendar = false
                                    }
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(8)
                                    
                                    Spacer()
                                    
                                    Button("Select") {
                                        showingCalendar = false
                                    }
                                    .foregroundColor(Color(hex: "#404C42"))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color(hex: "#C7C7BD"))
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                            }
                            .background(Color(hex: "#404C42"))
                            .cornerRadius(12)
                            .frame(width: min(geometry.size.width - 40, 400))
                            .padding(.horizontal, 20)
                        }
                        .zIndex(1) // Ensure it appears on top
                    }
                }
            }
        }
        .background(Color.clear)
        .navigationViewStyle(.stack)
    }
    
    // Calculate proper insets based on screen size
    private func horizontalInsets(for geometry: GeometryProxy) -> CGFloat {
        if horizontalSizeClass == .regular && geometry.size.width > 768 {
            // For iPads and larger screens - prevent content from stretching too much
            return max((geometry.size.width - 768) / 3, 0)
        }
        return 0 // Default - use full width on phones
    }
}

struct LogEntryRow: View {
    let logEntry: MedicationLog
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        HStack {
            // Medication name
            Text(logEntry.medicationName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD"))
            
            Spacer()
            
            // Time taken
            Text(timeFormatter.string(from: logEntry.takenAt))
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.black.opacity(0.1))
        .cornerRadius(6)
    }
    
    // Time formatter for displaying just the time
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}
