//
//  ResultsView.swift
//  ClimbPulse
//
//  Results screen showing final BPM, quality assessment, and PPG plot.
//

import SwiftUI

struct ResultsView: View {
    let measurement: Measurement
    let onDismiss: () -> Void
    
    @EnvironmentObject var measurementStore: MeasurementStore
    @State private var isSaved = false
    @State private var showShareSheet = false
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
                colors: [primaryBlue.opacity(0.02), primaryBlue.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : primaryBlue.opacity(0.08)
    }
    
    private var primaryText: Color {
        colorScheme == .dark ? Color.white : primaryBlue
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : primaryBlue.opacity(0.6)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Success header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(accentOrange.opacity(colorScheme == .dark ? 0.15 : 0.1))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(accentOrange)
                            }
                            
                            Text("Measurement Complete")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(primaryText)
                        }
                        .padding(.top, 20)
                        
                        // BPM Result Card
                        VStack(spacing: 16) {
                            HStack(alignment: .lastTextBaseline, spacing: 12) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(accentOrange)
                                
                                Text("\(measurement.bpm)")
                                    .font(.system(size: 72, weight: .bold, design: .rounded))
                                    .foregroundColor(primaryText)
                                
                                Text("BPM")
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .foregroundColor(secondaryText)
                            }
                            
                            // Quality badge
                            QualityBadge(quality: measurement.quality)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(cardBorder, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 15, y: 8)
                        .padding(.horizontal, 20)
                        
                        // PPG Plot
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PPG Recording")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(primaryText)
                            
                            StaticPPGPlotView(data: measurement.ppgData)
                                .frame(height: 160)
                        }
                        .padding(.horizontal, 20)
                        
                        // Measurement details
                        VStack(spacing: 12) {
                            DetailRow(label: "Duration", value: String(format: "%.1f seconds", measurement.duration))
                            DetailRow(label: "Sample Rate", value: String(format: "%.1f Hz", measurement.sampleRate))
                            DetailRow(label: "Recorded", value: measurement.formattedDate)
                            DetailRow(label: "Device", value: measurement.deviceModel)
                        }
                        .padding(20)
                        .background(
                            colorScheme == .dark
                            ? Color.white.opacity(0.12)
                            : Color.white
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    colorScheme == .dark ? Color.white.opacity(0.18) : cardBorder,
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 10, y: 6)
                        .padding(.horizontal, 20)
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            Button(action: saveAndDismiss) {
                                HStack(spacing: 8) {
                                    Image(systemName: isSaved ? "checkmark" : "square.and.arrow.down")
                                    Text(isSaved ? "Saved" : "Save Result")
                                }
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            .background(isSaved ? Color.green : accentOrange)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(isSaved)
                            
                            Button(action: onDismiss) {
                                Text("Done")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundColor(primaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(primaryText.opacity(colorScheme == .dark ? 0.12 : 0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(primaryText)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [createShareText()])
        }
    }
    
    private func saveAndDismiss() {
        measurementStore.save(measurement)
        withAnimation {
            isSaved = true
        }
    }
    
    private func createShareText() -> String {
        """
        ClimbPulse Heart Rate Measurement
        ❤️ \(measurement.bpm) BPM
        📊 Quality: \(measurement.quality.rawValue)
        📅 \(measurement.formattedDate)
        """
    }
}

// MARK: - Supporting Views

struct QualityBadge: View {
    let quality: SignalQuality
    
    private var backgroundColor: Color {
        quality == .good ? Color.green.opacity(0.15) : Color.orange.opacity(0.15)
    }
    
    private var textColor: Color {
        quality == .good ? .green : .orange
    }
    
    private var icon: String {
        quality == .good ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text("Signal Quality: \(quality.rawValue)")
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundColor(textColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .clipShape(Capsule())
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    @Environment(\.colorScheme) private var colorScheme
    private let primaryBlue = Color(red: 0.0, green: 0.34, blue: 0.65)
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.75) : primaryBlue.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? Color.white : primaryBlue)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let sampleMeasurement = Measurement(
        userId: "test-user",
        duration: 30.0,
        sampleRate: 30.0,
        bpm: 72,
        quality: .good,
        ppgData: (0..<100).map { i in
            120 + 15 * sin(Double(i) / 100.0 * 30.0 * 2 * .pi * 1.2)
        }
    )
    
    return ResultsView(measurement: sampleMeasurement, onDismiss: {})
        .environmentObject(MeasurementStore())
}


