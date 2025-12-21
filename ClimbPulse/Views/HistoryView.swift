//
//  HistoryView.swift
//  ClimbPulse
//
//  History view showing past measurements sorted by date.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var measurementStore: MeasurementStore
    @State private var selectedMeasurement: Measurement?
    @Environment(\.colorScheme) private var colorScheme
    
    // JYU-inspired palette
    private let primaryBlue = Color(red: 0.0, green: 0.34, blue: 0.65)      // #0056A5
    private let darkBlue = Color(red: 0.02, green: 0.16, blue: 0.32)       // #042948
    private let accentOrange = Color(red: 1.0, green: 0.51, blue: 0.0)     // #FF8200
    private let accentYellow = Color(red: 1.0, green: 0.72, blue: 0.11)    // #FFB81C
    
    private var backgroundGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.black, darkBlue.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [primaryBlue.opacity(0.05), primaryBlue.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var primaryText: Color {
        colorScheme == .dark ? Color.white : darkBlue
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : darkBlue.opacity(0.6)
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
                .ignoresSafeArea()
            
            if measurementStore.measurements.isEmpty {
                EmptyHistoryView()
            } else {
                List {
                    ForEach(groupedMeasurements, id: \.0) { dateString, measurements in
                        Section {
                            ForEach(measurements) { measurement in
                                MeasurementRow(measurement: measurement)
                                    .onTapGesture {
                                        selectedMeasurement = measurement
                                    }
                            }
                            .onDelete { offsets in
                                deleteMeasurements(in: measurements, at: offsets)
                            }
                        } header: {
                            Text(dateString)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(secondaryText)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !measurementStore.measurements.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: clearAllHistory) {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(primaryText)
                    }
                }
            }
        }
        .sheet(item: $selectedMeasurement) { measurement in
            MeasurementDetailView(measurement: measurement)
        }
    }
    
    /// Group measurements by date.
    private var groupedMeasurements: [(String, [Measurement])] {
        let grouped = Dictionary(grouping: measurementStore.measurements) { measurement -> String in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: measurement.timestamp)
        }
        
        return grouped.sorted { first, second in
            // Sort by most recent date first
            guard let date1 = first.value.first?.timestamp,
                  let date2 = second.value.first?.timestamp else { return false }
            return date1 > date2
        }
    }
    
    private func deleteMeasurements(in measurements: [Measurement], at offsets: IndexSet) {
        for index in offsets {
            let measurementToDelete = measurements[index]
            measurementStore.delete(measurementToDelete)
        }
    }
    
    private func clearAllHistory() {
        measurementStore.clearAll()
    }
}

// MARK: - Supporting Views

struct EmptyHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let primaryBlue = Color(red: 0.0, green: 0.34, blue: 0.65)
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundColor((colorScheme == .dark ? Color.white : primaryBlue).opacity(0.3))
            
            VStack(spacing: 8) {
                Text("No Measurements Yet")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? Color.white : primaryBlue)
                
                Text("Your heart rate measurements will appear here")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : primaryBlue.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

struct MeasurementRow: View {
    let measurement: Measurement
    
    @Environment(\.colorScheme) private var colorScheme
    private let primaryBlue = Color(red: 0.0, green: 0.34, blue: 0.65)
    private let accentOrange = Color(red: 1.0, green: 0.51, blue: 0.0)
    
    var body: some View {
        HStack(spacing: 16) {
            // Heart icon with BPM
            ZStack {
                Circle()
                    .fill((colorScheme == .dark ? Color.white : accentOrange).opacity(0.12))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundColor(accentOrange)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(measurement.bpm)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? Color.white : primaryBlue)
                    
                    Text("BPM")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : primaryBlue.opacity(0.6))
                }
                
                Text(timeString(from: measurement.timestamp))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : primaryBlue.opacity(0.5))
            }
            
            Spacer()
            
            // Quality indicator
            QualityIndicator(quality: measurement.quality)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor((colorScheme == .dark ? Color.white : primaryBlue).opacity(0.35))
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct QualityIndicator: View {
    let quality: SignalQuality
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Text(quality.rawValue)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(quality == .good ? .green : .orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                (quality == .good ? Color.green : Color.orange).opacity(colorScheme == .dark ? 0.18 : 0.12)
            )
            .clipShape(Capsule())
    }
}

// MARK: - Detail View

struct MeasurementDetailView: View {
    let measurement: Measurement
    @Environment(\.dismiss) private var dismiss
    
    @Environment(\.colorScheme) private var colorScheme
    private let primaryBlue = Color(red: 0.0, green: 0.34, blue: 0.65)
    private let darkBlue = Color(red: 0.02, green: 0.16, blue: 0.32)
    private let accentOrange = Color(red: 1.0, green: 0.51, blue: 0.0)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // BPM display
                    VStack(spacing: 8) {
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 32))
                                .foregroundColor(accentOrange)
                            
                            Text("\(measurement.bpm)")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? Color.white : primaryBlue)
                            
                            Text("BPM")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : primaryBlue.opacity(0.6))
                        }
                        
                        QualityBadge(quality: measurement.quality)
                    }
                    .padding(.top, 20)
                    
                    // PPG Plot
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PPG Recording")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? Color.white : primaryBlue)
                        
                        StaticPPGPlotView(data: measurement.ppgData)
                            .frame(height: 160)
                    }
                    .padding(.horizontal, 20)
                    
                    // Details
                    VStack(spacing: 12) {
                        DetailRow(label: "Date", value: measurement.formattedDate)
                        DetailRow(label: "Duration", value: String(format: "%.1f seconds", measurement.duration))
                        DetailRow(label: "Sample Rate", value: String(format: "%.1f Hz", measurement.sampleRate))
                        DetailRow(label: "Device", value: measurement.deviceModel)
                    }
                    .padding(20)
                    .background(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.18) : primaryBlue.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 10, y: 6)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 30)
            }
            .background(
                (colorScheme == .dark ?
                 AnyView(LinearGradient(colors: [Color.black, darkBlue.opacity(0.9)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()) :
                    AnyView(LinearGradient(colors: [primaryBlue.opacity(0.05), primaryBlue.opacity(0.12)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
                )
            )
            .navigationTitle("Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(colorScheme == .dark ? Color.white : primaryBlue)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environmentObject(MeasurementStore())
    }
}


