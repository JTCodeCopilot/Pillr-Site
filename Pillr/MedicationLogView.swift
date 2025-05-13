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
                    // Background color - match the exact gradient from ContentView
                    LinearGradient.pillrBackground
                    .ignoresSafeArea()
                    
                    List {
                        if store.logs.isEmpty {
                            Text("No medications logged yet.")
                                .foregroundColor(.white.opacity(0.7))
                                .listRowBackground(Color.clear)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 50)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(logEntry.medicationName)
                .font(horizontalSizeClass == .regular ? .title3 : .headline)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: horizontalSizeClass == .regular ? 14 : 12))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("\(logEntry.takenAt, format: .dateTime)")
                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }

            if let notes = logEntry.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: horizontalSizeClass == .regular ? 14 : 12))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 2)
                    
                    Text(notes)
                        .font(horizontalSizeClass == .regular ? .subheadline : .caption)
                        .italic()
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(3)
                }
            }
            
            // Add visual status indicator
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: horizontalSizeClass == .regular ? 14 : 12))
                    .foregroundColor(.green.opacity(0.8))
                
                Text("Completed")
                    .font(horizontalSizeClass == .regular ? .footnote : .caption2)
                    .foregroundColor(.green.opacity(0.8))
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(horizontalSizeClass == .regular ? 16 : 12)
        .gyroGlassCardStyle(
            cornerRadius: 20, 
            material: .ultraThinMaterial,
            borderColor: Color.white.opacity(0.3),
            borderWidth: 1.2,
            shadowOpacity: 0.18,
            shadowRadius: 10,
            shineOpacity: 0.6
        )
    }
}
