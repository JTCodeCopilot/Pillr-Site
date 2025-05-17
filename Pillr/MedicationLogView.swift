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

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background color
                    Color(hex: "#404C42")
                        .ignoresSafeArea(edges: [.top, .leading, .trailing, .bottom])
                    
                    List {
                        if store.logs.isEmpty {
                            // Minimal empty state
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
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "#C7C7BD").opacity(0.08), lineWidth: 0.8)
                            )
                            .padding(.horizontal, 20)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 30, leading: 0, bottom: 30, trailing: 0))
                        } else {
                            ForEach(store.logs) { logEntry in
                                LogEntryRow(logEntry: logEntry)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .padding(.vertical, 4)
                            }
                            .onDelete(perform: store.deleteLog)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.clear)
                    .navigationBarHidden(true)
                    // Adjust side padding based on device size
                    .padding(.horizontal, horizontalInsets(for: geometry))
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
        VStack(alignment: .leading, spacing: 6) {
            Text(logEntry.medicationName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#C7C7BD"))
                
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                
                Text("\(logEntry.takenAt, format: .dateTime)")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.7))
            }

            if let notes = logEntry.notes, !notes.isEmpty {
                Divider()
                    .background(Color(hex: "#C7C7BD").opacity(0.1))
                    
                Text(notes)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.6))
                    .lineLimit(2)
            }
            
            // Minimal status indicator
            HStack {
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                
                Text("Taken")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#C7C7BD"))
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(Color.black.opacity(0.12))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#C7C7BD").opacity(0.08), lineWidth: 0.8)
        )
    }
}
